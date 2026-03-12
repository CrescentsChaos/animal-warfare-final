import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing game audio including sound effects and background music
class AudioService {
  static final AudioService instance = AudioService._internal();
  static bool isTesting = false;

  AudioService._internal() {
    if (!isTesting) {
      _musicPlayer = AudioPlayer();
      _soundPlayer = AudioPlayer();
    }
  }

  // Separate players for music and sound effects
  late final AudioPlayer _musicPlayer;
  late final AudioPlayer _soundPlayer;

  bool _isMusicEnabled = true;
  bool _isSoundEnabled = true;
  double _musicVolume = 1.0;
  double _soundVolume = 1.0;
  String? _currentMusicPath;
  bool _isInitialized = false;
  SharedPreferences? _prefs;

  bool get isMusicEnabled => _isMusicEnabled;
  bool get isSoundEnabled => _isSoundEnabled;
  double get musicVolume => _musicVolume;
  double get soundVolume => _soundVolume;
  bool get isInitialized => _isInitialized;

  /// Initialize settings from SharedPreferences
  Future<void> init() async {
    if (_isInitialized || isTesting) return;

    _prefs = await SharedPreferences.getInstance();
    _isMusicEnabled = _prefs?.getBool('isMusicEnabled') ?? true;
    _isSoundEnabled = _prefs?.getBool('isSoundEnabled') ?? true;
    _musicVolume = _prefs?.getDouble('musicVolume') ?? 1.0;
    _soundVolume = _prefs?.getDouble('soundVolume') ?? 1.0;

    // Context for background music: Requests audio focus
    final musicContext = AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    );

    // Context for sound effects: Does NOT request audio focus, allowing it to mix
    final sfxContext = AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none, // Key Fix: Don't interrupt music
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    );

    // Apply specific contexts to each player
    await _musicPlayer.setAudioContext(musicContext);
    await _soundPlayer.setAudioContext(sfxContext);

    // Set music player to loop by default
    _musicPlayer.setReleaseMode(ReleaseMode.loop);
    await _musicPlayer
        .setVolume(_isMusicEnabled ? _musicVolume : 0.0)
        .catchError((e) => print('Error setting initial music volume: $e'));

    // Sound effects should play once
    _soundPlayer.setReleaseMode(ReleaseMode.release);
    await _soundPlayer
        .setVolume(_isSoundEnabled ? _soundVolume : 0.0)
        .catchError((e) => print('Error setting initial sound volume: $e'));

    _isInitialized = true;
  }

  /// Play a sound effect once
  Future<void> playSound(String assetPath) async {
    if (isTesting) return;
    try {
      // Volume is controlled separately via _soundVolume and _isSoundEnabled
      // When disabled, volume is set to 0.0, so we don't need an early return here
      await _soundPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing sound: $e');
    }
  }

  /// Play an organism's cry
  Future<void> playOrganismCry(String cryName) async {
    if (isTesting) return;
    try {
      // Path construction: assets/audio/cries/ + cryName + .mp3
      await playSound('audio/cries/$cryName.mp3');
    } catch (e) {
      print('Error playing organism cry: $e');
    }
  }

  /// Play background music with looping
  Future<void> playMusic(String assetPath, {bool loop = true}) async {
    if (isTesting) return;

    // Ensure volume is reset to current music volume setting (it might have been faded out)
    await _musicPlayer.setVolume(_isMusicEnabled ? _musicVolume : 0.0);

    // If already playing this track, don't restart it (avoids stuttering)
    if (_currentMusicPath == assetPath &&
        (_musicPlayer.state == PlayerState.playing ||
            _musicPlayer.state == PlayerState.paused)) {
      if (_musicPlayer.state == PlayerState.paused) {
        await _musicPlayer.resume();
      }
      return;
    }

    _currentMusicPath = assetPath;

    try {
      if (loop) {
        await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      } else {
        await _musicPlayer.setReleaseMode(ReleaseMode.release);
      }
    } catch (e) {
      print('Error setting release mode: $e');
    }

    if (!_isMusicEnabled) return;

    try {
      await _musicPlayer.play(AssetSource(assetPath));
    } catch (e) {
      print('Error playing music: $e');
    }
  }

  /// Stop the current background music
  Future<void> stopMusic() async {
    if (isTesting) return;
    try {
      await _musicPlayer.stop();
      _currentMusicPath = null;
    } catch (e) {
      print('Error stopping music: $e');
    }
  }

  /// Fade out the current music smoothly
  Future<void> fadeOutMusic({
    Duration duration = const Duration(milliseconds: 1500),
  }) async {
    if (isTesting || _musicPlayer.state != PlayerState.playing) return;

    final int steps = 15;
    final double stepVolume = _musicVolume / steps;
    final Duration stepDuration = Duration(
      milliseconds: duration.inMilliseconds ~/ steps,
    );

    for (int i = steps; i >= 0; i--) {
      try {
        await _musicPlayer.setVolume(i * stepVolume);
      } catch (e) {
        print('Error during music fade out: $e');
        break;
      }
      await Future.delayed(stepDuration);
    }

    await stopMusic();
  }

  /// Set music volume (0.0 to 1.0)
  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    if (_isMusicEnabled) {
      try {
        await _musicPlayer.setVolume(_musicVolume);
      } catch (e) {
        print('Error setting music volume: $e');
      }
    }
    // Async save, don't await to avoid stalling UI
    _prefs?.setDouble('musicVolume', _musicVolume);
  }

  /// Set sound effects volume (0.0 to 1.0)
  Future<void> setSoundVolume(double volume) async {
    _soundVolume = volume.clamp(0.0, 1.0);
    if (_isSoundEnabled) {
      try {
        await _soundPlayer.setVolume(_soundVolume);
      } catch (e) {
        print('Error setting sound volume: $e');
      }
    }
    // Async save, don't await
    _prefs?.setDouble('soundVolume', _soundVolume);
  }

  /// Enable/disable music
  Future<void> setMusicEnabled(bool enabled) async {
    _isMusicEnabled = enabled;
    try {
      if (!enabled) {
        await _musicPlayer.setVolume(0.0);
      } else {
        await _musicPlayer.setVolume(_musicVolume);
        if (_currentMusicPath != null &&
            _musicPlayer.state != PlayerState.playing) {
          await playMusic(_currentMusicPath!);
        }
      }
    } catch (e) {
      print('Error toggling music: $e');
    }
    _prefs?.setBool('isMusicEnabled', _isMusicEnabled);
  }

  /// Enable/disable sound effects
  Future<void> setSoundEnabled(bool enabled) async {
    _isSoundEnabled = enabled;
    try {
      if (!enabled) {
        await _soundPlayer.setVolume(0.0);
      } else {
        await _soundPlayer.setVolume(_soundVolume);
      }
    } catch (e) {
      print('Error toggling sound: $e');
    }
    _prefs?.setBool('isSoundEnabled', _isSoundEnabled);
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
      if (_musicPlayer.state != PlayerState.stopped) {
        await _musicPlayer.pause();
      }
      if (_soundPlayer.state != PlayerState.stopped) {
        await _soundPlayer.pause();
      }
    } catch (e) {
      print('Error pausing audio: $e');
    }
  }

  /// Resume audio (useful when app returns to foreground)
  Future<void> resumeAll() async {
    if (!_isMusicEnabled || _currentMusicPath == null) return;
    try {
      if (_musicPlayer.state == PlayerState.paused) {
        await _musicPlayer.resume();
      } else if (_musicPlayer.state == PlayerState.stopped ||
          _musicPlayer.state == PlayerState.completed) {
        if (_musicPlayer.state != PlayerState.playing) {
          await playMusic(_currentMusicPath!);
        }
      }
    } catch (e) {
      print('Error resuming audio: $e');
    }
  }

  /// Stop all audio
  Future<void> stopAll() async {
    try {
      await _musicPlayer.stop();
      await _soundPlayer.stop();
      _currentMusicPath = null;
    } catch (e) {
      print('Error stopping all audio: $e');
    }
  }

  /// Dispose of audio players when no longer needed
  /// Note: The global instance should generally not be disposed.
  Future<void> dispose() async {
    try {
      await _musicPlayer.dispose();
      await _soundPlayer.dispose();
    } catch (e) {
      print('Error disposing audio players: $e');
    }
  }
}
