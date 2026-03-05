// lib/user_state.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/quest.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/nature.dart';
import 'dart:math' as math;
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

  Future<void> updateProfile({
    String? avatar,
    String? gender,
    String? displayName,
    String? avatarIconKey,
    String? faction,
    String? title,
    String? bio,
  }) async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(
        avatar: avatar,
        gender: gender,
        displayName: displayName,
        avatarIconKey: avatarIconKey,
        faction: faction,
        title: title,
        bio: bio,
      ),
    );
  }

  Future<void> addCapturedOrganism(CapturedOrganism newCapture) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final list = List<CapturedOrganism>.from(u.capturedOrganisms)
        ..add(newCapture);

      // Mark species as captured in stats
      final newStats = Map<String, Map<String, int>>.from(
        u.speciesStats.map((k, v) => MapEntry(k, Map<String, int>.from(v))),
      );
      final species = newCapture.name;
      final existing =
          newStats[species] ?? {'matches': 0, 'wins': 0, 'captured': 0};
      newStats[species] = {
        'matches': existing['matches'] ?? 0,
        'wins': existing['wins'] ?? 0,
        'captured': 1,
      };

      return u.copyWith(capturedOrganisms: list, speciesStats: newStats);
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

  Future<void> updateDisplayedAchievements(
    List<String> achievementTitles,
  ) async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) =>
          u.copyWith(displayedAchievements: achievementTitles.take(3).toList()),
    );
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

  Future<bool> sellItem(String itemId, int count, int pricePerItem) async {
    if (_currentUser == null) return false;
    bool success = false;
    await _readModifyWrite((u) {
      final inv = Map<String, int>.from(u.inventory);
      final currentCount = inv[itemId] ?? 0;
      if (currentCount >= count) {
        inv[itemId] = currentCount - count;
        if (inv[itemId] == 0) inv.remove(itemId);
        success = true;
        return u.copyWith(
          inventory: inv,
          money: u.money + (pricePerItem * count),
        );
      }
      return u;
    });
    return success;
  }

  Future<void> renameOrganism(String id, String newNickname) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final orgs = List<CapturedOrganism>.from(u.capturedOrganisms);
      final index = orgs.indexWhere((o) => o.id == id);
      if (index != -1) {
        orgs[index] = orgs[index].copyWith(nickname: newNickname);
      }

      // Also update in rogue team if active
      var rogueState = u.rogueLikeState;
      if (rogueState.isActive) {
        final rogueTeam = List<CapturedOrganism>.from(rogueState.team);
        final rIndex = rogueTeam.indexWhere((o) => o.id == id);
        if (rIndex != -1) {
          rogueTeam[rIndex] = rogueTeam[rIndex].copyWith(nickname: newNickname);
          rogueState = rogueState.copyWith(team: rogueTeam);
        }
      }

      return u.copyWith(capturedOrganisms: orgs, rogueLikeState: rogueState);
    });
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
          // Restore Stamina
          final Map<String, int> fullStamina = {};
          for (final moveName in org.selectedMoveNames) {
            final move = Move.findByName(moveName);
            fullStamina[moveName] = move?.stamina ?? Move.defaultStamina;
          }

          organisms[index] = org.copyWith(
            currentHealth: org.maxHealth,
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

  /// Equips a talisman from either craftedTalismans list or global inventory.
  /// Returns the old talisman to the appropriate source.
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
      final newInventory = Map<String, int>.from(u.inventory);

      if (talismanId != null) {
        // Try crafted first
        final tIndex = newCrafted.indexOf(talismanId);
        if (tIndex != -1) {
          // From crafted pool
          newCrafted.removeAt(tIndex);
        } else {
          // Try global inventory
          final invCount = newInventory[talismanId] ?? 0;
          if (invCount <= 0) return u; // Not available anywhere
          newInventory[talismanId] = invCount - 1;
          if (newInventory[talismanId]! <= 0) newInventory.remove(talismanId);
        }
        organisms[organismIndex] = targetOrg.copyWith(
          equippedTalisman: Talisman.findById(talismanId),
        );
      } else {
        organisms[organismIndex] = targetOrg.copyWith(clearTalisman: true);
      }

      // Return old talisman: check if the id is in craftedTalismans - if yes, it was crafted.
      // Otherwise put it back in inventory.
      if (oldId != null) {
        // We check if oldId was originally from crafted (craftedTalismans still has other entries with same id? no—we just removed one)
        // Heuristic: if it's a known non-shop talisman or is in craftedTalismans pool name list, use crafted
        // Simpler: always return to craftedTalismans for now (backwards compatible)
        newCrafted.add(oldId);
      }

      return u.copyWith(
        capturedOrganisms: organisms,
        craftedTalismans: newCrafted,
        inventory: newInventory,
      );
    });
  }

  Future<void> useAbilityCapsule(
    int organismIndex,
    String newAbilityName,
  ) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (organismIndex < 0 || organismIndex >= u.capturedOrganisms.length) {
        return u;
      }
      final newTalismans = List<String>.from(u.craftedTalismans);
      final capsuleIndex = newTalismans.indexOf('Ability Capsule');
      if (capsuleIndex == -1) return u;

      newTalismans.removeAt(capsuleIndex);

      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);
      final org = organisms[organismIndex];
      organisms[organismIndex] = org.changeAbility(newAbilityName);

      return u.copyWith(
        craftedTalismans: newTalismans,
        capturedOrganisms: organisms,
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
        // Fix: Skip "River Monsters" category for automatic updates
        if (quest.status == QuestStatus.active &&
            quest.category != 'River Monsters' &&
            quest.targetOrganismName == organismName) {
          return quest.copyWith(currentCount: quest.currentCount + 1);
        }
        return quest;
      }).toList();
      return u.copyWith(activeQuests: list);
    });
  }

  Future<void> submitQuestAnimal(
    String questId,
    CapturedOrganism organism,
  ) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final index = u.activeQuests.indexWhere((q) => q.id == questId);
      if (index == -1) return u;
      final quest = u.activeQuests[index];

      if (quest.status != QuestStatus.active) return u;
      if (quest.targetOrganismName != organism.baseOrganism.name) return u;

      final newList = u.activeQuests.map((q) {
        if (q.id == questId) {
          return q.copyWith(currentCount: q.currentCount + 1);
        }
        return q;
      }).toList();

      // Release the animal
      final newCaptured = List<CapturedOrganism>.from(u.capturedOrganisms)
        ..removeWhere((o) => o.id == organism.id);

      // Re-map team indices since list changed
      final currentTeamIds = u.battleTeam
          .map((idx) => u.capturedOrganisms[idx].id)
          .where((id) => id != organism.id)
          .toList();

      final updatedTeamIndices = <int>[];
      for (final id in currentTeamIds) {
        final newIdx = newCaptured.indexWhere((o) => o.id == id);
        if (newIdx != -1) updatedTeamIndices.add(newIdx);
      }

      return u.copyWith(
        activeQuests: newList,
        capturedOrganisms: newCaptured,
        battleTeam: updatedTeamIndices,
      );
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

  Future<void> startRogueRun({CapturedOrganism? starter, String? biome}) async {
    if (_currentUser == null) return;

    // Clear any existing run
    await LocalAuthService.loadOrganisms();
    final selectedBiome = biome ?? getRandomBiome();

    // Default inventory: 5 capture nets
    Map<String, int> initialInventory = {'capture_net': 5};

    List<CapturedOrganism> startingTeam = [];
    if (starter != null) {
      startingTeam = [starter];
    }

    final opponents = _generateRogueOpponentTeam(
      selectedBiome,
      1, // 1st battle usually 1 enemy
      1, // floor 1
      encounterIndex: 0,
      playerTeamOverride: startingTeam,
    );

    await _readModifyWrite(
      (u) => u.copyWith(
        rogueLikeState: RogueLikeState(
          floor: 1,
          encounterIndex: 0,
          currentBiome: selectedBiome,
          inventory: initialInventory,
          team: startingTeam,
          opponentTeam: opponents,
          isActive: true,
          highestFloor: u.rogueLikeState.highestFloor,
        ),
      ),
    );
  }

  List<CapturedOrganism> generateStarterOptions(String biome) {
    final organisms = LocalAuthService.getCachedOrganisms();
    if (organisms.isEmpty) return [];

    final pool = organisms
        .where((o) => o.habitat.toLowerCase().contains(biome.toLowerCase()))
        .toList();
    // Pool already excludes human since human habitat is "Everywhere" and we usually search for specific biomes
    // or pool defaults to everything discovered.
    // Ensure Human is explicitly excluded if it sneaks in.
    final selectionPool = pool.isEmpty ? organisms : pool;

    final options = <CapturedOrganism>[];
    final random = math.Random();

    // Try to pick 3 balanced starters (around level 5)
    while (options.length < 3 && options.length < selectionPool.length) {
      final base = selectionPool[random.nextInt(selectionPool.length)];
      if (base.name == 'Human') continue;
      if (options.any((o) => o.baseOrganism.name == base.name)) continue;

      options.add(
        CapturedOrganism.spawn(base, level: 1),
      ); // Starter level set to 1
    }

    return options;
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

      // If we just finished the 5th battle (newEncounter == 5),
      // we don't generate a new opponent team for a 6th battle.
      List<CapturedOrganism>? newOpponents = state.opponentTeam;
      if (newEncounter < 5) {
        newOpponents = _generateRogueOpponentTeam(
          state.currentBiome ?? 'Jungle',
          newEncounter == 4
              ? (2 + math.Random().nextInt(4)).clamp(2, 5)
              : 1, // Boss is at index 4 (5th fight)
          state.floor,
          encounterIndex: newEncounter,
        );
      }

      // Generate rewards after every battle
      final rewards = _generateRogueRewards(state.floor, newEncounter == 5);

      return u.copyWith(
        rogueLikeState: state.copyWith(
          encounterIndex: newEncounter,
          opponentTeam: newOpponents,
          currentOpponentIndex: 0,
          pendingRewards: rewards,
        ),
      );
    });
  }

  List<RogueReward> _generateRogueRewards(int floor, bool isPremium) {
    final rewards = <RogueReward>[];
    final random = math.Random();

    if (isPremium) {
      // Special premium rewards after 5th battle
      rewards.add(
        const RogueReward(
          type: RogueRewardType.premium,
          label: 'GOLDEN TALISMAN',
        ),
      );
      rewards.add(
        const RogueReward(
          type: RogueRewardType.natureMint,
          label: 'MYSTICAL NATURE MINT',
        ),
      );
      rewards.add(
        const RogueReward(
          type: RogueRewardType.premium,
          label: 'LEGENDARY SNACK',
        ),
      );
      return rewards;
    }

    // Normal rewards: pick 3 different types with weighting
    // Weights: Item: 2, FullHeal: 1, SingleHeal: 3, CureStatus: 1, CaptureItems: 3
    final weightMap = <RogueRewardType, int>{
      RogueRewardType.item: 2,
      RogueRewardType.fullHeal: 1,
      RogueRewardType.singleHeal: 4,
      RogueRewardType.cureStatus: 1,
      RogueRewardType.captureItems: 4,
      RogueRewardType.natureMint: 1,
    };

    final availableTypes = RogueRewardType.values
        .where((t) => t != RogueRewardType.premium && weightMap.containsKey(t))
        .toList();

    Set<RogueRewardType> selectedTypes = {};
    while (selectedTypes.length < 3 &&
        selectedTypes.length < availableTypes.length) {
      // Weighted selection
      int totalWeight = 0;
      weightMap.forEach((type, weight) {
        if (!selectedTypes.contains(type)) totalWeight += weight;
      });

      int r = random.nextInt(totalWeight);
      int current = 0;
      for (var type in weightMap.keys) {
        if (selectedTypes.contains(type)) continue;
        current += weightMap[type]!;
        if (r < current) {
          selectedTypes.add(type);
          break;
        }
      }
    }

    for (final type in selectedTypes) {
      switch (type) {
        case RogueRewardType.item:
          final allTalismans = Talisman.allTalismans
              .where((t) => t.id != 'none' && t.effects.isNotEmpty)
              .toList();
          if (allTalismans.isNotEmpty) {
            final randomTalisman =
                allTalismans[random.nextInt(allTalismans.length)];
            rewards.add(
              RogueReward(
                type: RogueRewardType.item,
                label: 'TALISMAN: ${randomTalisman.name.toUpperCase()}',
                itemId: randomTalisman.id,
              ),
            );
          } else {
            rewards.add(
              const RogueReward(
                type: RogueRewardType.item,
                label: 'LUCKY CHARM',
                itemId: 'lucky_charm',
              ),
            );
          }
          break;
        case RogueRewardType.fullHeal:
          rewards.add(
            const RogueReward(
              type: RogueRewardType.fullHeal,
              label: 'FULL TEAM HEAL',
            ),
          );
          break;
        case RogueRewardType.singleHeal:
          rewards.add(
            const RogueReward(
              type: RogueRewardType.singleHeal,
              label: 'SINGLE ANIMAL HEAL',
            ),
          );
          break;
        case RogueRewardType.cureStatus:
          rewards.add(
            const RogueReward(
              type: RogueRewardType.cureStatus,
              label: 'RESTORE ALL STAMINA',
            ),
          );
          break;
        case RogueRewardType.captureItems:
          // Random 1-3 nets
          final count = 1 + random.nextInt(3);
          rewards.add(
            RogueReward(
              type: RogueRewardType.captureItems,
              label: '$count' + (count == 1 ? ' CAPTURE NET' : ' CAPTURE NETS'),
              itemId: 'capture_net',
              count: count,
            ),
          );
          break;
        case RogueRewardType.natureMint:
          rewards.add(
            const RogueReward(
              type: RogueRewardType.natureMint,
              label: 'NATURE MINT',
              itemId: 'nature_mint',
            ),
          );
          break;
        default:
          break;
      }
    }
    return rewards;
  }

  Future<void> claimRogueReward(RogueReward reward) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final state = u.rogueLikeState;
      final inventory = Map<String, int>.from(state.inventory);
      List<CapturedOrganism> team = List.from(state.team);

      switch (reward.type) {
        case RogueRewardType.item:
          if (reward.itemId != null) {
            inventory[reward.itemId!] = (inventory[reward.itemId!] ?? 0) + 1;
          }
          break;
        case RogueRewardType.fullHeal:
          team = team
              .map((org) => org.copyWith(currentHealth: org.maxHealth))
              .toList();
          break;
        case RogueRewardType.singleHeal:
          // Heal the chosen animal or the one with lowest HP %
          if (team.isNotEmpty) {
            int targetIdx;
            if (reward.targetIndex != null &&
                reward.targetIndex! >= 0 &&
                reward.targetIndex! < team.length) {
              targetIdx = reward.targetIndex!;
            } else {
              targetIdx = 0;
              double lowestRatio = 1.1;
              for (int i = 0; i < team.length; i++) {
                final ratio = team[i].currentHealth / team[i].maxHealth;
                if (ratio < lowestRatio) {
                  lowestRatio = ratio;
                  targetIdx = i;
                }
              }
            }
            team[targetIdx] = team[targetIdx].copyWith(
              currentHealth: team[targetIdx].maxHealth,
            );
          }
          break;
        case RogueRewardType.cureStatus:
          team = team.map((org) => org..restoreAllStamina()).toList();
          break;
        case RogueRewardType.captureItems:
          inventory['capture_net'] =
              (inventory['capture_net'] ?? 0) + (reward.count ?? 1);
          break;
        case RogueRewardType.natureMint:
          inventory['nature_mint'] = (inventory['nature_mint'] ?? 0) + 1;
          break;
        case RogueRewardType.premium:
          inventory['premium_token'] = (inventory['premium_token'] ?? 0) + 1;
          break;
      }

      return u.copyWith(
        rogueLikeState: state.copyWith(
          inventory: inventory,
          team: team,
          clearPendingRewards: true,
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
        playerTeamOverride: nextTeam,
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
        rogueLikeState: u.rogueLikeState.copyWith(
          isActive: false,
          team: [],
          inventory: {},
          pendingRewards: null,
        ),
      ),
    );
  }

  Future<void> captureForRogueRun(CapturedOrganism newCapture) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final team = List<CapturedOrganism>.from(u.rogueLikeState.team)
        ..add(newCapture);

      // Mark species as captured in stats (Roguelike counts too!)
      final newStats = Map<String, Map<String, int>>.from(
        u.speciesStats.map((k, v) => MapEntry(k, Map<String, int>.from(v))),
      );
      final species = newCapture.name;
      final existing =
          newStats[species] ?? {'matches': 0, 'wins': 0, 'captured': 0};
      newStats[species] = {
        'matches': existing['matches'] ?? 0,
        'wins': existing['wins'] ?? 0,
        'captured': 1,
      };

      return u.copyWith(
        rogueLikeState: u.rogueLikeState.copyWith(team: team),
        speciesStats: newStats,
      );
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
      final state = u.rogueLikeState;
      final team = List<CapturedOrganism>.from(state.team);
      if (index < 0 || index >= team.length) return u;

      final old = team[index].equippedTalisman;
      final inv = Map<String, int>.from(state.inventory);
      if (old != null) {
        inv[old.id] = (inv[old.id] ?? 0) + 1;
      }

      team[index] = team[index].copyWith(clearTalisman: true);

      return u.copyWith(
        rogueLikeState: state.copyWith(team: team, inventory: inv),
      );
    });
  }

  Future<void> changeRogueAnimalNature(int index, Nature newNature) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final state = u.rogueLikeState;
      final team = List<CapturedOrganism>.from(state.team);
      if (index < 0 || index >= team.length) return u;

      final inventory = Map<String, int>.from(state.inventory);
      final mintCount = inventory['nature_mint'] ?? 0;

      if (mintCount > 0) {
        inventory['nature_mint'] = mintCount - 1;
        team[index] = team[index].copyWith(nature: newNature);
        return u.copyWith(
          rogueLikeState: state.copyWith(team: team, inventory: inventory),
        );
      }
      return u;
    });
  }

  Future<bool> applyRogueBerry(int orgIndex, String berryId) async {
    if (_currentUser == null) return false;
    bool success = false;
    await _readModifyWrite((u) {
      final state = u.rogueLikeState;
      final team = List<CapturedOrganism>.from(state.team);
      if (orgIndex < 0 || orgIndex >= team.length) return u;

      final inventory = Map<String, int>.from(state.inventory);
      final berryCount = inventory[berryId] ?? 0;

      if (berryCount > 0) {
        inventory[berryId] = berryCount - 1;
        if (inventory[berryId]! <= 0) inventory.remove(berryId);

        final updatedOrg = team[orgIndex].copyWith();
        updatedOrg.applyBerry(berryId);
        team[orgIndex] = updatedOrg;

        success = true;
        return u.copyWith(
          rogueLikeState: state.copyWith(team: team, inventory: inventory),
        );
      }
      return u;
    });
    return success;
  }

  Future<void> equipRogueTalisman(int teamIndex, String talismanId) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final state = u.rogueLikeState;
      final team = List<CapturedOrganism>.from(state.team);
      if (teamIndex < 0 || teamIndex >= team.length) return u;

      final talisman = Talisman.findById(talismanId);
      if (talisman == null) return u;

      final inv = Map<String, int>.from(state.inventory);
      if ((inv[talismanId] ?? 0) <= 0) return u;

      // Return old item to inventory if any
      final old = team[teamIndex].equippedTalisman;
      if (old != null) {
        inv[old.id] = (inv[old.id] ?? 0) + 1;
      }

      // Take from inventory
      inv[talismanId] = inv[talismanId]! - 1;
      if (inv[talismanId] == 0) inv.remove(talismanId);

      team[teamIndex] = team[teamIndex].copyWith(equippedTalisman: talisman);

      return u.copyWith(
        rogueLikeState: state.copyWith(team: team, inventory: inv),
      );
    });
  }

  Future<void> addRogueLoot(String itemId, int amount) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final state = u.rogueLikeState;
      final inv = Map<String, int>.from(state.inventory);
      inv[itemId] = (inv[itemId] ?? 0) + amount;
      if (inv[itemId]! <= 0) inv.remove(itemId);
      return u.copyWith(rogueLikeState: state.copyWith(inventory: inv));
    });
  }

  Future<void> updateRogueRunState(RogueLikeState state) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.copyWith(rogueLikeState: state));
  }

  String getRandomBiome() {
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
    return biomes[math.Random().nextInt(biomes.length)];
  }

  List<CapturedOrganism> _generateRogueOpponentTeam(
    String biome,
    int count,
    int floor, {
    int encounterIndex = 0,
    List<CapturedOrganism>? playerTeamOverride,
  }) {
    final organisms = LocalAuthService.getCachedOrganisms();
    if (organisms.isEmpty) return [];

    final pool = organisms
        .where((o) => o.habitat.toLowerCase().contains(biome.toLowerCase()))
        .toList();
    final selectionPool = pool.isEmpty ? organisms : pool;

    // Get player's highest level to cap opponent scaling
    final playerTeam =
        playerTeamOverride ?? _currentUser?.rogueLikeState.team ?? [];
    final maxPlayerLevel = playerTeam.isNotEmpty
        ? playerTeam.map((o) => o.level).reduce(math.max)
        : 1;

    final team = <CapturedOrganism>[];
    final random = math.Random();
    bool isBoss = encounterIndex == 4;

    for (int i = 0; i < count; i++) {
      final base = selectionPool[random.nextInt(selectionPool.length)];

      int level;
      if (isBoss) {
        level = maxPlayerLevel + 2;
      } else {
        // Normal encounters: 1-2 levels lower
        level = maxPlayerLevel - (random.nextInt(2));
      }

      // Ensure level is at least 1
      level = math.max(1, level);

      team.add(CapturedOrganism.spawn(base, level: level));
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
    int? levelCap, // Optional cap
  }) async {
    if (_currentUser == null) return {};

    final effectiveCap = levelCap ?? _currentUser!.accountLevel;

    // Rebalanced XP constants
    final baseXP = defeatedLevel * 10; // Animal battle XP
    final accountXPShare = (defeatedLevel * 5).clamp(
      50,
      1000,
    ); // Account XP aligned with animal growth

    Map<String, dynamic> results = {
      'accountLeveledUp': false,
      'animalLeveledUp': <String, bool>{},
      'gainedAnimalXP': baseXP,
      'gainedAccountXP': accountXPShare,
    };

    await _readModifyWrite((u) {
      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);

      // Update animals
      for (int i = 0; i < organisms.length; i++) {
        final org = organisms[i];
        if (teamIds.contains(org.id)) {
          int share = (org.id == killerId) ? baseXP : (baseXP / 2).floor();
          if (share > 0) {
            // Normal team: use the effectiveCap (floor-based for roguelike)
            final xpResult = org.gainXP(share, effectiveCap);
            if (xpResult['leveledUp'] as bool) {
              results['animalLeveledUp'][org.id] = true;
            }
            organisms[i] = org.copyWith(
              xp: xpResult['xp'] as int,
              level: xpResult['level'] as int,
              currentHealth: xpResult['health'] as int,
              satisfaction: math.min(
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
          final xpResult = org.gainXP(0, effectiveCap);
          if (xpResult['leveledUp'] as bool) {
            results['animalLeveledUp'][org.id] = true;
            organisms[i] = org.copyWith(level: xpResult['level'] as int);
          }
        }
      }

      // Update Roguelike Team if active
      if (u.rogueLikeState.isActive) {
        final rogueTeam = List<CapturedOrganism>.from(u.rogueLikeState.team);
        for (int j = 0; j < rogueTeam.length; j++) {
          final org = rogueTeam[j];
          if (teamIds.contains(org.id)) {
            int share = (org.id == killerId) ? baseXP : (baseXP / 2).floor();
            if (share > 0) {
              // Roguelike team: ignore account level, use 100 as fallback if levelCap is null
              final rogueCap = levelCap ?? 100;
              final xpResult = org.gainXP(share, rogueCap);
              if (xpResult['leveledUp'] as bool) {
                results['animalLeveledUp'][org.id] = true;
              }
              rogueTeam[j] = org.copyWith(
                xp: xpResult['xp'] as int,
                level: xpResult['level'] as int,
                currentHealth: xpResult['health'] as int,
                satisfaction: math.min(255, org.satisfaction + 2),
              );
            }
          }
        }
        u = u.copyWith(
          rogueLikeState: u.rogueLikeState.copyWith(team: rogueTeam),
        );
      }

      return u.copyWith(
        capturedOrganisms: organisms,
        accountXP: newAccountXP,
        accountLevel: newAccountLevel,
      );
    });

    return results;
  }

  /// Updates or clears a persistent exploration encounter for a biome.
  Future<void> updateExplorationEncounter(
    String biome,
    CapturedOrganism? encounter,
  ) async {
    await _readModifyWrite((u) {
      final encounters = Map<String, CapturedOrganism?>.from(
        u.explorationEncounters,
      );
      encounters[biome] = encounter;
      return u.copyWith(explorationEncounters: encounters);
    });
  }

  /// Records wins/losses for all animals involved in a battle.
  Future<void> recordMatchResults({
    required List<String> playerSpecies,
    required List<String> opponentSpecies,
    required bool playerWon,
  }) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final newStats = Map<String, Map<String, int>>.from(
        u.speciesStats.map((k, v) => MapEntry(k, Map<String, int>.from(v))),
      );

      // Helper to update stats
      void update(String species, bool won) {
        final existing =
            newStats[species] ?? {'matches': 0, 'wins': 0, 'captured': 0};
        newStats[species] = {
          'matches': (existing['matches'] ?? 0) + 1,
          'wins': (existing['wins'] ?? 0) + (won ? 1 : 0),
          'captured': existing['captured'] ?? 0,
        };
      }

      // Track unique species in the team for that match
      final pUnique = playerSpecies.toSet();
      final oUnique = opponentSpecies.toSet();

      for (final species in pUnique) {
        update(species, playerWon);
      }
      for (final species in oUnique) {
        update(species, !playerWon);
      }

      return u.copyWith(speciesStats: newStats);
    });
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
              satisfaction: math.min(
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
  /// Consumes 1 Generic Nature Mint from inventory and applies the specified Nature.
  Future<bool> applyMint(int orgIndex, Nature newNature) async {
    if (_currentUser == null) return false;
    const mintId = 'nature_mint';
    if ((_currentUser!.inventory[mintId] ?? 0) <= 0) return false;

    await _readModifyWrite((u) {
      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);
      if (orgIndex < 0 || orgIndex >= organisms.length) return u;

      // Apply
      organisms[orgIndex] = organisms[orgIndex].copyWith(nature: newNature);

      // Consume
      final inventory = Map<String, int>.from(u.inventory);
      inventory[mintId] = (inventory[mintId] ?? 1) - 1;
      if (inventory[mintId]! <= 0) inventory.remove(mintId);

      return u.copyWith(capturedOrganisms: organisms, inventory: inventory);
    });
    return true;
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
      currentKVs[statKey] = math.max(0, (currentKVs[statKey] ?? 0) - amount);
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
