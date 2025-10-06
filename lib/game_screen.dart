import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:animal_warfare/explore_screen.dart'; 
import 'package:animal_warfare/anidex_screen.dart'; 
import 'package:animal_warfare/quiz_screen.dart'; // 1. ADD: Import the new screen

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late AudioPlayer _audioPlayer;

  // Define High-Contrast Retro/Military-themed colors (Copied from main_screen for consistency)
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color tertiaryButtonColor = Color(0xFF8B0000); // 2. ADD: A new color for the quiz button (Deep Red/Maroon)
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

  // MODIFIED: Use setSourceAsset and then resume/pause/stop
  Future<void> _playBackgroundMusic() async {
    // Set source and release mode once
    await _audioPlayer.setSourceAsset('audio/main_theme.mp3'); 
    await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
    await _audioPlayer.resume(); // Start playing
  }

  // MODIFIED: Helper method to navigate to the new screens
  void _navigateTo(Widget screen) {
    // 1. Pause background music before navigating
    _audioPlayer.pause(); 
    
    // 2. Navigate and wait for the new screen to pop
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) {
      // 3. Resume background music when returning to GameScreen
      _audioPlayer.resume(); 
    });
  }

  // Helper method for themed buttons (MODIFIED to accept explicit color)
  Widget _buildThemedButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color, // MODIFIED: Take color as a required argument
  }) {
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: color, // Use the passed-in color
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
                const SizedBox(width: 12),
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
      appBar: AppBar(
        title: const Text('Battle Arena'),
        backgroundColor: Colors.green[900],
      ),
      body: Stack(
        children: [
          // 1. Background Image
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.5), // Darken background slightly
                BlendMode.darken,
              ),
              child: Image.asset(
                // Assuming you have 'game_bg.png' in your assets folder
                'assets/main.png', 
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // 2. Centered Content (Title and Buttons)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Game Title
                  Text(
                    'WARFARE COMMAND',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                      color: highlightColor,
                      fontFamily: 'PressStart2P',
                      shadows: [
                        Shadow(color: Colors.black, offset: const Offset(2, 2))
                      ]
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Explore Button
                  _buildThemedButton(
                    text: 'EXPLORE BIOME',
                    icon: Icons.map,
                    onPressed: () => _navigateTo(const ExploreScreen()),
                    color: primaryButtonColor, // Use explicit color
                  ),

                  // Anidex Button
                  _buildThemedButton(
                    text: 'ANIMAL DEX',
                    icon: Icons.pets,
                    onPressed: () => _navigateTo(const AnidexScreen()),
                    color: secondaryButtonColor, // Use explicit color
                  ),
                  
                  // 3. ADD: Quiz Button
                  _buildThemedButton(
                    text: 'BATTLE QUIZ',
                    icon: Icons.quiz,
                    onPressed: () => _navigateTo(const QuizScreen()),
                    color: tertiaryButtonColor, // Use the new color
                  ),
                  // END ADD

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