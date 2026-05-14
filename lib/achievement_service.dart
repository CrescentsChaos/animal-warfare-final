// lib/achievement_service.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/models/achievement.dart';

class AchievementService {
  final List<dynamic>
  allOrganisms; // All organisms in Map<String, dynamic> format
  final LocalAuthService authService;

  late List<Achievement> _allAchievements = [];

  AchievementService({required this.allOrganisms, required this.authService}) {
    // NOTE: The synchronous call now uses the public method.
    loadAchievements();
  }

  // --- Initialization ---

  // Loads all achievement definitions from an asset file
  // CHANGED: Removed '_' to make it public, fixing the access error.
  Future<void> loadAchievements() async {
    try {
      // NOTE: Ensure you have an assets/achievements.json file
      final String response = await rootBundle.loadString(
        'assets/achievements.json',
      );
      final List<dynamic> data = json.decode(response);
      _allAchievements = data.map((e) => Achievement.fromJson(e)).toList();
    } catch (e) {
      debugPrint("Error loading achievements: $e");
      _allAchievements = [];
    }
  }

  // --- Core Logic ---

  // Public method to return all defined achievements
  List<Achievement> getAllAchievements() {
    return _allAchievements;
  }

  /// Checks if a user has completed a specific achievement condition.
  bool _isAchievementCompleted(UserData user, Achievement achievement) {
    if (user.completedAchievements.contains(achievement.title)) {
      return true; // Already unlocked
    }

    // --- LOGIC 1: Specific Organisms (e.g., 'African Lion' or '5 Panthera species') ---
    if (achievement.requiredOrganisms.isNotEmpty &&
        achievement.requiredSpecificCount > 0) {
      int specificDiscoveredCount = 0;
      final requiredSet = achievement.requiredOrganisms
          .toSet(); // For O(1) lookup

      // Count how many of the required organisms the user has discovered
      for (String orgName in user.discoveredOrganisms) {
        if (requiredSet.contains(orgName)) {
          specificDiscoveredCount++;
        }
      }

      return specificDiscoveredCount >= achievement.requiredSpecificCount;
    }

    // --- LOGIC 2: Rarity-based achievements (e.g., 'Collect 10 Common') ---
    if (achievement.requiredRarity.isNotEmpty &&
        achievement.requiredCount > 0) {
      // 1. Filter all known organisms by the required rarity
      final requiredOrganisms = allOrganisms
          .where(
            (organism) =>
                organism['rarity'].toLowerCase() ==
                achievement.requiredRarity.toLowerCase(),
          )
          .map((organism) => organism['name'])
          .toSet();

      // 2. Count how many of the required organisms the user has discovered
      int discoveredCount = 0;
      for (String orgName in user.discoveredOrganisms) {
        if (requiredOrganisms.contains(orgName)) {
          discoveredCount++;
        }
      }

      // 3. Check if the discovered count meets the requirement
      return discoveredCount >= achievement.requiredCount;
    }

    // 🆕 LOGIC 3: Total Discovered Count (for achievements like "Discover your first animal")
    // This runs if requiredOrganisms and requiredRarity are empty, but a requiredCount > 0 exists.
    if (achievement.requiredOrganisms.isEmpty &&
        achievement.requiredRarity.isEmpty &&
        achievement.requiredCount > 0 &&
        achievement.requiredFloor <= 0) {
      // Check if the total number of unique discovered organisms meets the required count
      return user.discoveredOrganisms.length >= achievement.requiredCount;
    }

    // 🆕 LOGIC 4: Rogue-like Floor reached
    if (achievement.requiredFloor > 0) {
      return user.rogueLikeState.highestFloor >= achievement.requiredFloor ||
          user.bestRogueFloor >= achievement.requiredFloor;
    }

    // 🆕 LOGIC 5: Quiz-related achievements
    if (achievement.requiredQuizCorrect > 0 ||
        achievement.requiredHardQuizCorrect > 0 ||
        achievement.requiredGenusQuizCorrect > 0 ||
        achievement.requiredQuizStreak > 0) {
      int totalCorrect = 0;
      int totalHardCorrect = 0;
      int totalGenusCorrect = 0;
      int maxStreak = 0;

      user.quizStats.forEach((quizName, data) {
        if (data is Map<String, dynamic>) {
          // Check if new difficulty-based structure
          bool isNewStructure = data.keys.any((k) {
            final lk = k.toLowerCase();
            return lk == 'easy' || lk == 'normal' || lk == 'hard';
          });
          if (isNewStructure) {
            data.forEach((difficulty, stats) {
              if (stats is Map<String, dynamic>) {
                final correct = stats['correct'] as int? ?? 0;
                final streak = stats['bestStreak'] as int? ?? 0;
                totalCorrect += correct;
                if (difficulty.toLowerCase() == 'hard') {
                  totalHardCorrect += correct;
                }
                if (quizName.toLowerCase().contains('genus')) {
                  totalGenusCorrect += correct;
                }
                if (streak > maxStreak) maxStreak = streak;
              }
            });
          } else {
            // Old structure (flat map)
            final correct = data['correct'] as int? ?? 0;
            totalCorrect += correct;
            // Best streak wasn't always tracked in old structure
            final streak = data['bestStreak'] as int? ?? 0;
            if (streak > maxStreak) maxStreak = streak;
          }
        }
      });

      if (achievement.requiredQuizCorrect > 0 &&
          totalCorrect >= achievement.requiredQuizCorrect) {
        return true;
      }
      if (achievement.requiredHardQuizCorrect > 0 &&
          totalHardCorrect >= achievement.requiredHardQuizCorrect) {
        return true;
      }
      if (achievement.requiredGenusQuizCorrect > 0 &&
          totalGenusCorrect >= achievement.requiredGenusQuizCorrect) {
        return true;
      }
      if (achievement.requiredQuizStreak > 0 &&
          maxStreak >= achievement.requiredQuizStreak) {
        return true;
      }
    }

    // 🆕 LOGIC 6: Arcade Game achievements
    if (achievement.requiredEchoWave > 0) {
      final best = _getMaxStat(user.quizStats['echoMemory'], 'correct');
      if (best >= achievement.requiredEchoWave) return true;
    }
    if (achievement.requiredHabitatScore > 0) {
      final best = _getMaxStat(user.quizStats['habitatSort'], 'correct');
      if (best >= achievement.requiredHabitatScore) return true;
    }
    if (achievement.requiredSilhouetteScore > 0) {
      final best = _getMaxStat(user.quizStats['silhouetteSprint'], 'correct');
      if (best >= achievement.requiredSilhouetteScore) return true;
    }
    if (achievement.requiredShowdownStreak > 0) {
      final best = _getMaxStat(user.quizStats['statShowdown'], 'correct');
      if (best >= achievement.requiredShowdownStreak) return true;
    }

    // Default to false if no condition is defined (or invalid achievement object)
    return false;
  }

  int _getMaxStat(dynamic data, String statKey) {
    if (data is Map<String, dynamic>) {
      int maxVal = data[statKey] as int? ?? 0; // Old flat structure

      // Check difficulties
      final difficulties = ['Easy', 'Normal', 'Hard', 'easy', 'normal', 'hard'];
      for (var d in difficulties) {
        final diffData = data[d];
        if (diffData is Map<String, dynamic>) {
          final val = diffData[statKey] as int? ?? 0;
          if (val > maxVal) maxVal = val;
        }
      }
      return maxVal;
    }
    return 0;
  }

  // Helper extension for UserData if it's missing easy floor access
  // Actually, UserData now has bestRogueFloor.
  // Let's use user.bestRogueFloor directly once I'm sure it compiled.
  // For now I'll use a safer check since bestRogueFloor was just added.

  /// Checks all achievements against the user's data and unlocks any newly completed ones.
  List<String> checkAndUnlockAchievements(UserData user) {
    List<String> newlyUnlocked = [];

    // Create a mutable set of the user's current completed achievements titles
    Set<String> completedTitles = Set.from(user.completedAchievements);

    for (var achievement in _allAchievements) {
      if (!completedTitles.contains(achievement.title)) {
        if (_isAchievementCompleted(user, achievement)) {
          // Unlock the achievement
          completedTitles.add(achievement.title);
          newlyUnlocked.add(achievement.title);
        }
      }
    }

    return newlyUnlocked;
  }

  // --- UI Helpers ---

  void showAchievementSnackbar(BuildContext context, String achievementTitle) {
    // Find the achievement object to get its image
    final achievement = _allAchievements.firstWhere(
      (a) => a.title == achievementTitle,
      orElse: () => Achievement(title: achievementTitle, description: ''),
    );

    final imagePath =
        achievement.imagePath ?? 'assets/achievements/medal_bronze.png';

    // 1. Define the duration and the overlay entry
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    const Duration duration = Duration(seconds: 4);

    // 2. The design of the top-aligned notification
    final Widget notificationContent = SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -50 * (1 - value)),
                child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.shade900.withValues(alpha: 0.95),
                      Colors.blue.shade900.withValues(alpha: 0.95),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.purple.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: -10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Medal Image (200x200 placeholder but sized for notification)
                    Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.yellow.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.stars,
                              color: Colors.yellow,
                              size: 80,
                            ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ACHIEVEMENT UNLOCKED',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 2,
                        color: Colors.white70,
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      achievement.title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                        fontFamily: 'PressStart2P',
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 4,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 8,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontFamily: 'PressStart2P',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    // 3. Create the overlay entry with content
    overlayEntry = OverlayEntry(builder: (context) => notificationContent);

    // 4. Insert the notification and automatically remove it after the duration
    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }
}
