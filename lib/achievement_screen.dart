// lib/achievement_screen.dart

import 'package:flutter/material.dart';
// ADDED: Import AchievementService
import 'package:animal_warfare/achievement_service.dart';
// ADDED: Import Achievement model (assuming path)
import 'package:animal_warfare/models/achievement.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/theme.dart';

class AchievementsScreen extends StatefulWidget {
  // CHANGE: StatelessWidget to StatefulWidget
  final UserData currentUser;
  final List<dynamic> allOrganisms;
  final LocalAuthService authService;

  const AchievementsScreen({
    super.key,
    required this.currentUser,
    required this.allOrganisms,
    required this.authService,
  });

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late AchievementService _achievementService;
  List<Achievement> _achievements = [];
  bool _isLoading = true; // NEW: Loading state

  // Custom retro/military colors mapped to premium theme
  static const Color primaryButtonColor = AppColors.primary;
  static const Color secondaryButtonColor = AppColors.surface;
  static const Color highlightColor = AppColors.highlight;
  static const Color neonGreen = AppColors.correctGreen;

  @override
  void initState() {
    super.initState();
    // Initialize the service
    _achievementService = AchievementService(
      allOrganisms: widget.allOrganisms,
      authService: widget.authService,
    );
    // Asynchronously load the achievements and update state
    _loadAchievements();
  }

  // NEW: Asynchronous loading method
  Future<void> _loadAchievements() async {
    // CHANGED: Call the public loadAchievements() method.
    await _achievementService.loadAchievements();
    if (mounted) {
      setState(() {
        _achievements = _achievementService.getAllAchievements();
        _isLoading = false;
      });
    }
  }

  Widget _buildAchievementTile(Achievement achievement, bool completed) {
    final imagePath =
        achievement.imagePath ?? 'assets/achievements/medal_bronze.png';

    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      height: 120, // Give it enough height for the big medal and text
      decoration: BoxDecoration(
        color: completed
            ? primaryButtonColor.withValues(alpha: 0.9)
            : secondaryButtonColor.withValues(alpha: 0.6),
        border: Border.all(
          color: completed ? highlightColor : Colors.white12,
          width: 2.0,
        ),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: completed
            ? [
                BoxShadow(
                  color: highlightColor.withValues(alpha: 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Stack(
        children: [
          Row(
            children: [
              // Medal Image (200x200 placeholder but sized for tile)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Hero(
                  tag: 'medal_${achievement.title}',
                  child: Container(
                    height: 100,
                    width: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: completed
                          ? [
                              BoxShadow(
                                color: Colors.yellow.withValues(alpha: 0.2),
                                blurRadius: 15,
                              ),
                            ]
                          : [],
                    ),
                    child: ColorFiltered(
                      colorFilter: completed
                          ? const ColorFilter.mode(
                              Colors.transparent,
                              BlendMode.dst,
                            )
                          : const ColorFilter.matrix([
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0.2126,
                              0.7152,
                              0.0722,
                              0,
                              0,
                              0,
                              0,
                              0,
                              1,
                              0,
                            ]),
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          completed ? Icons.military_tech : Icons.lock,
                          size: 60,
                          color: completed ? highlightColor : Colors.white24,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12.0,
                    horizontal: 8.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        achievement.title.toUpperCase(),
                        style: TextStyle(
                          color: completed ? highlightColor : Colors.white70,
                          fontFamily: 'PressStart2P',
                          fontSize: 12,
                          shadows: completed
                              ? [
                                  const Shadow(
                                    color: Colors.black,
                                    blurRadius: 2,
                                    offset: Offset(1, 1),
                                  ),
                                ]
                              : [],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        achievement.description,
                        style: TextStyle(
                          color: completed ? Colors.white : Colors.white38,
                          fontFamily: 'PressStart2P',
                          fontSize: 8,
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              if (completed)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Icon(Icons.check_circle, color: neonGreen, size: 24),
                ),
              if (!completed)
                const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Icon(Icons.lock, color: Colors.white12, size: 24),
                ),
            ],
          ),
          if (!completed)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16.0),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ACHIEVEMENTS'),
        backgroundColor: secondaryButtonColor,
        titleTextStyle: const TextStyle(
          color: highlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 16,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: secondaryButtonColor,
          image: DecorationImage(
            image: const AssetImage('assets/main.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.7),
              BlendMode.darken,
            ),
          ),
        ),
        padding: const EdgeInsets.all(10.0),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: highlightColor),
              ) // NEW: Show loading
            : ListView(
                padding: const EdgeInsets.all(10.0),
                // FIX: Use the state variable _achievements
                children: _achievements.map((achievement) {
                  // FIX 2: Change .id to .title (already done, kept for clarity)
                  final bool completed = widget
                      .currentUser
                      .completedAchievements
                      .contains(achievement.title);
                  return _buildAchievementTile(achievement, completed);
                }).toList(),
              ),
      ),
    );
  }
}
