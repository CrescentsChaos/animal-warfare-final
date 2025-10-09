// lib/achievement_service.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/material.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/models/achievement.dart';

class AchievementService {
  final List<dynamic> allOrganisms; // All organisms in Map<String, dynamic> format
  final LocalAuthService authService;
  
  late List<Achievement> _allAchievements = []; 

  AchievementService({
    required this.allOrganisms,
    required this.authService,
  }) {
    // NOTE: The synchronous call now uses the public method.
    loadAchievements();
  }

  // --- Initialization ---

  // Loads all achievement definitions from an asset file
  // CHANGED: Removed '_' to make it public, fixing the access error.
  Future<void> loadAchievements() async { 
    try {
      // NOTE: Ensure you have an assets/achievements.json file
      final String response = await rootBundle.loadString('assets/achievements.json');
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

    // 1. Filter all known organisms by the required rarity
    final requiredOrganisms = allOrganisms
      .where((organism) => organism['rarity'].toLowerCase() == achievement.requiredRarity.toLowerCase())
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


  /// Checks all achievements against the user's data and unlocks any newly completed ones.
  Future<List<String>> checkAndUnlockAchievements(UserData user) async {
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
    
    // Save updated user data if any achievement was newly unlocked
    if (newlyUnlocked.isNotEmpty) {
      final updatedUser = user.copyWith(completedAchievements: completedTitles.toList());
      // Use the new public updateUser method
      await authService.updateUser(updatedUser); 
    }
    
    return newlyUnlocked;
  }

  // --- UI Helpers ---
  
  void showAchievementSnackbar(BuildContext context, String achievementTitle) {
    // 1. Define the duration and the overlay entry
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;
    const Duration duration = Duration(seconds: 4);

    // 2. The design of the top-aligned notification
    final Widget notificationContent = SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 10.0), // Space from the top edge
          child: Material(
            elevation: 10.0,
            borderRadius: BorderRadius.circular(16.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400), // Max width for tablets/desktop
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.purple.shade700, // Retaining a dramatic color
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min, // Wrap content tightly
                children: [
                  const Icon(Icons.star, color: Colors.yellowAccent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACHIEVEMENT UNLOCKED',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          achievementTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // 3. Create the overlay entry with content
    overlayEntry = OverlayEntry(
      builder: (context) => notificationContent,
    );

    // 4. Insert the notification and automatically remove it after the duration
    overlay.insert(overlayEntry);

    Future.delayed(duration, () {
      overlayEntry.remove();
    });
  }
  }