import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Model to represent a user (we only store the necessary login details locally)
class UserData {
  final String email;
  final String password;
  String avatar;
  String gender;

  UserData({
    required this.email,
    required this.password,
    this.avatar = 'default',
    this.gender = 'N/A',
  });

  // Convert a UserData object to a JSON map
  Map<String, dynamic> toJson() => {
        'email': email,
        'password': password,
        'avatar': avatar,
        'gender': gender,
      };

  // Create a UserData object from a JSON map
  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      email: json['email'] as String,
      password: json['password'] as String,
      avatar: json['avatar'] as String,
      gender: json['gender'] as String,
    );
  }
}

class LocalAuthService {
  // Key used to store the list of all registered users
  static const _usersKey = 'registered_users';
  // Key used to store the email of the currently logged-in user
  static const _currentKey = 'current_user_email';

  // --- User Registration/Login Logic ---

  // Retrieves all registered users from local storage
  Future<List<UserData>> _getRegisteredUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final usersJsonString = prefs.getString(_usersKey) ?? '[]';
    final List usersList = jsonDecode(usersJsonString);
    
    return usersList.map((userMap) => UserData.fromJson(userMap)).toList();
  }

  // Attempts to register a new user
  Future<bool> registerUser(String email, String password) async {
    final users = await _getRegisteredUsers();
    
    // Check if user already exists
    if (users.any((user) => user.email.toLowerCase() == email.toLowerCase())) {
      return false; // User already exists
    }

    final newUser = UserData(email: email, password: password);
    users.add(newUser);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_usersKey, jsonEncode(users.map((u) => u.toJson()).toList()));
    
    // Auto-login the new user
    await _saveCurrentUserEmail(email);
    return true;
  }

  // Attempts to log a user in
  // Attempts to log a user in
  Future<UserData?> loginUser(String email, String password) async {
    final users = await _getRegisteredUsers();
    
    // Use .where() to filter the list, which returns an iterable.
    final matchingUsers = users.where(
      (user) => user.email.toLowerCase() == email.toLowerCase() && user.password == password,
    );

    // Check if a user was found.
    if (matchingUsers.isNotEmpty) {
      final foundUser = matchingUsers.first;
      await _saveCurrentUserEmail(foundUser.email);
      return foundUser;
    }
    
    return null; // Explicitly return null if no user was found.
  }

  // --- Session Management Logic ---

  // Saves the email of the logged-in user
  Future<void> _saveCurrentUserEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currentKey, email);
  }
  
  // Checks if a user is currently logged in and returns their data
  // Checks if a user is currently logged in and returns their data
  Future<UserData?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final currentEmail = prefs.getString(_currentKey);
    
    if (currentEmail == null) {
      return null;
    }
    
    final users = await _getRegisteredUsers();
    
    // Use .where() to filter for the current user's email.
    final matchingUsers = users.where(
      (user) => user.email.toLowerCase() == currentEmail.toLowerCase(),
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
  Future<void> updateProfile(String email, {String? avatar, String? gender}) async {
    final users = await _getRegisteredUsers();
    final userIndex = users.indexWhere((user) => user.email.toLowerCase() == email.toLowerCase());

    if (userIndex != -1) {
      final user = users[userIndex];
      // Create a copy with updated fields
      final updatedUser = UserData(
        email: user.email,
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
