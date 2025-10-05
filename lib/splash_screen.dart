import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:audioplayers/audioplayers.dart'; // ⬅️ NEW: Import the audio package

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// ⬅️ UPDATED: Add WidgetsBindingObserver mixin
class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  
  // ⬅️ NEW: Declare the audio player instance
  late AudioPlayer _audioPlayer;
  // ⬅️ NEW: Flag to track if the audio was playing before pause
  bool _wasPlayingBeforePause = false;
  
  // Flag to ensure pre-caching runs only once
  bool _assetsPrecached = false; 

  @override
  void initState() {
    super.initState();
    // ⬅️ NEW: Register the observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this); 
    
    // ⬅️ NEW: Initialize Audio Player and start music
    _audioPlayer = AudioPlayer();
    _playBackgroundMusic();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _opacityAnimation = Tween(begin: 0.0, end: 1.0).animate(_animationController);

    // Set the app to full-screen mode for a game look
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
  }
  
  // ⬅️ NEW: Override to handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      final isPlaying = await _audioPlayer.state == PlayerState.playing;
      _wasPlayingBeforePause = isPlaying;
      if (isPlaying) {
        await _audioPlayer.pause(); 
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        await _audioPlayer.resume();
      }
    }
  }
  
  // ⬅️ NEW: Function to play music in a loop
  void _playBackgroundMusic() async {
    _wasPlayingBeforePause = true; // Assume playback starts
    // Set a moderate volume (e.g., 50%) for background music
    await _audioPlayer.setVolume(0.5); 
    
    // Set the release mode to loop indefinitely 
    await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
    
    // Start playing the music asset
    try {
      await _audioPlayer.play(AssetSource('audio/splash_theme.mp3'));
    } catch (e) {
      // Handle the case where the file is not found or cannot be played
      debugPrint('Could not play audio: $e');
    }
  }

  // Use didChangeDependencies to safely run asset pre-caching
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Check if assets have been precached already
    if (!_assetsPrecached) {
      // 1. Pre-cache the background image
      precacheImage(const AssetImage('assets/background.png'), context);
      
      // 2. Pre-cache the logo image
      precacheImage(const AssetImage('assets/logo.png'), context);
      
      _assetsPrecached = true;
    }
  }

  // Navigate to the next screen (e.g., your main game menu)
  void _navigateToMainScreen() {
    // ⬅️ NEW: Stop and dispose of the audio player immediately before navigating
    _audioPlayer.stop();
    _audioPlayer.dispose();
    
    // Restore system UI overlays (status bar, navigation bar)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainScreen(),
      ),
    );
  }

  @override
  void dispose() {
    // ⬅️ NEW: Remove the observer before disposing
    WidgetsBinding.instance.removeObserver(this); 
    _animationController.dispose();
    // ⬅️ NEW: Just in case the player wasn't disposed during navigation, do it here too
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrap the entire screen in a GestureDetector so tapping anywhere works
    return GestureDetector(
      onTap: _navigateToMainScreen,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 1. Background Image
            Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return child;
                }
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  child: child,
                );
              },
            ),

            // 2. Main Content (Logo and Tap to Continue)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Logo
                  Image.asset(
                    'assets/logo.png',
                    width: 300, 
                    height: 300,
                  ),
                  const SizedBox(height: 80),

                  // Flickering "Tap to Continue" Text
                  FadeTransition(
                    opacity: _opacityAnimation,
                    child: const Text(
                      'TAP TO CONTINUE',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 2,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. App Version in the bottom right corner
            Positioned(
              right: 16,
              bottom: 16,
              child: Text(
                'V 0.0.1', // Replace with a dynamic version number later
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}