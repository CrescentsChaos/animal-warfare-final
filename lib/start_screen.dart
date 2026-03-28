// lib/start_screen.dart
import 'package:flutter/material.dart';
import 'package:animal_warfare/splash_screen.dart';
import 'package:audioplayers/audioplayers.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Gentle 2s fade in
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    _initStartSequence();
  }

  Future<void> _initStartSequence() async {
    // Slight delay before anything happens
    await Future.delayed(const Duration(milliseconds: 500));

    // Start playing background start clip
    await _audioPlayer.play(AssetSource('audio/start.mp3'));

    // Gently fade the image in
    await _fadeController.forward();

    // Remain fully visible for 2.5 seconds
    await Future.delayed(const Duration(milliseconds: 2500));

    // Gently fade black again
    await _fadeController.reverse();

    if (mounted) {
      // Navigate to the splash screen
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 1000),
          pageBuilder: (_, _, _) => const SplashScreen(),
          transitionsBuilder: (_, animation, _, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.asset('assets/start.png', fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}
