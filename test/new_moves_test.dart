import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AudioService.isTesting = true;

    // Register new moves for tests
    Move.addTestMove(
      const Move(
        name: 'Sleep Talk',
        baseDamage: 0,
        category: MoveCategory.status,
        type: ElementalType.basic,
        description: 'Test',
        effects: [MoveEffect(type: MoveEffectType.sleepTalk)],
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Snore',
        baseDamage: 50,
        category: MoveCategory.special,
        type: ElementalType.basic,
        description: 'Test',
        effects: [MoveEffect(type: MoveEffectType.snore)],
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Magic Coat',
        baseDamage: 0,
        category: MoveCategory.status,
        type: ElementalType.basic,
        description: 'Test',
        effects: [MoveEffect(type: MoveEffectType.magicCoat)],
      ),
    );
     Move.addTestMove(
      const Move(
        name: 'Tera Blast',
        baseDamage: 80,
        category: MoveCategory.special,
        type: ElementalType.basic,
        description: 'Test',
        effects: [MoveEffect(type: MoveEffectType.teraBlast)],
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Tackle',
        baseDamage: 40,
        category: MoveCategory.physical,
        type: ElementalType.basic,
        description: 'Test',
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Toxic',
        baseDamage: 0,
        category: MoveCategory.status,
        type: ElementalType.toxic,
        description: 'Test',
        effects: [MoveEffect(type: MoveEffectType.statusPoison)],
      ),
    );
  });

  Organism createTestOrganism({
    String name = 'Test',
    List<ElementalType>? types,
    int attack = 100,
    int power = 100,
  }) {
    return Organism(
      name: name,
      scientificName: 'Testus',
      habitat: 'Test',
      drops: '',
      attack: attack,
      defense: 100,
      power: power,
      resistance: 100,
      health: 100,
      speed: 100,
      abilities: 'None',
      category: 'Test',
      moves: 'Tackle',
      sprite: '',
      rarity: 'Common',
      description: '',
      weight: 1.0,
      types: types?.map((e) => e.toString().split('.').last).toList() ?? ['basic'],
    );
  }

  CapturedOrganism createCaptured(
    Organism base, {
    List<String>? moves,
    ElementalType? teraType,
  }) {
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
      selectedMoveNames: moves ?? ['Tackle'],
      teraType: teraType,
    );
  }

  group('New Moves Tests', () {
    test('Sleep Talk selects a random move when asleep', () async {
      final base = createTestOrganism();
      final attacker = createCaptured(base, moves: ['Sleep Talk', 'Tackle']);
      final defender = createCaptured(base);

      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.player.addStatusEffect(const StatusEffect(type: StatusEffectType.sleep, duration: 3));

      // Use Sleep Talk
      await manager.testExecuteTurn(manager.player, manager.opponent, Move.findByName('Sleep Talk')!);

      // Since Tackle is the only other move, it should be called (and deal damage)
      expect(manager.opponent.health, lessThan(200));
    });

    test('Snore deals damage while asleep', () async {
       final base = createTestOrganism();
      final attacker = createCaptured(base, moves: ['Snore']);
      final defender = createCaptured(base);

      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.player.addStatusEffect(const StatusEffect(type: StatusEffectType.sleep, duration: 3));

      await manager.testExecuteTurn(manager.player, manager.opponent, Move.findByName('Snore')!);

      expect(manager.opponent.health, lessThan(200));
    });

    test('Magic Coat reflects status moves', () async {
      final base = createTestOrganism();
      final attacker = createCaptured(base, moves: ['Magic Coat']);
      final defender = createCaptured(base, moves: ['Toxic']);

      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.ignoreRandom = true;

      // Player uses Magic Coat (sets flag)
      await manager.testExecuteTurn(manager.player, manager.opponent, Move.findByName('Magic Coat')!);
      expect(manager.player.magicCoatActive, true);

      // Opponent uses Toxic
      await manager.testExecuteTurn(manager.opponent, manager.player, Move.findByName('Toxic')!);

      // Player should NOT be poisoned, but Opponent SHOULD be (reflected)
      expect(manager.player.statusEffects.any((se) => se.type == StatusEffectType.poison), false);
      expect(manager.opponent.statusEffects.any((se) => se.type == StatusEffectType.poison), true);
    });

    test('Tera Blast changes type and uses higher offense when Prismorphed', () {
      final baseNormal = createTestOrganism(attack: 200, power: 50);
      
      final attacker = createCaptured(baseNormal, moves: ['Tera Blast'], teraType: ElementalType.blaze);
      final defender = createCaptured(baseNormal);

      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.ignoreRandom = true;

      final move = Move.findByName('Tera Blast')!;

      // Normal state: Special, Basic type
      final damageNormal = manager.calculateDamage(manager.player, manager.opponent, move);
      expect(manager.getDisplayType(manager.player, move), ElementalType.basic);

      // Prismorphed state: Blaze type (from createTestOrganism), uses Attack instead of Power
      manager.player.isPrismorphed = true;
      manager.player.activeTeraType = ElementalType.blaze;
      
      final damageTera = manager.calculateDamage(manager.player, manager.opponent, move);
      expect(manager.getDisplayType(manager.player, move), ElementalType.blaze);
      
      // Since attack (200) > power (50), damage should be much higher
      expect(damageTera.damage, greaterThan(damageNormal.damage));
    });
  });
}
