import 'package:flutter/material.dart';
import 'package:animal_warfare/widgets/background_screen.dart';
import 'package:animal_warfare/widgets/flicker_text_widget.dart';
import 'package:animal_warfare/screens/main_game_screen.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  // 🐛 FIX: This is the correct definition for _startGame
  void _startGame(BuildContext context) { 
    // 🚀 Navigate to the MainGameScreen and replace the current route
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        // Remember to address the 'const' error here as well if needed
        builder: (context) => MainGameScreen(), 
      ),
    );
  }

  // ⚠️ The problematic nested code has been removed:
  /*
  void _startGame(BuildContext context) {
    // Game start logic remains here
    void _startGame(BuildContext context) { // ⬅️ DUPLICATE/NESTED FUNCTION
    // ... navigation code ...
    }
  }
  */

  @override
  Widget build(BuildContext context) {
    // ... (Your build method remains the same and correctly calls the outer _startGame)
    return Scaffold(
      body: BackgroundScreen(
        child: GestureDetector(
          onTap: () => _startGame(context),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // 🚀 NEW: Replace the text title with your logo image
                SizedBox(
                  width: 250, // Set a specific width for visual control
                  child: Image.asset(
                    // !! IMPORTANT: Use your actual logo file name and path
                    'assets/logo.png', 
                    fit: BoxFit.contain,
                  ),
                ),
                
                SizedBox(height: 100), // Vertical spacing remains

                // --- Flickering "Tap to Continue" Prompt ---
                FlickerTextWidget(
                  text: 'TAP TO CONTINUE',
                  fontSize: 14.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}