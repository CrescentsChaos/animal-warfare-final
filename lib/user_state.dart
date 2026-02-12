// lib/user_state.dart
// Global user state. All writes use read-modify-write from file so quiz stats
// and other data are never overwritten by stale in-memory state.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/quest.dart';
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

  /// Toggle an animal's presence in the 5-animal battle team.
  Future<void> toggleTeamMember(int index) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (index < 0 || index >= u.capturedOrganisms.length) return u;
      final team = List<int>.from(u.battleTeam);
      if (team.contains(index)) {
        team.remove(index);
      } else {
        if (team.length < 5) {
          team.add(index);
        }
      }
      return u.copyWith(battleTeam: team);
    });
  }

  /// Clear the entire battle team.
  Future<void> clearTeam() async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.copyWith(battleTeam: []));
  }

  /// Release (remove) a captured organism at the given index. Persists via read-modify-write.
  Future<void> releaseOrganism(int index) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (u.capturedOrganisms.isEmpty || index < 0 || index >= u.capturedOrganisms.length) return u;
      
      final list = List<CapturedOrganism>.from(u.capturedOrganisms)..removeAt(index);
      
      // Update active attacker index
      int newAttacker = u.activeAttackerIndex;
      if (list.isEmpty) {
        newAttacker = 0;
      } else if (index <= u.activeAttackerIndex) {
        newAttacker = (u.activeAttackerIndex - 1).clamp(0, list.length - 1);
      } else {
        newAttacker = u.activeAttackerIndex.clamp(0, list.length - 1);
      }

      // Update battle team indices
      final newTeam = u.battleTeam
          .where((i) => i != index) // Remove the released organism
          .map((i) => i > index ? i - 1 : i) // Shift indices down
          .toList();

      return u.copyWith(
        capturedOrganisms: list, 
        activeAttackerIndex: newAttacker,
        battleTeam: newTeam,
      );
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

  /// Add money to user's wallet. Persists via read-modify-write.
  Future<void> addMoney(int amount) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.addMoney(amount));
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
      final targetOrg = organisms[organismIndex];
      final oldTalismanId = targetOrg.equippedTalisman?.id;
      
      final newCraftedTalismans = List<String>.from(u.craftedTalismans);
      
      // If equipping a new one
      if (talismanId != null) {
        // Check if we have it
        final tIndex = newCraftedTalismans.indexOf(talismanId);
        if (tIndex == -1) return u; // Don't have it
        
        // Remove from inventory
        newCraftedTalismans.removeAt(tIndex);
        
        // Equip
        final talisman = Talisman.findById(talismanId);
        organisms[organismIndex] = targetOrg.copyWith(equippedTalisman: talisman);
      } else {
        // Unequipping
        organisms[organismIndex] = targetOrg.copyWith(equippedTalisman: null);
      }
      
      // Return old one to inventory if it existed
      if (oldTalismanId != null) {
        newCraftedTalismans.add(oldTalismanId);
      }
      
      return u.copyWith(
        capturedOrganisms: organisms,
        craftedTalismans: newCraftedTalismans,
      );
    });
  }

  /// Update the selected moves for a captured organism.
  Future<void> updateCapturedOrganismMoves(int index, List<String> newMoves) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (index < 0 || index >= u.capturedOrganisms.length) return u;
      final list = List<CapturedOrganism>.from(u.capturedOrganisms);
      final org = list[index];
      
      // Initialize stamina for new moves if they weren't selected before
      final newStamina = Map<String, int>.from(org.moveStamina);
      for (final moveName in newMoves) {
        if (!newStamina.containsKey(moveName)) {
          final move = Move.findByName(moveName);
          newStamina[moveName] = move?.stamina ?? 20;
        }
      }
      
      list[index] = org.copyWith(
        selectedMoveNames: newMoves,
        moveStamina: newStamina,
      );
      return u.copyWith(capturedOrganisms: list);
    });
  }

  /// Quest management methods
  Future<void> acceptQuest(Quest quest) async {
    if (_currentUser == null) return;
    
    // Check if player already has 2 quests from this NPC
    final npcQuests = _currentUser!.activeQuests.where((q) => q.npcId == quest.npcId).length;
    if (npcQuests >= 2) {
      if (kDebugMode) print('UserState: Already have 2 quests from ${quest.npcId}');
      return;
    }

    await _readModifyWrite((u) {
      final list = List<Quest>.from(u.activeQuests)..add(quest);
      return u.copyWith(activeQuests: list);
    });
    if (kDebugMode) print('UserState: Accepted quest ${quest.description}');
  }

  Future<void> updateQuestProgress(String organismName) async {
    if (_currentUser == null || _currentUser!.activeQuests.isEmpty) return;
    
    await _readModifyWrite((u) {
      final list = u.activeQuests.map((quest) {
        if (quest.status == QuestStatus.active && quest.targetOrganismName == organismName) {
          return quest.copyWith(currentCount: quest.currentCount + 1);
        }
        return quest;
      }).toList();
      return u.copyWith(activeQuests: list);
    });
    if (kDebugMode) print('UserState: Progressed quests for $organismName');
  }

  Future<void> claimQuestReward(String questId) async {
    if (_currentUser == null) return;
    
    await _readModifyWrite((u) {
      final index = u.activeQuests.indexWhere((q) => q.id == questId);
      if (index == -1) return u;
      
      final quest = u.activeQuests[index];
      if (!quest.isCompleted) return u;
      
      final newList = List<Quest>.from(u.activeQuests)..removeAt(index);
      return u.addMoney(quest.rewardMoney).copyWith(activeQuests: newList);
    });
    if (kDebugMode) print('UserState: Claimed reward for quest $questId');
  }

  Future<void> removeQuestById(String questId) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final newList = List<Quest>.from(u.activeQuests)..removeWhere((q) => q.id == questId);
      return u.copyWith(activeQuests: newList);
    });
  }

  @override
  void dispose() {
    _staminaRegenTimer?.cancel();
    super.dispose();
  }
}