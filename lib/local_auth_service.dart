import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Model to represent a user (we only store the necessary login details locally)
class UserData {
  // CHANGED: Replaced 'email' with 'username'
  final String username; 
  final String password;
  String avatar;
  String gender;

  UserData({
    required this.username, // CHANGED
    required this.password,
    this.avatar = 'default',
    this.gender = 'N/A',
  });

  // Convert a UserData object to a JSON map
  Map<String, dynamic> toJson() => {
        'username': username, // CHANGED
        'password': password,
        'avatar': avatar,
        'gender': gender,
      };

  // Create a UserData object from a JSON map
  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      // FIX: Use 'as String? ?? '' ' to safely handle null values from local storage
      username: json['username'] as String? ?? '', 
      password: json['password'] as String? ?? '',
      avatar: json['avatar'] as String? ?? 'default',
      gender: json['gender'] as String? ?? 'N/A',
    );
  }
}

class LocalAuthService {
  // Key used to store the list of all registered users
  static const _usersKey = 'registered_users';
  // CHANGED: Key used to store the username of the currently logged-in user
  static const _currentKey = 'current_user_username'; 

  // --- User Registration/Login Logic ---

  // Retrieves all registered users from local storage
  Future<List<UserData>> _getRegisteredUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJsonString = prefs.getString(_usersKey) ?? '[]';
    final List usersList = jsonDecode(usersJsonString);
    
    return usersList.map((userMap) => UserData.fromJson(userMap)).toList();
  }

  // Attempts to register a new user
  // CHANGED: Takes username instead of email
  Future<bool> registerUser(String username, String password) async {
    final users = await _getRegisteredUsers();
    
    // Check if user already exists
    if (users.any((user) => user.username.toLowerCase() == username.toLowerCase())) { // CHANGED
      return false; // User already exists
    }

    final newUser = UserData(username: username, password: password); // CHANGED
    users.add(newUser);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users.map((u) => u.toJson()).toList()));
    
    // Auto-login the new user
    await _saveCurrentUserName(username); // CHANGED
    return true;
  }

  // Attempts to log a user in
  // CHANGED: Takes username instead of email
  Future<UserData?> loginUser(String username, String password) async {
    final users = await _getRegisteredUsers();
    
    // Use .where() to filter the list
    final matchingUsers = users.where(
      (user) => user.username.toLowerCase() == username.toLowerCase() && user.password == password, // CHANGED
    );

    // Check if a user was found.
    if (matchingUsers.isNotEmpty) {
      final foundUser = matchingUsers.first;
      await _saveCurrentUserName(foundUser.username); // CHANGED
      return foundUser;
    }
    
    return null; // Explicitly return null if no user was found.
  }

  // --- Session Management Logic ---

  // Saves the username of the logged-in user
  // CHANGED: Saves username instead of email
  Future<void> _saveCurrentUserName(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentKey, username);
  }
  
  // Checks if a user is currently logged in and returns their data
  Future<UserData?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    // CHANGED: Retrieve username key
    final currentUsername = prefs.getString(_currentKey); 
    
    if (currentUsername == null) {
      return null;
    }
    
    final users = await _getRegisteredUsers();
    
    // Use .where() to filter for the current user's username.
    final matchingUsers = users.where(
      (user) => user.username.toLowerCase() == currentUsername.toLowerCase(), // CHANGED
    );
    
    // Return the first match, or null if the list is empty.
    return matchingUsers.isNotEmpty ? matchingUsers.first : null;
  }

  // Logs out the current user
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentKey);
  }
  
  // --- Profile Update Logic ---
  
  // Updates avatar and gender for a logged-in user
  // CHANGED: Uses username for lookup
  Future<void> updateProfile(String username, {String? avatar, String? gender}) async {
    final users = await _getRegisteredUsers();
    final userIndex = users.indexWhere((user) => user.username.toLowerCase() == username.toLowerCase());

    if (userIndex != -1) {
      final user = users[userIndex];
      // Create a copy with updated fields
      final updatedUser = UserData(
        username: user.username, // CHANGED
        password: user.password,
        avatar: avatar ?? user.avatar,
        gender: gender ?? user.gender,
      );
      
      users[userIndex] = updatedUser;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usersKey, jsonEncode(users.map((u) => u.toJson()).toList()));
    }
  }
}