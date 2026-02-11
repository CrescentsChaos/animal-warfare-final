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
  int speedStage = 0; // Added speed stage

  StatusEffect statusEffect = const StatusEffect(type: StatusEffectType.none); // Strong typing
  
  // New flags for complex moves
  bool isInvulnerable = false;
  bool isProtected = false;
  bool mustRecharge = false;
  Move? chargingMove;
  int protectSuccessionCount = 0;
  bool tookDamageThisTurn = false;
  String semiInvulnerableTag = ''; // e.g., 'underground'

  BattleOrganism(this.organism)
      : health = organism.currentHealth.clamp(0, organism.maxHealth),
        ability = Ability.findByName(organism.baseOrganism.abilities);

  List<ElementalType>? _battleTypes;
  List<ElementalType> get types => _battleTypes ?? organism.baseOrganism.elementalTypes;
  set battleTypes(List<ElementalType> value) => _battleTypes = value;

  // Helper for stat stage multipliers (e.g., +1 stage is 1.5x)
  static double _getStatStageMultiplier(int stage) {
    if (stage > 0) return (2 + stage) / 2;
    if (stage < 0) return 2 / (2 + stage.abs());
    return 1.0;
  }

  double _getAbilityStatMultiplier(String statName) {
    if (ability == null || ability!.trigger != AbilityTrigger.onCalculateStat || ability!.targetStat != statName) {
      return 1.0;
    }

    // Check conditions
    for (final condition in ability!.conditions) {
      if (condition == 'statused' && statusEffect.type == StatusEffectType.none) return 1.0;
      if (condition == 'hp_below_30' && health / maxHealth > 0.3) return 1.0;
      if (condition == 'weather_sandstorm' && !(BattleManager.currentWeatherGlobal?.weather == Weather.sandstorm)) return 1.0;
      if (condition == 'weather_sun' && !(BattleManager.currentWeatherGlobal?.weather == Weather.heatwave)) return 1.0;
      if (condition == 'weather_rain' && !(BattleManager.currentWeatherGlobal?.weather == Weather.rain)) return 1.0;
      if (condition == 'weather_snow' && !(BattleManager.currentWeatherGlobal?.weather == Weather.snow || BattleManager.currentWeatherGlobal?.weather == Weather.blizzard)) return 1.0;
    }

    return ability!.magnitude;
  }

  int get currentAttack {
    double attack = organism.effectiveAttack.toDouble();
    attack *= _getStatStageMultiplier(attackStage);
    attack *= _getAbilityStatMultiplier('attack');

    // Burn halves attack
    if (statusEffect.type == StatusEffectType.burn) {
      attack *= 0.5;
    }

    // Talisman boost
    if (organism.equippedTalisman?.effect.type == TalismanEffectType.attackBoost) {
      attack *= organism.equippedTalisman!.effect.magnitude;
    }

    return attack.round();
  }

  int get currentDefense {
    double defense = (organism.effectiveDefense * _getStatStageMultiplier(defenseStage)).toDouble();
    defense *= _getAbilityStatMultiplier('defense');
    
    // Talisman boost
    if (organism.equippedTalisman?.effect.type == TalismanEffectType.defenseBoost) {
      defense *= organism.equippedTalisman!.effect.magnitude;
    }
    
    return defense.round();
  }

  int get currentSpeed {
    double speed = organism.effectiveSpeed.toDouble();
    speed *= _getAbilityStatMultiplier('speed');

    // Paralysis quarters speed
    if (statusEffect.type == StatusEffectType.paralysis) {
      speed *= 0.25;
    }

    // Talisman boost
    if (organism.equippedTalisman?.effect.type == TalismanEffectType.speedBoost) {
      speed *= organism.equippedTalisman!.effect.magnitude;
    }

    speed *= _getStatStageMultiplier(speedStage);

    return speed.round();
  }

  /// Use the captured organism's calculated max HP (IVs included), not base stat.
  int get maxHealth {
    double hp = organism.maxHealth.toDouble();
    
    // Talisman boost
    if (organism.equippedTalisman?.effect.type == TalismanEffectType.healthBoost) {
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
  
  static WeatherEffect? currentWeatherGlobal;
  static TerrainEffect? currentTerrainGlobal;
  int weatherTurnsLeft = 0;
  int terrainTurnsLeft = 0;

  BattleState currentState = BattleState.waitingForInput;
  String battleLog = ''; // Current/Latest message
  
  // LOGGING REFACTOR
  int currentTurn = 1;
  final List<BattleTurn> turnHistory = [];
  BattleResult? result;
  
  // LOOT DROP
  String? droppedLoot; // loot_id of dropped item, if any

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

  BattleManager(this.playerOrganism, this.opponentOrganism, {String? biomeName}) {
    player = BattleOrganism(playerOrganism);
    opponent = BattleOrganism(opponentOrganism);
    
    // Initialize move lists
    playerMoves = _getOrganismMoves(playerOrganism);
    opponentMoves = _getOrganismMoves(opponentOrganism);
    
    // Initialize first turn
    turnHistory.add(BattleTurn(currentTurn));

    _addToLog('A wild ${opponent.organism.name} appeared! Go, ${player.organism.name}!'); 
    
    currentWeatherGlobal = currentWeather;
    currentTerrainGlobal = currentTerrain;

    _initializeBattle(biomeName);
  }
  
  void _initializeBattle(String? biomeName) {
    // 0. Apply biome weather/terrain if no ability overrides
    if (biomeName != null && biomeName.isNotEmpty) {
      final biomeWeather = BiomeWeatherTable.getRandomWeatherForBiome(biomeName);
      if (biomeWeather != Weather.none && biomeWeather != Weather.clear) {
        _setWeather(biomeWeather, 99); // Long duration for biome weather
      }
      
      final biomeTerrain = BiomeWeatherTable.getDefaultTerrainForBiome(biomeName);
      if (biomeTerrain != Terrain.none) {
        _setTerrain(biomeTerrain, 99);
      }
    }
    
    // 1. Check for Auto-Weather/Terrain/Intimidate (abilities can override)
    _checkEntranceAbility(player, opponent);
    _checkEntranceAbility(opponent, player);
    
    // 2. Speed Check
    if (player.currentSpeed < opponent.currentSpeed) {
      _appendToLog('\n${opponent.organism.name} is faster and will attack first!');
    }
  }

  void _checkEntranceAbility(BattleOrganism user, BattleOrganism target) {
    if (user.ability == null || user.ability!.trigger != AbilityTrigger.onEntry) return;
    
    switch (user.ability!.effectType) {
      case AbilityEffectType.weatherChange:
        if (user.ability!.value == 'rain') _setWeather(Weather.rain);
        else if (user.ability!.value == 'sun') _setWeather(Weather.heatwave);
        else if (user.ability!.value == 'hail') _setWeather(Weather.blizzard);
        else if (user.ability!.value == 'sandstorm') _setWeather(Weather.sandstorm);
        break;
      case AbilityEffectType.terrainChange:
         if (user.ability!.value == 'electric') _setTerrain(Terrain.electric);
         else if (user.ability!.value == 'grassy') _setTerrain(Terrain.grassy);
         else if (user.ability!.value == 'misty') _setTerrain(Terrain.misty);
         else if (user.ability!.value == 'psychic') _setTerrain(Terrain.psychic);
         break;
      case AbilityEffectType.statChange:
        _applyStatChange(user.ability!.targetStat == 'attack' ? target : user, 
            user.ability!.targetStat, user.ability!.magnitude.toInt());
        _appendToLog('\n${user.organism.baseOrganism.name}\'s ${user.ability!.name} triggered!');
        break;
      default:
        break;
    }
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
      case Weather.rain: return 'Rain continues to fall.';
      case Weather.heavyRain: return 'The downpour persists!';
      case Weather.drizzle: return 'It\'s still drizzling.';
      case Weather.snow: return 'Snow keeps falling.';
      case Weather.blizzard: return 'The blizzard rages on!';
      case Weather.fog: return 'The fog lingers.';
      case Weather.heatwave: return 'The heat is intense!';
      case Weather.sandstorm: return 'The sandstorm continues.';
      case Weather.windstorm: return 'Strong winds persist.';
      case Weather.thunderstorm: return 'The storm rumbles on!';
      default: return '';
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
    
    // Pre-calculate opponent move for priority check
    final opponentMove = opponentMoves[Random().nextInt(opponentMoves.length)];
    
    // 1. Process who moves first in this turn (Check Priority first, then Speed)
    bool playerGoesFirst = false;
    
    // Priority Check
    int playerPriority = move.priority;
    int opponentPriority = opponentMove.priority;

    // Gale Wings check
    if (player.ability?.name == 'Gale Wings' && 
        player.health == player.maxHealth && 
        move.type == ElementalType.flying) {
      playerPriority += (player.ability!.magnitude).toInt();
    }
    if (opponent.ability?.name == 'Gale Wings' && 
        opponent.health == opponent.maxHealth && 
        opponentMove.type == ElementalType.flying) {
      opponentPriority += (opponent.ability!.magnitude).toInt();
    }

    if (playerPriority > opponentPriority) {
      playerGoesFirst = true;
    } else if (opponentPriority > playerPriority) {
      playerGoesFirst = false;
    } else {
      // Speed Check (same priority)
      if (player.currentSpeed >= opponent.currentSpeed) {
        playerGoesFirst = true;
      }
    }
    
    // Reset "took damage" at start of turn
    player.tookDamageThisTurn = false;
    opponent.tookDamageThisTurn = false;

    if (playerGoesFirst) {
      if (await _canMove(player)) {
        await _executeTurn(player, opponent, move, opponentMove: opponentMove);
      }
      if (_checkBattleEnd()) return;
      
      // Calculate Opponent Move (Need to select it earlier for priority check)
      // Done above in logic preparation
      if (await _canMove(opponent)) {
         await _executeTurn(opponent, player, opponentMove, opponentMove: move);
      }
    } else {
      if (await _canMove(opponent)) {
         await _executeTurn(opponent, player, opponentMove, opponentMove: move);
      }
      if (_checkBattleEnd()) return;

      if (await _canMove(player)) {
        await _executeTurn(player, opponent, move, opponentMove: opponentMove);
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
      
      // Clear one-turn flags
      player.isProtected = false;
      opponent.isProtected = false;
      player.isInvulnerable = false; // Should already be false if move finished, but safe to clear
      opponent.isInvulnerable = false;
    }
    notifyListeners();
  }
  
  // Executes the move and applies effects
  Future<void> _executeTurn(BattleOrganism attacker, BattleOrganism defender, Move move, {Move? opponentMove}) async {
    // Check if this is the second turn of a multi-turn move
    if (attacker.chargingMove != null) {
      move = attacker.chargingMove!;
      attacker.chargingMove = null;
      attacker.isInvulnerable = false; // Reset semi-invulnerability
    } else if (move.isMultiTurn) {
        // First turn of a multi-turn move
        if (move.effect.type == MoveEffectType.semiInvulnerable) {
          _addToLog('${attacker.organism.baseOrganism.name} ${move.name == 'Dig' ? 'burrowed underground!' : 'is preparing an attack!'}');
          attacker.isInvulnerable = true;
          attacker.semiInvulnerableTag = move.effect.stat;
          attacker.chargingMove = move;
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 700));
          return;
        } else if (move.effect.type == MoveEffectType.charge) {
          _addToLog('${attacker.organism.baseOrganism.name} is charging energy!');
          attacker.chargingMove = move;
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 700));
          return;
        }
    }

    // recharging move stamina
    if (attacker.organism.moveStamina.containsKey(move.name)) {
      attacker.organism.moveStamina[move.name] = (attacker.organism.moveStamina[move.name]! - 1).clamp(0, move.stamina);
    }

    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 700));

    // --- Ability Triggers: onCalculateDamage (Self) ---
    // (Already handled in damageCalc for Adaptability)

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
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    // 2. Protection and Invulnerability Checks
    if (defender.isInvulnerable) {
      _addToLog('${defender.organism.baseOrganism.name} is hidden!');
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    if (defender.isProtected) {
      _addToLog('${defender.organism.baseOrganism.name} protected itself!');
      if (move.name == 'Baneful Bunker' || (move.name != 'Protect' && attacker.organism.baseOrganism.moves.contains('Baneful Bunker'))) {
         if (move.baseDamage > 0) {
           await _applyMoveEffect(defender, attacker, const MoveEffect(type: MoveEffectType.statusPoison), move);
         }
      }
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      return;
    }

    // Flag-based fail check
    if (move.failIfTargetNotAttacking) {
       if (opponentMove == null || opponentMove.baseDamage == 0) {
         _addToLog('...but it failed!');
         notifyListeners();
         await Future.delayed(const Duration(milliseconds: 500));
         return;
       }
    }

    // Generic damage stat source
    int effectiveAttackerAtk = attacker.currentAttack;
    if (move.damageStat == 'defense') {
      effectiveAttackerAtk = attacker.currentDefense;
    } else if (move.damageStat == 'speed') {
      effectiveAttackerAtk = attacker.currentSpeed;
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
          double weatherMod = currentWeather.getDamageMultiplier(move.type.toString().split('.').last);
          
          // Critical Hit Logic
          bool isCrit = false;
          double critChance = 6.25; // Base 1/16 chance
          
          // Talisman crit boost
          if (attacker.organism.equippedTalisman?.effect.type == TalismanEffectType.critBoost) {
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
          if (defender.ability?.name == 'Battle Armor') {
             isCrit = false;
          }
          
          double damageCalc = ((effectiveAttackerAtk / defender.currentDefense) * move.baseDamage);
          if (isCrit) {
            damageCalc *= 1.5;
          }

          // Generic conditional multiplier
          if (move.multiplierCondition.isNotEmpty) {
            double multiplier = 1.0;
            final condition = move.multiplierCondition.toLowerCase();
            
            if (condition == 'target_poisoned' && defender.statusEffect.type == StatusEffectType.poison) {
              multiplier = move.conditionalMultiplier;
            } else if (condition == 'target_damaged' && defender.tookDamageThisTurn) {
              multiplier = move.conditionalMultiplier;
            } else if (condition == 'target_statused' && defender.statusEffect.type != StatusEffectType.none) {
              multiplier = move.conditionalMultiplier;
            }
            
            damageCalc *= multiplier;
          }
          
          // Talisman damage multiplier
          if (attacker.organism.equippedTalisman?.effect.type == TalismanEffectType.damageMultiplier) {
            damageCalc *= attacker.organism.equippedTalisman!.effect.magnitude;
          }
          
          // Talisman resistance boost (multiplier on incoming damage)
          if (defender.organism.equippedTalisman?.effect.type == TalismanEffectType.resistanceBoost) {
            damageCalc *= defender.organism.equippedTalisman!.effect.magnitude;
          }

          // Vulnerable Status
          if (defender.statusEffect.type == StatusEffectType.vulnerable) {
            damageCalc *= 1.3; // Take 30% more damage
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
            if (attacker.ability?.name == 'Adaptability') {
              stabBonus = attacker.ability!.magnitude;
            }
            damageCalc *= stabBonus;
          }

          // Weather Modifiers
          damageCalc *= weatherMod;

          // Randomness (0.9 to 1.1) and Round
          final int finalDamage = (damageCalc * (Random().nextDouble() * 0.2 + 0.9)).round(); 
          
          int oldHealth = defender.health;
          defender.health -= finalDamage;
          defender.health = defender.health.clamp(0, defender.maxHealth); 
          totalDamageDealt += finalDamage;
          defender.tookDamageThisTurn = true;
          
          if (move.drainPercent > 0 && finalDamage > 0) {
            final healAmount = (finalDamage * move.drainPercent).round();
            attacker.health = (attacker.health + healAmount).clamp(0, attacker.maxHealth);
            _addToLog('${attacker.organism.baseOrganism.name} drained $healAmount health!');
          }
          if (move.recoilPercent > 0 && finalDamage > 0) {
            final recoilDamage = (finalDamage * move.recoilPercent).round();
            attacker.health = (attacker.health - recoilDamage).clamp(0, attacker.maxHealth);
            _addToLog('${attacker.organism.baseOrganism.name} took $recoilDamage recoil damage!');
          }
          // --- Ability Triggers: onDamageTaken ---
          if (defender.ability != null && defender.ability!.trigger == AbilityTrigger.onDamageTaken) {
            final ab = defender.ability!;
            bool conditionMet = true;
            for (final cond in ab.conditions) {
               if (cond == 'crit' && !isCrit) conditionMet = false;
               if (cond == 'hp_below_50' && (defender.health / defender.maxHealth >= 0.5 || oldHealth / defender.maxHealth < 0.5)) conditionMet = false;
               if (cond == 'contact') {} // Trigger for contact moves
            }

            if (conditionMet) {
                if (ab.effectType == AbilityEffectType.statChange) {
                  _applyStatChange(defender, ab.targetStat, ab.magnitude.toInt());
                  _appendToLog('\n${defender.organism.baseOrganism.name}\'s ${ab.name} triggered!');
                } else if (ab.effectType == AbilityEffectType.typeChange) {
                  defender.battleTypes = [move.type];
                  _appendToLog('\n${defender.organism.baseOrganism.name} changed its type to ${move.type.toString().split('.').last}!');
                } else if (ab.effectType == AbilityEffectType.statusChange && Random().nextDouble() < ab.chance) {
                  if (attacker.statusEffect.type == StatusEffectType.none) {
                     attacker.statusEffect = StatusEffect(type: StatusEffectType.poison);
                     _appendToLog('\n${attacker.organism.baseOrganism.name} was poisoned by ${defender.ability!.name}!');
                  }
                }
            }
          }
          
          _addToLog(hits > 1 ? 'Hit ${i+1}!' : '${defender.organism.baseOrganism.name} took $finalDamage damage!');
          
          if (typeMod > 1.0) _addToLog('It\'s super effective!');
          if (typeMod < 1.0 && typeMod > 0) _addToLog('It\'s not very effective...');
          if (typeMod == 0) _addToLog('It had no effect!');
          if (isCrit) _addToLog('A critical hit!');
          
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 300));
        }
    }
    if (attacker.health > 0 && defender.health >= 0) {
      await _applyMoveEffect(attacker, defender, move.effect, move);
    }
  }

  Future<bool> _canMove(BattleOrganism org) async {
    if (org.mustRecharge) {
      _addToLog('${org.organism.baseOrganism.name} must recharge!');
      org.mustRecharge = false; // Recharge turn is used now
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      return false;
    }
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
      // Stun is cleared immediately after skipping one turn
      org.statusEffect = const StatusEffect(type: StatusEffectType.none);
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
  
  Future<void> _applyMoveEffect(BattleOrganism attacker, BattleOrganism defender, MoveEffect effect, Move move) async {
    if (effect.type == MoveEffectType.none) {
       // Still check for HP cost even if effect is none
       _handleHPCost(attacker, effect);
       return;
    }

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
        if (target.statusEffect.type == StatusEffectType.none) {
           // Mapping
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
           else if (effect.type == MoveEffectType.statusPoison) statusType = StatusEffectType.poison;

          // --- Ability Trigger: onStatusAttempt (Prevention) ---
          if (target.ability != null && target.ability!.trigger == AbilityTrigger.onStatusAttempt) {
             if (target.ability!.effectType == AbilityEffectType.preventStatus && 
                 target.ability!.value == statusType.toString().split('.').last) {
               _appendToLog('\n${target.organism.baseOrganism.name}\'s ${target.ability!.name} prevents status!');
               return;
             }
          }

          if (Random().nextInt(100) >= effect.chance) return;

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
            
            // Default durations: Sleep (1-3), Stun (1), Others (3-5)
            int duration = 3 + Random().nextInt(3); // 3-5 turns default
            if (effect.type == MoveEffectType.statusSleep) duration = 1 + Random().nextInt(3); // 1-3 turns
            if (effect.type == MoveEffectType.statusStun) duration = 1;

            final newStatus = StatusEffect(type: statusType, duration: duration); 
            target.statusEffect = newStatus;
            _appendToLog('\n${target.organism.baseOrganism.name} ${newStatus.startMessage}');
          }
        }
        break;
      case MoveEffectType.weather:
        // Ex: value mapping to Weather enum could be done here. 
        // For now, hardcode "Rain" if stat == 'rain', etc.
        if (effect.stat == 'rain') _setWeather(Weather.rain);
        else if (effect.stat == 'sun') _setWeather(Weather.heatwave);
        else if (effect.stat == 'hail') _setWeather(Weather.blizzard);
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
      case MoveEffectType.multiStatChange:
        _applyStatChange(target, effect.stat, effect.value);
        _appendToLog('\n${target.organism.baseOrganism.name}\'s ${effect.stat} stages changed!');
        break;
      case MoveEffectType.statChangeChance:
        if (Random().nextInt(100) < effect.chance) {
          _applyStatChange(target, effect.stat, effect.value);
          _appendToLog('\n${target.organism.baseOrganism.name}\'s ${effect.stat} stages increased!');
        }
        break;
      case MoveEffectType.protect:
        attacker.isProtected = true;
        break;
      case MoveEffectType.heal:
        final healedAmount = effect.value;
        target.health += healedAmount;
        target.health = target.health.clamp(0, target.maxHealth);
        _appendToLog('\n${target.organism.baseOrganism.name} recovered $healedAmount HP!');
        break;
      default:
        break;
    }

    _handleHPCost(attacker, effect);
    
    // Generic logic for multi-stat changes triggered on second turn of charge
    if (attacker.chargingMove == null && move.effect.type == MoveEffectType.charge) {
       _applyStatChange(attacker, move.effect.stat, move.effect.value);
       _appendToLog('\n${attacker.organism.baseOrganism.name}\'s stats sharply rose!');
    }
    
    if (move.name == 'Rest') {
      attacker.health = attacker.maxHealth;
      attacker.statusEffect = const StatusEffect(type: StatusEffectType.sleep, duration: 2);
      _appendToLog('\n${attacker.organism.baseOrganism.name} fell asleep and restored its HP!');
    }

    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
  }

  void _handleHPCost(BattleOrganism attacker, MoveEffect effect) {
    if (effect.hpCostPercent > 0) {
      final cost = (attacker.maxHealth * effect.hpCostPercent).round();
      attacker.health -= cost;
      attacker.health = attacker.health.clamp(0, attacker.maxHealth);
      _appendToLog('\n${attacker.organism.baseOrganism.name} cut its own HP!');
    }
  }

  void _applyStatChange(BattleOrganism target, String stat, int value) {
    // --- Ability Trigger: onStatLoss (Prevention) ---
    if (value < 0 && target.ability != null && target.ability!.trigger == AbilityTrigger.onStatLoss) {
       if (target.ability!.effectType == AbilityEffectType.preventStatLoss) {
         _appendToLog('\n${target.organism.baseOrganism.name}\'s ${target.ability!.name} prevents stat loss!');
         return;
       }
    }

    if (stat == 'all') {
      _changeStat(target, 'attack', value);
      _changeStat(target, 'defense', value);
      _changeStat(target, 'speed', value);
    } else {
      final stats = stat.split(',');
      for (final s in stats) {
        final pair = s.trim().split(':'); 
        final statName = pair[0];
        final statValue = pair.length > 1 ? int.tryParse(pair[1]) ?? value : value;
        _changeStat(target, statName, statValue);
      }
    }
  }

  void _changeStat(BattleOrganism target, String statName, int value) {
    int oldStage = 0;
    if (statName == 'attack') oldStage = target.attackStage;
    else if (statName == 'defense') oldStage = target.defenseStage;
    else if (statName == 'speed') oldStage = target.speedStage;

    if (statName == 'attack') target.attackStage = (target.attackStage + value).clamp(-6, 6);
    else if (statName == 'defense') target.defenseStage = (target.defenseStage + value).clamp(-6, 6);
    else if (statName == 'speed') target.speedStage = (target.speedStage + value).clamp(-6, 6);
    
    // --- Ability Trigger: onStatLoss (Reaction e.g. Defiant) ---
    if (value < 0 && target.ability != null && target.ability!.trigger == AbilityTrigger.onStatLoss) {
       if (target.ability!.effectType == AbilityEffectType.statChange) {
         _applyStatChange(target, target.ability!.targetStat, target.ability!.magnitude.toInt());
         _appendToLog('\n${target.organism.baseOrganism.name}\'s ${target.ability!.name} triggered!');
       }
    }
  }
  
  Future<void> _applyGlobalTurnEffects() async {
    // Weather
    if (weatherTurnsLeft > 0) {
      weatherTurnsLeft--;
      // Show weather persistence message occasionally
      if (weatherTurnsLeft % 3 == 0 && currentWeather.weather != Weather.clear) {
        final msg = _getWeatherPersistenceMessage(currentWeather.weather);
        if (msg.isNotEmpty) {
          _addToLog(msg);
          notifyListeners();
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
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
    
    // Weather Damage
    if (currentWeather.weather == Weather.sandstorm) {
       // TODO: Check types (Rock/Ground/Steel immune). For now, damage everyone.
       final damage = (target.maxHealth * 0.06).round().clamp(1, 9999);
       target.health -= damage;
       target.health = target.health.clamp(0, target.maxHealth);
        _addToLog('${target.organism.baseOrganism.name} is buffeted by the sandstorm!');
       notifyListeners();
       await Future.delayed(const Duration(milliseconds: 500));
    } else if (currentWeather.weather == Weather.blizzard) {
       // Blizzard damages non-Ice types
       final damage = (target.maxHealth * 0.0625).round().clamp(1, 9999);
       target.health -= damage;
       target.health = target.health.clamp(0, target.maxHealth);
       _addToLog('${target.organism.baseOrganism.name} is battered by the blizzard!');
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
    
    // Status Duration Decay and Recovery
    if (target.statusEffect.type != StatusEffectType.none && target.statusEffect.duration > 0) {
      int decay = 1;
      if (target.ability?.effectType == AbilityEffectType.wakeUpFaster && target.statusEffect.type == StatusEffectType.sleep) {
         decay = 2;
      }
      target.statusEffect = target.statusEffect.copyWith(duration: max(0, target.statusEffect.duration - decay));
      
      if (target.statusEffect.duration == 0) {
        _addToLog('${target.organism.baseOrganism.name} recovered from ${target.statusEffect.name}!');
        target.statusEffect = const StatusEffect(type: StatusEffectType.none);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 500));
      }
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

    // Arena Trap check
    if (opponent.ability?.name == 'Arena Trap') {
       _addToLog('The wild ${opponent.organism.baseOrganism.name} prevents escape!');
       currentState = BattleState.opponentTurn;
       await Future.delayed(const Duration(seconds: 1));
       await _processOpponentTurn(isCounter: false);
       currentState = BattleState.waitingForInput;
       notifyListeners();
       return;
    }

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
      
      // Roll for loot
      droppedLoot = opponent.organism.baseOrganism.rollLootDrop();
      if (droppedLoot != null) {
        _addToLog('The wild ${opponent.organism.baseOrganism.name} fainted! You won the battle.');
        _appendToLog('\nIt dropped something!');
      } else {
        _addToLog('The wild ${opponent.organism.baseOrganism.name} fainted! You won the battle.');
      }
      
      currentState = BattleState.battleEnd;
      notifyListeners();
      return true;
    }
    return false;
  }
}