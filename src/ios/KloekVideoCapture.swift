import MobileCoreServices
import AVFoundation
import Photos
import UIKit
import UIKit.UIDevice

extension UIImage {
    struct RotationOptions: OptionSet {
        let rawValue: Int
        
        static let flipOnVerticalAxis = RotationOptions(rawValue: 1)
        static let flipOnHorizontalAxis = RotationOptions(rawValue: 2)
    }
}

extension UIImage {
    func fixImageOrientation(isUsingFrontCamera: Bool) -> UIImage {
        
        print("Front camera?", isUsingFrontCamera);
   
        switch self.imageOrientation {
            case .down:
                print("down")
            case .downMirrored:
                print("downMirrored")
            case .left:
                print("left")
            case .leftMirrored:
                print("leftMirrored")
            case .right:
                print("right")
            case .rightMirrored:
                print("rightMirrored")
            case .up:
                print("up")
            case .upMirrored:
                print("upMirrored")
                break
        }

        switch UIKit.UIDevice.current.orientation {
            case UIDeviceOrientation.portrait:
                print("oriantation?", "portrait");
            case UIDeviceOrientation.portraitUpsideDown:
                print("oriantation?", "portraitUpsideDown");
            case UIDeviceOrientation.landscapeLeft:
                print("oriantation?", "landscapeLeft");
            case UIDeviceOrientation.landscapeRight:
                print("oriantation?", "landscapeRight");
            case UIDeviceOrientation.faceDown:
                print("oriantation?", "faceDown");
            case UIDeviceOrientation.faceUp:
                print("oriantation?", "faceUp");
            default:
                print("oriantation?", "default");
            }
        
        return self;
    }
    
    func autoAdjust() -> UIImage {
        var inputImage = CIImage(image: self)!
        let filters = inputImage.autoAdjustmentFilters(options: nil)
        for filter: CIFilter in filters {
            filter.setValue(inputImage, forKey: kCIInputImageKey)
//            print("filter", filter.name)
            inputImage = filter.outputImage!
        }
        
        let context:CIContext = CIContext.init(options: nil)
        let cgImage:CGImage = context.createCGImage(inputImage, from: inputImage.extent)!
        let image:UIImage = UIImage.init(cgImage: cgImage)
        
        return image
    }
}
extension UIImage {
    func fixedOrientation(isUsingFrontCamera: Bool) -> UIImage? {
        var flip:Bool = false //used to see if the image is mirrored
        var isRotatedBy90:Bool = false // used to check whether aspect ratio is to be changed or not
        
        var transform = CGAffineTransform.identity
        
        //check current orientation of original image
        switch self.imageOrientation {
        case .down, .downMirrored:
            print("down")
            transform = transform.rotated(by: .pi);
        case .left, .leftMirrored:
            print("left")
            transform = transform.rotated(by: .pi / 2);
            isRotatedBy90 = true
        case .right, .rightMirrored:
            print("right")
            transform = transform.rotated(by: .pi / -2);
            isRotatedBy90 = true
        case .up, .upMirrored:
            print("up")
            break
        }
        
        switch self.imageOrientation {
            
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: self.size.width, y: 0)
            flip = true
            print("mirror vertical")
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: self.size.height, y: 0)
            flip = true
            print("mirror horizontal")
        default:
            break;
        }
        
        if isUsingFrontCamera {
            transform = transform.translatedBy(x: self.size.width, y: 0)
            flip = true
        }
        
        // calculate the size of the rotated view's containing box for our drawing space
        let rotatedViewBox = UIView(frame: CGRect(origin: CGPoint(x:0, y:0), size: size))
        rotatedViewBox.transform = transform
        let rotatedSize = rotatedViewBox.frame.size
        
        // Create the bitmap context
        UIGraphicsBeginImageContext(rotatedSize)
        let bitmap = UIGraphicsGetCurrentContext()
        
        // Move the origin to the middle of the image so we will rotate and scale around the center.
        bitmap!.translateBy(x: rotatedSize.width / 2.0, y: rotatedSize.height / 2.0);
        
        // Now, draw the rotated/scaled image into the context
        if(flip){
            bitmap!.scaleBy(x: 1.0, y: 1.0)
        } else {
            bitmap!.scaleBy(x: 1.0, y: -1.0)
        }
        
        
        print("Transform Image", flip, isRotatedBy90, separator:" ")
        
        //check if we have to fix the aspect ratio
        if isRotatedBy90 {
            bitmap?.draw(self.cgImage!, in: CGRect(x: -floor(size.height / 2), y: -floor(size.width / 2), width: size.height,height: size.width))
        } else {
            bitmap?.draw(self.cgImage!, in: CGRect(x: -floor(size.width / 2), y: -floor(size.height / 2), width: size.width,height: size.height))
        }
        
        let fixedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return fixedImage
    }
}

class KloekCaptureMovieFileOutput : AVCaptureMovieFileOutput {
    var callbackID : String?;
    
    init(_ callbackID : String?){
        self.callbackID = callbackID;
    }
}

class KloekCapturePhotoOutput : AVCapturePhotoOutput {
    var callbackID : String?;
    
    init(_ callbackID : String?){
        self.callbackID = callbackID;
    }
}

class KloekCaptureFileOutput : AVCaptureFileOutput {
    var callbackID : String?;
    
    init(_ callbackID : String?){
        self.callbackID = callbackID;
    }
}

@objc(KloekVideoCapture) class KloekVideoCapture : CDVPlugin, AVCaptureFileOutputRecordingDelegate, AVCapturePhotoCaptureDelegate
{
    var videoSession : AVCaptureSession? = nil;
    
    // MARK: Video session settings
    var videoSessionPreset = AVCaptureSession.Preset.high;
    var videoSessionDevicePosition = AVCaptureDevice.Position.unspecified;
    var videoSessionVideoEnabled = true;
    var videoSessionAudioEnabled = true;

    // MARK: Preview settings
    var preview : AVCaptureVideoPreviewLayer? = nil;
    var previewBounds = CGRect.zero;
    var previewUseDeviceOrientation = false;
    var previewVideoGravity = AVLayerVideoGravity.resizeAspectFill;

    // MARK: Video recording settings
    var videoRecording : KloekCaptureMovieFileOutput? = nil;
    var videoRecordingUseDeviceOrientation = false;
    var videoRecordingAutoSave = false;
    
    // MARK: Grab Image settings
    var imageOutput : KloekCapturePhotoOutput? = nil;
    var imageFixOrientation = true;
    var imageAutoAdjust = true;
    var imageAutoSave = false;
    var imageFullFrame = true;

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

    @objc(showPreview:)
    func showPreview(command: CDVInvokedUrlCommand)
    {
        doShowPreview(command.argument(at: 0) as! Dictionary<String, Any>, command.callbackId);
    }

    @objc(hidePreview:)
    func hidePreview(command: CDVInvokedUrlCommand)
    {
        doHidePreview(command.argument(at: 0) as! Dictionary<String, Any>, command.callbackId);
    }

    @objc(startVideoRecording:)
    func startVideoRecording(command: CDVInvokedUrlCommand)
    {
        doStartVideoRecording(command.argument(at: 0) as! Dictionary<String, Any>, command.callbackId);
    }

    @objc(stopVideoRecording:)
    func stopVideoRecording(command: CDVInvokedUrlCommand)
    {
        doStopVideoRecording(command.callbackId);
    }

    @objc(grabImage:)
    func grabImage(command: CDVInvokedUrlCommand)
    {
        print("KloekVideoCapture.grabImage()");
        doGrabImage(command.argument(at: 0) as! Dictionary<String, Any>, command.callbackId);
    }

    
    

    // MARK: - Bridged methods
    func doStartCaptureSession(_ options : Dictionary<String, Any>, _ callbackID : String)
    {
        print("KloekVideoCapture.doStartCaptureSession()");
        if(isSessionRunning()){ return sendError("Session is already running", callbackID); }

        videoSessionVideoEnabled = options["video"] as? Bool ?? true;
        videoSessionAudioEnabled = options["audio"] as? Bool ?? true;
        if !videoSessionVideoEnabled && !videoSessionAudioEnabled {
            return commandDelegate.send(CDVPluginResult.init(status: CDVCommandStatus_ERROR, messageAs: "No audio and video selected"), callbackId: callbackID);
        }

        let preset : String? = options["preset"] as? String ?? options["quality"] as? String;
        switch preset {
        case "low"?: videoSessionPreset = AVCaptureSession.Preset.low;
        case "medium"?: videoSessionPreset = AVCaptureSession.Preset.medium;
        case "high"?: videoSessionPreset = AVCaptureSession.Preset.high;
        case "photo"?: videoSessionPreset = AVCaptureSession.Preset.photo;
        case "640x480"?: videoSessionPreset = AVCaptureSession.Preset.vga640x480;
        case "1280x720"?: videoSessionPreset = AVCaptureSession.Preset.hd1280x720;
        case "1920x1080"?: videoSessionPreset = AVCaptureSession.Preset.hd1920x1080;
        case "3840x2160"?: videoSessionPreset = AVCaptureSession.Preset.hd4K3840x2160;
        default: videoSessionPreset = AVCaptureSession.Preset.high;
        }

        let position : String? = options["position"] as? String ?? options["camera"] as? String;
        switch position {
        case "back"?: videoSessionDevicePosition = AVCaptureDevice.Position.back;
        case "rear"?: videoSessionDevicePosition = AVCaptureDevice.Position.back;
        case "front"?: videoSessionDevicePosition = AVCaptureDevice.Position.front;
        default: videoSessionDevicePosition = AVCaptureDevice.Position.unspecified;
        }
        
        imageFullFrame = options["fullFramePhotos"] as? Bool ?? true;

        /*
         Make sure all settings are set correctly now
         */

        //starting up a background thread for running checks and starting the session
        DispatchQueue.global(qos: .userInitiated).async {
            self.videoSession = AVCaptureSession.init();
            
            self.imageOutput = KloekCapturePhotoOutput(callbackID);
            self.imageOutput?.isHighResolutionCaptureEnabled = self.imageFullFrame;
            self.imageOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format:[AVVideoCodecKey:AVVideoCodecType.jpeg])], completionHandler: nil);
            self.videoSession?.addOutput(self.imageOutput!);
            
            // prepare the preview view
            self.preview = AVCaptureVideoPreviewLayer.init(session: self.videoSession!);
            
            // prepare recording
            self.videoRecording = KloekCaptureMovieFileOutput(callbackID);
            self.videoRecording?.movieFragmentInterval = CMTime.invalid; //unrecommended in docs, but other libs use this

            if self.videoSession?.canAddOutput(self.videoRecording!) ?? false {
                self.videoSession?.addOutput(self.videoRecording!)
            }

            //init session with preset
            self.videoSession?.startRunning();
            self.videoSession?.sessionPreset = self.videoSessionPreset;

            /*
             VIDEO
             */
            if(self.videoSessionVideoEnabled) {
                // find the default device and then try to find it by position
                var videoCaptureDevice = AVCaptureDevice.DiscoverySession.init(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera], mediaType: .video, position: self.videoSessionDevicePosition).devices.first;
                
                if (videoCaptureDevice == nil) {
                    videoCaptureDevice = AVCaptureDevice.default(for: AVMediaType.video);
                }
                
                if (videoCaptureDevice == nil) { return self.sendError("No suitable video device found", callbackID); }
                
                do {
                    try videoCaptureDevice?.lockForConfiguration();
                                                           
                    if (videoCaptureDevice!.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance)){
                        videoCaptureDevice?.whiteBalanceMode = .continuousAutoWhiteBalance;
                    }
                    
                    if (videoCaptureDevice?.isAutoFocusRangeRestrictionSupported == true) {
                        videoCaptureDevice?.autoFocusRangeRestriction =  AVCaptureDevice.AutoFocusRangeRestriction.near;
                    }
                    
                    if (videoCaptureDevice?.isLowLightBoostSupported == true) {
                        videoCaptureDevice?.automaticallyEnablesLowLightBoostWhenAvailable = true;
                    }
                    
                    videoCaptureDevice?.unlockForConfiguration();
                    
                } catch {
                    return self.sendError("Unable to set capture device configuration", callbackID);
                }
            
                do {
                    let videoCaptureDeviceInput = try AVCaptureDeviceInput.init(device: videoCaptureDevice!);
                    if(!self.videoSession!.canAddInput(videoCaptureDeviceInput)){ return self.sendError("Unable to add video device to session", callbackID); }
                    self.videoSession?.addInput(videoCaptureDeviceInput);
                }catch{
                    return self.sendError(error.localizedDescription, callbackID);
                }
            }


            /*
             AUDIO
             */
            if(self.videoSessionAudioEnabled){
                let audioCaptureDevice = AVCaptureDevice.default(for: AVMediaType.audio);
                do {
                    let audioCaptureDeviceInput = try AVCaptureDeviceInput.init(device: audioCaptureDevice!);
                    if(!self.videoSession!.canAddInput(audioCaptureDeviceInput)){ return self.sendError("Unable to add audio device to session", callbackID); }
                    self.videoSession?.addInput(audioCaptureDeviceInput);
                }catch{
                    return self.sendError(error.localizedDescription, callbackID);
                }
            }


            self.commandDelegate.send(CDVPluginResult.init(status: CDVCommandStatus_OK), callbackId: callbackID);
        }
    }

    func doStopCaptureSession(_ callbackID : String)
    {
        print("KloekVideoCapture.doStopCaptureSession()");
        if(!isSessionRunning()){ return sendError("Session not running", callbackID); }

        preview?.removeFromSuperlayer();
        DispatchQueue.global(qos: .userInitiated).async {
            self.videoSession?.stopRunning();
            self.videoSession = nil;
            
            self.preview?.connection?.isEnabled = false;
            self.preview = nil;
            
            self.videoRecording = nil;
            self.imageOutput = nil;
            
            self.commandDelegate.send(CDVPluginResult.init(status: CDVCommandStatus_OK), callbackId: callbackID);
        }
    }

    func doShowPreview(_ options : Dictionary<String, Any>, _ callbackID : String)
    {
        print("KloekVideoCapture.doShowPreview()");
        if(!isSessionRunning()){ return sendError("Session not running", callbackID); }
        if(!videoSessionVideoEnabled){ return sendError("No video in session", callbackID); }

        if(preview != nil && preview?.superlayer != nil){ return sendError("Preview should already showing", callbackID) }

        let rect : Dictionary<String, Double>? = options["rect"] as? Dictionary<String, Double> ?? options["bounds"] as? Dictionary<String, Double>;
        previewBounds = CGRect.init(x: rect?["x"] ?? 0, y: rect?["y"] ?? 0, width: rect?["width"] ?? 1920, height: rect?["height"] ?? 1080);

        previewUseDeviceOrientation = options["useDeviceOrientation"] as? Bool ?? false;

        let videoGravity = options["gravity"] as? String ?? options["size"] as? String;
        switch videoGravity {
            case "resize"?: previewVideoGravity = AVLayerVideoGravity.resize;
            case "fill"?: previewVideoGravity = AVLayerVideoGravity.resizeAspectFill;
            case "resizeAspect"?: previewVideoGravity = AVLayerVideoGravity.resizeAspect;
            case "contain"?: previewVideoGravity = AVLayerVideoGravity.resizeAspect;
            case "resizeAspectFill"?: previewVideoGravity = AVLayerVideoGravity.resizeAspectFill;
            case "cover"?: previewVideoGravity = AVLayerVideoGravity.resizeAspectFill;
            default: previewVideoGravity = AVLayerVideoGravity.resizeAspectFill;
        }

        self.preview?.bounds = self.previewBounds;
        self.preview?.videoGravity = self.previewVideoGravity;
        self.preview?.position = CGPoint(x: self.previewBounds.midX, y:self.previewBounds.midY);
        self.preview?.connection?.videoOrientation = findPreviewOrientation();

        // TODO: add behind
        self.preview?.connection?.isEnabled = true;
        self.webView.layer.addSublayer(self.preview!);

        var duration = options["fadeDuration"] as? Double ?? 0;
        if(duration==0){ duration = 0.01; }
        CATransaction.begin();
        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 0;
        fadeAnim.toValue = 1;
        fadeAnim.duration = duration;
        CATransaction.setCompletionBlock {
            self.preview?.removeAllAnimations();
            self.commandDelegate.send(CDVPluginResult.init(status: CDVCommandStatus_OK), callbackId: callbackID);
        }
        self.preview?.opacity = 1;
        self.preview?.add(fadeAnim, forKey: "opacity")
        CATransaction.commit();
    }

    func doHidePreview(_ options : Dictionary<String, Any>, _ callbackID : String)
    {
        print("KloekVideoCapture.doHidePreview()");
        if(preview == nil || preview?.superlayer == nil){ return sendError("No preview available", callbackID); }

        var duration = options["fadeDuration"] as? Double ?? 0;
        if(duration==0){ duration = 0.01; }
        CATransaction.begin();
        let fadeAnim = CABasicAnimation(keyPath: "opacity")
        fadeAnim.fromValue = 1;
        fadeAnim.toValue = 0;
        fadeAnim.duration = duration;
        CATransaction.setCompletionBlock {
            self.preview?.removeAllAnimations();
            self.preview?.connection?.isEnabled = false;
                    self.preview?.removeFromSuperlayer();
            self.commandDelegate.send(CDVPluginResult.init(status: CDVCommandStatus_OK), callbackId: callbackID);
        }
        self.preview?.opacity = 0;
        self.preview?.add(fadeAnim, forKey: "opacity")
        CATransaction.commit();
    }

    func doStartVideoRecording(_ options : Dictionary<String, Any>, _ callbackID : String)
    {
        print("KloekVideoCapture.doStartVideoRecording()");
        if(!isSessionRunning()){ return sendError("Session not running", callbackID); }
        if(!videoSessionVideoEnabled){ return sendError("No video in session", callbackID); }
        if(isVideoRecording()){ return sendError("Video already recording", callbackID); }

        videoRecordingUseDeviceOrientation = options["useDeviceOrientation"] as? Bool ?? false;
        videoRecordingAutoSave = options["autoSave"] as? Bool ?? false;

        let fileName = String(format: "%@%@", NSUUID().uuidString, ".mov");
        let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName);

        let duration : Double? = options["duration"] as? Double
        if duration != nil { videoRecording?.maxRecordedDuration = CMTime.init(seconds: duration!, preferredTimescale: 1); }

        // fix orientation
        let connection : AVCaptureConnection? = videoRecording?.connection(with: AVMediaType.video);
        if connection?.isVideoOrientationSupported ?? false {
            connection?.videoOrientation = findVideoRecordingOrientation();
        }

        videoRecording?.callbackID = callbackID;
        videoRecording?.startRecording(to: fileURL!, recordingDelegate: self);
    }

    func doStopVideoRecording(_ callbackID : String)
    {
        print("KloekVideoCapture.doStopVideoRecording()");
        if(!isVideoRecording()){ return sendError("Video not recording", callbackID); }

        videoRecording?.stopRecording();
        self.commandDelegate.send(CDVPluginResult.init(status: CDVCommandStatus_OK), callbackId: callbackID);
    }
    
    func doGrabImage(_ options : Dictionary<String, Any>, _ callbackID : String) {
        print("KloekVideoCapture.doGrabImage()");
        
        if(!isSessionRunning()){ return sendError("Session not running", callbackID); }
        if(!videoSessionVideoEnabled){ return sendError("No video in session", callbackID); }
       
        imageFixOrientation = options["fixOrientation"] as? Bool ?? true;
        imageAutoAdjust = options["autoAdjust"] as? Bool ?? true;
        imageAutoSave = options["autoSave"] as? Bool ?? false;
            
        let settings = AVCapturePhotoSettings();
        settings.flashMode = AVCaptureDevice.FlashMode.off;
        settings.isHighResolutionPhotoEnabled = false;
        
        imageOutput?.callbackID = callbackID;
        imageOutput?.capturePhoto(with: settings, delegate: self);
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("KloekVideoCapture.photoOutput()");
        
        let capture : KloekCapturePhotoOutput? = output as? KloekCapturePhotoOutput;
        if (capture == nil) { return; } //invalid capture
        
        if (error != nil) {
            return self.sendError(error!.localizedDescription, (capture?.callbackID)!);
        }
        
        let fileName = String(format: "%@%@", NSUUID().uuidString, ".jpg");
        let fileURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(fileName);
        
        let imageData:Data = photo.fileDataRepresentation()!;

        var image = UIImage.init(data: imageData);

        if (self.imageFixOrientation) {
            var frontcamera:Bool = false;
            if self.videoSessionDevicePosition == AVCaptureDevice.Position.front {
                frontcamera = true;
            }
            image = image?.fixedOrientation(isUsingFrontCamera:frontcamera);
        }

        if (self.imageAutoAdjust) {
            image = image?.autoAdjust();
        }

        do {
            try image!.jpegData(compressionQuality: 1.0)?.write(to: fileURL!);
        } catch {
            return self.sendError(error.localizedDescription, (capture?.callbackID)!);
        }

        let dict : Dictionary<String, Any> = [
            "url" : fileURL!.absoluteString
        ]
        let result = CDVPluginResult.init(status: CDVCommandStatus_OK, messageAs: dict);

        if (!self.imageAutoSave) { return self.commandDelegate.send(result, callbackId: capture?.callbackID); }

        // save to library!
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image!);
        }) { saved, error in
            if(!saved){ return self.sendError(error?.localizedDescription ?? "Unable to save to photo library", (capture?.callbackID)!); }
            return self.commandDelegate.send(result, callbackId:capture?.callbackID);
        }

        self.commandDelegate.send(result, callbackId: capture?.callbackID);
    }
    
    // MARK: - Util functions
    func isSessionRunning() -> Bool
    {
        return (videoSession != nil && videoSession!.isRunning);
    }

    func isVideoRecording() -> Bool
    {
        return videoRecording != nil && videoRecording!.isRecording;
    }

    func findPreviewOrientation() -> AVCaptureVideoOrientation
    {
        if(previewUseDeviceOrientation){ return getDeviceOriented(); }
        return getStatusBarOriented();
    }

    func findVideoRecordingOrientation() -> AVCaptureVideoOrientation
    {
        if(videoRecordingUseDeviceOrientation){ return getDeviceOriented(); }
        return getStatusBarOriented();
    }
    
    func findImageOrientation() -> AVCaptureVideoOrientation
    {
        if(imageFixOrientation){ return getDeviceOriented(); }
        return getStatusBarOriented();
    }

    func getDeviceOriented() -> AVCaptureVideoOrientation
    {
        switch UIDevice.current.orientation {
            case UIDeviceOrientation.landscapeLeft: return AVCaptureVideoOrientation.landscapeRight; //yes right on left :S
            case UIDeviceOrientation.landscapeRight: return AVCaptureVideoOrientation.landscapeLeft;
            case UIDeviceOrientation.portraitUpsideDown: return AVCaptureVideoOrientation.portraitUpsideDown;
            default: return AVCaptureVideoOrientation.portrait
        }
    }

    func getStatusBarOriented() -> AVCaptureVideoOrientation
    {
        switch UIApplication.shared.statusBarOrientation {
            case UIInterfaceOrientation.landscapeLeft: return AVCaptureVideoOrientation.landscapeLeft
            case UIInterfaceOrientation.landscapeRight: return AVCaptureVideoOrientation.landscapeRight
            case UIInterfaceOrientation.portraitUpsideDown: return AVCaptureVideoOrientation.portraitUpsideDown
            default: return AVCaptureVideoOrientation.portrait;
        }
    }

    func reset(){
    }

    func sendError(_ message : String, _ callbackID : String){
        return commandDelegate.send(CDVPluginResult.init(status: CDVCommandStatus_ERROR, messageAs: message), callbackId: callbackID);
    }

    // MARK: - Permission / device poll methods
    func isFrontCameraAvailable() -> Bool
    {
        return UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.front);
    }

    func isRearCameraAvailable() -> Bool
    {
        return UIImagePickerController.isCameraDeviceAvailable(UIImagePickerController.CameraDevice.rear);
    }

//
//    // MARK: - AVCaptureFileOutputRecordingDelegate
//    func capture(_ captureOutput: AVCaptureFileOutput!, didStartRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!) {
//        print("KloekVideoCapture.capture(start)");
//
//        let capture : KloekCaptureMovieFileOutput? = captureOutput as? KloekCaptureMovieFileOutput;
//        if (capture == nil) { return; } //invalid capture
//
//        let dict : Dictionary<String, Any> = [
//            "evt": "didStartRecording",
//            "file": [
//                "url" : fileURL.absoluteString
//            ]
//        ]
//        let result = CDVPluginResult.init(status: CDVCommandStatus_OK, messageAs: dict);
//        result?.keepCallback = true;
//        commandDelegate.send(result, callbackId: capture?.callbackID);
//    }

//    func capture(_ captureOutput: AVCaptureFileOutput!, didFinishRecordingToOutputFileAt fileURL: URL!, fromConnections connections: [Any]!, error: Error!) {
//        print("KloekVideoCapture.capture(finish)");
//        let capture : KloekCaptureMovieFileOutput? = captureOutput as? KloekCaptureMovieFileOutput;
//        if(capture == nil){ return; } //invalid capture
//
//        let dict : Dictionary<String, Any> = [
//            "evt": "didFinishRecording",
//            "file": [
//                "url" : fileURL.absoluteString
//            ]
//        ]
//        let result = CDVPluginResult.init(status: CDVCommandStatus_OK, messageAs: dict);
//
//        if(!videoRecordingAutoSave){ return commandDelegate.send(result, callbackId: capture?.callbackID); }
//
//        //save to library!
//        PHPhotoLibrary.shared().performChanges({
//            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
//        }) { saved, error in
//            if(!saved){ return self.sendError(error?.localizedDescription ?? "Unable to save to photo library", capture!.callbackID!); }
//            return self.commandDelegate.send(result, callbackId: capture?.callbackID);
//        }
//    }
    
//    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
//        print("KloekVideoCapture.fileOutput()");
//
//        // TODO
//        let capture : KloekCaptureFileOutput? = output as? KloekCaptureFileOutput;
//        print("fileOutput....", outputFileURL);
//    }
//

    func fileOutput(_ captureOutput: AVCaptureFileOutput, didStartRecordingTo: URL, from: [AVCaptureConnection]) {
        
      print("KloekVideoCapture.fileOutput(start)");

      let capture : KloekCaptureMovieFileOutput? = captureOutput as? KloekCaptureMovieFileOutput;
      if (capture == nil) { return; } //invalid capture

      let dict : Dictionary<String, Any> = [
          "evt": "didStartRecording",
          "file": [
              "url" : didStartRecordingTo.absoluteString
          ]
      ]
      let result = CDVPluginResult.init(status: CDVCommandStatus_OK, messageAs: dict);
      result?.keepCallback = true;
      commandDelegate.send(result, callbackId: capture?.callbackID);
    
    }

    func fileOutput(_ captureOutput: AVCaptureFileOutput, didFinishRecordingTo: URL, from: [AVCaptureConnection], error: Error?) {
        print("KloekVideoCapture.fileOutput(finish)");

        let capture : KloekCaptureMovieFileOutput? = captureOutput as? KloekCaptureMovieFileOutput;
        if(capture == nil){ return; } //invalid capture

        let dict : Dictionary<String, Any> = [
          "evt": "didFinishRecording",
          "file": [
              "url" : didFinishRecordingTo.absoluteString
          ]
        ]
        let result = CDVPluginResult.init(status: CDVCommandStatus_OK, messageAs: dict);

        if(!videoRecordingAutoSave){ return commandDelegate.send(result, callbackId: capture?.callbackID); }

        //save to library!
        PHPhotoLibrary.shared().performChanges({
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: didFinishRecordingTo)
        }) { saved, error in
          if(!saved){ return self.sendError(error?.localizedDescription ?? "Unable to save to photo library", (capture?.callbackID)!); }
          return self.commandDelegate.send(result, callbackId: capture?.callbackID);
        }
    
    }  
}
