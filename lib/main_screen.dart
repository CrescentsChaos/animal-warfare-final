import 'package:flutter/material.dart';
import 'package:animal_warfare/login_screen.dart';
import 'package:animal_warfare/profile_screen.dart';
import 'package:animal_warfare/game_screen.dart';

// Placeholder for user state (should eventually come from Firebase Auth)
enum AuthStatus { loggedIn, guest }

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  // Simple state to toggle between logged in/guest for the UI demo
  AuthStatus _authStatus = AuthStatus.guest;

  // Define High-Contrast Retro/Military-themed colors
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green (Primary action)
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green (Secondary action)
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod (Text/Border highlight)
  static const Color darkOverlayColor = Colors.black45; // Dark overlay for background

  // Custom button builder to ensure consistent retro/jungle styling
  Widget _buildThemedButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary, // Used to make the PLAY button stand out
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0), // Slightly less vertical padding
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 300, 
          minWidth: 200, 
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            // Primary button (PLAY) gets the vibrant green, others get deep forest green
            backgroundColor: isPrimary ? primaryButtonColor : secondaryButtonColor, 
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
              // Use the Goldenrod highlight color for a classic military look
              side: BorderSide(color: highlightColor, width: isPrimary ? 4 : 3), 
            ),
            elevation: 12, // Higher elevation for a more prominent look
            shadowColor: Colors.black.withOpacity(0.9),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Icon(icon, size: 22), 
              const SizedBox(width: 10), 
              Flexible( 
                child: Text(
                  text,
                  textAlign: TextAlign.center, 
                  style: TextStyle(
                    fontSize: 16, 
                    letterSpacing: 1.0, 
                    fontWeight: FontWeight.bold,
                    // Use the highlight color for text for better contrast and classic feel
                    color: highlightColor, 
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loginButtonText = _authStatus == AuthStatus.guest ? 'LOGIN / SIGNUP' : 'LOGOUT';
    final loginButtonIcon = _authStatus == AuthStatus.guest ? Icons.lock_open : Icons.lock;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Background Image
          Image.asset(
            'assets/background.png',
            fit: BoxFit.cover,
          ),
          
          // 2. Dark Overlay Layer for High Contrast
          Container(
            color: darkOverlayColor,
          ),

          // 3. Content 
          Center(
            // Use FractionallySizedBox to shift the content vertically
            child: FractionallySizedBox(
              heightFactor: 0.8, // Centers the content around 80% of screen height
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // App Title / Logo Area
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'ANIMAL WARFARE',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26, 
                        color: highlightColor,
                        shadows: [
                          Shadow(
                            color: Colors.black, // Darker shadow for greater depth
                            blurRadius: 8,
                            offset: Offset(5, 5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 50),

                  // PLAY GAME Button (Primary)
                  _buildThemedButton(
                    text: 'PLAY GAME',
                    icon: Icons.play_arrow,
                    onPressed: () => _navigateTo(const GameScreen()),
                    isPrimary: true,
                  ),

                  // LOGIN / LOGOUT Button (Secondary)
                  _buildThemedButton(
                    text: loginButtonText,
                    icon: loginButtonIcon,
                    onPressed: () {
                      setState(() {
                        _authStatus = _authStatus == AuthStatus.guest
                            ? AuthStatus.loggedIn
                            : AuthStatus.guest;
                      });
                    },
                    isPrimary: false,
                  ),

                  // PROFILE Button (Secondary - Visible when logged in)
                  if (_authStatus == AuthStatus.loggedIn) 
                    _buildThemedButton(
                      text: 'PROFILE',
                      icon: Icons.person,
                      onPressed: () => _navigateTo(const ProfileScreen()),
                      isPrimary: false,
                    ),

                  const SizedBox(height: 50),
                  // User Status (Subtle)
                  Text(
                    'STATUS: ${_authStatus == AuthStatus.guest ? 'GUEST ACCESS' : 'PLAYER ACTIVE'}',
                    style: TextStyle(
                      fontSize: 10,
                      color: highlightColor.withOpacity(0.8), // Use gold color for status
                      shadows: [
                        Shadow(color: Colors.black.withOpacity(0.5), offset: const Offset(1, 1))
                      ]
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
