// lib/models/rogue_like_state.dart
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/organism.dart';

class RogueLikeState {
  final int floor;
  final List<CapturedOrganism> team;
  final bool isActive;
  final int highestFloor;
  final int encounterIndex; // 0-4
  final String? currentBiome;
  final List<CapturedOrganism>? opponentTeam;
  final int currentOpponentIndex;

  const RogueLikeState({
    this.floor = 1,
    this.team = const [],
    this.isActive = false,
    this.highestFloor = 0,
    this.encounterIndex = 0,
    this.currentBiome,
    this.opponentTeam,
    this.currentOpponentIndex = 0,
  });

  RogueLikeState copyWith({
    int? floor,
    List<CapturedOrganism>? team,
    bool? isActive,
    int? highestFloor,
    int? encounterIndex,
    String? currentBiome,
    List<CapturedOrganism>? opponentTeam,
    int? currentOpponentIndex,
  }) {
    return RogueLikeState(
      floor: floor ?? this.floor,
      team: team ?? this.team,
      isActive: isActive ?? this.isActive,
      highestFloor: highestFloor ?? this.highestFloor,
      encounterIndex: encounterIndex ?? this.encounterIndex,
      currentBiome: currentBiome ?? this.currentBiome,
      opponentTeam: opponentTeam ?? this.opponentTeam,
      currentOpponentIndex: currentOpponentIndex ?? this.currentOpponentIndex,
    );
  }

  Map<String, dynamic> toJson() => {
    'floor': floor,
    'team': team.map((co) => co.toJson()).toList(),
    'isActive': isActive,
    'highestFloor': highestFloor,
    'encounterIndex': encounterIndex,
    'currentBiome': currentBiome,
    'opponentTeam': opponentTeam?.map((co) => co.toJson()).toList(),
    'currentOpponentIndex': currentOpponentIndex,
  };

  factory RogueLikeState.fromJson(
    Map<String, dynamic> json,
    List<Organism> allOrganisms,
  ) {
    final List<dynamic> teamJson = json['team'] ?? [];
    final List<CapturedOrganism> teamList = teamJson
        .map(
          (coJson) => CapturedOrganism.fromJson(
            coJson as Map<String, dynamic>,
            allOrganisms,
          ),
        )
        .whereType<CapturedOrganism>()
        .toList();

    final List<CapturedOrganism> opponentTeamList =
        (json['opponentTeam'] as List? ?? [])
            .map(
              (coJson) => CapturedOrganism.fromJson(
                coJson as Map<String, dynamic>,
                allOrganisms,
              ),
            )
            .whereType<CapturedOrganism>()
            .toList();

    return RogueLikeState(
      floor: json['floor'] as int? ?? 1,
      team: teamList,
      isActive: json['isActive'] as bool? ?? false,
      highestFloor: json['highestFloor'] as int? ?? 0,
      encounterIndex: json['encounterIndex'] as int? ?? 0,
      currentBiome: json['currentBiome'] as String?,
      opponentTeam: opponentTeamList.isEmpty ? null : opponentTeamList,
      currentOpponentIndex: json['currentOpponentIndex'] as int? ?? 0,
    );
  }
}
