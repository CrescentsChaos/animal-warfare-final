import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/nature.dart';

void main() {
  group('KV and Satisfaction Tests', () {
    final baseOrg = Organism(
      name: 'Test Animal',
      scientificName: 'Testus animalis',
      habitat: 'Grassland',
      rarity: 'Common',
      health: 100,
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      speed: 100,
      moves: 'Punch',
      abilities: 'None',
      description: 'A test animal.',
      drops: '',
      category: 'Test',
      sprite: '',
    );

    test('KV stat bonus calculation (252 KV = +63 Stat at Lvl 100)', () {
      // Create with fixed IVs and neutral nature
      final org = CapturedOrganism(
        baseOrganism: baseOrg,
        nature: Nature.findByName('Hardy'),
        currentHealth: 100,
        individualValues: {
          'health': 0,
          'attack': 0,
          'defense': 0,
          'power': 0,
          'resistance': 0,
          'speed': 0,
        },
        level: 100,
      );

      // Base stat 100 at Level 100 with 0 IV and 0 KV (constructor initializes kvs to 0)
      // floor((100 * 2 + 0) * 100 / 100) + 5 = 205
      expect(org.getAttack(), 205);

      // With 252 KVs, bonus = floor(252 / 4) = 63
      // Total = 205 + 63 = 268
      org.killValues['attack'] = 252;
      expect(org.getAttack(), 268);
    });

    test('KV limits: max 252 per stat, max 510 total in model logic', () {
      // Note: UserState handles the award logic limits, but CapturedOrganism
      // stores the values. We already verified maxTotalKV and maxStatKV constants.
      expect(CapturedOrganism.maxTotalKV, 510);
      expect(CapturedOrganism.maxStatKV, 252);
    });

    test('Satisfaction range and default value', () {
      final org = CapturedOrganism.spawn(baseOrg);
      expect(org.satisfaction, 120); // Default

      org.satisfaction =
          300; // Should ideally be clamped in setter if we had one,
      // but we use applyBerry/logic to clamp.
      // Let's verify applyBerry clamps it
      org.satisfaction = 250;
      org.applyBerry('pomeg_berry');
      expect(org.satisfaction, 255);
    });

    test('Berry effects: KV reduction and Satisfaction increase', () {
      final org = CapturedOrganism.spawn(baseOrg);
      org.killValues['health'] = 50;
      org.satisfaction = 100;

      org.applyBerry('pomeg_berry');

      expect(org.killValues['health'], 40);
      expect(org.satisfaction, 110);

      // Test reduction to 0
      org.killValues['health'] = 5;
      org.applyBerry('pomeg_berry');
      expect(org.killValues['health'], 0);
    });
  });
}
