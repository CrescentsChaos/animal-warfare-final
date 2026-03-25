import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/terrain.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Organism createTestOrganism({
    String name = 'Test',
    List<ElementalType>? types,
    int attack = 100,
    int power = 100,
    int defense = 100,
    int resistance = 100,
  }) {
    return Organism(
      name: name,
      scientificName: 'Testus',
      habitat: 'Test',
      drops: '',
      attack: attack,
      defense: defense,
      power: power,
      resistance: resistance,
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

  group('New Moves Batch 2 Tests', () {
    late BattleManager manager;
    late BattleOrganism playerOrg;
    late BattleOrganism opponentOrg;

    setUp(() {
      AudioService.isTesting = true;

      final p = createCaptured(createTestOrganism(name: 'PlayerMon'));
      final o = createCaptured(createTestOrganism(name: 'OpponentMon'));

      manager = BattleManager(p, o, isTesting: true);
      playerOrg = manager.player;
      opponentOrg = manager.opponent;
    });

    test('Safeguard shields from status', () async {
      await manager.testExecuteTurn(
        playerOrg,
        opponentOrg,
        Move(
          name: 'Safeguard',
          baseDamage: 0,
          type: ElementalType.basic,
          category: MoveCategory.status,
          description: 'Test',
          accuracy: 100,
          stamina: 25,
          effects: [const MoveEffect(type: MoveEffectType.safeguard)],
        ),
      );

      expect(manager.playerSafeguardTurns, 5);

      final success = await manager.applyStatusEffect(playerOrg, StatusEffectType.poison);
      expect(success, false);
      expect(playerOrg.statusEffects.isEmpty, true);
    });

    test('Rapid Spin clears hazards and binding', () async {
      manager.playerHazards.add('spikes');
      manager.playerHazards.add('stealth_rock');
      playerOrg.clampingTurns = 3;
      playerOrg.isTrapped = true;

      await manager.testExecuteTurn(
        playerOrg,
        opponentOrg,
        Move(
          name: 'Rapid Spin',
          baseDamage: 50,
          type: ElementalType.basic,
          category: MoveCategory.physical,
          description: 'Test',
          accuracy: 100,
          stamina: 40,
          effects: [const MoveEffect(type: MoveEffectType.rapidSpin)],
        ),
      );

      expect(manager.playerHazards.isEmpty, true);
      expect(playerOrg.clampingTurns, 0);
      expect(playerOrg.isTrapped, false);
    });

    test('Defog clears hazards, screens, terrain, and safeguard', () async {
      manager.playerHazards.add('stealth_rock');
      manager.playerReflectTurns = 5;
      manager.playerSafeguardTurns = 5;
      manager.currentTerrain = const TerrainEffect(terrain: Terrain.electric, duration: 5);

      await manager.testExecuteTurn(
        opponentOrg, // from opponent to clear player side usually, but defog clears both
        playerOrg,
        Move(
          name: 'Defog',
          baseDamage: 0,
          type: ElementalType.flying,
          category: MoveCategory.status,
          description: 'Test',
          accuracy: 100,
          stamina: 15,
          effects: [const MoveEffect(type: MoveEffectType.defog)],
        ),
      );

      expect(manager.playerHazards.isEmpty, true);
      expect(manager.playerReflectTurns, 0);
      expect(manager.playerSafeguardTurns, 0);
      expect(manager.currentTerrain.terrain, Terrain.none);
    });

    test('Growth raises attack and power by 1 normally, 2 in Sun', () async {
      // Normal weather
      await manager.testExecuteTurn(
        playerOrg,
        opponentOrg,
        Move(
          name: 'Growth',
          baseDamage: 0,
          type: ElementalType.basic,
          category: MoveCategory.status,
          description: 'Test',
          accuracy: 100,
          stamina: 20,
          effects: [const MoveEffect(type: MoveEffectType.growth)],
        ),
      );

      expect(playerOrg.attackStage, 1);
      expect(playerOrg.powerStage, 1);

      playerOrg.resetStatStages();

      // Sunny weather
      manager.currentWeather = const WeatherEffect(weather: Weather.sunny, duration: 5);
      await manager.testExecuteTurn(
        playerOrg,
        opponentOrg,
        Move(
          name: 'Growth',
          baseDamage: 0,
          type: ElementalType.basic,
          category: MoveCategory.status,
          description: 'Test',
          accuracy: 100,
          stamina: 20,
          effects: [const MoveEffect(type: MoveEffectType.growth)],
        ),
      );

      expect(playerOrg.attackStage, 2);
      expect(playerOrg.powerStage, 2);
    });

    test('Stockpile/Swallow/Spit Up mechanics', () async {
      final stockpile = Move(
        name: 'Stockpile',
        baseDamage: 0,
        type: ElementalType.basic,
        category: MoveCategory.status,
          description: 'Test',
        accuracy: 100,
        stamina: 20,
        effects: [const MoveEffect(type: MoveEffectType.stockpile)],
      );

      final swallow = Move(
        name: 'Swallow',
        baseDamage: 0,
        type: ElementalType.basic,
        category: MoveCategory.status,
          description: 'Test',
        accuracy: 100,
        stamina: 10,
        effects: [const MoveEffect(type: MoveEffectType.swallow)],
      );

      final spitUp = Move(
        name: 'Spit Up',
        baseDamage: 0,
        type: ElementalType.basic,
        category: MoveCategory.special,
        description: 'Test',
        accuracy: 100,
        stamina: 10,
        effects: [const MoveEffect(type: MoveEffectType.spitUp)],
      );

      // 1. Stockpile twice
      await manager.testExecuteTurn(playerOrg, opponentOrg, stockpile);
      await manager.testExecuteTurn(playerOrg, opponentOrg, stockpile);

      expect(playerOrg.stockpileCount, 2);
      expect(playerOrg.defenseStage, 2);
      expect(playerOrg.resistanceStage, 2);

      // 2. Swallow (heals 50% for 2 stockpiles)
      playerOrg.health = 10; // set low health
      await manager.testExecuteTurn(playerOrg, opponentOrg, swallow);

      expect(playerOrg.stockpileCount, 0); // resets
      expect(playerOrg.defenseStage, 0); // resets
      expect(playerOrg.resistanceStage, 0); // resets
      expect(playerOrg.health, 10 + (playerOrg.maxHealth * 0.5).round());

      // 3. Stockpile again
      await manager.testExecuteTurn(playerOrg, opponentOrg, stockpile);
      expect(playerOrg.stockpileCount, 1);

      // 4. Spit Up Damage Scaling (100 * count)
      final spitUpDmg = manager.calculateDamage(playerOrg, opponentOrg, spitUp, ignoreRandom: true);
      
      // Stockpile again
      await manager.testExecuteTurn(playerOrg, opponentOrg, stockpile);
      final spitUpDmg2 = manager.calculateDamage(playerOrg, opponentOrg, spitUp, ignoreRandom: true);

      // 200 base power vs 100 base power means damage should be larger
      expect(spitUpDmg2.damage > spitUpDmg.damage, true);

      // 5. Spit Up execution removes stockpile
      await manager.testExecuteTurn(playerOrg, opponentOrg, spitUp);
      expect(playerOrg.stockpileCount, 0);
      expect(playerOrg.defenseStage, 0);
    });
    
    test('Payback damage doubled if target moves first', () {
      final payback = Move(
        name: 'Payback',
        baseDamage: 50,
        type: ElementalType.darkness,
        category: MoveCategory.physical,
        description: 'Test',
        accuracy: 100,
        stamina: 10,
        effects: [const MoveEffect(type: MoveEffectType.payback)],
      );

      opponentOrg.hasMovedThisTurn = false;
      final dmg1 = manager.calculateDamage(playerOrg, opponentOrg, payback, ignoreRandom: true);
      
      opponentOrg.hasMovedThisTurn = true;
      final dmg2 = manager.calculateDamage(playerOrg, opponentOrg, payback, ignoreRandom: true);

      expect(dmg2.damage > dmg1.damage, true);
    });
  });
}
