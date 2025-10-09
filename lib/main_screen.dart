import 'package:flutter/material.dart';
import 'package:animal_warfare/login_screen.dart'; 
import 'package:animal_warfare/profile_screen.dart';
import 'package:animal_warfare/game_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:animal_warfare/utils/transitions.dart'; // Import utility file (assuming this defines _createFadeRoute)

// Placeholder for user state (adding 'loading' to prevent incorrect initial display)
enum AuthStatus { loading, loggedIn, guest } 

// ------------------------------------------------------------------
// FIX: Define the missing _createFadeRoute function here 
// or ensure transitions.dart is correctly defining it.
// ------------------------------------------------------------------
PageRouteBuilder _createFadeRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 400),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
}
// ------------------------------------------------------------------


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final LocalAuthService _authService = LocalAuthService();
  AuthStatus _authStatus = AuthStatus.loading; // Start in loading state
  UserData? _currentUser; 
  
  late AudioPlayer _audioPlayer; 
  bool _wasPlayingBeforePause = false; 

  // Define High-Contrast Retro/Military-themed colors
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod (Text/Border Highlight)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _audioPlayer = AudioPlayer();
    _playBackgroundMusic();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      _wasPlayingBeforePause = _audioPlayer.state == PlayerState.playing;
      await _audioPlayer.pause();
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        await _audioPlayer.resume();
      }
    }
  }

  Future<void> _playBackgroundMusic() async {
    // Assuming audio file is at assets/audio/main_theme.mp3
    try {
      await _audioPlayer.setSourceAsset('audio/main_theme.mp3'); 
      await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
      await _audioPlayer.resume();
    } catch (e) {
      if (mounted) {
        // Simple error handling for missing audio file
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Warning: Could not play main screen music.')),
        );
      }
    }
  }

  Future<void> _checkLoginStatus() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUser = user;
      _authStatus = user != null ? AuthStatus.loggedIn : AuthStatus.guest;
    });
  }

  void _navigateTo(Widget page) {
    _audioPlayer.pause();
    // Navigate using the custom fade transition
    Navigator.of(context).push(_createFadeRoute(page)).then((_) {
      // Refresh status and resume music when returning
      _checkLoginStatus(); 
      _audioPlayer.resume(); 
    });
  }
  
  void _handleAuthAction() {
    if (_authStatus == AuthStatus.loggedIn) {
      // Logout
      _authService.logout().then((_) {
        // After logout, refresh the status
        _checkLoginStatus(); 
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logged out successfully.')),
        );
      });
    } else {
      // Navigate to Login/Register screen
      _navigateTo(const LoginScreen());
    }
  }

  Widget _buildThemedButton({
    required String text, 
    required IconData icon, 
    required VoidCallback onPressed, 
    required bool isPrimary
  }) {
    // Determine the color scheme based on primary/secondary
    final Color color = isPrimary ? primaryButtonColor : secondaryButtonColor;
    final Color textColor = isPrimary ? Colors.white : highlightColor;
    final Color borderColor = highlightColor;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor, width: 2.0),
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
                  style: TextStyle(
                    color: textColor,
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
    if (_authStatus == AuthStatus.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: highlightColor)),
      );
    }
    
    // Determine text and icon for the login/logout button
    final String loginButtonText = _authStatus == AuthStatus.loggedIn ? 'LOGOUT' : 'LOGIN / REGISTER';
    final IconData loginButtonIcon = _authStatus == AuthStatus.loggedIn ? Icons.exit_to_app : Icons.login;

    return Scaffold(
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
                  // Title
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

                  // START GAME Button (Primary)
                  // FIX: Pass currentUser and authService to GameScreen
                  _buildThemedButton(
                    text: 'START GAME',
                    icon: Icons.play_arrow,
                    onPressed: () {
                      // Ensure we have user data if logged in, otherwise pass null or handle as guest
                      final userToPass = _currentUser ?? UserData(username: 'Guest', password: '');
                      _navigateTo(GameScreen(
                        currentUser: userToPass, // Pass the user data
                        authService: _authService, // Pass the service
                      ));
                    },
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
                      onPressed: () => _navigateTo(const ProfileScreen()), 
                      isPrimary: false,
                    ),

                  const SizedBox(height: 50),
                  // User Status (Subtle)
                  Text(
                    'STATUS: ${_authStatus == AuthStatus.guest ? 'GUEST ACCESS' : 'PLAYER ACTIVE'}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: highlightColor.withOpacity(0.8), 
                      fontFamily: 'PressStart2P',
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