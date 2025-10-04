import 'package:flutter/material.dart';
import 'package:animal_warfare/widgets/background_screen.dart';
import 'package:animal_warfare/widgets/flicker_text_widget.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

  void _startGame(BuildContext context) {
    // Game start logic remains here
    print("Game Started!");
  }

  @override
  Widget build(BuildContext context) {
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

                // Old Text Title (removed):
                /*
                Text(
                  'ANIMAL WARFARE',
                  // ... styling
                ),
                */
                
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