// lib/game/battle_manager.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/ability.dart';

// --- Enums ---
enum BattleState {
  waitingForInput, // Player must select Move, Capture, or Run
  playerTurn,
  opponentTurn,
  applyingEffects,
  battleEnd,
}

enum BattleResult {
  win,
  loss,
  capture, // Successful capture
  fled,    // Successful run
}

// --- BattleOrganism: Holds state for battle ---
class BattleOrganism {
  final CapturedOrganism organism;
  final Ability? ability;
  int health;
  
  // Dynamic battle stats
  int attackStage = 0; // -6 to +6 stages
  int defenseStage = 0;
  String statusEffect = 'None'; // e.g., 'Poison', 'Sleep'

  BattleOrganism(this.organism)
      : health = organism.currentHealth.clamp(0, organism.maxHealth),
        ability = Ability.findByName(organism.baseOrganism.abilities);

  // Helper for stat stage multipliers (e.g., +1 stage is 1.5x)
  double _getStatStageMultiplier(int stage) {
    if (stage > 0) return (2 + stage) / 2;
    if (stage < 0) return 2 / (2 + stage.abs());
    return 1.0;
  }

  int get currentAttack {
    double attack = organism.effectiveAttack.toDouble();
    attack *= _getStatStageMultiplier(attackStage);
    if (ability?.effectType == AbilityEffectType.passiveStatBoost && ability?.targetStat == 'attack') {
      attack *= ability!.magnitude;
    }
    if (ability?.effectType == AbilityEffectType.onLowHP &&
        ability?.targetStat == 'attack' &&
        health / maxHealth <= 0.3) {
      attack *= ability!.magnitude;
    }
    return attack.round();
  }

  int get currentDefense =>
      (organism.effectiveDefense * _getStatStageMultiplier(defenseStage)).round();

  int get currentSpeed {
    double speed = organism.effectiveSpeed.toDouble();
    if (ability?.effectType == AbilityEffectType.passiveStatBoost && ability?.targetStat == 'speed') {
      speed *= ability!.magnitude;
    }
    return speed.round();
  }

  /// Use the captured organism's calculated max HP (IVs included), not base stat.
  int get maxHealth => organism.maxHealth;
}

// --- BattleManager: The Core State Machine ---
class BattleManager extends ChangeNotifier {
  final CapturedOrganism playerOrganism;
  final CapturedOrganism opponentOrganism;
  
  late BattleOrganism player;
  late BattleOrganism opponent;
  
  late List<Move> playerMoves;
  late List<Move> opponentMoves;

  BattleState currentState = BattleState.waitingForInput;
  String battleLog = '';
  final List<String> battleLogHistory = [];
  BattleResult? result;

  void _addToLog(String message) {
    battleLog = message;
    battleLogHistory.add(message);
  }

  void _appendToLog(String message) {
    battleLog += message;
    battleLogHistory.add(message.trim());
  }

  /// Builds the move list for an organism from its moveset string. Uses predefined
  /// moves when available; otherwise creates moves with random damage (placeholder).
  List<Move> _getOrganismMoves(CapturedOrganism organism) {
    final moveNames = organism.baseOrganism.moves
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    final rng = Random();
    final List<Move> moves = [];
    for (final name in moveNames) {
      moves.add(Move.findOrCreate(name, rng));
    }
    if (moves.isEmpty) {
      moves.add(Move.findOrCreate('Struggle', rng));
    }
    return moves;
  }

  BattleManager(this.playerOrganism, this.opponentOrganism) {
    player = BattleOrganism(playerOrganism);
    opponent = BattleOrganism(opponentOrganism);
    
    // Initialize move lists
    playerMoves = _getOrganismMoves(playerOrganism);
    opponentMoves = _getOrganismMoves(opponentOrganism);
    
    _addToLog('A wild ${opponent.organism.name} appeared! Go, ${player.organism.name}!'); 
    
    if (player.currentSpeed < opponent.currentSpeed) {
      _appendToLog('\n${opponent.organism.name} is faster and will attack first!');
    }
  }

  // --- Turn Logic ---

  Future<void> processPlayerAction(Move move) async {
    if (currentState != BattleState.waitingForInput) return;
    currentState = BattleState.playerTurn;
    notifyListeners();
    
    // 1. Process who moves first in this turn
    if (player.currentSpeed >= opponent.currentSpeed) {
      await _executeTurn(player, opponent, move);
      if (_checkBattleEnd()) return;
      
      await _processOpponentTurn(isCounter: true);
    } else {
      await _processOpponentTurn(isCounter: false);
      if (_checkBattleEnd()) return;

      await _executeTurn(player, opponent, move);
    }

    // 2. Apply Turn-End Effects (e.g., Poison damage)
    if (!_checkBattleEnd()) {
      await _applyTurnEffects(player);
      if (_checkBattleEnd()) return;
      await _applyTurnEffects(opponent);
    }
    
    // 3. Transition to next turn or end
    if (!_checkBattleEnd()) {
      currentState = BattleState.waitingForInput;
      _addToLog('What will ${player.organism.name} do?');
    }
    notifyListeners();
  }
  
  // Executes the move and applies effects
  Future<void> _executeTurn(BattleOrganism attacker, BattleOrganism defender, Move move) async {
    // 🚨 FIX: Reverting to baseOrganism
    _addToLog('${attacker.organism.baseOrganism.name} used ${move.name}!');
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 700));

    // 1. Accuracy Check
    if (Random().nextInt(100) >= move.accuracy) {
      _addToLog('...but it missed!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    // 2. Damage Calculation (Simplified Formula: (AttackerATK / DefenderDEF) * MovePower)
    if (move.baseDamage > 0) {
      final damage = ((attacker.currentAttack / defender.currentDefense) * move.baseDamage * (Random().nextDouble() * 0.2 + 0.9)).round(); // Random 90%-110% damage
      defender.health -= damage;
      defender.health = defender.health.clamp(0, defender.maxHealth); 
      
      // 🚨 FIX: Reverting to baseOrganism
      _addToLog('${defender.organism.baseOrganism.name} took $damage damage!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 700));
    }
    
    // 3. Effect Application
    await _applyMoveEffect(attacker, defender, move.effect);
  }

  Future<void> _processOpponentTurn({required bool isCounter}) async {
    if (!isCounter) {
        _addToLog('Opponent\'s turn!');
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 700));
    }
    
    // Simple AI: Select a random move from its specific list
    final opponentMove = opponentMoves[Random().nextInt(opponentMoves.length)];

    await _executeTurn(opponent, player, opponentMove);
  }

  // --- Core Effect Logic ---
  
  Future<void> _applyMoveEffect(BattleOrganism attacker, BattleOrganism defender, MoveEffect effect) async {
    if (effect.type == MoveEffectType.none) return;

    final target = effect.target == 'self' ? attacker : defender;
    
    switch (effect.type) {
      case MoveEffectType.statusPoison:
        if (target.statusEffect == 'None') {
          target.statusEffect = 'Poison';
          // 🚨 FIX: Reverting to baseOrganism
          _appendToLog('\n${target.organism.baseOrganism.name} is poisoned!');
        }
        break;
      case MoveEffectType.statChange:
        _applyStatChange(target, effect.stat, effect.value);
        // 🚨 FIX: Reverting to baseOrganism
        _appendToLog('\n${target.organism.baseOrganism.name}\'s ${effect.stat} stage ${effect.value > 0 ? 'increased' : 'decreased'}!');
        break;
      case MoveEffectType.heal:
        final healedAmount = effect.value;
        target.health += healedAmount;
        target.health = target.health.clamp(0, target.maxHealth);
        // 🚨 FIX: Reverting to baseOrganism
        _appendToLog('\n${target.organism.baseOrganism.name} recovered $healedAmount HP!');
        break;
      default:
        break;
    }
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _applyStatChange(BattleOrganism target, String stat, int value) {
    if (stat == 'attack') {
      target.attackStage = (target.attackStage + value).clamp(-6, 6);
    } else if (stat == 'defense') {
      target.defenseStage = (target.defenseStage + value).clamp(-6, 6);
    }
  }
  
  Future<void> _applyTurnEffects(BattleOrganism target) async {
    if (target.health <= 0) return; 
    
    if (target.statusEffect == 'Poison') {
      final poisonDamage = (target.maxHealth * 0.05).round().clamp(1, 9999); // Min 1 damage
      target.health -= poisonDamage;
      target.health = target.health.clamp(0, target.maxHealth);
      // 🚨 FIX: Reverting to baseOrganism
      _addToLog('Poison hurt ${target.organism.baseOrganism.name} for $poisonDamage!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 700));
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
      result = BattleResult.capture;
      // 🚨 FIX: Reverting to baseOrganism
      _addToLog('Success! ${opponent.organism.baseOrganism.name} was captured!');
    } else {
      result = null; 
      _addToLog('The capture failed! Opponent is still fighting.');
      currentState = BattleState.opponentTurn;
      await Future.delayed(const Duration(seconds: 1));
      await _processOpponentTurn(isCounter: false);
    }
    
    if (result == BattleResult.capture) {
      currentState = BattleState.battleEnd;
    } else if (currentState == BattleState.opponentTurn) {
      currentState = BattleState.waitingForInput;
    }
    notifyListeners();
  }
  
  Future<void> attemptRun() async {
    if (currentState != BattleState.waitingForInput) return;
    
    currentState = BattleState.applyingEffects;
    _addToLog('Attempting to run...');
    notifyListeners();
    await Future.delayed(const Duration(seconds: 1));

    final runChance = (player.currentSpeed / opponent.currentSpeed) * 0.75; 

    if (Random().nextDouble() < runChance.clamp(0.1, 1.0)) { 
      result = BattleResult.fled;
      _addToLog('You successfully ran away!');
      currentState = BattleState.battleEnd;
    } else {
      result = null; 
      _addToLog('Failed to run! Opponent\'s turn.');
      currentState = BattleState.opponentTurn;
      await Future.delayed(const Duration(seconds: 1));
      await _processOpponentTurn(isCounter: false);
      currentState = BattleState.waitingForInput;
    }
    
    notifyListeners();
  }

  // --- End Check ---
  
  bool _checkBattleEnd() {
    if (player.health <= 0) {
      result = BattleResult.loss;
      // 🚨 FIX: Reverting to baseOrganism
      _addToLog('Your ${player.organism.baseOrganism.name} fainted! You lost the battle.');
      currentState = BattleState.battleEnd;
      notifyListeners();
      return true;
    }
    if (opponent.health <= 0) {
      result = BattleResult.win;
      // 🚨 FIX: Reverting to baseOrganism
      _addToLog('The wild ${opponent.organism.baseOrganism.name} fainted! You won the battle.');
      currentState = BattleState.battleEnd;
      notifyListeners();
      return true;
    }
    return false;
  }
}