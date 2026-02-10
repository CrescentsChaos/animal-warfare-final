// lib/local_auth_storage_web.dart
// Platform-specific storage for web using SharedPreferences.

import 'package:shared_preferences/shared_preferences.dart';

const _userPrefix = 'aw_user_';

String _userKey(String username) {
  final safe = username.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
  return '$_userPrefix$safe';
}

Future<String?> readUserData(String username) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_userKey(username));
}

Future<void> writeUserData(String username, String jsonData) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_userKey(username), jsonData);
}
