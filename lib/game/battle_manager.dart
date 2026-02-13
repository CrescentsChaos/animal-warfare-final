// lib/game/battle_manager.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/move.dart';

import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/game/biome_weather.dart';

// --- Enums ---
enum BattleState {
  intro, // New state for initialization sequence
  waitingForInput, // Player must select Move, Capture, or Run
  playerTurn,
  opponentTurn,
  applyingEffects,
  battleEnd,
  waitingForPlayerSwitch, // User must select a new animal after fainting
}

enum BattleResult {
  win,
  loss,
  capture, // Successful capture
  fled, // Successful run
}

// --- BattleOrganism: Holds state for battle ---
class BattleOrganism {
  final CapturedOrganism organism;
  final List<Ability> abilities;
  int _health;
  int get health => _health;
  set health(int value) {
    _health = value;
    organism.currentHealth = value;
  }

  // Dynamic battle stats
  int attackStage = 0; // -6 to +6 stages
  int defenseStage = 0;
  int powerStage = 0; // NEW
  int resistanceStage = 0; // NEW
  int speedStage = 0; // Added speed stage

  List<StatusEffect> _statusEffects = [];
  List<StatusEffect> get statusEffects => _statusEffects;
  set statusEffects(List<StatusEffect> value) {
    _statusEffects = value;
    organism.statusEffects = value;
  }

  // Compatibility getter/setter for single status check
  StatusEffect get statusEffect {
    if (_statusEffects.isEmpty)
      return const StatusEffect(type: StatusEffectType.none);
    return _statusEffects.last;
  }

  set statusEffect(StatusEffect value) {
    if (value.type == StatusEffectType.none) {
      _statusEffects = [];
    } else {
      _statusEffects = [value];
    }
    organism.statusEffects = _statusEffects;
  }

  void addStatusEffect(StatusEffect effect) {
    // Prevent duplicate status effects of the same type
    if (_statusEffects.any((se) => se.type == effect.type)) {
      return;
    }
    _statusEffects.add(effect);
    organism.statusEffects = _statusEffects;
  }

  void clearStatusEffects() {
    _statusEffects.clear();
    organism.statusEffects = _statusEffects;
  }

  // New flags for complex moves
  bool isInvulnerable = false;
  bool isProtected = false;
  bool rechargeTurn = false; // For Hyper Beam etc
  Move? chargeMove; // For Solar Beam etc
  String? chargeStatChanges; // Stat changes to apply after charge
  Move? chargingMove; // The move currently being charged
  bool mustRecharge = false;
  int protectSuccessionCount = 0;
  bool tookDamageThisTurn = false;
  String? semiInvulnerable; // e.g., 'underground'

  final bool isRogueMode;
  final int level;

  BattleOrganism(this.organism, {this.isRogueMode = false})
    : level = isRogueMode ? organism.level : 50,
      _health =
          (isRogueMode
                  ? organism.currentHealth
                  : organism.getMaxHealth(atLevel: 50))
              .clamp(
                0,
                (isRogueMode
                    ? organism.maxHealth
                    : organism.getMaxHealth(atLevel: 50)),
              ),
      _statusEffects = List.from(organism.statusEffects),
      abilities = organism.baseOrganism.abilities
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((name) => Ability.findByName(name))
          .where((a) => a != null)
          .cast<Ability>()
          .toList();

  List<ElementalType>? _battleTypes;
  List<ElementalType> get types =>
      _battleTypes ?? organism.baseOrganism.elementalTypes;
  set battleTypes(List<ElementalType> value) => _battleTypes = value;

  // Helper for stat stage multipliers (e.g., +1 stage is 1.5x)
  static double _getStatStageMultiplier(int stage) {
    if (stage > 0) return (2 + stage) / 2;
    if (stage < 0) return 2 / (2 + stage.abs());
    return 1.0;
  }

  double _getAbilityStatMultiplier(String statName) {
    double totalMultiplier = 1.0;

    for (final ability in abilities) {
      if (ability.trigger != AbilityTrigger.onCalculateStat ||
          ability.targetStat != statName) {
        continue;
      }

      // Check conditions
      bool conditionMet = true;
      for (final condition in ability.conditions) {
        if (condition == 'statused' &&
            statusEffect.type == StatusEffectType.none)
          conditionMet = false;
        if (condition == 'hp_below_30' && health / maxHealth > 0.3)
          conditionMet = false;
        if (condition == 'weather_sandstorm' &&
            !(BattleManager.currentWeatherGlobal?.weather == Weather.sandstorm))
          conditionMet = false;
        if (condition == 'weather_sun' &&
            !(BattleManager.currentWeatherGlobal?.weather == Weather.heatwave))
          conditionMet = false;
        if (condition == 'weather_rain' &&
            !(BattleManager.currentWeatherGlobal?.weather == Weather.rain))
          conditionMet = false;
        if (condition == 'weather_snow' &&
            !(BattleManager.currentWeatherGlobal?.weather == Weather.snow ||
                BattleManager.currentWeatherGlobal?.weather ==
                    Weather.blizzard))
          conditionMet = false;
      }

      if (conditionMet) {
        totalMultiplier *= ability.magnitude;
      }
    }

    return totalMultiplier;
  }

  int get currentAttack {
    double attack =
        (isRogueMode
                ? organism.effectiveAttack
                : organism.getAttack(atLevel: 50))
            .toDouble();
    attack *= _getStatStageMultiplier(attackStage);
    attack *= _getAbilityStatMultiplier('attack');

    // Apply multiple status modifiers
    for (final se in statusEffects) {
      if (se.type == StatusEffectType.burn) {
        attack *= 0.5;
      }
      if (se.type == StatusEffectType.fear) {
        attack *= 0.9;
      }
    }

    // Talisman boost
    if (organism.equippedTalisman?.effect.type ==
        TalismanEffectType.attackBoost) {
      attack *= organism.equippedTalisman!.effect.magnitude;
    }

    return attack.round();
  }

  int get currentDefense {
    int baseDefense = isRogueMode
        ? organism.effectiveDefense
        : organism.getDefense(atLevel: 50);
    double defense = (baseDefense * _getStatStageMultiplier(defenseStage))
        .toDouble();
    defense *= _getAbilityStatMultiplier('defense');

    // Apply multiple status modifiers
    for (final se in statusEffects) {
      if (se.type == StatusEffectType.fear) {
        defense *= 0.9;
      }
    }

    // Talisman boost
    if (organism.equippedTalisman?.effect.type ==
        TalismanEffectType.defenseBoost) {
      defense *= organism.equippedTalisman!.effect.magnitude;
    }

    return defense.round();
  }

  int get currentPower {
    double power =
        (isRogueMode ? organism.effectivePower : organism.getPower(atLevel: 50))
            .toDouble();
    power *= _getStatStageMultiplier(powerStage);
    power *= _getAbilityStatMultiplier('power');

    // Apply multiple status modifiers
    for (final se in statusEffects) {
      if (se.type == StatusEffectType.fear) {
        power *= 0.9;
      }
    }

    return power.round();
  }

  int get currentResistance {
    int baseRes = isRogueMode
        ? organism.effectiveResistance
        : organism.getResistance(atLevel: 50);
    double resistance = (baseRes * _getStatStageMultiplier(resistanceStage))
        .toDouble();
    resistance *= _getAbilityStatMultiplier('resistance');

    // Apply multiple status modifiers
    for (final se in statusEffects) {
      if (se.type == StatusEffectType.fear) {
        resistance *= 0.9;
      }
    }

    // Talisman boost
    if (organism.equippedTalisman?.effect.type ==
        TalismanEffectType.resistanceStatBoost) {
      resistance *= organism.equippedTalisman!.effect.magnitude;
    }

    return resistance.round();
  }

  int get currentSpeed {
    double speed =
        (isRogueMode ? organism.effectiveSpeed : organism.getSpeed(atLevel: 50))
            .toDouble();
    speed *= _getAbilityStatMultiplier('speed');

    // Paralysis is now checked in the loop below

    // Talisman boost
    if (organism.equippedTalisman?.effect.type ==
        TalismanEffectType.speedBoost) {
      speed *= organism.equippedTalisman!.effect.magnitude;
    }

    speed *= _getStatStageMultiplier(speedStage);

    // Apply multiple status modifiers
    for (final se in statusEffects) {
      if (se.type == StatusEffectType.fear) {
        speed *= 0.9;
      }
      if (se.type == StatusEffectType.paralysis) {
        speed *= 0.25;
      }
    }

    return speed.round();
  }

  /// Use the captured organism's calculated max HP (IVs included), not base stat.
  int get maxHealth {
    int baseMax = isRogueMode
        ? organism.maxHealth
        : organism.getMaxHealth(atLevel: 50);
    double hp = baseMax.toDouble();

    // Talisman boost
    if (organism.equippedTalisman?.effect.type ==
        TalismanEffectType.healthBoost) {
      hp *= organism.equippedTalisman!.effect.magnitude;
    }

    return hp.round();
  }
}

// --- Battle Turn Data ---
class BattleTurn {
  final int turnNumber;
  final List<String> logEntries = [];

  BattleTurn(this.turnNumber);
}

class AbilityNotification {
  final String animalName;
  final String abilityName;
  final bool isPlayer;

  AbilityNotification({
    required this.animalName,
    required this.abilityName,
    required this.isPlayer,
  });
}

// --- BattleManager: The Core State Machine ---
class BattleManager extends ChangeNotifier {
  final List<CapturedOrganism> playerTeam;
  int currentPlayerIndex = 0;
  final CapturedOrganism opponentOrganism;

  CapturedOrganism get playerOrganism => playerTeam[currentPlayerIndex];

  late BattleOrganism player;
  late BattleOrganism opponent;

  late List<Move> playerMoves;
  late List<Move> opponentMoves;

  // New Battle State
  WeatherEffect currentWeather = const WeatherEffect(weather: Weather.none);
  TerrainEffect currentTerrain = const TerrainEffect(terrain: Terrain.none);

  static WeatherEffect? currentWeatherGlobal;
  static TerrainEffect? currentTerrainGlobal;
  int weatherTurnsLeft = 0;
  int terrainTurnsLeft = 0;

  BattleState currentState = BattleState.intro;
  String battleLog = ''; // Current/Latest message
  AbilityNotification? currentAbilityNotify;

  // LOGGING REFACTOR
  int currentTurn = 1;
  final List<BattleTurn> turnHistory = [];
  BattleResult? _result;
  BattleResult? get result => _result;

  // LOOT DROP
  String? _droppedLoot;
  String? get droppedLoot => _droppedLoot;
  final bool isArenaBattle;
  final bool isRogueMode;
  List<CapturedOrganism> opponentTeam = [];
  int currentOpponentIndex = 0;
  bool opponentJustSwitched = false;
  bool playerJustSwitched = false;

  bool playerMovedThisTurn = false;
  bool opponentMovedThisTurn = false;
  bool isResumingTurn = false;
  Move? pendingPlayerMove;
  Move? currentTurnOpponentMove;

  // Callbacks for UI
  Function(BattleOrganism)? onAttack;
  VoidCallback? onVictory;

  void _addToLog(String message) {
    battleLog = message;
    if (turnHistory.isEmpty) {
      turnHistory.add(BattleTurn(currentTurn));
    }
    turnHistory.last.logEntries.add(message);
  }

  void _appendToLog(String message) {
    battleLog += message;
    if (turnHistory.isNotEmpty && turnHistory.last.logEntries.isNotEmpty) {
      // Append to the last entry instead of creating a new one?
      // The original logic seemed to treat _appendToLog as adding to the 'current line' in a sense,
      // but for the list it just added a new entry.
      // Let's keep it simple and add as a new line for clarity in the list.
      // to allow easier reading, OR append to the last string.
      // Given "battleLog += message", let's update the last entry if meaningful,
      // otherwise just add it.
      // User request: "turn number and things happened in order".
      // Let's just add it as a new line for clarity in the list.
      turnHistory.last.logEntries.add(message.trim());
    } else {
      if (turnHistory.isEmpty) turnHistory.add(BattleTurn(currentTurn));
      turnHistory.last.logEntries.add(message.trim());
    }
  }

  /// Builds the move list for an organism from its moveset string. Uses predefined
  /// moves when available; otherwise creates moves with random damage (placeholder).
  List<Move> _getOrganismMoves(CapturedOrganism organism) {
    final List<Move> moves = [];

    // For wild animals, use their current move selection
    // (If they don't have one, initialize it now)
    if (organism.selectedMoveNames.isEmpty) {
      organism.initializeDefaultMoves();
    }

    for (final name in organism.selectedMoveNames) {
      moves.add(Move.findOrCreate(name));
    }

    if (moves.isEmpty) {
      moves.add(Move.findOrCreate('Struggle'));
    }
    return moves;
  }

  BattleManager(
    CapturedOrganism initialPlayer,
    this.opponentOrganism, {
    String? biomeName,
    List<CapturedOrganism>? team,
    List<CapturedOrganism>? opponentTeam,
    this.isArenaBattle = false,
    this.isRogueMode = false,
  }) : playerTeam = (team?.isNotEmpty ?? false) ? team! : [initialPlayer],
       opponentTeam = (opponentTeam?.isNotEmpty ?? false)
           ? opponentTeam!
           : [opponentOrganism] {
    // Find initial player index if it's in the team
    int idx = playerTeam.indexOf(initialPlayer);
    currentPlayerIndex = idx != -1 ? idx : 0;

    // Set up opponent index
    int oppIdx = this.opponentTeam.indexOf(opponentOrganism);
    currentOpponentIndex = oppIdx != -1 ? oppIdx : 0;

    player = BattleOrganism(playerOrganism, isRogueMode: isRogueMode);
    opponent = BattleOrganism(this.opponentOrganism, isRogueMode: isRogueMode);

    // Initialize move lists
    playerMoves = _getOrganismMoves(playerOrganism);
    opponentMoves = _getOrganismMoves(opponentOrganism);

    // If Rogue-like mode, trust the opponent's current health/stamina/status
    // Otherwise, for wild battles/arena, reset them to full?
    // Actually, capturing generic wild animals usually spawns a fresh one.
    // But for Rogue-like, we pass the specific instance from UserState.
    // So we should respect its current state.
    if (isRogueMode) {
      opponent.health = opponentOrganism.currentHealth;
      if (opponentOrganism.statusEffects.isNotEmpty) {
        opponent.statusEffects = List.from(opponentOrganism.statusEffects);
      } else {
        opponent.clearStatusEffects();
      }
      // Ensure stamina is also synced if we track it on opponent (we don't effectively yet for AI)
    } else {
      // Standard wild/arena: ensure full health start
      // (Though usually spawn() creates them full health anyway)
      opponent.health = opponent.maxHealth;
    }

    // Initialize first turn
    turnHistory.add(BattleTurn(currentTurn));

    currentWeatherGlobal = currentWeather;
    currentTerrainGlobal = currentTerrain;

    // Start initialization sequence asynchronously
    _initializeSequence(biomeName);
  }

  Future<void> _initializeSequence(String? biomeName) async {
    _addToLog(
      'A wild ${opponent.organism.name} appeared! Go, ${player.organism.name}!',
    );
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 3000));

    await _initializeBattle(biomeName);

    // Transition to waiting for input
    currentState = BattleState.waitingForInput;
    _addToLog('What will ${player.organism.name} do?');
    notifyListeners();
  }

  Future<void> _initializeBattle(String? biomeName) async {
    // 0. Apply biome weather/terrain if no ability overrides
    if (biomeName != null && biomeName.isNotEmpty) {
      final biomeWeather = BiomeWeatherTable.getRandomWeatherForBiome(
        biomeName,
      );
      if (biomeWeather != Weather.none && biomeWeather != Weather.clear) {
        _setWeather(biomeWeather, 99); // Long duration for biome weather
      }

      final biomeTerrain = BiomeWeatherTable.getDefaultTerrainForBiome(
        biomeName,
      );
      if (biomeTerrain != Terrain.none) {
        _setTerrain(biomeTerrain, 99);
      }
    }

    // 1. Check for Auto-Weather/Terrain/Intimidate (abilities can override)
    await _checkEntranceAbility(player, opponent);
    await _checkEntranceAbility(opponent, player);

    // 2. Speed Check
    if (player.currentSpeed < opponent.currentSpeed) {
      _appendToLog(
        '\n${opponent.organism.name} is faster and will attack first!',
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
    }
  }

  Future<void> _checkEntranceAbility(
    BattleOrganism user,
    BattleOrganism target,
  ) async {
    for (final ability in user.abilities) {
      if (ability.trigger != AbilityTrigger.onEntry) continue;

      bool triggered = false;
      switch (ability.effectType) {
        case AbilityEffectType.weatherChange:
          triggered = true;
          await _notifyAbilityTrigger(user, ability);
          if (ability.value == 'rain')
            _setWeather(Weather.rain);
          else if (ability.value == 'sun')
            _setWeather(Weather.heatwave);
          else if (ability.value == 'hail')
            _setWeather(Weather.blizzard);
          else if (ability.value == 'sandstorm')
            _setWeather(Weather.sandstorm);
          break;
        case AbilityEffectType.terrainChange:
          triggered = true;
          await _notifyAbilityTrigger(user, ability);
          if (ability.value == 'electric')
            _setTerrain(Terrain.electric);
          else if (ability.value == 'grassy')
            _setTerrain(Terrain.grassy);
          else if (ability.value == 'misty')
            _setTerrain(Terrain.misty);
          else if (ability.value == 'psychic')
            _setTerrain(Terrain.psychic);
          break;
        case AbilityEffectType.statChange:
          triggered = true;
          await _notifyAbilityTrigger(user, ability);
          await _applyStatChange(
            ability.targetStat == 'attack' ? target : user,
            ability.targetStat,
            ability.magnitude.toInt(),
          );
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 3000));
          break;
        default:
          if (ability.name == 'Cold-blooded') {
            final w = currentWeatherGlobal?.weather ?? Weather.none;
            int stageChange = 0;

            if (w == Weather.heatwave) {
              stageChange = 1;
            } else if (w == Weather.rain ||
                w == Weather.heavyRain ||
                w == Weather.snow ||
                w == Weather.blizzard ||
                w == Weather.thunderstorm) {
              stageChange = -1;
            }

            if (stageChange != 0) {
              triggered = true;
              await _notifyAbilityTrigger(user, ability);
              await _applyStatChange(user, 'speed', stageChange);
              notifyListeners();
              await Future.delayed(const Duration(milliseconds: 3000));
            }
          }
          break;
      }
    }
  }

  Future<void> _notifyAbilityTrigger(
    BattleOrganism user,
    Ability ability,
  ) async {
    final isPlayer = user == player;
    currentAbilityNotify = AbilityNotification(
      animalName: user.organism.baseOrganism.name,
      abilityName: ability.name,
      isPlayer: isPlayer,
    );

    _addToLog("${user.organism.baseOrganism.name}'s ${ability.name}!");
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 3000));

    currentAbilityNotify = null;
    notifyListeners();
  }

  void _setWeather(Weather w, [int duration = 5]) {
    if (currentWeather.weather == w) return;
    currentWeather = WeatherEffect(weather: w, duration: duration);
    currentWeatherGlobal = currentWeather;
    weatherTurnsLeft = duration;
    _appendToLog('\n${currentWeather.description}');
  }

  void _setTerrain(Terrain t, [int duration = 5]) {
    if (currentTerrain.terrain == t) return;
    currentTerrain = TerrainEffect(terrain: t, duration: duration);
    currentTerrainGlobal = currentTerrain;
    terrainTurnsLeft = duration;
    _appendToLog('\n${currentTerrain.description}');
  }

  String _getWeatherPersistenceMessage(Weather w) {
    switch (w) {
      case Weather.rain:
        return 'Rain continues to fall.';
      case Weather.heavyRain:
        return 'The downpour persists!';
      case Weather.snow:
        return 'Snow keeps falling.';
      case Weather.blizzard:
        return 'The blizzard rages on!';
      case Weather.fog:
        return 'The fog lingers.';
      case Weather.heatwave:
        return 'The heat is intense!';
      case Weather.sandstorm:
        return 'The sandstorm continues.';
      case Weather.windstorm:
        return 'Strong winds persist.';
      case Weather.thunderstorm:
        return 'The storm rumbles on!';
      default:
        return '';
    }
  }

  // --- Turn Logic ---

  Future<void> processPlayerAction(Move move) async {
    if (currentState != BattleState.waitingForInput) return;

    // Check Stamina
    final currentStamina = playerOrganism.moveStamina[move.name] ?? 0;
    if (currentStamina <= 0) {
      _addToLog('${move.name} has no stamina left!');
      notifyListeners();
      return;
    }

    currentState = BattleState.playerTurn;
    notifyListeners();

    // 1. Determine priority and order (only if not resuming mid-turn)
    bool playerGoesFirst = true;

    if (!isResumingTurn) {
      // Pre-calculate opponent move for priority check
      currentTurnOpponentMove =
          opponentMoves[Random().nextInt(opponentMoves.length)];

      // Determine who goes first
      int playerPriority = move.priority;
      int opponentPriority = currentTurnOpponentMove!.priority;

      // Gale Wings check
      for (final ab in player.abilities) {
        if (ab.name == 'Gale Wings' &&
            player.health == player.maxHealth &&
            move.type == ElementalType.flying) {
          playerPriority += ab.magnitude.toInt();
        }
      }
      for (final ab in opponent.abilities) {
        if (ab.name == 'Gale Wings' &&
            opponent.health == opponent.maxHealth &&
            currentTurnOpponentMove!.type == ElementalType.flying) {
          opponentPriority += ab.magnitude.toInt();
        }
      }

      if (playerPriority > opponentPriority) {
        playerGoesFirst = true;
      } else if (opponentPriority > playerPriority) {
        playerGoesFirst = false;
      } else {
        // Speed Check (same priority)
        if (player.currentSpeed >= opponent.currentSpeed) {
          playerGoesFirst = true;
        } else {
          playerGoesFirst = false;
        }
      }

      // Reset flags for a new complete turn cycle
      playerMovedThisTurn = false;
      opponentMovedThisTurn = false;
      player.tookDamageThisTurn = false;
      opponent.tookDamageThisTurn = false;
      opponentJustSwitched = false;
      playerJustSwitched = false;
    } else {
      // If resuming, we need to know who was supposed to go first originally,
      // or simply rely on the moved flags.
      // Actually, if we are resuming, it means one side already moved (or fainted).
      // We can just follow the "player first" or "opponent first" logic but skip if already moved.
      // To be safe, we'll re-calculate who goes first based on current stats,
      // but the 'moved' flags will ensure they don't double-move.

      // We need to know who should go first among those who HAVEN'T moved.
      if (opponentMovedThisTurn && !playerMovedThisTurn) {
        playerGoesFirst = true; // Only player left
      } else if (playerMovedThisTurn && !opponentMovedThisTurn) {
        playerGoesFirst = false; // Only opponent left
      } else {
        // This shouldn't happen if isResumingTurn is true, but fallback:
        playerGoesFirst = player.currentSpeed >= opponent.currentSpeed;
      }
    }

    // 2. Execute turns
    if (playerGoesFirst) {
      // Player Turn
      if (!playerMovedThisTurn && (!playerJustSwitched || isResumingTurn)) {
        if (await _canMove(player)) {
          await _executeTurn(
            player,
            opponent,
            move,
            opponentMove: currentTurnOpponentMove,
          );
        }
        playerMovedThisTurn = true;
      }
      if (_checkBattleEnd()) return;
      if (currentState == BattleState.waitingForPlayerSwitch) return;

      // Opponent Turn
      if (!opponentMovedThisTurn && !opponentJustSwitched) {
        if (await _canMove(opponent)) {
          await _executeTurn(
            opponent,
            player,
            currentTurnOpponentMove!,
            opponentMove: move,
          );
        }
        opponentMovedThisTurn = true;
      }
      if (_checkBattleEnd()) return;
      if (currentState == BattleState.waitingForPlayerSwitch) return;
    } else {
      // Opponent Turn
      if (!opponentMovedThisTurn && !opponentJustSwitched) {
        if (await _canMove(opponent)) {
          await _executeTurn(
            opponent,
            player,
            currentTurnOpponentMove!,
            opponentMove: move,
          );
        }
        opponentMovedThisTurn = true;
      }
      if (_checkBattleEnd()) return;
      if (currentState == BattleState.waitingForPlayerSwitch) return;

      // Player Turn
      if (!playerMovedThisTurn && (!playerJustSwitched || isResumingTurn)) {
        if (await _canMove(player)) {
          await _executeTurn(
            player,
            opponent,
            move,
            opponentMove: currentTurnOpponentMove,
          );
        }
        playerMovedThisTurn = true;
      }
      if (_checkBattleEnd()) return;
      if (currentState == BattleState.waitingForPlayerSwitch) return;
    }

    // 3. Finalize Turn
    await _finalizeTurn();
  }

  // Executes the move and applies effects
  Future<void> _executeTurn(
    BattleOrganism attacker,
    BattleOrganism defender,
    Move move, {
    Move? opponentMove,
  }) async {
    // 1. Multi-turn logical handling
    if (attacker.chargingMove != null) {
      move = attacker.chargingMove!;
      attacker.chargingMove = null;
      attacker.semiInvulnerable = null;
    } else if (move.isMultiTurn) {
      final chargeEffect = move.effects.firstWhere(
        (e) =>
            e.type == MoveEffectType.charge ||
            e.type == MoveEffectType.semiInvulnerable,
        orElse: () => const MoveEffect(type: MoveEffectType.none),
      );

      if (chargeEffect.type != MoveEffectType.none) {
        _addToLog(
          '${attacker.organism.baseOrganism.name} ${move.name == 'Dig' ? 'burrowed underground!' : 'is preparing an attack!'}',
        );
        attacker.chargingMove = move;
        attacker.chargeStatChanges = chargeEffect.stat;
        if (chargeEffect.type == MoveEffectType.semiInvulnerable) {
          attacker.semiInvulnerable = chargeEffect.stat;
        }
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 3000));
        return; // Turn ends here for charging
      }
    }

    // recharging move stamina
    if (attacker.organism.moveStamina.containsKey(move.name)) {
      attacker.organism.moveStamina[move.name] =
          (attacker.organism.moveStamina[move.name]! - 1).clamp(
            0,
            move.stamina,
          );
    }

    if (move.customUsageText != null && move.customUsageText!.isNotEmpty) {
      _addToLog(move.customUsageText!);
    } else {
      _addToLog('${attacker.organism.baseOrganism.name} used ${move.name}!');
    }
    notifyListeners();
    // Trigger attack animation
    onAttack?.call(attacker);
    await Future.delayed(const Duration(milliseconds: 3000));

    // --- Ability Triggers: onCalculateDamage (Self) ---
    for (final ab in attacker.abilities) {
      if (ab.trigger == AbilityTrigger.onCalculateDamage) {
        if (ab.name == 'Adaptability' && attacker.types.contains(move.type)) {
          // Handled below in STAB
        }
      }
    }

    // 1. Accuracy Check (Blindness + Weather affects accuracy)
    int accuracy = move.accuracy;
    if (attacker.statusEffect.type == StatusEffectType.blind) {
      accuracy = (accuracy * 0.75).round(); // Reduce accuracy by 25% if blinded
    }

    // Weather-based accuracy modifier
    accuracy = (accuracy * currentWeather.accuracyModifier).round();

    if (Random().nextInt(100) >= accuracy) {
      _addToLog('...but it missed!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
      return;
    }

    // 2. Protection and Invulnerability Checks
    if (defender.isInvulnerable) {
      _addToLog('${defender.organism.baseOrganism.name} is hidden!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
      return;
    }

    if (defender.isProtected) {
      _addToLog('${defender.organism.baseOrganism.name} protected itself!');
      if (move.name == 'Baneful Bunker' ||
          (move.name != 'Protect' &&
              attacker.organism.baseOrganism.moves.contains(
                'Baneful Bunker',
              ))) {
        if (move.baseDamage > 0) {
          await _applyMoveEffect(defender, attacker, [
            const MoveEffect(type: MoveEffectType.statusPoison),
          ], move);
        }
      }
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
      return;
    }

    // Flag-based fail check
    if (move.failIfTargetNotAttacking) {
      if (opponentMove == null || opponentMove.baseDamage == 0) {
        _addToLog('...but it failed!');
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 3000));
        return;
      }
    }

    // Determine which stats to use based on move category
    int effectiveAttackerAtk;
    int effectiveDefenderDef;

    if (move.category == MoveCategory.special) {
      effectiveAttackerAtk = attacker.currentPower;
      effectiveDefenderDef = defender.currentResistance;
    } else {
      // Default to physical
      effectiveAttackerAtk = attacker.currentAttack;
      effectiveDefenderDef = defender.currentDefense;
    }

    // Allow the move to override EXACTLY which stat it uses for the ATTACKER
    if (move.damageStat.isNotEmpty) {
      if (move.damageStat == 'attack')
        effectiveAttackerAtk = attacker.currentAttack;
      else if (move.damageStat == 'power')
        effectiveAttackerAtk = attacker.currentPower;
      else if (move.damageStat == 'defense')
        effectiveAttackerAtk = attacker.currentDefense;
      else if (move.damageStat == 'resistance')
        effectiveAttackerAtk = attacker.currentResistance;
      else if (move.damageStat == 'speed')
        effectiveAttackerAtk = attacker.currentSpeed;
    }

    // Note: If we added moves that target a specific defense (like Psyshock),
    // we would add an override for effectiveDefenderDef here.

    // Multi-Hit Loop
    int hits = 1;
    if (move.maxHits > 1) {
      hits = move.minHits + Random().nextInt(move.maxHits - move.minHits + 1);
    }

    int totalDamageDealt = 0;

    for (int i = 0; i < hits; i++) {
      if (defender.health <= 0) break; // Stop if opponent fainted

      // 2. Damage Calculation (Standard Formula: (((2*Level/5 + 2) * Atk * BaseDamage / Def) / 50 + 2) * Modifiers)
      if (move.baseDamage > 0) {
        // Weather Modifiers
        double weatherMod = currentWeather.getDamageMultiplier(
          move.type.toString().split('.').last,
        );

        // Critical Hit Logic
        bool isCrit = false;
        double critChance = 6.25; // Base 1/16 chance

        // Talisman crit boost
        if (attacker.organism.equippedTalisman?.effect.type ==
            TalismanEffectType.critBoost) {
          critChance += attacker.organism.equippedTalisman!.effect.magnitude;
        }

        // Move-specific crit rate
        if (move.critRate == 1) critChance = 12.5; // 1/8
        if (move.critRate == 2) critChance = 50.0; // 1/2
        if (move.critRate >= 3) critChance = 100.0; // Guaranteed crit

        if (Random().nextDouble() * 100 < critChance) {
          isCrit = true;
        }

        // Battle Armor check
        bool hasBattleArmor = false;
        for (final ab in defender.abilities) {
          if (ab.name == 'Battle Armor') hasBattleArmor = true;
        }
        if (hasBattleArmor) {
          isCrit = false;
        }

        // Core Damage Formula
        double damageCalc =
            ((2 * attacker.level / 5 + 2) *
                    move.baseDamage *
                    effectiveAttackerAtk /
                    effectiveDefenderDef) /
                50 +
            2;

        if (isCrit) {
          damageCalc *= 1.5;
        }

        // Random variance (0.85 to 1.0)
        double random = 0.85 + (Random().nextDouble() * 0.15);
        damageCalc *= random;

        damageCalc *= weatherMod;

        // Generic conditional multiplier
        if (move.multiplierCondition.isNotEmpty) {
          double multiplier = 1.0;
          final condition = move.multiplierCondition.toLowerCase();

          if (condition == 'target_poisoned' &&
              defender.statusEffect.type == StatusEffectType.poison) {
            multiplier = move.conditionalMultiplier;
          } else if (condition == 'target_damaged' &&
              defender.tookDamageThisTurn) {
            multiplier = move.conditionalMultiplier;
          } else if (condition == 'target_statused' &&
              defender.statusEffect.type != StatusEffectType.none) {
            multiplier = move.conditionalMultiplier;
          }

          damageCalc *= multiplier;
        }

        // Talisman damage multiplier
        if (attacker.organism.equippedTalisman?.effect.type ==
            TalismanEffectType.damageMultiplier) {
          damageCalc *= attacker.organism.equippedTalisman!.effect.magnitude;
        }

        // Talisman resistance boost (multiplier on incoming damage)
        if (defender.organism.equippedTalisman?.effect.type ==
            TalismanEffectType.resistanceBoost) {
          damageCalc *= defender.organism.equippedTalisman!.effect.magnitude;
        }

        // Vulnerable Status
        if (defender.statusEffect.type == StatusEffectType.vulnerable) {
          damageCalc *= 1.3; // Take 30% more damage
        }

        // Marked Status
        if (defender.statusEffect.type == StatusEffectType.marked) {
          damageCalc *= 1.2; // Take 20% more damage
        }

        // Type Effectiveness
        double typeMod = 1.0;
        for (final defType in defender.types) {
          typeMod *= TypeChart.getEffectiveness(move.type, defType);
        }
        damageCalc *= typeMod;

        // STAB
        if (attacker.types.contains(move.type)) {
          double stabBonus = 1.5;
          for (final ab in attacker.abilities) {
            if (ab.name == 'Adaptability') {
              stabBonus = ab.magnitude;
            }
          }
          damageCalc *= stabBonus;
        }

        // Weather Modifiers
        damageCalc *= weatherMod;

        // Randomness (0.9 to 1.1) and Round
        final int finalDamage =
            (damageCalc * (Random().nextDouble() * 0.2 + 0.9)).round();

        int oldHealth = defender.health;
        defender.health -= finalDamage;
        defender.health = defender.health.clamp(0, defender.maxHealth);
        totalDamageDealt += finalDamage;
        defender.tookDamageThisTurn = true;

        if (move.drainPercent > 0 && finalDamage > 0) {
          final healAmount = (finalDamage * move.drainPercent).round();
          attacker.health = (attacker.health + healAmount).clamp(
            0,
            attacker.maxHealth,
          );
          _addToLog(
            '${attacker.organism.baseOrganism.name} drained $healAmount health!',
          );
        }
        if (move.recoilPercent > 0 && finalDamage > 0) {
          final recoilDamage = (finalDamage * move.recoilPercent).round();
          attacker.health = (attacker.health - recoilDamage).clamp(
            0,
            attacker.maxHealth,
          );
          _addToLog(
            '${attacker.organism.baseOrganism.name} took $recoilDamage recoil damage!',
          );
        }
        // --- Ability Triggers: onDamageTaken ---
        for (final ab in defender.abilities) {
          if (ab.trigger == AbilityTrigger.onDamageTaken) {
            bool conditionMet = true;
            for (final cond in ab.conditions) {
              if (cond == 'crit' && !isCrit) conditionMet = false;
              if (cond == 'hp_below_50' &&
                  (defender.health / defender.maxHealth >= 0.5 ||
                      oldHealth / defender.maxHealth < 0.5))
                conditionMet = false;
              if (cond == 'contact' && !move.isContact) conditionMet = false;
            }

            if (conditionMet) {
              if (ab.effectType == AbilityEffectType.statChange) {
                await _notifyAbilityTrigger(defender, ab);
                await _applyStatChange(
                  defender,
                  ab.targetStat,
                  ab.magnitude.toInt(),
                );
              } else if (ab.effectType == AbilityEffectType.typeChange) {
                await _notifyAbilityTrigger(defender, ab);
                defender.battleTypes = [move.type];
                _addToLog(
                  '${defender.organism.baseOrganism.name} changed its type to ${move.type.toString().split('.').last}!',
                );
                notifyListeners();
                await Future.delayed(const Duration(milliseconds: 3000));
              } else if (ab.effectType == AbilityEffectType.statusChange &&
                  Random().nextDouble() < ab.chance) {
                if (attacker.statusEffect.type == StatusEffectType.none) {
                  await _notifyAbilityTrigger(defender, ab);
                  attacker.addStatusEffect(
                    StatusEffect(
                      type: StatusEffectType.poison,
                      duration: int.tryParse(ab.value) ?? 3,
                    ),
                  );
                  _addToLog(
                    '${attacker.organism.baseOrganism.name} was poisoned!',
                  );
                  notifyListeners();
                  await Future.delayed(const Duration(milliseconds: 3000));
                }
              }
            }
          }
        }

        // --- Ability Triggers: onDamageDealt ---
        for (final ab in attacker.abilities) {
          if (ab.trigger == AbilityTrigger.onDamageDealt) {
            bool conditionMet = true;
            for (final cond in ab.conditions) {
              if (cond == 'contact' && !move.isContact) conditionMet = false;
            }

            if (conditionMet &&
                ab.effectType == AbilityEffectType.statusChange &&
                Random().nextDouble() < ab.chance) {
              if (defender.statusEffect.type == StatusEffectType.none) {
                await _notifyAbilityTrigger(attacker, ab);
                defender.addStatusEffect(
                  StatusEffect(
                    type: StatusEffectType.poison,
                    duration: int.tryParse(ab.value) ?? 3,
                  ),
                );
                _addToLog(
                  '${defender.organism.baseOrganism.name} was poisoned!',
                );
                notifyListeners();
                await Future.delayed(const Duration(milliseconds: 3000));
              }
            }
          }
        }

        _addToLog(
          hits > 1
              ? 'Hit ${i + 1}!'
              : '${defender.organism.baseOrganism.name} took $finalDamage damage!',
        );

        if (typeMod > 1.0) _addToLog('It\'s super effective!');
        if (typeMod < 1.0 && typeMod > 0)
          _addToLog('It\'s not very effective...');
        if (typeMod == 0) _addToLog('It had no effect!');
        if (isCrit) _addToLog('A critical hit!');

        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 3000));
      }
    }
    if (attacker.health > 0 && defender.health >= 0) {
      await _applyMoveEffect(attacker, defender, move.effects, move);
    }
  }

  Future<bool> _canMove(BattleOrganism org) async {
    if (org.mustRecharge) {
      _addToLog('${org.organism.baseOrganism.name} must recharge!');
      org.mustRecharge = false; // Recharge turn is used now
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
      return false;
    }
    if (org.statusEffect.type == StatusEffectType.sleep) {
      if (org.statusEffect.duration <= 0) {
        _addToLog('${org.organism.baseOrganism.name} woke up!');
        org.clearStatusEffects(); // Clear all statuses, or just sleep? For now, clear all.
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 3000));
        return true;
      }

      // Status Duration Decay
      int decay = 1;
      final wakeUpAbility = org.abilities.firstWhere(
        (ab) => ab.effectType == AbilityEffectType.wakeUpFaster,
        orElse: () => const Ability(name: '', description: ''),
      );
      if (wakeUpAbility.name.isNotEmpty) {
        await _notifyAbilityTrigger(org, wakeUpAbility);
        decay = 2;
      }

      // Find the sleep status and update its duration
      final updatedStatuses = org.statusEffects.map((se) {
        if (se.type == StatusEffectType.sleep) {
          return se.copyWith(duration: max(0, se.duration - decay));
        }
        return se;
      }).toList();
      org.statusEffects = updatedStatuses;

      _addToLog('${org.organism.baseOrganism.name} is fast asleep.');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
      return false;
    }
    if (org.statusEffect.type == StatusEffectType.stun) {
      _addToLog(
        '${org.organism.baseOrganism.name} is stunned and cannot move!',
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
      // Stun is cleared immediately after skipping one turn
      org.clearStatusEffects(); // Clear all statuses, or just stun? For now, clear all.
      return false;
    }
    if (org.statusEffect.type == StatusEffectType.confusion) {
      _addToLog('${org.organism.baseOrganism.name} is confused!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 2000));
      if (Random().nextDouble() < 0.33) {
        _addToLog('It hurt itself in its confusion!');
        final selfDamage = (org.maxHealth * 0.15).round();
        org.health -= selfDamage;
        org.health = org.health.clamp(0, org.maxHealth);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 2800));
        return false;
      }
    }
    if (org.statusEffect.type == StatusEffectType.freeze) {
      // 20% chance to thaw
      if (Random().nextDouble() < 0.2) {
        _addToLog('${org.organism.baseOrganism.name} thawed out!');
        org.clearStatusEffects(); // Clear all statuses, or just freeze? For now, clear all.
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 3000));
        return true;
      }
      _addToLog('${org.organism.baseOrganism.name} is frozen solid!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
      return false;
    }
    if (org.statusEffect.type == StatusEffectType.paralysis) {
      if (Random().nextDouble() < 0.25) {
        _addToLog(
          '${org.organism.baseOrganism.name} is paralyzed! It can\'t move!',
        );
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 2200));
        return false;
      }
    }
    return true;
  }

  Future<void> _processOpponentTurn({required bool isCounter}) async {
    if (!isCounter) {
      _addToLog('Opponent\'s turn!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 1200));
    }

    // Simple AI: Select a random move from its specific list

    // Simple AI: Select a random move from its specific list
    final opponentMove = opponentMoves[Random().nextInt(opponentMoves.length)];

    if (await _canMove(opponent)) {
      await _executeTurn(opponent, player, opponentMove);
    }
  }

  // --- Core Effect Logic ---

  Future<void> _applyMoveEffect(
    BattleOrganism attacker,
    BattleOrganism defender,
    List<MoveEffect> effects, // Changed to List<MoveEffect>
    Move move,
  ) async {
    for (final effect in effects) {
      if (effect.type == MoveEffectType.none) continue;

      final target = effect.target == 'self' ? attacker : defender;

      switch (effect.type) {
        case MoveEffectType.statusBurn:
        case MoveEffectType.statusSleep:
        case MoveEffectType.statusParalysis:
        case MoveEffectType.statusFreeze:
        case MoveEffectType.statusBleed:
        case MoveEffectType.statusConfusion:
        case MoveEffectType.statusBlind:
        case MoveEffectType.statusRegen:
        case MoveEffectType.statusVulnerable:
        case MoveEffectType.statusStun:
        case MoveEffectType.statusPoison:
        case MoveEffectType.statusFear:
        case MoveEffectType.statusMarked:
          // --- 1. Consolidate Status Mapping ---
          StatusEffectType statusType;
          switch (effect.type) {
            case MoveEffectType.statusPoison:
              statusType = StatusEffectType.poison;
              break;
            case MoveEffectType.statusBurn:
              statusType = StatusEffectType.burn;
              break;
            case MoveEffectType.statusSleep:
              statusType = StatusEffectType.sleep;
              break;
            case MoveEffectType.statusParalysis:
              statusType = StatusEffectType.paralysis;
              break;
            case MoveEffectType.statusFreeze:
              statusType = StatusEffectType.freeze;
              break;
            case MoveEffectType.statusBleed:
              statusType = StatusEffectType.bleed;
              break;
            case MoveEffectType.statusConfusion:
              statusType = StatusEffectType.confusion;
              break;
            case MoveEffectType.statusBlind:
              statusType = StatusEffectType.blind;
              break;
            case MoveEffectType.statusRegen:
              statusType = StatusEffectType.regen;
              break;
            case MoveEffectType.statusVulnerable:
              statusType = StatusEffectType.vulnerable;
              break;
            case MoveEffectType.statusStun:
              statusType = StatusEffectType.stun;
              break;
            case MoveEffectType.statusFear:
              statusType = StatusEffectType.fear;
              break;
            case MoveEffectType.statusMarked:
              statusType = StatusEffectType.marked;
              break;
            default:
              statusType = StatusEffectType.none;
          }

          if (statusType == StatusEffectType.none) continue;

          // --- 2. Ability Trigger: onStatusAttempt (Prevention) ---
          bool prevented = false;
          for (final ab in target.abilities) {
            if (ab.trigger == AbilityTrigger.onStatusAttempt) {
              if (ab.effectType == AbilityEffectType.preventStatus &&
                  ab.value == statusType.toString().split('.').last) {
                await _notifyAbilityTrigger(target, ab);
                _addToLog(
                  '${target.organism.baseOrganism.name} prevented the status!',
                );
                notifyListeners();
                await Future.delayed(const Duration(milliseconds: 3000));
                prevented = true;
                break;
              }
            }
          }
          if (prevented) continue;

          // --- 3. Chance and Terrain Checks ---
          if (Random().nextInt(100) >= effect.chance) continue;

          if (currentTerrain.terrain == Terrain.misty ||
              (effect.type == MoveEffectType.statusSleep &&
                  currentTerrain.terrain == Terrain.electric)) {
            _appendToLog('\nThe terrain prevents the status condition!');
          } else {
            // Check if already has this status if it's not stackable
            // For now, let's just add it. Multi-status system handles it.

            // Default durations: Major (Indefinite), Volatile (Fixed)
            int duration = -1; // Default to indefinite for major statuses

            if (statusType == StatusEffectType.sleep)
              duration = 2 + Random().nextInt(4); // 2-5 turns
            else if (statusType == StatusEffectType.stun)
              duration = 1;
            else if (statusType == StatusEffectType.regen ||
                statusType == StatusEffectType.confusion ||
                statusType == StatusEffectType.blind ||
                statusType == StatusEffectType.vulnerable) {
              duration = 3 + Random().nextInt(3);
            } else if (statusType == StatusEffectType.fear ||
                statusType == StatusEffectType.marked) {
              duration = 2; // Lasts for next 2 turns
            } else if (effect.value > 0) {
              duration = effect.value; // Use move-defined duration if present
            }

            final newStatus = StatusEffect(
              type: statusType,
              duration: duration,
              // Mapping default colors/names from StatusEffect if needed, but constructor handles it
            );
            target.addStatusEffect(newStatus);
            _appendToLog(
              '\n${target.organism.baseOrganism.name} ${newStatus.startMessage}',
            );
          }
          break;
        case MoveEffectType.weather:
          if (effect.stat == 'rain')
            _setWeather(Weather.rain);
          else if (effect.stat == 'sun')
            _setWeather(Weather.heatwave);
          else if (effect.stat == 'hail')
            _setWeather(Weather.blizzard);
          else if (effect.stat == 'sandstorm')
            _setWeather(Weather.sandstorm);
          break;
        case MoveEffectType.terrain:
          if (effect.stat == 'electric')
            _setTerrain(Terrain.electric);
          else if (effect.stat == 'grassy')
            _setTerrain(Terrain.grassy);
          else if (effect.stat == 'misty')
            _setTerrain(Terrain.misty);
          else if (effect.stat == 'psychic')
            _setTerrain(Terrain.psychic);
          break;
        case MoveEffectType.statChange:
          await _applyStatChange(target, effect.stat, effect.value);
          _appendToLog(
            '\n${target.organism.baseOrganism.name}\'s ${effect.stat} stage ${effect.value > 0 ? 'increased' : 'decreased'}!',
          );
          break;
        case MoveEffectType.multiStatChange:
          // Format stat: 'attack:1,defense:1' or similar
          final changes = effect.stat.split(',');
          for (final change in changes) {
            final parts = change.split(':');
            if (parts.length == 2) {
              final stat = parts[0];
              final val = int.tryParse(parts[1]) ?? 0;
              await _applyStatChange(target, stat, val);
            }
          }
          _appendToLog(
            '\n${target.organism.baseOrganism.name}\'s stats changed!',
          );
          break;
        case MoveEffectType.statChangeChance:
          if (Random().nextInt(100) < effect.chance) {
            final changes = effect.stat.split(',');
            for (final change in changes) {
              final parts = change.split(':');
              if (parts.length == 2) {
                final stat = parts[0];
                final val = int.tryParse(parts[1]) ?? 0;
                await _applyStatChange(target, stat, val);
              }
            }
            _appendToLog(
              '\n${target.organism.baseOrganism.name}\'s stats increased!',
            );
          }
          break;
        case MoveEffectType.protect:
          attacker.isProtected = true;
          break;
        case MoveEffectType.heal:
          final healedAmount = effect.value;
          target.health += healedAmount;
          target.health = target.health.clamp(0, target.maxHealth);
          _appendToLog(
            '\n${target.organism.baseOrganism.name} recovered $healedAmount HP!',
          );
          break;
        case MoveEffectType.recharge:
          attacker.rechargeTurn = true;
          break;
        case MoveEffectType.charge:
          attacker.chargeMove = move;
          attacker.chargeStatChanges = effect.stat;
          break;
        case MoveEffectType.semiInvulnerable:
          attacker.semiInvulnerable = effect.stat;
          break;
        default:
          break;
      }

      // HP Cost (e.g. for Belly Drum)
      if (effect.hpCostPercent > 0) {
        final cost = (attacker.maxHealth * effect.hpCostPercent).floor();
        attacker.health -= cost;
        _appendToLog(
          '\n${attacker.organism.baseOrganism.name} cut its own HP!',
        );
        notifyListeners();
      }
    }
  }

  Future<void> _applyStatChange(
    BattleOrganism target,
    String stat,
    int value,
  ) async {
    // --- Ability Trigger: onStatLoss (Prevention) ---
    if (value < 0) {
      for (final ab in target.abilities) {
        if (ab.trigger == AbilityTrigger.onStatLoss &&
            ab.effectType == AbilityEffectType.preventStatLoss) {
          await _notifyAbilityTrigger(target, ab);
          _addToLog(
            '${target.organism.baseOrganism.name}\'s ${ab.name} prevents stat loss!',
          );
          return;
        }
      }
    }

    if (stat == 'all') {
      await _changeStat(target, 'attack', value);
      await _changeStat(target, 'defense', value);
      await _changeStat(target, 'power', value);
      await _changeStat(target, 'resistance', value);
      await _changeStat(target, 'speed', value);
    } else {
      final stats = stat.split(',');
      for (final s in stats) {
        final pair = s.trim().split(':');
        final statName = pair[0];
        final statValue = pair.length > 1
            ? int.tryParse(pair[1]) ?? value
            : value;
        await _changeStat(target, statName, statValue);
      }
    }
  }

  Future<void> _changeStat(
    BattleOrganism target,
    String statName,
    int value,
  ) async {
    int oldStage = 0;
    if (statName == 'attack')
      oldStage = target.attackStage;
    else if (statName == 'defense')
      oldStage = target.defenseStage;
    else if (statName == 'power')
      oldStage = target.powerStage;
    else if (statName == 'resistance')
      oldStage = target.resistanceStage;
    else if (statName == 'speed')
      oldStage = target.speedStage;

    if (statName == 'attack')
      target.attackStage = (target.attackStage + value).clamp(-6, 6);
    else if (statName == 'defense')
      target.defenseStage = (target.defenseStage + value).clamp(-6, 6);
    else if (statName == 'power')
      target.powerStage = (target.powerStage + value).clamp(-6, 6);
    else if (statName == 'resistance')
      target.resistanceStage = (target.resistanceStage + value).clamp(-6, 6);
    else if (statName == 'speed')
      target.speedStage = (target.speedStage + value).clamp(-6, 6);

    // --- Ability Trigger: onStatLoss (Reaction e.g. Defiant) ---
    if (value < 0) {
      for (final ab in target.abilities) {
        if (ab.trigger == AbilityTrigger.onStatLoss &&
            ab.effectType == AbilityEffectType.statChange) {
          await _notifyAbilityTrigger(target, ab);
          await _applyStatChange(target, ab.targetStat, ab.magnitude.round());
        }
      }
    }
  }

  Future<void> _applyGlobalTurnEffects() async {
    // Weather
    if (weatherTurnsLeft > 0) {
      weatherTurnsLeft--;
      // Show weather persistence message every turn
      if (currentWeather.weather != Weather.clear) {
        final msg = _getWeatherPersistenceMessage(currentWeather.weather);
        if (msg.isNotEmpty) {
          _addToLog(msg);
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 3000));
        }
      }

      if (weatherTurnsLeft == 0) {
        _addToLog(currentWeather.endMessage);
        currentWeather = const WeatherEffect(weather: Weather.none);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 3000));
      }
    }

    // Terrain
    if (terrainTurnsLeft > 0) {
      terrainTurnsLeft--;
      if (terrainTurnsLeft == 0) {
        _addToLog(currentTerrain.endMessage);
        currentTerrain = const TerrainEffect(terrain: Terrain.none);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 3000));
      }
    }
  }

  Future<void> _applyTurnEffects(BattleOrganism target) async {
    if (target.health <= 0) return;

    // Status Damage & Healing (Iterate over all active effects)
    final List<StatusEffect> currentEffects = List.from(target.statusEffects);
    for (final se in currentEffects) {
      if (se.type == StatusEffectType.poison) {
        final poisonDamage = (target.maxHealth * 0.125).round().clamp(1, 9999);
        target.health -= poisonDamage;
        target.health = target.health.clamp(0, target.maxHealth);
        _addToLog('${target.organism.baseOrganism.name} is hurt by poison!');
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 3000));
      } else if (se.type == StatusEffectType.burn) {
        final burnDamage = (target.maxHealth * 0.06).round().clamp(1, 9999);
        target.health -= burnDamage;
        target.health = target.health.clamp(0, target.maxHealth);
        _addToLog('${target.organism.baseOrganism.name} is hurt by its burn!');
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 3000));
      } else if (se.type == StatusEffectType.bleed) {
        final bleedDamage = (target.maxHealth * 0.125).round().clamp(1, 9999);
        target.health -= bleedDamage;
        target.health = target.health.clamp(0, target.maxHealth);
        _addToLog('${target.organism.baseOrganism.name} is hurt by bleeding!');
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 3000));
      } else if (se.type == StatusEffectType.regen) {
        final heal = (target.maxHealth * 0.06).round().clamp(1, 9999);
        target.health += heal;
        target.health = target.health.clamp(0, target.maxHealth);
        _addToLog('${target.organism.baseOrganism.name} restored a little HP.');
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 3000));
      }
    }

    if (target.health <= 0) return;

    // Weather Damage
    if (currentWeather.weather == Weather.sandstorm) {
      final damage = (target.maxHealth * 0.06).round().clamp(1, 9999);
      target.health -= damage;
      target.health = target.health.clamp(0, target.maxHealth);
      _addToLog(
        '${target.organism.baseOrganism.name} is buffeted by the sandstorm!',
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
    } else if (currentWeather.weather == Weather.blizzard) {
      final damage = (target.maxHealth * 0.0625).round().clamp(1, 9999);
      target.health -= damage;
      target.health = target.health.clamp(0, target.maxHealth);
      _addToLog(
        '${target.organism.baseOrganism.name} is battered by the blizzard!',
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
    }

    // Grassy Terrain Healing
    if (currentTerrain.terrain == Terrain.grassy) {
      final heal = (target.maxHealth * 0.06).round();
      target.health += heal;
      target.health = target.health.clamp(0, target.maxHealth);
      _addToLog(
        '${target.organism.baseOrganism.name} is healed by the Grassy Terrain!',
      );
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
    }

    // Status Duration Decay and Recovery for ALL effects
    final List<StatusEffect> updatedEffects = [];
    bool stateChanged = false;

    for (final se in target.statusEffects) {
      if (se.duration > 0 && se.type != StatusEffectType.sleep) {
        final newDuration = max(0, se.duration - 1);
        if (newDuration == 0) {
          _addToLog(
            '${target.organism.baseOrganism.name} recovered from ${se.name}!',
          );
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 3000));
          stateChanged = true;
          // Don't add to updatedEffects, effectively removing it
        } else {
          updatedEffects.add(se.copyWith(duration: newDuration));
        }
      } else {
        updatedEffects.add(se);
      }
    }

    if (stateChanged || updatedEffects.length != target.statusEffects.length) {
      target.organism.statusEffects = updatedEffects;
      target.organism.statusEffects = updatedEffects; // Sync
      notifyListeners();
    }
  }

  // --- Capture and Run Logic ---

  Future<void> attemptCapture() async {
    if (currentState != BattleState.waitingForInput) return;

    currentState = BattleState.applyingEffects;
    _addToLog('Throwing a Capture Net...');
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));

    final hpRatio = opponent.health / opponent.maxHealth;
    final baseChance = 0.50;
    final hpBonus = (1.0 - hpRatio) * 0.50;

    double captureChance = baseChance + hpBonus;

    // 🚨 FIX: Reverting to baseOrganism
    if (opponent.organism.baseOrganism.rarity.toLowerCase() == 'epic') {
      captureChance *= 0.7;
    }

    if (Random().nextDouble() < captureChance) {
      opponent.organism.currentHealth = opponent.health;
      _result = BattleResult.capture;
      // 🚨 FIX: Reverting to baseOrganism
      _addToLog(
        'Success! ${opponent.organism.baseOrganism.name} was captured!',
      );
    } else {
      _result = null;
      _addToLog('The capture failed! Opponent is still fighting.');
      currentState = BattleState.opponentTurn;
      await Future.delayed(const Duration(seconds: 1));
      await _processOpponentTurn(isCounter: false);
    }

    if (result == BattleResult.capture) {
      currentState = BattleState.battleEnd;
      notifyListeners();
    } else if (currentState == BattleState.opponentTurn) {
      await _finalizeTurn();
    }
  }

  Future<void> attemptRun() async {
    if (currentState != BattleState.waitingForInput) return;

    currentState = BattleState.applyingEffects;
    _addToLog('Attempting to run...');
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));

    final runChance = (player.currentSpeed / opponent.currentSpeed) * 0.75;

    // Arena Trap check
    final trapper = opponent.abilities.firstWhere(
      (ab) => ab.name == 'Arena Trap',
      orElse: () => const Ability(name: '', description: ''),
    );
    if (trapper.name.isNotEmpty) {
      await _notifyAbilityTrigger(opponent, trapper);
      _addToLog(
        'The wild ${opponent.organism.baseOrganism.name} prevents escape!',
      );
      currentState = BattleState.opponentTurn;
      await Future.delayed(const Duration(seconds: 1));
      await _processOpponentTurn(isCounter: false);
      currentState = BattleState.waitingForInput;
      notifyListeners();
      return;
    }

    if (Random().nextDouble() < runChance.clamp(0.1, 1.0)) {
      _result = BattleResult.fled;
      _addToLog('You successfully ran away!');
      currentState = BattleState.battleEnd;
      notifyListeners();
    } else {
      _result = null;
      _addToLog('Failed to run! Opponent\'s turn.');
      currentState = BattleState.opponentTurn;
      await Future.delayed(const Duration(seconds: 1));
      await _processOpponentTurn(isCounter: false);
      await _finalizeTurn();
    }
  }

  Future<void> switchAnimal(int index) async {
    bool isForced = currentState == BattleState.waitingForPlayerSwitch;
    if (currentState != BattleState.waitingForInput && !isForced) return;
    if (index < 0 || index >= playerTeam.length) return;
    if (index == currentPlayerIndex) return;
    if (playerTeam[index].currentHealth <= 0) return;

    currentState = BattleState.applyingEffects;
    _addToLog('Come back, ${player.organism.baseOrganism.name}!');
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 3000));

    _switchToAnimal(index);
    if (isForced) {
      isResumingTurn =
          true; // Mark as resuming so we don't start a new turn cycle
    } else {
      playerJustSwitched = true; // Normal switch skips player's turn action
    }
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 3000));

    if (isForced) {
      // If forced switch, turn continues or waits for next round
      currentState = BattleState.waitingForInput;
      _addToLog('What will ${player.organism.name} do?');
      notifyListeners();
      return;
    }

    // Normal switching takes a turn, so process opponent's turn
    currentState = BattleState.opponentTurn;
    await _processOpponentTurn(isCounter: false);

    await _finalizeTurn();
  }

  Future<void> _finalizeTurn() async {
    if (!_checkBattleEnd()) {
      await _applyGlobalTurnEffects();
      if (_checkBattleEnd()) return;

      await _applyTurnEffects(player);
      if (_checkBattleEnd()) return;

      await _applyTurnEffects(opponent);
      if (_checkBattleEnd()) return;
    }

    if (!_checkBattleEnd()) {
      currentTurn++;
      turnHistory.add(BattleTurn(currentTurn));

      currentState = BattleState.waitingForInput;
      _addToLog('What will ${player.organism.name} do?');

      // Reset flags for next turn
      playerMovedThisTurn = false;
      opponentMovedThisTurn = false;
      isResumingTurn = false;
      currentTurnOpponentMove = null;

      player.isProtected = false;
      opponent.isProtected = false;
      player.isInvulnerable = false;
      opponent.isInvulnerable = false;
    }
    notifyListeners();
  }

  void _switchToAnimal(int index) {
    if (index < 0 || index >= playerTeam.length) return;
    currentPlayerIndex = index;

    player = BattleOrganism(playerOrganism, isRogueMode: isRogueMode);
    playerMoves = _getOrganismMoves(playerOrganism);

    _addToLog('Go, ${player.organism.baseOrganism.name}!');
    notifyListeners();
  }

  // --- End Check ---

  bool _checkBattleEnd() {
    if (player.health <= 0) {
      // Check if team has more healthy animals
      final nextHealthyIndex = playerTeam.indexWhere(
        (org) => org.currentHealth > 0,
      );

      if (nextHealthyIndex != -1) {
        _addToLog(
          'Your ${player.organism.baseOrganism.name} fainted! Choose an animal to send out.',
        );
        currentState = BattleState.waitingForPlayerSwitch;
        notifyListeners();
        return false; // Battle continues, but waiting for switch
      }

      _result = BattleResult.loss;
      // 🚨 FIX: Reverting to baseOrganism
      _addToLog(
        'Your ${player.organism.baseOrganism.name} fainted! Your whole team is defeated.',
      );
      currentState = BattleState.battleEnd;
      notifyListeners();
      return true;
    }
    if (opponent.health <= 0) {
      // ARENA BATTLE: Check if opponent has more animals
      if (isArenaBattle) {
        final nextOpponentHealthy = opponentTeam.indexWhere(
          (org) => org.currentHealth > 0,
        );

        if (nextOpponentHealthy != -1) {
          _addToLog(
            'Opponent\'s ${opponent.organism.baseOrganism.name} fainted!',
          );
          _switchOpponentTo(nextOpponentHealthy);
          opponentJustSwitched = true; // Prevent immediate attack
          return false; // Battle continues
        }

        // All opponent animals defeated
        _result = BattleResult.win;
        _addToLog(
          'Opponent\'s ${opponent.organism.baseOrganism.name} fainted! You won the arena battle!',
        );
        currentState = BattleState.battleEnd;
        onVictory?.call();
        notifyListeners();
        return true;
      }

      // WILD BATTLE: Single opponent defeat
      _result = BattleResult.win;

      // Roll for loot (only in wild battles, not Rogue-like)
      if (!isRogueMode) {
        _droppedLoot = opponent.organism.baseOrganism.rollLootDrop();
      }
      if (_droppedLoot != null) {
        _addToLog(
          'The wild ${opponent.organism.baseOrganism.name} fainted! You won the battle.',
        );
        _appendToLog('\nIt dropped something!');
      } else {
        _addToLog(
          'The wild ${opponent.organism.baseOrganism.name} fainted! You won the battle.',
        );
      }

      currentState = BattleState.battleEnd;
      onVictory?.call();
      notifyListeners();
      return true;
    }
    return false;
  }

  void _switchOpponentTo(int index) {
    if (index < 0 || index >= opponentTeam.length) return;
    currentOpponentIndex = index;

    opponent = BattleOrganism(opponentTeam[currentOpponentIndex]);
    opponentMoves = _getOrganismMoves(opponentTeam[currentOpponentIndex]);

    _addToLog('Opponent sends out ${opponent.organism.baseOrganism.name}!');
    notifyListeners();
  }

  DamageResult calculateDamage(
    BattleOrganism attacker,
    BattleOrganism defender,
    Move move,
  ) {
    if (move.baseDamage <= 0) return const DamageResult(0, 1.0, false);

    // Weather Modifiers
    double weatherMod = currentWeather.getDamageMultiplier(
      move.type.toString().split('.').last,
    );

    // Critical Hit Logic
    bool isCrit = false;
    double critChance = 6.25; // Base 1/16 chance

    // Talisman crit boost
    if (attacker.organism.equippedTalisman?.effect.type ==
        TalismanEffectType.critBoost) {
      critChance += attacker.organism.equippedTalisman!.effect.magnitude;
    }

    // Move-specific crit rate
    if (move.critRate == 1) critChance = 12.5; // 1/8
    if (move.critRate == 2) critChance = 50.0; // 1/2
    if (move.critRate >= 3) critChance = 100.0; // Guaranteed crit

    if (Random().nextDouble() * 100 < critChance) {
      isCrit = true;
    }

    // Battle Armor check
    if (defender.abilities.any((ab) => ab.name == 'Battle Armor')) {
      isCrit = false;
    }

    // Stats
    int atk = (move.category == MoveCategory.special)
        ? attacker.currentPower
        : attacker.currentAttack;
    int def = (move.category == MoveCategory.special)
        ? defender.currentResistance
        : defender.currentDefense;

    // Stat overrides
    if (move.damageStat.isNotEmpty) {
      if (move.damageStat == 'attack')
        atk = attacker.currentAttack;
      else if (move.damageStat == 'power')
        atk = attacker.currentPower;
      else if (move.damageStat == 'defense')
        atk = attacker.currentDefense;
      else if (move.damageStat == 'resistance')
        atk = attacker.currentResistance;
      else if (move.damageStat == 'speed')
        atk = attacker.currentSpeed;
    }

    // Core Damage Formula
    double damageCalc =
        ((2 * attacker.level / 5 + 2) * move.baseDamage * atk / def) / 50 + 2;

    if (isCrit) damageCalc *= 1.5;

    // Random variance (0.85 to 1.0)
    damageCalc *= (0.85 + (Random().nextDouble() * 0.15));

    damageCalc *= weatherMod;

    // Conditionals
    if (move.multiplierCondition.isNotEmpty) {
      double multiplier = 1.0;
      final condition = move.multiplierCondition.toLowerCase();
      if (condition == 'target_poisoned' &&
          defender.statusEffects.any(
            (se) => se.type == StatusEffectType.poison,
          ))
        multiplier = move.conditionalMultiplier;
      else if (condition == 'target_damaged' && defender.tookDamageThisTurn)
        multiplier = move.conditionalMultiplier;
      else if (condition == 'target_statused' &&
          defender.statusEffects.isNotEmpty)
        multiplier = move.conditionalMultiplier;
      damageCalc *= multiplier;
    }

    // Status modifiers
    if (defender.statusEffects.any(
      (se) => se.type == StatusEffectType.vulnerable,
    ))
      damageCalc *= 1.3;
    if (defender.statusEffects.any((se) => se.type == StatusEffectType.marked))
      damageCalc *= 1.2;

    // Type Effectiveness
    double typeMod = 1.0;
    for (final defType in defender.types) {
      typeMod *= TypeChart.getEffectiveness(move.type, defType);
    }
    damageCalc *= typeMod;

    // STAB
    if (attacker.types.contains(move.type)) {
      double stabBonus = 1.5;
      final adaptability = attacker.abilities.firstWhere(
        (ab) => ab.name == 'Adaptability',
        orElse: () => const Ability(name: '', description: ''),
      );
      if (adaptability.name.isNotEmpty) stabBonus = adaptability.magnitude;
      damageCalc *= stabBonus;
    }

    return DamageResult(damageCalc.round(), typeMod, isCrit);
  }
}

class DamageResult {
  final int damage;
  final double typeMultiplier;
  final bool isCrit;
  const DamageResult(this.damage, this.typeMultiplier, this.isCrit);
}
