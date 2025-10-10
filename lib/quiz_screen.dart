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
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  // NEW: A tertiary color for the sprite modes
  static const Color tertiaryButtonColor = Color(0xFF13281A); // Very Dark Forest Green
  // 🟢 NEW: A quaternary color for the silhouette modes
  static const Color quaternaryButtonColor = Color(0xFF674EA7); // A deep purple/indigo

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
        // Shadow effect for depth
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            offset: const Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: highlightColor),
        label: Text(
          text,
          style: const TextStyle(
            color: highlightColor,
            fontFamily: 'PressStart2P',
            fontSize: 14.0,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color, // Use the passed color as the base
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
            // The border is handled by the parent Container's Decoration for the full effect
          ),
          elevation: 0, // Remove default elevation as we use BoxDecoration for shadow
          foregroundColor: highlightColor,
        ),
      ),
    );
  }

  void _navigateToQuizGame(BuildContext context, QuizType quizType) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => QuizGameScreen(
          quizType: quizType,
          currentUser: currentUser,
          authService: authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Animal Warfare Quizzes'),
        backgroundColor: secondaryButtonColor, // Use deep forest green for app bar
        titleTextStyle: const TextStyle(
          color: highlightColor, 
          fontFamily: 'PressStart2P', 
          fontSize: 16.0,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: secondaryButtonColor,
          image: DecorationImage(
            image: const AssetImage('assets/biomes/savanna-bg.png'), 
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
                'Select a Quiz Mode',
                style: TextStyle(
                  color: highlightColor,
                  fontFamily: 'PressStart2P',
                  fontSize: 18.0,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(2, 2))
                  ]
                ),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Game One Button (Scientific Name to Common Name)
                    _buildThemedButton(
                      text: 'SCIENTIFIC TO NAME',
                      icon: Icons.science,
                      onPressed: () => _navigateToQuizGame(context, QuizType.scientificToCommon),
                      color: primaryButtonColor, // Bright Jungle Green
                    ),

                    // Game Two Button (Common Name to Scientific Name)
                    _buildThemedButton(
                      text: 'NAME TO SCIENTIFIC',
                      icon: Icons.sort_by_alpha,
                      onPressed: () => _navigateToQuizGame(context, QuizType.commonToScientific),
                      color: secondaryButtonColor,
                    ),
                    
                    // Game Three Button (Sprite to Common Name)
                    _buildThemedButton(
                      text: 'SPRITE TO NAME', 
                      icon: Icons.image,
                      onPressed: () => _navigateToQuizGame(context, QuizType.spriteToName),
                      color: tertiaryButtonColor, 
                    ),
                    
                    // Game Four Button (Sprite to Scientific Name)
                    _buildThemedButton(
                      text: 'SPRITE TO SCIENTIFIC',
                      icon: Icons.image_search,
                      onPressed: () => _navigateToQuizGame(context, QuizType.spriteToScientific),
                      color: primaryButtonColor.withOpacity(0.7),
                    ),
                    
                    // 🟢 NEW Game Five Button (Silhouette to Common Name)
                    _buildThemedButton(
                      text: 'SILHOUETTE TO NAME',
                      icon: Icons.hide_image, 
                      onPressed: () => _navigateToQuizGame(context, QuizType.silhouetteToName),
                      color: quaternaryButtonColor, // Deep purple
                    ),
                    
                    // 🟢 NEW Game Six Button (Silhouette to Scientific Name)
                    _buildThemedButton(
                      text: 'SILHOUETTE TO SCIENTIFIC',
                      icon: Icons.visibility_off, 
                      onPressed: () => _navigateToQuizGame(context, QuizType.silhouetteToScientific),
                      color: secondaryButtonColor.withOpacity(0.7), // Darker shade of secondary
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