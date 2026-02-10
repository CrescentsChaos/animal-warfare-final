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

  /// Set which captured animal is used as attacker in battle. Persists via read-modify-write.
  Future<void> setActiveAttacker(int index) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (u.capturedOrganisms.isEmpty) return u;
      final i = index.clamp(0, u.capturedOrganisms.length - 1);
      return u.copyWith(activeAttackerIndex: i);
    });
  }

  /// Release (remove) a captured organism at the given index. Persists via read-modify-write.
  Future<void> releaseOrganism(int index) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (u.capturedOrganisms.isEmpty || index < 0 || index >= u.capturedOrganisms.length) return u;
      final list = List<CapturedOrganism>.from(u.capturedOrganisms)..removeAt(index);
      int newAttacker = u.activeAttackerIndex;
      if (list.isEmpty) {
        newAttacker = 0;
      } else if (index <= u.activeAttackerIndex) {
        newAttacker = (u.activeAttackerIndex - 1).clamp(0, list.length - 1);
      } else {
        newAttacker = u.activeAttackerIndex.clamp(0, list.length - 1);
      }
      return u.copyWith(capturedOrganisms: list, activeAttackerIndex: newAttacker);
    });
  }

  /// Remove a specific captured organism (e.g., death in battle). Finds by matching properties.
  Future<void> removeCapturedOrganism(CapturedOrganism organism) async {
    if (_currentUser == null) return;
    // Find the organism by matching name and IVs (unique signature)
    final index = _currentUser!.capturedOrganisms.indexWhere((o) => 
      o.baseOrganism.name == organism.baseOrganism.name &&
      o.individualValues['health'] == organism.individualValues['health'] &&
      o.individualValues['attack'] == organism.individualValues['attack'] &&
      o.individualValues['defense'] == organism.individualValues['defense'] &&
      o.individualValues['speed'] == organism.individualValues['speed']
    );
    if (index >= 0) {
      await releaseOrganism(index);
    }
  }

  /// Add loot to inventory
  Future<void> addLoot(String lootId, int quantity) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final newInventory = Map<String, int>.from(u.inventory);
      newInventory[lootId] = (newInventory[lootId] ?? 0) + quantity;
      return u.copyWith(inventory: newInventory);
    });
    if (kDebugMode) print('UserState: Added $quantity x $lootId to inventory.');
  }

  /// Craft a talisman from recipe
  Future<bool> craftTalisman(String talismanId, Map<String, int> requiredLoot) async {
    if (_currentUser == null) return false;
    
    // Check if we have enough materials
    for (final entry in requiredLoot.entries) {
      final owned = _currentUser!.inventory[entry.key] ?? 0;
      if (owned < entry.value) {
        if (kDebugMode) print('UserState: Not enough ${entry.key} to craft.');
        return false;
      }
    }
    
    // Consume materials and add talisman
    await _readModifyWrite((u) {
      final newInventory = Map<String, int>.from(u.inventory);
      for (final entry in requiredLoot.entries) {
        newInventory[entry.key] = (newInventory[entry.key] ?? 0) - entry.value;
        if (newInventory[entry.key]! <= 0) {
          newInventory.remove(entry.key);
        }
      }
      final newTalismans = List<String>.from(u.craftedTalismans)..add(talismanId);
      return u.copyWith(inventory: newInventory, craftedTalismans: newTalismans);
    });
    
    if (kDebugMode) print('UserState: Crafted talisman $talismanId.');
    return true;
  }

  /// Equip talisman to a captured organism
  Future<void> equipTalisman(int organismIndex, String? talismanId) async {
    if (_currentUser == null) return;
    
    await _readModifyWrite((u) {
      if (organismIndex < 0 || organismIndex >= u.capturedOrganisms.length) return u;
      
      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);
      final organism = organisms[organismIndex];
      
      // For simplicity, we'll need to update CapturedOrganism
      // This is a limitation - we can't easily modify the talisman field
      // without recreating the object. Let me handle this differently.
      return u; // TODO: Implement talisman equipment
    });
  }

  @override
  void dispose() {
    _staminaRegenTimer?.cancel();
    super.dispose();
  }
}