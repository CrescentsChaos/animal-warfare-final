// lib/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:animal_warfare/user_state.dart';

import 'package:animal_warfare/services/audio_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthService _authService = LocalAuthService();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmNewPasswordController =
      TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _showForgotPassword = false;

  // Custom Theming
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod
  static const Color primaryButtonColor = Color(
    0xFF38761D,
  ); // Bright Jungle Green

  @override
  void initState() {
    super.initState();
    _playBackgroundMusic();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _playBackgroundMusic() async {
    // AudioService handles its own 'enabled' state internally
    await AudioService.instance.playMusic('audio/login_theme.mp3');
  }

  PageRouteBuilder _createFadeRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  Future<void> _handleForgotPassword() async {
    final username = _usernameController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmNew = _confirmNewPasswordController.text.trim();

    if (username.isEmpty) {
      _showError('Enter your username first.');
      return;
    }
    if (newPassword.isEmpty || confirmNew.isEmpty) {
      _showError('Fill in both password fields.');
      return;
    }
    if (newPassword != confirmNew) {
      _showError('New passwords do not match!');
      return;
    }

    setState(() => _isLoading = true);
    final success = await _authService.resetPassword(username, newPassword);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Password reset successfully! You can now log in.',
              style: TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
            ),
            backgroundColor: primaryButtonColor,
          ),
        );
        setState(() {
          _showForgotPassword = false;
          _newPasswordController.clear();
          _confirmNewPasswordController.clear();
        });
      } else {
        _showError('Username not found. Check your username and try again.');
      }
    }
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
      setState(() {
        _isLoading = false;
      });
      return;
    }

    if (!_isLogin) {
      // 🚨 NEW: Check password confirmation on registration
      if (password != confirmPassword) {
        _showError('Passwords do not match!');
        setState(() {
          _isLoading = false;
        });
        return;
      }
    }

    bool success;
    String message;

    if (_isLogin) {
      success = await _authService.login(username, password);
      message = success
          ? 'LOGIN SUCCESSFUL!'
          : 'LOGIN FAILED. Invalid credentials.';
    } else {
      // Use the confirmed password for registration
      success = await _authService.register(username, password);
      message = success
          ? 'REGISTRATION SUCCESSFUL!'
          : 'REGISTRATION FAILED. User already exists.';
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        await context.read<UserState>().handleSuccessfulAuth();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(fontFamily: 'PressStart2P', fontSize: 12),
            ),
            backgroundColor: primaryButtonColor,
          ),
        );
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
        color: Colors.brown.shade700.withValues(alpha: 0.8),
        border: Border.all(color: highlightColor, width: 1),
        borderRadius: BorderRadius.circular(4.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: isPassword
            ? TextInputType.visiblePassword
            : TextInputType.text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'PressStart2P',
        ),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: TextStyle(
            color: highlightColor.withValues(alpha: 0.8),
            fontSize: 14,
            fontFamily: 'PressStart2P',
          ),
          prefixIcon: Icon(
            icon,
            color: highlightColor.withValues(alpha: 0.8),
            size: 20,
          ),
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
              Colors.black.withValues(alpha: 0.7),
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
                Text(
                  _showForgotPassword
                      ? 'RESET PASSWORD'
                      : (_isLogin ? 'SYSTEM LOGIN' : 'NEW RECRUIT'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    color: highlightColor,
                    fontFamily: 'PressStart2P',
                    shadows: [
                      Shadow(
                        color: Colors.black.withValues(alpha: 0.9),
                        blurRadius: 4,
                        offset: const Offset(3, 3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                if (_showForgotPassword) ...[
                  _buildTextField(
                    controller: _usernameController,
                    labelText: 'USERNAME',
                    icon: Icons.person,
                  ),
                  _buildTextField(
                    controller: _newPasswordController,
                    labelText: 'NEW PASSWORD',
                    icon: Icons.lock,
                    isPassword: true,
                  ),
                  _buildTextField(
                    controller: _confirmNewPasswordController,
                    labelText: 'CONFIRM NEW PASSWORD',
                    icon: Icons.lock_open,
                    isPassword: true,
                  ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: primaryButtonColor,
                          ),
                        )
                      : _buildActionButton(
                          title: 'RESET PASSWORD',
                          onPressed: _handleForgotPassword,
                          color: primaryButtonColor,
                        ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showForgotPassword = false;
                        _newPasswordController.clear();
                        _confirmNewPasswordController.clear();
                      });
                    },
                    child: Text(
                      'BACK TO LOGIN',
                      style: TextStyle(
                        color: highlightColor,
                        fontFamily: 'PressStart2P',
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ] else ...[
                  _buildTextField(
                    controller: _usernameController,
                    labelText: 'USERNAME',
                    icon: Icons.person,
                  ),
                  _buildTextField(
                    controller: _passwordController,
                    labelText: 'PASSWORD',
                    icon: Icons.lock,
                    isPassword: true,
                  ),
                  if (!_isLogin)
                    _buildTextField(
                      controller: _confirmPasswordController,
                      labelText: 'CONFIRM PASSWORD',
                      icon: Icons.lock_open,
                      isPassword: true,
                    ),
                  const SizedBox(height: 30),
                  _isLoading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: primaryButtonColor,
                          ),
                        )
                      : _buildActionButton(
                          title: _isLogin ? 'LOG IN' : 'REGISTER',
                          onPressed: _authenticate,
                          color: primaryButtonColor,
                        ),
                  const SizedBox(height: 12),
                  if (_isLogin)
                    TextButton(
                      onPressed: () {
                        setState(() => _showForgotPassword = true);
                      },
                      child: Text(
                        'FORGOT PASSWORD?',
                        style: TextStyle(
                          color: highlightColor.withValues(alpha: 0.9),
                          fontFamily: 'PressStart2P',
                          fontSize: 10,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _usernameController.clear();
                        _passwordController.clear();
                        _confirmPasswordController.clear();
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
