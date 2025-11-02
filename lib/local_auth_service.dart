// lib/local_auth_service.dart

import 'dart:convert';
import 'dart:io'; 
import 'package:flutter/foundation.dart';
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
  }) : quizStats = quizStats ?? {},
       discoveredOrganisms = discoveredOrganisms ?? [],
       completedAchievements = completedAchievements ?? [],
       capturedOrganisms = capturedOrganisms ?? []; // INITIALIZE

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
    List<String>? completedAchievements,
    List<CapturedOrganism>? capturedOrganisms,
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
  
  // 🟢 NEW: Add a lock to prevent concurrent writes to the same user file
  final Map<String, Future<void>?> _writeLocks = {};
  
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
  Future<void> addCapturedOrganism(String username, CapturedOrganism newCapture) async {
    // NOTE: In a complete app, you would pass the list of all base organisms 
    // to the `readUserFile` method (which internally uses UserData.fromJson).
    
    // 1. Read fresh data 
    final user = await readUserFile(username); // Assume readUserFile now loads base organisms

    if (user != null) {
      final updatedList = List<CapturedOrganism>.from(user.capturedOrganisms)
        ..add(newCapture);
        
      // 2. Use copyWith to preserve ALL existing fields
      final updatedUser = user.copyWith(capturedOrganisms: updatedList);
      
      // 3. Write to file
      // Assume _writeUserFile is the private method in the original file
      await _writeUserFile(updatedUser); 
      
      if (kDebugMode) {
        print("DEBUG: Organism '${newCapture.baseOrganism.name}' captured for $username");
      }
    }
  }
  // Reads a single user's data from their JSON file
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
        // 🟢 FIX: Force a fresh read by checking file length first (bypasses caching)
        final fileLength = await file.length();
        final contents = await file.readAsString();
        
        if (kDebugMode) {
          print("DEBUG: Reading user file for $username (length: $fileLength bytes)");
        }
        
        try {
          // NEW: Inner try-catch to specifically handle JSON decoding errors
          final userMap = jsonDecode(contents);
          final userData = UserData.fromJson(userMap);
          
          if (kDebugMode) {
            print("DEBUG: Loaded user data for $username - Quiz stats: ${userData.quizStats}");
          }
          
          return userData;
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
    // 🟢 FIX: Wait for any existing write operation to complete first
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
  
  // 🟢 NEW: Actual write implementation with staleness check
  Future<void> _performWrite(UserData user) async {
    try {
      final file = await _getUserFile(user.username);
      
      // 🟢 NEW: Before writing, read the current file to check if we have stale data
      if (await file.exists()) {
        final currentContents = await file.readAsString();
        final currentData = jsonDecode(currentContents);
        final currentUser = UserData.fromJson(currentData);
        
        // Compare quiz stats sizes - if current file has MORE quiz types, we're stale
        if (currentUser.quizStats.length > user.quizStats.length) {
          if (kDebugMode) {
            print("⚠️  WARNING: Prevented stale data write for ${user.username}!");
            print("   Current file has ${currentUser.quizStats.length} quiz types");
            print("   Attempted write has ${user.quizStats.length} quiz types");
            print("   WRITE ABORTED to preserve data integrity");
          }
          return; // Abort the write - our data is stale
        }
      }
      
      final userJson = jsonEncode(user.toJson());
      
      // Write and immediately flush to disk to ensure persistence
      await file.writeAsString(userJson, flush: true);
      
      if (kDebugMode) {
        print("DEBUG: User data written successfully for ${user.username}");
        print("DEBUG: Quiz stats being saved: ${user.quizStats}");
        print("DEBUG: Discovered organisms: ${user.discoveredOrganisms.length}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error writing user file for ${user.username}: $e");
      }
      rethrow;
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
    // 🟢 FIX: Always read fresh data first
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
    // 🟢 FIX: Always read fresh data first
    final user = await readUserFile(username);

    if (user != null) {
      // 1. Get the current stats for the specific quiz, providing defaults if null
      final Map<String, dynamic> currentQuizData = 
          Map.from(user.quizStats[quizName] ?? {'attempts': 0, 'correct': 0});
      
      // 2. Calculate the new values for the specific quiz
      final int newAttempts = (currentQuizData['attempts'] as int) + 1;
      final int newCorrect = (currentQuizData['correct'] as int) + (isCorrect ? 1 : 0);
      
      // 3. Create the new, updated data map for the specific quiz
      final Map<String, dynamic> newQuizData = {
        // Keep existing keys, if any (though we initialized above)
        ...?currentQuizData, 
        'attempts': newAttempts,
        'correct': newCorrect,
        'lastAttempt': DateTime.now().toIso8601String(),
      };
      
      // 4. Create the final top-level quizStats map with the updated quiz entry
      final Map<String, dynamic> newStats = {
        // Copy all existing quiz stats
        ...user.quizStats,
        // Override or add the updated quiz data
        quizName: newQuizData,
      };
      
      // 5. Update the user object and write to file
      final updatedUser = user.copyWith(quizStats: newStats);
      await _writeUserFile(updatedUser);
      
      if (kDebugMode) {
        print("DEBUG: Updated quiz stats for $quizName - Attempts: $newAttempts, Correct: $newCorrect");
      }
    }
  }
  
  // Method to mark an organism as discovered
  Future<void> markOrganismAsDiscovered(String username, String organismName) async {
    // 🟢 FIX: Always read fresh data first
    final user = await readUserFile(username);

    if (user != null) {
      // Use a Set for efficient check and prevent duplicates
      final discovered = Set<String>.from(user.discoveredOrganisms);
      
      if (!discovered.contains(organismName)) {
        discovered.add(organismName);
        
        // 🟢 FIX: Use copyWith to preserve ALL existing fields including quizStats
        final updatedUser = user.copyWith(discoveredOrganisms: discovered.toList());
        await _writeUserFile(updatedUser);
        
        if (kDebugMode) {
          print("DEBUG: Organism '$organismName' marked as discovered for $username");
          print("DEBUG: Total discovered: ${discovered.length}");
          print("DEBUG: Quiz stats preserved: ${updatedUser.quizStats}");
        }
      }
    }
  }
}
// 🟢 NEW: Add a map to track the last write time for each user
  