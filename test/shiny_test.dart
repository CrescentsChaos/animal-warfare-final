import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Shiny Animals Tests', () {
    late Organism base;

    setUp(() {
      base = Organism(
        name: 'TestAnimal',
        scientificName: 'Testis',
        habitat: 'Test',
        drops: '',
        attack: 50,
        defense: 50,
        power: 50,
        resistance: 50,
        health: 100,
        speed: 50,
        abilities: '',
        category: 'basic',
        moves: 'Strugggle',
        sprite: '',
        rarity: 'Common',
        description: '',
        types: ['basic'],
      );
    });

    test('CapturedOrganism.spawn has ~5% alpha rate', () {
      int alphaCount = 0;
      const count = 2000;
      for (int i = 0; i < count; i++) {
        final org = CapturedOrganism.spawn(base);
        if (org.isAlpha) alphaCount++;
      }

      print('Alpha count: $alphaCount / $count');
      // ~100 expected
      expect(alphaCount, greaterThan(60));
      expect(alphaCount, lessThan(140));
    });

    test('isAlpha persistence in JSON', () {
      final org = CapturedOrganism(
        baseOrganism: base,
        individualValues: {
          'health': 31,
          'attack': 31,
          'defense': 31,
          'power': 31,
          'resistance': 31,
          'speed': 31,
        },
        currentHealth: 100,
        isAlpha: true,
      );

      final json = org.toJson();
      expect(json['isAlpha'], isTrue);

      final decoded = CapturedOrganism.fromJson(json, [base]);
      expect(decoded?.isAlpha, isTrue);
    });

    test('Alpha IVs are superior (all 15+, at least two 31)', () {
      int alphaFound = 0;
      for (int i = 0; i < 500; i++) {
        final org = CapturedOrganism.spawn(base);
        if (org.isAlpha) {
          alphaFound++;
          int maxIVs = 0;
          for (final value in org.individualValues.values) {
            expect(value, greaterThanOrEqualTo(15));
            if (value == 31) maxIVs++;
          }
          expect(maxIVs, greaterThanOrEqualTo(2));
        }
      }
      expect(alphaFound, greaterThan(0));
    });

    test('Shiny IVs have at least one 31', () {
      int shinyFound = 0;
      for (int i = 0; i < 500; i++) {
        final org = CapturedOrganism.spawn(base);
        if (org.isShiny && !org.isAlpha) {
          shinyFound++;
          bool has31 = org.individualValues.values.any((v) => v == 31);
          expect(has31, isTrue);
        }
      }
      expect(shinyFound, greaterThan(0));
    });

    test('Default isShiny and isAlpha are false', () {
      final org = CapturedOrganism(
        baseOrganism: base,
        individualValues: {
          'health': 10,
          'attack': 10,
          'defense': 10,
          'power': 10,
          'resistance': 10,
          'speed': 10,
        },
        currentHealth: 100,
      );
      expect(org.isShiny, isFalse);
      expect(org.isAlpha, isFalse);
    });
  });
}
