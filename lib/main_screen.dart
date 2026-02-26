// lib/main_screen.dart

import 'package:flutter/material.dart';
import 'package:animal_warfare/login_screen.dart';
import 'package:animal_warfare/profile_screen.dart';
import 'package:animal_warfare/game_screen.dart';
import 'package:animal_warfare/quest_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/shop_screen.dart';

import 'package:animal_warfare/services/audio_service.dart';

enum AuthStatus { loading, loggedIn, guest }

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final LocalAuthService _authService = LocalAuthService();
  AuthStatus _authStatus = AuthStatus.loading;
  UserData? _currentUser;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
    _playBackgroundMusic();
  }

  @override
  void dispose() {
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
    // AudioService handles its own 'enabled' state internally
    await AudioService.instance.playMusic('audio/coastal_theme.mp3');
  }

  void _navigateTo(Widget page) {
    // Stop music via AudioService when navigating away if necessary,
    // though the new page should handle its own music or pause it.
    AudioService.instance.pauseAll();

    // FIX: Replace MaterialPageRoute with your custom _createFadeRoute
    Navigator.of(context)
        .push(
          _createFadeRoute(page), // <--- Use the custom route here!
        )
        .then((_) {
          // This block runs AFTER the new page is POPPED (i.e., you return to the current screen)
          _checkAuthStatus();
          _playBackgroundMusic();
          // Resume music when returning
          AudioService.instance.resumeAll();
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
    // 🚨 EDITED: Use AppColors
    final Color buttonColor = isPrimary
        ? AppColors.primaryButtonColor
        : AppColors.secondaryButtonColor;
    final Color textColor = isPrimary ? Colors.white : AppColors.highlightColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10.0),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor),
        label: Text(
          text,
          // 🚨 EDITED: Use AppTextStyles.body (or a custom size based on it)
          style: AppTextStyles.body(context, baseSize: 16.0, color: textColor),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor.withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(5.0),
            // 🚨 EDITED: Use AppColors.highlightColor
            side: const BorderSide(color: AppColors.highlightColor, width: 2.0),
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
        // 🚨 EDITED: Use AppColors for scaffold background
        backgroundColor: AppColors.secondaryButtonColor,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.highlightColor),
        ),
      );
    }

    return Scaffold(
      // 🚨 EDITED: Use AppColors for scaffold background
      backgroundColor: AppColors.secondaryButtonColor,
      body: Stack(
        children: [
          // Background Image
          Container(
            decoration: BoxDecoration(
              color: AppColors.secondaryButtonColor,
              image: DecorationImage(
                image: const AssetImage('assets/biomes/coastal-bg.png'),
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
                    // 🚨 EDITED: Use AppTextStyles.headline for the main title
                    style: AppTextStyles.headline(context, baseSize: 32.0)
                        .copyWith(
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.9),
                              blurRadius: 4,
                              offset: const Offset(3, 3),
                            ),
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
                        _navigateTo(
                          GameScreen(
                            currentUser: _currentUser!,
                            authService: _authService,
                          ),
                        );
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

                  // QUEST Button (Secondary - Visible ONLY when logged in)
                  if (_authStatus == AuthStatus.loggedIn)
                    _buildThemedButton(
                      text: 'QUESTS',
                      icon: Icons.assignment,
                      onPressed: () => _navigateTo(const QuestScreen()),
                      isPrimary: false,
                    ),

                  // SHOP Button
                  if (_authStatus == AuthStatus.loggedIn)
                    _buildThemedButton(
                      text: 'SHOP',
                      icon: Icons.shopping_bag,
                      onPressed: () => _navigateTo(const ShopScreen()),
                      isPrimary: false,
                    ),

                  const SizedBox(height: 50),
                  // User Status (Subtle)
                  Text(
                    'STATUS: ${_authStatus == AuthStatus.guest ? 'GUEST ACCESS' : 'PLAYER ACTIVE'}',
                    textAlign: TextAlign.center,
                    // 🚨 EDITED: Use AppTextStyles.small for subtle status text
                    style:
                        AppTextStyles.small(
                          context,
                          baseSize: 12.0,
                          color: AppColors.highlightColor.withOpacity(0.8),
                        ).copyWith(
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.5),
                              offset: const Offset(1, 1),
                            ),
                          ],
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

PageRouteBuilder _createFadeRoute(Widget page) {
  return PageRouteBuilder(
    // Reduce duration for a snappier feel
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
