import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AudioService.isTesting = true;

    // Register abilities for tests
    Ability.addTestAbility(
      const Ability(name: 'Heavy Metal', description: '', magnitude: 2.0),
    );
    Ability.addTestAbility(
      const Ability(
        name: 'Light Metal',
        description: '',
        trigger: AbilityTrigger.onCalculateStat,
        effectType: AbilityEffectType.statMultiplier,
        targetStat: 'speed',
        magnitude: 1.3,
      ),
    );
    Ability.addTestAbility(
      const Ability(name: 'Multiscale', description: '', magnitude: 0.5),
    );
    Ability.addTestAbility(
      const Ability(
        name: 'Toxic Boost',
        description: '',
        trigger: AbilityTrigger.onCalculateStat,
        targetStat: 'attack',
        magnitude: 1.5,
      ),
    );
    Ability.addTestAbility(
      const Ability(
        name: 'Flare Boost',
        description: '',
        trigger: AbilityTrigger.onCalculateStat,
        targetStat: 'power',
        magnitude: 1.5,
      ),
    );
    Ability.addTestAbility(
      const Ability(
        name: 'Sand Rush',
        description: '',
        trigger: AbilityTrigger.onCalculateStat,
        effectType: AbilityEffectType.statMultiplier,
        targetStat: 'speed',
        magnitude: 1.5,
      ),
    );
    Ability.addTestAbility(
      const Ability(name: 'Big Pecks', description: '', magnitude: 1.3),
    );
    Ability.addTestAbility(
      const Ability(name: 'Analytic', description: '', magnitude: 1.3),
    );
    Ability.addTestAbility(const Ability(name: 'Regenerator', description: ''));
    Ability.addTestAbility(
      const Ability(
        name: 'Imposter',
        description: '',
        trigger: AbilityTrigger.onEntry,
      ),
    );
    Ability.addTestAbility(const Ability(name: 'Infiltrator', description: ''));
    Ability.addTestAbility(const Ability(name: 'Overcoat', description: ''));
    Ability.addTestAbility(const Ability(name: 'Wonder Skin', description: ''));
    Ability.addTestAbility(
      const Ability(
        name: 'Rattled',
        description: '',
        trigger: AbilityTrigger.onDamageTaken,
        effectType: AbilityEffectType.statChange,
        targetStat: 'speed',
        magnitude: 1.0,
        conditions: ['type_arthropod', 'type_spectral', 'type_darkness'],
      ),
    );

    // Register moves
    Move.addTestMove(
      const Move(
        name: 'Struggle',
        baseDamage: 50,
        category: MoveCategory.physical,
        type: ElementalType.basic,
        description: 'Test',
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Spore',
        baseDamage: 0,
        category: MoveCategory.status,
        type: ElementalType.grass,
        description: 'Test',
        isPowder: true,
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Slash',
        baseDamage: 50,
        category: MoveCategory.physical,
        type: ElementalType.basic,
        description: 'Test',
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Bug Bite',
        baseDamage: 50,
        category: MoveCategory.physical,
        type: ElementalType.arthropod,
        description: 'Test',
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Shadow Ball',
        baseDamage: 80,
        category: MoveCategory.special,
        type: ElementalType.spectral,
        description: 'Test',
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Bite',
        baseDamage: 60,
        category: MoveCategory.physical,
        type: ElementalType.darkness,
        description: 'Test',
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Growl',
        baseDamage: 0,
        category: MoveCategory.status,
        type: ElementalType.basic,
        description: 'Test',
        effects: [
          MoveEffect(
            type: MoveEffectType.statChange,
            stat: 'attack',
            value: -1,
            chance: 100,
          ),
        ],
      ),
    );
  });

  Organism createTestOrganism({
    String name = 'Test',
    String abilities = '',
    double weight = 1.0,
    List<ElementalType>? types,
  }) {
    return Organism(
      name: name,
      scientificName: 'Testus',
      habitat: 'Test',
      drops: '',
      attack: 100,
      defense: 100,
      power: 100,
      resistance: 100,
      health: 100,
      speed: 100,
      abilities: abilities,
      category: 'Test',
      moves: 'Struggle',
      sprite: '',
      rarity: 'Common',
      description: '',
      weight: weight,
      types:
          types?.map((e) => e.toString().split('.').last).toList() ?? ['basic'],
    );
  }

  CapturedOrganism createCaptured(
    Organism base, {
    String? ability,
    int? health,
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
      currentHealth: health ?? 200,
      activeAbilityName: ability,
      level: 50,
      selectedMoveNames: ['Struggle', 'Spore', 'Slash'],
    );
  }

  group('Ability Tests', () {
    test('Heavy Metal and Light Metal Weight Calculation', () {
      final base = createTestOrganism(weight: 100.0);

      final normal = createCaptured(base, ability: 'None');
      final normalBO = BattleOrganism(normal);
      expect(normalBO.currentWeight, 100.0);

      final heavy = createCaptured(base, ability: 'Heavy Metal');
      final heavyBO = BattleOrganism(heavy);
      expect(heavyBO.currentWeight, 200.0);

      final light = createCaptured(base, ability: 'Light Metal');
      final lightBO = BattleOrganism(light);
      expect(lightBO.currentWeight, 50.0);
    });

    test('Light Metal Speed Boost', () {
      final base = createTestOrganism();
      final light = createCaptured(base, ability: 'Light Metal');
      final lightBO = BattleOrganism(light);

      expect(lightBO.getAbilityStatMultiplier('speed'), 1.3);
    });

    test('Multiscale Damage Reduction', () async {
      final attackerBase = createTestOrganism();
      final defenderBase = createTestOrganism();

      final attacker = createCaptured(attackerBase);
      final defender = createCaptured(defenderBase, ability: 'Multiscale');

      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.ignoreRandom = true;

      final move = Move.findByName('Struggle')!;

      // Full HP: Multiscale should trigger
      final resultFull = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
      );

      // Not Full HP: Multiscale should NOT trigger
      manager.opponent.health = manager.opponent.maxHealth - 1;
      final resultNotFull = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
      );

      expect(resultFull.damage, (resultNotFull.damage * 0.5).round());
    });

    test('Overcoat Special Damage Reduction', () async {
      final attackerBase = createTestOrganism();
      final defenderBase = createTestOrganism();

      final attacker = createCaptured(attackerBase);
      final defender = createCaptured(defenderBase, ability: 'Overcoat');

      final manager = BattleManager(attacker, defender, isTesting: true);
      manager.ignoreRandom = true;

      final physicalMove = Move.findByName('Struggle')!;
      final specialMove = physicalMove.copyWith(category: MoveCategory.special);

      // Physical: No reduction
      final damagePhys = manager.calculateDamage(
        manager.player,
        manager.opponent,
        physicalMove,
      );

      // Remove ability temporarily by clearing temp abilities
      manager.opponent.tempAbilities.clear();
      // BattleOrganism.abilities is a getter $[\dots\_baseAbilities, \dots tempAbilities]$
      // To "remove" it, we'd need to mock or change the organism.

      // Let's just compare Special vs Physical relative to base stats (both 100/100)
      final damageSpec = manager.calculateDamage(
        manager.player,
        manager.opponent,
        specialMove,
      );

      // Since attack=100 and defense=100 and baseDamage is same, damage should be same if no Overcoat
      // Overcoat reduces special by 0.8
      expect(damageSpec.damage, (damagePhys.damage * 0.8).round());
    });

    test('Toxic Boost Attack Multiplier', () {
      final base = createTestOrganism();
      final toxic = createCaptured(base, ability: 'Toxic Boost');

      final move = Move.findByName('Struggle')!;

      final manager = BattleManager(
        toxic,
        createCaptured(base),
        isTesting: true,
      );
      manager.ignoreRandom = true;

      manager.calculateDamage(manager.player, manager.opponent, move);

      // Poisoned: stat-based boost (1.5x to atk)
      manager.player.statusEffects.add(
        const StatusEffect(type: StatusEffectType.poison),
      );
      final damageBoosted = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
      );

      expect(damageBoosted.damage, 53);
    });

    test('Sand Rush Speed Multiplier', () {
      final base = createTestOrganism();
      final sand = createCaptured(base, ability: 'Sand Rush');
      final sandBO = BattleOrganism(sand);

      final manager = BattleManager(
        sand,
        createCaptured(base),
        isTesting: true,
      );

      // No sandstorm
      expect(sandBO.getAbilityStatMultiplier('speed'), 1.0);

      // Sandstorm
      manager.currentWeather = const WeatherEffect(weather: Weather.sandstorm);
      expect(manager.player.getAbilityStatMultiplier('speed'), 1.5);
    });

    test('Analytic Power Boost', () async {
      final base = createTestOrganism();
      final analytic = createCaptured(base, ability: 'Analytic');

      final manager = BattleManager(
        analytic,
        createCaptured(base),
        isTesting: true,
      );
      manager.ignoreRandom = true;

      final move = Move.findByName('Struggle')!;

      // Moved first (Analytic doesn't trigger)
      manager.opponentMovedThisTurn = false;
      manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
      );

      // Moved last (Analytic triggers)
      manager.opponentMovedThisTurn = true;
      final damageLast = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
      );

      expect(damageLast.damage, 46);
    });

    test('Regenerator Health Restore', () async {
      final base = createTestOrganism();
      final reger = createCaptured(base, ability: 'Regenerator', health: 100);

      final defender = createCaptured(base);
      final manager = BattleManager(reger, defender, isTesting: true);

      // Add a backup animal to switch to
      manager.playerTeam.add(createCaptured(base));

      // Max HP is around 175 (Level 50, IV 31, Base 100)
      // Ensure we wait for initialization
      await Future.delayed(const Duration(milliseconds: 100));

      // Switch out
      await manager.switchAnimal(1);

      // Check if original animal (reger) was healed
      // Regenerator heals 1/3 of max HP
      expect(manager.playerTeam[0].currentHealth, greaterThan(100));
    });

    test('Imposter Transformation', () async {
      final baseA = createTestOrganism(name: 'A');
      final baseB = createTestOrganism(name: 'B');

      final imposter = createCaptured(baseA, ability: 'Imposter');
      final target = createCaptured(baseB);
      target.attackStage = 2; // Buff target

      final manager = BattleManager(imposter, target, isTesting: true);
      await Future.delayed(const Duration(milliseconds: 100));

      // Imposter should have copied stages
      expect(manager.player.attackStage, 2);
      expect(manager.player.isDisguised, true);
    });

    test('Infiltrator Screen Bypass', () async {
      final base = createTestOrganism();
      final infiltrator = createCaptured(base, ability: 'Infiltrator');
      final defender = createCaptured(base);

      final manager = BattleManager(infiltrator, defender, isTesting: true);
      manager.ignoreRandom = true;
      manager.opponentReflectTurns = 5; // Set reflect

      final move = Move.findByName('Slash')!;

      // Infiltrator: deals full damage
      final damageFiltered = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
      );

      // Remove Infiltrator by changing ability
      manager.player.organism.activeAbilityName = 'None';
      // We might need to recreate BattleOrganism or just override it

      // Let's just compare to a base run without reflect
      manager.opponentReflectTurns = 0;
      final damageNoReflect = manager.calculateDamage(
        manager.player,
        manager.opponent,
        move,
      );

      expect(damageFiltered.damage, damageNoReflect.damage);
    });

    test('Overcoat Powder Block', () async {
      final base = createTestOrganism();
      final attacker = createCaptured(base);
      final defender = createCaptured(base, ability: 'Overcoat');

      final manager = BattleManager(attacker, defender, isTesting: true);

      final spore = Move.findByName('Spore')!;

      // Execute turn with Spore
      await manager.testExecuteTurn(manager.player, manager.opponent, spore);

      // Defender should NOT be asleep
      expect(
        manager.opponent.statusEffects.any(
          (se) => se.type == StatusEffectType.sleep,
        ),
        false,
      );
    });

    test('Grass Type Powder Immunity', () async {
      final attackerBase = createTestOrganism();
      final defenderBase = createTestOrganism(types: [ElementalType.grass]);

      final attacker = createCaptured(attackerBase);
      final defender = createCaptured(defenderBase);

      final manager = BattleManager(attacker, defender, isTesting: true);

      final spore = Move.findByName('Spore')!;

      await manager.testExecuteTurn(manager.player, manager.opponent, spore);

      expect(
        manager.opponent.statusEffects.any(
          (se) => se.type == StatusEffectType.sleep,
        ),
        false,
      );
    });
  });

  group('Rattled Ability Tests', () {
    test('Rattled triggers on Dark, Ghost (Spectral), and Bug (Arthropod) hits',
        () async {
      final attackerBase = createTestOrganism();
      final defenderBase = createTestOrganism();
      final attackerCaptured = createCaptured(attackerBase);
      final defenderCaptured = createCaptured(defenderBase, ability: 'Rattled');

      final manager = BattleManager(
        attackerCaptured,
        defenderCaptured,
        isTesting: true,
      );
      manager.ignoreRandom = true;

      // Initial speed stage should be 0
      expect(manager.opponent.speedStage, 0);

      // Hit with Bug Bite (Arthropod)
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        Move.findByName('Bug Bite')!,
      );
      expect(manager.opponent.speedStage, 1);

      // Hit with Shadow Ball (Spectral)
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        Move.findByName('Shadow Ball')!,
      );
      expect(manager.opponent.speedStage, 2);

      // Hit with Bite (Darkness)
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        Move.findByName('Bite')!,
      );
      expect(manager.opponent.speedStage, 3);
    });

    test('Rattled does NOT trigger on other types', () async {
      final attackerBase = createTestOrganism();
      final defenderBase = createTestOrganism();
      final attackerCaptured = createCaptured(attackerBase);
      final defenderCaptured = createCaptured(defenderBase, ability: 'Rattled');

      final manager = BattleManager(
        attackerCaptured,
        defenderCaptured,
        isTesting: true,
      );
      manager.ignoreRandom = true;

      // Hit with Struggle (Basic)
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        Move.findByName('Struggle')!,
      );
      expect(manager.opponent.speedStage, 0);
    });

    test('Rattled triggers on stat loss (as per instruction)', () async {
      final attackerBase = createTestOrganism();
      final defenderBase = createTestOrganism();
      final attackerCaptured = createCaptured(attackerBase);
      final defenderCaptured = createCaptured(defenderBase, ability: 'Rattled');

      final manager = BattleManager(
        attackerCaptured,
        defenderCaptured,
        isTesting: true,
      );
      manager.ignoreRandom = true;

      // Use Growl (Stat loss only, no damage)
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        Move.findByName('Growl')!,
      );
      expect(manager.opponent.attackStage, -1);
      expect(manager.opponent.speedStage, 1);
    });
  });
}
