import 'package:animal_warfare/game/archetype_teams.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/move.dart';
import 'dart:convert';
import 'dart:io';

void main() async {
  print('--- Verifying Item Overhaul ---');

  // 1. Load data
  final talismansJson = json.decode(
    File('assets/talismans.json').readAsStringSync(),
  );
  Talisman.loadAll(talismansJson);

  final movesJson = json.decode(File('assets/moves.json').readAsStringSync());
  Move.loadAll(movesJson);

  final organismsJson = json.decode(
    File('assets/organisms.json').readAsStringSync(),
  );
  final List<Organism> allOrganisms = (organismsJson as List)
      .map((j) => Organism.fromJson(j))
      .toList();

  // 2. Test 4x Weakness (E.g. an animal with 4x Fire weakness should get Occa Berry)
  // Let's find one or create a mock
  final mock4xFire = Organism(
    name: 'BugGrassTest',
    scientificName: 'Test',
    habitat: 'Test',
    drops: '',
    attack: 50,
    defense: 50,
    power: 50,
    resistance: 50,
    health: 50,
    speed: 50,
    abilities: '',
    category: 'Bug,Grass',
    types: ['arthropod', 'grass'], // 4x weak to blaze (fire)
    description: '',
  );

  final cap4x = CapturedOrganism(
    baseOrganism: mock4xFire,
    level: 50,
    selectedMoveNames: [],
  );

  final assigned4x = ArchetypeTeamBuilder.build([
    mock4xFire,
  ], allowChaos: false).team.first;
  print('4x Blaze weak animal item: ${assigned4x.equippedTalisman?.name}');
  if (assigned4x.equippedTalisman?.name == 'Occa Berry') {
    print('SUCCESS: Correctly assigned Occa Berry for 4x Blaze weakness.');
  }

  // 3. Test Rain Setter (Should get Damp Rock)
  final mockRainSetter = allOrganisms.firstWhere(
    (o) => o.abilities.toLowerCase().contains('drizzle'),
    orElse: () => allOrganisms.first,
  );
  final rainTeam = ArchetypeTeamBuilder.build(
    allOrganisms,
    allowChaos: false,
  ).team;
  // Note: build() picks a random archetype, might need multiple tries or specific check

  print('Verifying specific archetype logic...');
  // Since build() is randomized, we could test _assignTalisman directly if it was public, but it's static private.
  // We'll rely on current logic and check a few samples from build().

  print('Checking random team items:');
  for (int i = 0; i < 5; i++) {
    final result = ArchetypeTeamBuilder.build(allOrganisms, allowChaos: false);
    print('Archetype: ${result.archetypeName}');
    for (final org in result.team) {
      final gemUsed = org.equippedTalisman?.name.contains('Gem') ?? false;
      print(
        '  - ${org.baseOrganism.name}: ${org.equippedTalisman?.name} ${gemUsed ? "(GEM!)" : ""}',
      );
    }
  }

  print('--- Verification Complete ---');
}
