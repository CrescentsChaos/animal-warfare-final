import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/archetype_teams.dart';
import 'package:animal_warfare/game/ai_decision_engine.dart';
import 'package:animal_warfare/game/battle_models.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AudioService.isTesting = true;
    // Manually populate talismans with realistic effects for AI tests
    Talisman.allTalismans = [
      const Talisman(
        id: 'damp_rock',
        name: 'Damp Rock',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.weatherDuration,
            magnitude: 1.0,
          ),
        ],
      ),
      const Talisman(
        id: 'heat_rock',
        name: 'Heat Rock',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.weatherDuration,
            magnitude: 1.0,
          ),
        ],
      ),
      const Talisman(
        id: 'smooth_rock',
        name: 'Smooth Rock',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.weatherDuration,
            magnitude: 1.0,
          ),
        ],
      ),
      const Talisman(
        id: 'icy_rock',
        name: 'Icy Rock',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.weatherDuration,
            magnitude: 1.0,
          ),
        ],
      ),
      const Talisman(
        id: 'assault_vest',
        name: 'Assault Vest',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.blockStatusMoves,
            magnitude: 1.0,
          ),
        ],
      ),
      const Talisman(
        id: 'choice_band',
        name: 'Choice Band',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.choiceLock,
            magnitude: 1.5,
            stat: 'attack',
          ),
        ],
      ),
      const Talisman(
        id: 'choice_specs',
        name: 'Choice Specs',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.choiceLock,
            magnitude: 1.5,
            stat: 'power',
          ),
        ],
      ),
      const Talisman(
        id: 'choice_scarf',
        name: 'Choice Scarf',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.choiceLock,
            magnitude: 1.5,
            stat: 'speed',
          ),
        ],
      ),
      const Talisman(
        id: 'life_orb',
        name: 'Life Orb',
        description: '',
        effects: [
          TalismanEffect(type: TalismanEffectType.recoilDamage, magnitude: 1.1),
        ],
      ),
      const Talisman(
        id: 'focus_sash',
        name: 'Focus Sash',
        description: '',
        effects: [
          TalismanEffect(type: TalismanEffectType.oneHitSave, magnitude: 1.0),
        ],
      ),
      const Talisman(
        id: 'leftovers',
        name: 'Leftovers',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.onTurnHeal,
            magnitude: 0.0625,
          ),
        ],
      ),
      const Talisman(
        id: 'black_sludge',
        name: 'Black Sludge',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.conditionalHeal,
            magnitude: 0.0625,
          ),
        ],
      ),
      const Talisman(
        id: 'rocky_helmet',
        name: 'Rocky Helmet',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.contactDamage,
            magnitude: 0.16,
          ),
        ],
      ),
      const Talisman(
        id: 'power_herb',
        name: 'Power Herb',
        description: '',
        effects: [
          TalismanEffect(type: TalismanEffectType.powerHerb, magnitude: 1.0),
        ],
      ),
      const Talisman(
        id: 'fire_gem',
        name: 'Fire Gem',
        description: '',
        effects: [
          TalismanEffect(type: TalismanEffectType.gemBoost, magnitude: 1.5),
        ],
      ),
      const Talisman(
        id: 'muscle_band',
        name: 'Muscle Band',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.categoryDamageBoost,
            magnitude: 1.1,
            category: 'physical',
          ),
        ],
      ),
      const Talisman(
        id: 'wise_glasses',
        name: 'Wise Glasses',
        description: '',
        effects: [
          TalismanEffect(
            type: TalismanEffectType.categoryDamageBoost,
            magnitude: 1.1,
            category: 'special',
          ),
        ],
      ),
    ];

    // Add a test move
    Move.addTestMove(
      const Move(
        name: 'Solar Beam',
        type: ElementalType.grass,
        category: MoveCategory.special,
        baseDamage: 120,
        accuracy: 100,
        stamina: 10,
        description: 'A multi-turn move.',
        effects: [MoveEffect(type: MoveEffectType.charge)],
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Protect',
        type: ElementalType.basic,
        category: MoveCategory.status,
        baseDamage: 0,
        accuracy: 100,
        stamina: 10,
        description: 'Protects the user.',
        effects: [MoveEffect(type: MoveEffectType.protect)],
      ),
    );
    Move.addTestMove(
      const Move(
        name: 'Struggle',
        type: ElementalType.basic,
        category: MoveCategory.physical,
        baseDamage: 50,
        accuracy: 100,
        stamina: 10,
        description: 'Desperate attack.',
      ),
    );
  });

  group('Archetype Item Assignment Tests', () {
    final baseOrganism = Organism(
      name: 'Test Mon',
      scientificName: 'Testus',
      habitat: 'Test',
      drops: '',
      attack: 50,
      defense: 50,
      power: 50,
      resistance: 50,
      health: 100,
      speed: 50,
      abilities: 'Drought, Drizzle, Sand Stream, Snow Warning',
      category: 'Basic',
      moves:
          'Struggle', // Default to single-turn move to avoid Power Herb priority in HO test
      sprite: '',
      rarity: 'Common',
      description: '',
    );

    test('Sun setter gets Heat Rock', () {
      final sunMon = baseOrganism.copyWith(abilities: 'Drought');
      final team = ArchetypeTeamBuilder.buildForArchetype(
        TeamArchetype.sunTeam,
        [sunMon],
        teamSize: 1,
      );
      expect(team.first.equippedTalisman?.name, 'Heat Rock');
    });

    test('Rain setter gets Damp Rock', () {
      final rainMon = baseOrganism.copyWith(abilities: 'Drizzle');
      final team = ArchetypeTeamBuilder.buildForArchetype(
        TeamArchetype.rainTeam,
        [rainMon],
        teamSize: 1,
      );
      expect(team.first.equippedTalisman?.name, 'Damp Rock');
    });

    test('Stall archetype gets defensive items', () {
      final stallMon = baseOrganism.copyWith(defense: 120, resistance: 120);
      final team = ArchetypeTeamBuilder.buildForArchetype(TeamArchetype.stall, [
        stallMon,
      ], teamSize: 1);
      final itemName = team.first.equippedTalisman?.name;
      expect(
        [
          'Leftovers',
          'Black Sludge',
          'Rocky Helmet',
          'Assault Vest',
        ].contains(itemName),
        isTrue,
        reason: 'Stall mon should have defensive item, got $itemName',
      );
    });

    test('Hyper Offense gets offensive items or Gems', () {
      final hoMon = baseOrganism.copyWith(
        attack: 130,
        speed: 110,
        types: ['blaze'],
      );
      final team = ArchetypeTeamBuilder.buildForArchetype(
        TeamArchetype.hyperOffense,
        [hoMon],
        teamSize: 1,
      );
      final itemName = team.first.equippedTalisman?.name;
      // Since it has no multi-turn moves now, it should NOT get Power Herb
      expect(
        [
          'Choice Band',
          'Choice Scarf',
          'Life Orb',
          'Focus Sash',
          'Fire Gem',
          'Muscle Band',
          'Wise Glasses',
        ].contains(itemName),
        isTrue,
        reason:
            'Hyper Offense should get offensive items or Gems, got $itemName',
      );
      expect(itemName, isNot(equals('Power Herb')));
    });

    test('Power Herb assigned for multi-turn moves', () {
      final herbMon = baseOrganism.copyWith(moves: 'Solar Beam', power: 120);
      final team = ArchetypeTeamBuilder.buildForArchetype(
        TeamArchetype.balanced,
        [herbMon],
        teamSize: 1,
      );
      expect(team.first.equippedTalisman?.name, 'Power Herb');
    });
  });

  group('AI Decision Engine Item Awareness Tests', () {
    test('AI penalizes choosing status move with Choice item', () {
      final attackerOrg = Organism(
        name: 'Attacker',
        scientificName: '',
        habitat: '',
        drops: '',
        attack: 100,
        defense: 100,
        power: 100,
        resistance: 100,
        health: 100,
        speed: 100,
        abilities: '',
        category: 'Basic',
        moves: 'Protect, Struggle',
        sprite: '',
        rarity: '',
        description: '',
      );
      final attackerCaptured = CapturedOrganism.spawn(attackerOrg)
        ..selectedMoveNames = ['Protect', 'Struggle'];
      // Use Choice Band - it HAS choiceLock effect now
      attackerCaptured.equippedTalisman = Talisman.findByName('Choice Band');

      final attacker = BattleOrganism(attackerCaptured);
      // We don't even need isChoiceLocked = true to see the penalty in calculateMoveScore
      // because the score penalty is based on having the Choice item and selecting a status move.

      final defenderOrg = Organism(
        name: 'Defender',
        scientificName: '',
        habitat: '',
        drops: '',
        attack: 100,
        defense: 100,
        power: 100,
        resistance: 100,
        health: 100,
        speed: 100,
        abilities: '',
        category: 'Basic',
        moves: 'Struggle',
        sprite: '',
        rarity: '',
        description: '',
      );
      final defender = BattleOrganism(
        CapturedOrganism.spawn(defenderOrg)..selectedMoveNames = ['Struggle'],
      );

      final statusMove = Move.findByName('Protect')!;
      final attackMove = Move.findByName('Struggle')!;

      final scoreStatus = AIDecisionEngine.calculateMoveScore(
        move: statusMove,
        attacker: attacker,
        defender: defender,
        damageResult: const DamageResult(0, 1.0, false),
        targetHazards: [],
        currentEffect: const WeatherEffect(weather: Weather.none),
        currentTerrain: const TerrainEffect(terrain: Terrain.none),
      );

      final scoreAttack = AIDecisionEngine.calculateMoveScore(
        move: attackMove,
        attacker: attacker,
        defender: defender,
        damageResult: const DamageResult(20, 1.0, false),
        targetHazards: [],
        currentEffect: const WeatherEffect(weather: Weather.none),
        currentTerrain: const TerrainEffect(terrain: Terrain.none),
      );

      // scoreStatus should be heavily penalized (-400)
      expect(
        scoreStatus,
        lessThan(scoreAttack - 350),
        reason:
            'Status move with Choice item should be heavily penalized. Status: $scoreStatus, Attack: $scoreAttack',
      );
    });

    test('AI prioritizes multi-turn move with Power Herb', () {
      final attackerOrg = Organism(
        name: 'Attacker',
        scientificName: '',
        habitat: '',
        drops: '',
        attack: 100,
        defense: 100,
        power: 100,
        resistance: 100,
        health: 100,
        speed: 100,
        abilities: '',
        category: 'Basic',
        moves: 'Solar Beam, Struggle',
        sprite: '',
        rarity: '',
        description: '',
      );
      final attackerCaptured = CapturedOrganism.spawn(attackerOrg)
        ..selectedMoveNames = ['Solar Beam', 'Struggle'];

      final attackerNoHerb = BattleOrganism(attackerCaptured);

      final attackerWithHerbCaptured = CapturedOrganism.spawn(attackerOrg)
        ..selectedMoveNames = ['Solar Beam', 'Struggle'];
      attackerWithHerbCaptured.equippedTalisman = Talisman.findByName(
        'Power Herb',
      );
      final attackerWithHerb = BattleOrganism(attackerWithHerbCaptured);

      final defenderOrg = Organism(
        name: 'Defender',
        scientificName: '',
        habitat: '',
        drops: '',
        attack: 100,
        defense: 100,
        power: 100,
        resistance: 100,
        health: 100,
        speed: 100,
        abilities: '',
        category: 'Basic',
        moves: 'Struggle',
        sprite: '',
        rarity: '',
        description: '',
      );
      final defender = BattleOrganism(
        CapturedOrganism.spawn(defenderOrg)..selectedMoveNames = ['Struggle'],
      );

      final multiTurnMove = Move.findByName('Solar Beam')!;

      final scoreNoHerb = AIDecisionEngine.calculateMoveScore(
        move: multiTurnMove,
        attacker: attackerNoHerb,
        defender: defender,
        damageResult: const DamageResult(100, 1.0, false),
        targetHazards: [],
        currentEffect: const WeatherEffect(weather: Weather.none),
        currentTerrain: const TerrainEffect(terrain: Terrain.none),
      );

      final scoreWithHerb = AIDecisionEngine.calculateMoveScore(
        move: multiTurnMove,
        attacker: attackerWithHerb,
        defender: defender,
        damageResult: const DamageResult(100, 1.0, false),
        targetHazards: [],
        currentEffect: const WeatherEffect(weather: Weather.none),
        currentTerrain: const TerrainEffect(terrain: Terrain.none),
      );

      // scoreWithHerb should be higher than scoreNoHerb because of Power Herb synergy (+150)
      expect(scoreWithHerb, greaterThan(scoreNoHerb + 100));
    });
  });
}
