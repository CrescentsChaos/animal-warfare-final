import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mock audio channels to prevent errors in tests
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'),
        (MethodCall methodCall) async => null,
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'),
        (MethodCall methodCall) async => null,
      );

  group('New Moves Comprehensive Tests', () {
    late BattleManager manager;
    late CapturedOrganism playerOrg;
    late CapturedOrganism opponentOrg;

    // Manual Moves for testing to avoid rootBundle errors
    final sacredSword = Move(
      name: 'Sacred Sword',
      description: 'Test',
      baseDamage: 90,
      type: ElementalType.basic,
    );
    final smartStrike = Move(
      name: 'Smart Strike',
      description: 'Test',
      baseDamage: 70,
      type: ElementalType.basic,
    );
    final retaliate = Move(
      name: 'Retaliate',
      description: 'Test',
      baseDamage: 70,
      type: ElementalType.basic,
    );
    final laserFocus = Move(
      name: 'Laser Focus',
      description: 'Test',
      baseDamage: 0,
      type: ElementalType.basic,
      category: MoveCategory.status,
    );
    final whirlwind = Move(
      name: 'Whirlwind',
      description: 'Test',
      baseDamage: 0,
      type: ElementalType.flying,
      category: MoveCategory.status,
      priority: -6,
    );
    final endeavor = Move(
      name: 'Endeavor',
      description: 'Test',
      baseDamage: 1,
      type: ElementalType.basic,
    );
    final solarBeam = Move(
      name: 'Solar Beam',
      description: 'Test',
      baseDamage: 120,
      type: ElementalType.grass,
      category: MoveCategory.special,
      effects: const [MoveEffect(type: MoveEffectType.charge)],
    );
    final naturesMadness = Move(
      name: 'Nature\'s Madness',
      description: 'Test',
      baseDamage: 1,
      type: ElementalType.mystic,
      category: MoveCategory.special,
    );
    final brickBreak = Move(
      name: 'Brick Break',
      description: 'Test',
      baseDamage: 75,
      type: ElementalType.basic,
    );
    final thrash = Move(
      name: 'Thrash',
      description: 'Test',
      baseDamage: 120,
      type: ElementalType.basic,
    );
    final brine = Move(
      name: 'Brine',
      description: 'Test',
      baseDamage: 65,
      type: ElementalType.aquatic,
      category: MoveCategory.special,
    );
    final scaleShot = Move(
      name: 'Scale Shot',
      description: 'Test',
      baseDamage: 25,
      type: ElementalType.drake,
      effects: const [MoveEffect(type: MoveEffectType.none)],
      minHits: 2,
      maxHits: 5,
    );

    Organism createBase(String name, {int hp = 100, int def = 50}) {
      return Organism(
        name: name,
        scientificName: 'Test',
        habitat: 'Test',
        drops: '',
        attack: 50,
        defense: def,
        power: 50,
        resistance: 50,
        health: hp,
        speed: 50,
        abilities: '',
        category: 'Test',
        moves: '',
        sprite: '',
        rarity: 'Common',
        description: 'Test',
        types: ['basic'],
      );
    }

    CapturedOrganism createCaptured(Organism base, {int level = 50}) {
      return CapturedOrganism(
        baseOrganism: base,
        level: level,
        individualValues: {
          'health': 15,
          'attack': 15,
          'defense': 15,
          'power': 15,
          'resistance': 15,
          'speed': 15,
        },
        currentHealth: 100,
        selectedMoveNames: [],
      );
    }

    setUp(() {
      playerOrg = createCaptured(createBase('Player'));
      opponentOrg = createCaptured(createBase('Opponent'));
      playerOrg.currentHealth = playerOrg.maxHealth;
      opponentOrg.currentHealth = opponentOrg.maxHealth;

      manager = BattleManager(
        playerOrg,
        opponentOrg,
        isTesting: true,
        isArenaBattle: true,
      );
      manager.ignoreRandom = true;
    });

    test('Sacred Sword ignores defense stages', () async {
      manager.opponent.defenseStage = 6;
      final res = manager.calculateDamage(
        manager.player,
        manager.opponent,
        sacredSword,
      );
      manager.opponent.defenseStage = 0;
      final res2 = manager.calculateDamage(
        manager.player,
        manager.opponent,
        sacredSword,
      );
      expect(res.damage, equals(res2.damage));
    });

    test('Smart Strike never misses', () async {
      manager.ignoreRandom = false;
      manager.opponent.evasionStage = 6;
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        smartStrike,
      );
      expect(manager.opponent.health, lessThan(opponentOrg.maxHealth));
    });

    test('Retaliate doubles damage if teammate fainted last turn', () async {
      final dmgNormal = manager.calculateDamage(
        manager.player,
        manager.opponent,
        retaliate,
        ignoreRandom: true,
      );
      manager.lastPlayerFaintTurn = manager.currentTurn - 1;
      final dmgRetaliate = manager.calculateDamage(
        manager.player,
        manager.opponent,
        retaliate,
        ignoreRandom: true,
      );
      expect(dmgRetaliate.damage, equals(dmgNormal.damage * 2));
    });

    test('Endeavor equalizes HP', () async {
      manager.player.health = 10;
      manager.opponent.health = 100;
      final dmgResult = manager.calculateDamage(
        manager.player,
        manager.opponent,
        endeavor,
      );
      expect(dmgResult.damage, equals(90));
    });

    test('Nature\'s Madness deals 50% current HP', () async {
      manager.opponent.health = 100;
      final dmgResult = manager.calculateDamage(
        manager.player,
        manager.opponent,
        naturesMadness,
      );
      expect(dmgResult.damage, equals(50));
    });

    test('Brine doubles power at low HP', () async {
      final dmgFull = manager.calculateDamage(
        manager.player,
        manager.opponent,
        brine,
        ignoreRandom: true,
      );
      manager.opponent.health = (manager.opponent.maxHealth * 0.4).floor();
      final dmgLow = manager.calculateDamage(
        manager.player,
        manager.opponent,
        brine,
        ignoreRandom: true,
      );
      expect(dmgLow.damage, greaterThan(dmgFull.damage * 1.5));
    });

    test('Solar Beam skips charge in sun', () async {
      manager.currentWeather = const WeatherEffect(weather: Weather.sunny);
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        solarBeam,
      );
      expect(manager.player.chargingMove, isNull);
      expect(manager.opponent.health, lessThan(opponentOrg.maxHealth));
    });

    test('Laser Focus guaranteed crit', () async {
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        laserFocus,
      );
      final res = manager.calculateDamage(
        manager.player,
        manager.opponent,
        sacredSword,
      );
      expect(res.isCrit, isTrue);
    });

    test('Brick Break shatters screens', () async {
      manager.opponentReflectTurns = 5;
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        brickBreak,
      );
      expect(manager.opponentReflectTurns, equals(0));
    });

    test('Scale Shot lowers Defense, raises Speed', () async {
      await manager.testExecuteTurn(
        manager.player,
        manager.opponent,
        scaleShot,
      );
      expect(manager.player.defenseStage, equals(-1));
      expect(manager.player.speedStage, equals(1));
    });

    test('Thrash locks user', () async {
      await manager.testExecuteTurn(manager.player, manager.opponent, thrash);
      expect(manager.player.thrashTurnCount, greaterThan(0));
      expect(manager.player.thrashMove?.name, equals('Thrash'));
    });

    test('Whirlwind forces switch in Arena Battle', () async {
      final teammate = createCaptured(createBase('Teammate'));
      teammate.currentHealth = teammate.maxHealth;

      final m2 = BattleManager(
        playerOrg,
        opponentOrg,
        opponentTeam: [opponentOrg, teammate],
        isArenaBattle: true,
        isTesting: true,
      );
      m2.ignoreRandom = true;

      await m2.testExecuteTurn(m2.player, m2.opponent, whirlwind);
      expect(m2.currentOpponentIndex, equals(1));
      expect(m2.opponent.organism, equals(teammate));
    });
  });
}
