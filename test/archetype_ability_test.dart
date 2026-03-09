import 'package:flutter_test/flutter_test.dart';
import 'package:animal_warfare/game/archetype_teams.dart';
import 'package:animal_warfare/game/ai_decision_engine.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    AudioService.isTesting = true;
  });

  group('ArchetypeTeamBuilder Ability Selection Tests', () {
    test('Chaos archetype randomizes abilities', () {
      final organism = Organism(
        name: 'Test Cat',
        scientificName: 'Felis testus',
        habitat: 'Test',
        drops: '',
        attack: 50,
        defense: 50,
        power: 50,
        resistance: 50,
        health: 50,
        speed: 50,
        abilities: 'Ability A, Ability B, Ability C',
        category: 'Basic',
        moves: 'Struggle',
        sprite: '',
        rarity: 'Common',
        description: '',
      );

      final abilitiesSeen = <String>{};

      // Run multiple times to see different abilities (statistically likely)
      for (int i = 0; i < 50; i++) {
        final team = ArchetypeTeamBuilder.buildChaos([organism], teamSize: 1);
        abilitiesSeen.add(team.first.activeAbilityName ?? 'None');
      }

      // It should have seen more than just the first ability
      expect(
        abilitiesSeen.length,
        greaterThan(1),
        reason: 'Chaos should select more than just the first ability',
      );
    });

    test('Sun archetype prioritizes Drought', () {
      final droughtOrganism = Organism(
        name: 'Sun Fox',
        scientificName: 'Vulpes solaris',
        habitat: 'Test',
        drops: '',
        attack: 50,
        defense: 50,
        power: 50,
        resistance: 50,
        health: 50,
        speed: 50,
        abilities: 'Prankster, Drought',
        category: 'Blaze',
        moves: 'Sunny Day',
        sprite: '',
        rarity: 'Common',
        description: '',
      );

      final team = ArchetypeTeamBuilder.buildForArchetype(
        TeamArchetype.sunTeam,
        [droughtOrganism],
        teamSize: 1,
      );

      expect(team.first.activeAbilityName, 'Drought');
    });

    test('Rain archetype prioritizes Drizzle', () {
      final drizzleOrganism = Organism(
        name: 'Rain Bird',
        scientificName: 'Aves pluvia',
        habitat: 'Test',
        drops: '',
        attack: 50,
        defense: 50,
        power: 50,
        resistance: 50,
        health: 50,
        speed: 50,
        abilities: 'Infiltrator, Drizzle',
        category: 'Aquatic',
        moves: 'Rain Dance',
        sprite: '',
        rarity: 'Common',
        description: '',
      );

      final team = ArchetypeTeamBuilder.buildForArchetype(
        TeamArchetype.rainTeam,
        [drizzleOrganism],
        teamSize: 1,
      );

      expect(team.first.activeAbilityName, 'Drizzle');
    });

    test(
      'Archetype synergy: Sun Team prioritizes Chlorophyll if Drought is not present',
      () {
        final chloroOrganism = Organism(
          name: 'Sun Plant',
          scientificName: 'Planta solaris',
          habitat: 'Test',
          drops: '',
          attack: 50,
          defense: 50,
          power: 50,
          resistance: 50,
          health: 50,
          speed: 50,
          abilities: 'Leaf Guard, Chlorophyll',
          category: 'Grass',
          moves: 'Struggle',
          sprite: '',
          rarity: 'Common',
          description: '',
        );

        final team = ArchetypeTeamBuilder.buildForArchetype(
          TeamArchetype.sunTeam,
          [chloroOrganism],
          teamSize: 1,
        );

        // Chlorophyll is 2nd in the list, but should be picked for Sun Team
        expect(team.first.activeAbilityName, 'Chlorophyll');
      },
    );
  });
}
