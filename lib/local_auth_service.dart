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
  // START NEW: Quiz Stats
  final Map<String, dynamic> quizStats; // Stores {quizName: {attempts: 5, correct: 3, lastAttempt: timestamp}}
  // END NEW
  // START NEW DISCOVERY TRACKING
  final List<String> discoveredOrganisms; // Stores names of discovered organisms
  // END NEW DISCOVERY TRACKING

  UserData({
    required this.username,
    required this.password,
    this.avatar = 'default',
    this.gender = 'N/A',
    // START NEW
    Map<String, dynamic>? quizStats,
    // END NEW
    // START NEW DISCOVERY TRACKING
    List<String>? discoveredOrganisms,
    // END NEW DISCOVERY TRACKING
  }) : quizStats = quizStats ?? {},
       // START NEW DISCOVERY TRACKING
       discoveredOrganisms = discoveredOrganisms ?? [];
       // END NEW DISCOVERY TRACKING

  // Method to create a new UserData instance with optional updated fields
  UserData copyWith({
    String? username,
    String? password,
    String? avatar,
    String? gender,
    // START NEW
    Map<String, dynamic>? quizStats,
    // END NEW
    // START NEW DISCOVERY TRACKING
    List<String>? discoveredOrganisms,
    // END NEW DISCOVERY TRACKING
  }) {
    return UserData(
      username: username ?? this.username,
      password: password ?? this.password,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
      // START NEW
      quizStats: quizStats ?? this.quizStats,
      // END NEW
      // START NEW DISCOVERY TRACKING
      discoveredOrganisms: discoveredOrganisms ?? this.discoveredOrganisms,
      // END NEW DISCOVERY TRACKING
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'avatar': avatar,
        'gender': gender,
        // START NEW
        'quizStats': quizStats,
        // END NEW
        // START NEW DISCOVERY TRACKING
        'discoveredOrganisms': discoveredOrganisms,
        // END NEW DISCOVERY TRACKING
      };

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      avatar: json['avatar'] as String? ?? 'default',
      gender: json['gender'] as String? ?? 'N/A',
      // START NEW
      // Safely deserialize quizStats (handling null or wrong type)
      quizStats: (json['quizStats'] as Map<String, dynamic>?) ?? {},
      // END NEW
      // START NEW DISCOVERY TRACKING
      // Safely deserialize discoveredOrganisms
      discoveredOrganisms: (json['discoveredOrganisms'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      // END NEW DISCOVERY TRACKING
    );
  }
}

// ------------------------------------------------------------------
// LocalAuthService
// Handles file operations, login, registration, and user session
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
  
  // Attempts to register a new user (renamed for compatibility)
  Future<bool> registerUser(String username, String password) async {
    final existingUser = await _readUserFile(username);
    if (existingUser != null) {
      return false; // User already exists
    }

    // UPDATED: Create new user with empty discoveredOrganisms list
    final newUser = UserData(
      username: username, 
      password: password,
      discoveredOrganisms: [], 
    );
    await _writeUserFile(newUser);
    
    await _saveCurrentUserName(username); 
    return true;
  }

  // Attempts to log a user in (renamed for compatibility)
  Future<UserData?> loginUser(String username, String password) async {
    final foundUser = await _readUserFile(username);
    
    if (foundUser != null && foundUser.password == password) {
      await _saveCurrentUserName(foundUser.username); 
      return foundUser;
    }
    
    return null;
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
  
  // START NEW: Method to update quiz statistics
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
  // END NEW

  // START NEW: Method to mark an organism as discovered
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
  // END NEW
}