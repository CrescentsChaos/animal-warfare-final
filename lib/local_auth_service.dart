// lib/local_auth_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';

// Model to represent a user
class UserData {
  final String username;
  final String password;
  final String avatar;
  final String gender;
  final int money;
  final int stamina;
  final Map<String, dynamic> quizStats;
  final List<String> discoveredOrganisms;
  final List<String> completedAchievements;
  final List<CapturedOrganism> capturedOrganisms;
  /// Index into [capturedOrganisms] for the animal used as attacker in battle. 0 if none chosen.
  final int activeAttackerIndex;

  UserData({
    required this.username,
    required this.password,
    this.avatar = 'default',
    this.gender = 'N/A',
    this.money = 1000,
    this.stamina = 100,
    Map<String, dynamic>? quizStats,
    List<String>? discoveredOrganisms,
    List<String>? completedAchievements,
    List<CapturedOrganism>? capturedOrganisms,
    int? activeAttackerIndex,
  }) : quizStats = quizStats ?? {},
       discoveredOrganisms = discoveredOrganisms ?? [],
       completedAchievements = completedAchievements ?? [],
       capturedOrganisms = capturedOrganisms ?? [],
       activeAttackerIndex = activeAttackerIndex ?? 0;

  UserData copyWith({
    String? username,
    String? password,
    String? avatar,
    String? gender,
    int? money,
    int? stamina,
    Map<String, dynamic>? quizStats,
    List<String>? discoveredOrganisms,
    List<String>? completedAchievements,
    List<CapturedOrganism>? capturedOrganisms,
    int? activeAttackerIndex,
  }) {
    return UserData(
      username: username ?? this.username,
      password: password ?? this.password,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      money: money ?? this.money,
      stamina: stamina ?? this.stamina,
      quizStats: quizStats ?? this.quizStats,
      discoveredOrganisms: discoveredOrganisms ?? this.discoveredOrganisms,
      completedAchievements: completedAchievements ?? this.completedAchievements,
      capturedOrganisms: capturedOrganisms ?? this.capturedOrganisms,
      activeAttackerIndex: activeAttackerIndex ?? this.activeAttackerIndex,
    );
  }

  /// The captured organism currently set as battle attacker, or null if none/invalid.
  CapturedOrganism? get activeAttacker {
    if (capturedOrganisms.isEmpty) return null;
    final i = activeAttackerIndex.clamp(0, capturedOrganisms.length - 1);
    return capturedOrganisms[i];
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
        'stamina': stamina,
        'money': money,
        'quizStats': quizStats,
        'discoveredOrganisms': discoveredOrganisms,
        'completedAchievements': completedAchievements,
        'capturedOrganisms': capturedOrganisms.map((co) => co.toJson()).toList(),
        'activeAttackerIndex': activeAttackerIndex,
      };

  factory UserData.fromJson(Map<String, dynamic> json,{List<Organism>? allOrganisms}) {
    Organism? findBaseOrganism(String name) {
      if (allOrganisms == null) return null;
      try {
        return allOrganisms.firstWhere((org) => org.name == name);
      } catch (_) {
        return null; 
      }
    }
    final List<dynamic> capturedJson = json['capturedOrganisms'] ?? [];
    final List<CapturedOrganism> capturedList = capturedJson.map((coJson) {
      
      // 🚨 FIX: Safely check and cast 'name' to String, providing a fallback if null
      final organismName = coJson['name'] as String?; // Cast to nullable String
      if (organismName == null) {
          return null; // Skip this entry if the name is missing/null
      }
      
      final baseOrganism = findBaseOrganism(organismName);
      
      if (baseOrganism == null) {
        // If the base organism list isn't provided or the organism is missing, skip
        return null; 
      }
      
      // FIX: Also ensure currentHealth is safely handled, though the main error is 'String'
      final currentHealth = coJson['currentHealth'] as int?; 
      if (currentHealth == null) {
          return null;
      }
      
      return CapturedOrganism(
        baseOrganism: baseOrganism,
        // Safely map individualValues as Map<String, int>
        individualValues: Map<String, int>.from(coJson['ivs'] ?? {}),
        currentHealth: currentHealth,
      );
    }).whereType<CapturedOrganism>().toList();
    return UserData(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      avatar: json['avatar'] as String? ?? 'default',
      gender: json['gender'] as String? ?? 'Select Gender',
      stamina: json['stamina'] as int? ?? 100,
      quizStats: (json['quizStats'] as Map<String, dynamic>?) ?? {},
      discoveredOrganisms: (json['discoveredOrganisms'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      completedAchievements: (json['completedAchievements'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      capturedOrganisms: capturedList,
      activeAttackerIndex: json['activeAttackerIndex'] as int? ?? 0,
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
  static Future<List<Organism>> _loadOrganisms() async {
    if (_cachedOrganisms != null) return _cachedOrganisms!;
    try {
      final String response = await rootBundle.loadString(_organismsAssetPath);
      final List<dynamic> data = jsonDecode(response);
      _cachedOrganisms = data.map((e) => Organism.fromJson(e as Map<String, dynamic>)).toList();
      return _cachedOrganisms!;
    } catch (e) {
      if (kDebugMode) print('LocalAuthService: could not load organisms: $e');
      return [];
    }
  }
  
  // Generates the file path for a specific user.
  Future<File> _getUserFile(String username) async {
    final directory = await getApplicationDocumentsDirectory();
    final safeUsername = username.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
    final fileName = '$safeUsername.json';
    final appSubdirectory = '${directory.path}/AnimalWarfare/UserSaves/'; 
    final appDir = Directory(appSubdirectory);
    
    if (!await appDir.exists()) {
        await appDir.create(recursive: true);
    }

    return File('$appSubdirectory$fileName');
  }
  /// Adds a captured organism (read-modify-write). Preserves quiz stats and other data.
  Future<void> addCapturedOrganism(String username, CapturedOrganism newCapture) async {
    final user = await readUserFile(username);
    if (user == null) return;
    final list = List<CapturedOrganism>.from(user.capturedOrganisms)..add(newCapture);
    await _writeUserFile(user.copyWith(capturedOrganisms: list));
  }

  Future<UserData?> readUserFile(String username) async {
    if (_writeLocks[username] != null) {
      if (kDebugMode) {
        print("DEBUG: Waiting for pending write to complete before reading for $username");
      }
      await _writeLocks[username];
    }
    try {
      final file = await _getUserFile(username);
      if (await file.exists()) {
        final contents = await file.readAsString();
        if (kDebugMode) {
          print("DEBUG: Read user file for $username (${await file.length()} bytes)");
        }
        try {
          final userMap = jsonDecode(contents) as Map<String, dynamic>;
          final organisms = await _loadOrganisms();
          return UserData.fromJson(userMap, allOrganisms: organisms.isEmpty ? null : organisms);
        } on FormatException catch (e) {
          if (kDebugMode) {
            print("ERROR: JSON decode failed for $username: $e");
          }
          return null;
        }
      }
      if (kDebugMode) {
         print("DEBUG: User file not found/does not exist for $username."); // NEW: Debug print for missing file
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        // CRITICAL ERROR: File I/O failure (e.g., permissions, pathing)
        print("CRITICAL ERROR: File I/O failure for $username: $e"); 
      }
      return null; 
    }
  }
  Future<void> _writeUserFile(UserData user) async {
    if (_writeLocks[user.username] != null) {
      if (kDebugMode) {
        print("DEBUG: Waiting for existing write operation to complete for ${user.username}");
      }
      await _writeLocks[user.username];
    }
    
    // Create a new write operation
    final writeOperation = _performWrite(user);
    _writeLocks[user.username] = writeOperation;
    
    try {
      await writeOperation;
    } finally {
      // Clear the lock after write completes
      _writeLocks[user.username] = null;
    }
  }
  
  /// Writes user to file. Aborts if file on disk has more quiz types (stale write).
  Future<void> _performWrite(UserData user) async {
    try {
      final file = await _getUserFile(user.username);
      if (await file.exists()) {
        final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final currentQuizCount = (data['quizStats'] as Map?)?.length ?? 0;
        if (currentQuizCount > user.quizStats.length) {
          if (kDebugMode) {
            print("WARNING: Aborted stale write for ${user.username} (file has more quiz data)");
          }
          return;
        }
      }
      await file.writeAsString(jsonEncode(user.toJson()), flush: true);
      if (kDebugMode) {
        print("DEBUG: Saved ${user.username} (quiz keys: ${user.quizStats.length})");
      }
    } catch (e) {
      if (kDebugMode) print("Error writing user ${user.username}: $e");
      rethrow;
    }
  }

  Future<void> updateUser(UserData user) async {
    await _writeUserFile(user);
  }

  // 🚨 FIXED: Renamed from registerUser to register and ensures Future<bool> return type
  Future<bool> register(String username, String password) async {
    if (await readUserFile(username) != null) {
      if (kDebugMode) print("DEBUG: Registration failed for $username (already exists).");
      return false;
    }
    await _writeUserFile(UserData(
      username: username,
      password: password,
      discoveredOrganisms: [],
      completedAchievements: [],
    ));
    return await login(username, password);
  }

  Future<bool> login(String username, String password) async {
    final user = await readUserFile(username);
    if (user == null) {
      if (kDebugMode) print("DEBUG: Login failed for $username (user not found).");
      return false;
    }
    if (user.password != password) {
      if (kDebugMode) print("DEBUG: Login failed for $username (wrong password).");
      return false;
    }
    await _saveCurrentUserName(user.username);
    if (kDebugMode) print("DEBUG: Login successful for $username.");
    return true;
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
  
  Future<void> updateProfile(String username, {String? avatar, String? gender}) async {
    final user = await readUserFile(username);
    if (user != null) {
      await _writeUserFile(user.copyWith(avatar: avatar, gender: gender));
    }
  }
  
  /// Updates quiz stats (read-modify-write). Preserves all other user data.
  Future<void> updateQuizStats(String username, String quizName, bool isCorrect) async {
    final user = await readUserFile(username);
    if (user == null) return;

    final current = Map.from(user.quizStats[quizName] ?? {'attempts': 0, 'correct': 0});
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

  /// Adds organism to discovered list (read-modify-write). Preserves quiz stats etc.
  Future<void> markOrganismAsDiscovered(String username, String organismName) async {
    final user = await readUserFile(username);
    if (user == null) return;

    final discovered = Set<String>.from(user.discoveredOrganisms);
    if (discovered.contains(organismName)) return;
    discovered.add(organismName);
    await _writeUserFile(user.copyWith(discoveredOrganisms: discovered.toList()));
  }
}
