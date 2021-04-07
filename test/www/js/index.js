/*
* Licensed to the Apache Software Foundation (ASF) under one
* or more contributor license agreements.  See the NOTICE file
* distributed with this work for additional information
* regarding copyright ownership.  The ASF licenses this file
* to you under the Apache License, Version 2.0 (the
* "License"); you may not use this file except in compliance
* with the License.  You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing,
* software distributed under the License is distributed on an
* "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
* KIND, either express or implied.  See the License for the
* specific language governing permissions and limitations
* under the License.
*/
var app = {
  // Application Constructor
  initialize: function() {
    document.addEventListener('deviceready', this.onDeviceReady.bind(this), false);
  },

  // deviceready Event Handler
  //
  // Bind any cordova events here. Common events are:
  // 'pause', 'resume', etc.
  onDeviceReady: function() {
    this.receivedEvent('deviceready');
  },

  // Update DOM on a Received Event
  receivedEvent: function(id) {

    var ui = document.getElementById('ui');
    ui.setAttribute('style', 'display:block;')

    var pixiApp = this.pixiApp = new PIXI.Application(300, 200, { transparent: true });
    document.body.appendChild(pixiApp.view);

  },

  startVideoSession: function(){
    Kloek.video.startSession({
      //   // video: true,
      //   // audio: true,
      //   // quality: 'high',
      //   // preset: '1920x1080',
      //   camera: 'rear',
      // fullFramePhotos: true
    }, ()=>{
      console.log('session started')
    }, onError)

    return false;
  },

  stopVideoSession: function(){
    Kloek.video.stopSession(function(){
      console.log('capture session stopped!');
    }, onError)
    return false;
  },

  showVideoPreview: function(){
    Kloek.video.showPreview({
      rect: {
        x: 200, y:75, width:200, height:150,
      },
      gravity: 'resizeAspect',
      // useDeviceOrientation: false,
      fadeDuration: 2
    }, function(){
      console.log('preview should be visible');
    }, onError)
  },

  hideVidePreview: function(){
    Kloek.video.hidePreview({
      fadeDuration: 2
    }, function(){
      console.log('preview hidden');
    }, onError)
  },

  startVideoRecording(){
    var video = document.querySelector('video');
    if(video && video.parentNode) video.parentNode.removeChild(video);

    Kloek.video.startRecording({
      autoSave: false,
      duration: 3,
      // useDeviceOrientation: false,
      onStart: function(){
        console.log('recording has started')
      }
    }, function(file){
      console.log('video recording done');
      console.log(file);

      /*
      de pixi js library vindt direct inladen niet leuk, maar
      zelf de video laden en starten is geen probleem
      */

      var video = document.createElement('video');
      video.setAttribute('src', file.url);
      video.setAttribute('autoplay', '');
      video.setAttribute('webkit-playsinline', '');
      video.setAttribute('playsinline', '');
      video.setAttribute('loop', '');

      var body = document.querySelector('body');
      body.appendChild(video);

      var texture = app.texture = PIXI.Texture.fromVideo(video);

      // create a new Sprite using the video texture (yes it's that easy)
      var videoSprite = new PIXI.Sprite(texture);

      // Stetch the fullscreen
      videoSprite.width = app.pixiApp.renderer.width;
      videoSprite.height = app.pixiApp.renderer.height;

      app.pixiApp.stage.addChild(videoSprite);

    }, onError);
  },

  stopVideoRecording(){
    Kloek.video.stopRecording(function(){

    }, onError);
  },

  grabImage(){
    Kloek.video.grabImage({
      autoSave: true
    }, function(file){

      var img = document.createElement('img');
      img.src = file.url;

      document.querySelector('body').appendChild(img);

    }, onError);
  },

  startAudioSession(){
    Kloek.audio.startSession({
      // sampleRate: 44100,
      // numChannels: 1,
      reuseRecorder: true
    }, ()=>{
      console.log('session started')
    }, onError)

    return false;
  },

  stopAudioSession(){
    Kloek.audio.stopSession(function(){
      console.log('capture session stopped!');
    }, onError)
    return false;
  },

  startAudioRecording(){
    var audio = document.querySelector('audio');
    if(audio && audio.parentNode) audio.parentNode.removeChild(audio);

    Kloek.audio.startRecording({
      duration: 3,
      onStart: function(){
        console.log('recording has started')
      },
      onMetering: function(meters){
        console.log(meters);
      }
    }, function(file){
      console.log('audio recording done');
      console.log(file);

      var audio = document.createElement('audio');
      audio.setAttribute('src', file.url);
      audio.setAttribute('autoplay', '');
      audio.setAttribute('webkit-playsinline', '');
      audio.setAttribute('playsinline', '');
      audio.setAttribute('loop', '');
      audio.setAttribute('controls', '');

      var body = document.querySelector('body');
      body.appendChild(audio);

    }, onError);
    return false;
  },

  stopAudioRecording(){
    Kloek.audio.stopRecording(function(){

    }, onError);
    return false;
  }
};

app.initialize();

var onError = function(err){
  console.log('Error: %s', err);
}
