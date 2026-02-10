// lib/game/battle_manager.dart
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/move.dart';

import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/elemental_type.dart';

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

  StatusEffect statusEffect = const StatusEffect(type: StatusEffectType.none); // Strong typing

  BattleOrganism(this.organism)
      : health = organism.currentHealth.clamp(0, organism.maxHealth),
        ability = Ability.findByName(organism.baseOrganism.abilities);

  List<ElementalType> get types => organism.baseOrganism.elementalTypes;

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

    // Burn halves attack
    if (statusEffect.type == StatusEffectType.burn) {
      attack *= 0.5;
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

    // Paralysis quarters speed
    if (statusEffect.type == StatusEffectType.paralysis) {
      speed *= 0.25;
    }
    return speed.round();
  }

  /// Use the captured organism's calculated max HP (IVs included), not base stat.
  /// Use the captured organism's calculated max HP (IVs included), not base stat.
  int get maxHealth => organism.maxHealth;
}

// --- Battle Turn Data ---
class BattleTurn {
  final int turnNumber;
  final List<String> logEntries = [];

  BattleTurn(this.turnNumber);
}

// --- BattleManager: The Core State Machine ---
class BattleManager extends ChangeNotifier {
  final CapturedOrganism playerOrganism;
  final CapturedOrganism opponentOrganism;
  
  late BattleOrganism player;
  late BattleOrganism opponent;
  
  late List<Move> playerMoves;
  late List<Move> opponentMoves;

  // New Battle State
  WeatherEffect currentWeather = const WeatherEffect(weather: Weather.none);
  TerrainEffect currentTerrain = const TerrainEffect(terrain: Terrain.none);
  int weatherTurnsLeft = 0;
  int terrainTurnsLeft = 0;

  BattleState currentState = BattleState.waitingForInput;
  String battleLog = ''; // Current/Latest message
  
  // LOGGING REFACTOR
  int currentTurn = 1;
  final List<BattleTurn> turnHistory = [];
  BattleResult? result;

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
       // Let's keep it simple and add as a new entry to the current turn history
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
    
    // Initialize first turn
    turnHistory.add(BattleTurn(currentTurn));

    _addToLog('A wild ${opponent.organism.name} appeared! Go, ${player.organism.name}!'); 
    
    _initializeBattle();
  }
  
  void _initializeBattle() {
    // 1. Check for Auto-Weather/Terrain/Intimidate
    _checkEntranceAbility(player, opponent);
    _checkEntranceAbility(opponent, player);
    
    // 2. Speed Check
    if (player.currentSpeed < opponent.currentSpeed) {
      _appendToLog('\n${opponent.organism.name} is faster and will attack first!');
    }
  }

  void _checkEntranceAbility(BattleOrganism user, BattleOrganism target) {
    if (user.ability == null) return;
    
    switch (user.ability!.effectType) {
      case AbilityEffectType.weatherChange:
        if (user.ability!.targetStat == 'rain') _setWeather(Weather.rain);
        else if (user.ability!.targetStat == 'sun') _setWeather(Weather.harshSun);
        else if (user.ability!.targetStat == 'hail') _setWeather(Weather.hail);
        else if (user.ability!.targetStat == 'sandstorm') _setWeather(Weather.sandstorm);
        break;
      case AbilityEffectType.terrainChange:
         if (user.ability!.targetStat == 'electric') _setTerrain(Terrain.electric);
         else if (user.ability!.targetStat == 'grassy') _setTerrain(Terrain.grassy);
         else if (user.ability!.targetStat == 'misty') _setTerrain(Terrain.misty);
         else if (user.ability!.targetStat == 'psychic') _setTerrain(Terrain.psychic);
         break;
      case AbilityEffectType.onBattleStart:
        if (user.ability!.targetStat == 'attack') {
          // Intimidate logic
          _applyStatChange(target, 'attack', user.ability!.magnitude.toInt());
          _appendToLog('\n${user.organism.baseOrganism.name}\'s ${user.ability!.name} cut ${target.organism.baseOrganism.name}\'s Attack!');
        }
        break;
      default:
        break;
    }
  }

  void _setWeather(Weather w, [int duration = 5]) {
    if (currentWeather.weather == w) return;
    currentWeather = WeatherEffect(weather: w, duration: duration);
    weatherTurnsLeft = duration;
    _appendToLog('\n${currentWeather.description}');
  }

  void _setTerrain(Terrain t, [int duration = 5]) {
    if (currentTerrain.terrain == t) return;
    currentTerrain = TerrainEffect(terrain: t, duration: duration);
    terrainTurnsLeft = duration;
    _appendToLog('\n${currentTerrain.description}');
  }

  // --- Turn Logic ---

  Future<void> processPlayerAction(Move move) async {
    if (currentState != BattleState.waitingForInput) return;
    currentState = BattleState.playerTurn;
    notifyListeners();
    
    // Pre-calculate opponent move for priority check
    final opponentMove = opponentMoves[Random().nextInt(opponentMoves.length)];
    
    // 1. Process who moves first in this turn (Check Priority first, then Speed)
    bool playerGoesFirst = false;
    
    // Priority Check
    if (move.priority > opponentMove.priority) {
      playerGoesFirst = true;
    } else if (opponentMove.priority > move.priority) {
      playerGoesFirst = false;
    } else {
      // Speed Check (same priority)
      if (player.currentSpeed >= opponent.currentSpeed) {
        playerGoesFirst = true;
      }
    }

    if (playerGoesFirst) {
      if (await _canMove(player)) {
        await _executeTurn(player, opponent, move);
      }
      if (_checkBattleEnd()) return;
      
      // Calculate Opponent Move (Need to select it earlier for priority check)
      // Done above in logic preparation
      if (await _canMove(opponent)) {
         await _executeTurn(opponent, player, opponentMove);
      }
    } else {
      if (await _canMove(opponent)) {
         await _executeTurn(opponent, player, opponentMove);
      }
      if (_checkBattleEnd()) return;

      if (await _canMove(player)) {
        await _executeTurn(player, opponent, move);
      }
    }

    // 2. Apply Turn-End Effects (e.g., Poison damage, Weather)
    if (!_checkBattleEnd()) {
      await _applyGlobalTurnEffects();
      if (_checkBattleEnd()) return;
      
      await _applyTurnEffects(player);
      if (_checkBattleEnd()) return;
      
      await _applyTurnEffects(opponent);
    }
    
    // 3. Transition to next turn or end
    if (!_checkBattleEnd()) {
      // End of this turn's cycle. Prepare for next turn.
      currentTurn++;
      turnHistory.add(BattleTurn(currentTurn));
      
      currentState = BattleState.waitingForInput;
      _addToLog('What will ${player.organism.name} do?');
    }
    notifyListeners();
  }
  
  // Executes the move and applies effects
  Future<void> _executeTurn(BattleOrganism attacker, BattleOrganism defender, Move move) async {
    _addToLog('${attacker.organism.baseOrganism.name} used ${move.name}!');
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 700));

    // 1. Accuracy Check (Blindness affects accuracy)
    int accuracy = move.accuracy;
    if (attacker.statusEffect.type == StatusEffectType.blind) {
      accuracy = (accuracy * 0.75).round(); // Reduce accuracy by 25% if blinded
    }

    if (Random().nextInt(100) >= accuracy) {
      _addToLog('...but it missed!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    // Multi-Hit Loop
    int hits = 1;
    if (move.maxHits > 1) {
      hits = move.minHits + Random().nextInt(move.maxHits - move.minHits + 1);
    }

    int totalDamageDealt = 0;

    for (int i = 0; i < hits; i++) {
        if (defender.health <= 0) break; // Stop if opponent fainted

        // 2. Damage Calculation (Simplified Formula: (AttackerATK / DefenderDEF) * MovePower)
        if (move.baseDamage > 0) {
          // Weather Modifiers
          double weatherMod = 1.0;
          if (currentWeather.weather == Weather.rain) {
             // If move is Water -> 1.5, Fire -> 0.5
          } else if (currentWeather.weather == Weather.harshSun) {
             // If move is Fire -> 1.5, Water -> 0.5
          }
          
          // Critical Hit Logic
          bool isCrit = false;
          double critMult = 1.0;
          double critChance = 0.0416; // ~1/24 default
          if (move.critRate == 1) critChance = 0.125;
          if (move.critRate == 2) critChance = 0.50;
          if (move.critRate >= 3) critChance = 1.0;

          if (Random().nextDouble() < critChance) {
            isCrit = true;
            critMult = 1.5;
          }

          // Vulnerable Status
          double vulnerableMod = 1.0;
          if (defender.statusEffect.type == StatusEffectType.vulnerable) {
            vulnerableMod = 1.3; // Take 30% more damage
          }

          // Type Effectiveness
          double typeMod = 1.0;
          for (final defType in defender.types) {
             typeMod *= TypeChart.getEffectiveness(move.type, defType);
          }

          final damage = ((attacker.currentAttack / defender.currentDefense) * move.baseDamage * weatherMod * critMult * vulnerableMod * typeMod * (Random().nextDouble() * 0.2 + 0.9)).round(); 
          defender.health -= damage;
          defender.health = defender.health.clamp(0, defender.maxHealth); 
          totalDamageDealt += damage;
          
          _addToLog(hits > 1 ? 'Hit ${i+1}!' : '${defender.organism.baseOrganism.name} took $damage damage!');
          
          if (typeMod > 1.0) _addToLog('It\'s super effective!');
          if (typeMod < 1.0 && typeMod > 0) _addToLog('It\'s not very effective...');
          if (typeMod == 0) _addToLog('It had no effect!');
          if (isCrit) _addToLog('A critical hit!');
          
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 300));
        }
    }

    if (hits > 1) {
      _addToLog('Hit $hits times!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Drain Effect
    if (move.drainPercent > 0 && totalDamageDealt > 0) {
      final heal = (totalDamageDealt * move.drainPercent).round();
      attacker.health += heal;
      attacker.health = attacker.health.clamp(0, attacker.maxHealth);
      _addToLog('${attacker.organism.baseOrganism.name} drained energy!');
      notifyListeners();
    }

    // Recoil Effect
    if (move.recoilPercent > 0 && totalDamageDealt > 0) {
      final recoil = (totalDamageDealt * move.recoilPercent).round();
      attacker.health -= recoil;
      attacker.health = attacker.health.clamp(0, attacker.maxHealth);
      _addToLog('${attacker.organism.baseOrganism.name} is damaged by recoil!');
      notifyListeners();
    }
    
    // 3. Effect Application
    await _applyMoveEffect(attacker, defender, move.effect);
  }

  Future<bool> _canMove(BattleOrganism org) async {
    if (org.statusEffect.type == StatusEffectType.sleep) {
      _addToLog('${org.organism.baseOrganism.name} is fast asleep.');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      return false; 
    }
    if (org.statusEffect.type == StatusEffectType.stun) {
      _addToLog('${org.organism.baseOrganism.name} is stunned and cannot move!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      // Stun usually lasts 1 turn, so we might want to clear it here or rely on duration logic. 
      // For now, let's assume duration logic handles it, or clarify that stun wears off.
      return false;
    }
    if (org.statusEffect.type == StatusEffectType.confusion) {
      _addToLog('${org.organism.baseOrganism.name} is confused!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      if (Random().nextDouble() < 0.33) {
         _addToLog('It hurt itself in its confusion!');
         final selfDamage = (org.maxHealth * 0.15).round();
         org.health -= selfDamage;
         org.health = org.health.clamp(0, org.maxHealth);
         notifyListeners();
         await Future.delayed(const Duration(milliseconds: 500));
         return false;
      }
    }
    if (org.statusEffect.type == StatusEffectType.freeze) {
       _addToLog('${org.organism.baseOrganism.name} is frozen solid!');
       notifyListeners();
       await Future.delayed(const Duration(milliseconds: 500));
       return false;
    }
    if (org.statusEffect.type == StatusEffectType.paralysis) {
      if (Random().nextDouble() < 0.25) {
        _addToLog('${org.organism.baseOrganism.name} is paralyzed! It can\'t move!');
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 500));
        return false;
      }
    }
    return true;
  }

  Future<void> _processOpponentTurn({required bool isCounter}) async {
    if (!isCounter) {
        _addToLog('Opponent\'s turn!');
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 700));
    }
    
    // Simple AI: Select a random move from its specific list


    // Simple AI: Select a random move from its specific list
    final opponentMove = opponentMoves[Random().nextInt(opponentMoves.length)];

    if (await _canMove(opponent)) {
      await _executeTurn(opponent, player, opponentMove);
    }
  }

  // --- Core Effect Logic ---
  
  Future<void> _applyMoveEffect(BattleOrganism attacker, BattleOrganism defender, MoveEffect effect) async {
    if (effect.type == MoveEffectType.none) return;

    final target = effect.target == 'self' ? attacker : defender;
    
    switch (effect.type) {
      case MoveEffectType.statusPoison:
        if (target.statusEffect.type == StatusEffectType.none) {
          if (currentTerrain.terrain == Terrain.misty) {
             _appendToLog('\nMisty Terrain prevents status conditions!');
          } else {
             target.statusEffect = const StatusEffect(type: StatusEffectType.poison);
             _appendToLog('\n${target.organism.baseOrganism.name} was poisoned!');
          }
        }
        break;
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
        if (target.statusEffect.type == StatusEffectType.none) {
           if (currentTerrain.terrain == Terrain.misty || (effect.type == MoveEffectType.statusSleep && currentTerrain.terrain == Terrain.electric)) {
             _appendToLog('\nThe terrain prevents the status condition!');
           } else {
             // Map MoveEffectType to StatusEffectType
             var statusType = StatusEffectType.none;
             if (effect.type == MoveEffectType.statusBurn) statusType = StatusEffectType.burn;
             else if (effect.type == MoveEffectType.statusSleep) statusType = StatusEffectType.sleep;
             else if (effect.type == MoveEffectType.statusParalysis) statusType = StatusEffectType.paralysis;
             else if (effect.type == MoveEffectType.statusFreeze) statusType = StatusEffectType.freeze;
             else if (effect.type == MoveEffectType.statusBleed) statusType = StatusEffectType.bleed;
             else if (effect.type == MoveEffectType.statusConfusion) statusType = StatusEffectType.confusion;
             else if (effect.type == MoveEffectType.statusBlind) statusType = StatusEffectType.blind;
             else if (effect.type == MoveEffectType.statusRegen) statusType = StatusEffectType.regen;
             else if (effect.type == MoveEffectType.statusVulnerable) statusType = StatusEffectType.vulnerable;
             else if (effect.type == MoveEffectType.statusStun) statusType = StatusEffectType.stun;
             
             final newStatus = StatusEffect(type: statusType, duration: (effect.type == MoveEffectType.statusSleep) ? 2 + Random().nextInt(3) : -1); 
             target.statusEffect = newStatus;
             _appendToLog('\n${target.organism.baseOrganism.name} ${newStatus.startMessage}');
           }
        }
        break;
      case MoveEffectType.weather:
        // Ex: value mapping to Weather enum could be done here. 
        // For now, hardcode "Rain" if stat == 'rain', etc.
        if (effect.stat == 'rain') _setWeather(Weather.rain);
        else if (effect.stat == 'sun') _setWeather(Weather.harshSun);
        else if (effect.stat == 'hail') _setWeather(Weather.hail);
        else if (effect.stat == 'sandstorm') _setWeather(Weather.sandstorm);
        break;
      case MoveEffectType.terrain:
        if (effect.stat == 'electric') _setTerrain(Terrain.electric);
        else if (effect.stat == 'grassy') _setTerrain(Terrain.grassy);
        else if (effect.stat == 'misty') _setTerrain(Terrain.misty);
        else if (effect.stat == 'psychic') _setTerrain(Terrain.psychic);
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
  
  Future<void> _applyGlobalTurnEffects() async {
    // Weather
    if (weatherTurnsLeft > 0) {
      weatherTurnsLeft--;
      _addToLog(currentWeather.weather == Weather.rain ? 'Rain continues to fall.' : 
                currentWeather.weather == Weather.harshSun ? 'The sunlight is strong.' : 
                currentWeather.weather == Weather.hail ? 'The hail crashes down.' : 
                currentWeather.weather == Weather.sandstorm ? 'The sandstorm rages.' : '');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (weatherTurnsLeft == 0) {
        _addToLog(currentWeather.endMessage);
        currentWeather = const WeatherEffect(weather: Weather.none);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    
    // Terrain
    if (terrainTurnsLeft > 0) {
      terrainTurnsLeft--;
      if (terrainTurnsLeft == 0) {
        _addToLog(currentTerrain.endMessage);
        currentTerrain = const TerrainEffect(terrain: Terrain.none);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> _applyTurnEffects(BattleOrganism target) async {
    if (target.health <= 0) return; 
    
    // Status Damage
    if (target.statusEffect.type == StatusEffectType.poison) {
      final poisonDamage = (target.maxHealth * 0.125).round().clamp(1, 9999); 
      target.health -= poisonDamage;
      target.health = target.health.clamp(0, target.maxHealth);
      _addToLog('${target.organism.baseOrganism.name} is hurt by poison!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
    } else if (target.statusEffect.type == StatusEffectType.burn) {
       final burnDamage = (target.maxHealth * 0.06).round().clamp(1, 9999);
       target.health -= burnDamage;
       target.health = target.health.clamp(0, target.maxHealth);
       _addToLog('${target.organism.baseOrganism.name} is hurt by its burn!');
       notifyListeners();
       await Future.delayed(const Duration(milliseconds: 500));
    } else if (target.statusEffect.type == StatusEffectType.bleed) {
       final bleedDamage = (target.maxHealth * 0.125).round().clamp(1, 9999);
       target.health -= bleedDamage;
       target.health = target.health.clamp(0, target.maxHealth);
       _addToLog('${target.organism.baseOrganism.name} is hurt by bleeding!');
       notifyListeners();
       await Future.delayed(const Duration(milliseconds: 500));
    } else if (target.statusEffect.type == StatusEffectType.regen) {
       final heal = (target.maxHealth * 0.06).round().clamp(1, 9999);
       target.health += heal;
       target.health = target.health.clamp(0, target.maxHealth);
       _addToLog('${target.organism.baseOrganism.name} restored a little HP.');
       notifyListeners();
       await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Weather Damage (Sandstorm/Hail)
    if (currentWeather.weather == Weather.sandstorm) {
       // TODO: Check types (Rock/Ground/Steel immune). For now, damage everyone.
       final damage = (target.maxHealth * 0.06).round().clamp(1, 9999);
       target.health -= damage;
       target.health = target.health.clamp(0, target.maxHealth);
        _addToLog('The sandstorm buffets ${target.organism.baseOrganism.name}!');
       notifyListeners();
       await Future.delayed(const Duration(milliseconds: 500));
    }
    
    // Grassy Terrain Healing
    if (currentTerrain.terrain == Terrain.grassy) {
      final heal = (target.maxHealth * 0.06).round();
      target.health += heal;
      target.health = target.health.clamp(0, target.maxHealth);
      _addToLog('${target.organism.baseOrganism.name} is healed by the Grassy Terrain!');
       notifyListeners();
       await Future.delayed(const Duration(milliseconds: 500));
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