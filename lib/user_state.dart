// lib/user_state.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/quest.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/nature.dart';
import 'dart:math';
import 'package:animal_warfare/models/rogue_like_state.dart';
import 'local_auth_service.dart';

class UserState with ChangeNotifier {
  UserData? _currentUser;
  final LocalAuthService _authService = LocalAuthService();
  Timer? _staminaRegenTimer;
  Future<void> _writeLock = Future.value();

  UserData? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  UserState() {
    loadCurrentUser();
    _startStaminaRegeneration();
  }

  Future<void> _readModifyWrite(UserData Function(UserData) update) async {
    if (_currentUser == null) return;
    final completer = Completer<void>();
    final previousLock = _writeLock;
    _writeLock = completer.future;
    try {
      await previousLock;
      final username = _currentUser!.username;
      final fresh = await _authService.readUserFile(username);
      if (fresh == null) return;
      final updated = update(fresh);
      await _authService.updateUser(updated);
      _currentUser = updated;
      notifyListeners();
    } finally {
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
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final list = List<CapturedOrganism>.from(u.capturedOrganisms)
        ..add(newCapture);
      return u.copyWith(capturedOrganisms: list);
    });
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

  Future<void> decreaseStamina(int amount) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.decreaseStamina(amount));
  }

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

  Future<void> clearTeam() async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.copyWith(battleTeam: []));
  }

  Future<void> reorderBattleTeam(int oldIndex, int newIndex) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final team = List<int>.from(u.battleTeam);
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final int item = team.removeAt(oldIndex);
      team.insert(newIndex, item);
      return u.copyWith(battleTeam: team);
    });
  }

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
      final newTeam = u.battleTeam
          .where((i) => i != index)
          .map((i) => i > index ? i - 1 : i)
          .toList();
      return u.copyWith(capturedOrganisms: list, battleTeam: newTeam);
    });
  }

  Future<void> removeCapturedOrganism(CapturedOrganism organism) async {
    if (_currentUser == null) return;
    final index = _currentUser!.capturedOrganisms.indexWhere(
      (o) =>
          o.baseOrganism.name == organism.baseOrganism.name &&
          o.individualValues['health'] == organism.individualValues['health'] &&
          o.individualValues['attack'] == organism.individualValues['attack'] &&
          o.individualValues['defense'] ==
              organism.individualValues['defense'] &&
          o.individualValues['speed'] == organism.individualValues['speed'],
    );
    if (index >= 0) await releaseOrganism(index);
  }

  Future<void> addLoot(String lootId, int quantity) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final newInventory = Map<String, int>.from(u.inventory);
      newInventory[lootId] = (newInventory[lootId] ?? 0) + quantity;
      return u.copyWith(inventory: newInventory);
    });
    if (kDebugMode) {
      print('UserState: Added $quantity x $lootId to inventory.');
    }
  }

  Future<void> addMoney(int amount) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.addMoney(amount));
  }

  /// Fully heals all animals in the current team (HP, Status, Stamina).
  Future<void> fullyHealTeam() async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final teamIndices = u.battleTeam;
      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);
      for (final index in teamIndices) {
        if (index >= 0 && index < organisms.length) {
          final org = organisms[index];
          // Restore HP
          int maxHp = org.maxHealth;
          // Restore Stamina
          final Map<String, int> fullStamina = {};
          for (final moveName in org.selectedMoveNames) {
            final move = Move.findByName(moveName);
            fullStamina[moveName] = move?.stamina ?? Move.defaultStamina;
          }

          organisms[index] = org.copyWith(
            currentHealth: maxHp,
            statusEffects: [],
            moveStamina: fullStamina,
          );
        }
      }
      return u.copyWith(capturedOrganisms: organisms);
    });
  }

  Future<bool> craftTalisman(
    String talismanId,
    Map<String, int> requiredLoot,
  ) async {
    if (_currentUser == null) return false;
    for (final entry in requiredLoot.entries) {
      if ((_currentUser!.inventory[entry.key] ?? 0) < entry.value) return false;
    }
    await _readModifyWrite((u) {
      final newInventory = Map<String, int>.from(u.inventory);
      for (final entry in requiredLoot.entries) {
        newInventory[entry.key] = (newInventory[entry.key] ?? 0) - entry.value;
        if (newInventory[entry.key]! <= 0) newInventory.remove(entry.key);
      }
      final newTalismans = List<String>.from(u.craftedTalismans)
        ..add(talismanId);
      return u.copyWith(
        inventory: newInventory,
        craftedTalismans: newTalismans,
      );
    });
    return true;
  }

  Future<void> equipTalisman(int organismIndex, String? talismanId) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (organismIndex < 0 || organismIndex >= u.capturedOrganisms.length) {
        return u;
      }
      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);
      final targetOrg = organisms[organismIndex];
      final oldId = targetOrg.equippedTalisman?.id;
      final newCrafted = List<String>.from(u.craftedTalismans);
      if (talismanId != null) {
        final tIndex = newCrafted.indexOf(talismanId);
        if (tIndex == -1) return u;
        newCrafted.removeAt(tIndex);
        organisms[organismIndex] = targetOrg.copyWith(
          equippedTalisman: Talisman.findById(talismanId),
        );
      } else {
        organisms[organismIndex] = targetOrg.copyWith(clearTalisman: true);
      }
      if (oldId != null) newCrafted.add(oldId);
      return u.copyWith(
        capturedOrganisms: organisms,
        craftedTalismans: newCrafted,
      );
    });
  }

  Future<void> updateCapturedOrganismMoves(
    int index,
    List<String> newMoves,
  ) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (index < 0 || index >= u.capturedOrganisms.length) return u;
      final list = List<CapturedOrganism>.from(u.capturedOrganisms);
      final org = list[index];
      final newStamina = Map<String, int>.from(org.moveStamina);
      for (final moveName in newMoves) {
        if (!newStamina.containsKey(moveName)) {
          newStamina[moveName] = Move.findByName(moveName)?.stamina ?? 20;
        }
      }
      list[index] = org.copyWith(
        selectedMoveNames: newMoves,
        moveStamina: newStamina,
      );
      return u.copyWith(capturedOrganisms: list);
    });
  }

  Future<void> acceptQuest(Quest quest) async {
    if (_currentUser == null) return;
    if (_currentUser!.activeQuests
            .where((q) => q.npcId == quest.npcId)
            .length >=
        2) {
      return;
    }
    await _readModifyWrite((u) {
      final list = List<Quest>.from(u.activeQuests)..add(quest);
      return u.copyWith(activeQuests: list);
    });
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
  }

  Future<void> removeQuestById(String questId) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final newList = List<Quest>.from(u.activeQuests)
        ..removeWhere((q) => q.id == questId);
      return u.copyWith(activeQuests: newList);
    });
  }

  Future<void> startRogueRun({List<CapturedOrganism>? team}) async {
    if (_currentUser == null) return;
    List<CapturedOrganism> startingTeam = team ?? [];
    if (startingTeam.isEmpty) {
      final organisms = LocalAuthService.getCachedOrganisms();
      if (organisms.isEmpty) return;
      final base = organisms[Random().nextInt(organisms.length)];
      startingTeam = [CapturedOrganism.spawn(base, level: 5)];
    }
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

  Future<void> updateRogueTeam(List<CapturedOrganism> team) async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(rogueLikeState: u.rogueLikeState.copyWith(team: team)),
    );
  }

  Future<void> completeRogueEncounter() async {
    if (_currentUser == null) return;
    await LocalAuthService.loadOrganisms();
    await _readModifyWrite((u) {
      final state = u.rogueLikeState;
      if (state.encounterIndex >= 5) {
        return u; // End of floor handled separately
      }

      int newEncounter = state.encounterIndex + 1;

      final newOpponents = _generateRogueOpponentTeam(
        state.currentBiome ?? 'Jungle',
        newEncounter == 4
            ? (2 + Random().nextInt(4)).clamp(2, 5)
            : 1, // Boss is at index 4 (5th fight)
        state.floor,
      );

      return u.copyWith(
        rogueLikeState: state.copyWith(
          encounterIndex: newEncounter,
          opponentTeam: newOpponents,
          currentOpponentIndex: 0,
        ),
      );
    });
  }

  List<String> generateBiomeOptions() {
    final organisms = LocalAuthService.getCachedOrganisms();
    List<String> allBiomes = organisms
        .expand((o) => o.habitat.split(',').map((e) => e.trim()))
        .toSet()
        .toList();

    if (allBiomes.isEmpty) {
      allBiomes = [
        'Volcano',
        'Cave',
        'Coastal',
        'Coral Reef',
        'Deep Sea',
        'Frozen Ocean',
        'Kelp Forest',
        'Swamp',
        'Lake',
        'Mangrove',
        'Polar',
        'Rainforest',
        'Taiga',
        'Tundra',
        'Urban',
        'Jungle',
        'Desert',
        'Savanna',
        'River',
        'Ocean',
        'Mountain',
      ];
    }

    final current = _currentUser?.rogueLikeState.currentBiome;
    final options = allBiomes.where((b) => b != current).toList();
    options.shuffle();
    return options.take(2).toList();
  }

  Future<void> advanceToNextFloor(String selectedBiome) async {
    if (_currentUser == null) return;
    await LocalAuthService.loadOrganisms();
    await _readModifyWrite((u) {
      final state = u.rogueLikeState;
      int newFloor = state.floor + 1;

      // Team Upgrades
      List<CapturedOrganism> nextTeam = state.team.map((member) {
        final int newLevel = member.level + 2;
        var upgraded = member.copyWith(level: newLevel);
        upgraded.restoreAllStamina();
        return upgraded.copyWith(
          currentHealth: upgraded.maxHealth,
          statusEffects: [],
        );
      }).toList();

      final newOpponents = _generateRogueOpponentTeam(
        selectedBiome,
        1, // First encounter of new floor is always single
        newFloor,
      );

      int bestFloor = u.bestRogueFloor;
      List<CapturedOrganism> bestTeam = List<CapturedOrganism>.from(
        u.bestRogueTeam,
      );
      if (newFloor > bestFloor) {
        bestFloor = newFloor;
        bestTeam = List<CapturedOrganism>.from(nextTeam);
      }

      return u.copyWith(
        bestRogueFloor: bestFloor,
        bestRogueTeam: bestTeam,
        rogueLikeState: state.copyWith(
          floor: newFloor,
          encounterIndex: 0,
          currentBiome: selectedBiome,
          team: nextTeam,
          opponentTeam: newOpponents,
          currentOpponentIndex: 0,
          highestFloor: newFloor > state.highestFloor
              ? newFloor
              : state.highestFloor,
        ),
      );
    });
  }

  Future<void> endRogueRun() async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(
        rogueLikeState: u.rogueLikeState.copyWith(isActive: false, team: []),
      ),
    );
  }

  Future<void> captureForRogueRun(CapturedOrganism newCapture) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final team = List<CapturedOrganism>.from(u.rogueLikeState.team)
        ..add(newCapture);
      return u.copyWith(rogueLikeState: u.rogueLikeState.copyWith(team: team));
    });
  }

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

  Future<void> releaseFromRogueRun(int index) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (index < 0 || index >= u.rogueLikeState.team.length) return u;
      final team = List<CapturedOrganism>.from(u.rogueLikeState.team)
        ..removeAt(index);
      return u.copyWith(rogueLikeState: u.rogueLikeState.copyWith(team: team));
    });
  }

  Future<void> swapRogueTalismans(int indexA, int indexB) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final team = List<CapturedOrganism>.from(u.rogueLikeState.team);
      if (indexA < 0 ||
          indexA >= team.length ||
          indexB < 0 ||
          indexB >= team.length)
        return u;

      final tA = team[indexA].equippedTalisman;
      final tB = team[indexB].equippedTalisman;

      team[indexA] = team[indexA].copyWith(
        equippedTalisman: tB,
        clearTalisman: tB == null,
      );
      team[indexB] = team[indexB].copyWith(
        equippedTalisman: tA,
        clearTalisman: tA == null,
      );

      return u.copyWith(rogueLikeState: u.rogueLikeState.copyWith(team: team));
    });
  }

  Future<void> removeRogueTalisman(int index) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final team = List<CapturedOrganism>.from(u.rogueLikeState.team);
      if (index < 0 || index >= team.length) return u;

      team[index] = team[index].copyWith(clearTalisman: true);

      return u.copyWith(rogueLikeState: u.rogueLikeState.copyWith(team: team));
    });
  }

  Future<void> updateRogueRunState(RogueLikeState state) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.copyWith(rogueLikeState: state));
  }

  String _getRandomBiome() {
    final organisms = LocalAuthService.getCachedOrganisms();
    List<String> biomes = organisms
        .expand((o) => o.habitat.split(',').map((e) => e.trim()))
        .toSet()
        .toList();
    if (biomes.isEmpty) {
      biomes = [
        'Volcano',
        'Cave',
        'Coastal',
        'Coral Reef',
        'Deep Sea',
        'Frozen Ocean',
        'Kelp Forest',
        'Swamp',
        'Lake',
        'Mangrove',
        'Polar',
        'Rainforest',
        'Taiga',
        'Tundra',
        'Urban',
        'Jungle',
        'Desert',
        'Savanna',
        'River',
        'Ocean',
        'Mountain',
      ];
    }
    return biomes[Random().nextInt(biomes.length)];
  }

  List<CapturedOrganism> _generateRogueOpponentTeam(
    String biome,
    int count,
    int floor,
  ) {
    final organisms = LocalAuthService.getCachedOrganisms();
    final team = <CapturedOrganism>[];
    if (organisms.isEmpty) return team;
    final fallout = organisms
        .where((o) => o.habitat.toLowerCase().contains(biome.toLowerCase()))
        .toList();
    final pool = fallout.isEmpty ? organisms : fallout;
    bool isBoss = count > 1;
    int effectiveLevel =
        3 + (floor - 1) * 2 + (isBoss ? 2 : Random().nextInt(3));
    if (isBoss) count = count.clamp(2, 4);
    for (int i = 0; i < count; i++) {
      final base = pool[Random().nextInt(pool.length)];
      var spawn = isBoss
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
      if (Talisman.allTalismans.isNotEmpty) {
        spawn = spawn.copyWith(
          equippedTalisman: Talisman
              .allTalismans[Random().nextInt(Talisman.allTalismans.length)],
        );
      }
      team.add(spawn);
    }
    return team;
  }

  /// Awards XP after a battle.
  /// [defeatedLevel] is the level of the opponent animal.
  /// [killerId] is the unique ID of the animal that landed the final blow.
  /// [teamIds] are the unique IDs of all animals in the player's team.
  Future<Map<String, dynamic>> awardBattleXP({
    required int defeatedLevel,
    required String? killerId,
    required List<String> teamIds,
  }) async {
    if (_currentUser == null) return {};

    // XP constants - SUPER ACCELERATED
    final baseXP = defeatedLevel * 60; // Increased animal battle XP
    final accountXPShare = (defeatedLevel * 100).clamp(
      100,
      10000,
    ); // Significantly increased account XP

    Map<String, dynamic> results = {
      'accountLeveledUp': false,
      'animalLeveledUp': <String, bool>{},
      'gainedAnimalXP': baseXP,
      'gainedAccountXP': accountXPShare,
    };

    await _readModifyWrite((u) {
      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);
      final int accountLevel = u.accountLevel;

      // Update animals
      for (int i = 0; i < organisms.length; i++) {
        final org = organisms[i];
        if (teamIds.contains(org.id)) {
          int share = (org.id == killerId) ? baseXP : (baseXP / 2).floor();
          if (share > 0) {
            final xpResult = org.gainXP(share, accountLevel);
            if (xpResult['leveledUp'] as bool) {
              results['animalLeveledUp'][org.id] = true;
            }
            organisms[i] = org.copyWith(
              xp: xpResult['xp'] as int,
              level: xpResult['level'] as int,
              satisfaction: min(
                255,
                org.satisfaction + 2,
              ), // Increase satisfaction on victory
            );
          }
        }
      }

      // Update Account XP
      int newAccountXP = u.accountXP + accountXPShare;
      int newAccountLevel = u.accountLevel;
      bool accountLeveledUp = false;

      // Account XP formula: (level^2) * 100
      int xpForNextAccountLevel(int l) => (l * l) * 100;

      while (newAccountXP >= xpForNextAccountLevel(newAccountLevel + 1)) {
        newAccountLevel++;
        accountLeveledUp = true;
        results['accountLeveledUp'] = true;
      }

      // If account leveled up, refresh ALL animals to see if they can now level up
      if (accountLeveledUp) {
        for (int i = 0; i < organisms.length; i++) {
          final org = organisms[i];
          final xpResult = org.gainXP(0, newAccountLevel);
          if (xpResult['leveledUp'] as bool) {
            results['animalLeveledUp'][org.id] = true;
            organisms[i] = org.copyWith(level: xpResult['level'] as int);
          }
        }
      }

      return u.copyWith(
        capturedOrganisms: organisms,
        accountXP: newAccountXP,
        accountLevel: newAccountLevel,
      );
    });

    return results;
  }

  /// Awards KV (Kill Values) to the killer animal after defeating an opponent.
  /// The KV stat is determined by the defeated animal's highest base stat.
  Future<void> awardKV(String? killerId, Organism defeatedOrganism) async {
    if (_currentUser == null || killerId == null) return;
    final statKey = defeatedOrganism.highestBaseStat;
    final kvAmount = Organism.kvYield(defeatedOrganism.rarity);

    await _readModifyWrite((u) {
      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);
      for (int i = 0; i < organisms.length; i++) {
        final org = organisms[i];
        if (org.id == killerId) {
          final currentKVs = Map<String, int>.from(org.killValues);
          final currentTotal = currentKVs.values.fold(0, (s, v) => s + v);
          final currentStat = currentKVs[statKey] ?? 0;
          // Check caps
          if (currentTotal < CapturedOrganism.maxTotalKV &&
              currentStat < CapturedOrganism.maxStatKV) {
            final remaining = CapturedOrganism.maxTotalKV - currentTotal;
            final statRemaining = CapturedOrganism.maxStatKV - currentStat;
            final award = [
              kvAmount,
              remaining,
              statRemaining,
            ].reduce((a, b) => a < b ? a : b);
            currentKVs[statKey] = currentStat + award;
            organisms[i] = org.copyWith(
              killValues: currentKVs,
              satisfaction: min(
                255,
                org.satisfaction + 1,
              ), // Minor satisfaction boost for KO
            );
          }
          break;
        }
      }
      return u.copyWith(capturedOrganisms: organisms);
    });
  }

  /// Applies a mint item to change an animal's nature.
  /// Consumes 1 mint from inventory. Format of mintId: 'adamant_mint'
  Future<bool> applyMint(int orgIndex, String mintId) async {
    if (_currentUser == null) return false;
    // Check user has the mint
    if ((_currentUser!.inventory[mintId] ?? 0) <= 0) return false;
    // Derive nature name from mint id (e.g. 'adamant_mint' -> 'Adamant')
    final natureName = mintId
        .replaceAll('_mint', '')
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
    final nature = Nature.findByName(natureName);
    bool success = false;
    await _readModifyWrite((u) {
      if (orgIndex < 0 || orgIndex >= u.capturedOrganisms.length) return u;
      final inventory = Map<String, int>.from(u.inventory);
      inventory[mintId] = (inventory[mintId] ?? 1) - 1;
      if (inventory[mintId]! <= 0) inventory.remove(mintId);
      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);
      organisms[orgIndex] = organisms[orgIndex].copyWith(nature: nature);
      success = true;
      return u.copyWith(capturedOrganisms: organisms, inventory: inventory);
    });
    return success;
  }

  /// Applies a berry item to an animal to reduce KVs and increase satisfaction.
  Future<bool> applyBerry(int orgIndex, String berryId) async {
    if (_currentUser == null) return false;
    // Check user has the berry
    if ((_currentUser!.inventory[berryId] ?? 0) <= 0) return false;

    bool success = false;
    await _readModifyWrite((u) {
      if (orgIndex < 0 || orgIndex >= u.capturedOrganisms.length) return u;
      final inventory = Map<String, int>.from(u.inventory);
      inventory[berryId] = (inventory[berryId] ?? 1) - 1;
      if (inventory[berryId]! <= 0) inventory.remove(berryId);

      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);
      // We must modify a copy or just call the method if it's mutable (CapturedOrganism is mutable in this codebase)
      // but to follow the copyWith pattern safely:
      final updatedOrg = organisms[orgIndex].copyWith();
      updatedOrg.applyBerry(berryId);
      organisms[orgIndex] = updatedOrg;

      success = true;
      return u.copyWith(capturedOrganisms: organisms, inventory: inventory);
    });
    return success;
  }

  /// Manually reduces KV of a specific stat.
  Future<void> reduceKV(int orgIndex, String statKey, int amount) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (orgIndex < 0 || orgIndex >= u.capturedOrganisms.length) return u;
      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);
      final org = organisms[orgIndex];
      final currentKVs = Map<String, int>.from(org.killValues);
      currentKVs[statKey] = max(0, (currentKVs[statKey] ?? 0) - amount);
      organisms[orgIndex] = org.copyWith(killValues: currentKVs);
      return u.copyWith(capturedOrganisms: organisms);
    });
  }

  @override
  void dispose() {
    _staminaRegenTimer?.cancel();
    super.dispose();
  }
}
