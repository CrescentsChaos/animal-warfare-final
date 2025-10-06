import 'package:flutter/material.dart';
import 'package:animal_warfare/quiz_game_screen.dart';

class QuizScreen extends StatelessWidget {
  const QuizScreen({super.key});

  // Custom retro/military colors (Copied from GameScreen for consistency)
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod
  static const Color secondaryButtonColor = Color(0xFF8B0000); // Red/Maroon

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
            color: Colors.black.withOpacity(0.6),
            offset: const Offset(6, 6),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8.0),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: highlightColor, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'PressStart2P',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  void _navigateToQuizGame(BuildContext context, QuizType type) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => QuizGameScreen(quizType: type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Battle Quiz'),
        backgroundColor: Colors.green[900],
      ),
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5), 
                BlendMode.darken,
              ),
              child: Image.asset(
                'assets/main.png', 
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // Centered Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'SELECT YOUR QUIZ CHALLENGE',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                      color: highlightColor,
                      fontFamily: 'PressStart2P',
                      shadows: [
                        Shadow(color: Colors.black, offset: const Offset(2, 2))
                      ]
                    ),
                  ),
                  const SizedBox(height: 50),
                  
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}