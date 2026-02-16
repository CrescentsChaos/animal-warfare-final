// lib/user_state.dart
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

  Future<void> setActiveAttacker(int index) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (u.capturedOrganisms.isEmpty) return u;
      final i = index.clamp(0, u.capturedOrganisms.length - 1);
      return u.copyWith(activeAttackerIndex: i);
    });
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

  Future<void> releaseOrganism(int index) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (u.capturedOrganisms.isEmpty ||
          index < 0 ||
          index >= u.capturedOrganisms.length)
        return u;
      final list = List<CapturedOrganism>.from(u.capturedOrganisms)
        ..removeAt(index);
      int newAttacker = u.activeAttackerIndex;
      if (list.isEmpty) {
        newAttacker = 0;
      } else if (index <= u.activeAttackerIndex) {
        newAttacker = (u.activeAttackerIndex - 1).clamp(0, list.length - 1);
      } else {
        newAttacker = u.activeAttackerIndex.clamp(0, list.length - 1);
      }
      final newTeam = u.battleTeam
          .where((i) => i != index)
          .map((i) => i > index ? i - 1 : i)
          .toList();
      return u.copyWith(
        capturedOrganisms: list,
        activeAttackerIndex: newAttacker,
        battleTeam: newTeam,
      );
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
      if (organismIndex < 0 || organismIndex >= u.capturedOrganisms.length)
        return u;
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
        2)
      return;
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

  Future<void> incrementRogueFloor() async {
    if (_currentUser == null) return;
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
        nextTeam = nextTeam.map((member) {
          final int newLevel = member.level + 2;
          var upgraded = member.copyWith(level: newLevel);
          upgraded.restoreAllStamina();
          return upgraded.copyWith(
            currentHealth: upgraded.maxHealth,
            statusEffects: [],
          );
        }).toList();
      }
      final newOpponents = _generateRogueOpponentTeam(
        newBiome ?? 'Forest',
        newEncounter == 4 ? (2 + Random().nextInt(4)).clamp(2, 5) : 1,
        newFloor,
      );
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
    if (biomes.isEmpty)
      biomes = ['Jungle', 'Desert', 'Savanna', 'River', 'Ocean', 'Mountain'];
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

  @override
  void dispose() {
    _staminaRegenTimer?.cancel();
    super.dispose();
  }
}
