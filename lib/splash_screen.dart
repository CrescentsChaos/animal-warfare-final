import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  bool _assetsPrecached = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _playBackgroundMusic();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _opacityAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _precacheAssets();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _playBackgroundMusic() {
    AudioService.instance.playMusic('audio/rainforest_theme.mp3');
  }

  Future<void> _precacheAssets() async {
    if (_assetsPrecached) return;
    final BuildContext currentContext = context;
    await precacheImage(
      const AssetImage('assets/biomes/rainforest-bg.png'),
      currentContext,
    );
    await precacheImage(const AssetImage('assets/logo.png'), currentContext);
    _assetsPrecached = true;
  }

  void _navigateToMain() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    Navigator.of(context).pushReplacement(_createFadeRoute(const MainScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: _navigateToMain,
        child: Stack(
          children: [
            // Background
            Container(
              decoration: BoxDecoration(
                color: AppColors.background,
                image: DecorationImage(
                  image: const AssetImage('assets/biomes/rainforest-bg.png'),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.65),
                    BlendMode.darken,
                  ),
                ),
              ),
            ),

            // Center content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Logo with glow
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 260,
                      height: 260,
                    ),
                  ),
                  const SizedBox(height: 80),

                  // "TAP TO CONTINUE" with gold highlight
                  FadeTransition(
                    opacity: _opacityAnimation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.highlight.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Text(
                        'TAP TO CONTINUE',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.highlight,
                          fontFamily: 'PressStart2P',
                          letterSpacing: 2,
                          shadows: [
                            Shadow(
                              color: AppColors.highlight,
                              blurRadius: 8,
                              offset: Offset(0, 0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Version tag
            Positioned(
              right: 16,
              bottom: 16,
              child: Text(
                'V 0.1.1',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontFamily: 'PressStart2P',
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
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
