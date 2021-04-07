
import MobileCoreServices
import AVFoundation

class KloekAudioRecorder : AVAudioRecorder {
    var callbackID : String?;
}

@objc(KloekAudioCapture) class KloekAudioCapture : CDVPlugin, AVAudioRecorderDelegate {
    
    var audioSession : AVAudioSession? = nil;
    var audioRecorder : KloekAudioRecorder? = nil;
    
    var audioSampleRate = 44100.0;
    var audioNumChannels = 1;
    var audioReuseRecorder = false;
    
    var audioMeterTimer : Timer? = nil;
    
    var audioHasRecorded = false;
    
    
    // MARK: - Bridge methods
    @objc(startCaptureSession:)
    func startCaptureSession(command: CDVInvokedUrlCommand)
    {
        doStartCaptureSession(command.argument(at: 0) as! Dictionary<String, Any>, command.callbackId);
    }
    
    @objc(stopCaptureSession:)
    func stopCaptureSession(command: CDVInvokedUrlCommand)
    {
        doStopCaptureSession(command.callbackId);
    }
    
    @objc(startAudioRecording:)
    func startAudioRecording(command: CDVInvokedUrlCommand)
    {
        doStartAudioRecording(command.argument(at: 0) as! Dictionary<String, Any>, command.callbackId);
    }
    
    @objc(stopAudioRecording:)
    func stopAudioRecording(command: CDVInvokedUrlCommand)
    {
        doStopAudioRecording(command.callbackId);
    }
    
    // MARK: - Bridged methods
    func doStartCaptureSession(_ options : Dictionary<String, Any>, _ callbackID : String)
    {
        if(self.audioSession != nil){ return self.sendError("Session already running", callbackID); }
        
        audioSampleRate = options["sampleRate"] as? Double ?? 44100.0;
        audioNumChannels = options["numChannels"] as? Int ?? 1;
        audioReuseRecorder = options["reuseRecorder"] as? Bool ?? false;
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.audioSession = AVAudioSession.sharedInstance();
            do {
                self.audioSession?.requestRecordPermission({ (allowed) in
                    if(!allowed){ return self.sendError("Recording not allowed", callbackID); }
                    self.commandDelegate.send(CDVPluginResult.init(status: CDVCommandStatus_OK), callbackId: callbackID);
                });
            } catch {
                self.sendError(error.localizedDescription, callbackID);
            }
        }

    }
    
    func doStopCaptureSession(_ callbackID : String)
    {
        DispatchQueue.global(qos: .userInitiated).async {
            if(self.audioSession == nil){ return self.sendError("No session running", callbackID); }
            
            do {
                try self.audioSession?.setActive(false);
                self.audioSession = nil;
                if(!self.audioHasRecorded){
                    self.audioRecorder?.deleteRecording();
                }
                self.audioRecorder = nil;
                self.commandDelegate.send(CDVPluginResult.init(status: CDVCommandStatus_OK), callbackId: callbackID);
            } catch {
                return self.sendError(error.localizedDescription, callbackID);
            }
        }
    }
    
    func doStartAudioRecording(_ options : Dictionary<String, Any>, _ callbackID : String)
    {
        let duration : Double? = options["duration"] as? Double;
        
        DispatchQueue.global(qos: .userInitiated).async {
            if(self.audioSession == nil){ return self.sendError("No session running", callbackID); }
            if(self.audioRecorder != nil && self.audioRecorder!.isRecording){ return self.sendError("Recording already running", callbackID); }
            
            
            //prepare recorder
            do {
                try self.audioSession?.setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.record)));
                try self.audioSession?.setActive(true);
                try self.prepareRecorder();
            } catch {
                return self.sendError(error.localizedDescription, callbackID);
            }
            
            if(duration != nil){
                self.audioRecorder?.record(forDuration: duration!);
            }else{
                self.audioRecorder?.record();
            }
            self.audioRecorder?.callbackID = callbackID;
            self.audioHasRecorded = true;
            
            let dict : Dictionary<String, Any> = [
                "evt": "didStartRecording",
                "file": [
                    "url" : self.audioRecorder!.url.absoluteString
                ]
            ]
            let result = CDVPluginResult.init(status: CDVCommandStatus_OK, messageAs: dict);
            result?.keepCallback = true;
            self.commandDelegate.send(result, callbackId: callbackID);
            
            DispatchQueue.main.async {
                self.audioMeterTimer = Timer.scheduledTimer(timeInterval: 0.1,
                                                            target:self,
                                                            selector:#selector(self.updateAudioMeter(_:)),
                                                            userInfo:nil,
                                                            repeats:true);
            }
        }
    }
    
    func doStopAudioRecording(_ callbackID : String)
    {
        if(audioSession == nil){ return sendError("No session running", callbackID); }
        if(audioRecorder == nil || !audioRecorder!.isRecording){ return sendError("Recording not running", callbackID); }
        
        audioRecorder?.stop();
        
        self.commandDelegate.send(CDVPluginResult.init(status: CDVCommandStatus_OK), callbackId: callbackID);
    }

    // MARK: util functions
    func prepareRecorder() throws
    {
        if(audioReuseRecorder && self.audioRecorder != nil){
            audioRecorder?.prepareToRecord();
            return;
        }
        self.audioRecorder = try KloekAudioRecorder.init(url: createFileUrl()!, settings: [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: audioSampleRate,
            AVNumberOfChannelsKey: audioNumChannels,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]);
        audioRecorder?.delegate = self;
        audioRecorder?.prepareToRecord();
        audioRecorder?.isMeteringEnabled = true;
        audioHasRecorded = false;
    }
    
    
    @objc func updateAudioMeter(_ timer:Timer){
        audioRecorder?.updateMeters();
        let average = audioRecorder?.averagePower(forChannel: 0);
        let peak = audioRecorder?.peakPower(forChannel: 0);
        
        if(audioRecorder == nil){ return; }
        
        let dict : Dictionary<String, Any> = [
            "evt": "metering",
            "metering": [
                "average":average,
                "peak": peak
            ]
        ]
        let result = CDVPluginResult.init(status: CDVCommandStatus_OK, messageAs: dict);
        result?.keepCallback = true;
        self.commandDelegate.send(result, callbackId: audioRecorder!.callbackID);

    }
    
    func createFileUrl() -> URL?
    {
        let fileName = String(format: "%@%@", NSUUID().uuidString, ".m4a");
        let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName);
        return fileURL;
    }
    
    func sendError(_ message : String, _ callbackID : String?){
        return commandDelegate.send(CDVPluginResult.init(status: CDVCommandStatus_ERROR, messageAs: message), callbackId: callbackID);
    }
    
    // MARK: AVAudioRecorderDelegate
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        self.audioMeterTimer?.invalidate();
        
        let capture : KloekAudioRecorder? = recorder as? KloekAudioRecorder;
        if(capture == nil){ return; }
        
        if !flag {
            return sendError("Recorder finished unsuccessfully", capture!.callbackID!);
        }
        
        let finalURL = createFileUrl();
        
        do{
            try self.audioSession?.setCategory(AVAudioSession.Category(rawValue: convertFromAVAudioSessionCategory(AVAudioSession.Category.playback)));
            try FileManager.default.copyItem(at: capture!.url, to: finalURL!);
        }catch {
             return sendError(error.localizedDescription, capture!.callbackID!);
        }
        
        let dict : Dictionary<String, Any> = [
            "evt": "didFinishRecording",
            "file": [
                "url" : finalURL!.absoluteString
            ]
        ]
        let result = CDVPluginResult.init(status: CDVCommandStatus_OK, messageAs: dict);
        
        commandDelegate.send(result, callbackId: capture?.callbackID);
        
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
	return input.rawValue
}
