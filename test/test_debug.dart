import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('debug', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final base = Organism(
      name: 'TestAnimal',
      scientificName: 'Testus animalis',
      habitat: 'Test',
      drops: '',
      attack: 20,
      defense: 20,
      power: 20,
      resistance: 20,
      health: 20,
      speed: 20,
      abilities: 'Inner Focus',
      category: 'Test',
      moves: '',
      sprite: 'test.png',
      rarity: 'Common',
      description: 'A test animal.',
      types: ['basic'],
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

    final attacker = CapturedOrganism.spawn(base, level: 50);
    final defender = CapturedOrganism.spawn(base, level: 50);

    attacker.moveStamina[punchMove.name] = 10;
    final manager = BattleManager(attacker, defender, isTesting: true);
    manager.currentState = BattleState.waitingForInput;

    // Without Iron Fist
    await manager.processPlayerAction(punchMove);
    final damageWithout = defender.maxHealth - defender.health;
    print('Damage without Iron Fist: $damageWithout');
    print('State after first turn: ${manager.currentState}');

    // With Iron Fist
    defender.health = defender.maxHealth;
    manager.player.abilities.clear();
    manager.player.abilities.add(ironFist);
    attacker.moveStamina[punchMove.name] = 10; // refill stamina just in case
    await manager.processPlayerAction(punchMove);
    final damageWith = defender.maxHealth - defender.health;
    print('Damage with Iron Fist: $damageWith');
    print('State after second turn: ${manager.currentState}');

    if (damageWithout > 0) {
      print('Ratio: ${(damageWith / damageWithout).toStringAsFixed(2)}');
    } else {
      print('Ratio: undefined (damageWithout is 0)');
    }
  });
}
