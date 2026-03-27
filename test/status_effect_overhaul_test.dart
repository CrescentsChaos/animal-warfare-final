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

    // Register moves for tests
    Move.addTestMove(
      const Move(
        name: 'Rest',
        baseDamage: 0,
        category: MoveCategory.status,
        type: ElementalType.aura,
        description: 'Sleep for 2 turns to heal.',
        effects: [
          MoveEffect(type: MoveEffectType.heal, target: 'self', value: 100), // Heals 100%
          MoveEffect(type: MoveEffectType.statusSleep, target: 'self', value: 0),
        ],
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Toxic',
        baseDamage: 0,
        category: MoveCategory.status,
        type: ElementalType.toxic,
        description: 'Badly poisons the target.',
        effects: [MoveEffect(type: MoveEffectType.statusPoison)],
      ),
    );
     Move.addTestMove(
      const Move(
        name: 'Tackle',
        baseDamage: 40,
        category: MoveCategory.physical,
        type: ElementalType.basic,
        description: 'Basic attack.',
      ),
    );
  });

  Organism createTestOrganism({String name = 'Test'}) {
    return Organism(
      name: name,
      scientificName: 'Testus',
      habitat: 'Test',
      drops: '',
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      health: 100, // Standard base HP
      speed: 100,
      abilities: 'None',
      category: 'Test',
      moves: 'Tackle',
      sprite: '',
      rarity: 'Common',
      description: '',
      weight: 1.0,
      types: ['basic'],
    );
  }

  CapturedOrganism createCaptured(Organism base, {List<String>? moves}) {
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
      level: 100,
      selectedMoveNames: moves ?? ['Tackle'],
    );
  }

  group('Status Effect Overhaul Tests', () {
    test('Rest move should always set sleep duration to 2 turns', () async {
      final base = createTestOrganism();
      final attacker = createCaptured(base, moves: ['Rest']);
      final defender = createCaptured(base);

      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.ignoreRandom = true;

      // Ensure attacker has some damage to heal
      manager.player.health = 50;

      // Use Rest
      await manager.testExecuteTurn(manager.player, manager.opponent, Move.findByName('Rest')!);

      expect(manager.player.health, manager.player.maxHealth);
      expect(manager.player.statusEffects.any((se) => se.type == StatusEffectType.sleep), true);
      
      final sleepEffect = manager.player.statusEffects.firstWhere((se) => se.type == StatusEffectType.sleep);
      expect(sleepEffect.duration, 2, reason: 'Rest sleep duration must be exactly 2 turns');
    });

    test('Poison damage should scale each turn (Badly Poisoned)', () async {
      final base = createTestOrganism();
      final attacker = createCaptured(base, moves: ['Toxic']);
      final defender = createCaptured(base);

      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.ignoreRandom = true;

      final int maxHp = manager.opponent.maxHealth;

      // Poison the opponent
      await manager.testExecuteTurn(manager.player, manager.opponent, Move.findByName('Toxic')!);
      expect(manager.opponent.statusEffects.any((se) => se.type == StatusEffectType.poison), true);
      expect(manager.opponent.poisonTurnCount, 0, reason: 'poisonTurnCount should start at 0');

      // End turn 1: damage = maxHp * 1 / 16
      await manager.testApplyTurnEffects(manager.opponent); 
      expect(manager.opponent.poisonTurnCount, 1);
      final turn1Damage = maxHp - manager.opponent.health;
      expect(turn1Damage, (maxHp * 1 / 16).round().clamp(1, 9999), 
          reason: 'Turn 1 damage should be 1/16 of max HP');

      // End turn 2: additional damage = maxHp * 2 / 16
      final healthAfterTurn1 = manager.opponent.health;
      await manager.testApplyTurnEffects(manager.opponent);
      expect(manager.opponent.poisonTurnCount, 2);
      final turn2Damage = healthAfterTurn1 - manager.opponent.health;
      expect(turn2Damage, (maxHp * 2 / 16).round().clamp(1, 9999), 
          reason: 'Turn 2 damage should be 2/16 of max HP');

      // End turn 3: additional damage = maxHp * 3 / 16
      final healthAfterTurn2 = manager.opponent.health;
      await manager.testApplyTurnEffects(manager.opponent);
      expect(manager.opponent.poisonTurnCount, 3);
      final turn3Damage = healthAfterTurn2 - manager.opponent.health;
      expect(turn3Damage, (maxHp * 3 / 16).round().clamp(1, 9999), 
          reason: 'Turn 3 damage should be 3/16 of max HP');
    });

    test('PoisonTurnCount should reset when status is cleared', () async {
      final base = createTestOrganism();
      final attacker = createCaptured(base);
      final defender = createCaptured(base);

      final manager = BattleManager(attacker, defender, isTesting: true);
      
      // Simulate poison and scaling
      manager.opponent.addStatusEffect(const StatusEffect(type: StatusEffectType.poison));
      manager.opponent.poisonTurnCount = 5;

      // Clear status
      manager.opponent.clearStatusEffects();
      expect(manager.opponent.poisonTurnCount, 0, reason: 'poisonTurnCount must reset when poison is cleared');
    });

    test('PoisonTurnCount should reset when organism switches out', () async {
      final base = createTestOrganism();
      final attacker = createCaptured(base);
      final defender = createCaptured(base);

      final manager = BattleManager(attacker, defender, isTesting: true);
      
      // Simulate poison and scaling
      manager.player.addStatusEffect(const StatusEffect(type: StatusEffectType.poison));
      manager.player.poisonTurnCount = 3;

      // Reset battle state (happens during switch out)
      manager.player.resetBattleState();
      expect(manager.player.poisonTurnCount, 0, reason: 'poisonTurnCount must reset when switching out');
    });
  });
}
