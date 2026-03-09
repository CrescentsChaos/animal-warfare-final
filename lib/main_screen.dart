// lib/main_screen.dart

import 'package:flutter/material.dart';
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

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  @override
  void initState() {
    super.initState();
    _playBackgroundMusic();
  }

  Future<void> _playBackgroundMusic() async {
    await AudioService.instance.playMusic('audio/coastal_theme.mp3');
  }

  void _navigateTo(Widget page) {
    AudioService.instance.pauseAll();
    Navigator.of(context).push(_createFadeRoute(page)).then((_) {
      _playBackgroundMusic();
      AudioService.instance.resumeAll();
    });
  }

  void _handleAuthAction(BuildContext ctx) {
    _navigateTo(const LoginScreen());
  }

  Widget _buildNavButton({
    required String text,
    required IconData icon,
    required VoidCallback onPressed,
    bool isPrimary = false,
    Color? accentColor,
  }) {
    final Color accent = accentColor ?? AppColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? accent : AppColors.border,
          width: isPrimary ? 1.5 : 1,
        ),
        boxShadow: isPrimary
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          splashColor: accent.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    text,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
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
                  image: DecorationImage(
                    image: const AssetImage('assets/biomes/coastal-bg.png'),
                    fit: BoxFit.cover,
                    colorFilter: isDay
                        ? ColorFilter.mode(
                            Colors.black.withValues(alpha: 0.75),
                            BlendMode.darken,
                          )
                        : ColorFilter.mode(
                            isEvening
                                ? Colors.orangeAccent.withValues(alpha: 0.3)
                                : Colors.indigo[900]!.withValues(alpha: 0.5),
                            BlendMode.darken,
                          ),
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
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 40.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        // Title
                        Column(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                colors: [
                                  AppColors.highlight,
                                  Color(0xFFFFF8E1),
                                  AppColors.highlight,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ).createShader(bounds),
                              child: const Text(
                                'ANIMAL\nWARFARE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'PressStart2P',
                                  fontSize: 28,
                                  height: 1.6,
                                  letterSpacing: 3,
                                  shadows: [
                                    Shadow(
                                      color: Color(0xFFFFB300),
                                      blurRadius: 20,
                                      offset: Offset(0, 0),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            GameClockWidget(
                              highlightColor: AppColors.highlight,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              height: 2,
                              width: 80,
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
                          ],
                        ),
                        const SizedBox(height: 48),

                        // Buttons
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
                          _buildNavButton(
                            text: 'Start Game',
                            icon: Icons.shield_rounded,
                            onPressed: () {
                              if (currentUser != null) {
                                _navigateTo(
                                  GameScreen(currentUser: currentUser),
                                );
                              } else {
                                _navigateTo(const LoginScreen());
                              }
                            },
                            isPrimary: true,
                            accentColor: AppColors.primary,
                          ),

                          if (!isLoggedIn)
                            _buildNavButton(
                              text: 'Login / Register',
                              icon: Icons.login_rounded,
                              onPressed: () => _handleAuthAction(context),
                              accentColor: AppColors.highlight,
                            ),

                          if (isLoggedIn) ...[
                            _buildNavButton(
                              text: 'Profile',
                              icon: Icons.person_rounded,
                              onPressed: () =>
                                  _navigateTo(const ProfileScreen()),
                              accentColor: AppColors.highlight,
                            ),
                            _buildNavButton(
                              text: 'Quests',
                              icon: Icons.assignment_rounded,
                              onPressed: () => _navigateTo(const QuestScreen()),
                              accentColor: const Color(0xFF7C4DFF),
                            ),
                            _buildNavButton(
                              text: 'Shop',
                              icon: Icons.shopping_bag_rounded,
                              onPressed: () => _navigateTo(const ShopScreen()),
                              accentColor: const Color(0xFFFF6F00),
                            ),
                            _buildNavButton(
                              text: 'Farm',
                              icon: Icons.agriculture_rounded,
                              onPressed: () =>
                                  _navigateTo(const FarmingScreen()),
                              accentColor: Colors.green,
                            ),
                          ],
                        ],

                        const SizedBox(height: 36),

                        // Status
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
                                    color: isLoggedIn
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

PageRouteBuilder _createFadeRoute(Widget page) {
  return PageRouteBuilder(
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}
