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
  final Map<String, dynamic> quizStats; 
  final List<String> discoveredOrganisms; 
  // ADDED: List to track completed achievement titles
  final List<String> completedAchievements; 

  UserData({
    required this.username,
    required this.password,
    this.avatar = 'default',
    this.gender = 'N/A',
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
    Map<String, dynamic>? quizStats,
    List<String>? discoveredOrganisms,
    List<String>? completedAchievements, // ADDED
  }) {
    return UserData(
      username: username ?? this.username,
      password: password ?? this.password,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      quizStats: quizStats ?? this.quizStats,
      discoveredOrganisms: discoveredOrganisms ?? this.discoveredOrganisms,
      completedAchievements: completedAchievements ?? this.completedAchievements, // ADDED
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'avatar': avatar,
        'gender': gender,
        'quizStats': quizStats,
        'discoveredOrganisms': discoveredOrganisms,
        'completedAchievements': completedAchievements, // ADDED
      };

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      avatar: json['avatar'] as String? ?? 'default',
      gender: json['gender'] as String? ?? 'N/A',
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
  Future<UserData?> _readUserFile(String username) async {
    try {
      final file = await _getUserFile(username);
      if (await file.exists()) {
        final contents = await file.readAsString();
        final userMap = jsonDecode(contents);
        return UserData.fromJson(userMap);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print("Error reading user file for $username: $e");
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
    final existingUser = await _readUserFile(username);
    if (existingUser != null) {
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
    final foundUser = await _readUserFile(username);
    
    if (foundUser != null && foundUser.password == password) {
      await _saveCurrentUserName(foundUser.username); 
      return true; // Login success
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
    
    return await _readUserFile(currentUsername);
  }

  // Logs out the current user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentKey);
  }
  
  // --- Profile Update Logic ---
  Future<void> updateProfile(String username, {String? avatar, String? gender}) async {
    final user = await _readUserFile(username);

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
    final user = await _readUserFile(username);

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
    final user = await _readUserFile(username);

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