// lib/local_auth_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/quest.dart';
import 'package:animal_warfare/models/rogue_like_state.dart';

import 'local_auth_storage_io.dart'
    if (dart.library.html) 'local_auth_storage_web.dart'
    as user_storage;

// Model to represent a user
class UserData {
  final String username;
  final String password;
  final String avatar;
  final String gender;

  // --- Character Customization Fields ---
  /// Player's chosen display name (can differ from login username)
  final String displayName;

  /// Built-in character portrait key, e.g. 'm_warrior', 'f_ranger'
  final String avatarIconKey;

  /// Player's chosen faction: 'Wilderness', 'Ocean', 'Sky', 'Shadow'
  final String faction;

  /// Starting title / rank label, e.g. 'Novice Tamer'
  final String title;

  /// Short player bio (max 80 chars)
  final String bio;

  final int money; // Currency
  final int stamina;
  final Map<String, dynamic> quizStats;
  final List<String> discoveredOrganisms;
  final List<String> completedAchievements;
  final List<CapturedOrganism> capturedOrganisms;

  /// Inventory: map from loot_id to quantity
  final Map<String, int> inventory;

  /// Crafted talismans (owned but not equipped)
  final List<String> craftedTalismans; // List of talisman IDs
  final List<Quest> activeQuests;

  /// Indices into [capturedOrganisms] for the 5-animal team
  final List<int> battleTeam;

  /// State of the current rogue-like run
  final RogueLikeState rogueLikeState;

  /// Best records for Rogue-like
  final int bestRogueFloor;
  final List<CapturedOrganism> bestRogueTeam;
  final int accountLevel;
  final int accountXP;
  final Map<String, Map<String, int>> speciesStats;
  final Map<String, CapturedOrganism?>
  explorationEncounters; // biome -> encounter
  final Map<String, dynamic> weatherData; // biome -> weather info

  UserData({
    required this.username,
    required this.password,
    this.avatar = 'default',
    this.gender = 'N/A',
    this.displayName = '',
    this.avatarIconKey = '',
    this.faction = '',
    this.title = '',
    this.bio = '',
    this.money = 1000,
    this.stamina = 100,
    Map<String, dynamic>? quizStats,
    List<String>? discoveredOrganisms,
    List<String>? completedAchievements,
    List<CapturedOrganism>? capturedOrganisms,
    Map<String, int>? inventory,
    List<String>? craftedTalismans,
    List<Quest>? activeQuests,
    List<int>? battleTeam,
    RogueLikeState? rogueLikeState,
    this.bestRogueFloor = 0,
    this.bestRogueTeam = const [],
    this.accountLevel = 1,
    this.accountXP = 0,
    Map<String, Map<String, int>>? speciesStats,
    Map<String, CapturedOrganism?>? explorationEncounters,
    Map<String, dynamic>? weatherData,
  }) : quizStats = quizStats ?? {},
       discoveredOrganisms = discoveredOrganisms ?? [],
       completedAchievements = completedAchievements ?? [],
       capturedOrganisms = capturedOrganisms ?? [],
       inventory = inventory ?? {},
       craftedTalismans = craftedTalismans ?? [],
       activeQuests = activeQuests ?? [],
       battleTeam = battleTeam ?? [],
       rogueLikeState = rogueLikeState ?? const RogueLikeState(),
       speciesStats = speciesStats ?? {},
       explorationEncounters = explorationEncounters ?? {},
       weatherData = weatherData ?? {};

  /// Returns displayName if set, otherwise falls back to username
  String get effectiveDisplayName =>
      displayName.isNotEmpty ? displayName : username;

  UserData copyWith({
    String? username,
    String? password,
    String? avatar,
    String? gender,
    String? displayName,
    String? avatarIconKey,
    String? faction,
    String? title,
    String? bio,
    int? money,
    int? stamina,
    Map<String, dynamic>? quizStats,
    List<String>? discoveredOrganisms,
    List<String>? completedAchievements,
    List<CapturedOrganism>? capturedOrganisms,
    Map<String, int>? inventory,
    List<String>? craftedTalismans,
    List<Quest>? activeQuests,
    List<int>? battleTeam,
    RogueLikeState? rogueLikeState,
    int? bestRogueFloor,
    List<CapturedOrganism>? bestRogueTeam,
    int? accountLevel,
    int? accountXP,
    Map<String, Map<String, int>>? speciesStats,
    Map<String, CapturedOrganism?>? explorationEncounters,
    Map<String, dynamic>? weatherData,
  }) {
    return UserData(
      username: username ?? this.username,
      password: password ?? this.password,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      displayName: displayName ?? this.displayName,
      avatarIconKey: avatarIconKey ?? this.avatarIconKey,
      faction: faction ?? this.faction,
      title: title ?? this.title,
      bio: bio ?? this.bio,
      money: money ?? this.money,
      stamina: stamina ?? this.stamina,
      quizStats: quizStats ?? this.quizStats,
      discoveredOrganisms: discoveredOrganisms ?? this.discoveredOrganisms,
      completedAchievements:
          completedAchievements ?? this.completedAchievements,
      capturedOrganisms: capturedOrganisms ?? this.capturedOrganisms,
      inventory: inventory ?? this.inventory,
      craftedTalismans: craftedTalismans ?? this.craftedTalismans,
      activeQuests: activeQuests ?? this.activeQuests,
      battleTeam: battleTeam ?? this.battleTeam,
      rogueLikeState: rogueLikeState ?? this.rogueLikeState,
      bestRogueFloor: bestRogueFloor ?? this.bestRogueFloor,
      bestRogueTeam: bestRogueTeam ?? this.bestRogueTeam,
      accountLevel: accountLevel ?? this.accountLevel,
      accountXP: accountXP ?? this.accountXP,
      speciesStats: speciesStats ?? this.speciesStats,
      explorationEncounters:
          explorationEncounters ?? this.explorationEncounters,
      weatherData: weatherData ?? this.weatherData,
    );
  }

  /// The 5 animals in the battle team
  List<CapturedOrganism> get teamOrganisms {
    return battleTeam
        .where((index) => index >= 0 && index < capturedOrganisms.length)
        .map((index) => capturedOrganisms[index])
        .toList();
  }

  String get rankName {
    if (accountLevel >= 100) return 'MYTHICAL';
    if (accountLevel >= 80) return 'EMERALD';
    if (accountLevel >= 70) return 'DIAMOND';
    if (accountLevel >= 60) return 'PLATINUM';
    if (accountLevel >= 50) return 'MASTER';
    if (accountLevel >= 40) return 'GOLD';
    if (accountLevel >= 30) return 'SILVER';
    if (accountLevel >= 20) return 'BRONZE';
    return 'ROOKIE';
  }

  Color get rankColor {
    if (accountLevel >= 100) return Colors.redAccent;
    if (accountLevel >= 80) return Colors.greenAccent;
    if (accountLevel >= 70) return Colors.cyanAccent;
    if (accountLevel >= 60) return Colors.blueGrey;
    if (accountLevel >= 50) return const Color(0xFFDAA520); // Master Gold
    if (accountLevel >= 40) return Colors.orangeAccent;
    if (accountLevel >= 30) return Colors.white70;
    if (accountLevel >= 20) return Colors.brown;
    return Colors.grey;
  }

  UserData decreaseStamina(int amount) {
    final newStamina = (stamina - amount).clamp(0, 100);
    return copyWith(stamina: newStamina);
  }

  UserData restoreStamina(int amount) {
    final newStamina = (stamina + amount).clamp(0, 100);
    return copyWith(stamina: newStamina);
  }

  UserData spendMoney(int amount) {
    final newMoney = (money - amount);
    return copyWith(money: newMoney);
  }

  UserData addMoney(int amount) {
    final newMoney = (money + amount);
    return copyWith(money: newMoney);
  }

  Map<String, dynamic> toJson() => {
    'username': username,
    'password': password,
    'avatar': avatar,
    'gender': gender,
    'displayName': displayName,
    'avatarIconKey': avatarIconKey,
    'faction': faction,
    'title': title,
    'bio': bio,
    'stamina': stamina,
    'money': money,
    'quizStats': quizStats,
    'discoveredOrganisms': discoveredOrganisms,
    'completedAchievements': completedAchievements,
    'capturedOrganisms': capturedOrganisms.map((co) => co.toJson()).toList(),
    'inventory': inventory,
    'craftedTalismans': craftedTalismans,
    'activeQuests': activeQuests.map((q) => q.toJson()).toList(),
    'battleTeam': battleTeam,
    'rogueLikeState': rogueLikeState.toJson(),
    'bestRogueFloor': bestRogueFloor,
    'bestRogueTeam': bestRogueTeam.map((co) => co.toJson()).toList(),
    'accountLevel': accountLevel,
    'accountXP': accountXP,
    'speciesStats': speciesStats,
    'explorationEncounters': explorationEncounters.map(
      (k, v) => MapEntry(k, v?.toJson()),
    ),
    'weatherData': weatherData,
  };

  factory UserData.fromJson(
    Map<String, dynamic> json, {
    List<Organism>? allOrganisms,
  }) {
    Organism? findBaseOrganism(String name) {
      if (allOrganisms == null) return null;
      try {
        return allOrganisms.firstWhere((org) => org.name == name);
      } catch (_) {
        return null;
      }
    }

    final List<dynamic> capturedJson = json['capturedOrganisms'] ?? [];
    final List<CapturedOrganism> capturedList = capturedJson
        .map((coJson) {
          final organismName = coJson['name'] as String?;
          if (organismName == null) {
            return null;
          }

          final baseOrganism = findBaseOrganism(organismName);

          if (baseOrganism == null) {
            return null;
          }

          return CapturedOrganism.fromJson(coJson, [baseOrganism]);
        })
        .whereType<CapturedOrganism>()
        .toList();
    return UserData(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      avatar: json['avatar'] as String? ?? 'default',
      gender: json['gender'] as String? ?? 'N/A',
      displayName: json['displayName'] as String? ?? '',
      avatarIconKey: json['avatarIconKey'] as String? ?? '',
      faction: json['faction'] as String? ?? '',
      title: json['title'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
      money: json['money'] as int? ?? 1000,
      stamina: json['stamina'] as int? ?? 100,
      quizStats: (json['quizStats'] as Map<String, dynamic>?) ?? {},
      discoveredOrganisms:
          (json['discoveredOrganisms'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      completedAchievements:
          (json['completedAchievements'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      capturedOrganisms: capturedList,
      inventory: json['inventory'] != null
          ? Map<String, int>.from(json['inventory'] as Map)
          : {},
      craftedTalismans:
          (json['craftedTalismans'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      activeQuests:
          (json['activeQuests'] as List<dynamic>?)
              ?.map((q) => Quest.fromJson(q as Map<String, dynamic>))
              .toList() ??
          [],
      battleTeam:
          (json['battleTeam'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      rogueLikeState: json['rogueLikeState'] != null
          ? RogueLikeState.fromJson(
              json['rogueLikeState'] as Map<String, dynamic>,
              allOrganisms ?? [],
            )
          : const RogueLikeState(),
      bestRogueFloor: json['bestRogueFloor'] as int? ?? 0,
      bestRogueTeam: (json['bestRogueTeam'] as List? ?? [])
          .map((coJson) {
            final organismName = coJson['name'] as String?;
            if (organismName == null) return null;
            final base = findBaseOrganism(organismName);
            return base != null
                ? CapturedOrganism.fromJson(coJson, [base])
                : null;
          })
          .whereType<CapturedOrganism>()
          .toList(),
      accountLevel: json['accountLevel'] as int? ?? 1,
      accountXP: json['accountXP'] as int? ?? 0,
      speciesStats:
          (json['speciesStats'] as Map?)?.map(
            (k, v) => MapEntry(
              k as String,
              (v as Map).map((ki, vi) => MapEntry(ki as String, vi as int)),
            ),
          ) ??
          {},
      explorationEncounters:
          (json['explorationEncounters'] as Map?)?.map(
            (k, v) => MapEntry(
              k as String,
              v != null
                  ? CapturedOrganism.fromJson(
                      v as Map<String, dynamic>,
                      allOrganisms ?? [],
                    )
                  : null,
            ),
          ) ??
          {},
      weatherData: (json['weatherData'] as Map?)?.cast<String, dynamic>() ?? {},
    );
  }
}

// ------------------------------------------------------------------
// LocalAuthService
// ------------------------------------------------------------------
class LocalAuthService {
  static const _currentKey = 'current_user_username';
  static const _organismsAssetPath = 'assets/Organisms.json';

  /// Prevents concurrent writes to the same user file.
  final Map<String, Future<void>?> _writeLocks = {};

  static List<Organism>? _cachedOrganisms;
  static Future<List<Organism>> loadOrganisms() async {
    if (_cachedOrganisms != null) return _cachedOrganisms!;
    try {
      final String response = await rootBundle.loadString(_organismsAssetPath);
      final List<dynamic> data = jsonDecode(response);
      _cachedOrganisms = data
          .map((e) => Organism.fromJson(e as Map<String, dynamic>))
          .toList();
      return _cachedOrganisms!;
    } catch (e) {
      if (kDebugMode) print('LocalAuthService: could not load organisms: $e');
      return [];
    }
  }

  static List<Organism> getCachedOrganisms() => _cachedOrganisms ?? [];

  Future<UserData?> readUserFile(String username) async {
    if (_writeLocks[username] != null) {
      if (kDebugMode) {
        print(
          "DEBUG: Waiting for pending write to complete before reading for $username",
        );
      }
      await _writeLocks[username];
    }
    try {
      final contents = await user_storage.readUserData(username);
      if (contents == null) {
        if (kDebugMode) {
          print("DEBUG: User file not found/does not exist for $username.");
        }
        return null;
      }
      try {
        final userMap = _robustJsonDecode(contents, username);
        final organisms = await loadOrganisms();
        return UserData.fromJson(
          userMap,
          allOrganisms: organisms.isEmpty ? null : organisms,
        );
      } catch (e) {
        if (kDebugMode) {
          print("ERROR: JSON decode failed for $username: $e");
        }
        return null;
      }
    } catch (e) {
      if (kDebugMode) {
        print("CRITICAL ERROR: Storage failure for $username: $e");
      }
      return null;
    }
  }

  Map<String, dynamic> _robustJsonDecode(String contents, String username) {
    if (contents.trim().isEmpty) {
      throw const FormatException("Empty JSON content");
    }
    try {
      return jsonDecode(contents) as Map<String, dynamic>;
    } catch (e) {
      // Recovery attempt: strip trailing junk characters by searching for valid closing brace from the end
      if (kDebugMode) {
        print("DEBUG: Attempting robust JSON recovery for $username...");
      }
      int index = contents.lastIndexOf('}');
      while (index != -1) {
        try {
          final cleaned = contents.substring(0, index + 1);
          final decoded = jsonDecode(cleaned);
          if (decoded is Map<String, dynamic>) {
            if (kDebugMode) {
              print(
                "DEBUG: Successfully recovered JSON for $username at index $index.",
              );
            }
            return decoded;
          }
        } catch (_) {
          // ignore and keep searching backwards
        }
        if (index <= 0) break;
        index = contents.lastIndexOf('}', index - 1);
      }
      rethrow;
    }
  }

  Future<void> _writeUserFile(UserData user) async {
    if (_writeLocks[user.username] != null) {
      if (kDebugMode) {
        print(
          "DEBUG: Waiting for existing write operation to complete for ${user.username}",
        );
      }
      await _writeLocks[user.username];
    }

    final writeOperation = _performWrite(user);
    _writeLocks[user.username] = writeOperation;

    try {
      await writeOperation;
    } finally {
      _writeLocks[user.username] = null;
    }
  }

  Future<void> _performWrite(UserData user) async {
    try {
      final contents = await user_storage.readUserData(user.username);
      if (contents != null) {
        try {
          final data = _robustJsonDecode(contents, user.username);
          final currentQuizCount = (data['quizStats'] as Map?)?.length ?? 0;
          if (currentQuizCount > user.quizStats.length) {
            if (kDebugMode) {
              print(
                "WARNING: Aborted stale write for ${user.username} (file has more quiz data)",
              );
            }
            return;
          }
        } catch (e) {
          if (kDebugMode) {
            print(
              "WARNING: Failed to decode existing file for ${user.username} during write: $e. Proceeding with atomic write to fix corruption.",
            );
          }
          // If the file is so corrupted that recovery fails, we MUST proceed with the write
          // to overwrite the corruption with a fresh, valid JSON state.
        }
      }
      await user_storage.writeUserData(
        user.username,
        jsonEncode(user.toJson()),
      );
      if (kDebugMode) {
        print(
          "DEBUG: Saved ${user.username} (quiz keys: ${user.quizStats.length})",
        );
      }
    } catch (e) {
      if (kDebugMode) print("Error writing user ${user.username}: $e");
      rethrow;
    }
  }

  Future<void> updateUser(UserData user) async {
    await _writeUserFile(user);
  }

  Future<bool> register(
    String username,
    String password, {
    String displayName = '',
    String gender = 'N/A',
    String avatarIconKey = '',
    String faction = '',
    String title = '',
    String bio = '',
  }) async {
    if (await readUserFile(username) != null) {
      if (kDebugMode) {
        print("DEBUG: Registration failed for $username (already exists).");
      }
      return false;
    }
    await _writeUserFile(
      UserData(
        username: username,
        password: password,
        displayName: displayName,
        gender: gender,
        avatarIconKey: avatarIconKey,
        faction: faction,
        title: title,
        bio: bio,
        discoveredOrganisms: [],
        completedAchievements: [],
        inventory: {'capture_net': 10},
      ),
    );
    return await login(username, password);
  }

  Future<bool> login(String username, String password) async {
    final user = await readUserFile(username);
    if (user == null) {
      if (kDebugMode) {
        print("DEBUG: Login failed for $username (user not found).");
      }
      return false;
    }
    if (user.password != password) {
      if (kDebugMode) {
        print("DEBUG: Login failed for $username (wrong password).");
      }
      return false;
    }
    await _saveCurrentUserName(user.username);
    if (kDebugMode) print("DEBUG: Login successful for $username.");
    return true;
  }

  /// Reset password for an existing user. Returns true if successful.
  Future<bool> resetPassword(String username, String newPassword) async {
    final user = await readUserFile(username);
    if (user == null) {
      if (kDebugMode) {
        print("DEBUG: Password reset failed for $username (user not found).");
      }
      return false;
    }
    await _writeUserFile(user.copyWith(password: newPassword));
    if (kDebugMode) print("DEBUG: Password reset successful for $username.");
    return true;
  }

  /// Import user data from a JSON string, write it to disk, and set it as the active user.
  Future<bool> importUser(String jsonContent) async {
    try {
      final data = _robustJsonDecode(jsonContent, 'imported_user');
      final username = data['username'] as String?;

      if (username == null || username.isEmpty) {
        if (kDebugMode)
          print("ERROR: Imported JSON is missing a valid username.");
        return false;
      }

      final organisms = await loadOrganisms();
      final userData = UserData.fromJson(
        data,
        allOrganisms: organisms.isEmpty ? null : organisms,
      );

      await _writeUserFile(userData);
      await _saveCurrentUserName(username);

      if (kDebugMode) print("DEBUG: Import successful for $username.");
      return true;
    } catch (e) {
      if (kDebugMode) print("ERROR: Failed to import user: $e");
      return false;
    }
  }

  Future<void> _saveCurrentUserName(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentKey, username);
  }

  Future<UserData?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUsername = prefs.getString(_currentKey);

    if (currentUsername == null) {
      return null;
    }

    return await readUserFile(currentUsername);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentKey);
  }

  Future<void> updateProfile(
    String username, {
    String? avatar,
    String? gender,
    String? displayName,
    String? avatarIconKey,
    String? faction,
    String? title,
    String? bio,
  }) async {
    final user = await readUserFile(username);
    if (user != null) {
      await _writeUserFile(
        user.copyWith(
          avatar: avatar,
          gender: gender,
          displayName: displayName,
          avatarIconKey: avatarIconKey,
          faction: faction,
          title: title,
          bio: bio,
        ),
      );
    }
  }

  Future<void> addCapturedOrganism(
    String username,
    CapturedOrganism newCapture,
  ) async {
    final user = await readUserFile(username);
    if (user == null) return;
    final list = List<CapturedOrganism>.from(user.capturedOrganisms)
      ..add(newCapture);
    await _writeUserFile(user.copyWith(capturedOrganisms: list));
  }

  Future<void> updateQuizStats(
    String username,
    String quizName,
    bool isCorrect,
  ) async {
    final user = await readUserFile(username);
    if (user == null) return;

    final current = Map.from(
      user.quizStats[quizName] ?? {'attempts': 0, 'correct': 0},
    );
    final newStats = {
      ...user.quizStats,
      quizName: {
        ...current,
        'attempts': (current['attempts'] as int) + 1,
        'correct': (current['correct'] as int) + (isCorrect ? 1 : 0),
        'lastAttempt': DateTime.now().toIso8601String(),
      },
    };
    await _writeUserFile(user.copyWith(quizStats: newStats));
  }

  Future<void> markOrganismAsDiscovered(
    String username,
    String organismName,
  ) async {
    final user = await readUserFile(username);
    if (user == null) return;

    final discovered = Set<String>.from(user.discoveredOrganisms);
    if (discovered.contains(organismName)) return;
    discovered.add(organismName);
    await _writeUserFile(
      user.copyWith(discoveredOrganisms: discovered.toList()),
    );
  }
}
