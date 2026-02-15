// lib/services/audio_service.dart
import 'package:audioplayers/audioplayers.dart';

/// Service for managing game audio including sound effects and background music
class AudioService {
  // Separate players for music and sound effects
  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _soundPlayer = AudioPlayer();

  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  String? _currentMusicPath;

  AudioService() {
    // Set music player to loop by default
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
    // Sound effects should play once
    _soundPlayer.setReleaseMode(ReleaseMode.release);
  }

  /// Play a sound effect once
  Future<void> playSound(String assetPath) async {
    if (!_isSoundEnabled) return;

    try {
      await _soundPlayer.stop();
      await _soundPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  /// Play background music with looping
  Future<void> playMusic(String assetPath, {bool loop = true}) async {
    if (!_isMusicEnabled) return;

    // Don't restart if already playing the same music
    if (_currentMusicPath == assetPath) return;

    try {
      await _musicPlayer.stop();
      _currentMusicPath = assetPath;

      if (loop) {
        _musicPlayer.setReleaseMode(ReleaseMode.loop);
      } else {
        _musicPlayer.setReleaseMode(ReleaseMode.release);
      }

      await _musicPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing music: $e');
    }
  }

  /// Stop the current background music
  Future<void> stopMusic() async {
    try {
      await _musicPlayer.stop();
      _currentMusicPath = null;
    } catch (e) {
      print('Error stopping music: $e');
    }
  }

  /// Set music volume (0.0 to 1.0)
  Future<void> setMusicVolume(double volume) async {
    await _musicPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Set sound effects volume (0.0 to 1.0)
  Future<void> setSoundVolume(double volume) async {
    await _soundPlayer.setVolume(volume.clamp(0.0, 1.0));
  }

  /// Enable/disable music
  void setMusicEnabled(bool enabled) {
    _isMusicEnabled = enabled;
    if (!enabled) {
      stopMusic();
    }
  }

  /// Enable/disable sound effects
  void setSoundEnabled(bool enabled) {
    _isSoundEnabled = enabled;
  }

  /// Get the default sound effect path based on move category
  String getDefaultSoundEffect(String category) {
    switch (category.toLowerCase()) {
      case 'physical':
        return 'audio/effects/physical_attack.mp3';
      case 'special':
        return 'audio/effects/special_attack.mp3';
      case 'status':
        return 'audio/effects/status_move.mp3';
      default:
        return 'audio/effects/physical_attack.mp3';
    }
  }

  /// Pause all audio (useful when app goes to background)
  Future<void> pauseAll() async {
    try {
      await _musicPlayer.pause();
      await _soundPlayer.pause();
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }

  /// Resume audio (useful when app returns to foreground)
  Future<void> resumeAll() async {
    try {
      await _musicPlayer.resume();
      // Don't resume sound effects - they're one-shot
    } catch (e) {
      print('Error resuming audio: $e');
    }
  }

  /// Dispose of audio players when no longer needed
  Future<void> dispose() async {
    await _musicPlayer.dispose();
    await _soundPlayer.dispose();
  }
}
