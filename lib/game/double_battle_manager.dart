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
import 'package:animal_warfare/models/talisman.dart';

// ──────────────────────────────────────────────
// Enums
// ──────────────────────────────────────────────

enum DoubleBattleState {
  intro, // Initialization animation / opening text
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

    turnHistory.add(BattleTurn(currentTurn));
    addLog('GO! ${_slotName(playerSlot1)} & ${_slotName(playerSlot2)}!');
    if (!isTesting) {
      if (playerSlot1 != null) {
        _audio.playOrganismCry(playerSlot1!.organism.baseOrganism.cry);
      }
      if (playerSlot2 != null) {
        _audio.playOrganismCry(playerSlot2!.organism.baseOrganism.cry);
      }
      if (opponentSlot1 != null) {
        _audio.playOrganismCry(opponentSlot1!.organism.baseOrganism.cry);
      }
      if (opponentSlot2 != null) {
        _audio.playOrganismCry(opponentSlot2!.organism.baseOrganism.cry);
      }
    }

    _startIntro();
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

  int _popBench(List<int> bench) {
    final idx = bench.first;
    bench.removeAt(0);
    return idx;
  }

  Future<void> _startIntro() async {
    if (!isTesting) {
      await _audio.playMusic('audio/battle_default.mp3');
      await Future.delayed(const Duration(milliseconds: 2500));
    }
    _transitionToSelection();
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
      if (playerSlot2 != null) {
        currentState = DoubleBattleState.selectingForSlot2;
        addLog('What will ${_slotName(playerSlot2)} do?');
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
      if (playerSlot2 != null) {
        currentState = DoubleBattleState.selectingForSlot2;
        addLog('What will ${_slotName(playerSlot2)} do?');
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

  List<SlotAction> _pickAiActions() {
    final actions = <SlotAction>[];

    // Context preparation
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

    for (int i = 0; i < 2; i++) {
      final aiSlot = i == 0 ? opponentSlot1 : opponentSlot2;
      if (aiSlot == null || aiSlot.health <= 0) continue;

      // --- Wild Animal Gimmick Adjustments ---
      final isWild = !isRogueMode && !isArenaBattle;

      if (isWild && currentTurn == 1 && !aiSlot.hasPrismorphedThisBattle) {
        final teraType = aiSlot.organism.teraType;
        final baseTypes = aiSlot.organism.baseOrganism.types
            .map(
              (t) => ElementalType.values.firstWhere(
                (e) =>
                    e.toString().split('.').last.toLowerCase() ==
                    t.toLowerCase(),
                orElse: () => ElementalType.basic,
              ),
            )
            .toList();

        if (teraType != null && !baseTypes.contains(teraType)) {
          // Force Prismorph on turn 1 for special tera types
          activatePrismorph(isPlayer: false, slotIdx: i == 0 ? 1 : 2);
        }
      }

      // AI GIMMICK TRIGGER: 60% HP
      if (aiSlot.health / aiSlot.maxHealth <= 0.6) {
        if (!opponentPrismorphUsed && !aiSlot.hasPrismorphedThisBattle) {
          activatePrismorph(isPlayer: false, slotIdx: i == 0 ? 1 : 2);
        }
      }

      // Re-fetch moves after potential gimmick activation
      final moves = getMovesFor(aiSlot);
      double bestScore = -double.infinity;
      SlotAction? bestAction;

      for (final move in moves) {
        final targets = _getPossibleTargetsForAi(move);
        for (final target in targets) {
          final defender = _resolveTarget(target);
          if (defender == null &&
              move.targetCount != MoveTargetCount.multiple) {
            continue;
          }

          // Evaluation target for multi-target moves (pick the most relevant one, typically slot 1 or 2)
          final evaluationDefender =
              defender ?? playerSlot1 ?? playerSlot2 ?? playerTeamBO[0];

          final damageResult = calculateDamage(
            aiSlot,
            evaluationDefender,
            move,
            multiTargetPenalty: move.targetCount == MoveTargetCount.multiple
                ? 0.75
                : 1.0,
          );

          final score = AIDecisionEngine.calculateMoveScore(
            move: move,
            attacker: aiSlot,
            defender: evaluationDefender,
            damageResult: damageResult,
            targetHazards: const [], // TODO: Implement hazards in Doubles
            currentEffect: const WeatherEffect(weather: Weather.none),
            currentTerrain: const TerrainEffect(terrain: Terrain.none),
            aiTeam: aiTeamBO,
            playerTeam: playerTeamBO,
            playerHistory: playerHistory,
            archetype: opponentArchetype,
          );

          if (score > bestScore) {
            bestScore = score;
            bestAction = SlotAction.move(move, target);
          }
        }
      }

      if (bestAction != null) {
        actions.add(bestAction);
      } else if (moves.isNotEmpty) {
        // Fallback to first move if no score found
        actions.add(SlotAction.move(moves[0], DoubleTarget.playerSlot1));
      }
    }
    return actions;
  }

  List<DoubleTarget> _getPossibleTargetsForAi(Move move) {
    if (move.targetCount == MoveTargetCount.multiple) {
      return [DoubleTarget.allOpponents];
    }
    final alive = <DoubleTarget>[];
    if (playerSlot1 != null && playerSlot1!.health > 0) {
      alive.add(DoubleTarget.playerSlot1);
    }
    if (playerSlot2 != null && playerSlot2!.health > 0) {
      alive.add(DoubleTarget.playerSlot2);
    }
    return alive.isNotEmpty ? alive : [DoubleTarget.playerSlot1];
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

    return moveType;
  }

  ElementalType _getTypeFromItemName(String name) {
    return ElementalTypeX.fromString(name);
  }

  DamageResult calculateDamage(
    BattleOrganism attacker,
    BattleOrganism defender,
    Move move, {
    double multiTargetPenalty = 1.0,
  }) {
    if (move.baseDamage == 0) return const DamageResult(0, 1.0, false);

    double atkStat = move.category == MoveCategory.special
        ? attacker.currentPower.toDouble()
        : attacker.currentAttack.toDouble();
    double defStat = move.category == MoveCategory.special
        ? defender.currentResistance.toDouble()
        : defender.currentDefense.toDouble();

    // --- Flower Gift ---
    // (Awaiting weather implementation in DoubleBattleManager)

    // --- Toxic Boost / Flare Boost ---
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

    // --- Defeatist ---
    if (attacker.abilities.any((ab) => ab.name == 'Defeatist') &&
        attacker.health <= attacker.maxHealth / 3) {
      atkStat /= 2.0;
    }

    double dmg =
        ((2 * attacker.level / 5 + 2) * move.baseDamage * atkStat / defStat) /
            50 +
        2;

    // Use dynamic move type
    final moveType = getDisplayType(attacker, move);

    // --- Type-changing power boost ---
    bool typeChangedByAbility = false;
    if (move.type == ElementalType.basic &&
        (attacker.abilities.any((ab) => ab.name == 'Aerilate') ||
            attacker.abilities.any((ab) => ab.name == 'Pixilate') ||
            attacker.abilities.any((ab) => ab.name == 'Refrigerate') ||
            attacker.abilities.any((ab) => ab.name == 'Galvanize'))) {
      typeChangedByAbility = true;
    } else if (move.type == ElementalType.sound &&
        attacker.abilities.any((ab) => ab.name == 'Liquid Voice')) {
      typeChangedByAbility = true;
    }

    if (typeChangedByAbility) {
      dmg *= 1.2;
    }

    // Type effectiveness
    double typeMod = 1.0;
    for (final defType in defender.types) {
      double mod = TypeChart.getEffectiveness(moveType, defType);

      // Scrappy: Normal/Fighting moves hit Ghost types
      if (mod == 0.0 &&
          defType == ElementalType.spectral &&
          (moveType == ElementalType.basic ||
              moveType == ElementalType.martial) &&
          attacker.abilities.any((ab) => ab.name == 'Scrappy')) {
        mod = 1.0;
      }
      typeMod *= mod;
    }

    // Solid Rock / Filter
    if (typeMod > 1.0 &&
        defender.abilities.any(
          (ab) => ab.name == 'Solid Rock' || ab.name == 'Filter',
        )) {
      typeMod *= 0.75;
    }

    dmg *= typeMod;

    // Gem Boost
    if (attacker.organism.equippedTalisman != null &&
        !attacker.talismanConsumed) {
      for (final effect in attacker.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.gemBoost &&
            effect.stat == moveType.toString().split('.').last.toLowerCase()) {
          dmg *= effect.magnitude;
        }
      }
    }

    // Expert Belt
    if (typeMod > 1.0 &&
        attacker.organism.equippedTalisman != null &&
        !attacker.talismanConsumed) {
      for (final effect in attacker.organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.damageBoost &&
            effect.condition == 'super_effective') {
          dmg *= effect.magnitude;
        }
      }
    }

    // STAB
    if (attacker.types.contains(moveType)) dmg *= 1.5;

    // Multi-target penalty
    dmg *= multiTargetPenalty;

    // Sheer Force: Remove secondary effects but boost damage
    if (attacker.abilities.any((ab) => ab.name == 'Sheer Force') &&
        move.effects.isNotEmpty) {
      dmg *= 1.3;
    }

    // Multiscale
    if (defender.abilities.any((ab) => ab.name == 'Multiscale') &&
        defender.health == defender.maxHealth) {
      dmg *= 0.5;
    }

    // Big Pecks
    if (attacker.abilities.any((ab) => ab.name == 'Big Pecks') &&
        move.isContact) {
      dmg *= 1.3;
    }

    // Analytic
    if (attacker.abilities.any((ab) => ab.name == 'Analytic') &&
        defender.hasMovedThisTurn) {
      dmg *= 1.3;
    }

    // Illusion
    if (attacker.abilities.any((ab) => ab.name == 'Illusion') &&
        attacker.isDisguised) {
      dmg *= 1.3;
    }

    // Sand Force (Awaiting weather implementation in DoubleBattleManager)

    return DamageResult(dmg.round().clamp(1, 99999), typeMod, false);
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
      if (b.speed != a.speed) return b.speed - a.speed;
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

    attacker.organism.moveStamina[move.name] =
        ((attacker.organism.moveStamina[move.name] ?? move.stamina) - 1).clamp(
          0,
          move.stamina,
        );

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

    addLog('${attacker.organism.baseOrganism.name} used ${move.name}!');

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
        if (!isTesting) await Future.delayed(const Duration(milliseconds: 1500));
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
          targetOrg = opposingSlots.firstWhere((s) => s != null && s.health > 0, orElse: () => null);
        }

        if (targetOrg == null || damage <= 0) {
          addLog("${attacker.name} unleashed its energy... but it failed!");
        } else {
          addLog("${attacker.name} unleashed its energy!");
          targetOrg.health = (targetOrg.health - damage).clamp(0, targetOrg.maxHealth);
          if (onDamage != null) onDamage!(targetOrg, damage);
        }
        notifyListeners();
        if (!isTesting) await Future.delayed(const Duration(milliseconds: 1500));
        return;
      }
    }

    if (move.targetCount == MoveTargetCount.multiple) {
      // Hit all alive opponents of the attacker
      final opposingSlots = entry.isPlayer
          ? [opponentSlot1, opponentSlot2]
          : [playerSlot1, playerSlot2];
      bool hitAtLeastOne = false;
      for (final defender in opposingSlots) {
        if (defender == null || defender.health <= 0) continue;
        hitAtLeastOne = true;
        await _applyMoveToTarget(
          attacker: attacker,
          move: move,
          defender: defender,
          multiTargetPenalty: 0.75,
        );
      }
      if (!hitAtLeastOne) {
        addLog('But there was no target!');
      }
    } else {
      // Single target
      BattleOrganism? defender = _resolveTarget(target);
      
      // --- Redirection Check ---
      final opposingSlots = entry.isPlayer
          ? [opponentSlot1, opponentSlot2]
          : [playerSlot1, playerSlot2];
      for (final slot in opposingSlots) {
        if (slot != null && slot.health > 0 && slot.isFollowMeTarget) {
          defender = slot;
          break;
        }
      }

      if (defender == null || defender.health <= 0) {
        addLog('But the target is gone!');
        return;
      }
      await _applyMoveToTarget(
        attacker: attacker,
        move: move,
        defender: defender,
        multiTargetPenalty: 1.0,
      );
    }
    attacker.hasMovedThisTurn = true;
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
    // Accuracy check
    int accuracy = move.accuracy;
    if (defender.organism.equippedTalisman != null &&
        !defender.talismanConsumed) {
      for (final effect in defender.organism.equippedTalisman!.effects) {
        if (effect.stat == 'evasion') {
          accuracy = (accuracy * (1.0 / effect.magnitude)).round();
        }
      }
    }

    if (Random().nextInt(100) >= accuracy) {
      addLog('...but it missed!');

      // Blunder Policy: Speed boost on miss
      if (attacker.organism.equippedTalisman != null &&
          !attacker.talismanConsumed) {
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
      await _applyEffects(attacker, defender, move);
      notifyListeners();
      return;
    }

    // Storm Drain
    if (defender.abilities.any((ab) => ab.name == 'Storm Drain') &&
        move.type == ElementalType.aquatic) {
      addLog('${defender.name}\'s Storm Drain absorbed the attack!');
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
    double dmg = damageResult.damage.toDouble();
    double typeMod = damageResult.typeMultiplier;

    // Crit
    final critRoll = Random().nextDouble() * 100;
    final critThreshold = switch (move.critRate) {
      0 => 6.25,
      1 => 12.5,
      2 => 50.0,
      _ => 100.0,
    };
    if (critRoll < critThreshold) {
      dmg *= 1.5;
      addLog('A critical hit!');
    }

    // Random variance [0.85–1.0]
    dmg *= 0.85 + (Random().nextDouble() * 0.15);

    // Apply damage (Only once!)
    int finalDmg = dmg.round().clamp(1, 99999);

    // Endure
    if (defender.isEnduring && finalDmg >= defender.health) {
      finalDmg = defender.health - 1;
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
      if (defender.grudgeActive && attacker.health > 0 && attacker.organism.moveStamina.containsKey(move.name)) {
        attacker.organism.moveStamina[move.name] = 0;
        addLog("${attacker.name}'s ${move.name} lost all its stamina due to the Grudge!");
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
        finalDmg > 0 &&
        move.isContact) {
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

    // Drain
    if (move.drainPercent > 0) {
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
    if (move.recoilPercent > 0) {
      final recoil = (finalDmg * move.recoilPercent).round();
      attacker.health = (attacker.health - recoil).clamp(0, attacker.maxHealth);
      addLog('${attacker.organism.baseOrganism.name} was hurt by recoil!');
    }

    // Apply secondary effects
    if (attacker.abilities.any((ab) => ab.name == 'Sheer Force') &&
        move.effects.isNotEmpty) {
      addLog('${attacker.name}\'s Sheer Force prevented secondary effects!');
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
        _applyStatus(
          attacker,
          const StatusEffect(type: StatusEffectType.confusion),
        );
        attacker.thrashMove = null;
        attacker.thrashTurnCount = 0;
      }
    }

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
          _applyStatChange(effectTarget, effect.stat, effect.value);
          break;
        case MoveEffectType.multiStatChange:
          final stats = effect.stat.split(',');
          final vals = effect.value.toString().split(',');
          for (int i = 0; i < stats.length && i < vals.length; i++) {
            _applyStatChange(
              effectTarget,
              stats[i].trim(),
              int.tryParse(vals[i].trim()) ?? 0,
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
          _applyStatus(
            effectTarget,
            const StatusEffect(type: StatusEffectType.poison),
          );
          break;
        case MoveEffectType.statusBurn:
          _applyStatus(
            effectTarget,
            const StatusEffect(type: StatusEffectType.burn),
          );
          break;
        case MoveEffectType.statusSleep:
          _applyStatus(
            effectTarget,
            const StatusEffect(type: StatusEffectType.sleep),
          );
          break;
        case MoveEffectType.statusParalysis:
          _applyStatus(
            effectTarget,
            const StatusEffect(type: StatusEffectType.paralysis),
          );
          break;
        case MoveEffectType.statusFreeze:
          _applyStatus(
            effectTarget,
            const StatusEffect(type: StatusEffectType.freeze),
          );
          break;
        case MoveEffectType.statusBleed:
          _applyStatus(
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
          attacker.health = (attacker.health + heal).clamp(0, attacker.maxHealth);
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
        default:
          break;
      }
    }
    notifyListeners();
  }

  Future<void> _applyStatChange(
    BattleOrganism org,
    String stat,
    int stages,
  ) async {
    // --- Contrary ---
    if (org.abilities.any((ab) => ab.name == 'Contrary')) {
      stages = -stages;
    }

    switch (stat.toLowerCase()) {
      case 'attack':
        org.attackStage = (org.attackStage + stages).clamp(-6, 6);
        break;
      case 'defense':
        org.defenseStage = (org.defenseStage + stages).clamp(-6, 6);
        break;
      case 'power':
        org.powerStage = (org.powerStage + stages).clamp(-6, 6);
        break;
      case 'resistance':
        org.resistanceStage = (org.resistanceStage + stages).clamp(-6, 6);
        break;
      case 'speed':
        org.speedStage = (org.speedStage + stages).clamp(-6, 6);
        break;
      case 'accuracy':
        org.accuracyStage = (org.accuracyStage + stages).clamp(-6, 6);
        break;
    }
    final dir = stages > 0 ? 'rose' : 'fell';
    addLog("${org.organism.baseOrganism.name}'s $stat $dir!");

    // --- Defiant ---
    if (stages < 0 && org.abilities.any((ab) => ab.name == 'Defiant')) {
      addLog("${org.organism.baseOrganism.name}'s Defiant triggered!");
      await _applyStatChange(org, 'attack', 2);
    }
    if (stages < 0 && org.abilities.any((ab) => ab.name == 'Rattled')) {
      addLog("${org.organism.baseOrganism.name}'s Rattled triggered!");
      await _applyStatChange(org, 'speed', 1);
    }

    notifyListeners();
  }

  void _applyStatus(BattleOrganism org, StatusEffect se) {
    if (org.statusEffects.any((e) => e.type == se.type)) return;
    org.addStatusEffect(se);
    addLog('${org.organism.baseOrganism.name} is now ${se.name}!');
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // End-of-turn effects
  // ──────────────────────────────────────────────

  Future<void> _applyEndOfTurnEffects() async {
    for (final slot in _allActiveSlots()) {
      if (slot.health <= 0) continue;

      // Ice Body
      if (slot.abilities.any((ab) => ab.name == 'Ice Body')) {
        // Double Battle Manager currently lacks full weather support (like currentWeatherGlobal)
        // so we can't implement Ice Body faithfully without weather state.
        // We will leave this placeholder.
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
          final damageAmount = (slot.maxHealth / 4).floor().clamp(
            1,
            slot.maxHealth,
          );
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
      slot.isElectrified = false;

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
        // Search for a source that is still on the field
        final source = _allActiveSlots().firstWhere(
          (s) =>
              s != slot &&
              s.organism.equippedTalisman != null &&
              !s.talismanConsumed &&
              s.organism.equippedTalisman!.effects.any(
                (e) => e.type == TalismanEffectType.bindingBandBoost,
              ),
          orElse: () => slot, // dummy
        );

        if (source != slot) {
          trapMult = 1.5;
          source.isItemRevealed = true;
        }

        final damage = (slot.maxHealth * 0.125 * trapMult).round().clamp(
          1,
          99999,
        );
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
            break; // Stop at first heal effect
          } else if (effect.type == TalismanEffectType.berryCureStatus &&
              slot.statusEffects.isNotEmpty) {
            final statusToCure = effect.stat; // e.g., 'burn', 'all'
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
      if (opponentLightScreenTurns == 0) addLog('Foe\'s Light Screen wore off!');
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

    // Check if another switch is needed
    if (await _processReplacements()) {
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
    final playerAlive = playerSlot1 != null || playerSlot2 != null;
    final opponentAlive = opponentSlot1 != null || opponentSlot2 != null;
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
