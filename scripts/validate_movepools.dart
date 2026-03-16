// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

void main() {
  final movesFile = File('assets/moves.json');
  final organismsFile = File('assets/Organisms.json');

  if (!movesFile.existsSync() || !organismsFile.existsSync()) {
    print('Error: Could not find assets/moves.json or assets/Organisms.json');
    return;
  }

  final movesData = json.decode(movesFile.readAsStringSync()) as List;
  final validMoves = movesData
      .map((m) => (m['name'] as String).toLowerCase().trim())
      .toSet();

  final organismsData = json.decode(organismsFile.readAsStringSync()) as List;

  final Map<String, int> missingMovesCount = {};

  for (final org in organismsData) {
    final movesStr = org['moves'] as String?;
    if (movesStr == null || movesStr.isEmpty) continue;

    final moves = movesStr
        .split(',')
        .map((m) => m.toLowerCase().trim())
        .where((m) => m.isNotEmpty);
    for (final move in moves) {
      if (!validMoves.contains(move) && move != 'struggle') {
        missingMovesCount[move] = (missingMovesCount[move] ?? 0) + 1;
      }
    }
  }

  final sortedMissing = missingMovesCount.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  print('Top 50 missing moves:');
  for (var i = 0; i < sortedMissing.length && i < 50; i++) {
    print('${sortedMissing[i].key}: ${sortedMissing[i].value}');
  }
}
