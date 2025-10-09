// lib/main_screen.dart

import 'package:flutter/material.dart';
import 'package:animal_warfare/login_screen.dart'; 
import 'package:animal_warfare/profile_screen.dart';
import 'package:animal_warfare/game_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:audioplayers/audioplayers.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
// REMOVED: import 'package:animal_warfare/utils/transitions.dart'; 

enum AuthStatus { loading, loggedIn, guest } 

// ------------------------------------------------------------------
// 🚨 REMOVED: The custom _createFadeRoute function definition is removed entirely
// ------------------------------------------------------------------


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  final LocalAuthService _authService = LocalAuthService();
  AuthStatus _authStatus = AuthStatus.loading;
  UserData? _currentUser;
  
  late AudioPlayer _audioPlayer; 
  bool _wasPlayingBeforePause = false; 

  // Define High-Contrast Retro/Military-themed colors
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    
    _audioPlayer = AudioPlayer(); 
    _checkAuthStatus();
    _playBackgroundMusic();
  }

  // Override to handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
      final playerState = await _audioPlayer.state;
      if (playerState == PlayerState.playing) {
        _wasPlayingBeforePause = true;
        await _audioPlayer.pause();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        await _audioPlayer.resume();
        _wasPlayingBeforePause = false;
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    final user = await _authService.getCurrentUser();
    setState(() {
      _currentUser = user;
      _authStatus = user != null ? AuthStatus.loggedIn : AuthStatus.guest;
    });
  }

  Future<void> _playBackgroundMusic() async {
    final prefs = await SharedPreferences.getInstance();
    final isMusicEnabled = prefs.getBool('isMusicEnabled') ?? true; // Default to ON

    if (isMusicEnabled) {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Ensure you use a valid AssetSource path
      await _audioPlayer.play(AssetSource('audio/background_track.mp3'));
    } else {
      await _audioPlayer.stop();
    }
  }

  void _navigateTo(Widget page) {
    // Stop and immediately replay music when returning to ensure the latest setting is applied
    _audioPlayer.stop();
    // 🚨 EDITED: Replaced custom route with standard MaterialPageRoute
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => page)).then((_) {
      _checkAuthStatus();
      _playBackgroundMusic();
    });
  }

  void _handleAuthAction() {
    _navigateTo(const LoginScreen()); 
  }

  Widget _buildThemedButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    required bool isPrimary,
  }) {
    final Color buttonColor = isPrimary ? primaryButtonColor : secondaryButtonColor;
    final Color textColor = isPrimary ? Colors.white : highlightColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor),
        label: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontFamily: 'PressStart2P',
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
            side: BorderSide(color: highlightColor, width: 2.0),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
          minimumSize: const Size(double.infinity, 70),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_authStatus == AuthStatus.loading) {
      return Scaffold(
        body: Container(
          color: secondaryButtonColor,
          child: const Center(child: CircularProgressIndicator(color: highlightColor)),
        ),
      );
    }
    
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              color: secondaryButtonColor,
              image: DecorationImage(
                image: const AssetImage('assets/background.png'), 
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(0.7),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          
          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Title
                  Text(
                    'ANIMAL WARFARE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      color: highlightColor,
                      fontFamily: 'PressStart2P',
                      shadows: [
                        Shadow(color: Colors.black.withOpacity(0.9), blurRadius: 4, offset: const Offset(3, 3))
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),

                  // GAME Button (Primary)
                  _buildThemedButton(
                    text: 'START GAME',
                    icon: Icons.shield,
                    onPressed: () {
                       if (_currentUser != null) {
                        _navigateTo(GameScreen(
                          currentUser: _currentUser!, 
                          authService: _authService,
                        ));
                      } else {
                        // Redirect to login if a player attempts to start the game while logged out
                        _navigateTo(const LoginScreen());
                      }
                    },
                    isPrimary: true,
                  ),

                  // LOGIN / REGISTER Button (Secondary) - Only show if not logged in
                  if (_authStatus == AuthStatus.guest)
                    _buildThemedButton(
                      text: 'LOGIN / REGISTER',
                      icon: Icons.login,
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