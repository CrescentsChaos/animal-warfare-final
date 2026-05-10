// lib/main_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:animal_warfare/login_screen.dart';
import 'package:animal_warfare/profile_screen.dart';
import 'package:animal_warfare/game_screen.dart';
import 'package:animal_warfare/quest_screen.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/shop_screen.dart';
import 'package:animal_warfare/farming_screen.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/widgets/game_clock_widget.dart';
import 'package:animal_warfare/services/haptic_service.dart';
import 'package:animal_warfare/utils/transitions.dart';
import 'package:animal_warfare/settings_screen.dart';
import 'package:animal_warfare/achievement_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/widgets/pop_menu_layout.dart';
import 'dart:convert';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  double _buttonsOpacity = 0.0;
  List<dynamic> _allOrganisms = [];

  @override
  void initState() {
    super.initState();
    _playBackgroundMusic();
    _loadOrganisms();
    // Fade in the button list after a short delay for a polished entry feel
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _buttonsOpacity = 1.0);
    });
  }

  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      if (mounted) {
        setState(() {
          _allOrganisms = json.decode(response);
        });
      }
    } catch (e) {
      debugPrint('Error loading Organisms.json: $e');
    }
  }

  Future<void> _playBackgroundMusic() async {
    await AudioService.instance.playMusic('audio/coastal_theme.mp3');
  }

  void _navigateTo(Widget page, {bool isGame = false}) {
    HapticService.light();
    AudioService.instance.pauseAll();
    final route = isGame
        ? createFadeScaleRoute(page)
        : createSlideUpRoute(page);
    Navigator.of(context).push(route).then((_) {
      _playBackgroundMusic();
      AudioService.instance.resumeAll();
    });
  }

  void _handleAuthAction(BuildContext ctx) {
    _navigateTo(const LoginScreen());
  }

  Widget _buildMenuButton({
    required String text,
    required String subtitle,
    required String iconPath,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Image.asset(
                  iconPath,
                  width: 56,
                  height: 56,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => 
                    Icon(
                      Icons.error_outline,
                      color: color ?? Colors.white54,
                      size: 28,
                    ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        text,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.6),
                  size: 22,
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
    final userState = context.watch<UserState>();
    final currentUser = userState.currentUser;
    final isLoggedIn = userState.isLoggedIn;
    final isInitialized = userState.isInitialized;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: StreamBuilder<GameTime>(
        stream: TimeService().timeStream,
        builder: (context, snapshot) {
          final hour = TimeService().currentGameTime.hour;
          final isDay = hour >= 6 && hour < 18;
          final isEvening = hour >= 18 && hour < 21;

          return Stack(
            children: [
              // Background image
              Container(
                decoration: BoxDecoration(
                  color: AppColors.background,
                  image: const DecorationImage(
                    image: AssetImage('assets/biomes/coastal-bg.png'),
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Subtle radial gradient overlay for depth
              Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5,
                    colors: [
                      AppColors.primary.withValues(alpha: 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Content
              SafeArea(
                child: PopMenuLayout(
                  header: Column(
                    children: [
                      // Title
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            AppColors.highlight,
                            Color(0xFFFFF8E1),
                            AppColors.highlight,
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          'ANIMAL WARFARE.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontFamily: 'PressStart2P',
                            height: 1.4,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GameClockWidget(highlightColor: AppColors.highlight),
                      const SizedBox(height: 4),
                      Text(
                        'Choose your path, Commander',
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  items: [
                    if (!isInitialized)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40.0),
                          child: CircularProgressIndicator(
                            color: AppColors.highlight,
                          ),
                        ),
                      )
                    else ...[
                      _buildMenuButton(
                        text: 'Start Game',
                        subtitle: 'Embark on your journey',
                        iconPath: 'assets/icon/start_game.png',
                        color: AppColors.primary,
                        onPressed: () {
                          if (currentUser != null) {
                            _navigateTo(
                              GameScreen(currentUser: currentUser),
                              isGame: true,
                            );
                          } else {
                            _navigateTo(const LoginScreen());
                          }
                        },
                      ),
                      if (!isLoggedIn)
                        _buildMenuButton(
                          text: 'Login / Register',
                          subtitle: 'Access your cloud save',
                          iconPath: 'assets/icon/profile.png',
                          color: AppColors.highlight,
                          onPressed: () => _handleAuthAction(context),
                        ),
                      if (isLoggedIn) ...[
                        _buildMenuButton(
                          text: 'Profile',
                          subtitle: 'View your stats & medals',
                          iconPath: 'assets/icon/profile.png',
                          color: AppColors.highlight,
                          onPressed: () => _navigateTo(const ProfileScreen()),
                        ),
                        _buildMenuButton(
                          text: 'Quests',
                          subtitle: 'Complete daily missions',
                          iconPath: 'assets/icon/quests.png',
                          color: const Color(0xFF7C4DFF),
                          onPressed: () => _navigateTo(const QuestScreen()),
                        ),
                        _buildMenuButton(
                          text: 'Shop',
                          subtitle: 'Purchase items & upgrades',
                          iconPath: 'assets/icon/shop.png',
                          color: const Color(0xFFFF6F00),
                          onPressed: () => _navigateTo(const ShopScreen()),
                        ),
                        _buildMenuButton(
                          text: 'Farm',
                          subtitle: 'Manage your resources',
                          iconPath: 'assets/icon/farm.png',
                          color: Colors.green,
                          onPressed: () => _navigateTo(const FarmingScreen()),
                        ),
                        _buildMenuButton(
                          text: 'Achievements',
                          subtitle: 'View your medals & milestones',
                          iconPath: 'assets/icon/achievements.png',
                          color: const Color(0xFFDAA520),
                          onPressed: () => _navigateTo(
                            AchievementsScreen(
                              currentUser: currentUser!,
                              allOrganisms: _allOrganisms,
                              authService: LocalAuthService(),
                            ),
                          ),
                        ),
                        _buildMenuButton(
                          text: 'Settings',
                          subtitle: 'Audio, Account & Preferences',
                          iconPath: 'assets/icon/settings.png',
                          color: Colors.blueGrey,
                          onPressed: () => _navigateTo(
                            SettingsScreen(
                              currentUser: currentUser!,
                              authService: LocalAuthService(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                  footer: [
                    const SizedBox(height: 32),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color:
                                    isLoggedIn
                                        ? AppColors.primary
                                        : AppColors.textMuted,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isLoggedIn ? 'Player Active' : 'Guest Access',
                              style: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// Navigation routes are provided by lib/utils/transitions.dart
