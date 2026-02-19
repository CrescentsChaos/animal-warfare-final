// lib/game/double_battle_manager.dart
//
// Manages the state for a 2v2 "Doubles" battle format.
// Both sides have two active slots and up to 4 animals on bench.
// Turn structure: select actions for both player slots → AI picks → speed-order execution.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/services/audio_service.dart';

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
  final bool isTesting;
  final AudioService _audio = AudioService.instance;
  bool _disposed = false;

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

  DoubleBattleManager({
    required List<CapturedOrganism> playerTeam,
    required List<CapturedOrganism> opponentTeam,
    this.isRogueMode = false,
    this.isTesting = false,
  }) : playerTeam = List.from(playerTeam),
       opponentTeam = List.from(opponentTeam) {
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
    _addLog('GO! ${_slotName(playerSlot1)} & ${_slotName(playerSlot2)}!');

    _startIntro();
  }

  void _fillSlotsFromBench() {
    if (playerBench.isNotEmpty) {
      playerIdx1 = _popBench(playerBench);
      playerSlot1 = BattleOrganism(
        playerTeam[playerIdx1],
        isRogueMode: isRogueMode,
      );
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
      _addLog(
        'What will ${_slotName(playerSlot1)} & ${_slotName(playerSlot2)} do?',
      );
    } else if (playerSlot2 != null) {
      currentState = DoubleBattleState.selectingForSlot2;
      _addLog('What will ${_slotName(playerSlot2)} do?');
    }
    notifyListeners();
  }

  Future<void> submitAction(Move move, DoubleTarget target) async {
    final action = SlotAction.move(move, target);
    if (currentState == DoubleBattleState.selectingForSlot1) {
      pendingAction1 = action;
      if (playerSlot2 != null) {
        currentState = DoubleBattleState.selectingForSlot2;
        _addLog('What will ${_slotName(playerSlot2)} do?');
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
    final action = SlotAction.switchMon(benchIndex);
    if (currentState == DoubleBattleState.selectingForSlot1) {
      pendingAction1 = action;
      if (playerSlot2 != null) {
        currentState = DoubleBattleState.selectingForSlot2;
        _addLog('What will ${_slotName(playerSlot2)} do?');
        notifyListeners();
      } else {
        await _executeAllActions();
      }
    } else if (currentState == DoubleBattleState.selectingForSlot2) {
      pendingAction2 = action;
      await _executeAllActions();
    }
  }

  List<SlotAction> _pickAiActions() {
    final rng = Random();
    final actions = <SlotAction>[];

    for (final aiSlot in [opponentSlot1, opponentSlot2]) {
      if (aiSlot == null) continue;
      final moves = _getMovesFor(aiSlot);
      final move = moves[rng.nextInt(moves.length)];
      final target = _randomValidTargetForAi(move);
      actions.add(SlotAction.move(move, target));
    }
    return actions;
  }

  DoubleTarget _randomValidTargetForAi(Move move) {
    if (move.targetCount == MoveTargetCount.multiple) {
      return DoubleTarget.allOpponents;
    }
    final alive = <DoubleTarget>[];
    if (playerSlot1 != null) alive.add(DoubleTarget.playerSlot1);
    if (playerSlot2 != null) alive.add(DoubleTarget.playerSlot2);
    if (alive.isEmpty) return DoubleTarget.playerSlot1;
    return alive[Random().nextInt(alive.length)];
  }

  List<Move> _getMovesFor(BattleOrganism org) {
    if (org.organism.selectedMoveNames.isEmpty) {
      org.organism.initializeDefaultMoves();
    }
    final moves = org.organism.selectedMoveNames
        .map((n) => Move.findOrCreate(n))
        .toList();
    if (moves.isEmpty) moves.add(Move.findOrCreate('Struggle'));
    return moves;
  }

  Future<void> _executeAllActions() async {
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
          entry.action.type != SlotActionType.switchMon)
        continue;

      await _executeAction(entry);
      await _processFaints();
    }

    await _applyEndOfTurnEffects();
    await _processFaints();

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
  }

  Future<void> _executeAction(_ActionEntry entry) async {
    final attacker = entry.attacker;

    if (entry.action.type == SlotActionType.switchMon) {
      final benchIdx = entry.action.switchBenchIndex!;
      final newOrg = BattleOrganism(playerTeam[benchIdx]);
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

      _addLog('Come back, ${attacker.organism.baseOrganism.name}!');
      _addLog('Go, ${newOrg.organism.baseOrganism.name}!');
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));
      return;
    }

    final move = entry.action.move!;
    final target = entry.action.target!;

    attacker.organism.moveStamina[move.name] =
        ((attacker.organism.moveStamina[move.name] ?? move.stamina) - 1).clamp(
          0,
          move.stamina,
        );

    _addLog('${attacker.organism.baseOrganism.name} used ${move.name}!');

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
        _addLog('But there was no target!');
      }
    } else {
      // Single target
      final defender = _resolveTarget(target);
      if (defender == null || defender.health <= 0) {
        _addLog('But the target is gone!');
        return;
      }
      await _applyMoveToTarget(
        attacker: attacker,
        move: move,
        defender: defender,
        multiTargetPenalty: 1.0,
      );
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
    // Accuracy check
    if (Random().nextInt(100) >= move.accuracy) {
      _addLog('...but it missed!');
      notifyListeners();
      return;
    }

    // Status-only moves: apply effects and return
    if (move.baseDamage == 0) {
      await _applyEffects(attacker, defender, move);
      notifyListeners();
      return;
    }

    // ── Damage calculation ──
    final atkStat = move.category == MoveCategory.special
        ? attacker.currentPower
        : attacker.currentAttack;
    final defStat = move.category == MoveCategory.special
        ? defender.currentResistance
        : defender.currentDefense;

    double dmg =
        ((2 * attacker.level / 5 + 2) * move.baseDamage * atkStat / defStat) /
            50 +
        2;

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
      _addLog('A critical hit!');
    }

    // Random variance [0.85–1.0]
    dmg *= 0.85 + (Random().nextDouble() * 0.15);

    // Type effectiveness
    double typeMod = 1.0;
    for (final defType in defender.types) {
      typeMod *= TypeChart.getEffectiveness(move.type, defType);
    }
    dmg *= typeMod;

    // STAB
    if (attacker.types.contains(move.type)) dmg *= 1.5;

    // Multi-target penalty (0.75× in doubles)
    dmg *= multiTargetPenalty;

    // Apply damage
    final finalDmg = dmg.round().clamp(1, 99999);
    defender.health = (defender.health - finalDmg).clamp(0, defender.maxHealth);
    defender.tookDamageThisTurn = true;

    if (typeMod > 1.0) _addLog('It\'s super effective!');
    if (typeMod < 1.0 && typeMod > 0) _addLog('It\'s not very effective...');
    if (typeMod == 0.0)
      _addLog('It doesn\'t affect ${defender.organism.baseOrganism.name}!');

    // Drain
    if (move.drainPercent > 0) {
      final heal = (finalDmg * move.drainPercent).round();
      attacker.health = (attacker.health + heal).clamp(0, attacker.maxHealth);
      _addLog('${attacker.organism.baseOrganism.name} absorbed energy!');
    }

    // Recoil
    if (move.recoilPercent > 0) {
      final recoil = (finalDmg * move.recoilPercent).round();
      attacker.health = (attacker.health - recoil).clamp(0, attacker.maxHealth);
      _addLog('${attacker.organism.baseOrganism.name} was hurt by recoil!');
    }

    // Apply secondary effects
    await _applyEffects(attacker, defender, move);

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
          _addLog('${effectTarget.organism.baseOrganism.name} restored HP!');
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
        default:
          break;
      }
    }
    notifyListeners();
  }

  void _applyStatChange(BattleOrganism org, String stat, int stages) {
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
    _addLog("${org.organism.baseOrganism.name}'s $stat $dir!");
    notifyListeners();
  }

  void _applyStatus(BattleOrganism org, StatusEffect se) {
    if (org.statusEffects.any((e) => e.type == se.type)) return;
    org.addStatusEffect(se);
    _addLog('${org.organism.baseOrganism.name} is now ${se.name}!');
    notifyListeners();
  }

  // ──────────────────────────────────────────────
  // End-of-turn effects
  // ──────────────────────────────────────────────

  Future<void> _applyEndOfTurnEffects() async {
    for (final slot in _allActiveSlots()) {
      for (final se in List<StatusEffect>.from(slot.statusEffects)) {
        switch (se.type) {
          case StatusEffectType.poison:
            final dmg = (slot.maxHealth * 0.0625).round().clamp(1, 99999);
            slot.health = (slot.health - dmg).clamp(0, slot.maxHealth);
            _addLog('${slot.organism.baseOrganism.name} was hurt by poison!');
            break;
          case StatusEffectType.burn:
            final dmg = (slot.maxHealth * 0.0625).round().clamp(1, 99999);
            slot.health = (slot.health - dmg).clamp(0, slot.maxHealth);
            _addLog('${slot.organism.baseOrganism.name} was hurt by burn!');
            break;
          case StatusEffectType.bleed:
            final dmg = (slot.maxHealth * 0.05).round().clamp(1, 99999);
            slot.health = (slot.health - dmg).clamp(0, slot.maxHealth);
            _addLog('${slot.organism.baseOrganism.name} is bleeding!');
            break;
          default:
            break;
        }
      }
      // Reset per-turn flags
      slot.tookDamageThisTurn = false;
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
        _addLog('${bo.organism.baseOrganism.name} fainted!');
        clear();
        anyNewFaints = true;
        notifyListeners();
        if (!isTesting)
          await Future.delayed(const Duration(milliseconds: 1000));
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
      _addLog(
        'Opponent sent out ${opponentSlot1!.organism.baseOrganism.name}!',
      );
      notifyListeners();
      if (!isTesting) await Future.delayed(const Duration(milliseconds: 1000));
    }
    if (opponentSlot2 == null && opponentBench.isNotEmpty) {
      final nextIdx = _popBench(opponentBench);
      opponentIdx2 = nextIdx;
      opponentSlot2 = BattleOrganism(opponentTeam[nextIdx]);
      _addLog(
        'Opponent sent out ${opponentSlot2!.organism.baseOrganism.name}!',
      );
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
    final bo = BattleOrganism(playerTeam[benchTeamIndex]);
    playerBench.remove(benchTeamIndex);

    if (slotNumber == 1) {
      playerIdx1 = benchTeamIndex;
      playerSlot1 = bo;
    } else {
      playerIdx2 = benchTeamIndex;
      playerSlot2 = bo;
    }
    _addLog('Go, ${bo.organism.baseOrganism.name}!');
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
    _addLog(
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

  int _effectiveSpeed(BattleOrganism org) => org.currentSpeed;

  String _slotName(BattleOrganism? slot) =>
      slot?.organism.baseOrganism.name ?? '---';

  void _addLog(String msg) {
    battleLog = msg;
    if (turnHistory.isEmpty) turnHistory.add(BattleTurn(currentTurn));
    turnHistory.last.logEntries.add(msg);
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
