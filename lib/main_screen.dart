import 'package:flutter/material.dart';
import 'package:animal_warfare/login_screen.dart'; 
import 'package:animal_warfare/profile_screen.dart';
import 'package:animal_warfare/game_screen.dart';
import 'package:animal_warfare/local_auth_service.dart'; // Import service
import 'package:audioplayers/audioplayers.dart'; // ⬅️ NEW: Import audio package

// Placeholder for user state (adding 'loading' to prevent incorrect initial display)
enum AuthStatus { loading, loggedIn, guest } 

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final LocalAuthService _authService = LocalAuthService();
  AuthStatus _authStatus = AuthStatus.loading; // Start in loading state
  UserData? _currentUser; 
  
  // ⬅️ NEW: Audio player instance
  late AudioPlayer _audioPlayer; 

  // Define High-Contrast Retro/Military-themed colors
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod (Text/Border highlight)
  static const Color darkOverlayColor = Colors.black45; // Dark overlay

  @override
  void initState() {
    super.initState();
    // ⬅️ NEW: Initialize Audio Player and start music
    _audioPlayer = AudioPlayer();
    _playBackgroundMusic();
    
    // CRITICAL: Check local storage status immediately when the screen loads
    _checkCurrentUserStatus(); 
  }
  
  // ⬅️ NEW: Function to play music in a loop
  void _playBackgroundMusic() async {
    await _audioPlayer.setVolume(0.4); 
    await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
    try {
      // Placeholder for your main menu music
      await _audioPlayer.play(AssetSource('audio/main_theme.mp3')); 
    } catch (e) {
      debugPrint('Could not play main menu audio: $e');
    }
  }

  // Asynchronously checks local storage for a current session
  Future<void> _checkCurrentUserStatus() async {
    final user = await _authService.getCurrentUser();
    if (mounted) {
      setState(() {
        if (user != null) {
          _authStatus = AuthStatus.loggedIn; // Set to loggedIn
          _currentUser = user;
        } else {
          _authStatus = AuthStatus.guest;
          _currentUser = null;
        }
      });
    }
  }

  // Handle navigation to other screens (Login, Profile, Game)
  void _navigateTo(Widget screen) {
    // ⬅️ NEW: Stop music when navigating away from the main menu
    _audioPlayer.stop(); 
    
    // Push the new screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    ).then((_) {
      // ⬅️ NEW: Resume music when returning to the main menu
      if(mounted) {
        _playBackgroundMusic();
      }
    });
  }

  // Handle the combined Login/Logout action
  Future<void> _handleAuthAction() async {
    if (_authStatus == AuthStatus.loggedIn) {
      // LOGOUT LOGIC
      await _authService.logout();
      // Force UI update
      if (mounted) {
        setState(() {
          _authStatus = AuthStatus.guest;
          _currentUser = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully.')),
        );
      }
    } else {
      // LOGIN/SIGNUP LOGIC
      _navigateTo(const LoginScreen());
    }
  }

  // Custom button builder (Code is unchanged)
  Widget _buildThemedButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary, // Used to make the PLAY button stand out
  }) {
    final Color buttonColor = isPrimary ? primaryButtonColor : secondaryButtonColor;
    final Color textColor = highlightColor; // Use gold for text

    return Container(
      width: double.infinity, 
      height: 65,
      margin: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: buttonColor,
        border: Border.all(color: highlightColor, width: isPrimary ? 3 : 2),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: textColor, size: 24),
                const SizedBox(width: 15),
                Text(
                  text,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16, 
                    fontWeight: FontWeight.bold,
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
  void dispose() {
    // ⬅️ NEW: Stop and dispose of the audio player
    _audioPlayer.stop();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine button text and icon based on current status
    final String loginButtonText = 
      _authStatus == AuthStatus.loggedIn ? 'LOGOUT' : 'LOGIN / SIGNUP';
    final IconData loginButtonIcon = 
      _authStatus == AuthStatus.loggedIn ? Icons.lock_open : Icons.lock;

    // Show a spinner while loading the authentication status
    if (_authStatus == AuthStatus.loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: highlightColor),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: <Widget>[
          // 1. Background Image
          Positioned.fill(
            child: Image.asset(
              'assets/main.png',
              fit: BoxFit.cover,
            ),
          ),
          // 2. Dark Overlay
          Positioned.fill(
            child: Container(
              color: darkOverlayColor,
            ),
          ),
          // 3. Content (Using SingleChildScrollView to prevent overflow)
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 20.0), 
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min, 
                children: <Widget>[
                  // App Title / Logo Area
                  Text(
                    'ANIMAL WARFARE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32, 
                      fontWeight: FontWeight.bold,
                      color: highlightColor,
                      shadows: [
                        Shadow(color: Colors.black, offset: const Offset(4, 4), blurRadius: 0),
                      ], 
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
                    onPressed: _handleAuthAction, 
                    isPrimary: false,
                  ),

                  // PROFILE Button (Secondary - Visible ONLY when logged in)
                  if (_authStatus == AuthStatus.loggedIn) 
                    _buildThemedButton(
                      text: 'PROFILE',
                      icon: Icons.person,
                      // Navigation is now handled by _navigateTo, which pauses/resumes music
                      onPressed: () => _navigateTo(const ProfileScreen()), 
                      isPrimary: false,
                    ),

                  const SizedBox(height: 50),
                  // User Status (Subtle)
                  Text(
                    'STATUS: ${_authStatus == AuthStatus.guest ? 'GUEST ACCESS' : 'PLAYER ACTIVE'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: highlightColor.withOpacity(0.8), 
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