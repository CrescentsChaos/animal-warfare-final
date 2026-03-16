// lib/game/npc_team_loader.dart

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/nature.dart';

/// Loads NPC trainer teams from assets/npc_teams.json and builds
/// CapturedOrganism teams for battle.
class NpcTeamLoader {
  static List<Map<String, dynamic>>? _teamsData;

  /// Load the JSON file. Call once at startup.
  static Future<void> loadData() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/npc_teams.json');
      final List<dynamic> parsed = json.decode(jsonStr) as List<dynamic>;
      _teamsData = parsed.map((e) => e as Map<String, dynamic>).toList();
      print('NpcTeamLoader: Successfully loaded ${_teamsData?.length} teams.');
    } catch (e, stack) {
      print('NpcTeamLoader Error loading npc_teams.json: $e');
      print(stack);
      _teamsData = [];
    }
  }

  /// Get the trainer name for a given teamId.
  static String getTrainerName(String teamId) {
    if (_teamsData == null) return teamId;
    for (final entry in _teamsData!) {
      if (entry['teamId'] == teamId) {
        return entry['trainerName'] as String? ?? teamId;
      }
    }
    return teamId;
  }

  /// Build a list of CapturedOrganism from a teamId for battle.
  static List<CapturedOrganism> buildTeam(
    String teamId,
    List<Organism> allOrganisms,
  ) {
    if (_teamsData == null) return [];

    Map<String, dynamic>? teamEntry;
    for (final entry in _teamsData!) {
      if (entry['teamId'] == teamId) {
        teamEntry = entry;
        break;
      }
    }
    if (teamEntry == null) return [];

    final animals = teamEntry['animals'] as List<dynamic>? ?? [];
    final List<CapturedOrganism> team = [];

    for (final animalJson in animals) {
      final map = animalJson as Map<String, dynamic>;
      final name = map['name'] as String;
      final level = map['level'] as int? ?? 10;
      final natureName = map['nature'] as String? ?? 'Hardy';
      final ability = map['ability'] as String?;

      // Find base organism
      Organism? base;
      try {
        base = allOrganisms.firstWhere(
          (o) => o.name.toLowerCase() == name.toLowerCase(),
        );
      } catch (_) {
        print('NpcTeamLoader: Skipped unknown organism "$name" for team $teamId');
        continue; // Skip unknown organisms
      }

      // Parse IVs
      final ivsRaw = map['ivs'] as Map<String, dynamic>?;
      final ivs = ivsRaw != null
          ? ivsRaw.map((k, v) => MapEntry(k, v as int))
          : <String, int>{};

      // Parse KVs
      final kvsRaw = map['kvs'] as Map<String, dynamic>?;
      final kvs = kvsRaw != null
          ? kvsRaw.map((k, v) => MapEntry(k, v as int))
          : <String, int>{};

      // Parse moves
      final moves = map['moves'] != null
          ? List<String>.from(map['moves'] as List)
          : <String>[];

      final nature = Nature.findByName(natureName);

      final captured = CapturedOrganism(
        baseOrganism: base,
        individualValues: ivs,
        currentHealth: CapturedOrganism.calculateStat(
          'health',
          base.health,
          ivs['health'] ?? 15,
          level: level,
          kv: kvs['health'] ?? 0,
        ),
        level: level,
        xp: CapturedOrganism.xpForLevel(level),
        initialLevel: level,
        nature: nature,
        killValues: kvs,
        activeAbilityName: ability,
        selectedMoveNames: moves,
      );

      // Re-initialize moves if none provided
      if (moves.isEmpty) {
        captured.initializeDefaultMoves();
      }

      team.add(captured);
    }

    return team;
  }
}
