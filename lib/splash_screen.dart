import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animal_warfare/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;
  
  // Flag to ensure pre-caching runs only once
  bool _assetsPrecached = false; 

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _opacityAnimation = Tween(begin: 0.0, end: 1.0).animate(_animationController);

    // Set the app to full-screen mode for a game look
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: []);
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

      // The custom font ('PressStart2P') is loaded globally via ThemeData, 
      // but if you had other specific assets, you'd cache them here too.
      
      _assetsPrecached = true;
    }
  }

  // Navigate to the next screen (e.g., your main game menu)
  void _navigateToMainScreen() {
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
    _animationController.dispose();
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
            // We use a Builder to ensure the Image is loaded after precacheImage
            Image.asset(
              'assets/background.png',
              fit: BoxFit.cover,
              // Use a small FadeInImage effect for a smoother transition
              // This is often not needed with precacheImage, but is a good fallback
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
                        // No need for explicit fontFamily here as it's set in the global theme, 
                        // but keeping it explicit for clarity if the theme is overridden later.
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
                'V 1.0.0', // Replace with a dynamic version number later
                style: TextStyle(
                  // Using Theme text style, ensuring the PressStart2P font is applied
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
