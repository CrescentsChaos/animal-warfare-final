import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';

void main() {
  group('Damage Calculation Tests', () {
    final baseOrganism = Organism(
      name: 'TestAnimal',
      scientificName: 'Testus Animalus',
      habitat: 'Plain',
      drops: 'Meat',
      health: 100,
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      speed: 100,
      abilities: '',
      category: 'Test',
      moves: 'Scratch,Water Gun',
      sprite: 'test.png',
      rarity: 'Common',
      description: 'Test',
      types: ['normal'],
    );

    test('BattleOrganism level initialization', () {
      final captured = CapturedOrganism(
        baseOrganism: baseOrganism,
        individualValues: {
          'health': 31,
          'attack': 31,
          'defense': 31,
          'power': 31,
          'resistance': 31,
          'speed': 31,
        },
        currentHealth: 100,
        level: 42,
      );

      final rogueOrg = BattleOrganism(captured, isRogueMode: true);
      expect(rogueOrg.level, 42);

      final normalOrg = BattleOrganism(captured, isRogueMode: false);
      expect(normalOrg.level, 50);
    });

    test('Damage formula scaling (Level 5 vs Level 50)', () {
      // Manual check of formula: (((2*L/5 + 2) * Atk * Power / Def) / 50 + 2)
      // Level 50, Atk 100, Def 100, Power 100:
      // (((2*50/5 + 2) * 100 * 100 / 100) / 50 + 2) = (((22) * 100) / 50 + 2) = (2200/50 + 2) = 44 + 2 = 46

      // Level 5, Atk 20 (base 100), Def 20, Power 100:
      // (((2*5/5 + 2) * 20 * 100 / 20) / 50 + 2) = (((4) * 100) / 50 + 2) = (400/50 + 2) = 8 + 2 = 10

      // Note: Actual stats in game include IVs and statConstant, so we'll just check if Level 50 > Level 5 significantly.

      final level5 = CapturedOrganism(
        baseOrganism: baseOrganism,
        individualValues: {
          'health': 31,
          'attack': 31,
          'defense': 31,
          'power': 31,
          'resistance': 31,
          'speed': 31,
        },
        currentHealth: 100,
        level: 5,
      );
      final level50 = CapturedOrganism(
        baseOrganism: baseOrganism,
        individualValues: {
          'health': 31,
          'attack': 31,
          'defense': 31,
          'power': 31,
          'resistance': 31,
          'speed': 31,
        },
        currentHealth: 100,
        level: 50,
      );

      // Verify stats actually scale
      expect(level50.effectiveAttack > level5.effectiveAttack, true);
      expect(level50.maxHealth > level5.maxHealth, true);
    });
  });
}
