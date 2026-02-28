// lib/game/battle_manager.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';

import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/game/biome_weather.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/game/ability_helpers.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/game/ai_decision_engine.dart';
import 'package:animal_warfare/game/player_history.dart';

// --- Enums ---
enum BattleState {
  intro, // New state for initialization sequence
  choosingLead, // Player must select their lead animal before battle starts
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

// --- BattleManager: The Core State Machine ---
class BattleManager extends ChangeNotifier with AbilityHelpers {
  final List<CapturedOrganism> playerTeam;
  final int accountLevel;
  int currentPlayerIndex = 0;
  final CapturedOrganism opponentOrganism;
  final bool isTesting;
  final String? biomeName;

  CapturedOrganism get playerOrganism => playerTeam[currentPlayerIndex];

  late BattleOrganism player;
  late BattleOrganism opponent;

  int _getEffectiveSpeed(BattleOrganism org) {
    double speed = org.currentSpeed.toDouble();

    // Tailwind
    final hasTailwind = org.isPlayer
        ? playerTailwindTurns > 0
        : opponentTailwindTurns > 0;
    if (hasTailwind) {
      speed *= 2.0;
    }

    // Ability Speed Modifiers
    for (final ab in org.abilities) {
      if (ab.trigger == AbilityTrigger.onCalculateStat &&
          ab.targetStat == 'speed') {
        if (ab.name == 'Chlorophyll' &&
            currentWeather.weather == Weather.sunny) {
          speed *= ab.magnitude;
        } else if (ab.name == 'Swift Swim' &&
            currentWeather.weather == Weather.rain) {
          speed *= ab.magnitude;
        } else if (ab.name == 'Sand Rush' &&
            currentWeather.weather == Weather.sandstorm) {
          speed *= ab.magnitude;
        } else if (ab.name == 'Slush Rush' &&
            (currentWeather.weather == Weather.snowstorm ||
                currentWeather.weather == Weather.hail)) {
          speed *= ab.magnitude;
        } else if (ab.name == 'Surge Surfer' &&
            currentTerrain.terrain == Terrain.electric) {
          speed *= ab.magnitude;
        }
      }
    }

    int finalSpeed = speed.round();

    // Trick Room: Effectively inverts speed for turn order.
    // However, _getEffectiveSpeed is used for comparison.
    // If Trick Room is active, we can return a "pseudo-speed" that is higher for lower speeds.
    // A common way is (10000 - speed) for speeds under 10000.
    if (trickRoomTurns > 0) {
      finalSpeed = 10000 - finalSpeed;
    }

    return finalSpeed;
  }

  late List<Move> playerMoves;
  late List<Move> opponentMoves;

  // New Battle State
  @override
  WeatherEffect currentWeather = const WeatherEffect(weather: Weather.none);
  @override
  TerrainEffect currentTerrain = const TerrainEffect(terrain: Terrain.none);

  static WeatherEffect? currentWeatherGlobal;
  static TerrainEffect? currentTerrainGlobal;
  @override
  int weatherTurnsLeft = 0;
  @override
  int terrainTurnsLeft = 0;

  BattleState currentState = BattleState.intro;
  bool isCapturing = false;
  int captureShakeCount = 0;
  String battleLog = ''; // Current/Latest message
  AbilityNotification? currentAbilityNotify;

  // LOGGING REFACTOR
  int currentTurn = 1;
  final List<BattleTurn> turnHistory = [];
  BattleResult? _result;
  BattleResult? get result => _result;

  /// NEW: Tracks which animal uniquely landed the final blow for XP awarding.
  String? lastBlowOrganismId;

  // LOOT DROP
  String? _droppedLoot;
  String? get droppedLoot => _droppedLoot;
  final bool isArenaBattle;
  final bool isRogueMode;
  List<CapturedOrganism> opponentTeam = [];
  int currentOpponentIndex = 0;
  int? lastOpponentSwitchTurn;
  bool opponentJustSwitched = false;
  bool playerJustSwitched = false;
  int lastPlayerFaintTurn = -1;
  int lastOpponentFaintTurn = -1;

  bool playerMovedThisTurn = false;
  bool opponentMovedThisTurn = false;
  Move? lastMoveUsedGlobal;
  bool isResumingTurn = false;
  bool ignoreRandom = false; // For deterministic tests

  // Stats Persistence
  final Map<String, BattleStats> battleStats = {};

  final List<String> playerHazards = [];
  final List<String> opponentHazards = [];

  // Screen Turn Counters
  int playerLightScreenTurns = 0;
  int playerReflectTurns = 0;
  int playerAuroraVeilTurns = 0;
  int opponentLightScreenTurns = 0;
  int opponentReflectTurns = 0;
  int opponentAuroraVeilTurns = 0;

  // New Field Effect Counters
  int trickRoomTurns = 0;
  int gravityTurns = 0;
  int playerTailwindTurns = 0;
  int opponentTailwindTurns = 0;
  bool healingWishPending = false;

  final PlayerHistory playerHistory = PlayerHistory();
  TeamArchetype opponentArchetype = TeamArchetype.balanced;

  int _lastGlobalFinalizeTurn = -1;
  final List<String> opponentLastUsedMoves = [];

  BattleStats _getStats(String organismId) {
    return battleStats.putIfAbsent(organismId, () => BattleStats());
  }

  Move? pendingPlayerMove;
  Move? currentTurnOpponentMove;
  Move? lastOpponentAction; // For UI/Testing persistence

  // Suggestion logic
  Timer? _suggestionTimer;
  String? suggestedMoveName;
  bool suggestionProcessed = false;

  bool _isProcessingHits = false;

  /// Completer used to pause U-turn/Volt Switch mid-turn until player selects a new animal.
  Completer<void>? _switchCompleter;

  // Callbacks for UI
  Function(BattleOrganism, Move)? onAttack;
  Function(BattleOrganism, int)? onDamage;
  Function(BattleOrganism, int)? onHeal;
  Function(BattleOrganism, String, int)? onStatChange;
  VoidCallback? onVictory;
  Future<void> Function(BattleOrganism killer, BattleOrganism victim)?
  onOpponentFainted;

  // Audio service for battle sounds and music
  final AudioService _audioService = AudioService.instance;

  void addToLog(String message) {
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
    this.biomeName,
    List<CapturedOrganism>? team,
    List<CapturedOrganism>? opponentTeam,
    this.isArenaBattle = false,
    this.isRogueMode = false,
    this.accountLevel = 100, // Default to max if not provided
    int? initialPlayerIndex,
    this.isTesting = false,
    TeamArchetype? opponentArchetype,
  }) : playerTeam = (team?.isNotEmpty ?? false) ? team! : [initialPlayer],
       opponentTeam = (opponentTeam?.isNotEmpty ?? false)
           ? opponentTeam!
           : [opponentOrganism] {
    if (opponentArchetype != null) {
      this.opponentArchetype = opponentArchetype;
    }
    // Find initial player index
    if (initialPlayerIndex != null && initialPlayerIndex < playerTeam.length) {
      currentPlayerIndex = initialPlayerIndex;
    } else {
      int idx = playerTeam.indexOf(initialPlayer);
      currentPlayerIndex = idx != -1 ? idx : 0;
    }

    // Set up opponent index
    if (isRogueMode) {
      // Find first healthy opponent if the assigned one is fainted
      if (opponentOrganism.currentHealth <= 0) {
        int firstHealthy = this.opponentTeam.indexWhere(
          (org) => org.currentHealth > 0,
        );
        currentOpponentIndex = firstHealthy != -1 ? firstHealthy : 0;
      } else {
        int oppIdx = this.opponentTeam.indexOf(opponentOrganism);
        currentOpponentIndex = oppIdx != -1 ? oppIdx : 0;
      }
    } else {
      int oppIdx = this.opponentTeam.indexOf(opponentOrganism);
      currentOpponentIndex = oppIdx != -1 ? oppIdx : 0;
    }

    player = BattleOrganism(
      playerOrganism,
      isRogueMode: isRogueMode,
      isOpponent: false,
      atLevel: isArenaBattle ? 50 : null,
    );
    player.revealedMoves.addAll(_getStats(playerOrganism.id).revealedMoves);

    opponent = BattleOrganism(
      this.opponentTeam[currentOpponentIndex],
      isRogueMode: isRogueMode,
      isOpponent: true,
      atLevel: isArenaBattle ? 50 : null,
    );
    opponent.revealedMoves.addAll(
      _getStats(this.opponentTeam[currentOpponentIndex].id).revealedMoves,
    );

    // Fix 2: Guard against isRogueMode construction-site mismatch.
    // If this fires, the caller forgot to pass isRogueMode: true, which would
    // cause the health setter to ratio-scale instead of using raw HP values.
    assert(
      player.isRogueMode == isRogueMode,
      '[BattleManager] CRITICAL: player.isRogueMode mismatch! '
      'HP will be scaled incorrectly. Ensure isRogueMode is forwarded correctly.',
    );
    assert(
      opponent.isRogueMode == isRogueMode,
      '[BattleManager] CRITICAL: opponent.isRogueMode mismatch! '
      'HP will be scaled incorrectly. Ensure isRogueMode is forwarded correctly.',
    );

    // Initialize move lists
    playerMoves = _getOrganismMoves(playerOrganism);
    opponentMoves = _getOrganismMoves(this.opponentTeam[currentOpponentIndex]);

    // If Rogue-like mode, trust the opponent's current health/stamina/status.
    // For wild battles/arena, ensure a clean slate.
    if (isRogueMode) {
      opponent.health = opponentOrganism.currentHealth;
      if (opponentOrganism.statusEffects.isNotEmpty) {
        opponent.statusEffects = List.from(opponentOrganism.statusEffects);
      } else {
        opponent.clearStatusEffects();
      }
    } else {
      // Standard wild/arena: ensure full health start.
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
    // Fix 4: Restore all move stamina at the start of every non-rogue battle.
    if (!isRogueMode) {
      for (final member in playerTeam) {
        member.restoreAllStamina();
      }
    }

    // Start battle music
    if (!isTesting) {
      await _audioService.playMusic('audio/battle_default.mp3');
    }

    // If player has NO animals at all, they must fight themselves (Trainer Combat)
    if (playerTeam.isEmpty) {
      final trainer = _createTrainerOrganism();
      playerTeam.add(trainer);
      currentPlayerIndex = 0;
      player = BattleOrganism(
        trainer,
        isRogueMode: isRogueMode,
        isOpponent: false,
      );
      playerMoves = _getOrganismMoves(trainer);
      addToLog('You have no animals! You must defend yourself!');
    } else {
      // Automatic lead: index 0
      currentPlayerIndex = 0;
      final lead = playerTeam[currentPlayerIndex];
      player = BattleOrganism(
        lead,
        isRogueMode: isRogueMode,
        isOpponent: false,
      );
      playerMoves = _getOrganismMoves(lead);
    }

    addToLog('A wild ${opponent.name} appeared! Go, ${player.name}!');

    if (!isTesting) {
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 3000));
    }

    await _initializeBattle(biomeName);

    // Check if opponent is already fainted (Roguelike re-entry case where lead fainted)
    if (opponent.health <= 0) {
      final healthyIndex = opponentTeam.indexWhere(
        (org) => org.currentHealth > 0,
      );
      if (healthyIndex != -1) {
        await _switchOpponentTo(healthyIndex);
        opponentJustSwitched = true;
      }
    }

    // Check if the starting animal is already fainted (Roguelike re-entry case)
    if (player.health <= 0) {
      final healthyIndex = playerTeam.indexWhere(
        (org) => org.currentHealth > 0,
      );
      if (healthyIndex != -1) {
        addToLog('${player.name} is unable to fight! Choose another animal.');
        currentState = BattleState.waitingForPlayerSwitch;
        notifyListeners();
        return;
      }
    }

    // Transition to waiting for input
    currentState = BattleState.waitingForInput;
    _startSuggestionTimer();
    addToLog('What will ${player.name} do?');
    if (!isTesting) notifyListeners();
  }

  /// Called by the UI when the player selects their lead animal before battle starts.
  /// Does NOT trigger entrance abilities (those fire in _initializeBattle).
  void setLeadAnimal(int index) {
    if (index < 0 || index >= playerTeam.length) return;
    // Change state BEFORE notifyListeners to prevent _handleStateTriggers from
    // re-opening the choosingLead dialog
    currentState = BattleState.intro;
    if (index != currentPlayerIndex) {
      currentPlayerIndex = index;
      player = BattleOrganism(
        playerTeam[currentPlayerIndex],
        isRogueMode: isRogueMode,
        isOpponent: false,
      );
      player.revealedMoves.addAll(_getStats(playerOrganism.id).revealedMoves);
      playerMoves = _getOrganismMoves(playerOrganism);
    }
    notifyListeners();
    if (_switchCompleter != null && !_switchCompleter!.isCompleted) {
      _switchCompleter!.complete();
    }
    _startSuggestionTimer();
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
    await _checkEntranceAbility(player, opponent, biomeName);
    await _checkEntranceAbility(opponent, player, biomeName);

    // 2. Speed Check
    // Removed "Opponent is faster" notification as per user request.
  }

  Future<void> _checkEntranceAbility(
    BattleOrganism user,
    BattleOrganism target,
    String? biomeName,
  ) async {
    for (final ability in user.abilities) {
      if (ability.trigger != AbilityTrigger.onEntry) continue;

      bool triggered = false;
      switch (ability.effectType) {
        case AbilityEffectType.weatherChange:
          final Weather targetWeather = _parseWeather(ability.value);
          if (currentWeather.weather != targetWeather) {
            triggered = true;
            await notifyAbilityTrigger(user, ability);
            await setWeatherHelper(ability.value, user);
          }
          break;
        case AbilityEffectType.terrainChange:
          triggered = true;
          await notifyAbilityTrigger(user, ability);
          await setTerrainHelper(ability.value);
          break;
        case AbilityEffectType.statChange:
          triggered = true;
          await notifyAbilityTrigger(user, ability);
          await applyStatChange(
            ability.targetStat == 'attack' ? target : user,
            ability.targetStat,
            ability.magnitude.toInt(),
            source: user,
          );
          notifyListeners();
          if (!isTesting)
            await Future.delayed(const Duration(milliseconds: 3000));
        case AbilityEffectType.statusChange:
          if (ability.name == 'Camouflage Carapace' && biomeName == 'Swamp') {
            triggered = true;
            await notifyAbilityTrigger(user, ability);
            user.addStatusEffect(
              const StatusEffect(type: StatusEffectType.stealth),
            );
            addToLog('${user.organism.name} became hidden in the swamp!');
            notifyListeners();
            if (!isTesting)
              await Future.delayed(const Duration(milliseconds: 3000));
          } else if (ability.name == 'Reef Camouflage' &&
              biomeName == 'Coral Reef') {
            triggered = true;
            await notifyAbilityTrigger(user, ability);
            user.addStatusEffect(
              const StatusEffect(type: StatusEffectType.stealth),
            );
            addToLog('${user.organism.name} became hidden in the coral reef!');
            notifyListeners();
            if (!isTesting)
              await Future.delayed(const Duration(milliseconds: 3000));
          }
          break;
        case AbilityEffectType.none:
          if (ability.name == 'Mimic' || ability.name == 'Mimicry') {
            final team = user == player ? playerTeam : opponentTeam;
            CapturedOrganism? disguiseTarget;
            for (int i = team.length - 1; i >= 0; i--) {
              if (team[i] != user.organism && team[i].currentHealth > 0) {
                disguiseTarget = team[i];
                break;
              }
            }
            if (disguiseTarget != null) {
              triggered = true;
              user.isDisguised = true;
              user.disguisedAs = disguiseTarget;
              // Deliberately skipping _notifyAbilityTrigger and _addToLog to keep the disguise secret!
            }
          }
          break;
        default:
          if (ability.name == 'Cold-blooded') {
            final w = currentWeatherGlobal?.weather ?? Weather.none;
            int stageChange = 0;

            if (w == Weather.sunny) {
              stageChange = 1;
            } else if (w == Weather.rain ||
                w == Weather.heavyRain ||
                w == Weather.snowstorm ||
                w == Weather.hail ||
                w == Weather.thunderstorm) {
              stageChange = -1;
            }

            if (stageChange != 0) {
              triggered = true;
              await notifyAbilityTrigger(user, ability);
              await applyStatChange(user, 'speed', stageChange);
              notifyListeners();
              if (!isTesting)
                await Future.delayed(const Duration(milliseconds: 3000));
            }
          }
          break;
      }
    }
  }

  Future<void> notifyAbilityTrigger(
    BattleOrganism user,
    Ability ability,
  ) async {
    final isPlayer = user == player;
    currentAbilityNotify = AbilityNotification(
      animalName: user.organism.baseOrganism.name,
      abilityName: ability.name,
      isPlayer: isPlayer,
    );

    // Track that the ability has been revealed
    user.isAbilityRevealed = true;
    _getStats(user.organism.id).isAbilityRevealed = true;

    addToLog("${user.organism.baseOrganism.name}'s ${ability.name}!");
    notifyListeners();
    if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));

    currentAbilityNotify = null;
    notifyListeners();
  }

  void _setWeather(Weather w, [int duration = 5]) {
    if (currentWeather.weather == w && weatherTurnsLeft > 0) return;
    currentWeather = WeatherEffect(weather: w, duration: duration);
    currentWeatherGlobal = currentWeather;
    weatherTurnsLeft = duration;
    _appendToLog('\n${currentWeather.description}');
  }

  void _setTerrain(Terrain t, [int duration = 5]) {
    if (currentTerrain.terrain == t && terrainTurnsLeft > 0) return;
    currentTerrain = TerrainEffect(terrain: t, duration: duration);
    currentTerrainGlobal = currentTerrain;
    terrainTurnsLeft = duration;
    _appendToLog('\n${currentTerrain.description}');
  }

  Weather _parseWeather(String value) {
    try {
      return Weather.values.firstWhere(
        (e) =>
            e.toString().split('.').last.toLowerCase() == value.toLowerCase(),
        orElse: () => Weather.none,
      );
    } catch (_) {
      return Weather.none;
    }
  }

  String get _weatherPersistenceMessage {
    switch (currentWeather.weather) {
      case Weather.rain:
        return 'Rain continues to fall.';
      case Weather.heavyRain:
        return 'The downpour persists!';
      case Weather.snowstorm:
        return 'snowstorm keeps falling.';
      case Weather.hail:
        return 'The hail rages on!';
      case Weather.fog:
        return 'The fog lingers.';
      case Weather.sunny:
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

    _stopSuggestionTimer();

    // Fix: Handle multi-turn locks (recharge/charge) immediately so they are cleared
    // even if the animal disobeys or is unable to move later.
    bool wasRecharging = player.mustRecharge;
    bool wasCharging = player.chargingMove != null;

    if (wasRecharging) {
      player.mustRecharge = false;
      // We still need to let the turn happen, but we've cleared the flag.
      // If we return here, the turn is spent loafing/recharging.
    }

    // Disobedience logic
    bool disobeyed = false;
    // Fix: Satisfaction and level disobedience should NOT apply in Rogue-like mode
    if (!isRogueMode) {
      final lvlDiff = playerOrganism.level - accountLevel;
      if (lvlDiff > 0 && !isArenaBattle) {
        // higher level = higher disobedience chance
        final disChance = (lvlDiff * 0.1).clamp(0.0, 0.8);
        if (Random().nextDouble() < disChance) {
          disobeyed = true;
        }
      } else if (playerOrganism.satisfaction < 100) {
        // low satisfaction disobedience
        final disChance = ((100 - playerOrganism.satisfaction) / 200).clamp(
          0.0,
          0.5,
        );
        if (Random().nextDouble() < disChance) {
          disobeyed = true;
        }
      }
    }

    if (disobeyed) {
      addToLog('${player.name} is loafing around and wouldn\'t listen!');

      // If they were charging, the charge is broken
      if (wasCharging) {
        player.chargingMove = null;
        player.semiInvulnerable = null;
        player.isInvulnerable = false;
      }

      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      // End turn or pick random move? Usually in Pokemon it just misses.
      // Let's end the player's action turn.
      currentState = BattleState.opponentTurn;
      notifyListeners();
      await _processOpponentTurn(isCounter: false);
      await _finalizeTurn();
      return;
    }

    // Since we handled mandatory clear above, we need to check if we should skip _executeTurn for recharge
    if (wasRecharging) {
      addToLog('${player.name} must recharge!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      currentState = BattleState.opponentTurn;
      notifyListeners();
      await _processOpponentTurn(isCounter: false);
      await _finalizeTurn();
      return;
    }

    // Check if player disobeyed suggestion
    if (suggestedMoveName != null && move.name != suggestedMoveName) {
      // Small satisfaction penalty for ignoring suggestion
      playerOrganism.satisfaction = max(0, playerOrganism.satisfaction - 3);
      addToLog(
        '${player.name} seems slightly annoyed by the mismatching command.',
      );
    }

    Move activeMove = move;

    // Rollout/Ice Ball Lock
    if (player.rolloutTurnCount > 0 && player.rolloutMove != null) {
      activeMove = player.rolloutMove!;
    } else if (move.name == 'Rollout' || move.name == 'Ice Ball') {
      player.rolloutMove = move;
    }

    // Record player action for AI history
    playerHistory.recordMove(activeMove);

    // Check Stamina
    final currentStamina = playerOrganism.moveStamina[activeMove.name] ?? 0;
    if (currentStamina <= 0) {
      addToLog('${activeMove.name} has no stamina left!');
      notifyListeners();
      return;
    }

    // Choice Lock Check
    if (player.isChoiceLocked &&
        player.lockedMove != null &&
        player.lockedMove!.name != activeMove.name) {
      addToLog('${player.organism.baseOrganism.name} is choice-locked!');
      notifyListeners();
      return;
    }

    currentState = BattleState.playerTurn;
    notifyListeners();

    // 1. Determine priority and order (only if not resuming mid-turn)
    bool playerGoesFirst = true;

    if (!isResumingTurn) {
      // Pre-calculate opponent action
      final int? switchIndex = _shouldOpponentSwitch();
      if (switchIndex != null) {
        // If switching, we set a high-priority dummy move to ensure switch happens first
        // and set the flag to skip their actual move execution
        currentTurnOpponentMove = Move(
          name: 'Switch',
          description: 'Switching...',
          baseDamage: 0,
          accuracy: 100,
          stamina: 0,
          priority: 6,
        );
        _switchOpponentTo(switchIndex);
        opponentJustSwitched = true;
        lastOpponentAction = currentTurnOpponentMove;
        lastOpponentSwitchTurn = currentTurn;
      } else {
        currentTurnOpponentMove = pickOpponentMove();
        lastOpponentAction = currentTurnOpponentMove;
      }

      // Determine who goes first
      int playerPriority = activeMove.priority;
      int opponentPriority = currentTurnOpponentMove!.priority;

      // Gale Wings check
      for (final ab in player.abilities) {
        if (ab.name == 'Gale Wings' &&
            player.health == player.maxHealth &&
            activeMove.type == ElementalType.flying) {
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

      // Prankster Check
      for (final ab in player.abilities) {
        if (ab.name == 'Prankster' &&
            activeMove.category == MoveCategory.status) {
          playerPriority += ab.magnitude.toInt();
        }
      }
      for (final ab in opponent.abilities) {
        if (ab.name == 'Prankster' &&
            currentTurnOpponentMove!.category == MoveCategory.status) {
          opponentPriority += ab.magnitude.toInt();
        }
      }

      // Grassy Glide Priority
      if (currentTerrain.terrain == Terrain.grassy) {
        if (activeMove.name == 'Grassy Glide') playerPriority += 1;
        if (currentTurnOpponentMove!.name == 'Grassy Glide') {
          opponentPriority += 1;
        }
      }

      bool playerQuickClawTriggered = false;
      if (player.organism.equippedTalisman != null &&
          player.organism.equippedTalisman!.effects.any(
            (e) => e.type == TalismanEffectType.quickClaw,
          )) {
        if (Random().nextDouble() < 0.20) playerQuickClawTriggered = true;
      }

      bool opponentQuickClawTriggered = false;
      if (opponent.organism.equippedTalisman != null &&
          opponent.organism.equippedTalisman!.effects.any(
            (e) => e.type == TalismanEffectType.quickClaw,
          )) {
        if (Random().nextDouble() < 0.20) opponentQuickClawTriggered = true;
      }

      _handleTurnStart(player, activeMove);
      _handleTurnStart(opponent, currentTurnOpponentMove);

      if (playerPriority > opponentPriority) {
        playerGoesFirst = true;
      } else if (opponentPriority > playerPriority) {
        playerGoesFirst = false;
      } else {
        if (playerQuickClawTriggered && !opponentQuickClawTriggered) {
          playerGoesFirst = true;
          addToLog(
            '${player.organism.baseOrganism.name} moved faster using its ${player.organism.equippedTalisman!.name}!',
          );
          player.isItemRevealed = true;
          _getStats(player.organism.id).isItemRevealed = true;
        } else if (opponentQuickClawTriggered && !playerQuickClawTriggered) {
          playerGoesFirst = false;
          addToLog(
            '${opponent.organism.baseOrganism.name} moved faster using its ${opponent.organism.equippedTalisman!.name}!',
          );
          opponent.isItemRevealed = true;
          _getStats(opponent.organism.id).isItemRevealed = true;
        } else {
          // Speed Check (same priority)
          if (_getEffectiveSpeed(player) >= _getEffectiveSpeed(opponent)) {
            playerGoesFirst = true;
          } else {
            playerGoesFirst = false;
          }
        }
      }

      // Reset per-turn damage flags for a new complete turn cycle.
      // Fix 1: opponentJustSwitched / playerJustSwitched are NOT reset here.
      // They must survive until _finalizeTurn clears them, otherwise the
      // opponent-turn skip check (lines below) sees a stale false value.
      playerMovedThisTurn = false;
      opponentMovedThisTurn = false;
      player.tookDamageThisTurn = false;
      opponent.tookDamageThisTurn = false;
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
        playerGoesFirst =
            _getEffectiveSpeed(player) >= _getEffectiveSpeed(opponent);
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
            activeMove,
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
            opponentMove: activeMove,
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
            opponentMove: activeMove,
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
            activeMove,
            opponentMove: currentTurnOpponentMove,
          );
        }
        playerMovedThisTurn = true;
      }
      if (_checkBattleEnd()) return;
      if (currentState == BattleState.waitingForPlayerSwitch) return;

      // START FIX: Delay to show new animal before finalizing turn
      if (opponentJustSwitched) {
        if (!isTesting)
          await Future.delayed(const Duration(milliseconds: 2000));
      }
      // END FIX
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
    defender.tookDamageThisTurn = false;
    // 1. Multi-turn logical handling
    bool wasCharging = attacker.chargingMove != null;
    if (wasCharging) {
      move = attacker.chargingMove!;
      attacker.chargingMove = null;
      attacker.semiInvulnerable = null;
      attacker.isInvulnerable = false; // Clear invulnerability when attacking
    }

    // --- NEW: Throat Chop Check ---
    if (attacker.throatChopTurns > 0 && move.isSoundBased) {
      addToLog(
        '${attacker.name} cannot use sound-based moves due to Throat Chop!',
      );
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    // --- NEW: Fake Out First Turn Check ---
    if (move.name == 'Fake Out' && !attacker.isFirstTurnOutOfBall) {
      addToLog('But it failed! (Can only be used on the first turn)');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    // --- NEW: Belch Requirement Check ---
    if (move.effects.any((e) => e.type == MoveEffectType.belch) &&
        !attacker.talismanConsumed) {
      addToLog('But it failed! (Must consume a berry/talisman first)');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    // --- Move Failure Conditions ---

    // Gigaton Hammer: Can't use twice in a row
    if (move.name == 'Gigaton Hammer' &&
        attacker.lastMoveName == 'Gigaton Hammer') {
      addToLog('But it failed! ${attacker.name} can\'t use its hammer again!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    // First Impression: Only works on first turn out
    if (move.name == 'First Impression' && !attacker.isFirstTurnOutOfBall) {
      addToLog('But it failed! ${attacker.name} is no longer impressed.');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    // Focus Punch: Fails if hit
    if (move.name == 'Focus Punch' && attacker.focusPunchFailed) {
      addToLog('${attacker.name} lost its focus and couldn\'t move!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    // Shell Trap: Fails if not triggered
    if (move.name == 'Shell Trap' && !attacker.shellTrapTriggered) {
      addToLog('${attacker.name}\'s shell trap didn\'t go off!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    // Last Resort: Only after using all other moves
    if (move.name == 'Last Resort') {
      final otherKnownMoves = attacker.organism.selectedMoveNames
          .where((m) => m != 'Last Resort')
          .toList();
      bool allOthersUsed =
          otherKnownMoves.isNotEmpty &&
          otherKnownMoves.every((m) => attacker.movesUsedInBattle.contains(m));
      if (!allOthersUsed) {
        addToLog(
          'But it failed! ${attacker.name} is not ready for the last resort.',
        );
        notifyListeners();
        if (!isTesting)
          await Future.delayed(const Duration(milliseconds: 2000));
        return;
      }
    }

    // --- NEW: Move Calling Logic (Metronome, Assist, Copycat) ---
    Move actualMove = move;
    bool isCallingMove = false;

    if (move.effects.any((e) => e.type == MoveEffectType.metronome)) {
      final validMoves = Move.allMoves
          .where((m) => m.name != 'Metronome' && m.name != 'Struggle')
          .toList();
      if (validMoves.isNotEmpty) {
        actualMove = validMoves[Random().nextInt(validMoves.length)];
        addToLog('${attacker.name} used Metronome!');
        isCallingMove = true;
      }
    } else if (move.effects.any((e) => e.type == MoveEffectType.assist)) {
      final partyMoves = <Move>[];
      final team = attacker.isOpponent ? opponentTeam : playerTeam;
      for (final org in team) {
        if (org == attacker.organism) continue;
        partyMoves.addAll(_getOrganismMoves(org));
      }
      if (partyMoves.isNotEmpty) {
        actualMove = partyMoves[Random().nextInt(partyMoves.length)];
        addToLog('${attacker.name} used Assist!');
        isCallingMove = true;
      } else {
        addToLog(
          '${attacker.name} used Assist! But there were no moves to call!',
        );
        return;
      }
    } else if (move.effects.any((e) => e.type == MoveEffectType.copycat)) {
      if (lastMoveUsedGlobal != null &&
          lastMoveUsedGlobal!.name != 'Copycat' &&
          lastMoveUsedGlobal!.name != 'Metronome' &&
          lastMoveUsedGlobal!.name != 'Assist') {
        actualMove = lastMoveUsedGlobal!;
        addToLog('${attacker.name} used Copycat!');
        isCallingMove = true;
      } else {
        addToLog(
          '${attacker.name} used Copycat! But there were no moves to copy!',
        );
        return;
      }
    }

    if (isCallingMove) {
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));
      // Re-evaluate everything with actualMove
      move = actualMove;
    }

    if (move.name == 'Focus Energy') {
      attacker.focusEnergyActive = true;
      addToLog('${attacker.name} is getting pumped!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    if (move.name == 'Laser Focus') {
      attacker.laserFocusTurns = 2; // Active this turn and next
      addToLog('${attacker.name} is concentrating intensely!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    if (move.name == 'Whirlwind' || move.name == 'Roar') {
      if (defender.isPlayer) {
        if (isArenaBattle || isRogueMode) {
          final healthyIndex = playerTeam.indexWhere(
            (org) => org.currentHealth > 0 && org != defender.organism,
          );
          if (healthyIndex != -1) {
            addToLog('${defender.name} was blown away!');
            currentState = BattleState.waitingForPlayerSwitch;
            notifyListeners();
            if (!isTesting)
              await Future.delayed(const Duration(milliseconds: 2000));
            return;
          }
        } else {
          // Wild battle ends
          addToLog('${defender.name} was blown away! The battle ended.');
          _result = BattleResult.fled;
          currentState = BattleState.battleEnd;
          notifyListeners();
          return;
        }
      } else {
        if (isArenaBattle || isRogueMode) {
          final healthyIndex = opponentTeam.indexWhere(
            (org) => org.currentHealth > 0 && org != defender.organism,
          );
          if (healthyIndex != -1) {
            addToLog('${defender.name} was blown away!');
            _switchOpponentTo(healthyIndex);
            opponentJustSwitched = true;
            notifyListeners();
            if (!isTesting)
              await Future.delayed(const Duration(milliseconds: 2000));
            return;
          }
        } else {
          addToLog('${defender.name} was blown away! The battle ended.');
          _result = BattleResult.fled;
          currentState = BattleState.battleEnd;
          notifyListeners();
          return;
        }
      }
      addToLog('But it failed!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    if (move.isMultiTurn && !wasCharging) {
      final chargeEffect = move.effects.firstWhere(
        (e) =>
            e.type == MoveEffectType.charge ||
            e.type == MoveEffectType.semiInvulnerable ||
            e.type == MoveEffectType.meteorBeam ||
            e.type == MoveEffectType.skullBash,
        orElse: () => const MoveEffect(type: MoveEffectType.none),
      );

      if (chargeEffect.type != MoveEffectType.none) {
        // Solar Beam / Blade skip charge in sun
        bool isSolarMove =
            move.name == 'Solar Beam' || move.name == 'Solar Blade';
        bool isSunny = currentWeather.weather == Weather.sunny;
        bool skipCharge = false;

        if (isSolarMove && isSunny) {
          skipCharge = true;
        }

        // Power Herb check
        if (!skipCharge &&
            attacker.organism.equippedTalisman != null &&
            !attacker.talismanConsumed) {
          for (final effect in attacker.organism.equippedTalisman!.effects) {
            if (effect.type == TalismanEffectType.powerHerb) {
              skipCharge = true;
              attacker.talismanConsumed = true;
              attacker.isItemRevealed = true;
              _getStats(attacker.organism.id).isItemRevealed = true;
              addToLog(
                '${attacker.organism.name} used its ${attacker.organism.equippedTalisman!.name} to skip the charge!',
              );
              break;
            }
          }
        }

        if (skipCharge) {
          // Continue to execution
        } else {
          String chargeMessage;
          switch (move.name) {
            case 'Dig':
              chargeMessage =
                  '${attacker.organism.baseOrganism.name} burrowed underearth!';
              break;
            case 'Dive':
              chargeMessage =
                  '${attacker.organism.baseOrganism.name} dove underwater!';
              break;
            case 'Fly':
              chargeMessage =
                  '${attacker.organism.baseOrganism.name} flew up high!';
              break;
            case 'Bounce':
              chargeMessage =
                  '${attacker.organism.baseOrganism.name} bounced into the air!';
              break;
            case 'Solar Beam':
            case 'Solar Blade':
              chargeMessage =
                  '${attacker.organism.baseOrganism.name} absorbed light!';
              break;
            case 'Meteor Beam':
              chargeMessage =
                  '${attacker.organism.baseOrganism.name} is overflowing with space energy!';
              break;
            case 'Skull Bash':
              chargeMessage =
                  '${attacker.organism.baseOrganism.name} tucked in its head!';
              break;
            default:
              chargeMessage =
                  '${attacker.organism.baseOrganism.name} is preparing an attack!';
          }
          addToLog(chargeMessage);

          // Apply first-turn effects (for Meteor Beam/Skull Bash)
          if (chargeEffect.type == MoveEffectType.meteorBeam) {
            await applyStatChange(attacker, 'power', 1);
          } else if (chargeEffect.type == MoveEffectType.skullBash) {
            await applyStatChange(attacker, 'defense', 1);
          }
          attacker.chargingMove = move;
          attacker.chargeStatChanges = chargeEffect.stat;
          if (chargeEffect.type == MoveEffectType.semiInvulnerable) {
            attacker.semiInvulnerable = chargeEffect.stat;
            attacker.isInvulnerable =
                true; // Make user invulnerable during charge
          }
          notifyListeners();
          if (!isTesting)
            await Future.delayed(const Duration(milliseconds: 3000));
          return; // Turn ends here for charging
        }
      }
    }

    attacker.lastMove = move;

    // recharging move stamina
    if (attacker.organism.moveStamina.containsKey(move.name)) {
      attacker.organism.moveStamina[move.name] =
          (attacker.organism.moveStamina[move.name]! - 1).clamp(
            0,
            move.stamina,
          );
    }

    if (move.customUsageText != null && move.customUsageText!.isNotEmpty) {
      addToLog(move.customUsageText!);
    } else {
      if (move.name != 'Switch') {
        addToLog('${attacker.name} used ${move.name}!');
      }
    }

    // Wait 1 second before playing the sound effect as requested
    if (!isTesting) await Future.delayed(const Duration(seconds: 1));

    // Play move sound effect
    if (!isTesting) {
      String soundPath =
          move.soundEffect ??
          _audioService.getDefaultSoundEffect(
            move.category.toString().split('.').last,
          );
      await _audioService.playSound(soundPath);
    }

    // Switch battle music if move has custom music
    if (move.battleMusic != null && move.battleMusic!.isNotEmpty) {
      await _audioService.playMusic(move.battleMusic!);
    }

    notifyListeners();
    // Trigger attack animation
    onAttack?.call(attacker, move);

    // Track revealed move
    final attackerStats = _getStats(attacker.organism.id);
    attackerStats.revealedMoves.add(move.name);
    attacker.revealedMoves.add(move.name);
    attacker.movesUsedInBattle.add(move.name);

    if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));

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

    // Guaranteed hit checks
    bool targetIsMarked = defender.statusEffects.any(
      (se) => se.type == StatusEffectType.marked,
    );
    bool hasNoGuard =
        attacker.abilities.any((ab) => ab.name == 'No Guard') ||
        defender.abilities.any((ab) => ab.name == 'No Guard');

    if (targetIsMarked ||
        hasNoGuard ||
        move.name == 'Kowtow Cleave' ||
        move.name == 'Smart Strike' ||
        defender.glaiveRushVulnerable) {
      accuracy = 100;
    } else {
      if (attacker.statusEffect.type == StatusEffectType.blind) {
        accuracy = (accuracy * 0.75)
            .round(); // Reduce accuracy by 25% if blinded
      }

      // Weather-based accuracy modifier
      accuracy = (accuracy * currentWeather.accuracyModifier).round();

      // Wide Lens / Zoom Lens accuracy boost
      if (attacker.abilities.any(
        (ab) => ab.name == 'Compound Eyes' || ab.name == 'Compoundeyes',
      )) {
        accuracy = (accuracy * 1.3).round();
      }

      if (attacker.organism.equippedTalisman != null &&
          !attacker.talismanConsumed) {
        for (final effect in attacker.organism.equippedTalisman!.effects) {
          if (effect.type == TalismanEffectType.wideLens) {
            accuracy = (accuracy * effect.magnitude).round();
          } else if (effect.type == TalismanEffectType.zoomLens &&
              ((attacker == player && opponentMovedThisTurn) ||
                  (attacker == opponent && playerMovedThisTurn))) {
            // Zoom lens only helps when moving second
            accuracy = (accuracy * effect.magnitude).round();
          }
        }
      }

      // Evasion stage modifier
      if (defender.evasionStage != 0 && move.name != 'Sacred Sword') {
        double evasionMultiplier = 1.0;
        // Standard Pokemon evasion formula: 3/(3+stage) for positive, (3-stage)/3 for negative
        if (defender.evasionStage > 0) {
          evasionMultiplier = 3.0 / (3 + defender.evasionStage);
        } else {
          evasionMultiplier = (3 - defender.evasionStage) / 3.0;
        }
        accuracy = (accuracy * evasionMultiplier).round();
      }

      // Stealth evasion (50% chance of getting hit over opponents actual accuracy)
      if (defender.statusEffects.any(
        (se) => se.type == StatusEffectType.stealth,
      )) {
        // Echolocation ignores stealth evasion
        bool attackerHasEcholocation = attacker.abilities.any(
          (ab) => ab.name == 'Echolocation',
        );
        if (!attackerHasEcholocation) {
          accuracy = (accuracy * 0.5).round();
        }
      }
    }

    // Rollout/Ice Ball accuracy check: Accuracy resets if it misses
    if (move.name == 'Rollout' || move.name == 'Ice Ball') {
      if (Random().nextInt(100) >= accuracy) {
        addToLog('${attacker.name}\'s attack missed!');
        attacker.rolloutTurnCount = 0;
        notifyListeners();
        if (!isTesting)
          await Future.delayed(const Duration(milliseconds: 3000));
        return;
      }
    } else if (Random().nextInt(100) >= accuracy && !ignoreRandom) {
      addToLog('...but it missed!');
      if (move.name == 'High Jump Kick') {
        final recoilDamage = (attacker.maxHealth / 2).round();
        attacker.health -= recoilDamage;
        addToLog('${attacker.name} kept going and crashed!');
        _checkBattleEnd();
      }
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
      return;
    }

    bool isSelfOrFieldMove =
        move.category == MoveCategory.status &&
        move.baseDamage == 0 &&
        move.effects.every(
          (e) =>
              e.target != 'opponent' ||
              e.type == MoveEffectType.setHazard ||
              e.type == MoveEffectType.weather ||
              e.type == MoveEffectType.terrain ||
              e.type == MoveEffectType.trickRoom ||
              e.type == MoveEffectType.tailwind ||
              e.type == MoveEffectType.setScreen,
        );

    // 2. Protection and Invulnerability Checks
    if (defender.isInvulnerable && !isSelfOrFieldMove) {
      bool bypassInvulnerability = false;
      if (defender.semiInvulnerable == 'underground' &&
          (move.name == 'Earthquake' || move.name == 'Magnitude')) {
        bypassInvulnerability = true;
      } else if (defender.semiInvulnerable == 'underwater' &&
          (move.name == 'Surf' || move.name == 'Whirlpool')) {
        bypassInvulnerability = true;
      } else if (defender.semiInvulnerable == 'airborne' &&
          (move.name == 'Hurricane' ||
              move.name == 'Thunder' ||
              move.name == 'Sky Uppercut' ||
              move.name == 'Smack Down' ||
              move.name == 'Feline Reflexes')) {
        bypassInvulnerability = true;
      }

      if (!bypassInvulnerability) {
        addToLog('${defender.organism.baseOrganism.name} is out of reach!');
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 3000));
        }
        return;
      } else {
        addToLog('It hit ${defender.organism.baseOrganism.name} while hidden!');
      }
    }

    if (defender.isProtected && !isSelfOrFieldMove) {
      // Unseen Fist bypasses Protect for contact moves
      bool attackerHasUnseenFist = attacker.abilities.any(
        (ab) => ab.name == 'Unseen Fist',
      );

      if (!(move.isContact && attackerHasUnseenFist) &&
          move.name != 'Feint' &&
          move.name != 'Mighty Cleave' &&
          move.name != 'Snipe Shot') {
        // Detect moves that penetrate Protect (Feint, etc.) - bypassing for now
        // But No Guard allows hitting through Protect? In some gens yes, some no.
        // Gen 4-5 yes, Gen 6+ no (except for dynamic punch glitch?).
        // Standard rule: No Guard allows hitting through Fly/Dig, but NOT Protect (except in Gen 4).
        // I will assume standard Gen 7+ behavior: Protect blocks No Guard.

        addToLog('${defender.organism.baseOrganism.name} protected itself!');
        // Track revealed move
        final attackerStats = _getStats(attacker.organism.id);
        attackerStats.revealedMoves.add(move.name);
        attacker.revealedMoves.add(move.name);

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
        if (move.name == 'Rollout' || move.name == 'Ice Ball') {
          attacker.rolloutTurnCount = 0;
        }
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 3000));
        }
        return;
      }
    }

    // Flag-based fail check
    if (move.failIfTargetNotAttacking) {
      if (opponentMove == null || opponentMove.baseDamage == 0) {
        addToLog('...but it failed!');
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 3000));
        }
        return;
      }
    }

    // Note: If we added moves that target a specific defense (like Psyshock),
    // we would add an override for effectiveDefenderDef here.

    // Multi-Hit Loop
    int hits = 1;
    if (move.maxHits > 1) {
      if (ignoreRandom) {
        hits = move.minHits;
      } else {
        hits = move.minHits + Random().nextInt(move.maxHits - move.minHits + 1);
      }
    }

    // Parental Bond Check
    bool hasParentalBond = attacker.abilities.any(
      (ab) => ab.name == 'Parental Bond',
    );
    if (hasParentalBond && hits == 1 && move.baseDamage > 0) {
      hits = 2;
    }

    for (int i = 0; i < hits; i++) {
      if (defender.health <= 0) break; // Stop if opponent fainted

      // Play sound effect for each hit after the first (first already played before loop)
      if (i > 0) {
        if (attacker.health <= 0) {
          break; // Stop if attacker fainted (e.g. from previous recoil)
        }
        String soundPath =
            move.soundEffect ??
            _audioService.getDefaultSoundEffect(
              move.category.toString().split('.').last,
            );
        await _audioService.playSound(soundPath);
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 300));
        } // Short delay between hits
      }

      // 2. Damage Calculation
      if (move.baseDamage > 0) {
        final damageResult = calculateDamage(attacker, defender, move);
        double damageCalc = damageResult.damage.toDouble();
        bool isCrit = damageResult.isCrit;
        double typeMod = damageResult.typeMultiplier;

        // Parental Bond 2nd hit damage reduction
        if (hasParentalBond && i == 1) {
          damageCalc *= 0.25;
        }

        int finalDamage = damageCalc.round();

        // Focus Sash (One-Hit Save)
        if (defender.organism.equippedTalisman != null &&
            defender.health == defender.maxHealth &&
            finalDamage >= defender.health &&
            !defender.focusSashUsed) {
          for (final effect in defender.organism.equippedTalisman!.effects) {
            if (effect.type == TalismanEffectType.oneHitSave) {
              finalDamage = defender.health - 1;
              defender.focusSashUsed = true;
              defender.focusSashUsed = true;
              defender.isItemRevealed = true;
              _getStats(defender.organism.id).isItemRevealed = true;
              addToLog(
                '${defender.organism.name} hung on using its ${defender.organism.equippedTalisman!.name}!',
              );
            }
          }
        }

        // Wait for attack animation and sound to register before showing HP decrease
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 100));
        }

        final int effectiveDamage = finalDamage.clamp(0, defender.health);
        final int oldHealth = defender.health;
        bool substituteTookDamage = false;

        // Store damage for Counter/Mirror Coat
        if (move.category == MoveCategory.physical) {
          defender.lastPhysicalDamageTaken = effectiveDamage;
          defender.lastSpecialDamageTaken = 0;
        } else if (move.category == MoveCategory.special) {
          defender.lastSpecialDamageTaken = effectiveDamage;
          defender.lastPhysicalDamageTaken = 0;
        }

        if (move.name == 'Brick Break' || move.name == 'Psychic Fangs') {
          if (defender.isPlayer) {
            if (playerReflectTurns > 0 ||
                playerLightScreenTurns > 0 ||
                playerAuroraVeilTurns > 0) {
              playerReflectTurns = 0;
              playerLightScreenTurns = 0;
              playerAuroraVeilTurns = 0;
              addToLog('${attacker.name} shattered the team\'s protection!');
              notifyListeners();
              if (!isTesting) {
                await Future.delayed(const Duration(milliseconds: 1000));
              }
            }
          } else {
            if (opponentReflectTurns > 0 ||
                opponentLightScreenTurns > 0 ||
                opponentAuroraVeilTurns > 0) {
              opponentReflectTurns = 0;
              opponentLightScreenTurns = 0;
              opponentAuroraVeilTurns = 0;
              addToLog(
                '${attacker.name} shattered the opposing team\'s protection!',
              );
              notifyListeners();
              if (!isTesting) {
                await Future.delayed(const Duration(milliseconds: 1000));
              }
            }
          }
        }

        if (defender.substituteHealth > 0) {
          final int subDamage = finalDamage.clamp(0, defender.substituteHealth);
          defender.substituteHealth -= subDamage;
          substituteTookDamage = true;
          addToLog('The substitute took damage for ${defender.name}!');
          if (defender.substituteHealth <= 0) {
            defender.substituteHealth = 0;
            addToLog('${defender.name}\'s substitute broke!');
          }
        } else {
          // False Swipe check
          bool isFalseSwipe = move.effects.any(
            (e) => e.type == MoveEffectType.falseSwipe,
          );
          int damageToApply = effectiveDamage;
          if (isFalseSwipe && damageToApply >= defender.health) {
            damageToApply = defender.health - 1;
            if (damageToApply < 0) damageToApply = 0;
          }

          defender.health -= damageToApply;
          defender.health = defender.health.clamp(0, defender.maxHealth);
          if (effectiveDamage > 0) {
            onDamage?.call(defender, effectiveDamage);
            if (defender.health <= 0 && attacker.isPlayer) {
              lastBlowOrganismId = attacker.organism.id;
            }
          }
        }

        // Focus Punch / Shell Trap Check
        if (effectiveDamage > 0 || substituteTookDamage) {
          defender.focusPunchFailed = true;
          if (move.category == MoveCategory.physical) {
            defender.shellTrapTriggered = true;
          }
        }

        // Faint handlers: Moxie, Beast Boost, Aftermath
        if (defender.health <= 0) {
          // Moxie / Chilling Neigh
          if (attacker.abilities.any(
                (ab) => ab.name == 'Moxie' || ab.name == 'Chilling Neigh',
              ) &&
              attacker.health > 0) {
            await notifyAbilityTrigger(
              attacker,
              attacker.abilities.firstWhere(
                (a) => a.name == 'Moxie' || a.name == 'Chilling Neigh',
              ),
            );
            await applyStatChange(attacker, 'attack', 1);
          }
          // Beast Boost
          if (attacker.abilities.any((ab) => ab.name == 'Beast Boost') &&
              attacker.health > 0) {
            final stats = {
              'attack': attacker.currentAttack,
              'defense': attacker.currentDefense,
              'power': attacker.currentPower,
              'resistance': attacker.currentResistance,
              'speed': attacker.currentSpeed,
            };
            final maxStat = stats.entries
                .reduce((a, b) => a.value > b.value ? a : b)
                .key;
            await notifyAbilityTrigger(
              attacker,
              attacker.abilities.firstWhere((a) => a.name == 'Beast Boost'),
            );
            await applyStatChange(attacker, maxStat, 1);
          }
          // Aftermath
          if (move.isContact &&
              defender.substituteHealth <= 0 &&
              defender.abilities.any((ab) => ab.name == 'Aftermath') &&
              !attacker.abilities.any((ab) => ab.name == 'Damp')) {
            final damage = (attacker.maxHealth * 0.25).round();
            if (damage > 0 && attacker.health > 0) {
              attacker.health = (attacker.health - damage).clamp(
                0,
                attacker.maxHealth,
              );
              await notifyAbilityTrigger(
                defender,
                defender.abilities.firstWhere((a) => a.name == 'Aftermath'),
              );
              addToLog(
                '${attacker.organism.baseOrganism.name} was hurt by Aftermath!',
              );
              notifyListeners();
              if (!isTesting) {
                await Future.delayed(const Duration(milliseconds: 1500));
              }
            }
          }
        }

        attacker.totalDamageDealt += effectiveDamage;
        defender.totalDamageTaken += effectiveDamage;

        // Sync to persistent stats
        final attackerStats = _getStats(attacker.organism.id);
        final defenderStats = _getStats(defender.organism.id);
        attackerStats.totalDamageDealt += effectiveDamage;
        defenderStats.totalDamageTaken += effectiveDamage;

        defender.tookDamageThisTurn = true;

        // Break Disguise (Mimic/Illusion)
        if (defender.isDisguised && effectiveDamage > 0) {
          defender.isDisguised = false;
          defender.disguisedAs = null;
          defender.isAbilityRevealed = true;
          _getStats(defender.organism.id).isAbilityRevealed = true;
          addToLog(
            '${defender.organism.baseOrganism.name}\'s illusion wore off!',
          );
        }

        // Knock Off side effect
        if (move.name == 'Knock Off' &&
            effectiveDamage > 0 &&
            defender.organism.equippedTalisman != null &&
            !defender.talismanConsumed) {
          defender.talismanConsumed = true;
          defender.isItemRevealed = true;
          _getStats(defender.organism.id).isItemRevealed = true;
          addToLog(
            '${attacker.organism.name} knocked off ${defender.organism.name}\'s ${defender.organism.equippedTalisman!.name}!',
          );
        }

        // Air Balloon Pop
        if (effectiveDamage > 0 &&
            !substituteTookDamage &&
            defender.organism.equippedTalisman != null &&
            !defender.talismanConsumed &&
            defender.organism.equippedTalisman!.effects.any(
              (e) => e.type == TalismanEffectType.airBalloon,
            )) {
          defender.talismanConsumed = true;
          defender.isItemRevealed = true;
          _getStats(defender.organism.id).isItemRevealed = true;
          addToLog(
            '${defender.organism.baseOrganism.name}\'s ${defender.organism.equippedTalisman!.name} popped!',
          );
          notifyListeners();
          if (!isTesting) {
            await Future.delayed(const Duration(milliseconds: 1500));
          }
        }

        // Notify UI to update HP bars after HP has changed
        notifyListeners();

        if (hits > 1) {
          addToLog('Hit ${i + 1}!');
        }
        final double dmgPct = (effectiveDamage / defender.maxHealth * 100);
        addToLog(
          '${defender.organism.name} took $effectiveDamage damage (${dmgPct.toStringAsFixed(1)}%)!',
        );

        if (move.drainPercent > 0 &&
            effectiveDamage > 0 &&
            attacker.health < attacker.maxHealth) {
          final healAmount = (effectiveDamage * move.drainPercent).round();
          attacker.health = (attacker.health + healAmount).clamp(
            0,
            attacker.maxHealth,
          );
          onHeal?.call(attacker, healAmount);

          // Play heal sound effect
          await _audioService.playSound('audio/effects/heal.mp3');

          final double drainPercent = (healAmount / attacker.maxHealth * 100);
          addToLog(
            '${attacker.organism.baseOrganism.name} drained $healAmount health (${drainPercent.toStringAsFixed(1)}%)!',
          );
        }
        if (move.recoilPercent > 0 && effectiveDamage > 0) {
          final recoilDamage = (finalDamage * move.recoilPercent).round();
          attacker.health = (attacker.health - recoilDamage).clamp(
            0,
            attacker.maxHealth,
          );
          final double recoilPercent =
              (recoilDamage / attacker.maxHealth * 100);
          addToLog(
            '${attacker.organism.baseOrganism.name} took $recoilDamage recoil damage (${recoilPercent.toStringAsFixed(1)}%)!',
          );
        }

        // Track damage for lifesteal
        attacker.damageDealtThisTurn += effectiveDamage;

        // Shell Bell: heal immediately after dealing damage (not end of turn)
        if (effectiveDamage > 0 &&
            attacker.organism.equippedTalisman != null &&
            !attacker.talismanConsumed &&
            attacker.health < attacker.maxHealth) {
          for (final effect in attacker.organism.equippedTalisman!.effects) {
            if (effect.type == TalismanEffectType.lifesteal) {
              final shellHeal = (effectiveDamage * effect.magnitude).round();
              if (shellHeal > 0) {
                attacker.health = (attacker.health + shellHeal).clamp(
                  0,
                  attacker.maxHealth,
                );
                attacker.isItemRevealed = true;
                _getStats(attacker.organism.id).isItemRevealed = true;
                addToLog(
                  '${attacker.organism.name} restored $shellHeal HP with ${attacker.organism.equippedTalisman!.name}!',
                );
                await _audioService.playSound('audio/effects/heal.mp3');
                notifyListeners();
                if (!isTesting) {
                  await Future.delayed(const Duration(milliseconds: 1500));
                }
              }
            }
          }
        }

        // Berry: Enigma Berry (heal on super-effective hit taken)
        if (effectiveDamage > 0 &&
            typeMod > 1.0 &&
            defender.organism.equippedTalisman != null &&
            !defender.talismanConsumed &&
            defender.health > 0 &&
            defender.health < defender.maxHealth) {
          for (final effect in defender.organism.equippedTalisman!.effects) {
            if (effect.type == TalismanEffectType.berryEnigma) {
              final berryHeal = (defender.maxHealth * effect.magnitude).round();
              defender.health = (defender.health + berryHeal).clamp(
                0,
                defender.maxHealth,
              );
              defender.talismanConsumed = true;
              defender.isItemRevealed = true;
              _getStats(defender.organism.id).isItemRevealed = true;
              addToLog(
                '${defender.organism.name} ate its ${defender.organism.equippedTalisman!.name} and recovered $berryHeal HP!',
              );
              await _audioService.playSound('audio/effects/heal.mp3');
              notifyListeners();
              if (!isTesting) {
                await Future.delayed(const Duration(milliseconds: 1500));
              }
            }
          }
        }

        // Berry: Jaboca/Rowap Berry (damage attacker when hit)
        if (effectiveDamage > 0 &&
            defender.organism.equippedTalisman != null &&
            !defender.talismanConsumed &&
            attacker.health > 0) {
          for (final effect in defender.organism.equippedTalisman!.effects) {
            if (effect.type == TalismanEffectType.berryJaboca) {
              final isPhysical = move.category == MoveCategory.physical;
              final targetsPhysical = effect.category == 'physical';
              if (isPhysical == targetsPhysical) {
                final jabocaDmg = (attacker.maxHealth * effect.magnitude)
                    .round();
                attacker.health = (attacker.health - jabocaDmg).clamp(
                  0,
                  attacker.maxHealth,
                );
                defender.talismanConsumed = true;
                defender.isItemRevealed = true;
                _getStats(defender.organism.id).isItemRevealed = true;
                addToLog(
                  '${defender.organism.name} ate its ${defender.organism.equippedTalisman!.name}! ${attacker.organism.name} took $jabocaDmg damage!',
                );
                notifyListeners();
                if (!isTesting) {
                  await Future.delayed(const Duration(milliseconds: 1500));
                }
              }
            }
          }
        }

        // Berry Heal (Sitrus/Oran) triggered after taking damage
        await _checkAndTriggerHealBerry(defender);

        // Berry Stat-boost triggered after taking damage (Salac/Petaya/Liechi/Lansat)
        await _checkAndTriggerStatBerry(defender);

        // Talisman recoil damage (Life Orb)
        if (attacker.organism.equippedTalisman != null) {
          for (final effect in attacker.organism.equippedTalisman!.effects) {
            if (effect.type == TalismanEffectType.recoilDamage &&
                effectiveDamage > 0) {
              final recoilDamage = (attacker.maxHealth * effect.magnitude)
                  .round();
              attacker.health = (attacker.health - recoilDamage).clamp(
                0,
                attacker.maxHealth,
              );
              final double recoilPercent =
                  (recoilDamage / attacker.maxHealth * 100);
              attacker.isItemRevealed = true;
              _getStats(attacker.organism.id).isItemRevealed = true;
              addToLog(
                '${attacker.organism.name} is hurt by its ${attacker.organism.equippedTalisman!.name}! (${recoilPercent.toStringAsFixed(1)}%)',
              );
            }
          }
        }

        // Check if attacker died from Life Orb
        if (attacker.health <= 0) break;

        // Rocky Helmet damage (contact moves only)
        if (move.isContact &&
            defender.substituteHealth <= 0 &&
            defender.organism.equippedTalisman != null) {
          for (final effect in defender.organism.equippedTalisman!.effects) {
            if (effect.type == TalismanEffectType.contactDamage) {
              final contactDamage = (attacker.maxHealth * effect.magnitude)
                  .round();
              attacker.health = (attacker.health - contactDamage).clamp(
                0,
                attacker.maxHealth,
              );
              defender.isItemRevealed = true;
              _getStats(defender.organism.id).isItemRevealed = true;
              addToLog(
                '${attacker.organism.name} was hurt by ${defender.organism.equippedTalisman!.name}! ($contactDamage damage)',
              );
            }
          }
        }

        // Check if attacker died from Rocky Helmet
        if (attacker.health <= 0) break;

        // --- Ability Triggers: onDamageTaken ---
        for (final ab in defender.abilities) {
          if (ab.trigger == AbilityTrigger.onDamageTaken) {
            bool conditionMet = true;
            for (final cond in ab.conditions) {
              if (cond == 'crit' && !isCrit) conditionMet = false;
              if (cond == 'hp_below_50' &&
                  (defender.health / defender.maxHealth >= 0.5 ||
                      oldHealth / defender.maxHealth < 0.5)) {
                conditionMet = false;
              }
              if (cond == 'contact' && !move.isContact) conditionMet = false;
            }

            if (conditionMet) {
              if (ab.effectType == AbilityEffectType.statChange) {
                await notifyAbilityTrigger(defender, ab);
                await applyStatChange(
                  defender,
                  ab.targetStat,
                  ab.magnitude.toInt(),
                );
              } else if (ab.effectType == AbilityEffectType.typeChange) {
                await notifyAbilityTrigger(defender, ab);
                defender.battleTypes = [move.type];
                addToLog(
                  '${defender.organism.baseOrganism.name} changed its type to ${move.type.toString().split('.').last}!',
                );
                notifyListeners();
                if (!isTesting)
                  await Future.delayed(const Duration(milliseconds: 3000));
              } else if (ab.effectType == AbilityEffectType.statusChange) {
                final statusType = parseStatusType(ab.value);
                if (statusType != null) {
                  final success = await applyStatusEffect(
                    attacker,
                    statusType,
                    chance: (ab.chance * 100).round(),
                    duration: null,
                  );
                  if (success) {
                    await notifyAbilityTrigger(defender, ab);
                  }
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
                ab.effectType == AbilityEffectType.statusChange) {
              final statusType = parseStatusType(ab.value);
              if (statusType != null) {
                final success = await applyStatusEffect(
                  defender,
                  statusType,
                  chance: (ab.chance * 100).round(),
                  duration: null,
                );
                if (success) {
                  await notifyAbilityTrigger(attacker, ab);
                }
              }
            }
          }
        }

        if (typeMod > 1.0) addToLog('It\'s super effective!');
        if (typeMod < 1.0 && typeMod > 0) {
          addToLog('It\'s not very effective...');
        }
        if (typeMod == 0) addToLog('It had no effect!');
        if (isCrit) addToLog('A critical hit!');

        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 3000));
        }
      }
    }
    if (attacker.health > 0 && defender.health >= 0) {
      await _applyMoveEffect(attacker, defender, move.effects, move);

      // Apply Choice Lock if applicable
      if (attacker.organism.equippedTalisman != null &&
          !attacker.isChoiceLocked) {
        for (final effect in attacker.organism.equippedTalisman!.effects) {
          if (effect.type == TalismanEffectType.choiceLock) {
            attacker.isChoiceLocked = true;
            attacker.lockedMove = move;
            // attacker.isItemRevealed = true; // Maybe not reveal immediately on lock, but on "move blocked"?
            // For now, let's reveal it if they are locked, so the player knows why.
            attacker.isItemRevealed = true;
          }
        }
      }
    }

    // Stealth removal (attacker)
    // Attacking reveals the attacker (unless it's a status move)
    bool attackerHadStealth = attacker.statusEffects.any(
      (se) => se.type == StatusEffectType.stealth,
    );
    if (attackerHadStealth && move.category != MoveCategory.status) {
      attacker.statusEffects = attacker.statusEffects
          .where((se) => se.type != StatusEffectType.stealth)
          .toList();
      addToLog('${attacker.organism.baseOrganism.name} was revealed!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
    }

    // Stealth removal (defender)
    // Taking damage from an attack reveals the defender
    bool defenderHadStealth = defender.statusEffects.any(
      (se) => se.type == StatusEffectType.stealth,
    );
    if (defenderHadStealth && defender.tookDamageThisTurn) {
      defender.statusEffects = defender.statusEffects
          .where((se) => se.type != StatusEffectType.stealth)
          .toList();
      addToLog('${defender.organism.baseOrganism.name} was revealed!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
    }

    attacker.isFirstTurnOutOfBall = false;
    lastMoveUsedGlobal = move;
    attacker.movesUsedInBattle.add(move.name);

    // Scale Shot Stat Changes
    if (move.name == 'Scale Shot' && defender.tookDamageThisTurn) {
      await applyStatChange(attacker, 'defense', -1);
      await applyStatChange(attacker, 'speed', 1);
    }

    // Thrash/Outrage/Petal Dance Lock
    if ((move.name == 'Thrash' ||
            move.name == 'Outrage' ||
            move.name == 'Petal Dance') &&
        defender.tookDamageThisTurn) {
      if (attacker.thrashTurnCount == 0) {
        attacker.thrashTurnCount = 2 + Random().nextInt(2); // 2-3 turns
        attacker.thrashMove = move;
      }
      attacker.thrashTurnCount--;
      if (attacker.thrashTurnCount == 0) {
        await applyStatusEffect(attacker, StatusEffectType.confusion);
        attacker.thrashMove = null;
      }
    }
  }

  Future<bool> _canMove(BattleOrganism org) async {
    // If blocked, ensure multi-turn states are cleared so user doesn't get stuck
    final bool canNormallyMove = await _canMoveLogic(org);
    if (!canNormallyMove) {
      org.chargingMove = null;
      org.semiInvulnerable = null;
      org.isInvulnerable = false;
      org.mustRecharge = false;
    }
    return canNormallyMove;
  }

  Future<bool> _canMoveLogic(BattleOrganism org) async {
    if (org.mustRecharge) {
      addToLog('${org.organism.baseOrganism.name} must recharge!');
      org.mustRecharge = false; // Recharge turn is used now
      org.rolloutTurnCount = 0;
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
      return false;
    }
    if (org.statusEffect.type == StatusEffectType.sleep) {
      if (org.statusEffect.duration <= 0) {
        addToLog('${org.organism.baseOrganism.name} woke up!');
        org.clearStatusEffects(); // Clear all statuses, or just sleep? For now, clear all.
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 3000));
        }
        return true;
      }

      // Status Duration Decay
      int decay = 1;
      final wakeUpAbility = org.abilities.firstWhere(
        (ab) => ab.effectType == AbilityEffectType.wakeUpFaster,
        orElse: () => const Ability(name: '', description: ''),
      );
      if (wakeUpAbility.name.isNotEmpty) {
        await notifyAbilityTrigger(org, wakeUpAbility);
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

      addToLog('${org.organism.baseOrganism.name} is fast asleep.');
      org.rolloutTurnCount = 0;
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
      return false;
    }
    if (org.statusEffect.type == StatusEffectType.stun) {
      addToLog('${org.organism.baseOrganism.name} is stunned and cannot move!');
      org.rolloutTurnCount = 0;
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
      // Remove only the stun status
      org.statusEffects = org.statusEffects
          .where((se) => se.type != StatusEffectType.stun)
          .toList();
      //addToLog('${org.organism.baseOrganism.name} recovered from Stun!');
      //notifyListeners();
      //if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
      return false;
    }
    if (org.statusEffect.type == StatusEffectType.confusion) {
      addToLog('${org.organism.baseOrganism.name} is confused!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
      if (Random().nextDouble() < 0.33) {
        addToLog('It hurt itself in its confusion!');
        final selfDamage = (org.maxHealth * 0.15).round();
        org.health -= selfDamage;
        org.health = org.health.clamp(0, org.maxHealth);
        org.rolloutTurnCount = 0;
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 3000));
        }
        return false;
      }
    }
    if (org.statusEffect.type == StatusEffectType.freeze) {
      // 20% chance to thaw
      if (Random().nextDouble() < 0.2) {
        addToLog('${org.organism.baseOrganism.name} thawed out!');
        org.clearStatusEffects(); // Clear all statuses, or just freeze? For now, clear all.
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 3000));
        }
        return true;
      }
      addToLog('${org.organism.baseOrganism.name} is frozen solid!');
      org.rolloutTurnCount = 0;
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
      return false;
    }
    if (org.statusEffect.type == StatusEffectType.paralysis) {
      if (Random().nextDouble() < 0.25) {
        addToLog(
          '${org.organism.baseOrganism.name} is paralyzed! It can\'t move!',
        );
        org.rolloutTurnCount = 0;
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 3000));
        }
        return false;
      }
    }
    return true;
  }

  Future<void> _processOpponentTurn({required bool isCounter}) async {
    // Removed "Opponent's turn!" text as per user request.

    // AI: Select a move from its specific list using scoring
    Move opponentMove = pickOpponentMove();
    lastOpponentAction = opponentMove;

    if (await _canMove(opponent)) {
      await _executeTurn(opponent, player, opponentMove);
    }
  }

  // --- Core Effect Logic ---

  Future<bool> applyStatusEffect(
    BattleOrganism target,
    StatusEffectType type, {
    int chance = 100,
    int? duration,
  }) async {
    if (Random().nextInt(100) >= chance) return false;
    if (target.health <= 0) return false;
    if (type == StatusEffectType.none) return false;

    // Substitute blocks most status effects
    if (target.substituteHealth > 0 &&
        type != StatusEffectType.blind &&
        type != StatusEffectType.marked) {
      return false;
    }

    // 1. Ability Trigger: onStatusAttempt (Prevention)
    for (final ab in target.abilities) {
      if (ab.trigger == AbilityTrigger.onStatusAttempt) {
        if (ab.effectType == AbilityEffectType.preventStatus &&
            (ab.value == type.toString().split('.').last ||
                ab.value == 'all')) {
          await notifyAbilityTrigger(target, ab);
          addToLog(
            '${target.organism.baseOrganism.name} prevented the status!',
          );
          notifyListeners();
          if (!isTesting) {
            await Future.delayed(const Duration(milliseconds: 3000));
          }
          return false;
        }
      }
    }

    // 3. Terrain Checks
    if (currentTerrain.terrain == Terrain.misty ||
        (type == StatusEffectType.sleep &&
            currentTerrain.terrain == Terrain.electric)) {
      _appendToLog('\nThe terrain prevents the status condition!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
      return false;
    }

    // 4. Existing Status Check (Duplicate prevention)
    if (target.statusEffects.any((se) => se.type == type)) return false;

    // 5. Apply Status
    int finalDuration = duration ?? -1;
    if (duration == null) {
      if (type == StatusEffectType.sleep) {
        finalDuration = 2 + Random().nextInt(4); // 2-5 turns
      } else if (type == StatusEffectType.stun) {
        finalDuration = 1;
      } else if (type == StatusEffectType.confusion) {
        finalDuration = 1 + Random().nextInt(3);
      } else if (type == StatusEffectType.regen ||
          type == StatusEffectType.blind ||
          type == StatusEffectType.vulnerable) {
        finalDuration = 3 + Random().nextInt(3);
      } else if (type == StatusEffectType.fear ||
          type == StatusEffectType.marked) {
        finalDuration = 2;
      } else if (type == StatusEffectType.taunt) {
        finalDuration = 3;
        target.tauntTurns = 3;
      } else if (type == StatusEffectType.encore) {
        finalDuration = 3;
        target.encoreTurns = 3;
      } else if (type == StatusEffectType.imprison) {
        finalDuration = -1;
        target.isImprisoning = true;
      } else if (type == StatusEffectType.soaked ||
          type == StatusEffectType.poison ||
          type == StatusEffectType.burn ||
          type == StatusEffectType.bleed ||
          type == StatusEffectType.paralysis ||
          type == StatusEffectType.freeze ||
          type == StatusEffectType.stealth) {
        finalDuration = -1; // Infinite duration until cured/removed
      }
    }

    final newStatus = StatusEffect(type: type, duration: finalDuration);
    target.addStatusEffect(newStatus);
    _appendToLog(
      '\n${target.organism.baseOrganism.name} ${newStatus.startMessage}',
    );
    notifyListeners();
    if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));

    // After applying status, check if the holding berry can cure it
    await _checkAndTriggerCureBerry(target);
    return true;
  }

  Future<void> _applyMoveEffect(
    BattleOrganism attacker,
    BattleOrganism defender,
    List<MoveEffect> effects,
    Move move,
  ) async {
    for (final effect in effects) {
      if (effect.type == MoveEffectType.none) continue;

      final target = effect.target == 'self' ? attacker : defender;

      if (target.health <= 0) continue; // Skip effects if target is fainted

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
        case MoveEffectType.statusStealth:
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
            case MoveEffectType.statusStealth:
              statusType = StatusEffectType.stealth;
              break;
            default:
              statusType = StatusEffectType.none;
          }

          if (statusType == StatusEffectType.none) continue;

          if (statusType == StatusEffectType.poison) {
            bool isImmune =
                target.types.contains(ElementalType.toxic) ||
                target.types.contains(ElementalType.metal);
            if (attacker.abilities.any((ab) => ab.name == 'Corrosion')) {
              isImmune = false;
            }
            if (isImmune) continue;
          }

          if (statusType == StatusEffectType.burn) {
            if (target.types.contains(ElementalType.blaze)) continue;
          }

          await applyStatusEffect(
            target,
            statusType,
            chance: effect.chance,
            duration: effect.value > 0 ? effect.value : null,
          );
          break;
        case MoveEffectType.weather:
          await setWeatherHelper(
            effect.stat.isNotEmpty
                ? effect.stat
                : effect.weather.name.toLowerCase(),
            attacker,
          );
          break;
        case MoveEffectType.terrain:
          await setTerrainHelper(effect.stat);
          break;
        case MoveEffectType.statChange:
          if (Random().nextInt(100) < effect.chance) {
            await applyStatChange(
              target,
              effect.stat,
              effect.value,
              source: attacker,
            );
            // Log is handled in _applyStatChange
          }
          break;
        case MoveEffectType.multiStatChange:
          if (Random().nextInt(100) < effect.chance) {
            // Format stat: 'attack:1,defense:1' or similar
            final changes = effect.stat.split(',');
            for (final change in changes) {
              final parts = change.split(':');
              if (parts.length == 2) {
                final stat = parts[0];
                final val = int.tryParse(parts[1]) ?? 0;
                await applyStatChange(target, stat, val);
              }
            }
            addToLog(
              '\n${target.organism.baseOrganism.name}\'s stats changed!',
            );
          }
          break;
        case MoveEffectType.statChangeChance:
          if (Random().nextInt(100) < effect.chance) {
            final changes = effect.stat.split(',');
            for (final change in changes) {
              final parts = change.split(':');
              if (parts.length == 2) {
                final stat = parts[0];
                final val = int.tryParse(parts[1]) ?? 0;
                await applyStatChange(target, stat, val);
              }
            }
            addToLog(
              '\n${target.organism.baseOrganism.name}\'s stats increased!',
            );
          }
          break;
        case MoveEffectType.forceSwitchSelf:
        case MoveEffectType.damageAndSwitchSelf:
          if (attacker.isOpponent) {
            // AI: pick a random valid team member and switch immediately
            final available = <int>[];
            for (int i = 0; i < opponentTeam.length; i++) {
              if (i != currentOpponentIndex &&
                  opponentTeam[i].currentHealth > 0) {
                available.add(i);
              }
            }
            if (available.isNotEmpty) {
              addToLog('${attacker.organism.baseOrganism.name} dashed back!');
              notifyListeners();
              if (!isTesting) {
                await Future.delayed(const Duration(milliseconds: 1500));
              }
              await _switchOpponentTo(
                available[Random().nextInt(available.length)],
              );
              opponentJustSwitched = true;
            }
          } else {
            // Player: show switch dialog and pause until they choose
            final hasAvailable = playerTeam.any(
              (org) => org.currentHealth > 0 && org != player.organism,
            );
            if (hasAvailable) {
              addToLog(
                '${attacker.organism.baseOrganism.name} dashed back! Choose the next animal!',
              );
              currentState = BattleState.waitingForPlayerSwitch;
              notifyListeners();
              _switchCompleter = Completer<void>();
              await _switchCompleter!.future;
              _switchCompleter = null;
              currentState = BattleState.applyingEffects;
            }
          }
          break;
        case MoveEffectType.changeType:
          if (effect.stat == 'water') {
            target.battleTypes = [ElementalType.aquatic];
            addToLog(
              '${target.organism.baseOrganism.name} was soaked in water!',
            );
          }
          break;
        case MoveEffectType.setScreen:
          final turns = effect.value > 0 ? effect.value : 5;
          if (effect.stat == 'break') {
            // Brick Break / Psychic Fangs: shatter opponent screens
            bool broke = false;
            if (attacker.isOpponent) {
              if (playerReflectTurns > 0) {
                playerReflectTurns = 0;
                broke = true;
              }
              if (playerLightScreenTurns > 0) {
                playerLightScreenTurns = 0;
                broke = true;
              }
              if (playerAuroraVeilTurns > 0) {
                playerAuroraVeilTurns = 0;
                broke = true;
              }
            } else {
              if (opponentReflectTurns > 0) {
                opponentReflectTurns = 0;
                broke = true;
              }
              if (opponentLightScreenTurns > 0) {
                opponentLightScreenTurns = 0;
                broke = true;
              }
              if (opponentAuroraVeilTurns > 0) {
                opponentAuroraVeilTurns = 0;
                broke = true;
              }
            }
            if (broke) addToLog('${attacker.name} shattered the barrier!');
          } else if (effect.stat == 'reflect') {
            if (attacker.isOpponent) {
              opponentReflectTurns = turns;
            } else {
              playerReflectTurns = turns;
            }
            addToLog('A reflecting wall rose up!');
          } else if (effect.stat == 'light_screen') {
            if (attacker.isOpponent) {
              opponentLightScreenTurns = turns;
            } else {
              playerLightScreenTurns = turns;
            }
            addToLog('A shimmering screen rose up!');
          } else if (effect.stat == 'aurora_veil') {
            if (currentWeather.weather == Weather.snowstorm ||
                currentWeather.weather == Weather.hail) {
              if (attacker.isOpponent) {
                opponentAuroraVeilTurns = turns;
              } else {
                playerAuroraVeilTurns = turns;
              }
              addToLog('An aurora veil rose up!');
            } else {
              addToLog('But it failed!');
            }
          }
          break;
        case MoveEffectType.protect:
          attacker.isProtected = true;
          break;
        case MoveEffectType.heal:
          if (target.health < target.maxHealth) {
            // effect.value is treated as a percentage (e.g., 50 = 50% of max HP)
            final healedAmount = effect.value > 0
                ? (target.maxHealth * effect.value / 100).round()
                : 0;
            if (healedAmount > 0) {
              target.health += healedAmount;
              target.health = target.health.clamp(0, target.maxHealth);
              onHeal?.call(target, healedAmount);
              final double healPercent =
                  (healedAmount / target.maxHealth * 100);
              _appendToLog(
                '\n${target.organism.baseOrganism.name} recovered $healedAmount HP (${healPercent.toStringAsFixed(1)}%)!',
              );
              // Play healing sound effect
              await _audioService.playSound('audio/effects/heal.mp3');
            }
          }
          break;
        case MoveEffectType.recharge:
          attacker.mustRecharge = true;
          break;
        case MoveEffectType.charge:
          // Check for Power Herb
          bool skipCharge = false;
          if (attacker.organism.equippedTalisman != null &&
              !attacker.talismanConsumed) {
            for (final tEffect in attacker.organism.equippedTalisman!.effects) {
              if (tEffect.type == TalismanEffectType.powerHerb) {
                skipCharge = true;
                attacker.talismanConsumed = true;
                attacker.isItemRevealed = true;
                _getStats(attacker.organism.id).isItemRevealed = true;
                addToLog(
                  '${attacker.organism.name} used its ${attacker.organism.equippedTalisman!.name} to skip the charge!',
                );
                break;
              }
            }
          }

          if (skipCharge) {
            // If skip, we don't set chargeMove, we just continue (which will cause the move to execute immediately in next turn logic OR we need to handle it here)
            // Actually, charge moves in this engine seem to just set chargeMove.
            // I need to see where chargeMove is handled.
          } else {
            attacker.chargeMove = move;
            attacker.chargeStatChanges = effect.stat;
          }
          break;
        case MoveEffectType.setHazard:
          final isTargetPlayer = target == player;
          final hazardSet = isTargetPlayer ? playerHazards : opponentHazards;

          int maxLayers = 1;
          if (effect.stat == 'spikes') maxLayers = 3;
          if (effect.stat == 'toxic_spikes') maxLayers = 2;

          final count = hazardSet.where((h) => h == effect.stat).length;
          if (count >= maxLayers) {
            String hazardName = effect.stat.replaceAll('_', ' ');
            addToLog('But no more $hazardName can be set!');
          } else {
            hazardSet.add(effect.stat);
            String hazardName = effect.stat.replaceAll('_', ' ');
            if (count > 0) {
              addToLog('Another layer of $hazardName was added!');
            } else {
              addToLog(
                'The ${target.isOpponent ? "opponent's" : "your"} side was surrounded by $hazardName!',
              );
            }
          }
          break;
        case MoveEffectType.semiInvulnerable:
          attacker.semiInvulnerable = effect.stat;
          break;
        case MoveEffectType.forceSwitch:
          // 1. Ability Trigger: Sticky Hold / Abyss Dweller (Prevention)
          bool isStable = target.abilities.any(
            (ab) => ab.name == 'Sticky Hold' || ab.name == 'Abyss Dweller',
          );
          if (isStable) {
            final ab = target.abilities.firstWhere(
              (a) => a.name == 'Sticky Hold' || a.name == 'Abyss Dweller',
            );
            await notifyAbilityTrigger(target, ab);
            String actionText = ab.name == 'Abyss Dweller'
                ? 'remained in the depths'
                : 'anchored itself';
            addToLog(
              '${target.organism.baseOrganism.name} $actionText with ${ab.name}!',
            );
            notifyListeners();
            if (!isTesting) {
              await Future.delayed(const Duration(milliseconds: 2000));
            }
            continue;
          }

          // 2. Check if team has other members to switch to
          final isTargetPlayer = target == player;
          final team = isTargetPlayer ? playerTeam : opponentTeam;
          final currentIndex = isTargetPlayer
              ? currentPlayerIndex
              : currentOpponentIndex;

          final availableIndices = <int>[];
          for (int i = 0; i < team.length; i++) {
            if (i != currentIndex && team[i].currentHealth > 0) {
              availableIndices.add(i);
            }
          }

          if (availableIndices.isEmpty) {
            addToLog('But there was no one to switch with!');
            notifyListeners();
            if (!isTesting) {
              await Future.delayed(const Duration(milliseconds: 2000));
            }
            continue;
          }

          // 3. Perform the switch
          final nextIndex =
              availableIndices[Random().nextInt(availableIndices.length)];
          addToLog('${target.organism.baseOrganism.name} was blown away!');
          notifyListeners();
          if (!isTesting) {
            await Future.delayed(const Duration(milliseconds: 2000));
          }

          if (isTargetPlayer) {
            _switchToAnimal(nextIndex);
            // Since it's forced, we might need to handle turn flow
            // but Whirlwind usually just ends the move effect.
          } else {
            await _switchOpponentTo(nextIndex);
            opponentJustSwitched = true;
          }
          notifyListeners();
          if (!isTesting) {
            await Future.delayed(const Duration(milliseconds: 2000));
          }
          break;
        case MoveEffectType.finalGambit:
          // Damage is handled in calculateDamage, here we just faint the user
          attacker.health = 0;
          addToLog('${attacker.name} fainted to inflict massive damage!');
          _checkBattleEnd();
          break;
        case MoveEffectType.trickRoom:
          if (trickRoomTurns > 0) {
            trickRoomTurns = 0;
            addToLog('The twisted dimensions returned to normal!');
          } else {
            trickRoomTurns = effect.value > 0 ? effect.value : 5;
            addToLog('Dimensions were twisted!');
          }
          break;
        case MoveEffectType.tailwind:
          final turns = effect.value > 0 ? effect.value : 4;
          if (attacker.isPlayer) {
            playerTailwindTurns = turns;
          } else {
            opponentTailwindTurns = turns;
          }
          addToLog(
            'The tailwind blew from behind the ${attacker.isPlayer ? "player's" : "opponent's"} team!',
          );
          break;
        case MoveEffectType.perishSong:
          attacker.perishTurnCount = effect.value > 0 ? effect.value : 3;
          defender.perishTurnCount = effect.value > 0 ? effect.value : 3;
          addToLog('All animals hearing the song will faint in three turns!');
          break;
        case MoveEffectType.cureTeamStatus:
          final team = attacker.isPlayer ? playerTeam : opponentTeam;
          for (final org in team) {
            org.statusEffects.clear();
          }
          addToLog('A soothing bell chimed, healing the team\'s status!');
          break;
        case MoveEffectType.healingWish:
          attacker.health = 0;
          healingWishPending = true;
          addToLog(
            '${attacker.name} fainted to grant a wish to its successor!',
          );
          _checkBattleEnd();
          break;
        case MoveEffectType.wish:
          attacker.wishTurns = 2;
          attacker.wishHealAmount = (attacker.maxHealth / 2).round();
          addToLog('${attacker.name} made a wish!');
          break;
        case MoveEffectType.healBlock:
          target.healBlockTurns = 5;
          addToLog('${target.name} was blocked from healing!');
          break;
        case MoveEffectType.miracleEye:
          target.isMiracleEyed = true;
          target.evasionStage = 0;
          addToLog('${target.name} was identified by Miracle Eye!');
          break;
        case MoveEffectType.gravity:
          gravityTurns = 5;
          addToLog('Gravity intensified!');
          break;
        case MoveEffectType.substitute:
          if (attacker.substituteHealth > 0) {
            addToLog('${attacker.name} already has a substitute!');
          } else {
            final cost = (attacker.maxHealth * 0.25).floor();
            if (attacker.health > cost) {
              attacker.health -= cost;
              attacker.substituteHealth = cost;
              addToLog('${attacker.name} created a substitute!');
              notifyListeners();
            } else {
              addToLog('But it failed! Not enough HP.');
            }
          }
          break;
        case MoveEffectType.defenseCurl:
          attacker.usedDefenseCurl = true;
          await applyStatChange(attacker, 'defense', 1);
          break;
        case MoveEffectType.futureSight:
          if (defender.futureSightTurns > 0) {
            addToLog('But it failed! Future Sight is already in effect.');
          } else {
            defender.futureSightTurns = 3;
            defender.futureSightUser = attacker;
            addToLog('${attacker.name} foresaw an attack!');
          }
          break;
        case MoveEffectType.clamping:
          defender.clampingTurns = 2 + Random().nextInt(4); // 2-5 turns
          defender.isTrapped = true;
          addToLog('${defender.name} was trapped by ${move.name}!');
          break;
        case MoveEffectType.trapIndices:
          defender.isTrapped = true;
          addToLog('${defender.name} can no longer escape!');
          break;
        case MoveEffectType.throatChop:
          defender.throatChopTurns = 2;
          addToLog(
            '${defender.name}\'s throat was chopped! It can\'t use sound-based moves!',
          );
          break;
        case MoveEffectType.defog:
          playerHazards.clear();
          opponentHazards.clear();
          playerReflectTurns = 0;
          opponentReflectTurns = 0;
          playerLightScreenTurns = 0;
          opponentLightScreenTurns = 0;
          playerAuroraVeilTurns = 0;
          opponentAuroraVeilTurns = 0;
          addToLog('The fog blew away the hazards and screens!');
          await applyStatChange(defender, 'evasion', -1, source: attacker);
          break;
        case MoveEffectType.acupressure:
          final stats = [
            'attack',
            'defense',
            'power',
            'resistance',
            'speed',
            'accuracy',
            'evasion',
          ];
          final stat = stats[Random().nextInt(stats.length)];
          await applyStatChange(target, stat, 2, source: attacker);
          break;
        case MoveEffectType.filletAway:
          final cost = (attacker.maxHealth * 0.5).floor();
          if (attacker.health > cost) {
            attacker.health -= cost;
            await applyStatChange(attacker, 'attack', 2);
            await applyStatChange(attacker, 'power', 2);
            await applyStatChange(attacker, 'speed', 2);
            addToLog('${attacker.name} fillet away its meat to boost stats!');
          } else {
            addToLog('But it failed! Not enough HP.');
          }
          break;
        case MoveEffectType.memento:
          attacker.health = 0;
          await applyStatChange(defender, 'attack', -2, source: attacker);
          await applyStatChange(defender, 'power', -2, source: attacker);
          addToLog('${attacker.name} fainted as a memento!');
          _checkBattleEnd();
          break;
        case MoveEffectType.jungleHealing:
          final healedAmount = (attacker.maxHealth * 0.25).round();
          attacker.health += healedAmount;
          attacker.health = attacker.health.clamp(0, attacker.maxHealth);
          attacker.clearStatusEffects();
          addToLog('${attacker.name} was healed by the jungle!');
          onHeal?.call(attacker, healedAmount);
          break;
        case MoveEffectType.mindBlown:
          final cost = (attacker.maxHealth * 0.5).floor();
          attacker.health -= cost;
          addToLog('${attacker.name} was hurt by its own explosion!');
          _checkBattleEnd();
          break;
        case MoveEffectType.meteorBeam:
          // Boost handled in _executeTurn on first turn
          break;
        case MoveEffectType.skullBash:
          // Boost handled in _executeTurn on first turn
          break;
        case MoveEffectType.payDay:
          addToLog('Coins were scattered everywhere!');
          break;
        case MoveEffectType.shellTrap:
          attacker.shellTrapActive = true;
          addToLog('${attacker.name} set a shell trap!');
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
      }
      attacker.lastMoveName = move.name;
    }
  }

  Future<void> applyStatChange(
    BattleOrganism target,
    String stat,
    int value, {
    BattleOrganism? source,
  }) async {
    // Substitute blocks stat reductions from opponents
    if (value < 0 &&
        source != null &&
        source != target &&
        target.substituteHealth > 0) {
      return;
    }

    // --- Ability Trigger: onStatLoss (Prevention) ---
    if (value < 0) {
      for (final ab in target.abilities) {
        if (ab.trigger == AbilityTrigger.onStatLoss &&
            ab.effectType == AbilityEffectType.preventStatLoss) {
          await notifyAbilityTrigger(target, ab);
          addToLog(
            '${target.organism.baseOrganism.name}\'s ${ab.name} prevents stat loss!',
          );
          return;
        }
      }
    }

    if (stat == 'all') {
      await _changeStat(target, 'attack', value, source: source);
      await _changeStat(target, 'defense', value, source: source);
      await _changeStat(target, 'power', value, source: source);
      await _changeStat(target, 'resistance', value, source: source);
      await _changeStat(target, 'speed', value, source: source);
    } else {
      final stats = stat.split(',');
      for (final s in stats) {
        final pair = s.trim().split(':');
        final statName = pair[0];
        final statValue = pair.length > 1
            ? int.tryParse(pair[1]) ?? value
            : value;
        await _changeStat(target, statName, statValue, source: source);
      }
    }
  }

  Future<void> _changeStat(
    BattleOrganism target,
    String statName,
    int value, {
    BattleOrganism? source,
  }) async {
    if (statName == 'accuracy' && value < 0) {
      bool hasEcholocation = target.abilities.any(
        (ab) => ab.name == 'Echolocation',
      );
      if (hasEcholocation) {
        final ab = target.abilities.firstWhere((a) => a.name == 'Echolocation');
        await notifyAbilityTrigger(target, ab);
        addToLog(
          '${target.organism.baseOrganism.name}\'s accuracy was protected by ${ab.name}!',
        );
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 2000));
        }
        return;
      }
    }

    if (value < 0) {
      target.statsLoweredThisTurn = true;
    }

    if (statName == 'attack') {
      target.attackStage = (target.attackStage + value).clamp(-6, 6);
    } else if (statName == 'defense') {
      target.defenseStage = (target.defenseStage + value).clamp(-6, 6);
    } else if (statName == 'power') {
      target.powerStage = (target.powerStage + value).clamp(-6, 6);
    } else if (statName == 'resistance') {
      target.resistanceStage = (target.resistanceStage + value).clamp(-6, 6);
    } else if (statName == 'speed') {
      target.speedStage = (target.speedStage + value).clamp(-6, 6);
    } else if (statName == 'accuracy') {
      target.accuracyStage = (target.accuracyStage + value).clamp(-6, 6);
    } else if (statName == 'evasion') {
      target.evasionStage = (target.evasionStage + value).clamp(-6, 6);
    }

    // Map internal stat names to UI/User-friendly terms
    String displayStatName = statName.toUpperCase();
    if (statName == 'power') displayStatName = 'POWER'; // Was Sp. Atk
    if (statName == 'resistance') displayStatName = 'RESISTANCE'; // Was Sp. Def
    if (value != 0) {
      onStatChange?.call(target, statName, value);
      // displayStatName is already upper case from logic above
      final bool increased = value > 0;
      final String direction = increased ? 'rose' : 'fell';
      final int absValue = value.abs();

      String stageText;
      if (absValue == 1) {
        stageText = '';
      } else if (absValue == 2) {
        stageText = ' sharply';
      } else if (absValue >= 3) {
        stageText = ' drastically';
      } else {
        stageText = '';
      }

      addToLog(
        '${target.organism.baseOrganism.name}\'s $displayStatName $direction$stageText!',
      );

      // Play stat change sound effect
      if (increased) {
        if (!isTesting) {
          await _audioService.playSound('audio/effects/stat_up.mp3');
        }
      } else {
        if (!isTesting) {
          await _audioService.playSound('audio/effects/stat_down.mp3');
        }
      }

      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
    }

    // White Herb
    if (value < 0 &&
        target.organism.equippedTalisman != null &&
        !target.talismanConsumed &&
        target.organism.equippedTalisman!.effects.any(
          (e) => e.type == TalismanEffectType.whiteHerb,
        )) {
      target.talismanConsumed = true;
      target.isItemRevealed = true;
      _getStats(target.organism.id).isItemRevealed = true;
      addToLog(
        '${target.organism.baseOrganism.name} restored its lowered stats using its ${target.organism.equippedTalisman!.name}!',
      );
      if (target.attackStage < 0) target.attackStage = 0;
      if (target.defenseStage < 0) target.defenseStage = 0;
      if (target.powerStage < 0) target.powerStage = 0;
      if (target.resistanceStage < 0) target.resistanceStage = 0;
      if (target.speedStage < 0) target.speedStage = 0;
      if (target.accuracyStage < 0) target.accuracyStage = 0;
      if (target.evasionStage < 0) target.evasionStage = 0;
      notifyListeners();
      if (!isTesting) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }

    // --- Ability Trigger: onStatLoss (Reaction e.g. Defiant) ---
    if (value < 0 && source != null && source != target) {
      for (final ab in target.abilities) {
        if (ab.trigger == AbilityTrigger.onStatLoss &&
            ab.effectType == AbilityEffectType.statChange) {
          await notifyAbilityTrigger(target, ab);
          await applyStatChange(
            target,
            ab.targetStat,
            ab.magnitude.round(),
            source: target,
          );
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
        final msg = _weatherPersistenceMessage;
        if (msg.isNotEmpty) {
          addToLog(msg);
          notifyListeners();
          if (!isTesting) {
            await Future.delayed(const Duration(milliseconds: 3000));
          }
        }
      }

      if (weatherTurnsLeft == 0) {
        addToLog(currentWeather.endMessage);
        currentWeather = const WeatherEffect(weather: Weather.none);
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 3000));
        }
      }
    }

    // Future Sight handling
    for (final organism in [player, opponent]) {
      if (organism.futureSightTurns > 0) {
        organism.futureSightTurns--;
        if (organism.futureSightTurns == 0) {
          final user = organism.futureSightUser;
          if (user != null) {
            addToLog('The future sight attack hit ${organism.name}!');
            // Calculate damage now
            // Future Sight is 120 power, special (power), typeless/neutral usually
            if (organism.isProtected) {
              addToLog(
                '${organism.name} protected itself from the foreseen attack!',
              );
            } else {
              // Future Sight is 120 power, special (power), Aura type (Gen 5+)
              final int atk = user.currentPower;
              final int def = organism.currentResistance;
              double damage =
                  ((2 * user.level / 5 + 2) * 120 * atk / def) / 50 + 2;

              // Type Effectiveness
              double typeMod = 1.0;
              for (final defType in organism.types) {
                typeMod *= TypeChart.getEffectiveness(
                  ElementalType.aura,
                  defType,
                );
              }
              damage *= typeMod;

              // STAB
              if (user.types.contains(ElementalType.aura)) {
                damage *= 1.5;
              }

              // Critical Hit (1/16 chance)
              bool isCrit = Random().nextDouble() < 0.0625;
              if (isCrit) {
                damage *= 1.5;
              }

              // Apply it as indirect/direct damage
              int finalDamage = damage.round().clamp(0, organism.health);

              if (isCrit && finalDamage > 0) {
                addToLog('A critical hit!');
              }

              if (typeMod > 1.0) {
                addToLog("It's super effective!");
              } else if (typeMod > 0 && typeMod < 1.0) {
                addToLog("It's not very effective...");
              } else if (typeMod == 0) {
                addToLog('It had no effect...');
              }

              if (finalDamage > 0) {
                if (organism.substituteHealth > 0) {
                  final int subDamage = finalDamage.clamp(
                    0,
                    organism.substituteHealth,
                  );
                  organism.substituteHealth -= subDamage;
                  addToLog('The substitute took damage for ${organism.name}!');
                  if (organism.substituteHealth <= 0) {
                    organism.substituteHealth = 0;
                    addToLog('${organism.name}\'s substitute broke!');
                  }
                } else {
                  organism.health -= finalDamage;
                  onDamage?.call(organism, finalDamage);
                }
              }
            }
            notifyListeners();
            if (!isTesting)
              await Future.delayed(const Duration(milliseconds: 3000));
          }
          organism.futureSightUser = null;
        }
      }
    }

    // Gravity
    if (gravityTurns > 0) {
      gravityTurns--;
      if (gravityTurns == 0) {
        addToLog('Gravity returned to normal!');
        notifyListeners();
        if (!isTesting)
          await Future.delayed(const Duration(milliseconds: 3000));
      }
    }

    // Terrain
    if (terrainTurnsLeft > 0) {
      terrainTurnsLeft--;
      if (terrainTurnsLeft == 0) {
        addToLog(currentTerrain.endMessage);
        currentTerrain = const TerrainEffect(terrain: Terrain.none);
        notifyListeners();
        if (!isTesting)
          await Future.delayed(const Duration(milliseconds: 3000));
      }
    }

    // Screens
    if (playerReflectTurns > 0) {
      playerReflectTurns--;
      if (playerReflectTurns == 0) addToLog('Your team\'s Reflect wore off!');
    }
    if (playerLightScreenTurns > 0) {
      playerLightScreenTurns--;
      if (playerLightScreenTurns == 0)
        addToLog('Your team\'s Light Screen wore off!');
    }
    if (playerAuroraVeilTurns > 0) {
      playerAuroraVeilTurns--;
      if (playerAuroraVeilTurns == 0)
        addToLog('Your team\'s Aurora Veil wore off!');
    }
    if (opponentReflectTurns > 0) {
      opponentReflectTurns--;
      if (opponentReflectTurns == 0)
        addToLog('The opposing team\'s Reflect wore off!');
    }
    if (opponentLightScreenTurns > 0) {
      opponentLightScreenTurns--;
      if (opponentLightScreenTurns == 0)
        addToLog('The opposing team\'s Light Screen wore off!');
    }
    if (opponentAuroraVeilTurns > 0) {
      opponentAuroraVeilTurns--;
      if (opponentAuroraVeilTurns == 0)
        addToLog('The opposing team\'s Aurora Veil wore off!');
    }
  }

  Future<void> _applyTurnEffects(BattleOrganism target) async {
    if (target.health <= 0) return;

    // Reset per-turn flags
    target.shellTrapActive = false;
    target.shellTrapTriggered = false;
    target.statsLoweredThisTurn = false;
    target.focusPunchFailed = false;

    // Glaive Rush Vulnerability Decay
    if (target.glaiveRushVulnerable) {
      target.glaiveRushVulnerable = false;
    }

    // Wish Logic
    if (target.wishTurns > 0) {
      target.wishTurns--;
      if (target.wishTurns == 0) {
        if (target.health > 0 &&
            target.health < target.maxHealth &&
            target.healBlockTurns == 0) {
          final heal = target.wishHealAmount;
          target.health += heal;
          target.health = target.health.clamp(0, target.maxHealth);
          addToLog('${target.name}\'s wish came true!');
          onHeal?.call(target, heal);
          notifyListeners();
          if (!isTesting)
            await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }

    // Heal Block Decay
    if (target.healBlockTurns > 0) {
      target.healBlockTurns--;
      if (target.healBlockTurns == 0) {
        addToLog('${target.name}\'s heal block wore off!');
        notifyListeners();
        if (!isTesting)
          await Future.delayed(const Duration(milliseconds: 1500));
      }
    }

    // Status Damage & Healing (Iterate over all active effects)
    final List<StatusEffect> currentEffects = List.from(target.statusEffects);

    // Hydration Check (Cure status if raining)
    if (currentWeather.weather == Weather.rain) {
      bool hasHydration = target.abilities.any((ab) => ab.name == 'Hydration');
      if (hasHydration && target.statusEffects.isNotEmpty) {
        target.clearStatusEffects();
        addToLog(
          '${target.organism.baseOrganism.name}\'s status was cured by Hydration!',
        );
        notifyListeners();
        if (!isTesting) {
          if (!isTesting)
            await Future.delayed(const Duration(milliseconds: 3000));
        }
        return; // Status cured, skip damage processing
      }
    }
    for (final se in currentEffects) {
      if (se.type == StatusEffectType.poison) {
        // Poison Heal Check
        bool hasPoisonHeal = target.abilities.any(
          (ab) => ab.name == 'Poison Heal',
        );

        if (hasPoisonHeal) {
          final heal = (target.maxHealth * 0.125).round().clamp(1, 9999);
          target.health += heal;
          target.health = target.health.clamp(0, target.maxHealth);
          addToLog(
            '${target.organism.baseOrganism.name} restored HP due to Poison Heal!',
          );
          // Play healing sound effect
          await _audioService.playSound('audio/effects/heal.mp3');
          notifyListeners();
          if (!isTesting) {
            if (!isTesting)
              await Future.delayed(const Duration(milliseconds: 3000));
          }
        } else {
          final poisonDamage = (target.maxHealth * 0.125).round().clamp(
            1,
            9999,
          );
          target.health -= poisonDamage;
          target.health = target.health.clamp(0, target.maxHealth);
          addToLog(
            '${target.organism.baseOrganism.name} is hurt by poison (12.5%)!',
          );
          notifyListeners();
          if (!isTesting) {
            if (!isTesting)
              await Future.delayed(const Duration(milliseconds: 3000));
          }
          if (_checkBattleEnd()) return;
        }
      } else if (se.type == StatusEffectType.burn) {
        final burnDamage = (target.maxHealth * 0.06).round().clamp(1, 9999);
        target.health -= burnDamage;
        target.health = target.health.clamp(0, target.maxHealth);
        addToLog(
          '${target.organism.baseOrganism.name} is hurt by its burn (6.0%)!',
        );
        notifyListeners();
        if (!isTesting) {
          if (!isTesting)
            await Future.delayed(const Duration(milliseconds: 3000));
        }
        if (_checkBattleEnd()) return;
      } else if (se.type == StatusEffectType.bleed) {
        final bleedDamage = (target.maxHealth * 0.125).round().clamp(1, 9999);
        target.health -= bleedDamage;
        target.health = target.health.clamp(0, target.maxHealth);
        addToLog('${target.organism.baseOrganism.name} is hurt by bleeding!');
        notifyListeners();
        if (!isTesting) {
          if (!isTesting)
            await Future.delayed(const Duration(milliseconds: 3000));
        }
        if (_checkBattleEnd()) return;
      } else if (se.type == StatusEffectType.regen) {
        if (target.health < target.maxHealth) {
          final heal = (target.maxHealth * 0.06).round().clamp(1, 9999);
          target.health += heal;
          target.health = target.health.clamp(0, target.maxHealth);
          final hpPercent = (target.health / target.maxHealth * 100).round();
          addToLog(
            '${target.organism.baseOrganism.name} restored a little HP. ($hpPercent%)',
          );
          // Play healing sound effect
          await _audioService.playSound('audio/effects/heal.mp3');
          notifyListeners();
          if (!isTesting) {
            if (!isTesting)
              await Future.delayed(const Duration(milliseconds: 3000));
          }
        }
      }
    }

    // Check for fainting after status effects
    if (_checkBattleEnd()) return;

    if (target.health <= 0) return;

    // Weather Damage
    if (currentWeather.weather == Weather.sandstorm) {
      // Overcoat Check & Type Immunities (Metal, Earth, Rock)
      bool hasOvercoat = target.abilities.any((ab) => ab.name == 'Overcoat');
      bool isImmune = target.types.any(
        (t) =>
            t == ElementalType.metal ||
            t == ElementalType.earth ||
            t == ElementalType.rock,
      );
      if (!hasOvercoat && !isImmune) {
        final damage = (target.maxHealth * 0.06).round().clamp(1, 9999);
        target.health -= damage;
        target.health = target.health.clamp(0, target.maxHealth);
        addToLog(
          '${target.organism.baseOrganism.name} is buffeted by the sandstorm!',
        );
        notifyListeners();
      }
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
    } else if (currentWeather.weather == Weather.hail) {
      // Overcoat Check & Type Immunity (Cryo)
      bool hasOvercoat = target.abilities.any((ab) => ab.name == 'Overcoat');
      bool isCryo = target.types.any((t) => t == ElementalType.cryo);
      if (!hasOvercoat && !isCryo) {
        final damage = (target.maxHealth * 0.0625).round().clamp(1, 9999);
        target.health -= damage;
        target.health = target.health.clamp(0, target.maxHealth);
        addToLog(
          '${target.organism.baseOrganism.name} is battered by the hail!',
        );
        notifyListeners();
      }
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
    }

    // Grassy Terrain Healing
    if (currentTerrain.terrain == Terrain.grassy &&
        target.health < target.maxHealth) {
      final heal = (target.maxHealth * 0.06).round();
      target.health += heal;
      target.health = target.health.clamp(0, target.maxHealth);
      addToLog(
        '${target.organism.baseOrganism.name} is healed by the Grassy Terrain!',
      );
      // Play healing sound effect
      await _audioService.playSound('audio/effects/heal.mp3');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
    }

    // Talisman effects - Leftovers healing
    if (target.organism.equippedTalisman != null &&
        target.health < target.maxHealth) {
      for (final effect in target.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.onTurnHeal) {
          final healAmount = (target.maxHealth * effect.magnitude).round();
          target.health += healAmount;
          target.health = target.health.clamp(0, target.maxHealth);
          addToLog(
            '${target.organism.name} restored HP with ${target.organism.equippedTalisman!.name}! ($healAmount HP)',
          );
          // Play healing sound effect
          await _audioService.playSound('audio/effects/heal.mp3');
          notifyListeners();
          if (!isTesting) {
            await Future.delayed(const Duration(milliseconds: 3000));
          }
        }
      }
    }

    // Toxic Orb / Flame Orb
    if (target.clampingTurns > 0) {
      target.clampingTurns--;
      final damage = (target.maxHealth * 0.125).round().clamp(1, 9999);
      target.health -= damage;
      target.health = target.health.clamp(0, target.maxHealth);
      addToLog('${target.name} is hurt by the clamping effect!');
      notifyListeners();
      if (target.clampingTurns == 0) {
        target.isTrapped = false;
        addToLog('${target.name} was freed from the trapping effect!');
      }
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));
      if (_checkBattleEnd()) return;
    }

    if (target.throatChopTurns > 0) {
      target.throatChopTurns--;
      if (target.throatChopTurns == 0) {
        addToLog('${target.name} can use sound-based moves again!');
        notifyListeners();
        if (!isTesting)
          await Future.delayed(const Duration(milliseconds: 3000));
      }
    }

    if (target.organism.equippedTalisman != null && !target.talismanConsumed) {
      final itemName = target.organism.equippedTalisman!.name;
      if (itemName == 'Toxic Orb' &&
          !target.statusEffects.any((e) => e.type == StatusEffectType.poison)) {
        if (!target.types.contains(ElementalType.toxic) &&
            !target.types.contains(ElementalType.metal)) {
          addToLog(
            '${target.organism.baseOrganism.name} was badly poisoned by its Toxic Orb!',
          );
          await applyStatusEffect(
            target,
            StatusEffectType.poison,
            duration: null,
          );
          notifyListeners();
          if (!isTesting)
            await Future.delayed(const Duration(milliseconds: 1500));
        }
      } else if (itemName == 'Flame Orb' &&
          !target.statusEffects.any((e) => e.type == StatusEffectType.burn)) {
        if (!target.types.contains(ElementalType.blaze)) {
          addToLog(
            '${target.organism.baseOrganism.name} was burned by its Flame Orb!',
          );
          await applyStatusEffect(
            target,
            StatusEffectType.burn,
            duration: null,
          );
          notifyListeners();
          if (!isTesting)
            await Future.delayed(const Duration(milliseconds: 1500));
        }
      }
    }

    // Reset damage tracking for next turn (Shell Bell now fires immediately in _executeTurn)
    target.damageDealtThisTurn = 0;

    int berryApplies = target.abilities.any((ab) => ab.name == 'Cud Chew')
        ? 2
        : 1;
    for (int i = 0; i < berryApplies; i++) {
      // End-of-turn berry triggers: stat-boosting berries (Salac/Petaya/Liechi/Lansat)
      await _checkAndTriggerStatBerry(target);
    }

    // Status Duration Decay and Recovery for ALL effects
    final List<StatusEffect> updatedEffects = [];
    bool stateChanged = false;

    for (final se in target.statusEffects) {
      if (se.duration > 0 && se.type != StatusEffectType.sleep) {
        final newDuration = max(0, se.duration - 1);

        // --- Taunt/Encore decrement ---
        if (se.type == StatusEffectType.taunt) target.tauntTurns = newDuration;
        if (se.type == StatusEffectType.encore)
          target.encoreTurns = newDuration;

        if (newDuration == 0) {
          if (se.type == StatusEffectType.stealth) {
            addToLog('${target.organism.baseOrganism.name} was revealed!');
          } else {
            addToLog(
              '${target.organism.baseOrganism.name} recovered from ${se.name}!',
            );
          }
          notifyListeners();
          if (!isTesting) {
            await Future.delayed(const Duration(milliseconds: 3000));
          }
          stateChanged = true;
          // Don't add to updatedEffects, effectively removing it
        } else {
          updatedEffects.add(se.copyWith(duration: newDuration));
        }
      } else {
        updatedEffects.add(se);
      }
    }

    // Actually update the status effects list
    if (stateChanged) {
      target.statusEffects = updatedEffects;
    }

    if (stateChanged || updatedEffects.length != target.statusEffects.length) {
      target.organism.statusEffects = updatedEffects;
      target.organism.statusEffects = updatedEffects; // Sync
      notifyListeners();
    }
    // Brace removed

    // Moody Check
    bool hasMoody = target.abilities.any((ab) => ab.name == 'Moody');
    if (hasMoody && target.health > 0) {
      final stats = [
        'attack',
        'defense',
        'power',
        'resistance',
        'speed',
        'accuracy',
      ];
      final raiseStat = stats[Random().nextInt(stats.length)];
      String lowerStat = stats[Random().nextInt(stats.length)];
      while (lowerStat == raiseStat) {
        lowerStat = stats[Random().nextInt(stats.length)];
      }

      await notifyAbilityTrigger(
        target,
        target.abilities.firstWhere((ab) => ab.name == 'Moody'),
      );
      await applyStatChange(target, raiseStat, 2); // Sharp rise
      await applyStatChange(target, lowerStat, -1); // Fall
    }

    // Harvest Check
    if (target.health > 0 &&
        target.talismanConsumed &&
        target.organism.equippedTalisman != null &&
        target.organism.equippedTalisman!.name.toLowerCase().contains(
          'berry',
        )) {
      bool hasHarvest = target.abilities.any((ab) => ab.name == 'Harvest');
      if (hasHarvest) {
        double harvestChance = 0.5;
        if (currentWeather.weather == Weather.sunny) {
          harvestChance = 1.0;
        }

        if (Random().nextDouble() < harvestChance) {
          target.talismanConsumed = false;
          final harvestAbility = target.abilities.firstWhere(
            (ab) => ab.name == 'Harvest',
          );
          await notifyAbilityTrigger(target, harvestAbility);
          addToLog(
            '${target.organism.name} harvested its ${target.organism.equippedTalisman!.name}!',
          );
          notifyListeners();
          if (!isTesting) {
            await Future.delayed(const Duration(milliseconds: 3000));
          }
        }
      }
    }

    // Reset turn-based flags
    target.isFirstTurnOutOfBall = false;
    target.statsLoweredThisTurn = false;
    target.shellTrapTriggered = false;
    target.focusPunchFailed = false;
    target.tookDamageThisTurn = false;
  }

  // --- Capture and Run Logic ---

  Future<void> attemptCapture({String netId = 'capture_net'}) async {
    if (currentState != BattleState.waitingForInput) return;

    currentState = BattleState.applyingEffects;
    isCapturing = true;
    captureShakeCount = 0;

    String netName = 'Capture Net';
    double netMultiplier = 1.0;

    if (netId == 'great_net') {
      netName = 'Great Net';
      netMultiplier = 1.5;
    } else if (netId == 'ultra_net') {
      netName = 'Ultra Net';
      netMultiplier = 2.0;
    }

    addToLog('Throwing a $netName...');
    notifyListeners();
    if (!isTesting) await Future.delayed(const Duration(seconds: 1));

    final hpRatio = opponent.health / opponent.maxHealth;
    final baseChance = 0.50;
    final hpBonus = (1.0 - hpRatio) * 0.50;
    double captureChance = (baseChance + hpBonus) * netMultiplier;

    if (opponent.organism.baseOrganism.rarity.toLowerCase() == 'epic') {
      captureChance *= 0.7;
    } else if (opponent.organism.baseOrganism.rarity.toLowerCase() ==
        'legendary') {
      captureChance *= 0.4;
    } else if (opponent.organism.baseOrganism.rarity.toLowerCase() ==
        'mythical') {
      captureChance *= 0.1;
    }

    // 3 Shakes logic
    bool success = true;
    for (int i = 1; i <= 3; i++) {
      captureShakeCount = i;
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));

      // Each shake is a partial roll of the capture chance
      // We use pow(captureChance, 1/3) to make the total probability equal to captureChance
      if (Random().nextDouble() > pow(captureChance.clamp(0.01, 0.99), 1 / 3)) {
        success = false;
        break;
      }
    }

    if (success) {
      opponent.organism.currentHealth = opponent.health;
      _result = BattleResult.capture;
      addToLog('Success! ${opponent.organism.baseOrganism.name} was captured!');
      // Award XP for capture
      onOpponentFainted?.call(player, opponent);
      _cleanupStatusEffects();
      currentState = BattleState.battleEnd;
      notifyListeners(); // Ensure UI sees success for sprite disappearance
    } else {
      _result = null;
      addToLog('The capture failed! Opponent broke free!');
      currentState = BattleState.opponentTurn;
      if (!isTesting) await Future.delayed(const Duration(seconds: 1));
      await _processOpponentTurn(isCounter: false);
    }

    isCapturing = false;
    notifyListeners();

    if (currentState == BattleState.opponentTurn) {
      await _finalizeTurn();
    }
  }

  CapturedOrganism _createTrainerOrganism() {
    final base = Organism(
      name: 'Trainer',
      scientificName: 'Homo sapiens',
      habitat: 'Urban',
      drops: '',
      attack: 40,
      defense: 40,
      power: 40,
      resistance: 40,
      health: 100,
      speed: 40,
      abilities: 'Inner Focus',
      category: 'Human',
      moves: 'Punch,Kick,Defend,Focus',
      sprite: 'assets/sprites/trainer_human.png',
      rarity: 'Common',
      description: 'A human trainer forced to defend themselves.',
      types: ['basic'],
    );

    return CapturedOrganism(
      baseOrganism: base,
      individualValues: {
        'health': 15,
        'attack': 15,
        'defense': 15,
        'power': 15,
        'resistance': 15,
        'speed': 15,
      },
      currentHealth: 100,
      level: 10, // Default level for trainer
      selectedMoveNames: ['Punch', 'Kick', 'Defend', 'Focus'],
    );
  }

  Future<void> attemptRun() async {
    if (currentState != BattleState.waitingForInput) return;

    currentState = BattleState.applyingEffects;
    addToLog('Attempting to run...');
    notifyListeners();
    if (!isTesting) await Future.delayed(const Duration(seconds: 1));

    final runChance = (player.currentSpeed / opponent.currentSpeed) * 0.75;

    final trapper = opponent.abilities.firstWhere(
      (ab) => ab.name == 'Arena Trap',
      orElse: () => const Ability(name: '', description: ''),
    );

    final magnetTrapper = opponent.abilities.firstWhere(
      (ab) => ab.name == 'Magnet Pull',
      orElse: () => const Ability(name: '', description: ''),
    );

    bool isearthed =
        !player.types.contains(ElementalType.flying) &&
        !player.abilities.any(
          (a) => a.name == 'Levitate' || a.name == 'True Flight',
        ) &&
        player.organism.equippedTalisman?.name != 'Air Balloon';

    if ((trapper.name.isNotEmpty && isearthed) ||
        (magnetTrapper.name.isNotEmpty &&
            player.types.contains(ElementalType.metal))) {
      final actualTrapper = trapper.name.isNotEmpty && isearthed
          ? trapper
          : magnetTrapper;
      await notifyAbilityTrigger(opponent, actualTrapper);
      addToLog(
        'The wild ${opponent.organism.baseOrganism.name} prevents escape!',
      );
      currentState = BattleState.opponentTurn;
      if (!isTesting) await Future.delayed(const Duration(seconds: 1));
      await _processOpponentTurn(isCounter: false);
      currentState = BattleState.waitingForInput;
      _startSuggestionTimer();
      notifyListeners();
      return;
    }

    if (Random().nextDouble() < runChance.clamp(0.1, 1.0)) {
      _result = BattleResult.fled;
      addToLog('You successfully ran away!');
      _cleanupStatusEffects();
      currentState = BattleState.battleEnd;
      notifyListeners();
    } else {
      _result = null;
      addToLog('Failed to run! Opponent\'s turn.');
      currentState = BattleState.opponentTurn;
      if (!isTesting) await Future.delayed(const Duration(seconds: 1));
      await _processOpponentTurn(isCounter: false);
      await _finalizeTurn();
    }
  }

  /// Used in arena/rogue battles instead of run. Immediately ends the battle as a loss.
  Future<void> forfeit() async {
    if (currentState != BattleState.waitingForInput) return;
    addToLog('You forfeited the battle...');
    _result = BattleResult.loss;
    _cleanupStatusEffects();
    currentState = BattleState.battleEnd;
    notifyListeners();
  }

  Future<void> switchAnimal(int index) async {
    bool isForced = currentState == BattleState.waitingForPlayerSwitch;
    if (currentState != BattleState.waitingForInput && !isForced) return;

    // Prevent switching during two-turn moves or recharge
    if (!isForced &&
        (player.chargingMove != null ||
            player.mustRecharge ||
            player.semiInvulnerable != null ||
            player.isInvulnerable)) {
      if (player.mustRecharge) {
        addToLog('Cannot switch while ${player.name} is recharging!');
      } else if (player.semiInvulnerable != null) {
        addToLog('Cannot switch while ${player.name} is hidden!');
      } else {
        addToLog('Cannot switch while ${player.name} is charging a move!');
      }
      notifyListeners();
      return;
    }

    if (!isForced && player.isTrapped) {
      addToLog('${player.name} is trapped and cannot switch!');
      currentState = BattleState.waitingForInput;
      notifyListeners();
      return;
    }

    // Fix: Immediately transition state and notify so UI knows we are processing
    currentState = BattleState.applyingEffects;
    notifyListeners();

    // Record player switch for AI history
    playerHistory.recordSwitch(index);
    if (index < 0 || index >= playerTeam.length) return;
    if (index == currentPlayerIndex) return;

    // Fix 3: Deadlock guard for forced switches.
    // If the UI sends an invalid (fainted) target while forced, either redirect
    // to a healthy fallback or trigger a loss rather than hanging forever.
    if (isForced && playerTeam[index].currentHealth <= 0) {
      final fallback = playerTeam.indexWhere(
        (org) =>
            org.currentHealth > 0 &&
            playerTeam.indexOf(org) != currentPlayerIndex,
      );
      if (fallback == -1) {
        // No healthy animals remain — force a loss.
        _result = BattleResult.loss;
        addToLog('Your whole team is defeated. You blacked out!');
        _cleanupStatusEffects();
        currentState = BattleState.battleEnd;
        notifyListeners();
        return;
      }
      // Redirect to the first healthy animal.
      return switchAnimal(fallback);
    }

    if (playerTeam[index].currentHealth <= 0) return;

    // Arena Trap Check (Prevention)
    bool isearthed =
        !player.types.contains(ElementalType.flying) &&
        !player.abilities.any(
          (a) => a.name == 'Levitate' || a.name == 'True Flight',
        ) &&
        player.organism.equippedTalisman?.name != 'Air Balloon';

    final trapper = opponent.abilities.firstWhere(
      (ab) => ab.name == 'Arena Trap',
      orElse: () => const Ability(name: '', description: ''),
    );

    final magnetTrapper = opponent.abilities.firstWhere(
      (ab) => ab.name == 'Magnet Pull',
      orElse: () => const Ability(name: '', description: ''),
    );

    if (trapper.name == 'Arena Trap' && isearthed && !isForced) {
      await notifyAbilityTrigger(opponent, trapper);
      addToLog(
        '${opponent.organism.baseOrganism.name}\'s ${trapper.name} prevents switching!',
      );
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    } else if (magnetTrapper.name == 'Magnet Pull' &&
        player.types.contains(ElementalType.metal) &&
        !isForced) {
      await notifyAbilityTrigger(opponent, magnetTrapper);
      addToLog(
        '${opponent.organism.baseOrganism.name}\'s ${magnetTrapper.name} prevents switching!',
      );
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 2000));
      return;
    }

    addToLog('Come back, ${player.organism.baseOrganism.name}!');
    if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));

    // Reset battle-specific flags for the animal being switched out
    player.resetBattleState();

    // Natural Cure Check
    if (player.abilities.any((ab) => ab.name == 'Natural Cure')) {
      player.clearStatusEffects();
    }

    // Regenerator Check
    if (player.abilities.any((ab) => ab.name == 'Regenerator')) {
      final heal = (player.maxHealth / 3).round();
      if (player.health < player.maxHealth) {
        player.health += heal;
        player.health = player.health.clamp(0, player.maxHealth);
      }
    }

    await _switchToAnimal(index);

    // Detect if this is a mid-turn U-turn switch (completer is waiting)
    final isMidTurnSwitch =
        _switchCompleter != null && !_switchCompleter!.isCompleted;

    if (isMidTurnSwitch) {
      // U-turn: just complete the completer so the turn flow resumes naturally
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1500));
      _switchCompleter!.complete();
      return;
    }

    if (isForced) {
      // FIX: Do not resume turn. Treat this as the end of the "faint" turn cycle.
      // isResumingTurn = true;
    } else {
      playerJustSwitched = true; // Normal switch skips player's turn action
    }
    notifyListeners();
    if (!isTesting) await Future.delayed(const Duration(milliseconds: 3000));

    if (isForced) {
      // FIX: Finalize the turn so we start a FRESH turn (resetting flags, applying weather, etc.)
      await _finalizeTurn();
      return;
    }

    // Normal switching takes a turn, so process opponent's turn
    currentState = BattleState.opponentTurn;
    await _processOpponentTurn(isCounter: false);

    await _finalizeTurn();
  }

  void _handleTurnStart(BattleOrganism attacker, Move? move) {
    if (move == null) return;
    if (move.name == 'Focus Punch') {
      attacker.focusPunchFailed = false;
      addToLog('${attacker.name} is tightening its focus!');
    } else if (move.name == 'Shell Trap') {
      attacker.shellTrapTriggered = false;
      attacker.shellTrapActive = true;
      addToLog('${attacker.name} set a shell trap!');
    }
  }

  Future<void> _finalizeTurn() async {
    if (!_checkBattleEnd()) {
      await _applyGlobalTurnEffects();
      if (_checkBattleEnd()) return;

      // Check if waiting for switch (e.g. from arena opponent fainting in global effects)
      if (currentState == BattleState.waitingForPlayerSwitch) return;

      await _applyTurnEffects(player);
      if (_checkBattleEnd()) return;
      if (currentState == BattleState.waitingForPlayerSwitch) return;

      await _applyTurnEffects(opponent);
      if (_checkBattleEnd()) return;
      if (currentState == BattleState.waitingForPlayerSwitch) return;
    }

    if (!_checkBattleEnd() &&
        currentState != BattleState.waitingForPlayerSwitch) {
      currentTurn++;
      turnHistory.add(BattleTurn(currentTurn));

      currentState = BattleState.waitingForInput;
      _startSuggestionTimer();
      // If the player is recharging or charging, the message box description
      // is handled by the UI or the log.
      addToLog('What will ${player.organism.name} do?');

      // Reset flags for next turn.
      // Fix 1: Clear switch flags here (end of turn) not at start of processPlayerAction,
      // so they remain valid throughout the entire turn execution.
      playerMovedThisTurn = false;
      opponentMovedThisTurn = false;
      opponentJustSwitched = false;
      playerJustSwitched = false;
      isResumingTurn = false;
      currentTurnOpponentMove = null;

      // Handle Perish Song
      await _handlePerishSong(player);
      await _handlePerishSong(opponent);

      // Decimate field effect counters - ONLY ONCE PER TURN
      if (_lastGlobalFinalizeTurn != currentTurn) {
        _lastGlobalFinalizeTurn = currentTurn;

        if (trickRoomTurns > 0) {
          trickRoomTurns--;
          if (trickRoomTurns == 0)
            addToLog('The dimensions returned to normal!');
        }
        if (playerTailwindTurns > 0) {
          playerTailwindTurns--;
          if (playerTailwindTurns == 0)
            addToLog('The player\'s tailwind petered out!');
        }
        if (opponentTailwindTurns > 0) {
          opponentTailwindTurns--;
          if (opponentTailwindTurns == 0)
            addToLog('The opponent\'s tailwind petered out!');
        }

        // Decimate Screen counters
        if (playerReflectTurns > 0) {
          playerReflectTurns--;
          if (playerReflectTurns == 0) addToLog('Your reflect wore off!');
        }
        if (opponentReflectTurns > 0) {
          opponentReflectTurns--;
          if (opponentReflectTurns == 0)
            addToLog('The opponent\'s reflect wore off!');
        }
        if (playerLightScreenTurns > 0) {
          playerLightScreenTurns--;
          if (playerLightScreenTurns == 0)
            addToLog('Your light screen wore off!');
        }
        if (opponentLightScreenTurns > 0) {
          opponentLightScreenTurns--;
          if (opponentLightScreenTurns == 0)
            addToLog('The opponent\'s light screen wore off!');
        }
        if (playerAuroraVeilTurns > 0) {
          playerAuroraVeilTurns--;
          if (playerAuroraVeilTurns == 0)
            addToLog('Your aurora veil wore off!');
        }
        if (opponentAuroraVeilTurns > 0) {
          opponentAuroraVeilTurns--;
          if (opponentAuroraVeilTurns == 0)
            addToLog('The opponent\'s aurora veil wore off!');
        }
      }
      // Track if we are in the middle of a multi-hit move to avoid repeating logic
      _isProcessingHits = false;

      player.isProtected = false;
      opponent.isProtected = false;
      // Fly/Dig/Dive invulnerability should persist if still charging
      if (player.chargingMove == null) {
        player.isInvulnerable = false;
        player.semiInvulnerable = null;
      }
      if (opponent.chargingMove == null) {
        opponent.isInvulnerable = false;
        opponent.semiInvulnerable = null;
      }

      if (player.laserFocusTurns > 0) player.laserFocusTurns--;
      if (opponent.laserFocusTurns > 0) opponent.laserFocusTurns--;
    }
    notifyListeners();
  }

  Future<void> _handlePerishSong(BattleOrganism target) async {
    if (target.perishTurnCount != null) {
      target.perishTurnCount = target.perishTurnCount! - 1;
      addToLog(
        '${target.name}\'s perish count fell to ${target.perishTurnCount}!',
      );
      if (target.perishTurnCount! <= 0) {
        addToLog('${target.name}\'s perish count reached zero!');
        target.health = 0;
        target.perishTurnCount = null;
        _checkBattleEnd();
      }
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1500));
    }
  }

  Future<void> _switchToAnimal(int index) async {
    if (index < 0 || index >= playerTeam.length) return;
    currentPlayerIndex = index;
    final playerOrganism = playerTeam[currentPlayerIndex];

    final int fsTurns = player.futureSightTurns;
    final BattleOrganism? fsUser = player.futureSightUser;

    player = BattleOrganism(playerOrganism, isRogueMode: isRogueMode);
    player.futureSightTurns = fsTurns;
    player.futureSightUser = fsUser;
    // Restore persistent stats
    final stats = _getStats(playerOrganism.id);
    player.totalDamageDealt = stats.totalDamageDealt;
    player.totalDamageTaken = stats.totalDamageTaken;
    player.isItemRevealed = stats.isItemRevealed;
    player.revealedMoves.addAll(stats.revealedMoves);

    playerMoves = _getOrganismMoves(playerOrganism);
    addToLog('Go, ${player.organism.baseOrganism.name}!');

    if (healingWishPending) {
      healingWishPending = false;
      player.health = player.maxHealth;
      player.clearStatusEffects();
      addToLog('${player.name} had its wish granted by the fallen friend!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1500));
    }

    // Trigger Entrance Ability
    await _checkEntranceAbility(player, opponent, biomeName);

    // Trigger Entry Hazards
    await triggerHazards(player, playerHazards);

    notifyListeners();
  }

  // --- End Check ---

  bool _checkBattleEnd() {
    if (player.health <= 0) {
      lastPlayerFaintTurn = currentTurn;
      // Check if team has more healthy animals
      final nextHealthyIndex = playerTeam.indexWhere(
        (org) =>
            org.currentHealth > 0 &&
            playerTeam.indexOf(org) != currentPlayerIndex,
      );

      if (nextHealthyIndex != -1) {
        addToLog(
          'Your ${player.organism.baseOrganism.name} fainted! Choose an animal to send out.',
        );
        currentState = BattleState.waitingForPlayerSwitch;
        notifyListeners();
        return false; // Battle continues, but waiting for switch
      }

      _result = BattleResult.loss;
      // 🚨 FIX: Reverting to baseOrganism
      addToLog(
        'Your ${player.organism.baseOrganism.name} fainted! Your whole team is defeated.',
      );
      _cleanupStatusEffects();
      currentState = BattleState.battleEnd;
      notifyListeners();
      return true;
    }
    if (opponent.health <= 0) {
      lastOpponentFaintTurn = currentTurn;
      // ARENA BATTLE: Check if opponent has more animals
      if (isArenaBattle) {
        final nextOpponentHealthy = opponentTeam.indexWhere(
          (org) => org.currentHealth > 0,
        );

        if (nextOpponentHealthy != -1) {
          addToLog(
            'Opponent\'s ${opponent.organism.baseOrganism.name} fainted!',
          );

          // Award XP for defeating this opponent animal
          if (lastBlowOrganismId != null) {
            // playerTeam is CapturedOrganism, so we need to find the BattleOrganism if it's currently out
            // but for XP awarding, we just need the killer and the victim.
            // onOpponentFainted will handle the logic.
            final killerBO = player.organism.id == lastBlowOrganismId
                ? player
                : BattleOrganism(
                    playerTeam.firstWhere((o) => o.id == lastBlowOrganismId),
                  );

            onOpponentFainted?.call(killerBO, opponent);
          }

          _switchOpponentTo(nextOpponentHealthy);
          opponentJustSwitched = true; // Prevent immediate attack
          return false; // Battle continues
        }

        // All opponent animals defeated
        _result = BattleResult.win;
        addToLog(
          'Opponent\'s ${opponent.organism.baseOrganism.name} fainted! You won the arena battle!',
        );

        // Award XP for final opponent
        if (lastBlowOrganismId != null) {
          final killerBO = player.organism.id == lastBlowOrganismId
              ? player
              : BattleOrganism(
                  playerTeam.firstWhere((o) => o.id == lastBlowOrganismId),
                );
          onOpponentFainted?.call(killerBO, opponent);
        }
        _cleanupStatusEffects();
        currentState = BattleState.battleEnd;
        onVictory?.call();
        notifyListeners();
        return true;
      }

      // WILD BATTLE: Single opponent defeat
      _result = BattleResult.win;

      // Award XP for defeating the wild animal
      if (lastBlowOrganismId != null) {
        final killerBO = player.organism.id == lastBlowOrganismId
            ? player
            : BattleOrganism(
                playerTeam.firstWhere((o) => o.id == lastBlowOrganismId),
              );
        onOpponentFainted?.call(killerBO, opponent);
      }

      // Roll for loot (only in wild battles, not Rogue-like)
      if (!isRogueMode) {
        _droppedLoot = opponent.organism.baseOrganism.rollLootDrop();
      }
      if (_droppedLoot != null) {
        addToLog(
          'The wild ${opponent.organism.baseOrganism.name} fainted! You won the battle.',
        );
        _appendToLog('\nIt dropped something!');
      } else {
        addToLog(
          'The wild ${opponent.organism.baseOrganism.name} fainted! You won the battle.',
        );
      }

      _cleanupStatusEffects();
      currentState = BattleState.battleEnd;
      onVictory?.call();
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> _switchOpponentTo(int index) async {
    if (index < 0 || index >= opponentTeam.length) return;

    // Reset battle-specific flags for the opponent being switched out
    opponent.resetBattleState();

    // Natural Cure Check
    if (opponent.abilities.any((ab) => ab.name == 'Natural Cure')) {
      opponent.clearStatusEffects();
    }

    // Regenerator Check
    if (opponent.abilities.any((ab) => ab.name == 'Regenerator')) {
      final heal = (opponent.maxHealth / 3).round();
      if (opponent.health < opponent.maxHealth) {
        opponent.health += heal;
        opponent.health = opponent.health.clamp(0, opponent.maxHealth);
      }
    }

    currentOpponentIndex = index;

    final int fsTurns = opponent.futureSightTurns;
    final BattleOrganism? fsUser = opponent.futureSightUser;

    opponent = BattleOrganism(
      opponentTeam[currentOpponentIndex],
      isRogueMode: isRogueMode,
      isOpponent: true,
    );
    opponent.futureSightTurns = fsTurns;
    opponent.futureSightUser = fsUser;
    // Restore persistent stats
    final stats = _getStats(opponentTeam[currentOpponentIndex].id);
    opponent.totalDamageDealt = stats.totalDamageDealt;
    opponent.totalDamageTaken = stats.totalDamageTaken;
    opponent.isItemRevealed = stats.isItemRevealed;
    opponent.revealedMoves.addAll(stats.revealedMoves);
    opponentMoves = _getOrganismMoves(opponentTeam[currentOpponentIndex]);

    addToLog('${opponent.name} enters the field!');

    if (healingWishPending) {
      healingWishPending = false;
      opponent.health = opponent.maxHealth;
      opponent.clearStatusEffects();
      addToLog('${opponent.name} had its wish granted by the fallen friend!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1500));
    }

    // Trigger Entrance Ability
    await _checkEntranceAbility(opponent, player, biomeName);

    // Trigger Entry Hazards
    await triggerHazards(opponent, opponentHazards);

    notifyListeners();
  }

  DamageResult calculateDamage(
    BattleOrganism attacker,
    BattleOrganism defender,
    Move move, {
    bool ignoreRandom = false,
  }) {
    if (move.name == 'Counter') {
      if (attacker.lastPhysicalDamageTaken > 0) {
        return DamageResult(attacker.lastPhysicalDamageTaken * 2, 1.0, false);
      }
      return const DamageResult(0, 1.0, false);
    }
    if (move.name == 'Mirror Coat') {
      if (attacker.lastSpecialDamageTaken > 0) {
        return DamageResult(attacker.lastSpecialDamageTaken * 2, 1.0, false);
      }
      return const DamageResult(0, 1.0, false);
    }

    if (move.baseDamage <= 0) return const DamageResult(0, 1.0, false);

    bool isCrit = false;
    double critChance = 6.25;

    // Talisman crit boost
    if (attacker.organism.equippedTalisman != null) {
      for (final effect in attacker.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.critBoost) {
          critChance += effect.magnitude;
        }
      }
    }

    // Ability crit boosts (Super Luck)
    if (attacker.abilities.any((ab) => ab.name == 'Super Luck')) {
      if (critChance <= 6.25) {
        critChance = 12.5;
      } else if (critChance <= 12.5) {
        critChance = 50.0;
      } else {
        critChance = 100.0;
      }
    }

    // Move-specific crit rate
    if (move.critRate == 1) critChance = 12.5;
    if (move.critRate == 2) critChance = 50.0;
    if (move.critRate >= 3) critChance = 100.0;

    if (attacker.focusEnergyActive) {
      if (critChance < 50.0) critChance = 50.0;
    }

    if (attacker.laserFocusTurns > 0) {
      critChance = 100.0;
    }

    // Merciless Ability: Guaranteed crit against poisoned targets
    if (attacker.abilities.any((ab) => ab.name == 'Merciless') &&
        defender.statusEffects.any(
          (se) => se.type == StatusEffectType.poison,
        )) {
      isCrit = true;
    } else if (!ignoreRandom && Random().nextDouble() * 100 < critChance) {
      isCrit = true;
    }

    if (ignoreRandom) isCrit = false;

    // Battle Armor / Shell Armor blocks crits
    if (defender.abilities.any(
      (ab) => ab.name == 'Battle Armor' || ab.name == 'Shell Armor',
    )) {
      isCrit = false;
    }

    if (move.name == 'Endeavor') {
      if (defender.health > attacker.health) {
        return DamageResult(defender.health - attacker.health, 1.0, false);
      }
      return const DamageResult(0, 1.0, false);
    }

    if (move.name == 'Nature\'s Madness') {
      return DamageResult(max(1, (defender.health / 2).floor()), 1.0, false);
    }

    // 1. Determine Stats (Atk/Def or Power/Res)
    int atk = (move.category == MoveCategory.special)
        ? attacker.currentPower
        : attacker.currentAttack;
    int def = (move.category == MoveCategory.special)
        ? defender.currentResistance
        : defender.currentDefense;

    if (move.name == 'Sacred Sword') {
      def = defender.organism.getDefense(atLevel: defender.level);
    }

    // Psyshock: Special move targets Physical Defense
    if (move.name == 'Psyshock') {
      def = defender.currentDefense;
    }

    // Stat overrides
    if (move.damageStat.isNotEmpty) {
      switch (move.damageStat) {
        case 'attack':
          atk = attacker.currentAttack;
          break;
        case 'power':
          atk = attacker.currentPower;
          break;
        case 'defense':
          atk = attacker.currentDefense;
          break;
        case 'resistance':
          atk = attacker.currentResistance;
          break;
        case 'speed':
          atk = attacker.currentSpeed;
          break;
      }
    }

    // 2. Base Damage Substitutions
    int baseDamage = move.baseDamage;

    final hpRatioEffect = move.effects.firstWhere(
      (e) => e.type == MoveEffectType.hpRatioDamage,
      orElse: () => const MoveEffect(type: MoveEffectType.none),
    );
    if (hpRatioEffect.type != MoveEffectType.none) {
      if (move.name == 'Crush Grip' || move.name == 'Hard Press') {
        baseDamage = (baseDamage * (defender.health / defender.maxHealth))
            .round();
      } else {
        baseDamage = (baseDamage * (attacker.health / attacker.maxHealth))
            .round();
      }
      baseDamage = max(1, baseDamage);
    }

    final flailEffect = move.effects.firstWhere(
      (e) => e.type == MoveEffectType.flailDamage,
      orElse: () => const MoveEffect(type: MoveEffectType.none),
    );
    if (flailEffect.type != MoveEffectType.none) {
      final ratio = attacker.health / attacker.maxHealth;
      if (ratio < 0.0417) {
        baseDamage = 200;
      } else if (ratio < 0.1042) {
        baseDamage = 150;
      } else if (ratio < 0.2083) {
        baseDamage = 100;
      } else if (ratio < 0.3542) {
        baseDamage = 80;
      } else if (ratio < 0.6875) {
        baseDamage = 40;
      } else {
        baseDamage = 20;
      }
    }

    final happinessEffect = move.effects.firstWhere(
      (e) => e.type == MoveEffectType.happinessDamage,
      orElse: () => const MoveEffect(type: MoveEffectType.none),
    );
    if (happinessEffect.type != MoveEffectType.none) {
      if (move.name == 'Return') {
        baseDamage = (attacker.organism.satisfaction / 2.5).round();
      } else if (move.name == 'Frustration') {
        baseDamage = ((255 - attacker.organism.satisfaction) / 2.5).round();
      }
      baseDamage = max(1, baseDamage);
    }

    final weightOpponentEffect = move.effects.firstWhere(
      (e) => e.type == MoveEffectType.weightOpponentDamage,
      orElse: () => const MoveEffect(type: MoveEffectType.none),
    );
    if (weightOpponentEffect.type != MoveEffectType.none) {
      final w = defender.organism.baseOrganism.weight;
      if (w >= 200) {
        baseDamage = 120;
      } else if (w >= 100) {
        baseDamage = 100;
      } else if (w >= 50) {
        baseDamage = 80;
      } else if (w >= 25) {
        baseDamage = 60;
      } else if (w >= 10) {
        baseDamage = 40;
      } else {
        baseDamage = 20;
      }
    }

    final gyroBallEffect = move.effects.firstWhere(
      (e) => e.type == MoveEffectType.gyroBallDamage,
      orElse: () => const MoveEffect(type: MoveEffectType.none),
    );
    if (gyroBallEffect.type != MoveEffectType.none) {
      baseDamage = (25 * defender.currentSpeed / attacker.currentSpeed).round();
      if (baseDamage > 150) baseDamage = 150;
      if (baseDamage < 1) baseDamage = 1;
    }

    final weightEffect = move.effects.firstWhere(
      (e) => e.type == MoveEffectType.weightDamage,
      orElse: () => const MoveEffect(type: MoveEffectType.none),
    );
    if (weightEffect.type != MoveEffectType.none) {
      final ratio =
          attacker.organism.baseOrganism.weight /
          defender.organism.baseOrganism.weight;
      if (ratio >= 5) {
        baseDamage = 120;
      } else if (ratio >= 4) {
        baseDamage = 100;
      } else if (ratio >= 3) {
        baseDamage = 80;
      } else if (ratio >= 2) {
        baseDamage = 60;
      } else {
        baseDamage = 40;
      }
    }

    final magnitudeEffect = move.effects.firstWhere(
      (e) => e.type == MoveEffectType.magnitude,
      orElse: () => const MoveEffect(type: MoveEffectType.none),
    );
    if (magnitudeEffect.type != MoveEffectType.none) {
      final roll = Random().nextInt(100);
      int mag;
      if (roll < 5) {
        mag = 4;
        baseDamage = 10;
      } else if (roll < 15) {
        mag = 5;
        baseDamage = 30;
      } else if (roll < 35) {
        mag = 6;
        baseDamage = 50;
      } else if (roll < 65) {
        mag = 7;
        baseDamage = 70;
      } else if (roll < 85) {
        mag = 8;
        baseDamage = 90;
      } else if (roll < 95) {
        mag = 9;
        baseDamage = 110;
      } else {
        mag = 10;
        baseDamage = 150;
      }
      addToLog('Magnitude $mag!');
    }

    // Acrobatics Boost (2x if no item or consumed)
    if (move.name == 'Acrobatics') {
      if (attacker.organism.equippedTalisman == null ||
          attacker.talismanConsumed) {
        baseDamage *= 2;
      }
    }

    if (move.name == 'Retaliate') {
      int lastFaint = attacker.isPlayer
          ? lastPlayerFaintTurn
          : lastOpponentFaintTurn;
      if (lastFaint == currentTurn - 1 && lastFaint != -1) {
        baseDamage *= 2;
      }
    }

    if (move.name == 'Brine') {
      if (defender.health <= (defender.maxHealth / 2)) {
        baseDamage *= 2;
      }
    }

    // Rollout/Ice Ball stacking
    if (move.name == 'Rollout' || move.name == 'Ice Ball') {
      baseDamage *= (1 << attacker.rolloutTurnCount);
      if (attacker.usedDefenseCurl) baseDamage *= 2;
    }

    // 3. Core Damage Formula
    double damageCalc =
        ((2 * attacker.level / 5 + (ignoreRandom ? 0 : 2)) *
                baseDamage *
                atk /
                def) /
            50 +
        (ignoreRandom ? 0 : 2);

    // 4. Multipliers
    if (isCrit) damageCalc *= 1.5;

    // Lash Out
    if (move.name == 'Lash Out' && attacker.statsLoweredThisTurn) {
      damageCalc *= 2.0;
    }

    // Hex
    if (move.name == 'Hex' && defender.statusEffects.isNotEmpty) {
      damageCalc *= 2.0;
    }

    ElementalType moveType = move.type;

    // Weather Ball
    if (move.effects.any((e) => e.type == MoveEffectType.weatherBall)) {
      if (currentWeather.weather != Weather.none) {
        baseDamage *= 2;
        switch (currentWeather.weather) {
          case Weather.rain:
          case Weather.heavyRain:
          case Weather.thunderstorm:
            moveType = ElementalType.aquatic;
            break;
          case Weather.sunny:
            moveType = ElementalType.blaze;
            break;
          case Weather.sandstorm:
            moveType = ElementalType.rock;
            break;
          case Weather.hail:
          case Weather.snowstorm:
            moveType = ElementalType.cryo;
            break;
          default:
            break;
        }
      }
    }

    // Hidden Power
    if (move.effects.any((e) => e.type == MoveEffectType.hiddenPower) ||
        move.name == 'Hidden Power') {
      int typeIndex = 0;
      final stats = [
        'health',
        'attack',
        'defense',
        'speed',
        'power',
        'resistance',
      ];
      for (int k = 0; k < stats.length; k++) {
        if ((attacker.organism.individualValues[stats[k]] ?? 0) % 2 != 0) {
          typeIndex += (1 << k);
        }
      }
      final types = ElementalType.values
          .where((t) => t != ElementalType.basic)
          .toList();
      moveType = types[(typeIndex * types.length / 64).floor()];
    }

    // Multi-Attack
    if (move.effects.any((e) => e.type == MoveEffectType.multiAttack)) {
      final item = attacker.organism.equippedTalisman;
      if (item != null && item.id.endsWith('_memory')) {
        final part = item.id.split('_').first;
        moveType = _getTypeFromItemName(part);
      }
    }

    // Judgement
    if (move.effects.any((e) => e.type == MoveEffectType.judgement)) {
      final item = attacker.organism.equippedTalisman;
      if (item != null && item.id.endsWith('_plate')) {
        final part = item.id.split('_').first;
        moveType = _getTypeFromItemName(part);
      }
    }

    // Weather Modifiers
    double weatherMod = currentWeather.getDamageMultiplier(
      moveType.toString().split('.').last.toLowerCase(),
    );
    damageCalc *= weatherMod;

    // Snowstorm Cryo Physical Defense Buff
    if (currentWeather.weather == Weather.snowstorm &&
        defender.types.contains(ElementalType.cryo) &&
        move.category == MoveCategory.physical) {
      damageCalc *= (1 / 1.5);
    }

    // Type Effectiveness
    double typeMod = 1.0;
    bool attackerHasTrueFlight = attacker.abilities.any(
      (ab) => ab.name == 'True Flight',
    );
    bool defenderHasTrueFlight = defender.abilities.any(
      (ab) => ab.name == 'True Flight',
    );
    bool defenderHasAirBalloon =
        defender.organism.equippedTalisman != null &&
        !defender.talismanConsumed &&
        defender.organism.equippedTalisman!.effects.any(
          (e) => e.type == TalismanEffectType.airBalloon,
        );

    for (final defType in defender.types) {
      double eff = TypeChart.getEffectiveness(moveType, defType);

      // Earth Eater / True Flight / Air Balloon Earth Immunity
      if (moveType == ElementalType.earth) {
        if (defender.abilities.any((ab) => ab.name == 'Earth Eater')) {
          eff = 0.0;
        } else if (gravityTurns > 0) {
          // Gravity allows hitting Flying/Levitating targets
          if (defType == ElementalType.flying) eff = 1.0;
        } else if (defenderHasTrueFlight ||
            defenderHasAirBalloon ||
            defType == ElementalType.flying) {
          eff = 0.0;
        }
      }

      // Miracle Eye: Psychic hits Dark
      if (moveType == ElementalType.aura &&
          defType == ElementalType.darkness &&
          defender.isMiracleEyed) {
        eff = 1.0;
      }

      // Water Absorb / Dry Skin Water Immunity
      if (moveType == ElementalType.aquatic &&
          defender.abilities.any(
            (ab) => ab.name == 'Water Absorb' || ab.name == 'Dry Skin',
          )) {
        eff = 0.0;
      }

      // True Flight defensive perks (Min 1.0 effectiveness for weaknesses)
      if (defenderHasTrueFlight &&
          defender.types.contains(ElementalType.flying)) {
        if (moveType == ElementalType.electric ||
            moveType == ElementalType.rock ||
            moveType == ElementalType.cryo) {
          if (eff > 1.0) eff = 1.0;
        }
      }

      // True Flight offensive perks (Avoid resistance)
      if (attackerHasTrueFlight && moveType == ElementalType.flying) {
        if (eff < 1.0 && eff > 0) eff = 1.0;
      }

      typeMod *= eff;
    }

    // Tinted Lens
    if (typeMod < 1.0 &&
        attacker.abilities.any((ab) => ab.name == 'Tinted Lens')) {
      typeMod *= 2.0;
    }

    damageCalc *= typeMod;

    if (defender.glaiveRushVulnerable) {
      damageCalc *= 2.0;
    }

    // Weakness Berry
    if (typeMod > 1.0 &&
        defender.organism.equippedTalisman != null &&
        !defender.talismanConsumed) {
      final moveTypeName = move.type.toString().split('.').last.toLowerCase();
      for (final bEffect in defender.organism.equippedTalisman!.effects) {
        if (bEffect.type == TalismanEffectType.berryTypeResist &&
            bEffect.stat == moveTypeName) {
          damageCalc *= bEffect.magnitude;
          break;
        }
      }
    }

    // STAB
    if (attacker.types.contains(move.type)) {
      double stabBonus = 1.5;
      if (attacker.abilities.any((ab) => ab.name == 'Adaptability')) {
        stabBonus = 2.0;
      }
      damageCalc *= stabBonus;
    }

    // Ability Multipliers - Only apply if not already handled in stats (e.g. Iron Fist, Strong Jaw)
    for (final ab in attacker.abilities) {
      if (ab.name == 'Iron Fist' && move.isPunch) damageCalc *= ab.magnitude;
      if (ab.name == 'Strong Jaw' && move.isBite) damageCalc *= ab.magnitude;
      if (ab.name == 'Tough Claws' && move.isContact)
        damageCalc *= ab.magnitude;
      if (ab.name == 'Reckless' && move.recoilPercent > 0)
        damageCalc *= ab.magnitude;
      if (ab.name == 'Stakeout' &&
          (defender.isPlayer ? playerJustSwitched : opponentJustSwitched))
        damageCalc *= 2.0;
      if (ab.name == 'Analytic') {
        bool movingLast =
            (attacker.isPlayer && opponentMovedThisTurn) ||
            (attacker.isOpponent && playerMovedThisTurn);
        if (movingLast) damageCalc *= 1.3;
      }
      // Note: Guts is handled in BattleOrganism.currentAttack
    }

    for (final ab in defender.abilities) {
      if (ab.name == 'Heatproof' && move.type == ElementalType.blaze) {
        damageCalc *= ab.magnitude;
      }
      if (ab.name == 'Multiscale' && defender.health == defender.maxHealth) {
        damageCalc *= ab.magnitude;
      }
      if (ab.name == 'Dry Skin' && move.type == ElementalType.blaze) {
        damageCalc *= 1.25;
      }
      if (ab.name == 'Fur Coat' && move.category == MoveCategory.physical) {
        damageCalc *= 0.5;
      }
      if (ab.name == 'Thick Fat' &&
          (move.type == ElementalType.blaze ||
              move.type == ElementalType.cryo)) {
        damageCalc *= 0.5;
      }
    }

    // Move-specific Multipliers
    if (move.name == 'Facade' && attacker.statusEffects.isNotEmpty) {
      damageCalc *= 2.0;
    }
    if (move.name == 'Knock Off' &&
        defender.organism.equippedTalisman != null &&
        !defender.talismanConsumed) {
      damageCalc *= 1.5;
    }
    if (move.name == 'Freeze-Dry' &&
        defender.types.contains(ElementalType.aquatic)) {
      damageCalc *= 2.0;
    }
    if (move.name == 'Final Gambit') damageCalc = attacker.health.toDouble();

    final hexEffect = move.effects.firstWhere(
      (e) => e.type == MoveEffectType.hexDamage,
      orElse: () => const MoveEffect(type: MoveEffectType.none),
    );
    if (hexEffect.type != MoveEffectType.none) {
      if (defender.statusEffects.any(
        (se) => se.type != StatusEffectType.none,
      )) {
        damageCalc *= 2.0;
      }
    }

    if (move.name == 'Lash Out' && attacker.statsLoweredThisTurn) {
      damageCalc *= 2.0;
    }

    if (move.name == 'Mighty Cleave') {
      // Logic for hitting through protect will be in _executeTurn
    }

    if (move.name == 'Counter') {
      if (attacker.lastPhysicalDamageTaken > 0) {
        damageCalc = attacker.lastPhysicalDamageTaken * 2.0;
      } else {
        damageCalc = 0;
      }
    } else if (move.name == 'Mirror Coat') {
      if (attacker.lastSpecialDamageTaken > 0) {
        damageCalc = attacker.lastSpecialDamageTaken * 2.0;
      } else {
        damageCalc = 0;
      }
    }

    final moveFirstEffect = move.effects.firstWhere(
      (e) => e.type == MoveEffectType.moveFirstBoost,
      orElse: () => const MoveEffect(type: MoveEffectType.none),
    );
    if (moveFirstEffect.type != MoveEffectType.none) {
      bool movedFirst =
          (attacker.isPlayer && !opponentMovedThisTurn) ||
          (attacker.isOpponent && !playerMovedThisTurn);
      if (movedFirst) {
        damageCalc *= 2.0;
      }
    }

    // Conditionals
    if (move.multiplierCondition.isNotEmpty) {
      final condition = move.multiplierCondition.toLowerCase();
      if (condition == 'target_poisoned' &&
          defender.statusEffects.any(
            (se) => se.type == StatusEffectType.poison,
          )) {
        damageCalc *= move.conditionalMultiplier;
      } else if (condition == 'target_damaged' && defender.tookDamageThisTurn) {
        damageCalc *= move.conditionalMultiplier;
      } else if (condition == 'target_statused' &&
          defender.statusEffects.isNotEmpty) {
        damageCalc *= move.conditionalMultiplier;
      }
    }

    // Status Modifiers
    if (defender.statusEffects.any(
      (se) => se.type == StatusEffectType.vulnerable,
    )) {
      damageCalc *= 1.3;
    }
    if (defender.statusEffects.any(
      (se) => se.type == StatusEffectType.marked,
    )) {
      damageCalc *= 1.2;
    }
    if (attacker.statusEffects.any(
      (se) => se.type == StatusEffectType.stealth,
    )) {
      damageCalc *= 2.0;
    }
    if (defender.statusEffects.any(
      (se) => se.type == StatusEffectType.stealth,
    )) {
      if (!attacker.abilities.any((ab) => ab.name == 'Echolocation')) {
        damageCalc *= 2.0;
      }
    }

    // Talisman Multipliers
    if (attacker.organism.equippedTalisman != null) {
      for (final effect in attacker.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.damageMultiplier ||
            effect.type == TalismanEffectType.damageBoost) {
          damageCalc *= effect.magnitude;
        }
        if (effect.type == TalismanEffectType.categoryDamageBoost) {
          if ((effect.category == 'physical' &&
                  move.category == MoveCategory.physical) ||
              (effect.category == 'special' &&
                  move.category == MoveCategory.special)) {
            damageCalc *= effect.magnitude;
          }
        }
      }
    }

    if (defender.organism.equippedTalisman != null) {
      for (final effect in defender.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.resistanceBoost) {
          damageCalc *= effect.magnitude;
        }
      }
    }

    // Screens
    final bool hasAuroraVeil = defender.isPlayer
        ? playerAuroraVeilTurns > 0
        : opponentAuroraVeilTurns > 0;
    final bool hasReflect = defender.isPlayer
        ? playerReflectTurns > 0
        : opponentReflectTurns > 0;
    final bool hasLightScreen = defender.isPlayer
        ? playerLightScreenTurns > 0
        : opponentLightScreenTurns > 0;

    if (!isCrit && !attacker.abilities.any((ab) => ab.name == 'Infiltrator')) {
      if (hasAuroraVeil) {
        damageCalc *= 0.5;
      } else if (move.category == MoveCategory.physical && hasReflect) {
        damageCalc *= 0.5;
      } else if (move.category == MoveCategory.special && hasLightScreen) {
        damageCalc *= 0.5;
      }
    }

    // Final variation
    if (!ignoreRandom) {
      // Random Variance (0.85 to 1.0)
      damageCalc *= (0.85 + (Random().nextDouble() * 0.15));
    }

    return DamageResult(damageCalc.round(), typeMod, isCrit);
  }

  void _cleanupStatusEffects() {
    for (var captured in playerTeam) {
      if (!isRogueMode) {
        captured.statusEffects = [];
      }
      // Reset stat stages always at the end of a battle
      captured.attackStage = 0;
      captured.defenseStage = 0;
      captured.powerStage = 0;
      captured.resistanceStage = 0;
      captured.speedStage = 0;
      captured.accuracyStage = 0;
    }
    // Also reset stat stages for the opponent team
    for (var opponent in opponentTeam) {
      opponent.attackStage = 0;
      opponent.defenseStage = 0;
      opponent.powerStage = 0;
      opponent.resistanceStage = 0;
      opponent.speedStage = 0;
      opponent.accuracyStage = 0;
    }
  }

  /// Pause all audio (called when app goes to background)
  void pauseAudio() {
    _audioService.pauseAll();
  }

  /// Resume audio (called when app returns to foreearth)
  void resumeAudio() {
    _audioService.resumeAll();
  }

  // --- Testing Hooks ---
  @visibleForTesting
  Future<bool> testApplyStatusEffect(
    BattleOrganism target,
    StatusEffectType type,
  ) async {
    return await applyStatusEffect(target, type, chance: 100);
  }

  @visibleForTesting
  Future<void> testApplyMoveEffect(
    BattleOrganism attacker,
    BattleOrganism defender,
    List<MoveEffect> effects,
    Move move,
  ) async {
    return _applyMoveEffect(attacker, defender, effects, move);
  }

  @visibleForTesting
  Future<void> testApplyStatChange(
    BattleOrganism target,
    String stat,
    int value,
  ) async {
    return applyStatChange(target, stat, value);
  }

  @visibleForTesting
  Future<void> testCalculateDamage(
    BattleOrganism attacker,
    BattleOrganism defender,
    Move move,
  ) async {
    // This is a synchronous method, so we wrap it for consistency
    calculateDamage(attacker, defender, move);
  }

  @visibleForTesting
  Future<void> testApplyTurnEffects(BattleOrganism target) async {
    return _applyTurnEffects(target);
  }

  @visibleForTesting
  Future<void> testExecuteTurn(
    BattleOrganism attacker,
    BattleOrganism defender,
    Move move,
  ) async {
    return _executeTurn(attacker, defender, move);
  }

  // =====================================================================
  // BERRY HELPER METHODS
  // =====================================================================

  List<Move> getValidMoves(BattleOrganism org) {
    List<Move> moves = org.isOpponent ? opponentMoves : playerMoves;
    List<Move> validMoves = List.from(moves);
    final other = org.isOpponent ? player : opponent;

    // 1. Encore
    if (org.encoreTurns > 0 && org.lastMove != null) {
      if (moves.any((m) => m.name == org.lastMove!.name)) {
        return [moves.firstWhere((m) => m.name == org.lastMove!.name)];
      }
    }

    // Rollout/Ice Ball Lock
    if (org.rolloutTurnCount > 0 && org.rolloutMove != null) {
      if (moves.any((m) => m.name == org.rolloutMove!.name)) {
        return [moves.firstWhere((m) => m.name == org.rolloutMove!.name)];
      }
    }

    // Thrash/Outrage/Petal Dance Lock
    if (org.thrashTurnCount > 0 && org.thrashMove != null) {
      return [org.thrashMove!];
    }

    // 2. Taunt
    if (org.tauntTurns > 0) {
      validMoves = validMoves
          .where((m) => m.category != MoveCategory.status)
          .toList();
    }

    // 3. Imprison
    if (other.isImprisoning) {
      final otherMoves = org.isOpponent ? playerMoves : opponentMoves;
      validMoves = validMoves
          .where((m) => !otherMoves.any((om) => om.name == m.name))
          .toList();
    }

    // 4. Choice Lock
    if (org.isChoiceLocked && org.lockedMove != null) {
      validMoves = validMoves
          .where((m) => m.name == org.lockedMove!.name)
          .toList();
    }

    // 5. Special Multi-turn States (Recharge/Charge)
    // If in these states, the only "valid" move is the one being continued
    // but we return a filtered list so the UI knows we are locked in.
    if (org.mustRecharge) {
      // Return a dummy list or the last move?
      // For now, let's keep the moves but we'll handle the UI blocking.
      // Actually, it's better to return something that processPlayerAction can use.
      if (org.lastMove != null &&
          moves.any((m) => m.name == org.lastMove!.name)) {
        return [moves.firstWhere((m) => m.name == org.lastMove!.name)];
      }
    }

    if (org.chargingMove != null) {
      if (moves.any((m) => m.name == org.chargingMove!.name)) {
        return [moves.firstWhere((m) => m.name == org.chargingMove!.name)];
      } else {
        // Fallback for moves not in current moveset (e.g. from Mirror Move? Unlikely here)
        return [org.chargingMove!];
      }
    }

    // 6. Damp (prevents self-destruct moves)
    if (org.abilities.any((a) => a.name == 'Damp') ||
        other.abilities.any((a) => a.name == 'Damp')) {
      validMoves = validMoves
          .where((m) => m.name != 'Explosion' && m.name != 'Self-Destruct')
          .toList();
    }

    // 7. Armor Tail / Dazzling / Queenly Majesty (prevents priority moves against them)
    if (other.abilities.any(
      (a) =>
          a.name == 'Armor Tail' ||
          a.name == 'Dazzling' ||
          a.name == 'Queenly Majesty',
    )) {
      validMoves = validMoves
          .where(
            (m) => m.priority <= 0 || m.effects.any((e) => e.target == 'self'),
          )
          .toList();
    }

    // 8. Gorilla Tactics (Lock)
    if (org.abilities.any((a) => a.name == 'Gorilla Tactics') &&
        org.lockedMove != null) {
      if (validMoves.any((m) => m.name == org.lockedMove!.name)) {
        validMoves = [
          validMoves.firstWhere((m) => m.name == org.lockedMove!.name),
        ];
      }
    }

    // 9. Move Stamina check
    // If a move has 0 stamina, it's not valid.
    validMoves = validMoves.where((m) {
      final stamina = org.organism.moveStamina[m.name] ?? 0;
      return stamina > 0;
    }).toList();

    // 10. Assault Vest (Block status moves)
    if (org.organism.equippedTalisman != null && !org.talismanConsumed) {
      final hasVestLock = org.organism.equippedTalisman!.effects.any(
        (e) => e.type == TalismanEffectType.blockStatusMoves,
      );
      if (hasVestLock) {
        validMoves = validMoves
            .where((m) => m.category != MoveCategory.status)
            .toList();
      }
    }

    return validMoves;
  }

  Move pickOpponentMove() {
    if (opponent.rolloutTurnCount > 0 && opponent.rolloutMove != null) {
      return opponent.rolloutMove!;
    }
    if (opponent.thrashTurnCount > 0 && opponent.thrashMove != null) {
      return opponent.thrashMove!;
    }
    if (opponent.chargingMove != null) return opponent.chargingMove!;

    final validMoves = getValidMoves(opponent);

    if (validMoves.isEmpty) {
      // Struggle fallback
      return Move.findOrCreate('Struggle');
    }

    // AI Context preparation (convert teams to BO once for this decision)
    final aiTeamBO = opponentTeam
        .map(
          (org) =>
              BattleOrganism(org, isRogueMode: isRogueMode, isOpponent: true),
        )
        .toList();
    final playerTeamBO = playerTeam
        .map(
          (org) =>
              BattleOrganism(org, isRogueMode: isRogueMode, isOpponent: false),
        )
        .toList();

    double bestScore = -double.infinity;
    Move bestMove = validMoves[0];

    for (final move in validMoves) {
      final score = scoreMove(
        move,
        opponent,
        player,
        aiTeam: aiTeamBO,
        playerTeam: playerTeamBO,
      );
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    _recordOpponentMove(bestMove);
    if (bestMove.name == 'Rollout' || bestMove.name == 'Ice Ball') {
      opponent.rolloutMove = bestMove;
    }
    return bestMove;
  }

  void _recordOpponentMove(Move move) {
    opponentLastUsedMoves.add(move.name);
    if (opponentLastUsedMoves.length > 3) {
      opponentLastUsedMoves.removeAt(0);
    }
  }

  double scoreMove(
    Move move,
    BattleOrganism attacker,
    BattleOrganism defender, {
    List<BattleOrganism>? aiTeam,
    List<BattleOrganism>? playerTeam,
  }) {
    final damageResult = calculateDamage(attacker, defender, move);
    return AIDecisionEngine.calculateMoveScore(
      move: move,
      attacker: attacker,
      defender: defender,
      damageResult: damageResult,
      targetHazards: defender.isOpponent ? opponentHazards : playerHazards,
      currentEffect: currentWeather,
      currentTerrain: currentTerrain,
      aiTeam: aiTeam,
      playerTeam: playerTeam,
      playerHistory: playerHistory,
      lastUsedMoves: opponentLastUsedMoves,
      archetype: opponentArchetype,
      isTrickRoomActive: trickRoomTurns > 0,
      targetHasReflect: defender.isPlayer
          ? playerReflectTurns > 0
          : opponentReflectTurns > 0,
      targetHasLightScreen: defender.isPlayer
          ? playerLightScreenTurns > 0
          : opponentLightScreenTurns > 0,
      targetHasAuroraVeil: defender.isPlayer
          ? playerAuroraVeilTurns > 0
          : opponentAuroraVeilTurns > 0,
      targetHasSubstitute: defender.substituteHealth > 0,
    );
  }

  int? _shouldOpponentSwitch() {
    // Only switch if team has other healthy members
    final healthyTeammates = opponentTeam.where((org) => org.currentHealth > 0);
    if (healthyTeammates.length <= 1) return null;

    // Cooldown check: don't switch too often (e.g., 3 turns minimum)
    if (lastOpponentSwitchTurn != null &&
        (currentTurn - lastOpponentSwitchTurn!) < 3) {
      return null;
    }

    final aiTeamBO = opponentTeam
        .map(
          (org) =>
              BattleOrganism(org, isRogueMode: isRogueMode, isOpponent: true),
        )
        .toList();

    final bench = aiTeamBO
        .where(
          (org) => org.organism.id != opponent.organism.id && org.health > 0,
        )
        .toList();

    if (bench.isEmpty) return null;

    final decision = AIDecisionEngine.shouldSwitch(
      activeMon: opponent,
      bench: bench,
      opponent: player,
      playerHazards: playerHazards,
      playerHistory: playerHistory,
      archetype: opponentArchetype,
      estimateOpponentDamage: (attacker, defender) {
        double maxDmg = 1.0;
        final moves = _getOrganismMoves(attacker.organism);
        for (final m in moves) {
          final res = calculateDamage(
            attacker,
            defender,
            m,
            ignoreRandom: true,
          );
          if (res.damage > maxDmg) maxDmg = res.damage.toDouble();
        }
        return maxDmg;
      },
      estimateOurDamage: (attacker, defender) {
        double maxDmg = 1.0;
        final moves = _getOrganismMoves(attacker.organism);
        for (final m in moves) {
          final res = calculateDamage(
            attacker,
            defender,
            m,
            ignoreRandom: true,
          );
          if (res.damage > maxDmg) maxDmg = res.damage.toDouble();
        }
        return maxDmg;
      },
    );

    if (decision.shouldSwitch && decision.bestBenchIndex != null) {
      final targetId = bench[decision.bestBenchIndex!].organism.id;
      final idx = opponentTeam.indexWhere((org) => org.id == targetId);
      return idx != -1 ? idx : null;
    }

    return null;
  }

  /// when the holder's HP is below the berry's threshold.
  Future<void> _checkAndTriggerHealBerry(BattleOrganism target) async {
    if (target.health <= 0) return;
    if (target.organism.equippedTalisman == null) return;
    if (target.talismanConsumed) return;

    for (final effect in target.organism.equippedTalisman!.effects) {
      final hpRatio = target.health / target.maxHealth;

      double activeThreshold = effect.threshold;
      if (activeThreshold > 0 &&
          activeThreshold <= 0.25 &&
          target.abilities.any((ab) => ab.name == 'Gluttony')) {
        activeThreshold = 0.5;
        await notifyAbilityTrigger(
          target,
          target.abilities.firstWhere((a) => a.name == 'Gluttony'),
        );
      }

      if (activeThreshold > 0 && hpRatio > activeThreshold) continue;

      if (effect.type == TalismanEffectType.berryHealPercent) {
        int applications = target.abilities.any((ab) => ab.name == 'Cud Chew')
            ? 2
            : 1;
        for (int i = 0; i < applications; i++) {
          final healAmount = (target.maxHealth * effect.magnitude).round();
          target.health = (target.health + healAmount).clamp(
            0,
            target.maxHealth,
          );
        }
        target.talismanConsumed = true;
        target.isItemRevealed = true;
        _getStats(target.organism.id).isItemRevealed = true;
        addToLog(
          '${target.organism.name} ate its ${target.organism.equippedTalisman!.name}!',
        );
        await _audioService.playSound('audio/effects/heal.mp3');

        if (target.abilities.any((ab) => ab.name == 'Cheek Pouch')) {
          final cheekHeal = (target.maxHealth / 3).round();
          target.health = (target.health + cheekHeal).clamp(
            0,
            target.maxHealth,
          );
          await notifyAbilityTrigger(
            target,
            target.abilities.firstWhere((a) => a.name == 'Cheek Pouch'),
          );
          addToLog('${target.organism.name} restored HP due to Cheek Pouch!');
        }

        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
        return;
      } else if (effect.type == TalismanEffectType.berryHealFlat) {
        int applications = target.abilities.any((ab) => ab.name == 'Cud Chew')
            ? 2
            : 1;
        for (int i = 0; i < applications; i++) {
          final healAmount = effect.magnitude.round();
          target.health = (target.health + healAmount).clamp(
            0,
            target.maxHealth,
          );
        }
        target.talismanConsumed = true;
        target.isItemRevealed = true;
        _getStats(target.organism.id).isItemRevealed = true;
        addToLog(
          '${target.organism.name} ate its ${target.organism.equippedTalisman!.name}!',
        );
        await _audioService.playSound('audio/effects/heal.mp3');

        if (target.abilities.any((ab) => ab.name == 'Cheek Pouch')) {
          final cheekHeal = (target.maxHealth / 3).round();
          target.health = (target.health + cheekHeal).clamp(
            0,
            target.maxHealth,
          );
          await notifyAbilityTrigger(
            target,
            target.abilities.firstWhere((a) => a.name == 'Cheek Pouch'),
          );
          addToLog('${target.organism.name} restored HP due to Cheek Pouch!');
        }

        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
        return;
      }
    }
  }

  /// Checks and triggers berry stat boosts (Salac/Petaya/Liechi/Lansat)
  /// when the holder's HP falls below the berry's threshold.
  Future<void> _checkAndTriggerStatBerry(BattleOrganism target) async {
    if (target.health <= 0) return;
    if (target.organism.equippedTalisman == null) return;
    if (target.talismanConsumed) return;

    for (final effect in target.organism.equippedTalisman!.effects) {
      if (effect.threshold <= 0) continue;
      final hpRatio = target.health / target.maxHealth;
      if (hpRatio >= effect.threshold) continue;

      if (effect.type == TalismanEffectType.berryStatBoost) {
        target.talismanConsumed = true;
        target.isItemRevealed = true;
        _getStats(target.organism.id).isItemRevealed = true;
        addToLog(
          '${target.organism.name} ate its ${target.organism.equippedTalisman!.name}!',
        );
        await applyStatChange(
          target,
          effect.stat ?? 'attack',
          effect.magnitude.round(),
        );
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
        return;
      } else if (effect.type == TalismanEffectType.berryCritBoost) {
        target.talismanConsumed = true;
        target.critBoostFromBerry = effect.magnitude;
        target.isItemRevealed = true;
        _getStats(target.organism.id).isItemRevealed = true;
        addToLog(
          '${target.organism.name} ate its ${target.organism.equippedTalisman!.name}! Critical hit ratio rose!',
        );
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
        return;
      }
    }
  }

  /// Checks and triggers berry status cures (Lum/Rawst/Cheri etc.)
  Future<void> _checkAndTriggerCureBerry(BattleOrganism target) async {
    if (target.health <= 0) return;
    if (target.organism.equippedTalisman == null) return;
    if (target.talismanConsumed) return;
    if (target.statusEffects.isEmpty) return;

    for (final effect in target.organism.equippedTalisman!.effects) {
      if (effect.type != TalismanEffectType.berryCureStatus) continue;

      final cures = effect.curesStatus ?? '';
      bool shouldCure = false;

      if (cures == 'all') {
        shouldCure = target.statusEffects.isNotEmpty;
      } else {
        shouldCure = target.statusEffects.any((se) {
          switch (cures) {
            case 'burn':
              return se.type == StatusEffectType.burn;
            case 'paralysis':
              return se.type == StatusEffectType.paralysis;
            case 'poison':
              return se.type == StatusEffectType.poison;
            case 'sleep':
              return se.type == StatusEffectType.sleep;
            case 'freeze':
              return se.type == StatusEffectType.freeze;
            case 'bleed':
              return se.type == StatusEffectType.bleed;
            case 'confusion':
              return se.type == StatusEffectType.confusion;
            default:
              return false;
          }
        });
      }

      if (shouldCure) {
        if (cures == 'all') {
          target.clearStatusEffects();
        } else {
          target.statusEffects = target.statusEffects.where((se) {
            switch (cures) {
              case 'burn':
                return se.type != StatusEffectType.burn;
              case 'paralysis':
                return se.type != StatusEffectType.paralysis;
              case 'poison':
                return se.type != StatusEffectType.poison;
              case 'sleep':
                return se.type != StatusEffectType.sleep;
              case 'freeze':
                return se.type != StatusEffectType.freeze;
              case 'bleed':
                return se.type != StatusEffectType.bleed;
              case 'confusion':
                return se.type != StatusEffectType.confusion;
              default:
                return true;
            }
          }).toList();
        }
        target.talismanConsumed = true;
        target.isItemRevealed = true;
        _getStats(target.organism.id).isItemRevealed = true;
        addToLog(
          '${target.organism.name} ate its ${target.organism.equippedTalisman!.name}! Its status was cured!',
        );
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
        return;
      }
    }
  }

  Future<void> triggerHazards(
    BattleOrganism target,
    List<String> hazards,
  ) async {
    if (hazards.isEmpty) return;
    if (target.health <= 0) return;

    bool isGrounded =
        !target.types.contains(ElementalType.flying) &&
        !target.abilities.any(
          (a) => a.name == 'Levitate' || a.name == 'True Flight',
        ) &&
        (target.organism.equippedTalisman == null ||
            target.organism.equippedTalisman!.name != 'Air Balloon' ||
            target.talismanConsumed);

    final hazardCounts = <String, int>{};
    for (final h in hazards) {
      hazardCounts[h] = (hazardCounts[h] ?? 0) + 1;
    }

    final hazardsToRemove = <String>[];

    for (final entry in hazardCounts.entries) {
      final hazard = entry.key;
      final count = entry.value;

      if (hazard == 'spikes' && isGrounded) {
        double fraction = 0.125; // 1 layer: 1/8
        if (count == 2) fraction = 1 / 6;
        if (count >= 3) fraction = 0.25; // 3 layers: 1/4

        final damage = (target.maxHealth * fraction).round().clamp(
          1,
          target.health,
        );
        target.health -= damage;
        addToLog('${target.name} was hurt by Spikes!');
      } else if (hazard == 'stealth_rock') {
        double rockEff = 1.0;
        rockEff *= TypeChart.getEffectiveness(
          ElementalType.rock,
          target.types[0],
        );
        if (target.types.length > 1) {
          rockEff *= TypeChart.getEffectiveness(
            ElementalType.rock,
            target.types[1],
          );
        }
        final damage = (target.maxHealth * 0.125 * rockEff).round().clamp(
          1,
          target.health,
        );
        target.health -= damage;
        addToLog('${target.name} was hurt by Stealth Rock!');
      } else if (hazard == 'toxic_spikes' && isGrounded) {
        if (target.types.contains(ElementalType.toxic)) {
          addToLog('${target.name} absorbed the Toxic Spikes!');
          hazardsToRemove.add('toxic_spikes');
        } else {
          if (count >= 2) {
            await applyStatusEffect(target, StatusEffectType.bleed);
          } else {
            await applyStatusEffect(target, StatusEffectType.poison);
          }
        }
      } else if (hazard == 'sticky_web' && isGrounded) {
        addToLog('${target.name} was caught in a Sticky Web!');
        await applyStatChange(target, 'speed', -1);
      }
      notifyListeners();
    }

    if (hazardsToRemove.isNotEmpty) {
      for (final h in hazardsToRemove) {
        hazards.removeWhere((element) => element == h);
      }
      notifyListeners();
    }
  }

  void _startSuggestionTimer() {
    _stopSuggestionTimer();
    suggestedMoveName = null;
    suggestionProcessed = false;

    if (currentState == BattleState.waitingForInput) {
      _suggestionTimer = Timer(const Duration(seconds: 20), () {
        if (currentState == BattleState.waitingForInput &&
            !suggestionProcessed) {
          _suggestMove();
        }
      });
    }
  }

  void _stopSuggestionTimer() {
    _suggestionTimer?.cancel();
    _suggestionTimer = null;
  }

  void _suggestMove() {
    final validMoves = getValidMoves(player);
    if (validMoves.isEmpty) return;

    // Use scoreMove which prepares all necessary AI context
    if (isTesting) print('[BattleManager] Starting move suggestion...');
    double bestScore = -double.infinity;
    Move? bestMove;

    for (final move in validMoves) {
      final score = scoreMove(
        move,
        player,
        opponent,
        aiTeam: playerTeam
            .map(
              (org) => BattleOrganism(
                org,
                isRogueMode: isRogueMode,
                isOpponent: false,
              ),
            )
            .toList(),
        playerTeam: opponentTeam
            .map(
              (org) => BattleOrganism(
                org,
                isRogueMode: isRogueMode,
                isOpponent: true,
              ),
            )
            .toList(),
      );
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }

    if (bestMove != null) {
      if (isTesting)
        print(
          '[BattleManager] Suggested move: ${bestMove.name} with score $bestScore',
        );
      suggestedMoveName = bestMove.name;
      suggestionProcessed = true;
      addToLog('${player.name} suggests using ${bestMove.name}!');
      notifyListeners();
    } else {
      if (isTesting) print('[BattleManager] FAILED to find a suggested move');
      suggestedMoveName = null;
      suggestionProcessed =
          true; // Still mark as processed to avoid re-suggesting
      // No log message for failed suggestion, as it's an internal AI issue
      notifyListeners();
    }
  }

  ElementalType _getTypeFromItemName(String name) {
    switch (name.toLowerCase()) {
      case 'fire':
      case 'flame':
        return ElementalType.blaze;
      case 'water':
      case 'splash':
        return ElementalType.aquatic;
      case 'grass':
      case 'meadow':
        return ElementalType.grass;
      case 'electric':
      case 'zap':
        return ElementalType.electric;
      case 'ice':
      case 'icicle':
        return ElementalType.cryo;
      case 'ground':
      case 'earth':
        return ElementalType.earth;
      case 'rock':
      case 'stone':
        return ElementalType.rock;
      case 'flying':
      case 'sky':
        return ElementalType.flying;
      case 'poison':
      case 'toxic':
        return ElementalType.toxic;
      case 'dark':
      case 'dread':
        return ElementalType.darkness;
      case 'fairy':
      case 'pixie':
        return ElementalType.mystic;
      case 'fighting':
      case 'fist':
        return ElementalType.martial;
      case 'steel':
      case 'iron':
        return ElementalType.metal;
      case 'dragon':
      case 'draco':
        return ElementalType.drake;
      case 'ghost':
      case 'spooky':
        return ElementalType.spectral;
      case 'psychic':
      case 'mind':
        return ElementalType.aura;
      case 'bug':
      case 'insect':
        return ElementalType.arthropod;
      default:
        return ElementalType.basic;
    }
  }
}
