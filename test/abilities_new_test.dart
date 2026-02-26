import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/ability.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock platform channels for audioplayers
  const MethodChannel(
    'xyz.luan/audioplayers',
  ).setMockMethodCallHandler((call) async => null);
  const MethodChannel(
    'xyz.luan/audioplayers.global',
  ).setMockMethodCallHandler((call) async => null);

  final base = Organism(
    name: 'Test',
    scientificName: 'Testus testus',
    habitat: 'Forest',
    drops: '',
    attack: 100,
    defense: 100,
    power: 100,
    resistance: 100,
    health: 200,
    speed: 100,
    abilities: '',
    category: 'Test',
    moves: '',
    sprite: '',
    rarity: 'Common',
    description: 'Test',
  );

  group('New Abilities Tests', () {
    test('Iron Fist boosts punching moves', () async {
      const punchMove = Move(
        name: 'Punch',
        description: 'Punches.',
        baseDamage: 50,
        type: ElementalType.basic,
        accuracy: 100,
        stamina: 10,
        category: MoveCategory.physical,
        isPunch: true,
      );

      final ironFist = Ability(
        name: 'Iron Fist',
        description: 'Boosts punch.',
        trigger: AbilityTrigger.onCalculateDamage,
        effectType: AbilityEffectType.statMultiplier,
        magnitude: 1.2,
      );

      final ivs = {
        'health': 31,
        'attack': 31,
        'defense': 31,
        'power': 31,
        'resistance': 31,
        'speed': 31,
      };
      final attacker = CapturedOrganism.spawn(base, level: 50, ivs: ivs);
      final defender = CapturedOrganism.spawn(base, level: 50, ivs: ivs);

      attacker.moveStamina[punchMove.name] = 10;
      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.ignoreRandom = true;
      manager.currentState = BattleState.waitingForInput;

      // Without Iron Fist
      await manager.processPlayerAction(punchMove);
      final damageWithout = defender.maxHealth - defender.health;

      // With Iron Fist
      defender.health = defender.maxHealth;
      manager.player.abilities.clear();
      manager.player.abilities.add(ironFist);
      await manager.processPlayerAction(punchMove);
      final damageWith = defender.maxHealth - defender.health;

      expect(damageWith, greaterThan(damageWithout));
      expect((damageWith.toDouble() / damageWithout), closeTo(1.2, 0.15));
    });

    test('Strong Jaw boosts biting moves', () async {
      const biteMove = Move(
        name: 'Bite',
        description: 'Bites.',
        baseDamage: 50,
        type: ElementalType.basic,
        accuracy: 100,
        stamina: 10,
        category: MoveCategory.physical,
        isBite: true,
      );

      final strongJaw = Ability(
        name: 'Strong Jaw',
        description: 'Boosts bite.',
        trigger: AbilityTrigger.onCalculateDamage,
        effectType: AbilityEffectType.statMultiplier,
        magnitude: 1.5,
      );

      final ivs = {
        'health': 31,
        'attack': 31,
        'defense': 31,
        'power': 31,
        'resistance': 31,
        'speed': 31,
      };
      final attacker = CapturedOrganism.spawn(base, level: 50, ivs: ivs);
      final defender = CapturedOrganism.spawn(base, level: 50, ivs: ivs);

      attacker.moveStamina[biteMove.name] = 10;
      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.ignoreRandom = true;
      manager.currentState = BattleState.waitingForInput;

      // Without Strong Jaw
      await manager.processPlayerAction(biteMove);
      final damageWithout = defender.maxHealth - defender.health;

      // With Strong Jaw
      defender.health = defender.maxHealth;
      manager.player.abilities.clear();
      manager.player.abilities.add(strongJaw);
      await manager.processPlayerAction(biteMove);
      final damageWith = defender.maxHealth - defender.health;

      expect(damageWith, greaterThan(damageWithout));
      expect((damageWith.toDouble() / damageWithout), closeTo(1.5, 0.2));
    });

    test('Tough Claws boosts contact moves', () async {
      const contactMove = Move(
        name: 'Claw',
        description: 'Claws.',
        baseDamage: 50,
        type: ElementalType.basic,
        accuracy: 100,
        stamina: 10,
        category: MoveCategory.physical,
        isContact: true,
      );

      final toughClaws = Ability(
        name: 'Tough Claws',
        description: 'Boosts contact.',
        trigger: AbilityTrigger.onCalculateDamage,
        effectType: AbilityEffectType.statMultiplier,
        magnitude: 1.3,
      );

      final ivs = {
        'health': 31,
        'attack': 31,
        'defense': 31,
        'power': 31,
        'resistance': 31,
        'speed': 31,
      };
      final attacker = CapturedOrganism.spawn(base, level: 50, ivs: ivs);
      final defender = CapturedOrganism.spawn(base, level: 50, ivs: ivs);

      attacker.moveStamina[contactMove.name] = 10;
      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.ignoreRandom = true;
      manager.currentState = BattleState.waitingForInput;

      // Without Tough Claws
      await manager.processPlayerAction(contactMove);
      final damageWithout = defender.maxHealth - defender.health;

      // With Tough Claws
      defender.health = defender.maxHealth;
      manager.player.abilities.clear();
      manager.player.abilities.add(toughClaws);
      await manager.processPlayerAction(contactMove);
      final damageWith = defender.maxHealth - defender.health;

      expect(damageWith, greaterThan(damageWithout));
      expect((damageWith.toDouble() / damageWithout), closeTo(1.3, 0.15));
    });

    test('Infiltrator bypasses Reflect', () async {
      const move = Move(
        name: 'Strike',
        description: 'Strikes.',
        baseDamage: 50,
        type: ElementalType.basic,
        accuracy: 100,
        stamina: 10,
        category: MoveCategory.physical,
      );

      final infiltrator = Ability(
        name: 'Infiltrator',
        description: 'Bypasses screens.',
        trigger: AbilityTrigger.onCalculateDamage,
        effectType: AbilityEffectType.none,
      );

      final ivs = {
        'health': 31,
        'attack': 31,
        'defense': 31,
        'power': 31,
        'resistance': 31,
        'speed': 31,
      };
      final attacker = CapturedOrganism.spawn(base, level: 50, ivs: ivs);
      final defender = CapturedOrganism.spawn(base, level: 50, ivs: ivs);

      attacker.moveStamina[move.name] = 10;
      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.ignoreRandom = true;
      manager.currentState = BattleState.waitingForInput;
      manager.opponentReflectTurns = 5;

      // Without Infiltrator
      await manager.processPlayerAction(move);
      final damageWithReflect = defender.maxHealth - defender.health;

      // With Infiltrator
      defender.health = defender.maxHealth;
      manager.player.abilities.add(infiltrator);
      await manager.processPlayerAction(move);
      final damageWithInfiltrator = defender.maxHealth - defender.health;

      expect(damageWithInfiltrator, greaterThan(damageWithReflect));
      expect(
        (damageWithInfiltrator.toDouble() / damageWithReflect),
        closeTo(2.0, 0.3),
      );
    });

    test('Unseen Fist bypasses Protect', () async {
      const contactMove = Move(
        name: 'Contact Strike',
        description: 'Strikes.',
        baseDamage: 50,
        type: ElementalType.basic,
        accuracy: 100,
        stamina: 10,
        category: MoveCategory.physical,
        isContact: true,
      );

      final unseenFist = Ability(
        name: 'Unseen Fist',
        description: 'Bypasses protect.',
        trigger: AbilityTrigger.onCalculateDamage,
        effectType: AbilityEffectType.none,
      );

      final ivs = {
        'health': 31,
        'attack': 31,
        'defense': 31,
        'power': 31,
        'resistance': 31,
        'speed': 31,
      };
      final attacker = CapturedOrganism.spawn(base, level: 50, ivs: ivs);
      final defender = CapturedOrganism.spawn(base, level: 50, ivs: ivs);

      attacker.moveStamina[contactMove.name] = 10;
      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.ignoreRandom = true;
      manager.currentState = BattleState.waitingForInput;
      manager.opponent.isProtected = true;
      manager.player.abilities.add(unseenFist);

      await manager.processPlayerAction(contactMove);

      expect(defender.health, lessThan(defender.maxHealth));
    });

    test('Super Luck increases crit rate', () async {
      const move = Move(
        name: 'Crit Strike',
        description: 'Crit test.',
        baseDamage: 50,
        type: ElementalType.basic,
        accuracy: 100,
        stamina: 10,
        category: MoveCategory.physical,
      );

      final superLuck = Ability(
        name: 'Super Luck',
        description: 'Increases crit.',
        trigger: AbilityTrigger.onCalculateDamage,
        effectType: AbilityEffectType.none,
      );

      int successes = 0;
      int iterations = 100;

      for (int i = 0; i < iterations; i++) {
        final ivs = {
          'health': 31,
          'attack': 31,
          'defense': 31,
          'power': 31,
          'resistance': 31,
          'speed': 31,
        };
        final attacker = CapturedOrganism.spawn(base, level: 50, ivs: ivs);
        final defender = CapturedOrganism.spawn(base, level: 50, ivs: ivs);
        attacker.moveStamina[move.name] = 10;
        final manager = BattleManager(attacker, defender, isTesting: true);
        manager.currentState = BattleState.waitingForInput;
        manager.player.abilities.add(superLuck);

        await manager.processPlayerAction(move);
        final damage = defender.maxHealth - defender.health;

        // Base damage ~22 at level 50. Max non-crit is ~22. Min crit is ~28.
        if (damage > 23) {
          successes++;
        }
      }

      print('Crits with Super Luck in $iterations runs: $successes');
      expect(successes, greaterThan(0));
    });
    group('AI Synergy Tests', () {
      test('AI prefers Iron Fist moves', () async {
        const normalMove = Move(
          name: 'Normal Strike',
          description: 'Normal.',
          baseDamage: 50,
          type: ElementalType.basic,
          accuracy: 100,
          stamina: 10,
          category: MoveCategory.physical,
        );
        const punchMove = Move(
          name: 'Punch',
          description: 'Punch.',
          baseDamage: 50,
          type: ElementalType.basic,
          accuracy: 100,
          stamina: 10,
          category: MoveCategory.physical,
          isPunch: true,
        );

        final ironFist = Ability(
          name: 'Iron Fist',
          description: 'Boosts punch.',
          trigger: AbilityTrigger.onCalculateDamage,
          effectType: AbilityEffectType.statMultiplier,
          magnitude: 1.2,
        );

        final ivs = {
          'health': 31,
          'attack': 31,
          'defense': 31,
          'power': 31,
          'resistance': 31,
          'speed': 31,
        };
        final attackerOrg = CapturedOrganism.spawn(base, level: 50, ivs: ivs);
        final defenderOrg = CapturedOrganism.spawn(base, level: 50, ivs: ivs);

        attackerOrg.moveStamina[normalMove.name] = 10;
        attackerOrg.moveStamina[punchMove.name] = 10;

        final manager = BattleManager(
          attackerOrg,
          defenderOrg,
          isTesting: true,
        );
        manager.player.abilities.clear();
        manager.player.abilities.add(ironFist);

        final normalScore = manager.scoreMove(
          normalMove,
          manager.player,
          manager.opponent,
        );
        final punchScore = manager.scoreMove(
          punchMove,
          manager.player,
          manager.opponent,
        );

        expect(punchScore, greaterThan(normalScore));
      });
    });
  });
}
