import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'dart:math';

void main() {
  group('New Moves Tests', () {
    late BattleManager manager;
    late CapturedOrganism playerOrg;
    late CapturedOrganism opponentOrg;

    Organism createBase(String name, {int hp = 100, int def = 50}) {
      return Organism(
        name: name,
        scientificName: 'Test',
        habitat: 'Test',
        drops: '',
        attack: 50,
        defense: def,
        power: 50,
        resistance: 50,
        health: hp,
        speed: 50,
        abilities: '',
        category: 'Test',
        moves: '',
        sprite: '',
        rarity: 'Common',
        description: 'Test',
        types: ['basic'],
      );
    }

    CapturedOrganism createCaptured(Organism base, {int level = 50}) {
      return CapturedOrganism(
        baseOrganism: base,
        level: level,
        individualValues: {
          'health': 15,
          'attack': 15,
          'defense': 15,
          'power': 15,
          'resistance': 15,
          'speed': 15,
        },
        currentHealth: base.health,
        selectedMoveNames: [],
      );
    }

    setUp(() {
      playerOrg = createCaptured(createBase('Player'));
      opponentOrg = createCaptured(createBase('Opponent'));
      manager = BattleManager(playerOrg, opponentOrg, isTesting: true);
      manager.ignoreRandom = true;
      manager.player = BattleOrganism(playerOrg);
      manager.opponent = BattleOrganism(opponentOrg, isOpponent: true);
    });

    test('Sacred Sword ignores defense stages', () async {
      final move = Move.findOrCreate('Sacred Sword');
      manager.opponent.defenseStage = 6;

      // Calculate damage with +6 defense
      final dmgWithBoost = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
      );

      manager.opponent.defenseStage = 0;
      final dmgWithoutBoost = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
      );

      expect(
        dmgWithBoost.damage,
        equals(dmgWithoutBoost.damage),
        reason: 'Sacred Sword should ignore defense stages',
      );
    });

    test('Brine doubles power when target HP <= 50%', () async {
      final move = Move.findOrCreate('Brine');

      // Full HP
      final dmgFull = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
        ignoreRandom: true,
      );

      // Half HP
      manager.opponent.health = (manager.opponent.maxHealth * 0.5).floor();
      final dmgHalf = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
        ignoreRandom: true,
      );

      expect(
        dmgHalf.damage,
        greaterThan(dmgFull.damage * 1.5),
        reason: 'Brine should deal significantly more damage at <= 50% HP',
      );
    });

    test('Retaliate doubles damage if teammate fainted last turn', () async {
      final move = Move.findOrCreate('Retaliate');

      // Normal damage
      final dmgNormal = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
        ignoreRandom: true,
      );

      // Fake a faint last turn
      manager.lastPlayerFaintTurn = manager.currentTurn - 1;
      final dmgRetaliate = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
        ignoreRandom: true,
      );

      expect(
        dmgRetaliate.damage,
        equals(dmgNormal.damage * 2),
        reason: 'Retaliate should double damage after a faint',
      );
    });

    test('Laser Focus guarantees crit next turn', () async {
      final move = Move.findOrCreate('Laser Focus');
      final attackMove = Move.findOrCreate(
        'Tackle',
      ); // Default move for testing

      await manager.testApplyMoveEffect(
        manager.player,
        manager.opponent,
        move.effects,
        move,
      );
      expect(
        manager.player.laserFocusTurns,
        equals(2),
      ); // Should be set to 2 to last through next turn

      final res = manager.calculateDamage(
        manager.player,
        manager.opponent,
        attackMove,
      );
      expect(
        res.isCrit,
        isTrue,
        reason: 'Laser Focus should guarantee a critical hit',
      );
    });

    test('Brick Break shatters screens', () async {
      final move = Move.findOrCreate('Brick Break');
      manager.opponentReflectTurns = 5;
      manager.opponentLightScreenTurns = 5;

      await manager.testExecuteTurn(manager.player, manager.opponent, move);

      expect(manager.opponentReflectTurns, equals(0));
      expect(manager.opponentLightScreenTurns, equals(0));
    });

    test('Scale Shot multi-hits and modifies stats', () async {
      final move = Move.findOrCreate('Scale Shot');

      // Mocking Random for multi-hit
      // Scale Shot is at least 2 hits.
      await manager.testExecuteTurn(manager.player, manager.opponent, move);

      expect(manager.player.defenseStage, equals(-1));
      expect(manager.player.speedStage, equals(1));
    });

    test('Thrash locks user and confuses after 2-3 turns', () async {
      final move = Move.findOrCreate('Thrash');

      await manager.testExecuteTurn(manager.player, manager.opponent, move);
      expect(manager.player.thrashTurnCount, greaterThan(0));
      expect(manager.player.thrashMove?.name, equals('Thrash'));

      final validMoves = manager.getValidMoves(manager.player);
      expect(validMoves.length, equals(1));
      expect(validMoves.first.name, equals('Thrash'));
    });
  });
}
