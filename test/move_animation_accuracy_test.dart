import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AudioService.isTesting = true;

    // Register a standard test move with 100% accuracy
    Move.addTestMove(
      const Move(
        name: 'Perfect Hit',
        baseDamage: 40,
        category: MoveCategory.physical,
        type: ElementalType.basic,
        description: 'Test',
        accuracy: 100,
      ),
    );

    // Register a move with 0% accuracy (always misses)
    Move.addTestMove(
      const Move(
        name: 'Always Miss',
        baseDamage: 40,
        category: MoveCategory.physical,
        type: ElementalType.basic,
        description: 'Test',
        accuracy: 0,
      ),
    );

    // Register a multi-hit move (3 hits max/min)
    Move.addTestMove(
      const Move(
        name: 'Triple Strike',
        baseDamage: 10,
        category: MoveCategory.physical,
        type: ElementalType.basic,
        description: 'Test',
        accuracy: 100,
        minHits: 3,
        maxHits: 3,
      ),
    );
  });

  Organism createTestOrganism() {
    return Organism(
      name: 'Test',
      scientificName: 'Testus',
      habitat: 'Test',
      drops: '',
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      health: 100,
      speed: 100,
      abilities: 'None',
      category: 'Test',
      moves: 'Perfect Hit',
      sprite: '',
      rarity: 'Common',
      description: '',
      weight: 1.0,
      types: ['basic'],
    );
  }

  CapturedOrganism createCaptured(Organism base, List<String> moves) {
    return CapturedOrganism(
      baseOrganism: base,
      individualValues: {
        'health': 31,
        'attack': 31,
        'defense': 31,
        'power': 31,
        'resistance': 31,
        'speed': 31,
      },
      currentHealth: 200,
      level: 50,
      selectedMoveNames: moves,
    );
  }

  group('Move Animation and Accuracy Tests', () {
    test('onAttack is called when the move hits', () async {
      final base = createTestOrganism();
      final attacker = createCaptured(base, ['Perfect Hit']);
      final defender = createCaptured(base, ['Perfect Hit']);

      final manager = BattleManager(attacker, defender, isTesting: true);
      int animationCount = 0;
      manager.onAttack = (a, m) {
        animationCount++;
      };

      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        Move.findByName('Perfect Hit')!,
      );

      expect(animationCount, 1);
    });

    test('onAttack is NOT called when the move misses', () async {
      final base = createTestOrganism();
      final attacker = createCaptured(base, ['Always Miss']);
      final defender = createCaptured(base, ['Perfect Hit']);

      final manager = BattleManager(attacker, defender, isTesting: true);
      int animationCount = 0;
      manager.onAttack = (a, m) {
        animationCount++;
      };

      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        Move.findByName('Always Miss')!,
      );

      expect(animationCount, 0);
    });

    test('onAttack is called for each hit of a multi-hit move', () async {
      final base = createTestOrganism();
      final attacker = createCaptured(base, ['Triple Strike']);
      final defender = createCaptured(base, ['Perfect Hit']);

      final manager = BattleManager(attacker, defender, isTesting: true);
      int animationCount = 0;
      manager.onAttack = (a, m) {
        animationCount++;
      };

      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        Move.findByName('Triple Strike')!,
      );

      // Should be called 3 times (once for initial hit, and twice for subsequent hits in the loop)
      expect(animationCount, 3);
    });
  });
}
