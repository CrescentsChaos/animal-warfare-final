import 'package:flutter/material.dart';
import 'package:animal_warfare/quiz_game_screen.dart'; // Ensure this path is correct
import 'package:animal_warfare/local_auth_service.dart';

class QuizScreen extends StatelessWidget {
  final UserData currentUser;
  final LocalAuthService authService;
  const QuizScreen({super.key, required this.currentUser,required this.authService,});

  // Custom retro/military colors (Copied from GameScreen for consistency)
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod
  static const Color secondaryButtonColor = Color(0xFF8B0000); // Red/Maroon
  // NEW: A third color for the new game modes
  static const Color tertiaryButtonColor = Color(0xFFFFA500); // Orange/Yellow

  // Helper method for themed buttons (Adapted for use here)
  Widget _buildThemedButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: highlightColor, width: 2.0),
        borderRadius: BorderRadius.circular(8.0), 
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 5.0,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: highlightColor, size: 30),
                Expanded(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'PressStart2P',
                      fontSize: 14,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: highlightColor, size: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // FIX: Helper method to navigate to QuizGameScreen, now passing required arguments
  void _navigateToQuizGame(BuildContext context, QuizType quizType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizGameScreen(
          quizType: quizType,
          currentUser: currentUser,      // <-- ADDED required argument
          authService: authService,      // <-- ADDED required argument
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WARFARE TRAINING'),
        backgroundColor: primaryButtonColor,
        titleTextStyle: const TextStyle(color: highlightColor, fontFamily: 'PressStart2P', fontSize: 18),
      ),
      body: Container(
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Text(
                'SELECT TRAINING MODE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: highlightColor,
                  fontFamily: 'PressStart2P',
                  fontSize: 16,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(2, 2))
                  ]
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Game One Button (Scientific Name to Common Name)
                    _buildThemedButton(
                      text: 'SCIENTIFIC TO COMMON',
                      icon: Icons.science,
                      onPressed: () => _navigateToQuizGame(context, QuizType.scientificToCommon),
                      color: primaryButtonColor, // Green
                    ),

                    // Game Two Button (Common Name to Scientific Name)
                    _buildThemedButton(
                      text: 'COMMON TO SCIENTIFIC',
                      icon: Icons.sort_by_alpha,
                      onPressed: () => _navigateToQuizGame(context, QuizType.commonToScientific),
                      color: secondaryButtonColor, // Red/Maroon
                    ),
                    
                    // NEW Game Three Button (Sprite to Common Name)
                    _buildThemedButton(
                      text: 'SPRITE TO NAME',
                      icon: Icons.image,
                      onPressed: () => _navigateToQuizGame(context, QuizType.spriteToName),
                      color: tertiaryButtonColor, // Orange/Yellow
                    ),
                    
                    // NEW Game Four Button (Sprite to Scientific Name)
                    _buildThemedButton(
                      text: 'SPRITE TO SCIENTIFIC',
                      icon: Icons.image_search,
                      onPressed: () => _navigateToQuizGame(context, QuizType.spriteToScientific),
                      color: primaryButtonColor.withOpacity(0.7), // Re-use Green, slightly darker
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}