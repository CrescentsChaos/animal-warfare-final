// lib/user_state.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/player_active_effect.dart';
import 'package:animal_warfare/models/quest.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/nature.dart';
import 'dart:math' as math;
import 'package:animal_warfare/models/rogue_like_state.dart';
import 'package:animal_warfare/models/farm_slot.dart';
import 'package:animal_warfare/models/battle_replay.dart';
import 'package:animal_warfare/models/saved_map_state.dart';
import 'package:animal_warfare/models/event_flags.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/models/battle_card.dart';
import 'package:animal_warfare/models/survival_effect.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/services/weather_service.dart';
import 'local_auth_service.dart';
import 'achievement_service.dart';

class UserState with ChangeNotifier {
  UserData? _currentUser;
  final LocalAuthService _authService = LocalAuthService();
  Timer? _staminaRegenTimer;
  Future<void> _writeLock = Future.value();
  bool _isInitialized = false;
  Map<String, dynamic> _farmingConfig = {};

  UserData? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isInitialized => _isInitialized;
  Map<String, dynamic> get farmingConfig => _farmingConfig;
  bool _showDetailedCurrency = false;
  bool get showDetailedCurrency => _showDetailedCurrency;

  void toggleDetailedCurrency() {
    _showDetailedCurrency = !_showDetailedCurrency;
    notifyListeners();
  }

  static String formatCurrency(int value, {bool detailed = false}) {
    if (detailed || value.abs() < 1000) return value.toString();

    final sign = value < 0 ? "-" : "";
    final absVal = value.abs();

    if (absVal >= 1000000) {
      final m = absVal / 1000000.0;
      return "$sign${m.toStringAsFixed(m >= 10 ? 1 : 2)}M";
    } else if (absVal >= 1000) {
      final k = absVal / 1000.0;
      return "$sign${k.toStringAsFixed(k >= 10 ? 1 : 2)}K";
    }
    return value.toString();
  }

  UserState() {
    _init();
    _startStaminaRegeneration();
  }

  Future<void> _init() async {
    await loadCurrentUser();
    await _loadFarmingConfig();
  }

  Future<void> _loadFarmingConfig() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/farming.json',
      );
      _farmingConfig = json.decode(response);
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading farming.json: $e');
    }
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
      if (fresh == null) {
        if (kDebugMode) {
          print(
            'UserState: readUserFile returned null for $username, skipping update',
          );
        }
        return;
      }

      // Safety: if fresh data lost captured organisms that exist in memory,
      // the disk read likely failed to deserialize them (e.g. base organisms
      // not loaded). Fall back to the current in-memory list to prevent wipe.
      UserData safeBase = fresh;
      if (fresh.capturedOrganisms.isEmpty &&
          _currentUser!.capturedOrganisms.isNotEmpty) {
        if (kDebugMode) {
          print(
            'UserState: SAFETY — fresh data has 0 organisms but memory has '
            '${_currentUser!.capturedOrganisms.length}. Merging from memory.',
          );
        }
        safeBase = fresh.copyWith(
          capturedOrganisms: _currentUser!.capturedOrganisms,
          battleTeam: _currentUser!.battleTeam,
        );
      }

      final updated = update(safeBase);
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
      if (_currentUser != null) {
        if (_currentUser!.stamina < 100) {
          _regenerateStamina(20);
        }
        _processPlantGrowth();
        _cleanExpiredEffects();
      }
    });
  }

  Future<void> _cleanExpiredEffects() async {
    if (_currentUser == null) return;
    final now = DateTime.now();
    final hasExpiredLures = _currentUser!.activeEffects.any(
      (e) => now.isAfter(e.expiresAt),
    );
    final hasExpiredSurvival = _currentUser!.activeSurvivalEffects.any(
      (e) => now.isAfter(e.expiresAt),
    );

    if (!hasExpiredLures && !hasExpiredSurvival) return;

    await _readModifyWrite((u) {
      final filteredLures = u.activeEffects
          .where((e) => !now.isAfter(e.expiresAt))
          .toList();
      final filteredSurvival = u.activeSurvivalEffects
          .where((e) => !now.isAfter(e.expiresAt))
          .toList();
      return u.copyWith(
        activeEffects: filteredLures,
        activeSurvivalEffects: filteredSurvival,
      );
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

  double _staminaAccumulator = 0.0;

  Future<void> addStamina(double amount) async {
    if (_currentUser == null) return;
    _staminaAccumulator += amount;
    if (_staminaAccumulator >= 1.0) {
      final int toAdd = _staminaAccumulator.floor();
      _staminaAccumulator -= toAdd;
      await _regenerateStamina(toAdd);
    }
  }

  Future<void> updateProfile({
    String? avatar,
    String? gender,
    String? displayName,
    String? avatarIconKey,
    String? faction,
    String? title,
    String? bio,
    String? avatarFrame,
    String? profileBackground,
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
        avatarFrame: avatarFrame,
        profileBackground: profileBackground,
      ),
    );
  }

  /// Performs an atomic read-modify-write operation on the current user.
  /// The [updater] function receives the freshest data from disk.
  Future<void> updateUserAtomic(UserData Function(UserData) updater) async {
    await _readModifyWrite(updater);
  }

  Future<void> updateUserData(UserData updated) async {
    if (_currentUser == null) return;
    // 🔴 CRITICAL FIX: Instead of blindly overwriting with 'updated',
    // we use _readModifyWrite to ensure we don't lose data updated by other services (like achievements).
    // However, since we don't know exactly what changed in 'updated',
    // this remains a bit risky if 'updated' was based on very stale data.
    // Prefer using more specific atomic update methods.
    await _readModifyWrite((u) => updated);
  }

  /// Checks and unlocks achievements atomically.
  Future<List<String>> checkAndUnlockAchievements(
    AchievementService service,
  ) async {
    if (_currentUser == null) return [];
    List<String> newlyUnlocked = [];

    await _readModifyWrite((u) {
      newlyUnlocked = service.checkAndUnlockAchievements(u);
      if (newlyUnlocked.isEmpty) return u;

      final completed = Set<String>.from(u.completedAchievements);
      completed.addAll(newlyUnlocked);

      return u.copyWith(completedAchievements: completed.toList());
    });

    return newlyUnlocked;
  }

  void logout() {
    _currentUser = null;
    notifyListeners();
  }

  Future<void> addCapturedOrganism(CapturedOrganism newCapture) async {
    if (_currentUser == null) return;

    // Ensure capture metadata is recorded if it's a fresh capture (not restored from JSON)
    CapturedOrganism finalCapture = newCapture;
    if (finalCapture.capturedAtReal == null) {
      finalCapture = finalCapture.copyWith(
        capturedAtReal: DateTime.now(),
        capturedAtGame: TimeService().currentGameTime,
      );
    }

    await _readModifyWrite((u) {
      final list = List<CapturedOrganism>.from(u.capturedOrganisms)
        ..add(finalCapture);

      final newIndex = list.length - 1;
      if (kDebugMode) {
        print(
          'UserState: ADD CAPTURE: ${finalCapture.name} (Index: $newIndex, Total: ${list.length})',
        );
      }

      // Auto-add to team if not full
      final team = List<int>.from(u.battleTeam);
      if (team.length < 5) {
        team.add(newIndex);
        if (kDebugMode) {
          print('UserState: AUTO-ADDED to team. New Team: $team');
        }
      }

      final species = finalCapture.name;

      // Mark as discovered if not already
      final discovered = Set<String>.from(u.discoveredOrganisms);
      discovered.add(species);

      // Mark species as captured in stats
      final newStats = Map<String, Map<String, int>>.from(
        u.speciesStats.map((k, v) => MapEntry(k, Map<String, int>.from(v))),
      );
      final existing =
          newStats[species] ?? {'matches': 0, 'wins': 0, 'captured': 0};
      newStats[species] = {
        'matches': existing['matches'] ?? 0,
        'wins': existing['wins'] ?? 0,
        'captured': (existing['captured'] ?? 0) + 1,
      };

      return u.copyWith(
        capturedOrganisms: list,
        speciesStats: newStats,
        battleTeam: team,
        discoveredOrganisms: discovered.toList(),
      );
    });
  }

  /// Atomically feeds an organism and consumes the food from inventory.
  Future<void> feedOrganism(String organismId, Talisman food) async {
    if (_currentUser == null) return;

    await _readModifyWrite((u) {
      final inventory = Map<String, int>.from(u.inventory);
      final count = inventory[food.id] ?? 0;
      if (count <= 0) return u; // No food left

      inventory[food.id] = count - 1;

      final captured = List<CapturedOrganism>.from(u.capturedOrganisms);
      final index = captured.indexWhere((o) => o.id == organismId);
      if (index == -1) return u; // Organism not found

      // Modifying the organism in the list.
      captured[index].feed(food);

      return u.copyWith(inventory: inventory, capturedOrganisms: captured);
    });
  }

  /// Atomically consumes a taxonomic lure from inventory and adds its player effect.
  Future<bool> consumeLure(Talisman lure) async {
    if (_currentUser == null) return false;
    if (!lure.isLure) return false;

    bool success = false;
    await _readModifyWrite((u) {
      final inventory = Map<String, int>.from(u.inventory);
      final count = inventory[lure.id] ?? 0;
      if (count <= 0) return u; // Not in inventory

      // Decrement count
      inventory[lure.id] = count - 1;
      if (inventory[lure.id] == 0) {
        inventory.remove(lure.id);
      }

      // Add active effect
      final activeEffects = List<PlayerActiveEffect>.from(u.activeEffects);

      // Calculate expiration time
      final duration = Duration(minutes: lure.durationMinutes ?? 15);
      final expiresAt = DateTime.now().add(duration);

      activeEffects.add(
        PlayerActiveEffect(
          id: lure.id,
          name: lure.name,
          targetType: lure.targetTaxonomyType ?? 'class',
          targetValue: lure.targetTaxonomyValue ?? '',
          multiplier: lure.lureMultiplier ?? 2.0,
          expiresAt: expiresAt,
        ),
      );

      success = true;
      return u.copyWith(inventory: inventory, activeEffects: activeEffects);
    });

    return success;
  }

  /// Atomically consumes a survival item (hot cocoa, etc.) and adds its effect.
  Future<bool> consumeSurvivalItem(Talisman item) async {
    if (_currentUser == null) return false;
    if (!item.isSurvivalItem) return false;

    bool success = false;
    await _readModifyWrite((u) {
      final inventory = Map<String, int>.from(u.inventory);
      final count = inventory[item.id] ?? 0;
      if (count <= 0) return u; // Not in inventory

      // Decrement count
      inventory[item.id] = count - 1;
      if (inventory[item.id] == 0) {
        inventory.remove(item.id);
      }

      // Add active effect
      final activeSurvivalEffects = List<SurvivalEffect>.from(
        u.activeSurvivalEffects,
      );

      // Calculate expiration time
      final duration = Duration(minutes: item.survivalDurationMinutes ?? 30);
      final expiresAt = DateTime.now().add(duration);

      activeSurvivalEffects.add(
        SurvivalEffect(
          id: item.id,
          name: item.name,
          mitigatesSeverity: EnvironmentalSeverity.values.firstWhere(
            (e) => e.name == item.mitigatesSeverity,
            orElse: () => EnvironmentalSeverity.comfortable,
          ),
          damageReductionMultiplier: item.survivalDamageReduction ?? 1.0,
          expiresAt: expiresAt,
        ),
      );

      success = true;
      return u.copyWith(
        inventory: inventory,
        activeSurvivalEffects: activeSurvivalEffects,
        hunger: 100, // Replenish hunger
        thirst: 100, // Replenish thirst
      );
    });

    return success;
  }

  Future<void> healFullTeam() async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final healedList = u.capturedOrganisms.map((org) {
        // Create a new instance with full health and no status effects
        final healed = org.copyWith(
          currentHealth: org.maxHealth,
          statusEffects: [],
        );
        // Restore all move stamina
        healed.restoreAllStamina();
        return healed;
      }).toList();

      return u.copyWith(capturedOrganisms: healedList);
    });
  }

  Future<void> discoverOrganism(String species) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (u.discoveredOrganisms.contains(species)) return u;

      final discovered = Set<String>.from(u.discoveredOrganisms);
      discovered.add(species);

      return u.copyWith(discoveredOrganisms: discovered.toList());
    });
  }

  Future<void> refreshCurrentUser() async => loadCurrentUser();
  Future<void> loadCurrentUser() async {
    _currentUser = await _authService.getCurrentUser();
    _isInitialized = true;
    if (kDebugMode && _currentUser != null) {
      debugPrint(
        'UserState: loadCurrentUser — captured=${_currentUser!.capturedOrganisms.length}, team=${_currentUser!.battleTeam}',
      );
    }
    notifyListeners();
  }

  Future<void> handleSuccessfulAuth() async {
    _currentUser = await _authService.getCurrentUser();
    if (kDebugMode && _currentUser != null) {
      debugPrint(
        'UserState: handleSuccessfulAuth — captured=${_currentUser!.capturedOrganisms.length}, team=${_currentUser!.battleTeam}',
      );
    }
    notifyListeners();
  }

  Future<void> decreaseStamina(int amount) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.decreaseStamina(amount));
  }

  /// Calculates the stamina cost of taking an action (e.g. moving/exploring) based on weather and temperature
  int calculateExplorationStaminaDrain(String biomeName) {
    if (_currentUser == null) return 1; // Default
    int drain = 1;

    final severity = WeatherService().getEnvironmentalSeverity(biomeName);
    final weather = WeatherService().getCurrentWeather(biomeName);

    // Severity penalty
    if (severity == EnvironmentalSeverity.freezing ||
        severity == EnvironmentalSeverity.scorching) {
      drain += 1; // Was 2
    } else if (severity == EnvironmentalSeverity.cold ||
        severity == EnvironmentalSeverity.hot) {
      // drain += 0; // Removed penalty for mild temperatures
    }

    // Weather multiplier
    drain = (drain * weather.staminaDrainMultiplier).round();

    // Check inventory for passive items
    double passiveReduction = 0.0;
    if (severity == EnvironmentalSeverity.freezing ||
        severity == EnvironmentalSeverity.cold) {
      if ((_currentUser!.inventory['thermal_coat'] ?? 0) > 0) {
        passiveReduction = 0.5;
      }
    } else if (severity == EnvironmentalSeverity.scorching ||
        severity == EnvironmentalSeverity.hot) {
      if ((_currentUser!.inventory['cooling_vest'] ?? 0) > 0) {
        passiveReduction = 0.5;
      }
    }

    // Active effects (drinks)
    for (var effect in _currentUser!.activeSurvivalEffects) {
      if (severity == EnvironmentalSeverity.freezing ||
          severity == EnvironmentalSeverity.cold) {
        if (effect.mitigatesSeverity == EnvironmentalSeverity.freezing) {
          passiveReduction = 1.0; // 100% reduction of extra drain
        }
      }
      if (severity == EnvironmentalSeverity.scorching ||
          severity == EnvironmentalSeverity.hot) {
        if (effect.mitigatesSeverity == EnvironmentalSeverity.scorching) {
          passiveReduction = 1.0;
        }
      }
    }

    // Survival buffs/debuffs
    if (_currentUser!.hunger > 80 && _currentUser!.thirst > 80) {
      passiveReduction += 0.2; // 20% discount if well fed and hydrated
    } else if (_currentUser!.hunger < 20 || _currentUser!.thirst < 20) {
      drain += 2; // Penalty if starving or dehydrated
    }

    // Base cost is 1, only reduce the extra cost, never go below 1
    int extraCost = drain - 1;
    extraCost = (extraCost * (1.0 - passiveReduction)).round();
    return 1 + extraCost;
  }

  Future<bool> consumeItem(String itemId, {int count = 1}) async {
    if (_currentUser == null) return false;
    bool success = false;
    await _readModifyWrite((u) {
      final inv = Map<String, int>.from(u.inventory);
      final current = inv[itemId] ?? 0;
      if (current >= count) {
        if (current == count) {
          inv.remove(itemId);
        } else {
          inv[itemId] = current - count;
        }
        success = true;
        return u.copyWith(inventory: inv);
      }
      return u;
    });
    return success;
  }

  Future<bool> consumeFood(Talisman talisman) async {
    if (_currentUser == null) return false;
    final success = await consumeItem(talisman.id);
    if (!success) return false;

    await _readModifyWrite((u) {
      int newHunger = (u.hunger + talisman.hungerFulfillment).clamp(0, 100);
      int newThirst = (u.thirst + talisman.thirstFulfillment).clamp(0, 100);
      int newStamina = (u.stamina + talisman.staminaBoost).clamp(0, 100);
      return u.copyWith(
        hunger: newHunger,
        thirst: newThirst,
        stamina: newStamina,
      );
    });
    return true;
  }

  Future<void> toggleAnidexUnlocked(bool unlocked) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.copyWith(anidexUnlocked: unlocked));
  }

  Future<void> toggleIgnoreBiomeRequirements(bool ignore) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.copyWith(ignoreBiomeRequirements: ignore));
  }

  Future<void> toggleUnitSystem() async {
    if (_currentUser == null) return;
    final newSystem = _currentUser!.unitSystem == 'metric'
        ? 'imperial'
        : 'metric';
    await _readModifyWrite((u) => u.copyWith(unitSystem: newSystem));
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

  Future<void> saveReplay(BattleReplay replay) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final list = List<Map<String, dynamic>>.from(u.savedReplays);
      // Remove if already exists (shouldn't happen with timestamp IDs, but for safety)
      list.removeWhere((r) => r['id'] == replay.id);
      // Add new replay at the beginning
      list.insert(0, replay.toJson());
      // Keep only the most recent 20
      if (list.length > 20) {
        list.removeLast();
      }
      return u.copyWith(savedReplays: list);
    });
  }

  Future<void> deleteReplay(String id) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final list = List<Map<String, dynamic>>.from(u.savedReplays)
        ..removeWhere((r) => r['id'] == id);
      return u.copyWith(savedReplays: list);
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

    // Redirect cards if they accidentally come through addLoot
    if (BattleCard.findById(lootId) != null) {
      for (int i = 0; i < quantity; i++) {
        await addCardOrFragment(lootId);
      }
      return;
    }

    await _readModifyWrite((u) {
      final newInventory = Map<String, int>.from(u.inventory);
      newInventory[lootId] = (newInventory[lootId] ?? 0) + quantity;
      if (newInventory[lootId]! <= 0) {
        newInventory.remove(lootId);
      }
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

  Future<void> updateBankBalance({int? tk, int? gold, int? diamond}) async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(
        bankTaka: tk != null ? u.bankTaka + tk : u.bankTaka,
        bankGold: gold != null ? u.bankGold + gold : u.bankGold,
        bankDiamond: diamond != null ? u.bankDiamond + diamond : u.bankDiamond,
      ),
    );
  }

  Future<void> setBlackMarketUnlocked(bool unlocked) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) => u.copyWith(isBlackMarketUnlocked: unlocked));
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

  /// Updates the current team's state (HP, Status, Stamina) after a battle.
  Future<void> updateTeamAfterBattle(List<CapturedOrganism> updatedTeam) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final organisms = List<CapturedOrganism>.from(u.capturedOrganisms);
      final teamIndices = u.battleTeam;

      for (int i = 0; i < updatedTeam.length; i++) {
        if (i < teamIndices.length) {
          final originalIndex = teamIndices[i];
          if (originalIndex >= 0 && originalIndex < organisms.length) {
            // Update the organism at that index with the battle results
            organisms[originalIndex] = updatedTeam[i];
          }
        }
      }

      return u.copyWith(capturedOrganisms: organisms);
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

  /// Sets the last visited medical center spawn point.
  Future<void> setLastMedicalCenter(String mapId, int row, int col) async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(
        lastMedicalCenterMapId: mapId,
        lastMedicalCenterRow: row,
        lastMedicalCenterCol: col,
      ),
    );
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

    // Try to pick 3 balanced starters (level 5)
    while (options.length < 3 && options.length < selectionPool.length) {
      final base = selectionPool[random.nextInt(selectionPool.length)];
      if (base.name == 'Human') continue;
      if (options.any((o) => o.baseOrganism.name == base.name)) continue;

      options.add(
        CapturedOrganism.spawn(base, level: 5),
      ); // Starter level set to 5
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
      final nature =
          Nature.allNatures[math.Random().nextInt(Nature.allNatures.length)];
      rewards.add(
        RogueReward(
          type: RogueRewardType.natureMint,
          label: 'MYSTICAL ${nature.name.toUpperCase()} MINT',
          itemId: 'nature_mint_${nature.name.toLowerCase()}',
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
      RogueRewardType.singleStamina: 3, // Added this
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
        case RogueRewardType.singleStamina:
          rewards.add(
            const RogueReward(
              type: RogueRewardType.singleStamina,
              label: 'RESTORE STAMINA',
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
              label: '$count${count == 1 ? ' CAPTURE NET' : ' CAPTURE NETS'}',
              itemId: 'capture_net',
              count: count,
            ),
          );
          break;
        case RogueRewardType.natureMint:
          final nature =
              Nature.allNatures[random.nextInt(Nature.allNatures.length)];
          rewards.add(
            RogueReward(
              type: RogueRewardType.natureMint,
              label: '${nature.name.toUpperCase()} MINT',
              itemId: 'nature_mint_${nature.name.toLowerCase()}',
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
        case RogueRewardType.singleStamina:
          if (team.isNotEmpty) {
            int targetIdx = reward.targetIndex ?? 0;
            if (targetIdx < 0 || targetIdx >= team.length) targetIdx = 0;
            team[targetIdx] = team[targetIdx].copyWith(); // Clone just in case
            team[targetIdx].restoreAllStamina();
          }
          break;
        case RogueRewardType.cureStatus:
          team = team.map((org) {
            final newOrg = org.copyWith();
            newOrg.restoreAllStamina();
            return newOrg;
          }).toList();
          break;
        case RogueRewardType.captureItems:
          inventory['capture_net'] =
              (inventory['capture_net'] ?? 0) + (reward.count ?? 1);
          break;
        case RogueRewardType.natureMint:
          if (reward.itemId != null) {
            inventory[reward.itemId!] = (inventory[reward.itemId!] ?? 0) + 1;
          }
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
        .where((e) => e.isNotEmpty)
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
        'Redwoods',
        'Wetlands',
        'Plains',
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
          indexB >= team.length) {
        return u;
      }

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
      final specificMintId = 'nature_mint_${newNature.name.toLowerCase()}';
      const genericMintId = 'nature_mint';

      if ((inventory[specificMintId] ?? 0) > 0) {
        inventory[specificMintId] = inventory[specificMintId]! - 1;
        if (inventory[specificMintId] == 0) inventory.remove(specificMintId);
      } else if ((inventory[genericMintId] ?? 0) > 0) {
        inventory[genericMintId] = inventory[genericMintId]! - 1;
        if (inventory[genericMintId] == 0) inventory.remove(genericMintId);
      } else {
        return u; // No mint available
      }

      team[index] = team[index].copyWith(nature: newNature);
      return u.copyWith(
        rogueLikeState: state.copyWith(team: team, inventory: inventory),
      );
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
        .where((e) => e.isNotEmpty)
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
        'Redwoods',
        'Wetlands',
        'Plains',
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
  }) async {
    if (_currentUser == null) return {};

    // Initial level cap is 7. Can be increased later.
    int effectiveCap = 7;

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
            final xpResult = org.gainXP(share, levelCap: effectiveCap);
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
          final xpResult = org.gainXP(0, levelCap: effectiveCap);
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
              // Roguelike team: remove all level caps

              final xpResult = org.gainXP(share);
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

  /// Toggles the Sickle tool state (on/off).
  Future<void> toggleSickle() async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(eventFlags: u.eventFlags.toggleSickle()),
    );
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

  /// Records wins/losses and combat stats for animals that participated in a battle.
  /// [playerSpeciesStats] and [opponentSpeciesStats] map species name to
  /// {damageDealt, damageTaken, kills} for animals that actually participated.
  Future<void> recordMatchResults({
    // New rich format
    Map<String, Map<String, int>>? playerSpeciesStats,
    Map<String, Map<String, int>>? opponentSpeciesStats,
    // Legacy flat format (kept for backwards compatibility)
    List<String>? playerSpecies,
    List<String>? opponentSpecies,
    required bool playerWon,
  }) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final newStats = Map<String, Map<String, int>>.from(
        u.speciesStats.map((k, v) => MapEntry(k, Map<String, int>.from(v))),
      );

      // Build participation maps from either format
      final Map<String, Map<String, int>> pStats =
          playerSpeciesStats ?? {for (final s in (playerSpecies ?? [])) s: {}};
      final Map<String, Map<String, int>> oStats =
          opponentSpeciesStats ??
          {for (final s in (opponentSpecies ?? [])) s: {}};

      void update(String species, bool won, Map<String, int> combatData) {
        final existing =
            newStats[species] ??
            {
              'matches': 0,
              'wins': 0,
              'captured': 0,
              'damageDealt': 0,
              'damageTaken': 0,
              'kills': 0,
            };
        newStats[species] = {
          'matches': (existing['matches'] ?? 0) + 1,
          'wins': (existing['wins'] ?? 0) + (won ? 1 : 0),
          'captured': existing['captured'] ?? 0,
          'damageDealt':
              (existing['damageDealt'] ?? 0) + (combatData['damageDealt'] ?? 0),
          'damageTaken':
              (existing['damageTaken'] ?? 0) + (combatData['damageTaken'] ?? 0),
          'kills': (existing['kills'] ?? 0) + (combatData['kills'] ?? 0),
        };
      }

      for (final entry in pStats.entries) {
        update(entry.key, playerWon, entry.value);
      }
      for (final entry in oStats.entries) {
        update(entry.key, !playerWon, entry.value);
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

  Future<void> _processPlantGrowth() async {
    if (_currentUser == null) return;

    bool needsUpdate = false;
    final now = DateTime.now();
    final updatedSlots = List<FarmSlot>.from(_currentUser!.farmSlots);

    for (int i = 0; i < updatedSlots.length; i++) {
      final slot = updatedSlots[i];
      if (slot.stage == PlantStage.empty || slot.stage == PlantStage.fruit) {
        continue;
      }

      if (slot.lastStageTime != null) {
        final elapsed = now.difference(slot.lastStageTime!);
        // Base time: 60 seconds
        int requiredSeconds = 60;
        if (slot.isWatered) requiredSeconds -= 20;
        if (slot.isFertilized) requiredSeconds -= 20;

        if (elapsed.inSeconds >= requiredSeconds) {
          needsUpdate = true;
          PlantStage nextStage = PlantStage.values[slot.stage.index + 1];
          updatedSlots[i] = slot.copyWith(
            stage: nextStage,
            lastStageTime: now,
            isWatered: false,
            isFertilized: false,
          );
        }
      }
    }

    if (needsUpdate) {
      await _readModifyWrite((u) => u.copyWith(farmSlots: updatedSlots));
    }
  }

  Future<bool> plantSeed(int index, String seedId) async {
    if (_currentUser == null) return false;
    if ((_currentUser!.inventory[seedId] ?? 0) <= 0) return false;

    bool success = false;
    await _readModifyWrite((u) {
      if (index < 0 || index >= u.farmSlots.length) return u;
      if (u.farmSlots[index].stage != PlantStage.empty) return u;

      final inventory = Map<String, int>.from(u.inventory);
      inventory[seedId] = (inventory[seedId] ?? 1) - 1;
      if (inventory[seedId]! <= 0) inventory.remove(seedId);

      final slots = List<FarmSlot>.from(u.farmSlots);
      slots[index] = slots[index].copyWith(
        plantType: seedId.replaceAll('_seed', ''), // e.g., 'strawberry'
        stage: PlantStage.seed,
        lastStageTime: DateTime.now(),
        isWatered: false,
        isFertilized: false,
        clearPlantType: false,
      );

      success = true;
      return u.copyWith(inventory: inventory, farmSlots: slots);
    });
    return success;
  }

  Future<bool> waterPlant(int index) async {
    if (_currentUser == null) return false;
    if ((_currentUser!.inventory['spray_bottle'] ?? 0) <= 0) return false;

    bool success = false;
    await _readModifyWrite((u) {
      if (index < 0 || index >= u.farmSlots.length) return u;
      final slot = u.farmSlots[index];
      if (slot.stage == PlantStage.empty ||
          slot.stage == PlantStage.fruit ||
          slot.isWatered) {
        return u;
      }

      final slots = List<FarmSlot>.from(u.farmSlots);
      slots[index] = slot.copyWith(isWatered: true);
      success = true;
      return u.copyWith(farmSlots: slots);
    });
    return success;
  }

  Future<bool> fertilizePlant(int index) async {
    if (_currentUser == null) return false;
    if ((_currentUser!.inventory['organic_fertilizer'] ?? 0) <= 0) return false;

    bool success = false;
    await _readModifyWrite((u) {
      if (index < 0 || index >= u.farmSlots.length) return u;
      final slot = u.farmSlots[index];
      if (slot.stage == PlantStage.empty ||
          slot.stage == PlantStage.fruit ||
          slot.isFertilized) {
        return u;
      }

      final inventory = Map<String, int>.from(u.inventory);
      inventory['organic_fertilizer'] =
          (inventory['organic_fertilizer'] ?? 1) - 1;
      if (inventory['organic_fertilizer']! <= 0) {
        inventory.remove('organic_fertilizer');
      }

      final slots = List<FarmSlot>.from(u.farmSlots);
      slots[index] = slot.copyWith(isFertilized: true);
      success = true;
      return u.copyWith(inventory: inventory, farmSlots: slots);
    });
    return success;
  }

  Future<int> harvestPlant(int index) async {
    if (_currentUser == null) return 0;

    int yieldCount = 0;
    await _readModifyWrite((u) {
      if (index < 0 || index >= u.farmSlots.length) return u;
      final slot = u.farmSlots[index];
      if (slot.stage != PlantStage.fruit) return u;

      final inventory = Map<String, int>.from(u.inventory);

      // Get the name for the fruit: capitalized plantType (e.g., "Strawberry")
      final String plantType = slot.plantType ?? 'strawberry';
      final String fruitName =
          plantType[0].toUpperCase() + plantType.substring(1).toLowerCase();

      // Get yield config from farming.json
      final plantConfig = _farmingConfig['plants']?[plantType];
      final int minYield = plantConfig?['min_yield'] ?? 4;
      final int maxYield = plantConfig?['max_yield'] ?? 7;
      final int fertYield = plantConfig?['fertilized_yield'] ?? 7;

      yieldCount = slot.isFertilized
          ? fertYield
          : (minYield + math.Random().nextInt(maxYield - minYield + 1));
      inventory[fruitName] = (inventory[fruitName] ?? 0) + yieldCount;

      final slots = List<FarmSlot>.from(u.farmSlots);
      slots[index] = FarmSlot.empty(index);

      return u.copyWith(inventory: inventory, farmSlots: slots);
    });
    return yieldCount;
  }

  Future<bool> pickSeeds(String fruitId, [int count = 1]) async {
    if (_currentUser == null || count <= 0) return false;
    final config = _farmingConfig['seed_picking']?[fruitId.toLowerCase()];
    if (config == null) return false;

    final toolRequired = config['tool_required'];
    final resultSeed = config['result_seed'];
    final int minYield = config['min_yield'] ?? 1;
    final int maxYield = config['max_yield'] ?? 1;

    if ((_currentUser!.inventory[toolRequired] ?? 0) <= 0) return false;
    if ((_currentUser!.inventory[fruitId] ?? 0) < count) return false;

    bool success = false;
    await _readModifyWrite((u) {
      final inventory = Map<String, int>.from(u.inventory);

      // Consume fruits
      inventory[fruitId] = (inventory[fruitId] ?? count) - count;
      if (inventory[fruitId]! <= 0) inventory.remove(fruitId);

      // Grant seeds
      int totalSeeds = 0;
      final rand = math.Random();
      for (int i = 0; i < count; i++) {
        totalSeeds += minYield + rand.nextInt(maxYield - minYield + 1);
      }
      inventory[resultSeed] = (inventory[resultSeed] ?? 0) + totalSeeds;

      success = true;
      return u.copyWith(inventory: inventory);
    });
    return success;
  }

  SavedMapState? getMapState(String mapId) {
    return _currentUser?.savedMapStates[mapId];
  }

  Future<void> saveMapState(String mapId, SavedMapState state) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final newMapStates = Map<String, SavedMapState>.from(u.savedMapStates);
      newMapStates[mapId] = state;
      return u.copyWith(savedMapStates: newMapStates);
    });
  }

  Future<void> clearMapState(String mapId) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      final newMapStates = Map<String, SavedMapState>.from(u.savedMapStates);
      newMapStates.remove(mapId);
      return u.copyWith(savedMapStates: newMapStates);
    });
  }

  // ── Event Flags ──

  EventFlags get eventFlags => _currentUser?.eventFlags ?? const EventFlags();

  bool hasFlag(String flag) => eventFlags.hasFlag(flag);
  bool isTrainerDefeated(String npcId) => eventFlags.isTrainerDefeated(npcId);

  Future<void> setFlag(String flag) async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(eventFlags: u.eventFlags.withFlag(flag)),
    );
  }

  Future<void> markTrainerDefeated(String npcId) async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(eventFlags: u.eventFlags.withTrainerDefeated(npcId)),
    );
  }

  Future<void> markQuestCompleted(String questId) async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(eventFlags: u.eventFlags.withQuestCompleted(questId)),
    );
  }

  Future<void> markItemCollected(String itemId) async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(eventFlags: u.eventFlags.withItemCollected(itemId)),
    );
  }

  Future<void> updateCurrentMapId(String mapId) async {
    if (_currentUser == null) return;
    await _readModifyWrite(
      (u) => u.copyWith(eventFlags: u.eventFlags.copyWith(currentMapId: mapId)),
    );
  }

  Future<void> updateTileCooldown(String mapId, int row, int col) async {
    if (_currentUser == null) return;
    final key = '$mapId:$row:$col';
    await _readModifyWrite(
      (u) => u.copyWith(eventFlags: u.eventFlags.withTileCooldown(key)),
    );
  }

  bool isTileOnCooldown(String mapId, int row, int col) {
    if (_currentUser == null) return false;
    final key = '$mapId:$row:$col';
    return _currentUser!.eventFlags.isTileOnCooldown(key);
  }

  Future<void> cutGrass(String mapId, int row, int col) async {
    if (_currentUser == null) return;
    final key = '$mapId:$row:$col';
    final now = TimeService().currentInGameDateTime.millisecondsSinceEpoch;
    await _readModifyWrite(
      (u) => u.copyWith(eventFlags: u.eventFlags.withCutGrass(key, now)),
    );
  }

  Future<void> clearExpiredGrass() async {
    if (_currentUser == null) return;
    final now = TimeService().currentInGameDateTime.millisecondsSinceEpoch;
    await _readModifyWrite((u) {
      final newCutTiles = Map<String, int>.from(u.eventFlags.cutGrassTiles);
      final initialCount = newCutTiles.length;
      newCutTiles.removeWhere((key, timestamp) {
        // Regrow after 24 in-game hours (86,400,000 ms)
        return now - timestamp > 86400000;
      });
      if (newCutTiles.length == initialCount) return u;
      return u.copyWith(
        eventFlags: u.eventFlags.copyWith(cutGrassTiles: newCutTiles),
      );
    });
  }

  Future<void> addCardOrFragment(String cardId) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      if (u.unlockedCards.contains(cardId)) {
        // Add a card fragment if duplicate
        return u.copyWith(cardFragments: u.cardFragments + 1);
      } else {
        // Unlock new card
        final newCards = List<String>.from(u.unlockedCards)..add(cardId);
        return u.copyWith(unlockedCards: newCards);
      }
    });
  }

  Future<bool> buyCardWithFragments(String cardId, int cost) async {
    if (_currentUser == null) return false;
    bool success = false;
    await _readModifyWrite((u) {
      if (u.cardFragments >= cost && !u.unlockedCards.contains(cardId)) {
        final newCards = List<String>.from(u.unlockedCards)..add(cardId);
        success = true;
        return u.copyWith(
          unlockedCards: newCards,
          cardFragments: u.cardFragments - cost,
        );
      }
      return u;
    });
    return success;
  }

  Future<void> equipCard(String? cardId) async {
    if (_currentUser == null) return;
    await _readModifyWrite((u) {
      return u.copyWith(equippedCard: cardId);
    });
  }

  bool _unstuckRequested = false;
  bool get unstuckRequested => _unstuckRequested;

  void requestUnstuck() {
    _unstuckRequested = true;
    notifyListeners();
  }

  void consumeUnstuckRequest() {
    _unstuckRequested = false;
  }

  @override
  void dispose() {
    _staminaRegenTimer?.cancel();
    super.dispose();
  }
}
