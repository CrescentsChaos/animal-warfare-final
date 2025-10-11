import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:audioplayers/audioplayers.dart'; 
// REMOVED: import 'package:animal_warfare/utils/transitions.dart'; 

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  
  // NEW: Declare the audio player instance
  late AudioPlayer _audioPlayer;
  // NEW: Flag to track if the audio was playing before pause
  bool _wasPlayingBeforePause = false;
  
  // Flag to ensure pre-caching runs only once
  bool _assetsPrecached = false; 

  @override
  void initState() {
    super.initState();
    // NEW: Register the observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this); 
    
    // 🚨 MODIFIED: Set the screen to Immersive/Full-screen mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // NEW: Initialize Audio Player and start music
    _audioPlayer = AudioPlayer();
    _playBackgroundMusic();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _opacityAnimation = Tween(begin: 0.0, end: 1.0).animate(_animationController);
    
    // Listen for the first frame to precache assets
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAssets();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      final playerState = await _audioPlayer.state;
      if (playerState == PlayerState.playing) {
        _wasPlayingBeforePause = true;
        await _audioPlayer.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        // 🚨 EDITED: Re-apply immersive mode on resume, as system might have restored UI
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        await _audioPlayer.resume();
        _wasPlayingBeforePause = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }
  
  Future<void> _playBackgroundMusic() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('audio/rainforest_theme.mp3'));
  }
  
  // Precache all necessary images and JSON data
  Future<void> _precacheAssets() async {
    if (_assetsPrecached) return;

    final BuildContext? currentContext = context;
    if (currentContext == null) return;
    
    // 1. Precache main assets
    await precacheImage(const AssetImage('assets/taiga-bg.png'), currentContext);
    await precacheImage(const AssetImage('assets/logo.png'), currentContext);
    
    // 2. Precache other common assets (add any other images used in the first few screens)
    // Example: await precacheImage(const AssetImage('assets/default_avatar.png'), currentContext);

    // 3. Load and cache JSON data (Optional, for very fast access)
    // await rootBundle.loadString('assets/data/organisms.json');
    
    _assetsPrecached = true;
  }

  void _navigateToMain() {
    // 🚨 MODIFIED: Revert to default System UI visibility before navigating
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    // Stop and immediately dispose of the audio player
    _audioPlayer.stop();
    _audioPlayer.dispose();
    
    // ✅ FIX: Use the custom _createFadeRoute for a smooth, fade-in transition
    Navigator.of(context).pushReplacement(
        _createFadeRoute(const MainScreen()), // <--- Use the custom route here!
    );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _navigateToMain,
        child: Stack(
          children: [
            // 1. Background Image
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                image: DecorationImage(
                  image: const AssetImage('assets/biomes/rainforest-bg.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.7),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),

            // 2. Center Content (Logo and Tap to Continue)
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
PageRouteBuilder _createFadeRoute(Widget page) {
  return PageRouteBuilder(
    // Reduce duration for a snappier feel
    transitionDuration: const Duration(milliseconds: 300), 
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}