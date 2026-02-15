// lib/user_state.dart
// Global user state. All writes use read-modify-write from file so quiz stats
// and other data are never overwritten by stale in-memory state.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/quest.dart';
import 'dart:math';
import 'package:animal_warfare/models/rogue_like_state.dart';

import 'local_auth_service.dart';

class UserState with ChangeNotifier {
  UserData? _currentUser;
  final LocalAuthService _authService = LocalAuthService();
  Timer? _staminaRegenTimer;

  // Mutex to prevent race conditions during read-modify-write
  Future<void> _writeLock = Future.value();

  UserData? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  UserState() {
    loadCurrentUser();
    _startStaminaRegeneration();
  }

  /// Ensures we have the latest user from disk, applies [update], then saves.
  /// This method is serialized via _writeLock to prevent concurrent operations
  /// from overwriting each other.
  Future<void> _readModifyWrite(UserData Function(UserData) update) async {
    if (_currentUser == null) return;

    // Create a completer for the current operation
    final completer = Completer<void>();
    // Store the previous lock
    final previousLock = _writeLock;
    // Update the lock to the new completer's future
    _writeLock = completer.future;

    try {
      // Wait for all previous operations to complete
      await previousLock;

      final username = _currentUser!.username;
      final fresh = await _authService.readUserFile(username);
      if (fresh == null) return;

      final updated = update(fresh);
      await _authService.updateUser(updated);
      _currentUser = updated;
      notifyListeners();
    } finally {
      // Complete the current operation, allowing the next one to proceed
      completer.complete();
    }
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
      final list = List<CapturedOrganism>.from(u.capturedOrganisms)
        ..add(newCapture);
      return u.copyWith(capturedOrganisms: list);
    });
    if (kDebugMode) {
      print('UserState: ${newCapture.baseOrganism.name} captured and saved.');
    }
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
  /// Returns true if successful, false if the team is already full.
  Future<bool> toggleTeamMember(int index) async {
    if (_currentUser == null) return false;
    bool success = true;

    await _readModifyWrite((u) {
      if (index < 0 || index >= u.capturedOrganisms.length) return u;
      final team = List<int>.from(u.battleTeam);
      if (team.contains(index)) {
        team.remove(index);
      } else {
        if (team.length < 5) {
          team.add(index);
        } else {
          success = false;
        }
      }
      return u.copyWith(battleTeam: team);
    });

    return success;
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
      if (u.capturedOrganisms.isEmpty ||
          index < 0 ||
          index >= u.capturedOrganisms.length) {
        return u;
      }

      final list = List<CapturedOrganism>.from(u.capturedOrganisms)
        ..removeAt(index);

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
    final index = _currentUser!.capturedOrganisms.indexWhere(
      (o) =>
          o.baseOrganism.name == organism.baseOrganism.name &&
          o.individualValues['health'] == organism.individualValues['health'] &&
          o.individualValues['attack'] == organism.individualValues['attack'] &&
          o.individualValues['defense'] ==
              organism.individualValues['defense'] &&
          o.individualValues['speed'] == organism.individualValues['speed'],
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
  Future<bool> craftTalisman(
    String talismanId,
    Map<String, int> requiredLoot,
  ) async {
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
      final newTalismans = List<String>.from(u.craftedTalismans)
        ..add(talismanId);
      return u.copyWith(
        inventory: newInventory,
        craftedTalismans: newTalismans,
      );
    });

    if (kDebugMode) print('UserState: Crafted talisman $talismanId.');
    return true;
  }

  /// Equip talisman to a captured organism
  Future<void> equipTalisman(int organismIndex, String? talismanId) async {
    if (_currentUser == null) return;

    await _readModifyWrite((u) {
      if (organismIndex < 0 || organismIndex >= u.capturedOrganisms.length) {
        return u;
      }

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
        organisms[organismIndex] = targetOrg.copyWith(
          equippedTalisman: talisman,
        );
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
  Future<void> updateCapturedOrganismMoves(
    int index,
    List<String> newMoves,
  ) async {
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
    final npcQuests = _currentUser!.activeQuests
        .where((q) => q.npcId == quest.npcId)
        .length;
    if (npcQuests >= 2) {
      if (kDebugMode) {
        print('UserState: Already have 2 quests from ${quest.npcId}');
      }
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
        if (quest.status == QuestStatus.active &&
            quest.targetOrganismName == organismName) {
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
      final newList = List<Quest>.from(u.activeQuests)
        ..removeWhere((q) => q.id == questId);
      return u.copyWith(activeQuests: newList);
    });
  }

  /// Start a new Rogue-like run
  Future<void> startRogueRun({List<CapturedOrganism>? team}) async {
    if (_currentUser == null) return;

    List<CapturedOrganism> startingTeam = team ?? [];
    if (startingTeam.isEmpty) {
      final organisms = LocalAuthService.getCachedOrganisms();
      if (organisms.isNotEmpty) {
        final base = organisms[Random().nextInt(organisms.length)];
        startingTeam = [CapturedOrganism.spawn(base, level: 5)];
      }
    }

    // Ensure organisms are loaded for random biome selection
    await LocalAuthService.loadOrganisms();

    final biome = _getRandomBiome();
    final firstOpponents = _generateRogueOpponentTeam(biome, 1, 1);

    await _readModifyWrite(
      (u) => u.copyWith(
        rogueLikeState: u.rogueLikeState.copyWith(
          floor: 1,
          encounterIndex: 0,
          currentBiome: biome,
          opponentTeam: firstOpponents,
          currentOpponentIndex: 0,
          team: startingTeam,
          isActive: true,
        ),
      ),
    );
  }

  /// Update the current rogue-team
  Future<void> updateRogueTeam(List<CapturedOrganism> team) async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(rogueLikeState: u.rogueLikeState.copyWith(team: team)),
    );
  }

  /// Increment the current rogue-floor or advance encounter
  Future<void> incrementRogueFloor() async {
    if (_currentUser == null) return;

    // Ensure organisms are loaded
    await LocalAuthService.loadOrganisms();

    await _readModifyWrite((u) {
      final state = u.rogueLikeState;
      int newFloor = state.floor;
      int newEncounter = state.encounterIndex + 1;
      String? newBiome = state.currentBiome;

      List<CapturedOrganism> nextTeam = List.from(state.team);

      if (newEncounter >= 5) {
        newFloor++;
        newEncounter = 0;
        newBiome = _getRandomBiome();

        // HEAL & SCALE TEAM
        nextTeam = nextTeam.map((member) {
          final int newLevel = member.level + 2;

          // Create temp to get new max stats
          var upgraded = member.copyWith(level: newLevel);

          // Restore stamina (mutates map)
          upgraded.restoreAllStamina();

          return upgraded.copyWith(
            currentHealth: upgraded.maxHealth,
            statusEffects: [], // Clear all statuses
          );
        }).toList();
      }

      final isBoss = newEncounter == 4;
      final int count = isBoss
          ? (2 + Random().nextInt(4)).clamp(2, 5).toInt()
          : 1;
      final newOpponents = _generateRogueOpponentTeam(
        newBiome ?? 'Forest',
        count,
        newFloor,
      );

      final newHighest = newFloor > state.highestFloor
          ? newFloor
          : state.highestFloor;

      // Update best records if this is a new high floor
      int bestFloor = u.bestRogueFloor;
      List<CapturedOrganism> bestTeam = List.from(u.bestRogueTeam);

      if (newFloor > bestFloor) {
        bestFloor = newFloor;
        bestTeam = List.from(nextTeam);
      }

      return u.copyWith(
        bestRogueFloor: bestFloor,
        bestRogueTeam: bestTeam,
        rogueLikeState: state.copyWith(
          floor: newFloor,
          encounterIndex: newEncounter,
          currentBiome: newBiome,
          team: nextTeam,
          opponentTeam: newOpponents,
          currentOpponentIndex: 0,
          highestFloor: newHighest,
        ),
      );
    });
  }

  /// End the current rogue run
  Future<void> endRogueRun() async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(
        rogueLikeState: u.rogueLikeState.copyWith(isActive: false, team: []),
      ),
    );
  }

  /// Capture an organism specifically for the rogue run
  Future<void> captureForRogueRun(CapturedOrganism newCapture) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final team = List<CapturedOrganism>.from(u.rogueLikeState.team)
        ..add(newCapture);
      return u.copyWith(rogueLikeState: u.rogueLikeState.copyWith(team: team));
    });
  }

  /// Replace an organism in the rogue run team with a new capture
  Future<void> replaceRogueTeamMember(
    int teamIndex,
    CapturedOrganism newCapture,
  ) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (teamIndex < 0 || teamIndex >= u.rogueLikeState.team.length) return u;
      final team = List<CapturedOrganism>.from(u.rogueLikeState.team);
      team[teamIndex] = newCapture;
      return u.copyWith(rogueLikeState: u.rogueLikeState.copyWith(team: team));
    });
  }

  /// Release an organism from the rogue run team
  Future<void> releaseFromRogueRun(int index) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (index < 0 || index >= u.rogueLikeState.team.length) return u;
      final team = List<CapturedOrganism>.from(u.rogueLikeState.team)
        ..removeAt(index);
      return u.copyWith(rogueLikeState: u.rogueLikeState.copyWith(team: team));
    });
  }

  /// Update the full rogue state mid-battle (for deep persistence)
  Future<void> updateRogueRunState(RogueLikeState state) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.copyWith(rogueLikeState: state));
  }

  /// Internal: Pick a random biome that exists in the data
  String _getRandomBiome() {
    final organisms = LocalAuthService.getCachedOrganisms();
    List<String> biomes = [];

    if (organisms.isNotEmpty) {
      biomes = organisms
          .expand((o) => o.habitat.split(',').map((e) => e.trim()))
          .toSet()
          .toList();
    }

    if (biomes.isEmpty) {
      // Fallback biomes if data is missing, to avoid 'Forest' loop
      biomes = ['Jungle', 'Desert', 'Savanna', 'River', 'Ocean', 'Mountain'];
    }
    return biomes[Random().nextInt(biomes.length)];
  }

  /// Internal: Generate an opponent team for the rogue run
  List<CapturedOrganism> _generateRogueOpponentTeam(
    String biome,
    int count,
    int floor,
  ) {
    final organisms = LocalAuthService.getCachedOrganisms();
    final possible = organisms.where((o) {
      final habitats = o.habitat
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .toList();
      return habitats.contains(biome.toLowerCase());
    }).toList();
    final fallout = possible.isEmpty ? organisms : possible;

    final team = <CapturedOrganism>[];

    // Infinite Scaling Logic:
    // Regular encounters: Level = 3 + (floor - 1) * 2 + [0, 1, or 2]
    // Boss encounters: Level = 3 + (floor - 1) * 2 + 2 (always max of floor range)

    bool isBoss = count > 1;
    int baseLevel = 3 + (floor - 1) * 2;
    int effectiveLevel = isBoss
        ? baseLevel + 2
        : baseLevel + Random().nextInt(3);

    if (isBoss) {
      // Cap boss team size to 4 max for balance
      count = count.clamp(2, 4);
    }

    for (int i = 0; i < count; i++) {
      final base = fallout[Random().nextInt(fallout.length)];
      // Bosses have guaranteed better IVs (31 in all stats)
      final spawn = isBoss
          ? CapturedOrganism.spawn(base, level: effectiveLevel).copyWith(
              individualValues: {
                'health': 31,
                'attack': 31,
                'defense': 31,
                'power': 31,
                'resistance': 31,
                'speed': 31,
              },
            )
          : CapturedOrganism.spawn(base, level: effectiveLevel);

      team.add(spawn);
    }
    return team;
  }

  @override
  void dispose() {
    _staminaRegenTimer?.cancel();
    super.dispose();
  }
}
