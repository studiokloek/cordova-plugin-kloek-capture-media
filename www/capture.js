var exec = require('cordova/exec');

function startVideoSession(options, successCallback, errorCallback){
  run("KloekVideoCapture", "startCaptureSession", successCallback, errorCallback, options);
}

function stopVideoSession(options, successCallback, errorCallback){
  run("KloekVideoCapture", "stopCaptureSession", successCallback, errorCallback, options);
}

function showVideoPreview(options, successCallback, errorCallback){
  run("KloekVideoCapture", "showPreview", successCallback, errorCallback, options);
}

function hideVideoPreview(options, successCallback, errorCallback){
    run("KloekVideoCapture", "hidePreview", successCallback, errorCallback, options);
  }

function startVideoRecording(options, successCallback, errorCallback){
  run("KloekVideoCapture", "startVideoRecording", function(result){
    if(result.evt=='didStartRecording' && options.onStart) return options.onStart(result.file);
    if(result.evt=='didFinishRecording') return successCallback(result.file);
  }, errorCallback, options);
}

function stopVideoRecording(options, successCallback, errorCallback){
  run("KloekVideoCapture", "stopVideoRecording", successCallback, errorCallback, options);
}

function grabImage(options, successCallback, errorCallback){
  run("KloekVideoCapture", "grabImage", successCallback, errorCallback, options);
}


function startAudioSession(options, successCallback, errorCallback){
  run("KloekAudioCapture", "startCaptureSession", successCallback, errorCallback, options);
}

function stopAudioSession(options, successCallback, errorCallback){
  run("KloekAudioCapture", "stopCaptureSession", successCallback, errorCallback, options);
}

function startAudioRecording(options, successCallback, errorCallback){
  run("KloekAudioCapture", "startAudioRecording", function(result){
    if(result.evt=='didStartRecording' && options.onStart) return options.onStart(result.file);
    if(result.evt=='metering' && options.onMetering) return options.onMetering(result.metering);
    if(result.evt=='didFinishRecording') return successCallback(result.file);
  }, errorCallback, options);
}

function stopAudioRecording(options, successCallback, errorCallback){
  run("KloekAudioCapture", "stopAudioRecording", successCallback, errorCallback, options);
}


function run(service, action, ssc, ecb, opts){
  //fallback if a options object is forgotten
  if(typeof opts == 'function'){
    if(!ssc || (typeof ssc == 'function' && !ecb)){
      ecb = ssc;
      ssc = opts;
      opts = {};
    }
  }

  exec(ssc, ecb, service, action, [opts||{}]);
}

var Kloek = {
  video: {
    startSession: startVideoSession,
    stopSession: stopVideoSession,
    showPreview: showVideoPreview,
    hidePreview: hideVideoPreview,
    startRecording: startVideoRecording,
    stopRecording: stopVideoRecording,
    grabImage: grabImage
  },
  audio: {
    startSession: startAudioSession,
    stopSession: stopAudioSession,
    startRecording: startAudioRecording,
    stopRecording: stopAudioRecording
  }
}

module.exports = Kloek;
