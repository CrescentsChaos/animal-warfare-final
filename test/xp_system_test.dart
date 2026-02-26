import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/explore_screen.dart';

void main() {
  group('Account XP & Scaling Tests', () {
    final baseOrg = Organism(
      name: 'Test Animal',
      scientificName: 'Testus animalis',
      habitat: 'Grassland',
      rarity: 'Common',
      health: 100,
      attack: 50,
      defense: 50,
      power: 50,
      resistance: 50,
      speed: 50,
      moves: 'Punch',
      abilities: 'None',
      description: 'A test animal.',
      drops: '',
      category: 'Test',
      sprite: '',
    );

    test('CapturedOrganism.gainXP respects account level cap', () {
      final captured = CapturedOrganism.spawn(baseOrg, level: 5);

      // Attempt to gain XP that would reach level 15, but cap is 10
      final result = captured.gainXP(100000, 10);

      expect(result['level'], 10);
      expect(result['leveledUp'], isTrue);

      // XP should be capped just before Level 11
      final xpForLevel11 = CapturedOrganism.xpForLevel(11);
      expect(result['xp'], xpForLevel11 - 1);
    });

    test('CapturedOrganism.spawn scales wild level to account level', () {
      // Account Level 50
      final wild50 = CapturedOrganism.spawn(baseOrg, accountLevel: 50);
      expect(wild50.level, inClosedOpenRange(48, 53));

      // Account Level 1
      final wild1 = CapturedOrganism.spawn(baseOrg, accountLevel: 1);
      expect(wild1.level, inClosedOpenRange(1, 4)); // Clamped at 1
    });

    test('getWeightedRandomOrganism respects rarity gates', () {
      final uncommonOrg = Organism(
        name: 'Uncommon Animal',
        scientificName: 'Uncommunus',
        habitat: 'Grassland',
        rarity: 'Uncommon',
        health: 100,
        attack: 50,
        defense: 50,
        power: 50,
        resistance: 50,
        speed: 50,
        moves: 'Punch',
        abilities: 'None',
        description: 'An uncommon test animal.',
        drops: '',
        category: 'Test',
        sprite: '',
      );

      final rareOrg = Organism(
        name: 'Rare Animal',
        scientificName: 'Rarus',
        habitat: 'Grassland',
        rarity: 'Rare',
        health: 100,
        attack: 50,
        defense: 50,
        power: 50,
        resistance: 50,
        speed: 50,
        moves: 'Punch',
        abilities: 'None',
        description: 'A rare test animal.',
        drops: '',
        category: 'Test',
        sprite: '',
      );

      final allOrgs = [baseOrg, uncommonOrg, rareOrg];

      // Account Level 1: Should only find Common
      final encounter1 = getWeightedRandomOrganism(
        'Grassland',
        allOrgs,
        accountLevel: 1,
      );
      expect(encounter1?.rarity, 'Common');

      // Account Level 15: Should be able to find Uncommon but not Rare
      // We'll run it a few times to be sure
      bool foundUncommon = false;
      for (int i = 0; i < 20; i++) {
        final encounter15 = getWeightedRandomOrganism(
          'Grassland',
          allOrgs,
          accountLevel: 15,
        );
        if (encounter15?.rarity == 'Uncommon') foundUncommon = true;
        expect(encounter15?.rarity, isNot('Rare'));
      }
      expect(
        foundUncommon,
        isTrue,
        reason: 'Should have found an uncommon animal at level 15',
      );

      // Account Level 25: Should be able to find Rare
      bool foundRare = false;
      for (int i = 0; i < 50; i++) {
        final encounter25 = getWeightedRandomOrganism(
          'Grassland',
          allOrgs,
          accountLevel: 25,
        );
        if (encounter25?.rarity == 'Rare') foundRare = true;
      }
      expect(
        foundRare,
        isTrue,
        reason: 'Should have found a rare animal at level 25',
      );
    });
  });
}
