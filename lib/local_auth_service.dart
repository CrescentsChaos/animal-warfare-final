import 'dart:convert';
import 'dart:io'; 
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:path_provider/path_provider.dart'; 

// Model to represent a user
// Model to represent a user
class UserData {
  final String username;
  final String password;
  final String avatar; // ⬅️ CHANGED: MUST be final
  final String gender; // ⬅️ CHANGED: MUST be final

  UserData({
    required this.username,
    required this.password,
    this.avatar = 'default',
    this.gender = 'N/A',
  });

  // ⬅️ NEW: Method to create a new UserData instance with optional updated fields
  UserData copyWith({
    String? username,
    String? password,
    String? avatar,
    String? gender,
  }) {
    return UserData(
      username: username ?? this.username,
      password: password ?? this.password,
      avatar: avatar ?? this.avatar,
      gender: gender ?? this.gender,
    );
  }

  Map<String, dynamic> toJson() => {
        'username': username,
        'password': password,
        'avatar': avatar,
        'gender': gender,
      };

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      username: json['username'] as String? ?? '',
      password: json['password'] as String? ?? '',
      avatar: json['avatar'] as String? ?? 'default',
      gender: json['gender'] as String? ?? 'N/A',
    );
  }
}

class LocalAuthService {
  // Key used to store the username of the currently logged-in user (uses SharedPreferences)
  static const _currentKey = 'current_user_username'; 
  
  // ⬅️ NEW: Generates the file path for a specific user.
  Future<File> _getUserFile(String username) async {
    // Use getDownloadsDirectory() for user-accessible data
    final directory = await getDownloadsDirectory();
    
    // Sanitize username for use as a filename (e.g., replace spaces/special chars)
    final safeUsername = username.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
    final fileName = '$safeUsername.json';
    
    // Fallback to Documents if Downloads directory isn't available (e.g., on iOS)
    final path = directory?.path ?? (await getApplicationDocumentsDirectory()).path;
    
    // Use a subfolder to keep files organized: AnimalWarfare/UserSaves/
    final appSubdirectory = '$path/AnimalWarfare/UserSaves/'; 
    final appDir = Directory(appSubdirectory);
    
    // Ensure the folder structure exists
    if (!await appDir.exists()) {
        await appDir.create(recursive: true);
    }

    return File('$appSubdirectory$fileName');
  }
  
  // ⬅️ NEW: Reads a single user's data from their JSON file
  Future<UserData?> _readUserFile(String username) async {
    try {
      final file = await _getUserFile(username);
      if (await file.exists()) {
        final contents = await file.readAsString();
        final userMap = jsonDecode(contents);
        return UserData.fromJson(userMap);
      }
      return null; // Return null if file doesn't exist
    } catch (e) {
      debugPrint("Error reading user file for $username: $e");
      return null; 
    }
  }

  // ⬅️ NEW: Writes a single user's data to their JSON file
  Future<void> _writeUserFile(UserData user) async {
    try {
      final file = await _getUserFile(user.username);
      final userJson = jsonEncode(user.toJson());
      await file.writeAsString(userJson);
      debugPrint("User data successfully written to ${file.path}");
    } catch (e) {
      debugPrint("Error writing user file for ${user.username}: $e");
    }
  }
  
  // Attempts to register a new user
  Future<bool> registerUser(String username, String password) async {
    // ⬅️ CHANGED: Check if the user's specific file already exists
    final existingUser = await _readUserFile(username);
    if (existingUser != null) {
      return false; // User already exists
    }

    final newUser = UserData(username: username, password: password);
    // ⬅️ CHANGED: Write only the single user's data
    await _writeUserFile(newUser);
    
    await _saveCurrentUserName(username); 
    return true;
  }

  // Attempts to log a user in
  Future<UserData?> loginUser(String username, String password) async {
    // ⬅️ CHANGED: Read the specific user's file
    final foundUser = await _readUserFile(username);
    
    if (foundUser != null && foundUser.password == password) {
      await _saveCurrentUserName(foundUser.username); 
      return foundUser;
    }
    
    return null;
  }

  // --- Session Management Logic (uses SharedPreferences) ---
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
    
    // ⬅️ CHANGED: Read the current user's file
    return await _readUserFile(currentUsername);
  }

  // Logs out the current user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentKey);
  }
  
  // --- Profile Update Logic ---
  Future<void> updateProfile(String username, {String? avatar, String? gender}) async {
    // ⬅️ CHANGED: Read the specific user's file
    final user = await _readUserFile(username);

    if (user != null) {
      final updatedUser = UserData(
        username: user.username,
        password: user.password,
        avatar: avatar ?? user.avatar,
        gender: gender ?? user.gender,
      );
      
      // ⬅️ CHANGED: Write only the updated user's data back to their file
      await _writeUserFile(updatedUser);
    }
  }
}