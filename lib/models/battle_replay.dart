// lib/models/battle_replay.dart
import 'package:animal_warfare/game/battle_manager.dart';

class ReplayTurn {
  final int turnNumber;
  final List<String> entries;

  const ReplayTurn({required this.turnNumber, required this.entries});

  Map<String, dynamic> toJson() => {
    'turnNumber': turnNumber,
    'entries': entries,
  };

  factory ReplayTurn.fromJson(Map<String, dynamic> json) => ReplayTurn(
    turnNumber: json['turnNumber'] as int,
    entries: List<String>.from(json['entries'] as List),
  );
}

class BattleReplay {
  final String id;
  final DateTime timestamp;
  final String result; // 'win', 'loss', 'capture', 'fled'
  final List<String> playerTeamNames;
  final List<String> opponentTeamNames;
  final int turnCount;
  final List<ReplayTurn> turns;
  final String? biome;

  const BattleReplay({
    required this.id,
    required this.timestamp,
    required this.result,
    required this.playerTeamNames,
    required this.opponentTeamNames,
    required this.turnCount,
    required this.turns,
    this.biome,
  });

  /// Creates a BattleReplay snapshot from a completed BattleManager.
  factory BattleReplay.fromBattle(BattleManager bm) {
    final resultStr = switch (bm.result) {
      BattleResult.win => 'win',
      BattleResult.loss => 'loss',
      BattleResult.capture => 'capture',
      BattleResult.fled => 'fled',
      _ => 'unknown',
    };

    return BattleReplay(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      result: resultStr,
      playerTeamNames: bm.playerTeam.map((o) => o.baseOrganism.name).toList(),
      opponentTeamNames: bm.opponentTeam
          .map((o) => o.baseOrganism.name)
          .toList(),
      turnCount: bm.currentTurn,
      turns: bm.turnHistory
          .map(
            (t) => ReplayTurn(
              turnNumber: t.turnNumber,
              entries: List<String>.from(t.logEntries),
            ),
          )
          .toList(),
      biome: bm.biomeName,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'result': result,
    'playerTeamNames': playerTeamNames,
    'opponentTeamNames': opponentTeamNames,
    'turnCount': turnCount,
    'turns': turns.map((t) => t.toJson()).toList(),
    'biome': biome,
  };

  factory BattleReplay.fromJson(Map<String, dynamic> json) => BattleReplay(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    result: json['result'] as String,
    playerTeamNames: List<String>.from(json['playerTeamNames'] as List),
    opponentTeamNames: List<String>.from(json['opponentTeamNames'] as List),
    turnCount: json['turnCount'] as int,
    turns: (json['turns'] as List)
        .map((t) => ReplayTurn.fromJson(t as Map<String, dynamic>))
        .toList(),
    biome: json['biome'] as String?,
  );
}
