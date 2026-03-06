import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/main_screen.dart';
import 'package:animal_warfare/character_creation_screen.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/theme.dart';
import 'package:google_fonts/google_fonts.dart';

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
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

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
        _showSuccess('Password reset successfully!');
        setState(() {
          _showForgotPassword = false;
          _newPasswordController.clear();
          _confirmNewPasswordController.clear();
        });
      } else {
        _showError('Username not found.');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.dangerLight,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              color: AppColors.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showError('Username and password cannot be empty!');
      setState(() => _isLoading = false);
      return;
    }

    if (!_isLogin && password != confirmPassword) {
      _showError('Passwords do not match!');
      setState(() => _isLoading = false);
      return;
    }

    bool success;
    String message;

    if (_isLogin) {
      success = await _authService.login(username, password);
      message = success ? 'Welcome back!' : 'Invalid credentials.';
    } else {
      final existingUser = await _authService.readUserFile(username);
      if (existingUser != null) {
        success = false;
        message = 'Username already exists.';
      } else {
        success = true;
        message = '';
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        if (!mounted) return;
        if (message.isNotEmpty) {
          _showSuccess(message);
        }

        if (_isLogin) {
          // Normal login -> go to MainScreen
          await context.read<UserState>().handleSuccessfulAuth();
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              _createFadeRoute(const MainScreen()),
              (Route<dynamic> route) => false,
            );
          }
        } else {
          // New registration -> go to Character Creation
          Navigator.of(context).pushAndRemoveUntil(
            _createFadeRoute(
              CharacterCreationScreen(username: username, password: password),
            ),
            (route) => false,
          );
        }
      } else {
        _showError(message);
      }
    }
  }

  Future<void> _guestAuthenticate() async {
    setState(() => _isLoading = true);

    final success = await _authService.loginAsGuest();

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        if (!mounted) return;
        _showSuccess('Logged in as Guest (Debug Mode)');
        await context.read<UserState>().handleSuccessfulAuth();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            _createFadeRoute(const MainScreen()),
            (Route<dynamic> route) => false,
          );
        }
      } else {
        _showError('Failed to initialize Guest session.');
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    bool isPassword = false,
    bool? obscure,
    VoidCallback? onToggleObscure,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 7.0),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? (obscure ?? true) : false,
        keyboardType: isPassword
            ? TextInputType.visiblePassword
            : TextInputType.text,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          labelText: labelText,
          labelStyle: GoogleFonts.inter(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
          prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
          suffixIcon: isPassword && onToggleObscure != null
              ? IconButton(
                  icon: Icon(
                    obscure == true ? Icons.visibility_off : Icons.visibility,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          filled: true,
          fillColor: AppColors.surface.withValues(alpha: 0.8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? foregroundColor,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.primary,
          foregroundColor: foregroundColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          elevation: 0,
        ),
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 13,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenTitle = _showForgotPassword
        ? 'RESET\nPASSWORD'
        : (_isLogin ? 'SYSTEM\nLOGIN' : 'NEW\nRECRUIT');

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          image: DecorationImage(
            image: const AssetImage('assets/main.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.75),
              BlendMode.darken,
            ),
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  // Header
                  Text(
                    screenTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      color: AppColors.highlight,
                      fontFamily: 'PressStart2P',
                      height: 1.6,
                      shadows: [
                        Shadow(
                          color: AppColors.highlight,
                          blurRadius: 12,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      height: 2,
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            AppColors.highlight,
                            Colors.transparent,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),

                  if (_showForgotPassword) ...[
                    _buildTextField(
                      controller: _usernameController,
                      labelText: 'Username',
                      icon: Icons.person_outline,
                    ),
                    _buildTextField(
                      controller: _newPasswordController,
                      labelText: 'New Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      obscure: _obscurePassword,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    _buildTextField(
                      controller: _confirmNewPasswordController,
                      labelText: 'Confirm New Password',
                      icon: Icons.lock_reset,
                      isPassword: true,
                      obscure: _obscureConfirm,
                      onToggleObscure: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : _buildActionButton(
                            title: 'RESET',
                            onPressed: _handleForgotPassword,
                          ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _showForgotPassword = false;
                          _newPasswordController.clear();
                          _confirmNewPasswordController.clear();
                        });
                      },
                      child: Text(
                        '← Back to login',
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ] else ...[
                    _buildTextField(
                      controller: _usernameController,
                      labelText: 'Username',
                      icon: Icons.person_outline,
                    ),
                    _buildTextField(
                      controller: _passwordController,
                      labelText: 'Password',
                      icon: Icons.lock_outline,
                      isPassword: true,
                      obscure: _obscurePassword,
                      onToggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    if (!_isLogin)
                      _buildTextField(
                        controller: _confirmPasswordController,
                        labelText: 'Confirm Password',
                        icon: Icons.lock_reset,
                        isPassword: true,
                        obscure: _obscureConfirm,
                        onToggleObscure: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                          )
                        : Column(
                            children: [
                              _buildActionButton(
                                title: _isLogin ? 'LOG IN' : 'REGISTER',
                                onPressed: _authenticate,
                              ),
                              _buildActionButton(
                                title: 'PLAY AS GUEST',
                                onPressed: _guestAuthenticate,
                                backgroundColor: AppColors.surface,
                                foregroundColor: AppColors.textPrimary,
                              ),
                            ],
                          ),
                    const SizedBox(height: 12),
                    if (_isLogin)
                      TextButton(
                        onPressed: () {
                          setState(() => _showForgotPassword = true);
                        },
                        child: Text(
                          'Forgot password?',
                          style: GoogleFonts.inter(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    const SizedBox(height: 4),
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
                        _isLogin
                            ? 'Don\'t have an account? Create one'
                            : 'Already have an account? Log in',
                        style: GoogleFonts.inter(
                          color: AppColors.primary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
