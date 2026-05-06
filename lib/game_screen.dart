// lib/game_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/explore_screen.dart';
import 'package:animal_warfare/anidex_screen.dart';
import 'package:animal_warfare/quiz_screen.dart';
import 'package:animal_warfare/animal_box_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/phone_screen.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/crafting_screen.dart';
import 'package:animal_warfare/tool_screen.dart';
import 'package:animal_warfare/battle_tab_screen.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/biometric_scanner_screen.dart';
import 'package:animal_warfare/theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/widgets/game_clock_widget.dart';

class GameScreen extends StatefulWidget {
  final UserData currentUser;

  const GameScreen({super.key, required this.currentUser});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void initState() {
    super.initState();
    _playBackgroundMusic();
  }

  void _playBackgroundMusic() {
    AudioService.instance.playMusic('audio/main_theme.mp3');
  }

  void _navigateTo(Widget screen) async {
    AudioService.instance.pauseAll();
    await Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    AudioService.instance.resumeAll();
  }

  Widget _buildMenuButton({
    required String text,
    required String subtitle,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          splashColor: color.withValues(alpha: 0.12),
          highlightColor: color.withValues(alpha: 0.06),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.inter(
                          color: AppColors.textSecondary,
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
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'phoneButton',
        onPressed: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, _, _) => const PhoneScreen(),
              transitionsBuilder: (_, animation, _, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        },
        backgroundColor: const Color(0xFF1E1E2E),
        child: const Icon(Icons.smartphone_rounded, color: Colors.cyanAccent),
      ),
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              color: AppColors.background,
              image: DecorationImage(
                image: const AssetImage('assets/main.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.78),
                  BlendMode.darken,
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Title
                  Center(
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              AppColors.highlight,
                              Color(0xFFFFF8E1),
                              AppColors.highlight,
                            ],
                          ).createShader(bounds),
                          child: const Text(
                            'ANIMAL WARFARE',
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
                  ),
                  const SizedBox(height: 36),

                  // Menu buttons
                  _buildMenuButton(
                    text: 'Explore Biomes',
                    subtitle: 'Discover & capture wild animals',
                    icon: Icons.explore_rounded,
                    color: AppColors.primary,
                    onPressed: () {
                      final user =
                          Provider.of<UserState>(
                            context,
                            listen: false,
                          ).currentUser ??
                          widget.currentUser;
                      final authService = LocalAuthService();
                      _navigateTo(
                        ExploreScreen(
                          currentUser: user,
                          authService: authService,
                        ),
                      );
                    },
                  ),

                  _buildMenuButton(
                    text: 'Map & Tools',
                    subtitle: 'Walk through biomes & encounter animals',
                    icon: Icons.map_rounded,
                    color: const Color(0xFF66BB6A),
                    onPressed: () {
                      final userState = Provider.of<UserState>(
                        context,
                        listen: false,
                      );
                      final user = userState.currentUser ?? widget.currentUser;
                      final authService = LocalAuthService();

                      _navigateTo(
                        ToolScreen(
                          currentUser: user,
                          authService: authService,
                        ),
                      );
                    },
                  ),

                  _buildMenuButton(
                    text: 'Battle Arena',
                    subtitle: 'Fight AI, Rogue runs & more',
                    icon: Icons.sports_kabaddi_rounded,
                    color: const Color(0xFFEF5350),
                    onPressed: () => _navigateTo(const BattleTabScreen()),
                  ),

                  _buildMenuButton(
                    text: 'Animal Box',
                    subtitle: 'Manage your collection & team',
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFF42A5F5),
                    onPressed: () => _navigateTo(const AnimalBoxScreen(teamOnly: true)),
                  ),

                  _buildMenuButton(
                    text: 'Inventory',
                    subtitle: 'Manage items & forging',
                    icon: Icons.auto_awesome_rounded,
                    color: const Color(0xFFFFB300),
                    onPressed: () => _navigateTo(const CraftingScreen()),
                  ),

                  _buildMenuButton(
                    text: 'Animal Dex',
                    subtitle: 'Browse the full species database',
                    icon: Icons.pets_rounded,
                    color: const Color(0xFFAB47BC),
                    onPressed: () {
                      final user =
                          Provider.of<UserState>(
                            context,
                            listen: false,
                          ).currentUser ??
                          widget.currentUser;
                      final authService = LocalAuthService();
                      _navigateTo(
                        AnidexScreen(
                          currentUser: user,
                          authService: authService,
                        ),
                      );
                    },
                  ),

                  _buildMenuButton(
                    text: 'Animal Quiz',
                    subtitle: 'Test your knowledge',
                    icon: Icons.quiz_rounded,
                    color: const Color(0xFF26A69A),
                    onPressed: () => _navigateTo(
                      QuizScreen(
                        currentUser:
                            Provider.of<UserState>(
                              context,
                              listen: false,
                            ).currentUser ??
                            widget.currentUser,
                        authService: LocalAuthService(),
                      ),
                    ),
                  ),

                  _buildMenuButton(
                    text: 'Bio-Scanner',
                    subtitle: 'Identify animals in the wild',
                    icon: Icons.fingerprint_rounded,
                    color: Colors.cyanAccent,
                    onPressed: () => _navigateTo(
                      BiometricScannerScreen(onBack: () => Navigator.pop(context)),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'v$kAppVersion',
                      style: GoogleFonts.inter(
                        color: AppColors.textMuted.withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
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
