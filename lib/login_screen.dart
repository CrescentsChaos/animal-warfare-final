// lib/login_screen.dart

import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/main_screen.dart'; 
import 'package:audioplayers/audioplayers.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; // ADDED: For music control

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final LocalAuthService _authService = LocalAuthService();
  final TextEditingController _usernameController = TextEditingController(); 
  final TextEditingController _passwordController = TextEditingController();
  // 🚨 NEW: Controller for password confirmation
  final TextEditingController _confirmPasswordController = TextEditingController(); 
  
  late AudioPlayer _audioPlayer; 
  bool _wasPlayingBeforePause = false;
  
  bool _isLogin = true;
  bool _isLoading = false;
  
  // Custom Theming
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); 
    
    _audioPlayer = AudioPlayer(); 
    _playBackgroundMusic();
  }
  
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
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // 🚨 NEW: Dispose new controller
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playBackgroundMusic() async {
    final prefs = await SharedPreferences.getInstance();
    final isMusicEnabled = prefs.getBool('isMusicEnabled') ?? true; // Default to ON

    if (isMusicEnabled) {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('audio/login_background.mp3'));
    } else {
      await _audioPlayer.stop();
    }
  }

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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
        ),
        backgroundColor: Colors.red.shade700,
      ),
    );
  }

  Future<void> _authenticate() async {
    setState(() {
      _isLoading = true;
    });

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim(); // 🚨 NEW

    if (username.isEmpty || password.isEmpty) {
      _showError('Username and password cannot be empty!');
      setState(() { _isLoading = false; });
      return;
    }

    if (!_isLogin) {
      // 🚨 NEW: Check password confirmation on registration
      if (password != confirmPassword) {
        _showError('Passwords do not match!');
        setState(() { _isLoading = false; });
        return;
      }
    }

    bool success;
    String message;

    if (_isLogin) {
      success = await _authService.login(username, password);
      message = success ? 'LOGIN SUCCESSFUL!' : 'LOGIN FAILED. Invalid credentials.';
    } else {
      // Use the confirmed password for registration
      success = await _authService.register(username, password); 
      message = success ? 'REGISTRATION SUCCESSFUL!' : 'REGISTRATION FAILED. User already exists.';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
            ),
            backgroundColor: primaryButtonColor,
          ),
        );
        // Navigate to the main screen on success
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            _createFadeRoute(const MainScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        _showError(message);
      }
    }
  }

  // Helper function for building the themed action button
  Widget _buildActionButton({
    required String title,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: highlightColor, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 18.0),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'PressStart2P',
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper function for pixel-style text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.brown.shade700.withOpacity(0.8),
        border: Border.all(color: highlightColor, width: 1),
        borderRadius: BorderRadius.circular(4.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.text, 
        style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'PressStart2P'),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: highlightColor.withOpacity(0.8), 
            fontSize: 14,
            fontFamily: 'PressStart2P',
          ),
          prefixIcon: Icon(icon, color: highlightColor.withOpacity(0.8), size: 20),
          border: InputBorder.none, // Remove default underline border
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Colors.black,
          image: DecorationImage(
            image: const AssetImage('assets/main.png'), 
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.darken,
            ),
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Title
                Text(
                  _isLogin ? 'SYSTEM LOGIN' : 'NEW RECRUIT',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    color: highlightColor,
                    fontFamily: 'PressStart2P',
                    shadows: [
                      Shadow(color: Colors.black.withOpacity(0.9), blurRadius: 4, offset: const Offset(3, 3))
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Username Field
                _buildTextField(
                  controller: _usernameController,
                  labelText: 'USERNAME',
                  icon: Icons.person,
                ),

                // Password Field
                _buildTextField(
                  controller: _passwordController,
                  labelText: 'PASSWORD',
                  icon: Icons.lock,
                  isPassword: true,
                ),
                
                // 🚨 NEW: Password Confirmation Field (Only shown during registration)
                if (!_isLogin)
                  _buildTextField(
                    controller: _confirmPasswordController,
                    labelText: 'CONFIRM PASSWORD',
                    icon: Icons.lock_open,
                    isPassword: true,
                  ),
                
                const SizedBox(height: 30),

                // Main Action Button (Login/Register)
                _isLoading
                    ? Center(child: CircularProgressIndicator(color: primaryButtonColor))
                    : _buildActionButton(
                        title: _isLogin ? 'LOG IN' : 'REGISTER',
                        onPressed: _authenticate,
                        color: primaryButtonColor,
                      ),

                const SizedBox(height: 20),

                // Toggle Button (Switch to Register/Login)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                      // Clear fields when switching mode
                      _usernameController.clear();
                      _passwordController.clear();
                      _confirmPasswordController.clear(); // 🚨 NEW: Clear confirm field
                    });
                  },
                  child: Text(
                    _isLogin ? 'CREATE NEW ACCOUNT' : 'BACK TO LOGIN',
                    style: TextStyle(
                      color: highlightColor,
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}