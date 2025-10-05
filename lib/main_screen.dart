import 'package:flutter/material.dart';
import 'package:animal_warfare/login_screen.dart'; 
import 'package:animal_warfare/profile_screen.dart';
import 'package:animal_warfare/game_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:animal_warfare/utils/transitions.dart'; // Import utility file

// Placeholder for user state (adding 'loading' to prevent incorrect initial display)
enum AuthStatus { loading, loggedIn, guest } 

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
    _checkAuthStatus();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _pauseMusic(true);
    } else if (state == AppLifecycleState.resumed) {
      _resumeMusic();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }
  
  // Audio Control Methods
  Future<void> _playBackgroundMusic() async {
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource('audio/main_theme.mp3')); 
  }

  void _pauseMusic(bool rememberState) async {
    if (rememberState) {
      final state = await _audioPlayer.state;
      _wasPlayingBeforePause = state == PlayerState.playing;
    }
    await _audioPlayer.pause();
  }

  void _resumeMusic() async {
    if (_wasPlayingBeforePause) {
      await _audioPlayer.resume();
      _wasPlayingBeforePause = false;
    }
  }

  Future<void> _checkAuthStatus() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUser = user;
      _authStatus = user != null ? AuthStatus.loggedIn : AuthStatus.guest;
    });
  }
  
  void _navigateTo(Widget screen) async {
    _audioPlayer.pause().then((_) { 
      _wasPlayingBeforePause = true;
    });
    
    // Choose transition based on the destination screen
    final routeBuilder = screen is GameScreen 
        ? createCloudTransitionRoute(screen) // Use cloud for the game
        : createFadeRoute(screen);           // Use fade for other menus
    
    await Navigator.of(context).push(
      routeBuilder,
    ).then((_) {
      if(mounted && _wasPlayingBeforePause) {
        _audioPlayer.resume();
      } else if (mounted) {
        // If music was stopped for another reason, restart it here
        _playBackgroundMusic(); 
      }
    });
  }

  void _handleAuthAction() {
    if (_authStatus == AuthStatus.loggedIn) {
      // Logout logic
      _authService.logout().then((_) {
        _checkAuthStatus();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('LOGOUT SUCCESSFUL!', style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12)),
            backgroundColor: primaryButtonColor,
          ),
        );
      });
    } else {
      // Navigate to Login/Register screen
      _navigateTo(const LoginScreen()); 
    }
  }

  // --- UI Helpers ---
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
        borderRadius: BorderRadius.circular(4.0), // Slight corner
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
    if (_authStatus == AuthStatus.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: highlightColor)),
      );
    }
    
    final loginButtonText = _authStatus == AuthStatus.loggedIn ? 'LOGOUT' : 'LOGIN / REGISTER';
    final loginButtonIcon = _authStatus == AuthStatus.loggedIn ? Icons.exit_to_app : Icons.login;

    return Scaffold(
      // Theming is managed by the background image and colors
      body: Stack(
        children: [
          // 1. Background Image (Themed)
          Positioned.fill(
            // ⬅️ FIX: Wrap Image.asset in ColorFiltered for broader Flutter SDK compatibility
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withOpacity(0.6), 
                BlendMode.darken,
              ),
              child: Image.asset(
                'assets/main.png', 
                fit: BoxFit.cover,
              ),
            ),
          ),
          
          // 2. Centered Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // App Title / Logo Area
                  Image.asset(
                    'assets/logo.png',
                    height: 200, 
                  ),
                  const SizedBox(height: 50),

                  // MAIN BUTTONS
                  
                  // PLAY Button (Primary)
                  _buildThemedButton(
                    text: 'START WARFARE',
                    // ⬅️ FIX: Changed Icons.explosion to the compatible Icons.local_fire_department
                    icon: Icons.local_fire_department, 
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
