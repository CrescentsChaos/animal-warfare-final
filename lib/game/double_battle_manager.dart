// lib/game/double_battle_manager.dart
//
// Manages the state for a 2v2 "Doubles" battle format.
// Both sides have two active slots and up to 4 animals on bench.
// Turn structure: select actions for both player slots → AI picks → speed-order execution.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/game/ai_decision_engine.dart';
import 'package:animal_warfare/game/player_history.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/talisman.dart';

// ──────────────────────────────────────────────
// Enums
// ──────────────────────────────────────────────

enum DoubleBattleState {
  intro, // Initialization animation / opening text
  selectingLeads, // Player picking initial 2 active animals
  selectingForSlot1, // Player picking move + target for slot 1
  selectingForSlot2, // Player picking move + target for slot 2
  executing, // All four actions resolving in speed order
  waitingForSwitch, // A player slot fainted — pick a bench mon
  battleEnd,
}

enum DoubleBattleResult { win, loss }

/// Which of the four active slots a move should target.
enum DoubleTarget {
  opponentSlot1,
  opponentSlot2,
  playerSlot1,
  playerSlot2,
  allOpponents, // Used automatically by targetCount == multiple
}

// ──────────────────────────────────────────────
// Per-slot action choice (player or AI)
// ──────────────────────────────────────────────

enum SlotActionType { move, switchMon }

class SlotAction {
  final SlotActionType type;
  final Move? move;
  final DoubleTarget? target;
  final int? switchBenchIndex;

  const SlotAction.move(this.move, this.target)
    : type = SlotActionType.move,
      switchBenchIndex = null;

  const SlotAction.switchMon(this.switchBenchIndex)
    : type = SlotActionType.switchMon,
      move = null,
      target = null;

  int get priority =>
      type == SlotActionType.switchMon ? 99 : (move?.priority ?? 0);
}

// ──────────────────────────────────────────────
// DoubleBattleManager
// ──────────────────────────────────────────────

class DoubleBattleManager extends ChangeNotifier {
  // ... (keeping existing fields)
  final List<CapturedOrganism> playerTeam;
  final List<CapturedOrganism> opponentTeam;

  late BattleOrganism? playerSlot1;
  late BattleOrganism? playerSlot2;
  late BattleOrganism? opponentSlot1;
  late BattleOrganism? opponentSlot2;

  int playerIdx1 = 0;
  int playerIdx2 = 1;
  int opponentIdx1 = 0;
  int opponentIdx2 = 1;

  late List<int> playerBench;
  late List<int> opponentBench;

  SlotAction? pendingAction1;
  SlotAction? pendingAction2;

  int? switchNeededSlot;

  DoubleBattleState currentState = DoubleBattleState.intro;
  DoubleBattleResult? result;

  String battleLog = '';
  final List<BattleTurn> turnHistory = [];
  int currentTurn = 1;

  final bool isRogueMode;
  final bool isArenaBattle;
  final bool isTesting;

  final PlayerHistory playerHistory = PlayerHistory();
  TeamArchetype opponentArchetype = TeamArchetype.balanced;
  final AudioService _audio = AudioService.instance;
  bool _disposed = false;
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  bool playerPrismorphUsed = false;
  bool opponentPrismorphUsed = false;

  // Field Effects (Turns)
  int playerReflectTurns = 0;
  int playerLightScreenTurns = 0;
  int playerSafeguardTurns = 0;
  int playerTailwindTurns = 0;
  int playerAuroraVeilTurns = 0;

  int opponentReflectTurns = 0;
  int opponentLightScreenTurns = 0;
  int opponentSafeguardTurns = 0;
  int opponentTailwindTurns = 0;
  int opponentAuroraVeilTurns = 0;

  int trickRoomTurns = 0;
  int gravityTurns = 0;
  int terrainTurnsLeft = 0;
  TerrainEffect currentTerrain = const TerrainEffect(terrain: Terrain.none);
  WeatherEffect currentWeather = const WeatherEffect(weather: Weather.none);

  // Pending gimmick notification (read by UI listener, cleared after handling)
  String? pendingGimmickType;
  BattleOrganism? pendingGimmickTarget;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_disposed) {
      super.notifyListeners();
    }
  }

  // Stats tracking (for revealed moves etc)
  final Map<String, BattleStats> battleStats = {};

  // Callbacks
  void Function(BattleOrganism attacker, Move move, BattleOrganism target)?
  onAttack;
  void Function(BattleOrganism target, int damage)? onDamage;
  Future<void> Function(BattleOrganism killer, BattleOrganism victim)?
  onOpponentFainted;

  DoubleBattleManager({
    required List<CapturedOrganism> playerTeam,
    required List<CapturedOrganism> opponentTeam,
    this.isRogueMode = false,
    this.isArenaBattle = false,
    this.isTesting = false,
    TeamArchetype? opponentArchetype,
  }) : playerTeam = List.from(playerTeam),
       opponentTeam = List.from(opponentTeam) {
    if (opponentArchetype != null) {
      this.opponentArchetype = opponentArchetype;
    }
    _init();
  }

  void _init() {
    playerBench = List.generate(
      playerTeam.length,
      (i) => i,
    ).where((i) => playerTeam[i].currentHealth > 0).toList();
    opponentBench = List.generate(
      opponentTeam.length,
      (i) => i,
    ).where((i) => opponentTeam[i].currentHealth > 0).toList();

    _fillSlotsFromBench();

    _triggerEntryAbilities();
    
    if (playerTeam.length > 2) {
      currentState = DoubleBattleState.selectingLeads;
      addLog('Choose two animals to lead the battle!');
    } else {
      _startIntro();
    }
  }

  void _fillSlotsFromBench() {
    if (playerBench.isNotEmpty) {
      playerIdx1 = _popBench(playerBench);
      playerSlot1 = BattleOrganism(
        playerTeam[playerIdx1],
        isRogueMode: isRogueMode,
      );
      _checkMimic(playerSlot1!);
    } else {
      playerIdx1 = -1;
      playerSlot1 = null;
    }
    if (playerBench.isNotEmpty) {
      playerIdx2 = _popBench(playerBench);
      playerSlot2 = BattleOrganism(
        playerTeam[playerIdx2],
        isRogueMode: isRogueMode,
      );
      _checkMimic(playerSlot2!);
    } else {
      playerIdx2 = -1;
      playerSlot2 = null;
    }

    if (opponentBench.isNotEmpty) {
      opponentIdx1 = _popBench(opponentBench);
      opponentSlot1 = BattleOrganism(
        opponentTeam[opponentIdx1],
        isRogueMode: isRogueMode,
      );
      _checkMimic(opponentSlot1!);
    } else {
      opponentIdx1 = -1;
      opponentSlot1 = null;
    }
    if (opponentBench.isNotEmpty) {
      opponentIdx2 = _popBench(opponentBench);
      opponentSlot2 = BattleOrganism(
        opponentTeam[opponentIdx2],
        isRogueMode: isRogueMode,
      );
      _checkMimic(opponentSlot2!);
    } else {
      opponentIdx2 = -1;
      opponentSlot2 = null;
    }
  }

  Future<void> _triggerEntryAbilities() async {
    final allSlots = _allActiveSlots();
    if (allSlots.isEmpty) return;

    // 1. Reset suppression
    for (final slot in allSlots) {
      slot.isAbilitySuppressed = false;
    }

    // 2. Neutralizing Gas Check
    bool gasActive = false;
    for (final slot in allSlots) {
      if (slot.abilities.any((a) => a.name == 'Neutralizing Gas')) {
        gasActive = true;
        slot.isAbilityRevealed = true;
        break;
      }
    }

    if (gasActive) {
      addLog('Neutralizing Gas filled the area!');
      for (final slot in allSlots) {
        if (!slot.abilities.any((a) => a.name == 'Neutralizing Gas')) {
          slot.isAbilitySuppressed = true;
        }
      }
    }

    // 3. Sort by Speed
    final sortedSlots = List<BattleOrganism>.from(allSlots);
    sortedSlots.sort((a, b) {
      int speedA = _getEffectiveSpeed(a);
      int speedB = _getEffectiveSpeed(b);
      // Higher speed goes first
      return speedB.compareTo(speedA);
    });

    // 4. Trigger Abilities
    for (final slot in sortedSlots) {
      if (slot.isAbilitySuppressed) continue;

      for (final ability in slot.abilities) {
        if (ability.trigger != AbilityTrigger.onEntry) continue;

        // Trace
        if (ability.name == 'Trace') {
          final opposingSlots = (slot == playerSlot1 || slot == playerSlot2)
              ? [opponentSlot1, opponentSlot2]
              : [playerSlot1, playerSlot2];
          final targets = opposingSlots.where((s) => s != null && s.health > 0).toList();
          if (targets.isNotEmpty) {
            final target = targets[Random().nextInt(targets.length)]!;
            if (target.abilities.isNotEmpty) {
              final traced = target.abilities.first;
              slot.tempAbilities.add(traced);
              slot.isAbilityRevealed = true;
              addLog('${slot.name} traced ${target.name}\'s ${traced.name}!');
              // If the traced ability is also an entry ability, it should trigger now
              // For simplicity, we just handle the most common ones here or re-run the loop for this slot
            }
          }
        }

        switch (ability.effectType) {
          case AbilityEffectType.weatherChange:
            if (ability.name == 'Air Lock' || ability.name == 'Cloud Nine') {
              currentWeather = const WeatherEffect(weather: Weather.none, duration: 0);
              addLog('The weather effects were neutralized!');
            } else {
              final Weather targetWeather = _parseWeather(ability.value);
              if (currentWeather.weather != targetWeather) {
                currentWeather = WeatherEffect(
                  weather: targetWeather,
                  duration: slot.isItemValid && slot.organism.equippedTalisman!.effects.any((e) => e.type == TalismanEffectType.weatherDuration) == true ? 8 : 5,
                );
                addLog('${slot.name}\'s ${ability.name} changed the weather!');
              }
            }
            break;
          case AbilityEffectType.terrainChange:
            final Terrain targetTerrain = _parseTerrain(ability.value);
            if (currentTerrain.terrain != targetTerrain) {
              currentTerrain = TerrainEffect(
                terrain: targetTerrain,
                duration: slot.isItemValid && slot.organism.equippedTalisman!.effects.any((e) => e.type == TalismanEffectType.weatherDuration) == true ? 8 : 5,
              );
              addLog('${slot.name}\'s ${ability.name} changed the terrain!');
            }
            break;
          case AbilityEffectType.statChange:
            if (ability.name == 'Intimidate') {
              addLog('${slot.name}\'s Intimidate cut the opponents\' attack!');
              final opposingSlots = (slot == playerSlot1 || slot == playerSlot2)
                  ? [opponentSlot1, opponentSlot2]
                  : [playerSlot1, playerSlot2];
              for (final foe in opposingSlots) {
                if (foe != null && foe.health > 0) {
                  await _applyStatChange(foe, 'attack', -1);
                }
              }
            } else if (ability.name == 'Download') {
              final opposingSlots = (slot == playerSlot1 || slot == playerSlot2)
                  ? [opponentSlot1, opponentSlot2]
                  : [playerSlot1, playerSlot2];
              int avgDef = 0;
              int avgRes = 0;
              int count = 0;
              for (final foe in opposingSlots) {
                if (foe != null && foe.health > 0) {
                  avgDef += foe.organism.baseOrganism.defense;
                  avgRes += foe.organism.baseOrganism.resistance;
                  count++;
                }
              }
              if (count > 0) {
                if (avgDef / count <= avgRes / count) {
                  await _applyStatChange(slot, 'attack', 1);
                } else {
                  await _applyStatChange(slot, 'power', 1);
                }
              }
            } else {
              // General entry stat boosts (e.g. Speed Boost on entry? No usually it's EToT)
              await _applyStatChange(slot, ability.targetStat, ability.magnitude.toInt());
            }
            break;
          default:
            break;
        }
      }
    }
    notifyListeners();
  }

  int _popBench(List<int> bench) {
    final idx = bench.first;
    bench.removeAt(0);
    notifyListeners();
    return idx;
  }

  // ──────────────────────────────────────────────
  // AI Action Selection
  // ──────────────────────────────────────────────

  List<SlotAction> _pickAiActions() {
    final actions = <SlotAction>[];

    if (opponentSlot1 != null && opponentSlot1!.health > 0) {
      actions.add(_pickAiMove(opponentSlot1!, 1));
    }
    if (opponentSlot2 != null && opponentSlot2!.health > 0) {
      actions.add(_pickAiMove(opponentSlot2!, 2));
    }

    return actions;
  }

  SlotAction _pickAiMove(BattleOrganism attacker, int slotIdx) {
    final moves = getMovesFor(attacker);
    if (moves.isEmpty) {
      return const SlotAction.move(null, DoubleTarget.playerSlot1);
    }

    // Basic AI: Pick a random move and a random player target
    final move = moves[Random().nextInt(moves.length)];
    
    // Determine target based on move
    DoubleTarget targetSelection = DoubleTarget.playerSlot1;
    if (move.doublesTarget == MoveTarget.bothOpponents || 
        move.doublesTarget == MoveTarget.allAdjacent ||
        move.doublesTarget == MoveTarget.field) {
      targetSelection = DoubleTarget.allOpponents;
    } else if (move.doublesTarget == MoveTarget.singleAlly ||
               move.doublesTarget == MoveTarget.allAllies) {
      targetSelection = slotIdx == 1 ? DoubleTarget.opponentSlot2 : DoubleTarget.opponentSlot1;
    } else {
      // Pick random player target
      final playerAlive = [playerSlot1, playerSlot2].where((s) => s != null && s.health > 0).toList();
      if (playerAlive.isEmpty) {
        targetSelection = DoubleTarget.playerSlot1;
      } else {
        final chosen = playerAlive[Random().nextInt(playerAlive.length)];
        targetSelection = (chosen == playerSlot1) ? DoubleTarget.playerSlot1 : DoubleTarget.playerSlot2;
      }
    }

    return SlotAction.move(move, targetSelection);
  }

  Future<void> _startIntro() async {
    if (!isTesting) {
      await _audio.playMusic('audio/battle_default.mp3');
      await Future.delayed(const Duration(milliseconds: 2500));
    }
    _transitionToSelection();
  }

  void selectLeads(int p1, int p2) {
    if (currentState != DoubleBattleState.selectingLeads) return;

    // Remove from bench
    playerBench.remove(p1);
    playerBench.remove(p2);

    playerIdx1 = p1;
    playerIdx2 = p2;

    playerSlot1 = BattleOrganism(playerTeam[p1], isRogueMode: isRogueMode);
    playerSlot2 = BattleOrganism(playerTeam[p2], isRogueMode: isRogueMode);

    _checkMimic(playerSlot1!);
    _checkMimic(playerSlot2!);

    if (!isTesting) {
      _audio.playOrganismCry(playerSlot1!.organism.baseOrganism.cry);
      _audio.playOrganismCry(playerSlot2!.organism.baseOrganism.cry);
    }

    addLog('GO! ${_slotName(playerSlot1)} & ${_slotName(playerSlot2)}!');
    _startIntro();
  }

  void _transitionToSelection() {
    if (playerSlot1 != null) {
      currentState = DoubleBattleState.selectingForSlot1;
      addLog(
        'What will ${_slotName(playerSlot1)} & ${_slotName(playerSlot2)} do?',
      );
    } else if (playerSlot2 != null) {
      currentState = DoubleBattleState.selectingForSlot2;
      addLog('What will ${_slotName(playerSlot2)} do?');
    }
    notifyListeners();
  }

  Future<void> submitAction(Move move, DoubleTarget target) async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    // Thrash Lock enforcement
    final attacker = currentState == DoubleBattleState.selectingForSlot1
        ? playerSlot1
        : playerSlot2;
    if (attacker != null &&
        attacker.thrashTurnCount > 0 &&
        attacker.thrashMove != null) {
      move = attacker.thrashMove!;
    }

    final action = SlotAction.move(move, target);
    if (currentState == DoubleBattleState.selectingForSlot1) {
      pendingAction1 = action;
      if (playerSlot2 != null && playerSlot2!.health > 0) {
        currentState = DoubleBattleState.selectingForSlot2;
        addLog('What will ${_slotName(playerSlot2)} do?');
        _isProcessing = false; // Allow input for the second slot
        notifyListeners();
      } else {
        await _executeAllActions();
      }
    } else if (currentState == DoubleBattleState.selectingForSlot2) {
      pendingAction2 = action;
      await _executeAllActions();
    }
  }

  Future<void> submitSwitch(int benchIndex) async {
    if (_isProcessing) return;
    _isProcessing = true;
    notifyListeners();

    final action = SlotAction.switchMon(benchIndex);
    if (currentState == DoubleBattleState.selectingForSlot1) {
      pendingAction1 = action;
      if (playerSlot2 != null && playerSlot2!.health > 0) {
        currentState = DoubleBattleState.selectingForSlot2;
        addLog('What will ${_slotName(playerSlot2)} do?');
        _isProcessing = false; // Allow input for the second slot
        notifyListeners();
      } else {
        currentState = DoubleBattleState.executing;
        notifyListeners();
        await _executeAllActions();
      }
    } else if (currentState == DoubleBattleState.selectingForSlot2) {
      pendingAction2 = action;
      currentState = DoubleBattleState.executing;
      notifyListeners();
      await _executeAllActions();
    }
  }

  void _checkMimic(BattleOrganism org) {
    if (org.abilities.any(
      (a) => a.name == 'Mimic' || a.name == 'Mimicry' || a.name == 'Illusion',
    )) {
      final team = (org == playerSlot1 || org == playerSlot2)
          ? playerTeam
          : opponentTeam;
      CapturedOrganism? disguiseTarget;
      // Start from the end of the party
      for (int i = team.length - 1; i >= 0; i--) {
        if (team[i] != org.organism && team[i].currentHealth > 0) {
          disguiseTarget = team[i];
          break;
        }
      }
      if (disguiseTarget != null) {
        org.isDisguised = true;
        org.disguisedAs = disguiseTarget;
      }
    } else if (org.abilities.any((a) => a.name == 'Frisk')) {
      final opposingSlots = (org == playerSlot1 || org == playerSlot2)
          ? [opponentSlot1, opponentSlot2]
          : [playerSlot1, playerSlot2];
      for (final foe in opposingSlots) {
        if (foe != null &&
            foe.health > 0 &&
            foe.organism.equippedTalisman != null &&
            !foe.talismanConsumed) {
          addLog(
            '${org.organism.baseOrganism.name} frisked ${foe.organism.baseOrganism.name} and found its ${foe.organism.equippedTalisman!.name}!',
          );
          foe.itemDisabledTurns = 2;
          addLog(
            '${foe.organism.baseOrganism.name}\'s item was disabled for 2 turns!',
          );
        }
      }
    }
  }

  ElementalType getDisplayType(BattleOrganism attacker, Move move) {
    // This logic should ideally be shared, but since DoubleBattleManager
    // is separate, we'll implement a concise version here.
    ElementalType moveType = move.type;

    // Weather Ball (Concise version for Doubles)
    if (move.name == 'Weather Ball' ||
        move.effects.any((e) => e.type == MoveEffectType.weatherBall)) {
      // Weather context could be added here if environment is shared
    }

    // Refrigerate: Basic -> Cryo
    if (moveType == ElementalType.basic &&
        attacker.abilities.any((ab) => ab.name == 'Refrigerate')) {
      moveType = ElementalType.cryo;
    }

    // Aerilate: Basic -> Flying
    if (moveType == ElementalType.basic &&
        attacker.abilities.any((ab) => ab.name == 'Aerilate')) {
      moveType = ElementalType.flying;
    }

    // Pixilate: Basic -> Mystic
    if (moveType == ElementalType.basic &&
        attacker.abilities.any((ab) => ab.name == 'Pixilate')) {
      moveType = ElementalType.mystic;
    }

    // Galvanize: Basic -> Electric
    if (moveType == ElementalType.basic &&
        attacker.abilities.any((ab) => ab.name == 'Galvanize')) {
      moveType = ElementalType.electric;
    }

    // Liquid Voice: Sound -> Aquatic
    if (move.type == ElementalType.sound &&
        attacker.abilities.any((ab) => ab.name == 'Liquid Voice')) {
      moveType = ElementalType.aquatic;
    }

    // Hidden Power
    if (move.name == 'Hidden Power' ||
        move.effects.any((e) => e.type == MoveEffectType.hiddenPower)) {
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

    // Multi-Attack / Judgement
    if (move.name == 'Multi-Attack' ||
        move.name == 'Judgement' ||
        move.effects.any((e) => e.type == MoveEffectType.multiAttack) ||
        move.effects.any((e) => e.type == MoveEffectType.judgement)) {
      final item = attacker.organism.equippedTalisman;
      if (item != null) {
        if (item.id.endsWith('_memory') || item.id.endsWith('_plate')) {
          final part = item.id.split('_').first;
          moveType = _getTypeFromItemName(part);
        }
      }
    }

    if (move.name == 'Revelation Dance') {
      moveType = attacker.types.first;
    }

    if (move.isTerrainPulse && currentTerrain.terrain != Terrain.none) {
      switch (currentTerrain.terrain) {
        case Terrain.electric:
          moveType = ElementalType.electric;
          break;
        case Terrain.grassy:
          moveType = ElementalType.grass;
          break;
        case Terrain.misty:
          moveType = ElementalType.mystic;
          break;
        case Terrain.psychic:
          moveType = ElementalType.aura;
          break;
        default:
          break;
      }
    }

    return moveType;
  }

  ElementalType _getTypeFromItemName(String name) {
    return ElementalTypeX.fromString(name);
  }

  int _calculateMoveAccuracy(
    BattleOrganism attacker,
    BattleOrganism defender,
    Move move,
  ) {
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
        move.isNeverMiss ||
        (move.isFocusBlast &&
            attacker.abilities.any((ab) => ab.name == 'Inner Focus')) ||
        defender.glaiveRushVulnerable) {
      return 100;
    }

    if (attacker.statusEffect.type == StatusEffectType.blind) {
      accuracy = (accuracy * 0.75).round();
    }

    // Weather-based accuracy modifier
    accuracy = (accuracy * currentWeather.accuracyModifier).round();

    // Ability accuracy boost (Compound Eyes, Illuminate)
    accuracy = (accuracy * attacker.getAbilityStatMultiplier('accuracy'))
        .round();

    // Victory Star: 1.2x accuracy boost for all moves
    if (attacker.abilities.any((ab) => ab.name == 'Victory Star')) {
      accuracy = (accuracy * 1.2).round();
    }

    // Hustle: 0.9x accuracy
    if (attacker.abilities.any((ab) => ab.name == 'Hustle')) {
      accuracy = (accuracy * 0.9).round();
    }

    // Wonder Skin: Halve accuracy of status moves targeting this defender
    if (move.category == MoveCategory.status &&
        defender.abilities.any((ab) => ab.name == 'Wonder Skin')) {
      accuracy = (accuracy * 0.5).round();
    }

    if (attacker.organism.equippedTalisman != null &&
        !attacker.talismanConsumed) {
      for (final effect in attacker.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.wideLens) {
          accuracy = (accuracy * effect.magnitude).round();
        } else if (effect.type == TalismanEffectType.zoomLens) {
          // In doubles, we check if the target has already moved this turn
          if (defender.hasMovedThisTurn) {
            accuracy = (accuracy * effect.magnitude).round();
          }
        }
      }
    }

    // Bright Powder accuracy reduction
    if (defender.organism.equippedTalisman != null &&
        !defender.talismanConsumed) {
      for (final effect in defender.organism.equippedTalisman!.effects) {
        if (effect.stat == 'evasion') {
          accuracy = (accuracy * (1.0 / effect.magnitude)).round();
        }
      }
    }

    // Evasion stage modifier
    if (defender.evasionStage != 0 && move.name != 'Sacred Sword') {
      double evasionMultiplier = 1.0;
      if (defender.evasionStage > 0) {
        evasionMultiplier = 3.0 / (3.0 + defender.evasionStage);
      } else {
        evasionMultiplier = (3.0 - defender.evasionStage) / 3.0;
      }
      accuracy = (accuracy * evasionMultiplier).round();
    }

    // Tangled Feet: 2x evasion when confused (0.5x accuracy)
    if (defender.abilities.any((ab) => ab.name == 'Tangled Feet') &&
        defender.statusEffects.any(
          (se) => se.type == StatusEffectType.confusion,
        )) {
      accuracy = (accuracy * 0.5).round();
    }

    return accuracy;
  }

  Future<bool> _canMove(BattleOrganism org, Move move) async {
    if (org.health <= 0) return false;

    // Flinch
    if (org.statusEffects.any((se) => se.type == StatusEffectType.stun)) {
      addLog('${org.name} flinched and couldn\'t move!');
      org.statusEffects.removeWhere((se) => se.type == StatusEffectType.stun);
      return false;
    }

    // Sleep
    if (org.statusEffects.any((se) => se.type == StatusEffectType.sleep)) {
      StatusEffect sleepEffect = org.statusEffects.firstWhere((se) => se.type == StatusEffectType.sleep);
      if (sleepEffect.duration == 0) {
        addLog('${org.name} woke up!');
        org.statusEffects.removeWhere((se) => se.type == StatusEffectType.sleep);
      } else {
        addLog('${org.name} is fast asleep.');
        // Update duration
        int idx = org.statusEffects.indexOf(sleepEffect);
        org.statusEffects[idx] = sleepEffect.copyWith(duration: sleepEffect.duration - 1);
        return false;
      }
    }

    // Frozen
    if (org.statusEffects.any((se) => se.type == StatusEffectType.freeze)) {
      if (Random().nextDouble() < 0.2 || move.type == ElementalType.blaze) {
        addLog('${org.name} thawed out!');
        org.statusEffects.removeWhere((se) => se.type == StatusEffectType.freeze);
      } else {
        addLog('${org.name} is frozen solid!');
        return false;
      }
    }

    // Paralysis
    if (org.statusEffects.any((se) => se.type == StatusEffectType.paralysis)) {
      if (Random().nextDouble() < 0.25) {
        addLog('${org.name} is paralyzed! It can\'t move!');
        return false;
      }
    }

    // Confusion
    if (org.statusEffects.any((se) => se.type == StatusEffectType.confusion)) {
      StatusEffect confEffect = org.statusEffects.firstWhere((se) => se.type == StatusEffectType.confusion);
      if (confEffect.duration == 0) {
        addLog('${org.name} snapped out of its confusion!');
        org.statusEffects.removeWhere((se) => se.type == StatusEffectType.confusion);
      } else {
        addLog('${org.name} is confused...');
        // Update duration
        int idx = org.statusEffects.indexOf(confEffect);
        org.statusEffects[idx] = confEffect.copyWith(duration: confEffect.duration - 1);

        if (Random().nextDouble() < 0.33) {
          addLog('It hit itself in its confusion!');
          // Hit self with 40 power basic physical move
          final selfMove = Move.findByName('Struggle') ?? move;
          final selfDamage = calculateDamage(org, org, selfMove, ignoreRandom: true);
          org.health = (org.health - selfDamage.damage).clamp(0, org.maxHealth);
          if (onDamage != null) onDamage!(org, selfDamage.damage);
          return false;
        }
      }
    }

    // Taunt
    if (org.statusEffects.any((se) => se.type == StatusEffectType.taunt) && move.category == MoveCategory.status) {
      addLog('${org.name} is taunted and can\'t use status moves!');
      return false;
    }

    // Imprison
    if (org.statusEffects.any((se) => se.type == StatusEffectType.imprison)) {
      // Logic for checking if opponent knows the move
      // Simplified for now: just block it if it's the user's move
      // (This should ideally check the imprisoner's moveset)
    }

    return true;
  }

  DamageResult calculateDamage(
    BattleOrganism attacker,
    BattleOrganism defender,
    Move move, {
    double multiTargetPenalty = 1.0,
    bool ignoreRandom = false,
  }) {
    if (move.baseDamage == 0) return const DamageResult(0, 1.0, false);

    final bool moldBreakerActive = attacker.abilities.any(
      (ab) => ab.name == 'Mold Breaker',
    );

    // --- Fixed and Level-Based Damage Moves ---
    final fixedDamageEffect = move.effects.firstWhere(
      (e) => e.type == MoveEffectType.fixedDamage,
      orElse: () => const MoveEffect(type: MoveEffectType.none),
    );
    if (fixedDamageEffect.type != MoveEffectType.none) {
      return DamageResult(fixedDamageEffect.value.toInt(), 1.0, false);
    }

    final levelDamageEffect = move.effects.firstWhere(
      (e) => e.type == MoveEffectType.levelDamage,
      orElse: () => const MoveEffect(type: MoveEffectType.none),
    );
    if (levelDamageEffect.type != MoveEffectType.none) {
      return DamageResult(attacker.level, 1.0, false);
    }

    // Super Fang
    if (move.isSuperFang) {
      return DamageResult(max(1, (defender.health / 2).floor()), 1.0, false);
    }

    // Nature's Madness
    if (move.name == "Nature's Madness" ||
        move.effects.any((e) => e.type == MoveEffectType.naturesMadness)) {
      return DamageResult(max(1, (defender.health / 2).floor()), 1.0, false);
    }

    // Endeavor
    if (move.name == 'Endeavor' ||
        move.effects.any((e) => e.type == MoveEffectType.endeavor)) {
      if (defender.health > attacker.health) {
        return DamageResult(defender.health - attacker.health, 1.0, false);
      }
      return const DamageResult(0, 1.0, false);
    }

    // --- Stats (Atk/Def or Power/Res) ---
    final isFoulPlay = move.effects.any(
      (e) => e.type == MoveEffectType.foulPlay,
    );
    double atkStat = (move.category == MoveCategory.special)
        ? attacker.currentPower.toDouble()
        : isFoulPlay
        ? defender.currentAttack.toDouble()
        : attacker.currentAttack.toDouble();

    // Helping Hand
    if (attacker.helpingHandBoosted) {
      atkStat *= 1.5;
    }

    double defStat = (move.category == MoveCategory.special)
        ? (move.targetDefenseStat == 'defense'
              ? defender.currentDefense.toDouble()
              : defender.currentResistance.toDouble())
        : defender.currentDefense.toDouble();

    if (move.ignoresDefenseStages) {
      defStat = (move.category == MoveCategory.special)
          ? (move.targetDefenseStat == 'defense'
                ? defender.organism.getDefense(atLevel: defender.level).toDouble()
                : defender.organism.getResistance(atLevel: defender.level).toDouble())
          : defender.organism.getDefense(atLevel: defender.level).toDouble();
    }

    // --- Ability Stat Multipliers ---
    if (move.category == MoveCategory.physical &&
        attacker.abilities.any((ab) => ab.name == 'Toxic Boost') &&
        attacker.statusEffects.any(
          (se) => se.type == StatusEffectType.poison,
        )) {
      atkStat *= 1.5;
    }
    if (move.category == MoveCategory.special &&
        attacker.abilities.any((ab) => ab.name == 'Flare Boost') &&
        attacker.statusEffects.any((se) => se.type == StatusEffectType.burn)) {
      atkStat *= 1.5;
    }

    // --- Crit Check ---
    bool isCrit = false;
    double critChance = 6.25;

    if (attacker.isItemValid) {
      for (final effect in attacker.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.critBoost) {
          critChance += effect.magnitude;
        }
      }
    }

    if (attacker.abilities.any((ab) => ab.name == 'Super Luck')) {
      critChance = (critChance == 6.25) ? 12.5 : (critChance == 12.5 ? 50.0 : 100.0);
    }
    if (move.critRate == 1) critChance = 12.5;
    if (move.critRate == 2) critChance = 50.0;
    if (move.critRate >= 3) critChance = 100.0;
    if (attacker.focusEnergyActive) critChance = max(critChance, 50.0);
    if (attacker.laserFocusTurns > 0) critChance = 100.0;

    if (defender.abilities.any((ab) => ab.name == 'Battle Armor' || ab.name == 'Shell Armor') && !moldBreakerActive) {
      critChance = 0;
    }

    if (!ignoreRandom && Random().nextDouble() * 100 < critChance) {
      isCrit = true;
    }

    // --- Base Damage Calculation ---
    int basePower = move.baseDamage;
    if (move.isWringOut) {
      basePower = (120 * defender.health / defender.maxHealth).clamp(1, 120).toInt();
    }
    if (move.isTerrainPulse && currentTerrain.terrain != Terrain.none && attacker.isGrounded) {
      basePower = 100;
    }

    double dmg = ((2 * attacker.level / 5 + 2) * basePower * atkStat / defStat) / 50 + 2;

    if (isCrit) {
      dmg *= (attacker.abilities.any((ab) => ab.name == 'Sniper') ? 2.25 : 1.5);
    }

    // Move type logic
    final moveType = getDisplayType(attacker, move);

    // Type effectiveness
    double typeMod = 1.0;
    for (final defType in defender.types) {
      double mod = TypeChart.getEffectiveness(moveType, defType);
      if (mod == 0.0 && defType == ElementalType.spectral && 
          (moveType == ElementalType.basic || moveType == ElementalType.martial) && 
          attacker.abilities.any((ab) => ab.name == 'Scrappy')) {
        mod = 1.0;
      }
      typeMod *= mod;
    }
    dmg *= typeMod;

    // Gem Boost
    if (attacker.isItemValid) {
      for (final effect in attacker.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.gemBoost &&
            effect.stat == moveType.toString().split('.').last.toLowerCase()) {
          dmg *= effect.magnitude;
        }
      }
    }

    // Expert Belt
    if (typeMod > 1.0 && attacker.isItemValid) {
      for (final effect in attacker.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.damageBoost &&
            effect.condition == 'super_effective') {
          dmg *= effect.magnitude;
        }
      }
    }

    // STAB
    if (attacker.types.contains(moveType)) {
      dmg *= (attacker.abilities.any((ab) => ab.name == 'Adaptability') ? 2.0 : 1.5);
    }

    // Weather Multipliers
    dmg *= currentWeather.getDamageMultiplier(moveType.toString().split('.').last.toLowerCase());

    // Multi-target penalty
    dmg *= multiTargetPenalty;

    // Ability Damage Multipliers
    if (attacker.abilities.any((ab) => ab.name == 'Sheer Force') && move.effects.isNotEmpty) {
      dmg *= 1.3;
    }
    if (attacker.abilities.any((ab) => ab.name == 'Iron Fist') && move.isPunch) dmg *= 1.2;
    if (attacker.abilities.any((ab) => ab.name == 'Strong Jaw') && move.isBite) dmg *= 1.5;
    if (attacker.abilities.any((ab) => ab.name == 'Mega Launcher') && move.isPulse) dmg *= 1.5;
    if (attacker.abilities.any((ab) => ab.name == 'Tough Claws') && move.isContact) dmg *= 1.3;
    if (attacker.abilities.any((ab) => ab.name == 'Technician') && basePower <= 60 && basePower > 0) dmg *= 1.5;

    // Solid Rock / Filter
    if (typeMod > 1.0 && defender.abilities.any((ab) => ab.name == 'Solid Rock' || ab.name == 'Filter') && !moldBreakerActive) {
      dmg *= 0.75;
    }

    // Multiscale
    if (defender.abilities.any((ab) => ab.name == 'Multiscale') && defender.health == defender.maxHealth && !moldBreakerActive) {
      dmg *= 0.5;
    }

    // Random Factor
    if (!ignoreRandom) {
      dmg *= (85 + Random().nextInt(16)) / 100.0;
    }

    return DamageResult(max(1, dmg.round()), typeMod, isCrit);
  }

  List<Move> getMovesFor(BattleOrganism org) {
    if (org.organism.selectedMoveNames.isEmpty) {
      org.organism.initializeDefaultMoves();
    }
    List<Move> moves = org.organism.selectedMoveNames
        .map((n) => Move.findOrCreate(n))
        .toList();
    if (moves.isEmpty) moves.add(Move.findOrCreate('Struggle'));

    // Choice Lock / Gorilla Tactics Lock
    if (org.isChoiceLocked && org.lockedMove != null) {
      if (moves.any((m) => m.name == org.lockedMove!.name)) {
        moves = [moves.firstWhere((m) => m.name == org.lockedMove!.name)];
      }
    }

    return moves;
  }

  Future<void> _executeAllActions() async {
    // Before processing, check for any pending gimmick activations for player
    // (In reality, they are triggered by buttons that call the methods below)

    currentState = DoubleBattleState.executing;
    notifyListeners();

    final aiActions = _pickAiActions();
    final actionList = <_ActionEntry>[];

    if (playerSlot1 != null && pendingAction1 != null) {
      actionList.add(
        _ActionEntry(
          attacker: playerSlot1!,
          action: pendingAction1!,
          priority: pendingAction1!.priority,
          speed: _effectiveSpeed(playerSlot1!),
          isPlayer: true,
          slotIdx: 1,
        ),
      );
    }
    if (playerSlot2 != null && pendingAction2 != null) {
      actionList.add(
        _ActionEntry(
          attacker: playerSlot2!,
          action: pendingAction2!,
          priority: pendingAction2!.priority,
          speed: _effectiveSpeed(playerSlot2!),
          isPlayer: true,
          slotIdx: 2,
        ),
      );
    }

    int aiIdx = 0;
    if (opponentSlot1 != null && aiIdx < aiActions.length) {
      final a = aiActions[aiIdx++];
      actionList.add(
        _ActionEntry(
          attacker: opponentSlot1!,
          action: a,
          priority: a.priority,
          speed: _effectiveSpeed(opponentSlot1!),
          isPlayer: false,
          slotIdx: 1,
        ),
      );
    }
    if (opponentSlot2 != null && aiIdx < aiActions.length) {
      final a = aiActions[aiIdx++];
      actionList.add(
        _ActionEntry(
          attacker: opponentSlot2!,
          action: a,
          priority: a.priority,
          speed: _effectiveSpeed(opponentSlot2!),
          isPlayer: false,
          slotIdx: 2,
        ),
      );
    }

    actionList.sort((a, b) {
      if (b.priority != a.priority) return b.priority - a.priority;
      if (trickRoomTurns > 0) {
        if (a.speed != b.speed) return a.speed - b.speed;
      } else {
        if (b.speed != a.speed) return b.speed - a.speed;
      }
      return Random().nextBool() ? 1 : -1;
    });

    for (final entry in actionList) {
      if (_isBattleOver()) break;
      if (entry.attacker.health <= 0 &&
          entry.action.type != SlotActionType.switchMon) {
        continue;
      }

      await _executeAction(entry);
      await _processFaints();
    }

    await _applyEndOfTurnEffects();
    await _processFaints();

    // Decrement item disable turns
    for (final slot in _allActiveSlots()) {
      if (slot.itemDisabledTurns > 0) slot.itemDisabledTurns--;
    }

    if (await _processReplacements()) {
      _isProcessing = false;
      return;
    }

    pendingAction1 = null;
    pendingAction2 = null;
    currentTurn++;
    turnHistory.add(BattleTurn(currentTurn));

    if (!_isBattleOver()) {
      _transitionToSelection();
    }
    _isProcessing = false;
    notifyListeners();
  }

  Future<void> _executeAction(_ActionEntry entry) async {
    final attacker = entry.attacker;

    if (entry.action.type == SlotActionType.switchMon) {
      if (entry.isPlayer) {
        playerHistory.recordSwitch(entry.action.switchBenchIndex!);
      }
      final benchIdx = entry.action.switchBenchIndex!;
      final newOrg = BattleOrganism(playerTeam[benchIdx]);
      _checkMimic(newOrg);
      playerBench.remove(benchIdx);

      // Return old mon to bench if it didn't faint (manual switch)
      if (attacker.health > 0) {
        attacker.resetBattleState(); // Reset state (clears confusion etc.)
        playerBench.add(entry.slotIdx == 1 ? playerIdx1 : playerIdx2);
      }

      if (entry.slotIdx == 1) {
        playerIdx1 = benchIdx;
        playerSlot1 = newOrg;
      } else {
        playerIdx2 = benchIdx;
        playerSlot2 = newOrg;
      }
      if (!isTesting) {
        _audio.playOrganismCry(newOrg.organism.baseOrganism.cry);
      }

      // Restore persistent stats
      final stats = battleStats.putIfAbsent(
        newOrg.organism.id,
        () => BattleStats(),
      );
      newOrg.isPrismorphed = stats.isPrismorphed;
      newOrg.hasPrismorphedThisBattle = stats.hasPrismorphedThisBattle;
      newOrg.activeTeraType = stats.activeTeraType;
      newOrg.revealedMoves.addAll(stats.revealedMoves);
      newOrg.isItemRevealed = stats.isItemRevealed;
      newOrg.isAbilityRevealed = stats.isAbilityRevealed;

      addLog('Come back, ${attacker.organism.baseOrganism.name}!');
      addLog('Go, ${newOrg.organism.baseOrganism.name}!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));
      return;
    }

    final move = entry.action.move!;
    final target = entry.action.target!;

    if (entry.isPlayer) {
      playerHistory.recordMove(move);
    }

    // --- Ability: Neutralizing Gas ---
    // (Awaiting implementation)

    // --- Status Check ---
    if (!await _canMove(attacker, move)) {
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));
      return;
    }

    int staminaCost = 1;
    // Pressure Check
    final opposingTeam = entry.isPlayer ? [opponentSlot1, opponentSlot2] : [playerSlot1, playerSlot2];
    if (opposingTeam.any((s) => s != null && s.health > 0 && s.abilities.any((ab) => ab.name == 'Pressure'))) {
      staminaCost = 2;
    }

    attacker.organism.moveStamina[move.name] = 
        ((attacker.organism.moveStamina[move.name] ?? move.stamina) - staminaCost).clamp(
          0,
          move.stamina,
        ).toInt();

    addLog('${attacker.name} used ${move.name}!');

    // Apply Choice Lock if applicable
    if (attacker.lockedMove == null) {
      // Item lock
      if (attacker.organism.equippedTalisman != null) {
        for (final effect in attacker.organism.equippedTalisman!.effects) {
          if (effect.type == TalismanEffectType.choiceLock) {
            attacker.isChoiceLocked = true;
            attacker.lockedMove = move;
            attacker.isItemRevealed = true;
          }
        }
      }
      // Gorilla Tactics lock
      if (attacker.abilities.any((a) => a.name == 'Gorilla Tactics')) {
        attacker.isChoiceLocked = true;
        attacker.lockedMove = move;
      }
    }


    // --- Damp Check ---
    if (move.isSelfDestruct) {
      bool dampActive = _allActiveSlots().any(
        (slot) => slot.abilities.any((ab) => ab.name == 'Damp'),
      );
      if (dampActive) {
        addLog('Damp prevents self-destructive moves!');
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
        return;
      }
    }

    // Track revealed moves
    battleStats
        .putIfAbsent(attacker.organism.id, () => BattleStats())
        .revealedMoves
        .add(move.name);

    if (!isTesting) {
      final sfx =
          move.soundEffect ??
          _audio.getDefaultSoundEffect(
            move.category.toString().split('.').last,
          );
      await _audio.playSound(sfx);
      await Future.delayed(const Duration(milliseconds: 1200));
    }
    notifyListeners();

    // --- Biding Turn Check ---
    if (attacker.isBiding) {
      attacker.bideTurns--;
      if (attacker.bideTurns > 0) {
        addLog("${attacker.name} is biding its time!");
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
        return;
      } else {
        // Bide release
        final damage = attacker.bideDamage * 2;
        attacker.isBiding = false;
        attacker.bideDamage = 0;

        BattleOrganism? targetOrg = _resolveTarget(target);
        if (targetOrg == null || targetOrg.health <= 0) {
          // If original target is gone, pick another opponent
          final opposingSlots = entry.isPlayer
              ? [opponentSlot1, opponentSlot2]
              : [playerSlot1, playerSlot2];
          targetOrg = opposingSlots.firstWhere(
            (s) => s != null && s.health > 0,
            orElse: () => null,
          );
        }

        if (targetOrg == null || damage <= 0) {
          addLog("${attacker.name} unleashed its energy... but it failed!");
        } else {
          addLog("${attacker.name} unleashed its energy!");
          targetOrg.health = (targetOrg.health - damage).toInt().clamp(
            0,
            targetOrg.maxHealth,
          );
          if (onDamage != null) onDamage!(targetOrg, damage.toInt());
        }
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 1500));
        }
        return;
      }
    }

    // --- Helping Hand ---
    if (move.name == 'Helping Hand') {
      final partners = entry.isPlayer
          ? [playerSlot1, playerSlot2]
          : [opponentSlot1, opponentSlot2];
      final partner = partners.firstWhere(
        (s) => s != null && s != attacker,
        orElse: () => null,
      );
      if (partner != null && partner.health > 0) {
        partner.helpingHandBoosted = true;
        addLog('${attacker.name} is ready to help ${partner.name}!');
      } else {
        addLog('But it failed!');
      }
      return;
    }

    // Multi-Hit Loop
    int hits = 1;
    if (move.maxHits > 1) {
      if (attacker.abilities.any((ab) => ab.name == 'Skill Link')) {
        hits = move.maxHits;
      } else {
        hits = move.minHits + Random().nextInt(move.maxHits - move.minHits + 1);
      }
    }

    // Parental Bond Check
    if (attacker.abilities.any((ab) => ab.name == 'Parental Bond') && hits == 1 && move.baseDamage > 0) {
      hits = 2;
    }

    // Raging Boxer: Punching moves hit twice.
    if (attacker.abilities.any((ab) => ab.name == 'Raging Boxer')) {
      if (move.isPunch && hits == 1 && move.baseDamage > 0) {
        hits = 2;
      }
    }

    for (int i = 0; i < hits; i++) {
      if (_isBattleOver()) break;
      
      // Subsequent hit accuracy checks (Population Bomb style)
      if (i > 0) {
        if (attacker.health <= 0) break;
        
        bool skipCheck = attacker.abilities.any((ab) => ab.name == 'Skill Link' || ab.name == 'No Guard') ||
                        _allActiveSlots().any((s) => s.abilities.any((ab) => ab.name == 'No Guard'));
        
        if (!skipCheck) {
          // Re-calculate target and accuracy for subsequent hits
          // This is a simplified version; in a real game, you'd re-verify the target
          // but for now we'll assume the target persists or the loop handles it.
        }
        
        if (!isTesting) {
          final sfx = move.soundEffect ?? _audio.getDefaultSoundEffect(move.category.toString().split('.').last);
          await _audio.playSound(sfx);
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      if (move.targetCount == MoveTargetCount.multiple) {
        // Hit all alive opponents of the attacker
        final opposingSlots = entry.isPlayer
            ? [opponentSlot1, opponentSlot2]
            : [playerSlot1, playerSlot2];
        final targets = opposingSlots.where((s) => s != null && s.health > 0).toList();
        
        // Multi-target penalty (75% damage) only applies if there's more than one target hit
        final penalty = targets.length > 1 ? 0.75 : 1.0;
        
        bool hitAtLeastOne = false;
        for (final defender in targets) {
          hitAtLeastOne = true;
          await _applyMoveToTarget(
            attacker: attacker,
            move: move,
            defender: defender!,
            multiTargetPenalty: penalty,
          );
        }
        if (!hitAtLeastOne && i == 0) {
          addLog('But there was no target!');
          break;
        }
      } else {
        // Single target
        BattleOrganism? defender = _resolveTarget(target);

        // --- Redirection Check ---
        final opposingSlots = entry.isPlayer
            ? [opponentSlot1, opponentSlot2]
            : [playerSlot1, playerSlot2];
        final allOtherSlots = _allActiveSlots()
            .where((s) => s != attacker)
            .toList();

        bool redirected = false;

        // Follow me
        for (final slot in opposingSlots) {
          if (slot != null && slot.health > 0 && slot.isFollowMeTarget) {
            defender = slot;
            redirected = true;
            break;
          }
        }

        // Lightning Rod
        if (!redirected && move.type == ElementalType.electric) {
          for (final slot in allOtherSlots) {
            if (slot.health > 0 &&
                slot.abilities.any((a) => a.name == 'Lightning Rod')) {
              defender = slot;
              redirected = true;
              break;
            }
          }
        }

        // Storm Drain
        if (!redirected && move.type == ElementalType.aquatic) {
          for (final slot in allOtherSlots) {
            if (slot.health > 0 &&
                slot.abilities.any((a) => a.name == 'Storm Drain')) {
              defender = slot;
              redirected = true;
              break;
            }
          }
        }

        if (defender == null || defender.health <= 0) {
          if (i == 0) addLog('But the target is gone!');
          break;
        }
        await _applyMoveToTarget(
          attacker: attacker,
          move: move,
          defender: defender,
          multiTargetPenalty: 1.0,
        );
      }

      if (_isBattleOver()) break;
    }

    attacker.hasMovedThisTurn = true;

    // --- Explosion / Self-Destruct Faint ---
    if (move.isSelfDestruct && attacker.health > 0) {
      attacker.health = 0;
      addLog('${attacker.name} exploded!');
      notifyListeners();
      if (!isTesting) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }
  }

  // ──────────────────────────────────────────────
  // Apply move to a single defender
  // ──────────────────────────────────────────────

  Future<void> _applyMoveToTarget({
    required BattleOrganism attacker,
    required Move move,
    required BattleOrganism defender,
    required double multiTargetPenalty,
  }) async {
    // ── Accuracy Check ──
    int accuracy = _calculateMoveAccuracy(attacker, defender, move);

    if (Random().nextInt(100) >= accuracy) {
      addLog('...but it missed!');

      // Blunder Policy: Speed boost on miss
      if (attacker.isItemValid) {
        for (final effect in attacker.organism.equippedTalisman!.effects) {
          if (effect.type == TalismanEffectType.missStatBoost) {
            attacker.talismanConsumed = true;
            attacker.isItemRevealed = true;
            await _applyStatChange(attacker, effect.stat ?? 'speed', 2);
          }
        }
      }

      notifyListeners();
      return;
    }

    // Status-only moves: apply effects and return
    if (move.baseDamage == 0) {
      // Protect check for status moves
      if (defender.isProtected && move.name != 'Feint' && move.doublesTarget != MoveTarget.self) {
        addLog('${defender.name} protected itself!');
        return;
      }
      await _applyEffects(attacker, defender, move);
      notifyListeners();
      return;
    }
    
    // Protect check for attacks
    if (defender.isProtected && move.name != 'Feint') {
      addLog('${defender.name} protected itself!');
      return;
    }

    final bool moldBreakerActive = attacker.abilities.any((ab) => ab.name == 'Mold Breaker');

    // Storm Drain / Lightning Rod (already handled in resolveTarget but let's be safe for multi-hit or subsequent effects)
    if (defender.abilities.any((ab) => ab.name == 'Storm Drain') &&
        move.type == ElementalType.aquatic && !moldBreakerActive) {
      addLog('${defender.name}\'s Storm Drain absorbed the attack!');
      await _applyStatChange(defender, 'power', 1);
      notifyListeners();
      return;
    }
    if (defender.abilities.any((ab) => ab.name == 'Lightning Rod') &&
        move.type == ElementalType.electric && !moldBreakerActive) {
      addLog('${defender.name}\'s Lightning Rod absorbed the attack!');
      await _applyStatChange(defender, 'power', 1);
      notifyListeners();
      return;
    }

    // ── Damage calculation ──
    final damageResult = calculateDamage(
      attacker,
      defender,
      move,
      multiTargetPenalty: multiTargetPenalty,
    );
    int finalDmg = damageResult.damage;
    double typeMod = damageResult.typeMultiplier;
    bool isCrit = damageResult.isCrit;

    if (isCrit) {
      addLog('A critical hit!');
    }

    // Random variance [0.85–1.0] already handled in calculateDamage

    // Endure
    if (defender.isEnduring && finalDmg >= defender.health) {
      finalDmg = (defender.health - 1).toInt();
      addLog('${defender.name} braced itself and endured the hit!');
    }

    defender.health = (defender.health - finalDmg).clamp(0, defender.maxHealth);

    if (finalDmg > 0) {
      defender.lastHitById = attacker.organism.id;
      if (onDamage != null) onDamage!(defender, finalDmg);

      // Bide Accumulation
      if (defender.isBiding) {
        defender.bideDamage += finalDmg;
      }
    }

    // Faint Handlers
    if (defender.health <= 0) {
      // Destiny Bond
      if (defender.isDestinyBondActive && attacker.health > 0) {
        attacker.health = 0;
        addLog('${attacker.name} was taken down by Destiny Bond!');
      }
      // Grudge
      if (defender.grudgeActive &&
          attacker.health > 0 &&
          attacker.organism.moveStamina.containsKey(move.name)) {
        attacker.organism.moveStamina[move.name] = 0;
        addLog(
          "${attacker.name}'s ${move.name} lost all its stamina due to the Grudge!",
        );
      }
    }

    // Break Disguise (Mimic/Illusion)
    if (defender.isDisguised && finalDmg > 0) {
      defender.isDisguised = false;
      defender.disguisedAs = null;
      defender.isAbilityRevealed = true;
      addLog('${defender.organism.baseOrganism.name}\'s illusion wore off!');
    }

    // Consume Gem
    if (attacker.organism.equippedTalisman != null &&
        !attacker.talismanConsumed) {
      for (final effect in attacker.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.gemBoost &&
            effect.stat == move.type.toString().split('.').last.toLowerCase()) {
          attacker.talismanConsumed = true;
          addLog(
            'The ${attacker.organism.equippedTalisman!.name} strengthened ${attacker.organism.baseOrganism.name}\'s power!',
          );
          break;
        }
      }
    }

    // Absorb Bulb: Power boost when hit by Aquatic
    if (defender.organism.equippedTalisman != null &&
        !defender.talismanConsumed &&
        finalDmg > 0 &&
        move.type == ElementalType.aquatic) {
      for (final effect in defender.organism.equippedTalisman!.effects) {
        if (effect.stat == 'power' && effect.condition == 'hit_by_aquatic') {
          defender.talismanConsumed = true;
          defender.isItemRevealed = true;
          await _applyStatChange(defender, 'power', 1);
        }
      }
    }

    defender.tookDamageThisTurn = true;

    if (typeMod >= 3.9) {
      addLog('It\'s extremely effective!');
    } else if (typeMod > 1.1) {
      addLog('It\'s super effective!');
    }
    if (typeMod > 0 && typeMod <= 0.26) {
      addLog('It\'s barely effective...');
    } else if (typeMod > 0 && typeMod < 0.9) {
      addLog('It\'s not very effective...');
    }
    if (typeMod == 0.0) {
      addLog('It doesn\'t affect ${defender.organism.baseOrganism.name}!');
    }

    // --- Rattled ---
    if (defender.abilities.any((ab) => ab.name == 'Rattled') && finalDmg > 0) {
      if (move.type == ElementalType.arthropod ||
          move.type == ElementalType.spectral ||
          move.type == ElementalType.darkness) {
        await _applyStatChange(defender, 'speed', 1);
      }
    }

    // --- Weak Armor ---
    if (defender.abilities.any((ab) => ab.name == 'Weak Armor') &&
        finalDmg > 0 &&
        move.category == MoveCategory.physical) {
      await _applyStatChange(defender, 'defense', -1);
      await _applyStatChange(defender, 'speed', 2);
    }

    // --- Cursed Body ---
    if (defender.abilities.any((ab) => ab.name == 'Cursed Body') &&
        finalDmg > 0) {
      if (Random().nextDouble() < 0.3) {
        attacker.disabledMoves[move.name] = 4; // Disable for 4 turns
        addLog('${attacker.name}\'s ${move.name} was disabled by Cursed Body!');
      }
    }

    // --- Pickpocket ---
    if (defender.abilities.any((ab) => ab.name == 'Pickpocket') &&
        finalDmg > 0 &&
        move.isContact) {
      if (defender.organism.equippedTalisman == null &&
          attacker.organism.equippedTalisman != null &&
          !attacker.talismanConsumed) {
        // Steal item
        defender.organism.equippedTalisman = attacker.organism.equippedTalisman;
        attacker.organism.equippedTalisman = null;
        addLog(
          '${defender.name} stole ${attacker.name}\'s ${defender.organism.equippedTalisman!.name}!',
        );
      }
    }

    // --- Contact Abilities ---
    if (move.isContact && finalDmg > 0 && !attacker.abilities.any((a) => a.name == 'Long Reach')) {
      await _applyContactAbilities(attacker, defender, move);
    }

    // Drain
    if (move.drainPercent > 0 && attacker.health > 0) {
      double drainMult = move.drainPercent;
      if (attacker.organism.equippedTalisman != null &&
          !attacker.talismanConsumed) {
        for (final effect in attacker.organism.equippedTalisman!.effects) {
          if (effect.type == TalismanEffectType.drainBoost) {
            drainMult *= effect.magnitude;
          }
        }
      }
      final heal = (finalDmg * drainMult).round();
      attacker.health = (attacker.health + heal).clamp(0, attacker.maxHealth);
      addLog('${attacker.organism.baseOrganism.name} absorbed energy!');
    }

    // Recoil
    if (move.recoilPercent > 0 && attacker.health > 0) {
      final recoil = (finalDmg * move.recoilPercent).round();
      attacker.health = (attacker.health - recoil).clamp(0, attacker.maxHealth);
      addLog('${attacker.organism.baseOrganism.name} was hurt by recoil!');
    }

    // Life Orb Recoil
    if (attacker.organism.equippedTalisman != null &&
        finalDmg > 0 &&
        attacker.health > 0) {
      for (final effect in attacker.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.recoilDamage) {
          final recoil = (attacker.maxHealth / 10).round();
          attacker.health = (attacker.health - recoil).clamp(0, attacker.maxHealth);
          addLog('${attacker.name} was hurt by its Life Orb!');
          break;
        }
      }
    }

    // Apply secondary effects
    bool sheerForce = attacker.abilities.any((ab) => ab.name == 'Sheer Force') &&
        move.effects.any((e) => e.target == 'opponent');
    
    if (sheerForce) {
      // Sheer Force ignores secondary effects but keeps self-buffs
    } else {
      await _applyEffects(attacker, defender, move);
    }

    // Thrash/Outrage/Petal Dance Lock
    if (move.effects.any((e) => e.type == MoveEffectType.thrash) &&
        defender.health >= 0 &&
        defender.tookDamageThisTurn) {
      if (attacker.thrashTurnCount == 0) {
        attacker.thrashTurnCount = 2 + Random().nextInt(2); // 2-3 turns
        attacker.thrashMove = move;
      }
      attacker.thrashTurnCount--;
      if (attacker.thrashTurnCount <= 0) {
        await _applyStatus(
          attacker,
          const StatusEffect(type: StatusEffectType.confusion),
        );
        attacker.thrashMove = null;
        attacker.thrashTurnCount = 0;
      }
    }

    // Check for post-damage items (Berries)
    await _checkPostDamageItems(attacker);
    await _checkPostDamageItems(defender);

    notifyListeners();
    if (!isTesting) await Future.delayed(const Duration(milliseconds: 800));
  }

  // ──────────────────────────────────────────────
  // Apply move effects (status, stat changes, etc.)
  // ──────────────────────────────────────────────

  Future<void> _applyEffects(
    BattleOrganism attacker,
    BattleOrganism defender,
    Move move,
  ) async {
    for (final effect in move.effects) {
      // Determine the target organism for this effect
      final effectTarget = effect.target == 'self' ? attacker : defender;

      // Chance check
      if (Random().nextInt(100) >= effect.chance) continue;

      switch (effect.type) {
        case MoveEffectType.statChange:
          await _applyStatChange(effectTarget, effect.stat, effect.value, source: attacker);
          break;
        case MoveEffectType.multiStatChange:
          final stats = effect.stat.split(',');
          final vals = effect.value.toString().split(',');
          for (int i = 0; i < stats.length && i < vals.length; i++) {
            await _applyStatChange(
              effectTarget,
              stats[i].trim(),
              int.tryParse(vals[i].trim()) ?? 0,
              source: attacker,
            );
          }
          break;
        case MoveEffectType.heal:
          final heal = (effectTarget.maxHealth * (effect.value / 100.0))
              .round();
          effectTarget.health = (effectTarget.health + heal).clamp(
            0,
            effectTarget.maxHealth,
          );
          addLog('${effectTarget.organism.baseOrganism.name} restored HP!');
          break;
        case MoveEffectType.statusPoison:
          await _applyStatus(
            effectTarget,
            const StatusEffect(type: StatusEffectType.poison),
          );
          break;
        case MoveEffectType.statusBurn:
          await _applyStatus(
            effectTarget,
            const StatusEffect(type: StatusEffectType.burn),
          );
          break;
        case MoveEffectType.statusSleep:
          await _applyStatus(
            effectTarget,
            const StatusEffect(type: StatusEffectType.sleep),
          );
          break;
        case MoveEffectType.statusParalysis:
          await _applyStatus(
            effectTarget,
            const StatusEffect(type: StatusEffectType.paralysis),
          );
          break;
        case MoveEffectType.statusFreeze:
          await _applyStatus(
            effectTarget,
            const StatusEffect(type: StatusEffectType.freeze),
          );
          break;
        case MoveEffectType.statusBleed:
          await _applyStatus(
            effectTarget,
            const StatusEffect(type: StatusEffectType.bleed),
          );
          break;
        case MoveEffectType.bide:
          attacker.isBiding = true;
          attacker.bideTurns = 2; // Fixed 2-turn bide
          attacker.bideDamage = 0;
          addLog('${attacker.name} is biding its time!');
          break;
        case MoveEffectType.destinyBond:
          attacker.isDestinyBondActive = true;
          addLog('${attacker.name} is trying to take its foe with it!');
          break;
        case MoveEffectType.endure:
          attacker.isEnduring = true;
          addLog('${attacker.name} braced itself!');
          break;
        case MoveEffectType.ingrain:
          attacker.isIngrained = true;
          addLog('${attacker.name} planted its roots!');
          break;
        case MoveEffectType.redirection:
          attacker.isFollowMeTarget = true;
          addLog('${attacker.name} became the center of attention!');
          break;
        case MoveEffectType.feint:
          if (defender.isProtected) {
            defender.isProtected = false;
            addLog("${defender.name}'s protection was broken!");
          }
          break;
        case MoveEffectType.haze:
          _allActiveSlots().forEach((s) => s.resetStatStages());
          addLog('All stat changes were eliminated!');
          break;
        case MoveEffectType.lunarBlessing:
          final heal = (attacker.maxHealth * 0.25).round();
          attacker.health = (attacker.health + heal).clamp(
            0,
            attacker.maxHealth,
          );
          attacker.clearStatusEffects();
          addLog('${attacker.name} received a lunar blessing!');
          break;
        case MoveEffectType.electrify:
          defender.isElectrified = true;
          addLog("${defender.name}'s move was electrified!");
          break;
        case MoveEffectType.foresight:
          defender.isForesighted = true;
          defender.evasionStage = 0;
          addLog("${defender.name} was identified!");
          break;
        case MoveEffectType.forestsCurse:
          defender.hasForestsCurse = true;
          addLog("${defender.name} was cursed by the forest!");
          break;
        case MoveEffectType.grudge:
          attacker.grudgeActive = true;
          addLog("${attacker.name} wants its foe to bear a grudge!");
          break;
        case MoveEffectType.protect:
          attacker.isProtected = true;
          addLog('${attacker.name} protected itself!');
          break;
        default:
          break;
      }
    }
    notifyListeners();
  }

  Future<void> _applyStatChange(
    BattleOrganism target,
    String stat,
    int value, {
    BattleOrganism? source,
  }) async {
    if (value == 0) return;

    // Substitute blocks stat reductions from opponents
    if (value < 0 &&
        source != null &&
        source != target &&
        target.substituteHealth > 0) {
      return;
    }

    int effectiveValue = value;
    if (target.abilities.any((a) => a.name == 'Simple')) {
      effectiveValue *= 2;
    }
    if (target.abilities.any((a) => a.name == 'Contrary')) {
      effectiveValue = -effectiveValue;
    }

    bool changed = false;
    switch (stat.toLowerCase()) {
      case 'all':
        await _applyStatChange(target, 'attack', value, source: source);
        await _applyStatChange(target, 'defense', value, source: source);
        await _applyStatChange(target, 'power', value, source: source);
        await _applyStatChange(target, 'resistance', value, source: source);
        await _applyStatChange(target, 'speed', value, source: source);
        return;
      case 'attack':
        final old = target.attackStage;
        target.attackStage = (target.attackStage + effectiveValue).clamp(-6, 6);
        changed = old != target.attackStage;
        break;
      case 'defense':
        final old = target.defenseStage;
        target.defenseStage = (target.defenseStage + effectiveValue).clamp(-6, 6);
        changed = old != target.defenseStage;
        break;
      case 'power':
        final old = target.powerStage;
        target.powerStage = (target.powerStage + effectiveValue).clamp(-6, 6);
        changed = old != target.powerStage;
        break;
      case 'resistance':
        final old = target.resistanceStage;
        target.resistanceStage =
            (target.resistanceStage + effectiveValue).clamp(-6, 6);
        changed = old != target.resistanceStage;
        break;
      case 'speed':
        final old = target.speedStage;
        target.speedStage = (target.speedStage + effectiveValue).clamp(-6, 6);
        changed = old != target.speedStage;
        break;
      case 'accuracy':
        final old = target.accuracyStage;
        target.accuracyStage = (target.accuracyStage + effectiveValue).clamp(-6, 6);
        changed = old != target.accuracyStage;
        break;
      case 'evasion':
        final old = target.evasionStage;
        target.evasionStage = (target.evasionStage + effectiveValue).clamp(-6, 6);
        changed = old != target.evasionStage;
        break;
    }

    if (changed) {
      final String direction = effectiveValue > 0 ? 'rose' : 'fell';
      addLog('${target.name}\'s ${stat.toUpperCase()} $direction!');

      // --- Defiant ---
      if (effectiveValue < 0 && source != null && source != target) {
        if (target.abilities.any((ab) => ab.name == 'Defiant')) {
          addLog("${target.name}'s Defiant triggered!");
          await _applyStatChange(target, 'attack', 2);
        }
        if (target.abilities.any((ab) => ab.name == 'Competitive')) {
          addLog("${target.name}'s Competitive triggered!");
          await _applyStatChange(target, 'power', 2);
        }
        if (target.abilities.any((ab) => ab.name == 'Rattled')) {
          addLog("${target.name}'s Rattled triggered!");
          await _applyStatChange(target, 'speed', 1);
        }
      }

      notifyListeners();
      if (!isTesting) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } else if (value != 0) {
      addLog('${target.name}\'s ${stat.toUpperCase()} won\'t go any ${value > 0 ? "higher" : "lower"}!');
      notifyListeners();
      if (!isTesting) {
        await Future.delayed(const Duration(milliseconds: 1000));
      }
    }
  }

  Future<bool> _applyStatus(
    BattleOrganism target,
    StatusEffect effect, {
    int chance = 100,
    BattleOrganism? source,
  }) async {
    if (Random().nextInt(100) >= chance) return false;
    if (target.health <= 0) return false;

    // Safeguard check (per team)
    if (effect.type != StatusEffectType.none) {
      if ((target.isPlayer && playerSafeguardTurns > 0) ||
          (!target.isPlayer && opponentSafeguardTurns > 0)) {
        addLog('${target.name} is protected by Safeguard!');
        return false;
      }
    }

    // Type Immunities
    if (effect.type == StatusEffectType.poison) {
      if (target.types.contains(ElementalType.toxic) ||
          target.types.contains(ElementalType.metal)) {
        if (source == null || !source.abilities.any((ab) => ab.name == 'Corrosion')) {
          return false;
        }
      }
    }
    if (effect.type == StatusEffectType.burn && target.types.contains(ElementalType.blaze)) return false;
    if (effect.type == StatusEffectType.paralysis && target.types.contains(ElementalType.electric)) return false;
    if (effect.type == StatusEffectType.freeze && target.types.contains(ElementalType.cryo)) return false;

    // Ability Immunities
    for (final ab in target.abilities) {
      if (ab.name == 'Water Veil' && effect.type == StatusEffectType.burn) return false;
      if (ab.name == 'Limber' && effect.type == StatusEffectType.paralysis) return false;
      if (ab.name == 'Immunity' && effect.type == StatusEffectType.poison) return false;
      if (ab.name == 'Insomnia' && effect.type == StatusEffectType.sleep) return false;
      if (ab.name == 'Vital Spirit' && effect.type == StatusEffectType.sleep) return false;
      if (ab.name == 'Own Tempo' && effect.type == StatusEffectType.confusion) return false;
      if (ab.name == 'Magma Armor' && effect.type == StatusEffectType.freeze) return false;
      if (ab.name == 'Oblivious' && effect.type == StatusEffectType.taunt) return false;
    }

    // Existing Status Check
    if (target.statusEffects.any((e) => e.type == effect.type)) return false;

    // Randomized duration logic if not specified
    int duration = effect.duration;
    if (duration == -1) {
      if (effect.type == StatusEffectType.sleep) {
        duration = 2 + Random().nextInt(3); // 2-4 turns
      } else if (effect.type == StatusEffectType.confusion) {
        duration = 1 + Random().nextInt(4); // 1-4 turns
      }
    }

    final finalEffect = StatusEffect(
      type: effect.type,
      duration: duration,
    );

    target.addStatusEffect(finalEffect);
    addLog('${target.name} ${finalEffect.startMessage}');
    notifyListeners();
    if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));
    return true;
  }

  // ──────────────────────────────────────────────
  // End-of-turn effects
  // ──────────────────────────────────────────────

  Future<void> _applyEndOfTurnEffects() async {
    // 1. Weather Damage and Weather-Based Ability Effects
    if (currentWeather.weather != Weather.none) {
      for (final slot in _allActiveSlots()) {
        if (slot.health <= 0) continue;

        // Ability-based Weather Healing/Damage
        if (!slot.isAbilitySuppressed) {
          for (final ab in slot.abilities) {
            // Rain Dish
            if (ab.name == 'Rain Dish' &&
                (currentWeather.weather == Weather.rain ||
                    currentWeather.weather == Weather.heavyRain)) {
              final heal = (slot.maxHealth / 16).round().clamp(1, 9999);
              slot.health = (slot.health + heal).clamp(0, slot.maxHealth);
              addLog('${slot.name}\'s Rain Dish restored its HP!');
            }
            // Ice Body
            if (ab.name == 'Ice Body' &&
                (currentWeather.weather == Weather.hail ||
                    currentWeather.weather == Weather.snowstorm)) {
              final heal = (slot.maxHealth / 16).round().clamp(1, 9999);
              slot.health = (slot.health + heal).clamp(0, slot.maxHealth);
              addLog('${slot.name}\'s Ice Body restored its HP!');
            }
            // Dry Skin
            if (ab.name == 'Dry Skin') {
              if (currentWeather.weather == Weather.rain ||
                  currentWeather.weather == Weather.heavyRain) {
                final heal = (slot.maxHealth / 8).round().clamp(1, 9999);
                slot.health = (slot.health + heal).clamp(0, slot.maxHealth);
                addLog('${slot.name}\'s Dry Skin restored its HP!');
              } else if (currentWeather.weather == Weather.sunny ||
                  currentWeather.weather == Weather.intenseSun) {
                final damage = (slot.maxHealth / 8).round().clamp(1, 9999);
                slot.health = (slot.health - damage).clamp(0, slot.maxHealth);
                addLog('${slot.name} was hurt by its Dry Skin in the sunlight!');
              }
            }
            // Solar Power
            if (ab.name == 'Solar Power' &&
                (currentWeather.weather == Weather.sunny ||
                    currentWeather.weather == Weather.intenseSun)) {
              final damage = (slot.maxHealth / 8).round().clamp(1, 9999);
              slot.health = (slot.health - damage).clamp(0, slot.maxHealth);
              addLog('${slot.name} is hurt by its Solar Power in the sunlight!');
            }
          }
        }

        // Weather Damage
        bool isImmune = slot.abilities
            .any((a) => a.name == 'Overcoat' && !slot.isAbilitySuppressed);
        double damageMult = 0.0;
        String? weatherName;

        switch (currentWeather.weather) {
          case Weather.sandstorm:
            if (!isImmune &&
                !slot.types.contains(ElementalType.metal) &&
                !slot.types.contains(ElementalType.earth) &&
                !slot.types.contains(ElementalType.rock)) {
              damageMult = 0.0625; // 1/16
              weatherName = 'sandstorm';
            }
            break;
          case Weather.hail:
            if (!isImmune && !slot.types.contains(ElementalType.cryo)) {
              damageMult = 0.0625; // 1/16
              weatherName = 'hail';
            }
            break;
          case Weather.typhoon:
          case Weather.hurricane:
            if (!isImmune &&
                !slot.types.contains(ElementalType.aquatic) &&
                !slot.types.contains(ElementalType.flying) &&
                !slot.types.contains(ElementalType.electric)) {
              damageMult = 0.083; // 1/12
              weatherName = currentWeather.weather == Weather.typhoon
                  ? 'typhoon'
                  : 'hurricane';
            }
            break;
          case Weather.tornado:
            if (!isImmune) {
              damageMult = 0.125; // 1/8
              weatherName = 'tornado';
            }
            break;
          case Weather.tsunami:
            if (!slot.types.contains(ElementalType.aquatic)) {
              damageMult = 0.125; // 1/8
              weatherName = 'tsunami';
            }
            break;
          case Weather.earthquake:
            if (!slot.types.contains(ElementalType.flying)) {
              damageMult = 0.125; // 1/8
              weatherName = 'earthquake';
            }
            break;
          case Weather.volcanoEruption:
            if (!slot.types.contains(ElementalType.blaze)) {
              damageMult = 0.125; // 1/8
              weatherName = 'volcanic eruption';
            }
            break;
          case Weather.blizzard:
            if (!slot.types.contains(ElementalType.cryo)) {
              damageMult = 0.083; // 1/12
              weatherName = 'blizzard';
            }
            break;
          default:
            break;
        }

        if (damageMult > 0) {
          final damage = (slot.maxHealth * damageMult).round().clamp(1, 9999);
          slot.health = (slot.health - damage).clamp(0, slot.maxHealth);
          addLog('${slot.name} is buffeted by the $weatherName!');
        }
      }
    }

    notifyListeners();

    // 2. Per-Slot Ability and Status Effects
    for (final slot in _allActiveSlots()) {
      if (slot.health <= 0) continue;

      // Shed Skin
      if (slot.abilities
          .any((ab) => ab.name == 'Shed Skin' && !slot.isAbilitySuppressed)) {
        if (slot.statusEffects.isNotEmpty && Random().nextDouble() < 0.33) {
          slot.clearStatusEffects();
          addLog('${slot.name}\'s Shed Skin cured its status condition!');
        }
      }

      // Bad Dreams
      if (slot.statusEffects.any((se) => se.type == StatusEffectType.sleep)) {
        final opposingSlots = (slot == playerSlot1 || slot == playerSlot2)
            ? [opponentSlot1, opponentSlot2]
            : [playerSlot1, playerSlot2];
        if (opposingSlots.any(
          (foe) =>
              foe != null &&
              foe.health > 0 &&
              foe.abilities.any((ab) => ab.name == 'Bad Dreams'),
        )) {
          final damageAmount =
              (slot.maxHealth / 4).floor().clamp(1, slot.maxHealth);
          slot.health -= damageAmount;
          addLog(
            '${slot.organism.baseOrganism.name} is tormented by bad dreams!',
          );
        }
      }

      // Healer
      if (slot.abilities.any((ab) => ab.name == 'Healer') &&
          slot.statusEffects.any((se) => se.type != StatusEffectType.none)) {
        if (Random().nextDouble() < 0.3) {
          slot.clearStatusEffects();
          addLog(
            '${slot.organism.baseOrganism.name}\'s Healer cured its status conditions!',
          );
        }
      }

      // Honey Gather
      if (slot.abilities.any((ab) => ab.name == 'Honey Gather')) {
        if (Random().nextDouble() < 0.5) {
          addLog('${slot.organism.baseOrganism.name} gathered some honey!');
        }
      }

      // Poison / Burn damage
      for (final se in List<StatusEffect>.from(slot.statusEffects)) {
        switch (se.type) {
          case StatusEffectType.poison:
            final dmg = (slot.maxHealth * 0.0625).round().clamp(1, 99999);
            slot.health = (slot.health - dmg).clamp(0, slot.maxHealth);
            addLog('${slot.organism.baseOrganism.name} was hurt by poison!');
            break;
          case StatusEffectType.burn:
            final dmg = (slot.maxHealth * 0.0625).round().clamp(1, 99999);
            slot.health = (slot.health - dmg).clamp(0, slot.maxHealth);
            addLog('${slot.organism.baseOrganism.name} was hurt by burn!');
            break;
          case StatusEffectType.bleed:
            final dmg = (slot.maxHealth * 0.05).round().clamp(1, 99999);
            slot.health = (slot.health - dmg).clamp(0, slot.maxHealth);
            addLog('${slot.organism.baseOrganism.name} is bleeding!');
            break;
          default:
            break;
        }
      }

      // Reset per-turn flags
      slot.tookDamageThisTurn = false;
      slot.isProtected = false;
      slot.isEnduring = false;
      slot.isDestinyBondActive = false;
      slot.isFollowMeTarget = false;
      slot.helpingHandBoosted = false;
      slot.isElectrified = false;

      // --- Yawn Delay ---
      if (slot.yawnTurns > 0) {
        slot.yawnTurns--;
        if (slot.yawnTurns == 0) {
          if (slot.statusEffect.type == StatusEffectType.none) {
            _applyStatus(
              slot,
              const StatusEffect(type: StatusEffectType.sleep, duration: 3),
            );
            addLog('${slot.name} fell asleep!');
          }
        } else {
          addLog('${slot.name} is getting drowsy...');
        }
      }

      // --- Ingrain Healing ---
      if (slot.isIngrained && slot.health > 0 && slot.health < slot.maxHealth) {
        final heal = (slot.maxHealth / 16).round().clamp(1, 9999);
        slot.health = (slot.health + heal).clamp(0, slot.maxHealth);
        addLog('${slot.name} absorbed nutrients with its roots!');
      }

      // Binding Band / Clamping damage
      if (slot.clampingTurns > 0) {
        slot.clampingTurns--;
        double trapMult = 1.0;
        final source = _allActiveSlots().firstWhere(
          (s) =>
              s != slot &&
              s.organism.equippedTalisman != null &&
              !s.talismanConsumed &&
              s.organism.equippedTalisman!.effects.any(
                (e) => e.type == TalismanEffectType.bindingBandBoost,
              ),
          orElse: () => slot,
        );

        if (source != slot) {
          trapMult = 1.5;
          source.isItemRevealed = true;
        }

        final damage =
            (slot.maxHealth * 0.125 * trapMult).round().clamp(1, 99999);
        slot.health = (slot.health - damage).clamp(0, slot.maxHealth);
        addLog(
          '${slot.organism.baseOrganism.name} is hurt by the clamping effect!',
        );
      }

      // Unnerve Check
      final opposingSlots = (slot == playerSlot1 || slot == playerSlot2)
          ? [opponentSlot1, opponentSlot2]
          : [playerSlot1, playerSlot2];
      final foeHasUnnerve = opposingSlots.any(
        (foe) =>
            foe != null &&
            foe.health > 0 &&
            foe.abilities.any((ab) => ab.name == 'Unnerve'),
      );

      if (slot.organism.equippedTalisman != null &&
          !slot.talismanConsumed &&
          slot.itemDisabledTurns <= 0 &&
          !foeHasUnnerve) {
        for (final effect in slot.organism.equippedTalisman!.effects) {
          if (effect.type == TalismanEffectType.onTurnHeal) {
            final healAmount = (slot.maxHealth * effect.magnitude).round();
            slot.health = (slot.health + healAmount).clamp(0, slot.maxHealth);
            slot.talismanConsumed = true;
            break;
          } else if (effect.type == TalismanEffectType.berryCureStatus &&
              slot.statusEffects.isNotEmpty) {
            final statusToCure = effect.stat;
            if (statusToCure == 'all' ||
                slot.statusEffects.any(
                  (s) => s.type.toString().split('.').last == statusToCure,
                )) {
              slot.clearStatusEffects();
              slot.talismanConsumed = true;
              slot.isItemRevealed = true;
              addLog(
                '${slot.organism.equippedTalisman!.name} cured ${slot.organism.baseOrganism.name}\'s status!',
              );
            }
          }
        }
      }
    }

    // --- Field Effect Turn Decrements ---
    if (playerReflectTurns > 0) {
      playerReflectTurns--;
      if (playerReflectTurns == 0) addLog('Your Reflect wore off!');
    }
    if (playerLightScreenTurns > 0) {
      playerLightScreenTurns--;
      if (playerLightScreenTurns == 0) addLog('Your Light Screen wore off!');
    }
    if (playerSafeguardTurns > 0) {
      playerSafeguardTurns--;
      if (playerSafeguardTurns == 0) addLog('Your Safeguard wore off!');
    }
    if (playerTailwindTurns > 0) {
      playerTailwindTurns--;
      if (playerTailwindTurns == 0) addLog('Your Tailwind petered out!');
    }
    if (playerAuroraVeilTurns > 0) {
      playerAuroraVeilTurns--;
      if (playerAuroraVeilTurns == 0) addLog('Your Aurora Veil wore off!');
    }

    if (opponentReflectTurns > 0) {
      opponentReflectTurns--;
      if (opponentReflectTurns == 0) addLog('Foe\'s Reflect wore off!');
    }
    if (opponentLightScreenTurns > 0) {
      opponentLightScreenTurns--;
      if (opponentLightScreenTurns == 0) {
        addLog('Foe\'s Light Screen wore off!');
      }
    }
    if (opponentSafeguardTurns > 0) {
      opponentSafeguardTurns--;
      if (opponentSafeguardTurns == 0) addLog('Foe\'s Safeguard wore off!');
    }
    if (opponentTailwindTurns > 0) {
      opponentTailwindTurns--;
      if (opponentTailwindTurns == 0) addLog('Foe\'s Tailwind petered out!');
    }
    if (opponentAuroraVeilTurns > 0) {
      opponentAuroraVeilTurns--;
      if (opponentAuroraVeilTurns == 0) addLog('Foe\'s Aurora Veil wore off!');
    }

    if (trickRoomTurns > 0) {
      trickRoomTurns--;
      if (trickRoomTurns == 0) addLog('The dimensions returned to normal!');
    }
    if (gravityTurns > 0) {
      gravityTurns--;
      if (gravityTurns == 0) addLog('Gravity returned to normal!');
    }
    if (terrainTurnsLeft > 0) {
      terrainTurnsLeft--;
      if (terrainTurnsLeft == 0) {
        addLog('The ${currentTerrain.terrain.name} terrain subsided.');
        currentTerrain = const TerrainEffect(terrain: Terrain.none);
      }
    }
    if (currentWeather.duration > 0 && currentWeather.weather != Weather.none) {
      final newDuration = currentWeather.duration - 1;
      if (newDuration <= 0) {
        addLog(currentWeather.endMessage);
        currentWeather = const WeatherEffect(weather: Weather.none);
      } else {
        currentWeather = WeatherEffect(
          weather: currentWeather.weather,
          duration: newDuration,
        );
      }
    }

    // Clear Stun from all participants
    for (final slot in _allActiveSlots()) {
      slot.statusEffects = slot.statusEffects
          .where((se) => se.type != StatusEffectType.stun)
          .toList();
    }

    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // Faint checking and bench promotion
  // ──────────────────────────────────────────────

  /// Identifies fainted organisms, removes them from slots, and adds logs.
  /// Does NOT perform replacements.
  Future<void> _processFaints() async {
    bool anyNewFaints = false;

    // We check all slots
    final slots = [
      (opponentSlot1, () => opponentSlot1 = null),
      (opponentSlot2, () => opponentSlot2 = null),
      (playerSlot1, () => playerSlot1 = null),
      (playerSlot2, () => playerSlot2 = null),
    ];

    for (final (bo, clear) in slots) {
      if (bo != null && bo.health <= 0) {
        // Find killer before clearing
        BattleOrganism? killer;
        if (bo.lastHitById != null) {
          killer = slots
              .map((s) => s.$1)
              .firstWhere(
                (s) => s?.organism.id == bo.lastHitById,
                orElse: () => null,
              );
        }

        addLog('${bo.organism.baseOrganism.name} fainted!');
        if (!isTesting) {
          _audio.playOrganismCry(bo.organism.baseOrganism.cry);
        }

        if (onOpponentFainted != null && killer != null) {
          await onOpponentFainted!(killer, bo);
        }

        clear();
        anyNewFaints = true;
        notifyListeners();
        if (!isTesting) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }
    }

    if (anyNewFaints && _isBattleOver()) {
      _endBattle();
    }
  }

  /// Refills empty slots from the bench.
  /// Returns true if a player switch is needed (pauses execution).
  Future<bool> _processReplacements() async {
    if (_isBattleOver()) return false;

    // Opponent replacements (automatic)
    if (opponentSlot1 == null && opponentBench.isNotEmpty) {
      final nextIdx = _popBench(opponentBench);
      opponentIdx1 = nextIdx;
      opponentSlot1 = BattleOrganism(opponentTeam[nextIdx]);
      _checkMimic(opponentSlot1!);
      addLog('Opponent sent out ${opponentSlot1!.organism.baseOrganism.name}!');
      if (!isTesting) {
        _audio.playOrganismCry(opponentSlot1!.organism.baseOrganism.cry);
      }
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));
    }
    if (opponentSlot2 == null && opponentBench.isNotEmpty) {
      final nextIdx = _popBench(opponentBench);
      opponentIdx2 = nextIdx;
      opponentSlot2 = BattleOrganism(opponentTeam[nextIdx]);
      _checkMimic(opponentSlot2!);
      addLog('Opponent sent out ${opponentSlot2!.organism.baseOrganism.name}!');
      if (!isTesting) {
        _audio.playOrganismCry(opponentSlot2!.organism.baseOrganism.cry);
      }
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));
    }

    // Trigger entry abilities for newly sent out opponents
    if (opponentSlot1 != null || opponentSlot2 != null) {
      await _triggerEntryAbilities();
    }

    // Player replacements (requires UI interaction)
    if (playerSlot1 == null && playerBench.isNotEmpty) {
      switchNeededSlot = 1;
      currentState = DoubleBattleState.waitingForSwitch;
      notifyListeners();
      return true;
    }
    if (playerSlot2 == null && playerBench.isNotEmpty) {
      switchNeededSlot = 2;
      currentState = DoubleBattleState.waitingForSwitch;
      notifyListeners();
      return true;
    }

    return false;
  }

  /// Called from UI when the player picks a bench mon to send into [slotNumber].
  Future<void> confirmSwitch(int benchTeamIndex, int slotNumber) async {
    currentState =
        DoubleBattleState.executing; // Prevent UI loops while processing
    notifyListeners();

    playerHistory.recordSwitch(benchTeamIndex);
    final newOrg = BattleOrganism(
      playerTeam[benchTeamIndex],
      isRogueMode: isRogueMode,
    );
    _checkMimic(newOrg);
    playerBench.remove(benchTeamIndex);

    if (slotNumber == 1) {
      playerIdx1 = benchTeamIndex;
      playerSlot1 = newOrg;
    } else {
      playerIdx2 = benchTeamIndex;
      playerSlot2 = newOrg;
    }

    // Restore persistent stats
    final stats = battleStats.putIfAbsent(
      newOrg.organism.id,
      () => BattleStats(),
    );
    newOrg.isPrismorphed = stats.isPrismorphed;
    newOrg.hasPrismorphedThisBattle = stats.hasPrismorphedThisBattle;
    newOrg.activeTeraType = stats.activeTeraType;
    newOrg.revealedMoves.addAll(stats.revealedMoves);
    newOrg.isItemRevealed = stats.isItemRevealed;
    newOrg.isAbilityRevealed = stats.isAbilityRevealed;
    addLog('Go, ${newOrg.organism.baseOrganism.name}!');
    if (!isTesting) {
      _audio.playOrganismCry(newOrg.organism.baseOrganism.cry);
    }
    switchNeededSlot = null;
    notifyListeners();
    if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));

    await _triggerEntryAbilities();

    // Check if another switch is needed
    if (await _processReplacements()) {
      _isProcessing = false;
      return;
    }

    if (!_isBattleOver()) {
      _transitionToSelection();
    }
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // Battle end
  // ──────────────────────────────────────────────

  bool _isBattleOver() {
    final playerAlive =
        playerSlot1 != null || playerSlot2 != null || playerBench.isNotEmpty;
    final opponentAlive = opponentSlot1 != null ||
        opponentSlot2 != null ||
        opponentBench.isNotEmpty;
    return !playerAlive || !opponentAlive;
  }

  void _endBattle() {
    final playerAlive = playerSlot1 != null || playerSlot2 != null;
    result = playerAlive ? DoubleBattleResult.win : DoubleBattleResult.loss;
    currentState = DoubleBattleState.battleEnd;
    addLog(
      result == DoubleBattleResult.win
          ? 'You won the doubles battle!'
          : 'You lost the doubles battle...',
    );
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // Helpers
  // ──────────────────────────────────────────────

  BattleOrganism? _resolveTarget(DoubleTarget target) {
    return switch (target) {
      DoubleTarget.opponentSlot1 => opponentSlot1,
      DoubleTarget.opponentSlot2 => opponentSlot2,
      DoubleTarget.playerSlot1 => playerSlot1,
      DoubleTarget.playerSlot2 => playerSlot2,
      DoubleTarget.allOpponents => null, // handled externally
    };
  }

  List<BattleOrganism> _allActiveSlots() {
    return [
      playerSlot1,
      playerSlot2,
      opponentSlot1,
      opponentSlot2,
    ].whereType<BattleOrganism>().toList();
  }

  int _effectiveSpeed(BattleOrganism org) {
    double speed = org.currentSpeed.toDouble();

    // Custap Berry: Priority boost (simulated with large speed boost at low HP)
    if (org.organism.equippedTalisman != null && !org.talismanConsumed) {
      for (final effect in org.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.priorityLowHp &&
            org.health <= org.maxHealth * effect.threshold) {
          speed *= 100.0;
        }
      }
    }

    return speed.round();
  }

  String _slotName(BattleOrganism? slot) =>
      slot?.organism.baseOrganism.name ?? '---';

  void addLog(String msg) {
    battleLog = msg;
    if (turnHistory.isEmpty) turnHistory.add(BattleTurn(currentTurn));
    turnHistory.last.logEntries.add(msg);
  }

  int _getEffectiveSpeed(BattleOrganism org) {
    double speed = org.organism.baseOrganism.speed.toDouble();

    // Stage multiplier
    if (org.speedStage > 0) {
      speed *= (2 + org.speedStage) / 2;
    } else if (org.speedStage < 0) {
      speed *= 2 / (2 + org.speedStage.abs());
    }

    // Paralysis penalty
    if (org.statusEffect.type == StatusEffectType.paralysis) {
      speed *= 0.5;
    }

    // Ability multipliers
    speed *= org.getAbilityStatMultiplier('speed');

    return speed.round();
  }

  Weather _parseWeather(String value) {
    return Weather.values.firstWhere(
      (w) => w.toString().split('.').last.toLowerCase() == value.toLowerCase(),
      orElse: () => Weather.none,
    );
  }

  Terrain _parseTerrain(String value) {
    return Terrain.values.firstWhere(
      (t) => t.toString().split('.').last.toLowerCase() == value.toLowerCase(),
      orElse: () => Terrain.none,
    );
  }

  // =====================================================================
  // GIMMICK ACTIONS: Prismorph
  // =====================================================================

  void activatePrismorph({required bool isPlayer, required int slotIdx}) {
    if (isPlayer && playerPrismorphUsed) return;
    if (!isPlayer && opponentPrismorphUsed) return;

    BattleOrganism? org;
    if (isPlayer) {
      org = slotIdx == 1 ? playerSlot1 : playerSlot2;
    } else {
      org = slotIdx == 1 ? opponentSlot1 : opponentSlot2;
    }

    if (org == null || org.hasPrismorphedThisBattle) return;

    final teraType = org.organism.teraType;
    if (teraType == null) {
      addLog('${org.name} has no Tera type and cannot Prismorph!');
      notifyListeners();
      return;
    }

    if (isPlayer) {
      playerPrismorphUsed = true;
    } else {
      opponentPrismorphUsed = true;
    }

    org.isPrismorphed = true;
    org.activeTeraType = teraType;
    org.hasPrismorphedThisBattle = true;

    // Sync to persistent stats
    final stats = battleStats.putIfAbsent(org.organism.id, () => BattleStats());
    stats.isPrismorphed = true;
    stats.activeTeraType = teraType;
    stats.hasPrismorphedThisBattle = true;

    addLog(
      '${org.name} used Prismorph! It is shining with ${teraType.name} energy!',
    );
    pendingGimmickType = 'prismorph';
    pendingGimmickTarget = org;
    notifyListeners();
  }


  Future<void> _applyContactAbilities(
    BattleOrganism attacker,
    BattleOrganism defender,
    Move move,
  ) async {
    if (defender.isAbilitySuppressed) return;

    for (final ab in defender.abilities) {
      if (ab.trigger != AbilityTrigger.onContact) continue;

      switch (ab.name) {
        case 'Rough Skin':
        case 'Iron Barbs':
          final dmg = (attacker.maxHealth / 8).round();
          attacker.health = (attacker.health - dmg).clamp(0, attacker.maxHealth);
          addLog("${attacker.name} was hurt by ${defender.name}'s ${ab.name}!");
          break;
        case 'Static':
          if (Random().nextDouble() < 0.3) {
            await _applyStatus(attacker, const StatusEffect(type: StatusEffectType.paralysis));
          }
          break;
        case 'Flame Body':
          if (Random().nextDouble() < 0.3) {
            await _applyStatus(attacker, const StatusEffect(type: StatusEffectType.burn));
          }
          break;
        case 'Poison Point':
          if (Random().nextDouble() < 0.3) {
            await _applyStatus(attacker, const StatusEffect(type: StatusEffectType.poison));
          }
          break;
        case 'Gooey':
        case 'Tangling Hair':
          await _applyStatChange(attacker, 'speed', -1, source: defender);
          break;
      }
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));
    }
  }

  Future<void> _checkPostDamageItems(BattleOrganism org) async {
    if (org.health <= 0 || org.talismanConsumed || org.organism.equippedTalisman == null) return;

    final hpPercent = org.health / org.maxHealth;
    bool consumed = false;

    for (final effect in org.organism.equippedTalisman!.effects) {
      if (effect.type == TalismanEffectType.berryHealPercent && hpPercent <= 0.5) {
        final heal = (org.maxHealth * effect.magnitude).round();
        org.health = (org.health + heal).clamp(0, org.maxHealth);
        addLog("${org.name} ate its ${org.organism.equippedTalisman!.name} and restored HP!");
        consumed = true;
        break;
      } else if (effect.type == TalismanEffectType.berryStatBoost && hpPercent <= 0.25) {
        await _applyStatChange(org, effect.stat!, effect.magnitude.round());
        consumed = true;
        break;
      } else if (effect.type == TalismanEffectType.berryCureStatus && org.statusEffects.isNotEmpty) {
        org.clearStatusEffects();
        addLog("${org.name} ate its ${org.organism.equippedTalisman!.name} and cured its status!");
        consumed = true;
        break;
      }
    }

    if (consumed) {
      org.talismanConsumed = true;
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));
    }
  }
}

// ──────────────────────────────────────────────
// Internal helper for sorting actions
// ──────────────────────────────────────────────

class _ActionEntry {
  final BattleOrganism attacker;
  final SlotAction action;
  final int priority;
  final int speed;
  final bool isPlayer;
  final int slotIdx; // 1 or 2

  _ActionEntry({
    required this.attacker,
    required this.action,
    required this.priority,
    required this.speed,
    required this.isPlayer,
    required this.slotIdx,
  });
}
