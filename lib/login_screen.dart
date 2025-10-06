import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/main_screen.dart'; 
import 'package:audioplayers/audioplayers.dart'; // ⬅️ ADDED: Audio package

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// ⬅️ UPDATED: Add WidgetsBindingObserver mixin
class _LoginScreenState extends State<LoginScreen> with WidgetsBindingObserver {
  final LocalAuthService _authService = LocalAuthService();
  // ⬅️ RENAMED: from _emailController
  final TextEditingController _usernameController = TextEditingController(); 
  final TextEditingController _passwordController = TextEditingController();
  
  // ⬅️ ADDED: Audio player instance
  late AudioPlayer _audioPlayer; 
  // ⬅️ NEW: Flag to track if the audio was playing before pause
  bool _wasPlayingBeforePause = false;
  
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // ⬅️ NEW: Register the observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this); 
    
    // ⬅️ ADDED: Audio setup
    _audioPlayer = AudioPlayer(); 
    _playBackgroundMusic();
  }
  
  // ⬅️ NEW: Override to handle app lifecycle changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      final isPlaying = await _audioPlayer.state == PlayerState.playing;
      _wasPlayingBeforePause = isPlaying;
      if (isPlaying) {
        await _audioPlayer.pause(); 
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasPlayingBeforePause) {
        await _audioPlayer.resume();
      }
    }
  }
  
  // ⬅️ ADDED: Function to play music in a loop
  void _playBackgroundMusic() async {
    _wasPlayingBeforePause = true; // Assume playback starts
    await _audioPlayer.setVolume(0.4); 
    await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
    try {
      // Placeholder for your login screen music
      await _audioPlayer.play(AssetSource('audio/login_theme.mp3')); 
    } catch (e) {
      debugPrint('Could not play login audio: $e');
    }
  }

  @override
  void dispose() {
    // ⬅️ NEW: Remove the observer before disposing
    WidgetsBinding.instance.removeObserver(this); 
    _usernameController.dispose(); 
    _passwordController.dispose();
    // ⬅️ ADDED: Audio cleanup
    _audioPlayer.stop(); 
    _audioPlayer.dispose();
    super.dispose();
  }

  // Helper to show a feedback message to the user
  void _showSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  // Helper to navigate back to the main screen and force a refresh
  void _navigateToMainScreen() {
    // ⬅️ NEW: Stop and dispose the audio player before navigating away
    _audioPlayer.stop(); 
    _audioPlayer.dispose();
    
    if (mounted) {
      // Use pushReplacement to replace the LoginScreen with MainScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  // The fully functional authentication method
  Future<void> _authenticate() async {
    // ⬅️ UPDATED: Use username controller
    final username = _usernameController.text.trim(); 
    final password = _passwordController.text.trim();

    // ⬅️ UPDATED: Check for username emptiness
    if (username.isEmpty || password.isEmpty) { 
      _showSnackbar('Alert: Please enter both username and password.');
      return;
    }
    
    // Start loading state
    setState(() { _isLoading = true; });

    try {
      if (_isLogin) {
        // --- LOGIN LOGIC (using LocalAuthService) ---
        // ⬅️ FIXED: Call loginUser
        final user = await _authService.loginUser(username, password); 
        if (user != null) {
          _showSnackbar('Login successful for ${user.username}!'); // ⬅️ UPDATED
          _navigateToMainScreen(); // Navigate on success
        } else {
          _showSnackbar('Login failed: Invalid username or password.'); // ⬅️ UPDATED
        }
      } else {
        // --- SIGNUP LOGIC (using LocalAuthService) ---
        // ⬅️ FIXED: Call registerUser
        final success = await _authService.registerUser(username, password); 
        if (success) {
          _showSnackbar('Account created and automatically logged in!');
          _navigateToMainScreen(); // Navigate on success
        } else {
          _showSnackbar('Signup failed: User already exists with this username.'); // ⬅️ UPDATED
        }
      }
    } catch (e) {
      // General error catch for storage issues
      _showSnackbar('An internal error occurred: $e');
      debugPrint('Local Auth Error: $e');
    } finally {
      // End loading state
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'LOG IN' : 'SIGN UP'),
        backgroundColor: Colors.black, // Consistent dark theme
        elevation: 0,
      ),
      body: Container(
        padding: const EdgeInsets.all(24.0),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/login.png'), // Use your jungle background
            fit: BoxFit.cover,
            opacity: 0.2, // Make it subtle in the background
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  _isLogin ? 'AUTHENTICATE' : 'NEW ADVENTURER',
                  style: TextStyle(fontSize: 24, color: Colors.limeAccent.shade200),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),

                // Username Input Field (Replaced Email)
                _buildTextField(
                  controller: _usernameController, // ⬅️ UPDATED
                  labelText: 'USERNAME', // ⬅️ UPDATED
                  icon: Icons.person_outline,
                ),
                const SizedBox(height: 20),

                // Password Input Field
                _buildTextField(
                  controller: _passwordController,
                  labelText: 'PASSWORD',
                  icon: Icons.lock_outline,
                  isPassword: true,
                ),
                const SizedBox(height: 40),

                // Primary Action Button (Login / Signup)
                _buildActionButton(
                  context,
                  // Display loading text when busy
                  title: _isLogin 
                    ? (_isLoading ? 'LOGGING IN...' : 'LOG IN')
                    : (_isLoading ? 'SIGNING UP...' : 'SIGN UP'),
                  // Disable button while loading
                  onPressed: _isLoading ? () {} : _authenticate, 
                ),
                const SizedBox(height: 20),
                
                // Toggle Button (Switch to Login / Signup)
                TextButton(
                  onPressed: _isLoading ? null : () {
                    setState(() {
                      _isLogin = !_isLogin;
                      _usernameController.clear(); // ⬅️ UPDATED
                      _passwordController.clear();
                    });
                  },
                  child: Text(
                    _isLogin ? 'Don\'t have an account? SIGN UP' : 'Already have an account? LOG IN',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white70,
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

  // Helper function for pixel-style buttons (No change)
  Widget _buildActionButton(BuildContext context, {required String title, required VoidCallback? onPressed}) {
    // ... code is unchanged
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: onPressed == null ? Colors.grey.shade700 : Colors.brown.shade800, // Dimmer when disabled
        border: Border.all(color: onPressed == null ? Colors.grey.shade500 : Colors.limeAccent, width: 3),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            offset: Offset(4, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
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
      decoration: BoxDecoration(
        color: Colors.brown.shade700.withOpacity(0.8),
        border: Border.all(color: Colors.limeAccent, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        // ⬅️ UPDATED: Keyboard type changed from emailAddress to text
        keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.text, 
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: Colors.limeAccent.withOpacity(0.8), 
            fontSize: 14,
          ),
          prefixIcon: Icon(icon, color: Colors.limeAccent.withOpacity(0.8), size: 20),
          border: InputBorder.none, // Remove default underline border
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}