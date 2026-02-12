// lib/audio_manager.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioManager {
  static final AudioManager instance = AudioManager._internal();
  AudioManager._internal();

  final AudioPlayer _player = AudioPlayer();
  String? _currentAsset;
  bool _isPausedBySystem = false;
  bool _shouldBePlaying = false;

  Future<void> playBackgroundMusic(String asset) async {
    if (_currentAsset == asset && _shouldBePlaying) return;
    
    _currentAsset = asset;
    _shouldBePlaying = true;
    
    try {
      await _player.stop();
      await _player.setSourceAsset(asset);
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.resume();
    } catch (e) {
      debugPrint('AudioManager Error: $e');
    }
  }

  void pause() {
    _shouldBePlaying = false;
    _player.pause();
  }

  void resume() {
    _shouldBePlaying = true;
    _player.resume();
  }

  void stop() {
    _shouldBePlaying = false;
    _currentAsset = null;
    _player.stop();
  }

  void handleLifecycleChange(bool isBackground) {
    if (isBackground) {
      if (_shouldBePlaying) {
        _player.pause();
        _isPausedBySystem = true;
      }
    } else {
      if (_isPausedBySystem) {
        _player.resume();
        _isPausedBySystem = false;
      }
    }
  }

  void dispose() {
    _player.dispose();
  }
}
