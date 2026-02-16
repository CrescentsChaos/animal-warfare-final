import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';

void main() {
  group('Move Randomization Tests', () {
    final manyMovesOrganism = Organism(
      name: 'Test Animal',
      scientificName: 'Testus',
      habitat: 'Test',
      drops: 'Test',
      health: 100,
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      speed: 100,
      abilities: '',
      category: 'Test',
      moves: 'Move 1, Move 2, Move 3, Move 4, Move 5, Move 6, Move 7, Move 8',
      sprite: '',
      rarity: 'Common',
      description: '',
    );

    test('Spawned organisms with many moves have exactly 4 moves', () {
      final spawned = CapturedOrganism.spawn(manyMovesOrganism);
      expect(spawned.selectedMoveNames.length, 4);
    });

    test('Spawned organisms with many moves have unique moves', () {
      final spawned = CapturedOrganism.spawn(manyMovesOrganism);
      final uniqueSet = spawned.selectedMoveNames.toSet();
      expect(uniqueSet.length, 4);
    });

    test('Move sets are randomized (not identical across spawns)', () {
      final moveSets = <List<String>>[];

      // Spawn 10 instances and check if we get at least 2 different move sets
      // With 8 moves, choosing 4 produces 70 combinations (8C4).
      // Probability of getting 10 identical sets is extremely low if randomized.
      for (int i = 0; i < 10; i++) {
        final spawned = CapturedOrganism.spawn(manyMovesOrganism);
        moveSets.add(spawned.selectedMoveNames);
      }

      bool allSame = true;
      final firstSet = moveSets[0];
      for (int i = 1; i < moveSets.length; i++) {
        final currentSet = moveSets[i];
        // Compare sets ignoring order as shuffle results might differ in order too
        if (currentSet.toSet().difference(firstSet.toSet()).isNotEmpty) {
          allSame = false;
          break;
        }
      }

      expect(
        allSame,
        isFalse,
        reason:
            'Expected at least some variation in move sets across 10 spawns',
      );
    });

    test('Organisms with exactly 4 moves get all of them', () {
      final fourMovesOrganism = Organism(
        name: 'Four Moves',
        scientificName: 'Testus',
        habitat: 'Test',
        drops: 'Test',
        health: 100,
        attack: 100,
        defense: 100,
        power: 100,
        resistance: 100,
        speed: 100,
        abilities: '',
        category: 'Test',
        moves: 'Move 1, Move 2, Move 3, Move 4',
        sprite: '',
        rarity: 'Common',
        description: '',
      );

      final spawned = CapturedOrganism.spawn(fourMovesOrganism);
      expect(spawned.selectedMoveNames.length, 4);
      expect(spawned.selectedMoveNames.toSet().length, 4);
    });

    test('Organisms with fewer than 4 moves get all of them', () {
      final threeMovesOrganism = Organism(
        name: 'Three Moves',
        scientificName: 'Testus',
        habitat: 'Test',
        drops: 'Test',
        health: 100,
        attack: 100,
        defense: 100,
        power: 100,
        resistance: 100,
        speed: 100,
        abilities: '',
        category: 'Test',
        moves: 'Move 1, Move 2, Move 3',
        sprite: '',
        rarity: 'Common',
        description: '',
      );

      final spawned = CapturedOrganism.spawn(threeMovesOrganism);
      expect(spawned.selectedMoveNames.length, 3);
      expect(spawned.selectedMoveNames.toSet().length, 3);
    });
  });
}
