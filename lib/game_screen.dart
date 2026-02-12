// lib/game_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:animal_warfare/explore_screen.dart';
import 'package:animal_warfare/anidex_screen.dart';
import 'package:animal_warfare/quiz_screen.dart';
import 'package:animal_warfare/animal_box_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/stats_display_button.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/crafting_screen.dart';
import 'package:animal_warfare/battle_tab_screen.dart';

import 'package:animal_warfare/audio_manager.dart';

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

  // Define High-Contrast Retro/Military-themed colors (Copied from main_screen for consistency)
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color tertiaryButtonColor = Color(0xFF8B0000); // Deep Red/Maroon
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod (Text/Border Highlight)

  @override
  void initState() {
    super.initState();
    _playBackgroundMusic();
  }

  @override
  void dispose() {
    super.dispose();
  }
  
  void _playBackgroundMusic() {
    AudioManager.instance.playBackgroundMusic('audio/main_theme.mp3');
  }
  
  // Navigation function to pass UserData and LocalAuthService
  void _navigateTo(Widget screen) async {
    AudioManager.instance.pause();
    await Navigator.of(context).push(
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
    );
    
    // Resume music when returning
    AudioManager.instance.resume();
    
    // 🟢 FIX: Refresh user data when returning from any screen
    final updatedUser = await widget.authService.getCurrentUser();
    if (updatedUser != null && mounted) {
      setState(() {
        // This updates the GameScreen's reference to currentUser
        // Note: We can't directly modify widget.currentUser, but we need to
        // ensure the parent (MainScreen or wherever) knows about updates
      });
    }
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
      // ADD THE FLOATING ACTION BUTTON HERE
      floatingActionButton: const StatsDisplayButton(),
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

                  // Use UserState's current user when available (e.g. after setting attacker in Animal Box)
                  _buildThemedButton(
                    text: 'EXPLORE BIOMES',
                    icon: Icons.map,
                    onPressed: () {
                      final user = Provider.of<UserState>(context, listen: false).currentUser ?? widget.currentUser;
                      _navigateTo(ExploreScreen(currentUser: user, authService: widget.authService));
                    },
                    color: primaryButtonColor,
                  ),

                  _buildThemedButton(
                    text: 'BATTLE ARENA',
                    icon: Icons.sports_kabaddi,
                    onPressed: () => _navigateTo(const BattleTabScreen()),
                    color: const Color(0xFF8B0000),
                  ),

                  _buildThemedButton(
                    text: 'ANIMAL BOX',
                    icon: Icons.inventory_2,
                    onPressed: () => _navigateTo(const AnimalBoxScreen()),
                    color: const Color(0xFF2E5A1C),
                  ),
                  
                  _buildThemedButton(
                    text: 'CRAFTING STATION',
                    icon: Icons.auto_awesome,
                    onPressed: () => _navigateTo(const CraftingScreen()),
                    color: const Color(0xFF5A4A1C),
                  ),

                  _buildThemedButton(
                    text: 'ANIMAL DEX',
                    icon: Icons.pets,
                    onPressed: () {
                      final user = Provider.of<UserState>(context, listen: false).currentUser ?? widget.currentUser;
                      _navigateTo(AnidexScreen(currentUser: user, authService: widget.authService));
                    },
                    color: secondaryButtonColor,
                  ),
                  _buildThemedButton(
                    text: 'ANIMAL QUIZ',
                    icon: Icons.quiz,
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