import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart'; // Add this
import 'package:animal_warfare/explore_screen.dart'; // Add this
import 'package:animal_warfare/anidex_screen.dart'; // Add this

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

  Future<void> _playBackgroundMusic() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // Assuming you have a 'game_theme.mp3' in your assets/audio folder
    await _audioPlayer.play(AssetSource('audio/main.mp3')); 
  }

  // Helper method to navigate to the new screens
  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  // Helper method for themed buttons (Copied/Adapted from main_screen)
  Widget _buildThemedButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    final color = isPrimary ? primaryButtonColor : secondaryButtonColor;
    
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
                    text: 'EXPLORE TERRITORY',
                    icon: Icons.map,
                    onPressed: () => _navigateTo(const ExploreScreen()),
                    isPrimary: true,
                  ),

                  // Anidex Button
                  _buildThemedButton(
                    text: 'ANIDEX (UNITS)',
                    icon: Icons.pets,
                    onPressed: () => _navigateTo(const AnidexScreen()),
                    isPrimary: false,
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