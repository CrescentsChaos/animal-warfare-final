// lib/game_screen.dart
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:animal_warfare/explore_screen.dart'; 
import 'package:animal_warfare/anidex_screen.dart'; 
import 'package:animal_warfare/quiz_screen.dart'; 
import 'package:animal_warfare/local_auth_service.dart';
 // Import service

class GameScreen extends StatefulWidget {
  // FIX: ADDED: Required fields to pass down user data and service
  final UserData currentUser; 
  final LocalAuthService authService;

  const GameScreen({
    super.key,
    required this.currentUser, // ADDED
    required this.authService, // ADDED
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late AudioPlayer _audioPlayer;

  // Define High-Contrast Retro/Military-themed colors (Copied from main_screen for consistency)
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color tertiaryButtonColor = Color(0xFF8B0000); // Deep Red/Maroon
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod (Text/Border Highlight)

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playBackgroundMusic();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  void _playBackgroundMusic() async {
    // ... (music playback logic remains the same)
    try {
      await _audioPlayer.setSourceAsset('audio/main_theme.mp3');
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.resume();
    } catch (e) {
      // Handle error if music file is missing
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warning: Could not play game screen music.')),
        );
      }
    }
  }
  
  // Navigation function to pass UserData and LocalAuthService
  void _navigateTo(Widget screen) {
    _audioPlayer.pause();
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 400),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    ).then((_) {
      // Resume music when returning
      _audioPlayer.resume(); 
    });
  }

  // Helper function for themed buttons
  Widget _buildThemedButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    // ... (button UI logic remains the same)
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: highlightColor, width: 2.0),
        borderRadius: BorderRadius.circular(4.0), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.6),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4.0),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: highlightColor, size: 20),
                const SizedBox(width: 10),
                Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'PressStart2P',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              color: secondaryButtonColor,
              image: DecorationImage(
                image: const AssetImage('assets/main.png'), 
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.7),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          
          Center(
            
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  
                  const Text(
                    'ANIMAL WARFARE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: highlightColor,
                      fontSize: 28,
                      fontFamily: 'PressStart2P',
                      height: 1.5,
                      shadows: [
                        Shadow(
                          color: Color(0xFF8B0000),
                          blurRadius: 5.0,
                          offset: Offset(2, 2)
                        )
                      ]
                    ),
                  ),
                  const SizedBox(height: 60),

                  // Explore Biome Button
                  _buildThemedButton(
                    text: 'EXPLORE BIOME',
                    icon: Icons.map,
                    // PASSING REQUIRED WIDGET PROPERTIES
                    onPressed: () => _navigateTo(ExploreScreen(
                      currentUser: widget.currentUser, 
                      authService: widget.authService,
                    )),
                    color: primaryButtonColor, 
                  ),

                  // Anidex Button
                  _buildThemedButton(
                    text: 'ANIMAL DEX',
                    icon: Icons.pets,
                    // PASSING REQUIRED WIDGET PROPERTIES
                    onPressed: () => _navigateTo(AnidexScreen(
                      currentUser: widget.currentUser,
                      authService: widget.authService,
                    )),
                    color: secondaryButtonColor, 
                  ), 
                  // Quiz Button
                  _buildThemedButton(  
                    text: 'BATTLE QUIZ',
                    icon: Icons.quiz,
                    // PASSING REQUIRED WIDGET PROPERTIES (Assuming QuizScreen needs them)
                    onPressed: () => _navigateTo(QuizScreen(
                      currentUser: widget.currentUser,
                      authService: widget.authService,
                    )),
                    color: tertiaryButtonColor, 
                  ),

                  const SizedBox(height: 40),
                  Text(
                    'Deployment Status: Standby',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.8),
                      fontFamily: 'PressStart2P',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}