// lib/local_auth_storage_io.dart
// Platform-specific storage for mobile/desktop using dart:io File.

import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<String?> readUserData(String username) async {
  final file = await _getUserFile(username);
  if (await file.exists()) {
    return file.readAsString();
  }
  return null;
}

Future<void> writeUserData(String username, String jsonData) async {
  final file = await _getUserFile(username);
  await file.writeAsString(jsonData, flush: true);
}

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
