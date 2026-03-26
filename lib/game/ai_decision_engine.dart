// lib/game/ai_decision_engine.dart
import 'dart:math';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/game/player_history.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';

// ─────────────────────────────────────────────
// Trait 31-40: Team Archetype Enum
// ─────────────────────────────────────────────
enum TeamArchetype {
  hyperOffense, // 31: All-out attack, no setup
  stall, // 32: Protect/Toxic/Rest loops
  balanced, // 33: Mix of offense and defense
  statusSpread, // 34: Aim to poison/burn everyone
  rainTeam, // 35: Set rain; exploit it (Swift Swim/Aquatic)
  sunTeam, // 36: Set sun; exploit it (Chlorophyll/Blaze)
  sandTeam, // 37: Set sand; exploit it (Sand Rush/Metal/Rock)
  snowTeam, // 38: Set snow; exploit it (Slush Rush/Cryo)
  hazardStacker, // 39: Lead with Stealth Rock/Spikes
  antiHazard, // 40: Clear hazards with Rapid Spin/Defog
  revengeKiller, // 41: Fast priority sweeper
  defensiveCore, // 42: Bulk up and rotate tanks
  setupSweeper, // 43: Setup move then sweep
  trickRoom, // 44: Set Trick Room; slow heavy attackers sweep
  tailwindSpeed, // 45: Set Tailwind; outspeed everything
  dualScreens, // 46: Set Reflect/Light Screen; minimize damage
  prioritySweeper, // 47: Focus on priority moves (Aqua Jet/Bullet Punch)
  perishTrapper, // 48: Trap and use Perish Song
  gimmickyAssist, // 49: Metronome/Assist/Copycat chaos
  criticalFocus, // 50: High crit rate moves/items
  recoilReckless, // 51: Focus on high-damage recoil moves
  restLoop, // 52: Rest/Sleep Talk/Snore
  evasionBuffer, // 53: Double Team/Minimize (Annoying)
  bulkyBruiser, // 54: High HP/Attack but slow
  toxicStall, // 55: Focus purely on Toxic/Protect
  psychicTerrainAbuser, // 56: Set Psychic Terrain; boost Psychic moves
  electricTerrainAbuser, // 57: Set Electric Terrain; boost Electric moves
}

class AIDecisionEngine {
  /// Evaluates a move based on the 10 Core Decision Traits.
  /// Returns a score representing the desirability of the move.
  static double calculateMoveScore({
    required Move move,
    required BattleOrganism attacker,
    required BattleOrganism defender,
    required DamageResult damageResult,
    required List<String> targetHazards,
    required WeatherEffect currentEffect,
    required TerrainEffect currentTerrain,
    List<BattleOrganism>? aiTeam,
    List<BattleOrganism>? playerTeam,
    PlayerHistory? playerHistory,
    List<String>? lastUsedMoves, // Last few moves used by the AI for diversity
    TeamArchetype archetype = TeamArchetype.balanced,
    bool isTrickRoomActive = false,
    bool isTailwindActive = false,
    bool targetHasReflect = false,
    bool targetHasLightScreen = false,
    bool targetHasAuroraVeil = false,
    bool targetHasSubstitute = false,
    bool targetHasSafeguard = false,
  }) {
    double score = 0.0;

    // Redundant Environment Check
    for (final effect in move.effects) {
      if (effect.type == MoveEffectType.weather) {
        final weatherName = effect.stat.isNotEmpty
            ? effect.stat
            : effect.weather.name.toLowerCase();
        if (currentEffect.weather.name.toLowerCase() == weatherName) {
          score -= 600; // Heavily penalize setting the same weather
        }
      }
      if (effect.type == MoveEffectType.terrain) {
        if (currentTerrain.terrain.name.toLowerCase() ==
            effect.stat.toLowerCase()) {
          score -= 600; // Heavily penalize setting the same terrain
        }
      }
      if (effect.type == MoveEffectType.trickRoom) {
        if (isTrickRoomActive) {
          score -= 800;
        }
      }
    }

    // Redundant screen / tailwind check
    if ((move.name == 'Tailwind') && isTailwindActive) {
      score -= 700; // Already active, waste of a turn
    }
    if ((move.name == 'Reflect') && targetHasReflect) {
      score -= 700;
    }
    if ((move.name == 'Light Screen') && targetHasLightScreen) {
      score -= 700;
    }
    if ((move.name == 'Aurora Veil') && targetHasAuroraVeil) {
      score -= 700;
    }
    if ((move.name == 'Safeguard') && targetHasSafeguard) {
      score -= 700;
    }

    // ──────────────────────────────────────────────
    // Trait 1: Damage evaluation (calculate estimated damage)
    // Trait 2: Type effectiveness awareness
    // ──────────────────────────────────────────────
    final expectedDamage = damageResult.damage;
    final typeMultiplier = damageResult.typeMultiplier;

    if (typeMultiplier == 0) {
      return -9999.0; // The move has absolutely no effect, NEVER pick it
    }

    // ──────────────────────────────────────────────
    // Trait 8: Accuracy consideration
    // ──────────────────────────────────────────────
    final accuracy = move.accuracy / 100.0;
    final expectedValueDamage = expectedDamage * accuracy;

    // Base score heavily weighted on expected damage output
    score += expectedValueDamage * 3.0;

    if (typeMultiplier > 1.1) score += 50;
    if (typeMultiplier < 0.9) score -= 80;

    // ──────────────────────────────────────────────
    // Trait 3: Speed comparison awareness
    // ──────────────────────────────────────────────
    final isFaster = attacker.currentSpeed > defender.currentSpeed;

    // ──────────────────────────────────────────────
    // Trait 5: KO detection (can I KO this turn?)
    // ──────────────────────────────────────────────
    final bool canKO = expectedDamage >= defender.health;
    if (canKO) {
      // Massive priority to confirm a kill
      score += 200;

      // If we can KO, penalize low accuracy moves slightly more,
      // as we want to guarantee the kill securely.
      if (accuracy < 0.9) {
        score -= (1.0 - accuracy) * 100;
      }
    }

    // ──────────────────────────────────────────────
    // Trait 6: Survival detection (can I survive this turn?)
    // ──────────────────────────────────────────────
    // Simplified survival heuristic: if HP is critically low, assume survival is risky.
    final attackerHpRatio = attacker.health / attacker.maxHealth;
    final bool isSurvivalRisky = attackerHpRatio < 0.35;

    // ──────────────────────────────────────────────
    // Trait 4: Priority move usage logic
    // ──────────────────────────────────────────────
    if (move.priority > 0) {
      if (canKO && !isFaster) {
        // If we are slower, but a priority move gets the KO, ABSOLUTELY DO IT.
        score += 300;
      } else if (isSurvivalRisky && !isFaster) {
        // If we might die this turn and are slower, prioritize getting some damage in first.
        score += 100;
      } else if (isSurvivalRisky && isFaster) {
        // If we are already faster, priority is less valuable, but still nice.
        score += 20;
      }
    }

    // ──────────────────────────────────────────────
    // Trait 9: Critical hit probability awareness
    // ──────────────────────────────────────────────
    if (move.critRate > 0) {
      // Moves with higher innate crit rates are more valuable,
      // especially if we are trying to break through defenses.
      score += move.critRate * 15;
    }

    // ──────────────────────────────────────────────
    // Trait 10: Status impact evaluation
    // ──────────────────────────────────────────────
    for (final effect in move.effects) {
      final isStatusOrStat =
          effect.type.toString().contains('status') ||
          effect.type.toString().contains('statChange');

      if (isStatusOrStat && effect.target == 'opponent') {
        if (targetHasSubstitute) {
          score -=
              100; // Penalize heavily as substitute blocks most status/debuffs
        } else if (defender.statusEffects.isEmpty) {
          score += 40; // High value to cripple a fresh opponent

          if (typeMultiplier < 1.0) {
            // If we can't do much direct damage due to typing, statuses are excellent alternatives
            score += 50;
          }
        } else {
          // --- Target already has a status ---
          final isDedicatedStatusMove =
              move.category == MoveCategory.status || move.baseDamage == 0;

          if (isDedicatedStatusMove) {
            // Heuristic: Predict switch if we heavily threaten the current defender
            final predictsSwitch =
                typeMultiplier > 1.5 || expectedDamage >= defender.health;

            if (predictsSwitch) {
              score +=
                  20; // Small reward for catching a switch with a status move
            } else {
              score -= 800; // Heavily penalize redundant status moves
            }
          } else {
            score -=
                10; // Minimal penalty for attacks with secondary status effects
          }
        }
      }

      if (effect.type == MoveEffectType.heal) {
        if (attackerHpRatio < 0.35) {
          score += 150; // Desperate for heal
        } else if (attackerHpRatio < 0.6) {
          score += 60;
        } else {
          score -=
              80; // Negative value to not waste a turn healing when mostly full
        }
      }

      // Self setup (Stat boosts)
      if (effect.type == MoveEffectType.statChange ||
          effect.type == MoveEffectType.statChangeChance) {
        if (effect.target == 'self') {
          if (!isSurvivalRisky) {
            score += effect.value * 20; // Safe to setup
          } else {
            score -= 30; // Too risky to setup when near death
          }
        } else if (effect.target == 'opponent') {
          score -=
              effect.value *
              20; // Debuffing the opponent (negative value means positive score)
        }

        // Trait 26: Setup only when safe / Trait 28: Time setup properly
        if (effect.target == 'self' && effect.value > 0) {
          final defIsIncapacitated = defender.statusEffects.any(
            (se) =>
                se.type == StatusEffectType.sleep ||
                se.type == StatusEffectType.freeze ||
                se.type == StatusEffectType.stun,
          );

          if (defIsIncapacitated) {
            score += 50; // Great time to setup (Trait 28)
          }

          // Trait 27: Avoid unnecessary setup
          int currentStage = 0;
          switch (effect.stat) {
            case 'attack':
              currentStage = attacker.attackStage;
              break;
            case 'power':
              currentStage = attacker.powerStage;
              break;
            case 'defense':
              currentStage = attacker.defenseStage;
              break;
            case 'resistance':
              currentStage = attacker.resistanceStage;
              break;
            case 'speed':
              currentStage = attacker.speedStage;
              break;
          }
          if (currentStage >= 2) {
            score -= 80; // We are already boosted enough, just attack!
          } else if (canKO) {
            score -= 100; // Just take the KO instead of setting up.
          }
        }
      }

      // Hazard Setup Redundancy Check
      if (effect.type == MoveEffectType.setHazard) {
        if (targetHazards.contains(effect.stat)) {
          // If the hazard is already set on the target's side, penalize heavily!
          score -= 500;
        } else {
          // If not set, it's generally a good move to use early on.
          score += 150;
        }
      }
    }

    // ──────────────────────────────────────────────
    // Trait 29: Stall if advantageous
    // ──────────────────────────────────────────────
    final opponentHasFatalStatus = defender.statusEffects.any(
      (se) =>
          se.type == StatusEffectType.poison ||
          se.type == StatusEffectType.burn ||
          se.type == StatusEffectType.bleed,
    );
    if (opponentHasFatalStatus) {
      if (move.name == 'Protect' || move.name == 'Detect') {
        score += 100; // Stall them out!
      }
      if (move.effects.any((e) => e.type == MoveEffectType.heal)) {
        score += 80;
      }
    }

    // ──────────────────────────────────────────────
    // Trait 21-25 & 30: Team Status and Win Conditions
    // ──────────────────────────────────────────────
    if (aiTeam != null && playerTeam != null) {
      int aiAlive = aiTeam.where((m) => m.health > 0).length;
      int playerAlive = playerTeam.where((m) => m.health > 0).length;

      // Trait 30: Force trades when ahead
      if (aiAlive > playerAlive + 1 && canKO) {
        // We have a massive numbers advantage and can secure a kill.
        // Highly value moves that secure the kill even if they have recoil/recharge.
        score += 50;
      }

      final sweeper = identifyWinCondition(aiTeam);
      final wall = identifyWall(aiTeam);

      // Trait 21/23: Play to enable sweeper
      if (sweeper != null && attacker.organism.id != sweeper.organism.id) {
        // We are not the sweeper. If our move cripples/damages the opponent heavily,
        // it paves the way for the sweeper.
        if (expectedDamage > defender.maxHealth * 0.4) {
          score += 30;
        }
      }

      // Trait 25: Preserve defensive wall is handled primarily in shouldSwitch,
      // but here we can penalize the wall using recoil moves if it's healthy.
      if (wall != null && attacker.organism.id == wall.organism.id) {
        if (move.recoilPercent > 0 && attackerHpRatio > 0.5) {
          score -= 50;
        }
      }
    }

    // ──────────────────────────────────────────────
    // Trait 41-50: Prediction and Adaptation
    // ──────────────────────────────────────────────
    if (playerHistory != null) {
      final aggression = playerHistory.aggressionRatio;

      // Trait 48 is inherently tied to the rolling average aggressionRatio calculation

      // Trait 41 & 42: Track repeated patterns
      if (playerHistory.isSpammingLastMove) {
        final spammedMove = playerHistory.lastMove;
        if (spammedMove != null) {
          if (spammedMove.category == MoveCategory.status ||
              spammedMove.baseDamage == 0) {
            // Trait 47: Punish greedy play (Spamming setup)
            if (move.priority > 0 && canKO) {
              score += 200; // Snipe them!
            } else if (move.effects.any(
              (e) =>
                  e.type == MoveEffectType.statusPoison ||
                  e.type == MoveEffectType.statusBurn,
            )) {
              score += 100; // Status them while they setup
            }
          } else {
            // They are spamming an attack. Try to protect or resist.
            final typeMatchup = TypeChart.getEffectiveness(
              spammedMove.type,
              attacker.types.first,
            );
            if (typeMatchup < 1.0 && move.name == 'Protect') {
              score += 80;
            }
          }
        }
      }

      // Trait 43: Detect aggressive player
      if (aggression > 0.8) {
        // They attack non-stop. Setup moves are dangerous unless we outspeed.
        if (move.category == MoveCategory.status && !isFaster) {
          score -= 50;
        }
        // Trait 46: Bait setup (If we are a wall against an aggressive player, use protect)
        if (move.name == 'Protect' && attacker.currentDefense > 100) {
          score += 40;
        }
      }
      // Trait 44: Detect defensive player
      else if (aggression < 0.3) {
        // They stall/setup. Priority moves to break setup, or massive damage.
        if (move.baseDamage > 90) {
          score += 40; // Break the wall!
        }
        if (move.name == 'Taunt' || move.name == 'Encore') {
          score += 200; // Taunt defensive players!
        }
      }

      // Trait 49 & 50: Dynamic Aggression adjustments
      if (aiTeam != null && playerTeam != null) {
        int aiAlive = aiTeam.where((m) => m.health > 0).length;
        int playerAlive = playerTeam.where((m) => m.health > 0).length;

        if (aiAlive < playerAlive) {
          // Trait 49: Increase aggression when behind
          // Weight raw damage more, ignore risk penalties
          if (move.baseDamage > 0) score += 40;
        } else if (aiAlive > playerAlive) {
          // Trait 50: Play safe when ahead
          // Highly penalize inaccurate moves and recoil.
          if (accuracy < 1.0) score -= (1.0 - accuracy) * 200;
        }
      }
    }

    // ──────────────────────────────────────────────
    // Trait 7: Risk vs reward scoring
    // ──────────────────────────────────────────────
    // Recoil
    if (move.recoilPercent > 0) {
      if (canKO) {
        // High reward, it's fine.
      } else if (attackerHpRatio < 0.3) {
        score -=
            100; // Too risky, the recoil might kill us without achieving a KO
      } else {
        score -=
            move.recoilPercent * 50; // Standard penalty for hurting oneself
      }
    }

    // Recharge (Hyper Beam equivalents)
    if (move.effects.any((e) => e.type == MoveEffectType.recharge)) {
      if (!canKO) {
        score -=
            80; // Giving the opponent a free turn is very bad unless it guarantees a KO
      }
    }

    // Multi-turn charge moves (Solar Beam equivalents)
    if (move.effects.any((e) => e.type == MoveEffectType.charge)) {
      if (isSurvivalRisky) {
        score -= 100; // We might die before the charge finishes
      } else {
        score -= 30; // Inherently risky
      }
    }

    // ──────────────────────────────────────────────
    // Move Diversity: Penalize repeating the same move
    // ──────────────────────────────────────────────
    if (lastUsedMoves != null && lastUsedMoves.isNotEmpty) {
      final recentCount = lastUsedMoves.where((m) => m == move.name).length;
      if (recentCount >= 3) {
        score -= 300; // Strong spam penalty
      } else if (recentCount == 2) {
        score -= 120;
      } else if (recentCount == 1 && lastUsedMoves.last == move.name) {
        score -= 40; // Small discourage for direct repeat
      }
    }

    // ──────────────────────────────────────────────
    // Ability Synergy Scoring
    // ──────────────────────────────────────────────
    final hasIronFist = attacker.abilities.any((ab) => ab.name == 'Iron Fist');
    final hasStrongJaw = attacker.abilities.any(
      (ab) => ab.name == 'Strong Jaw',
    );
    final hasToughClaws = attacker.abilities.any(
      (ab) => ab.name == 'Tough Claws',
    );
    final hasSuperLuck = attacker.abilities.any(
      (ab) => ab.name == 'Super Luck',
    );
    final hasInfiltrator = attacker.abilities.any(
      (ab) => ab.name == 'Infiltrator',
    );
    final hasUnseenFist = attacker.abilities.any(
      (ab) => ab.name == 'Unseen Fist',
    );

    if (move.isPunch && hasIronFist) score += 30;
    if (move.isBite && hasStrongJaw) score += 40;
    if (move.isContact && hasToughClaws) score += 35;
    if (hasSuperLuck && move.baseDamage > 0) score += 20;

    if (hasInfiltrator &&
        (targetHasReflect || targetHasLightScreen || targetHasAuroraVeil)) {
      score += 150;
    }

    if (hasUnseenFist && move.isContact && defender.isProtected) {
      score += 200;
    }

    // Apply a small random jitter to prevent completely deterministic behavior
    score += Random().nextDouble() * 10.0;

    // ──────────────────────────────────────────────
    // Team Archetype Scoring — Deep Behavioral Logic
    // ──────────────────────────────────────────────
    final isStabMove = attacker.types.contains(move.type);
    final dealsBigDamage = expectedDamage > defender.maxHealth * 0.5;

    switch (archetype) {
      // ── Hyper Offense: Always attack hard. STAB & coverage win. ──
      case TeamArchetype.hyperOffense:
        if (move.baseDamage > 0) {
          score += 80;
          if (isStabMove) score += 40;
          if (dealsBigDamage) score += 60;
          if (typeMultiplier > 1.5) score += 80;
        }
        // Setup is almost always wrong for HO
        if (move.category == MoveCategory.status) score -= 180;
        if (move.effects.any(
              (e) => e.type == MoveEffectType.statChange && e.target == 'self',
            ) &&
            (isSurvivalRisky ||
                attacker.attackStage > 0 ||
                attacker.powerStage > 0)) {
          score -= 150;
        }
        break;

      // ── Stall: Protect/Toxic/Heal loop. Only attack for KOs. ──
      case TeamArchetype.stall:
        if (move.name == 'Protect' ||
            move.name == 'Spiky Shield' ||
            move.name == 'Detect') {
          score += 150;
          if (opponentHasFatalStatus) {
            score += 80; // Even better to stall with status ticking
          }
        }
        if (move.effects.any(
          (e) =>
              e.type == MoveEffectType.statusPoison ||
              e.type == MoveEffectType.statusBurn,
        )) {
          score += defender.statusEffects.isEmpty ? 140 : -60;
        }
        if (move.effects.any((e) => e.type == MoveEffectType.heal)) {
          if (attackerHpRatio < 0.25) {
            score += 200;
          } else if (attackerHpRatio < 0.5) {
            score += 100;
          } else {
            score -= 60;
          }
        }
        if (move.baseDamage > 0 && !canKO) score -= 80;
        if (canKO) score += 120;
        break;

      // ── Balanced: Slight STAB bonus, no major skew. ──
      case TeamArchetype.balanced:
        if (isStabMove && move.baseDamage > 0) score += 20;
        if (move.category == MoveCategory.status && move.baseDamage == 0) {
          score += 15;
        }
        break;

      // ── Status Spread: Smart status targeting. ──
      case TeamArchetype.statusSpread:
        final isAnyStatus = move.effects.any(
          (e) =>
              e.type == MoveEffectType.statusPoison ||
              e.type == MoveEffectType.statusBurn ||
              e.type == MoveEffectType.statusParalysis ||
              e.type == MoveEffectType.statusBleed,
        );
        if (isAnyStatus) {
          score += defender.statusEffects.isEmpty ? 220 : -80;
          // Burn is better on physical attackers, poison on tanks
          final defIsPhysical = defender.currentAttack > defender.currentPower;
          if (move.effects.any((e) => e.type == MoveEffectType.statusBurn) &&
              defIsPhysical &&
              defender.statusEffects.isEmpty) {
            score += 60;
          }
          if (move.effects.any((e) => e.type == MoveEffectType.statusPoison) &&
              !defIsPhysical &&
              defender.statusEffects.isEmpty) {
            score += 60;
          }
        }
        break;

      // ── Rain: Set rain immediately; then spam Aquatic moves. ──
      case TeamArchetype.rainTeam:
        final rainActive =
            currentEffect.weather == Weather.rain ||
            currentEffect.weather == Weather.heavyRain;
        if (!rainActive) {
          if (move.effects.any(
            (e) => e.stat == 'rain' || e.stat == 'heavyrain',
          )) {
            score += 400;
          }
        } else {
          if (move.type == ElementalType.aquatic) score += 80;
          if (move.name == 'Thunder' || move.name == 'Hurricane') score += 60;
          if (move.type == ElementalType.blaze) score -= 60;
        }
        break;
      case TeamArchetype.psychicTerrainAbuser:
        final psychicTerrainActive = currentTerrain.terrain == Terrain.psychic;
        if (!psychicTerrainActive) {
          if (move.effects.any((e) => e.stat == 'psychic')) score += 400;
        } else {
          if (move.type == ElementalType.aura) score += 80;
          if (move.name == 'Psychic' ||
              move.name == 'Psyshock' ||
              move.name == 'Expanding Force') {
            score += 60;
          }
          if (move.type == ElementalType.basic) score -= 60;
        }
        break;
      case TeamArchetype.electricTerrainAbuser:
        final electricTerrainActive =
            currentTerrain.terrain == Terrain.electric;
        if (!electricTerrainActive) {
          if (move.effects.any((e) => e.stat == 'electric')) score += 400;
        } else {
          if (move.type == ElementalType.aura) score += 80;
          if (move.name == 'Thunderbolt' ||
              move.name == 'Thunder' ||
              move.name == 'Volt Switch') {
            score += 60;
          }
          if (move.type == ElementalType.earth) score -= 60;
        }
        break;
      // ── Sun: Set sun immediately; then spam Blaze moves. ──
      case TeamArchetype.sunTeam:
        final sunActive = currentEffect.weather == Weather.sunny;
        if (!sunActive) {
          if (move.effects.any((e) => e.stat == 'sunny' || e.stat == 'sun')) {
            score += 400;
          }
        } else {
          if (move.type == ElementalType.blaze) score += 80;
          if (move.name == 'Solar Beam' || move.name == 'Solar Blade') {
            score += 80;
          }
          if (move.type == ElementalType.aquatic) score -= 60;
        }
        break;

      // ── Sand: Set sandstorm; Rock/Earth/Metal STAB exploiters. ──
      case TeamArchetype.sandTeam:
        final sandActive = currentEffect.weather == Weather.sandstorm;
        if (!sandActive) {
          if (move.effects.any((e) => e.stat == 'sandstorm')) score += 400;
        } else {
          if (move.type == ElementalType.rock ||
              move.type == ElementalType.earth ||
              move.type == ElementalType.metal) {
            score += 60;
          }
          if (move.name == 'Shore Up') score += 80;
        }
        break;

      // ── Snow: Set snow/hail; Cryo STAB + Aurora Veil. ──
      case TeamArchetype.snowTeam:
        final snowActive =
            currentEffect.weather == Weather.snowstorm ||
            currentEffect.weather == Weather.hail;
        if (!snowActive) {
          if (move.effects.any(
            (e) => e.stat == 'snowstorm' || e.stat == 'hail',
          )) {
            score += 400;
          }
        } else {
          if (move.type == ElementalType.cryo) score += 80;
          if (move.name == 'Aurora Veil') score += 120;
          if (move.name == 'Blizzard') score += 60;
        }
        break;

      // ── Hazard Stacker: Stack all hazards; then play offense. ──
      case TeamArchetype.hazardStacker:
        final allHazardsSet =
            targetHazards.contains('spikes') &&
            targetHazards.contains('stealthRock');
        if (!allHazardsSet) {
          if (move.effects.any((e) => e.type == MoveEffectType.setHazard)) {
            final hazardStat = move.effects
                .firstWhere(
                  (e) => e.type == MoveEffectType.setHazard,
                  orElse: () => move.effects.first,
                )
                .stat;
            score += targetHazards.contains(hazardStat) ? -500 : 350;
          }
        } else {
          if (move.baseDamage > 0) score += 60;
          if (isStabMove) score += 30;
        }
        break;

      // ── Anti-Hazard: Clear our hazards as top priority, then attack. ──
      case TeamArchetype.antiHazard:
        if (move.name == 'Rapid Spin' ||
            move.name == 'Defog' ||
            move.name == 'Mortal Spin') {
          // Only massively boost if there are hazards to clear
          score += targetHazards.isNotEmpty ? 9999 : -200;
        }
        if (targetHazards.isEmpty && move.baseDamage > 0) score += 60;
        break;

      // ── Revenge Killer: Priority moves for clean KOs. ──
      case TeamArchetype.revengeKiller:
        if (attackerHpRatio > 0.8) {
          if (move.priority > 0 && canKO) score += 250;
          if (move.baseDamage > 80 && typeMultiplier >= 1.0) score += 80;
        } else {
          if (canKO) score += 150;
          if (move.priority > 0) score += 100;
        }
        if (move.category == MoveCategory.status && move.baseDamage == 0) {
          score -= 120;
        }
        break;

      // ── Defensive Core: Bulk up, heal, never recoil. ──
      case TeamArchetype.defensiveCore:
        if (move.effects.any(
          (e) =>
              e.type == MoveEffectType.statChange &&
              e.target == 'self' &&
              (e.stat == 'defense' || e.stat == 'resistance'),
        )) {
          score += isSurvivalRisky ? -40 : 160;
        }
        if (move.effects.any((e) => e.type == MoveEffectType.heal)) {
          if (attackerHpRatio < 0.5) {
            score += 200;
          } else if (attackerHpRatio < 0.75) {
            score += 80;
          } else {
            score -= 80;
          }
        }
        if (move.recoilPercent > 0) score -= 120;
        if (canKO) score += 80;
        break;

      // ── Setup Sweeper: Two-phase: setup then sweep. ──
      case TeamArchetype.setupSweeper:
        final inSetupPhase =
            attacker.attackStage < 2 &&
            attacker.powerStage < 2 &&
            attacker.speedStage < 2;
        if (inSetupPhase) {
          if (move.effects.any(
            (e) =>
                e.type == MoveEffectType.statChange &&
                e.target == 'self' &&
                (e.stat == 'attack' || e.stat == 'power' || e.stat == 'speed'),
          )) {
            score += isSurvivalRisky ? -100 : 250;
          }
          if (move.baseDamage > 0 && !canKO) score -= 60;
          if (canKO) score += 100;
        } else {
          // Sweep phase: attack hard with STAB
          if (move.baseDamage > 0) score += 100;
          if (isStabMove) score += 60;
          if (dealsBigDamage) score += 80;
          if (move.category == MoveCategory.status) score -= 100;
        }
        break;

      // ── Trick Room: Set TR then sweep with slow heavyweights. ──
      case TeamArchetype.trickRoom:
        // If we have Trick Room in our moveset, it's the #1 priority if not yet set
        final hasTRMove = attacker.organism.selectedMoveNames.contains(
          'Trick Room',
        );
        if (hasTRMove && move.name == 'Trick Room') {
          if (!isTrickRoomActive) {
            // Trick Room flips speed. If we are already faster, using Trick Room
            // will make us move last, which is bad!
            if (isFaster) {
              score -= 500; // Very bad idea
            } else {
              score += 500; // Always try to set TR first turn if slower
            }
          } else {
            score -= 600; // Don't turn it off if we are a TR team!
          }
        }
        // Under TR, slow mons are "fast" — prize heavy-damage moves
        if (move.baseDamage > 0) score += 80;
        if (move.baseDamage > 100) score += 60;
        if (isStabMove) score += 40;
        if (dealsBigDamage) score += 80;
        // Don't bother with priority moves under TR
        if (move.priority > 0) score -= 60;
        // Status moves are only good on the setup turn
        if (move.category == MoveCategory.status && move.name != 'Trick Room') {
          score -= 60;
        }
        break;

      case TeamArchetype.tailwindSpeed:
        final hasTailwind = attacker.organism.selectedMoveNames.contains(
          'Tailwind',
        );
        if (hasTailwind && move.name == 'Tailwind') {
          if (isTailwindActive) {
            score -= 600; // Already active — don't waste the turn
          } else {
            score += 500; // Not yet active — top priority
          }
        }
        if (move.baseDamage > 0) score += 40;
        if (isTailwindActive) {
          score += 60; // Under tailwind, offense is rewarded
        }
        if (isFaster) score += 40;
        break;

      case TeamArchetype.dualScreens:
        if (move.name == 'Reflect') {
          score += targetHasReflect ? -600 : 400;
        } else if (move.name == 'Light Screen') {
          score += targetHasLightScreen ? -600 : 400;
        } else if (move.name == 'Aurora Veil') {
          score += targetHasAuroraVeil ? -600 : 500; // Highest priority if snow
        }
        // Once both main screens are up, attack!
        if (targetHasReflect && targetHasLightScreen && move.baseDamage > 0) {
          score += 80;
        }
        if (move.baseDamage > 0) score += 30;
        break;

      case TeamArchetype.prioritySweeper:
        if (move.priority > 0) {
          score += 150;
          if (canKO) score += 200;
        }
        if (move.baseDamage > 80) score += 40;
        break;

      case TeamArchetype.perishTrapper:
        if (move.name == 'Perish Song') score += 500;
        if (move.effects.any((e) => e.type == MoveEffectType.trapIndices)) {
          score += 300;
        }
        if (move.name == 'Protect') score += 100;
        break;

      case TeamArchetype.gimmickyAssist:
        if (move.name == 'Metronome' ||
            move.name == 'Assist' ||
            move.name == 'Copycat') {
          score += 500;
        }
        score += Random().nextDouble() * 50; // Extra chaos
        break;

      case TeamArchetype.criticalFocus:
        if (move.critRate > 0) score += 100;
        if (move.name == 'Focus Energy') score += 200;
        break;

      case TeamArchetype.recoilReckless:
        if (move.recoilPercent > 0) score += 150;
        if (move.baseDamage > 100) score += 80;
        break;

      case TeamArchetype.restLoop:
        if (move.name == 'Rest') {
          if (attackerHpRatio < 0.4) {
            score += 400;
          } else {
            score -= 100;
          }
        }
        if (move.name == 'Sleep Talk' || move.name == 'Snore') {
          final isAsleep = attacker.statusEffects.any(
            (se) => se.type == StatusEffectType.sleep,
          );
          score += isAsleep ? 500 : -100;
        }
        break;

      case TeamArchetype.evasionBuffer:
        if (move.name == 'Double Team' || move.name == 'Minimize') score += 300;
        if (move.baseDamage > 0 && canKO) score += 100;
        break;

      case TeamArchetype.bulkyBruiser:
        if (move.baseDamage > 80) score += 60;
        if (attacker.maxHealth > 120) score += 30;
        if (move.priority > 0) score += 40;
        break;

      case TeamArchetype.toxicStall:
        if (move.name == 'Toxic') score += 300;
        if (move.name == 'Protect') score += 200;
        if (move.effects.any((e) => e.type == MoveEffectType.heal)) {
          score += 150;
        }
        break;
    }

    // ──────────────────────────────────────────────
    // Trait 11: Held Item Synergy
    // ──────────────────────────────────────────────
    final item = attacker.organism.equippedTalisman;
    if (item != null && !attacker.talismanConsumed) {
      final itemName = item.name;

      // Choice Item Strategy
      final isChoiceItem = itemName.contains('Choice');
      if (isChoiceItem) {
        // If we are about to be locked into a move, ensure it's a good one.
        if (!attacker.isChoiceLocked) {
          if (move.category == MoveCategory.status) {
            score -= 400; // Heavily penalize locking into a status move
          }
          if (typeMultiplier < 1.0) {
            score -= 150; // Penalize locking into a resisted move
          }
          if (canKO) {
            score += 100; // Excellent to lock into a KO move
          }
        }
      }

      // Life Orb Recoil Awareness
      if (itemName == 'Life Orb' && move.category != MoveCategory.status) {
        final recoil = attacker.maxHealth * 0.1;
        if (attacker.health <= recoil) {
          score -= 300; // Don't suicide if we can help it
        } else if (isSurvivalRisky) {
          score -= 50; // Be more cautious
        }
      }

      // Focus Sash Aggression
      if (itemName == 'Focus Sash' && attackerHpRatio > 0.99) {
        // We can survive a hit. Be slightly more aggressive.
        if (canKO) {
          score += 150;
        } else {
          score += 30;
        }
      }

      // Weather/Terrain Extension
      final isDurationExtender =
          itemName.endsWith(' Rock') || itemName == 'Terrain Extender';
      if (isDurationExtender) {
        final hasWeatherEffect = move.effects.any(
          (e) => e.type == MoveEffectType.weather,
        );
        final hasTerrainEffect = move.effects.any(
          (e) => e.type == MoveEffectType.terrain,
        );
        if (hasWeatherEffect || hasTerrainEffect) {
          score += 200; // High priority to setup with extension item
        }
      }

      // Power Herb Synergy (Multi-turn moves skip charge)
      if (itemName == 'Power Herb' && move.isMultiTurn) {
        score += 300; // Great synergy
      }

      // Assault Vest (Heuristic)
      if (itemName == 'Assault Vest' && move.category == MoveCategory.status) {
        score -= 1000;
      }
    }

    return score;
  }

  /// Evaluates whether the AI should switch its active organism based on Traits 11-20.
  static SwitchDecision shouldSwitch({
    required BattleOrganism activeMon,
    required List<BattleOrganism> bench,
    required BattleOrganism opponent,
    required List<String> playerHazards,
    PlayerHistory? playerHistory,
    TeamArchetype archetype = TeamArchetype.balanced,
    // Provide a callback to estimate damage from opponent to our mon
    required double Function(BattleOrganism attacker, BattleOrganism defender)
    estimateOpponentDamage,
    required double Function(BattleOrganism attacker, BattleOrganism defender)
    estimateOurDamage,
  }) {
    if (bench.isEmpty) return SwitchDecision(false, null);

    // Cannot switch if locked into Rollout/Ice Ball, recharging, or semi-invulnerable
    if (activeMon.rolloutTurnCount > 0 ||
        activeMon.mustRecharge ||
        activeMon.semiInvulnerable != null ||
        activeMon.isInvulnerable ||
        activeMon.chargingMove != null) {
      return SwitchDecision(false, null);
    }

    final activeHpRatio = activeMon.health / activeMon.maxHealth;
    final opponentExpectedDmg = estimateOpponentDamage(opponent, activeMon);
    final isFacingOHKO = opponentExpectedDmg >= activeMon.health;
    final isSlower = activeMon.currentSpeed < opponent.currentSpeed;
    final ourExpectedDmg = estimateOurDamage(activeMon, opponent);

    // Baseline: Are we doing okay?
    bool forcedToSwitch = false;

    // Trait 11 & 12: Switch on bad matchup / likely OHKO
    if (isFacingOHKO && isSlower) {
      forcedToSwitch = true; // We will die before moving. Need to switch.
    } else if (ourExpectedDmg < opponent.health * 0.15 &&
        opponentExpectedDmg > activeMon.maxHealth * 0.15) {
      // Bad matchup: We do very little, they hit us hard.
      forcedToSwitch = true;
    }

    // Trait 45: Predict switch on bad matchup
    if (playerHistory != null && !forcedToSwitch) {
      // If the player is in a terrible matchup against us, AND they have a history of switching
      final playerExpectedDmg = estimateOpponentDamage(opponent, activeMon);
      final ourDmgOnPlayer = estimateOurDamage(activeMon, opponent);
      final playerIsDoomed =
          ourDmgOnPlayer >= opponent.health ||
          (playerExpectedDmg < activeMon.health * 0.1 &&
              ourDmgOnPlayer > opponent.maxHealth * 0.4);

      int switchCount = playerHistory.actions.where((a) => a.isSwitch).length;
      if (playerIsDoomed && switchCount > 0) {
        // We expect the player to switch.
        // If we also want to switch (maybe to gain momentum), do it!
        // (This encourages double-switching)
        if (bench.any((b) => b.currentSpeed > activeMon.currentSpeed)) {
          forcedToSwitch =
              true; // Let's grab momentum by switching our slow mon to a fast one.
        }
      }
    }

    // Trait 14 & 20: Preserve low-HP win condition / Late-game cleaner
    bool isWinCondition =
        (activeMon.currentSpeed > 100 || activeMon.currentAttack > 100) &&
        activeMon.level >= 20; // Heuristic
    if (isWinCondition && activeHpRatio < 0.3 && isFacingOHKO) {
      // Don't throw away our sweeper
      forcedToSwitch = true;
    }

    // Trait 19: Sacrifice weakest member when necessary
    // If we are forced to switch, but a VERY powerful hit is coming,
    // sometimes it's better to let the current mon die to bring in the counter safely,
    // UNLESS the current mon is our win condition.
    if (forcedToSwitch && opponentExpectedDmg > activeMon.maxHealth * 0.8) {
      if (!isWinCondition && activeHpRatio < 0.2) {
        // Just let it die, save the bench taking massive damage on entry.
        return SwitchDecision(false, null);
      }
    }

    if (!forcedToSwitch) {
      // Check for Trait 18: Pivot usage (this would be handled in move selection natively if they have U-turn,
      // but if the user wants hard switching, we don't switch unless forced).
      return SwitchDecision(false, null);
    }

    // --- We decided we WANT to switch. Now pick the best bench member. ---
    int? bestBenchIndex;
    double bestBenchScore = -double.infinity;

    for (int i = 0; i < bench.length; i++) {
      final bMon = bench[i];
      if (bMon.health <= 0) continue;

      double score = 0;
      final bMonHpRatio = bMon.health / bMon.maxHealth;

      // Trait 13: Switch to type counter
      // Estimate how much damage the opponent will do to this bench member
      final incomingDmgToBMon = estimateOpponentDamage(opponent, bMon);
      final outgoingDmgFromBMon = estimateOurDamage(bMon, opponent);

      if (incomingDmgToBMon < bMon.maxHealth * 0.3) {
        score += 50; // Resists
      } else if (incomingDmgToBMon >= bMon.health) {
        score -= 200; // Will be OHKOed on entry
      }

      if (outgoingDmgFromBMon > opponent.maxHealth * 0.5) {
        score += 50; // Can hit back hard
      }

      // Trait 15: Avoid switching into hazards
      if (playerHazards.isNotEmpty) {
        // Rough heuristic: rock weakness
        final rockEffectiveness = TypeChart.getEffectiveness(
          ElementalType
              .rock, // Assuming Stealth Rock is Earth/Rock type equivalent in this game
          bMon.types.first,
        );
        if (rockEffectiveness > 1.0) score -= 40;
        if (bMonHpRatio < 0.25) score -= 80;
      }

      // Trait 16 & 17: Predict opponent switch / Double-switch
      // If the incoming pokemon forces them out, add score.
      if (outgoingDmgFromBMon >= opponent.health &&
          bMon.currentSpeed > opponent.currentSpeed) {
        score += 30;
      }

      if (score > bestBenchScore) {
        bestBenchScore = score;
        bestBenchIndex = i;
      }
    }

    if (bestBenchIndex != null && bestBenchScore > -100) {
      return SwitchDecision(true, bestBenchIndex);
    }

    return SwitchDecision(false, null);
  }

  // --- Team Evaluation Helpers (Traits 21-25) ---

  /// Identifies the "sweeper" or primary win condition of a team.
  /// Heuristic: Highest combined Speed + Attack/Power.
  static BattleOrganism? identifyWinCondition(List<BattleOrganism>? team) {
    if (team == null || team.isEmpty) return null;
    BattleOrganism? bestSweeper;
    double highestOffensiveScore = -1;

    for (final mon in team) {
      if (mon.health <= 0) continue;
      // Evaluate mixed offense potential + speed
      double offenseScore =
          mon.currentSpeed.toDouble() +
          max(mon.currentAttack, mon.currentPower).toDouble();

      // Bonus if it has a stat-boosting move
      if (mon.organism.selectedMoveNames.any(
        (m) =>
            m.toLowerCase().contains('dance') ||
            m.toLowerCase().contains('plot'),
      )) {
        offenseScore *= 1.2;
      }

      if (offenseScore > highestOffensiveScore) {
        highestOffensiveScore = offenseScore;
        bestSweeper = mon;
      }
    }
    return bestSweeper;
  }

  /// Identifies the "wall" or primary defensive anchor of a team.
  /// Heuristic: Highest combined Health + Defense + Resistance.
  static BattleOrganism? identifyWall(List<BattleOrganism>? team) {
    if (team == null || team.isEmpty) return null;
    BattleOrganism? bestWall;
    double highestDefensiveScore = -1;

    for (final mon in team) {
      if (mon.health <= 0) continue;
      double defensiveScore =
          mon.maxHealth.toDouble() + mon.currentDefense + mon.currentResistance;

      // Bonus if it has healing or protection
      if (mon.organism.selectedMoveNames.any(
        (m) => m == 'Recover' || m == 'Roost' || m == 'Protect',
      )) {
        defensiveScore *= 1.3;
      }

      if (defensiveScore > highestDefensiveScore) {
        highestDefensiveScore = defensiveScore;
        bestWall = mon;
      }
    }
    return bestWall;
  }
}

class SwitchDecision {
  final bool shouldSwitch;
  final int? bestBenchIndex;

  SwitchDecision(this.shouldSwitch, this.bestBenchIndex);
}
