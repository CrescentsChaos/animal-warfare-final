// lib/user_state.dart
// Global user state. All writes use read-modify-write from file so quiz stats
// and other data are never overwritten by stale in-memory state.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'local_auth_service.dart';

class UserState with ChangeNotifier {
  UserData? _currentUser;
  final LocalAuthService _authService = LocalAuthService();
  Timer? _staminaRegenTimer;

  UserData? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  UserState() {
    loadCurrentUser();
    _startStaminaRegeneration();
  }

  /// Ensures we have the latest user from disk, applies [update], then saves.
  /// Prevents overwriting quiz stats (or any other data) when other screens
  /// (e.g. quiz) have updated the file.
  Future<void> _readModifyWrite(UserData Function(UserData) update) async {
    if (_currentUser == null) return;
    final username = _currentUser!.username;
    final fresh = await _authService.readUserFile(username);
    if (fresh == null) return;
    final updated = update(fresh);
    await _authService.updateUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  void _startStaminaRegeneration() {
    _staminaRegenTimer?.cancel();
    _staminaRegenTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_currentUser != null && _currentUser!.stamina < 100) {
        _regenerateStamina(20);
      }
    });
  }

  void setCurrentUser(UserData? user) {
    if (user != _currentUser) {
      _currentUser = user;
      notifyListeners();
    }
  }

  Future<void> _regenerateStamina(int amount) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.restoreStamina(amount));
  }

  Future<void> addCapturedOrganism(CapturedOrganism newCapture) async {
    if (_currentUser == null) {
      if (kDebugMode) print('Cannot add organism: User not logged in.');
      return;
    }
    await _readModifyWrite((u) {
      final list = List<CapturedOrganism>.from(u.capturedOrganisms)..add(newCapture);
      return u.copyWith(capturedOrganisms: list);
    });
    if (kDebugMode) print('UserState: ${newCapture.baseOrganism.name} captured and saved.');
  }

  Future<void> refreshCurrentUser() async => loadCurrentUser();

  Future<void> loadCurrentUser() async {
    _currentUser = await _authService.getCurrentUser();
    notifyListeners();
  }

  Future<void> handleSuccessfulAuth() async {
    _currentUser = await _authService.getCurrentUser();
    notifyListeners();
  }

  /// Decrease stamina (e.g. explore or identify). Uses read-modify-write so
  /// quiz and other file-backed data are preserved.
  Future<void> decreaseStamina(int amount) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.decreaseStamina(amount));
  }

  @override
  void dispose() {
    _staminaRegenTimer?.cancel();
    super.dispose();
  }
}