import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:animal_warfare/utils/transitions.dart'; // ⬅️ NEW: Import transitions utility

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

    // Pre-cache images after the first build cycle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAssets();
    });
  }

  // ⬅️ NEW: Override to handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _pauseMusic(true);
    } else if (state == AppLifecycleState.resumed) {
      _resumeMusic();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _audioPlayer.dispose(); 
    super.dispose();
  }
  
  // ⬅️ NEW: Audio control methods
  Future<void> _playBackgroundMusic() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('audio/splash_theme.mp3')); 
  }

  void _pauseMusic(bool rememberState) async {
    if (rememberState) {
      final state = await _audioPlayer.state;
      _wasPlayingBeforePause = state == PlayerState.playing;
    }
    await _audioPlayer.pause();
  }

  void _resumeMusic() async {
    if (_wasPlayingBeforePause) {
      await _audioPlayer.resume();
      _wasPlayingBeforePause = false;
    }
  }

  // Pre-cache all necessary assets to prevent lag during the first render
  void _precacheAssets() {
    if (_assetsPrecached) return;
    
    // Main Logo
    precacheImage(const AssetImage('assets/logo.png'), context);
    // Background Image
    precacheImage(const AssetImage('assets/main.png'), context);
    // Cloud transition image
    precacheImage(const AssetImage('assets/cloud_transition.png'), context); 
    
    _assetsPrecached = true;
  }
  
  // ⬅️ UPDATED: Use the cloud transition route
  void _navigateToMainScreen() {
    if (mounted) {
      Navigator.of(context).pushReplacement(
        createCloudTransitionRoute(const MainScreen()), // ⬅️ Use the Cloud Transition!
      );
      _audioPlayer.stop(); // Stop the splash music
    }
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI to be fully immersive (hides status/nav bars)
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      body: GestureDetector(
        onTap: _navigateToMainScreen,
        child: Stack(
          children: [
            // 1. Background Image
            Positioned.fill(
              child: Image.asset(
                'assets/background.png', 
                fit: BoxFit.cover,
                // Apply a mild overlay to ensure text visibility
                color: Colors.black.withOpacity(0.5), 
                colorBlendMode: BlendMode.darken,
              ),
            ),
            
            // 2. Centered Content (Logo and Text)
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
