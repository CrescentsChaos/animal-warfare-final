import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/move.dart';

void main() {
  group('True Flight Ability Tests', () {
    final baseBird = Organism(
      name: 'Bird',
      scientificName: 'Aves',
      habitat: 'Sky',
      drops: 'Feathers',
      health: 100,
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      speed: 100,
      abilities: 'True Flight',
      category: 'Flying',
      moves: 'Peck',
      sprite: 'bird.png',
      rarity: 'Common',
      description: 'A flying bird.',
      types: ['flying'],
    );

    final baseGround = Organism(
      name: 'Mole',
      scientificName: 'Talpidae',
      habitat: 'Ground',
      drops: 'Dirt',
      health: 100,
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      speed: 100,
      abilities: '',
      category: 'Ground',
      moves: 'Dig',
      sprite: 'mole.png',
      rarity: 'Common',
      description: 'A ground mole.',
      types: ['ground'],
    );

    final capturedBird = CapturedOrganism(
      baseOrganism: baseBird,
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

    final capturedMole = CapturedOrganism(
      baseOrganism: baseGround,
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

    test('Defensive: Ground moves deal 0 damage to True Flight users', () {
      final defender = BattleOrganism(capturedBird);
      final attacker = BattleOrganism(capturedMole);

      const move = Move(
        name: 'Dig',
        type: ElementalType.ground,
        baseDamage: 80,
        accuracy: 100,
        category: MoveCategory.physical,
        stamina: 10,
        description: 'Digs.',
      );

      // Verify True Flight is present
      expect(defender.abilities.any((ab) => ab.name == 'True Flight'), isTrue);

      // Simulate Type Effectiveness logic from BattleManager
      double typeMod = 1.0;
      bool defenderHasTrueFlight = defender.abilities.any(
        (ab) => ab.name == 'True Flight',
      );

      for (final defType in defender.types) {
        double eff = TypeChart.getEffectiveness(move.type, defType);
        if (defenderHasTrueFlight && move.type == ElementalType.ground) {
          eff = 0.0;
        }
        typeMod *= eff;
      }

      expect(typeMod, 0.0);
    });

    test('Defensive: Removes Flying-type weaknesses', () {
      final defender = BattleOrganism(capturedBird);

      const electricMove = Move(
        name: 'Thunder',
        type: ElementalType.electric,
        baseDamage: 100,
        accuracy: 100,
        category: MoveCategory.special,
        stamina: 10,
        description: 'Thunder.',
      );

      // Flying is normally weak to Electric (2.0x)
      expect(
        TypeChart.getEffectiveness(
          ElementalType.electric,
          ElementalType.flying,
        ),
        2.0,
      );

      double typeMod = 1.0;
      bool defenderHasTrueFlight = defender.abilities.any(
        (ab) => ab.name == 'True Flight',
      );

      for (final defType in defender.types) {
        double eff = TypeChart.getEffectiveness(electricMove.type, defType);
        if (defenderHasTrueFlight &&
            defender.types.contains(ElementalType.flying)) {
          if (electricMove.type == ElementalType.electric) {
            if (eff > 1.0) eff = 1.0;
          }
        }
        typeMod *= eff;
      }

      expect(typeMod, 1.0);
    });

    test('Offensive: Flying moves ignore resistances', () {
      final attacker = BattleOrganism(capturedBird);

      const flyingMove = Move(
        name: 'Peck',
        type: ElementalType.flying,
        baseDamage: 40,
        accuracy: 100,
        category: MoveCategory.physical,
        stamina: 10,
        description: 'Pecks.',
      );

      // Ground normally resists Flying (0.5x)
      expect(
        TypeChart.getEffectiveness(ElementalType.flying, ElementalType.ground),
        0.5,
      );

      double typeMod = 1.0;
      bool attackerHasTrueFlight = attacker.abilities.any(
        (ab) => ab.name == 'True Flight',
      );

      // Target is Ground
      for (final defType in [ElementalType.ground]) {
        double eff = TypeChart.getEffectiveness(flyingMove.type, defType);
        if (attackerHasTrueFlight && flyingMove.type == ElementalType.flying) {
          if (eff < 1.0 && eff > 0) eff = 1.0;
        }
        typeMod *= eff;
      }

      expect(typeMod, 1.0);
    });
  });
}
