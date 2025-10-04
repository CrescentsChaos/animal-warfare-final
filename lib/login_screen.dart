import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/main_screen.dart'; // To navigate back to main

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthService _authService = LocalAuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // State for toggling between Login and Signup
  bool _isLogin = true;
  // State for showing loading indicator and preventing double-taps
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
    if (mounted) {
      // Use pushReplacement to replace the LoginScreen with MainScreen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  // The fully functional authentication method
  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackbar('Alert: Please enter both email and password.');
      return;
    }
    
    // Start loading state
    setState(() { _isLoading = true; });

    try {
      if (_isLogin) {
        // --- LOGIN LOGIC (using LocalAuthService) ---
        final user = await _authService.loginUser(email, password);
        if (user != null) {
          _showSnackbar('Login successful for ${user.email}!');
          _navigateToMainScreen(); // Navigate on success
        } else {
          _showSnackbar('Login failed: Invalid email or password.');
        }
      } else {
        // --- SIGNUP LOGIC (using LocalAuthService) ---
        final success = await _authService.registerUser(email, password);
        if (success) {
          _showSnackbar('Account created and automatically logged in!');
          _navigateToMainScreen(); // Navigate on success
        } else {
          _showSnackbar('Signup failed: User already exists with this email.');
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
            image: AssetImage('assets/background.png'), // Use your jungle background
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

                // Email/Username Input Field
                _buildTextField(
                  controller: _emailController,
                  labelText: 'EMAIL',
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
                      _emailController.clear();
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

  // Helper function for pixel-style buttons
  Widget _buildActionButton(BuildContext context, {required String title, required VoidCallback? onPressed}) {
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
        keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.emailAddress,
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
