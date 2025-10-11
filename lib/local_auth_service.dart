// lib/local_auth_service.dart

import 'dart:convert';
import 'dart:io'; 
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:path_provider/path_provider.dart'; 

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

  UserData({
    required this.username,
    required this.password,
    this.avatar = 'default',
    this.gender = 'N/A',
    this.money = 1000,
    this.stamina = 100,
    Map<String, dynamic>? quizStats,
    List<String>? discoveredOrganisms,
    List<String>? completedAchievements, // ADDED
  }) : quizStats = quizStats ?? {},
       discoveredOrganisms = discoveredOrganisms ?? [],
       completedAchievements = completedAchievements ?? []; // INITIALIZE

  // Method to create a new UserData instance with optional updated fields
  UserData copyWith({
    String? username,
    String? password,
    String? avatar,
    String? gender,
    int? money,
    int? stamina,
    Map<String, dynamic>? quizStats,
    List<String>? discoveredOrganisms,
    List<String>? completedAchievements, // ADDED
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
      completedAchievements: completedAchievements ?? this.completedAchievements, // ADDED
    );
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
    final newMoney = (money - amount).clamp(0, 100);
    return copyWith(money: newMoney);
  }
  UserData addMoney(int amount) {
    final newMoney = (money + amount).clamp(0, 100);
    return copyWith(money: newMoney);
  }
  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'avatar': avatar,
        'gender': gender,
        'stamina': stamina,
        'quizStats': quizStats,
        'discoveredOrganisms': discoveredOrganisms,
        'completedAchievements': completedAchievements, // ADDED
      };

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      avatar: json['avatar'] as String? ?? 'default',
      gender: json['gender'] as String? ?? 'Select Gender',
      stamina: json['stamina'] as int? ?? 100,
      // Safely deserialize quizStats (handling null or wrong type)
      quizStats: (json['quizStats'] as Map<String, dynamic>?) ?? {},
      // Safely deserialize discoveredOrganisms
      discoveredOrganisms: (json['discoveredOrganisms'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      // ADDED: Safely deserialize completedAchievements
      completedAchievements: (json['completedAchievements'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    );
  }
}

// ------------------------------------------------------------------
// LocalAuthService
// ------------------------------------------------------------------
class LocalAuthService {
  static const _currentKey = 'current_user_username'; 
  
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
  
  // Reads a single user's data from their JSON file
  Future<UserData?> readUserFile(String username) async {
    try {
      final file = await _getUserFile(username);
      if (await file.exists()) {
        final contents = await file.readAsString();
        
        try {
          // NEW: Inner try-catch to specifically handle JSON decoding errors
          final userMap = jsonDecode(contents);
          return UserData.fromJson(userMap);
        } on FormatException catch (e) {
          if (kDebugMode) {
            print("ERROR: JSON decoding failed for user file $username (File Corrupted): $e");
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

  // Writes a single user's data to their JSON file
  Future<void> _writeUserFile(UserData user) async {
    try {
      final file = await _getUserFile(user.username);
      final userJson = jsonEncode(user.toJson());
      await file.writeAsString(userJson);
      if (kDebugMode) {
        print("DEBUG: User data written successfully for ${user.username}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error writing user file for ${user.username}: $e");
      }
    }
  }
  
  // NEW: Generic method for AchievementService to use
  Future<void> updateUser(UserData user) async {
    await _writeUserFile(user);
  }

  // 🚨 FIXED: Renamed from registerUser to register and ensures Future<bool> return type
  Future<bool> register(String username, String password) async {
    final existingUser = await readUserFile(username);
    if (existingUser != null) {
      if (kDebugMode) {
        print("DEBUG: Registration failed for $username. User already exists.");
      }
      return false; // User already exists
    }

    final newUser = UserData(
      username: username, 
      password: password,
      discoveredOrganisms: [], 
      completedAchievements: [], // Initialize new field
    );
    await _writeUserFile(newUser);
    
    // Automatically log the user in after successful registration
    return await login(username, password);
  }

  // 🚨 FIXED: Renamed from loginUser to login and returns Future<bool>
  Future<bool> login(String username, String password) async {
    final foundUser = await readUserFile(username);
    
    if (foundUser != null) {
        if (foundUser.password == password) {
             await _saveCurrentUserName(foundUser.username); 
             if (kDebugMode) {
                 print("DEBUG: Login successful for $username."); // NEW: Success debug print
             }
             return true; // Login success
        } else {
             if (kDebugMode) {
                 // NEW: Explicit password mismatch log
                 print("DEBUG: Login failed for $username. Password mismatch. (Input: '$password', Stored: '${foundUser.password}')"); 
             }
        }
    } else {
        if (kDebugMode) {
            // NEW: Explicit user not found log
            print("DEBUG: Login failed for $username. User not found/file read error (see _readUserFile logs)."); 
        }
    }
    
    return false; // Login failure
  }

  // --- Session Management Logic ---
  Future<void> _saveCurrentUserName(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentKey, username);
  }
  
  // Checks if a user is currently logged in and returns their data
  Future<UserData?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final currentUsername = prefs.getString(_currentKey); 
    
    if (currentUsername == null) {
      return null;
    }
    
    return await readUserFile(currentUsername);
  }

  // Logs out the current user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentKey);
  }
  
  // --- Profile Update Logic ---
  Future<void> updateProfile(String username, {String? avatar, String? gender}) async {
    final user = await readUserFile(username);

    if (user != null) {
      final updatedUser = user.copyWith(
        avatar: avatar,
        gender: gender,
      );
      
      await _writeUserFile(updatedUser);
    }
  }
  
  // Method to update quiz statistics
  Future<void> updateQuizStats(String username, String quizName, bool isCorrect) async {
    final user = await readUserFile(username);

    if (user != null) {
      // Create a mutable copy of the stats map
      final stats = Map<String, dynamic>.from(user.quizStats);
      // Get mutable copy of the specific quiz's data, initializing if necessary
      final quizData = Map<String, dynamic>.from(stats[quizName] ?? {'attempts': 0, 'correct': 0});

      quizData['attempts'] = (quizData['attempts'] as int) + 1;
      quizData['lastAttempt'] = DateTime.now().toIso8601String();

      if (isCorrect) {
        quizData['correct'] = (quizData['correct'] as int) + 1;
      }
      
      stats[quizName] = quizData;
      
      final updatedUser = user.copyWith(quizStats: stats);
      
      await _writeUserFile(updatedUser);
    }
  }
  
  // Method to mark an organism as discovered
  Future<void> markOrganismAsDiscovered(String username, String organismName) async {
    final user = await readUserFile(username);

    if (user != null) {
      // Use a Set for efficient check and prevent duplicates
      final discovered = Set<String>.from(user.discoveredOrganisms);
      
      if (!discovered.contains(organismName)) {
        discovered.add(organismName);
        
        final updatedUser = user.copyWith(discoveredOrganisms: discovered.toList());
        await _writeUserFile(updatedUser);
      }
    }
  }
}
