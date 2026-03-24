import 'dart:convert';
import 'dart:io';

void main() async {
  final file = File('assets/maps.json');
  if (!await file.exists()) {
    print('assets/maps.json not found!');
    return;
  }

  final content = await file.readAsString();
  final List<dynamic> mapsArray = jsonDecode(content);

  // 1. Build map heights dictionary
  final heights = <String, int>{};
  for (final mapData in mapsArray) {
    if (mapData is Map<String, dynamic>) {
      final id = mapData['id'] as String;
      final layout = mapData['layout'] as Map<String, dynamic>;
      final base = layout['base'] as List<dynamic>;
      heights[id] = base.length;
    }
  }

  // 2. Iterate and flip Y values back to Top-Down
  for (final mapData in mapsArray) {
    if (mapData is Map<String, dynamic>) {
      final id = mapData['id'] as String;
      final int h = heights[id]!;

      // Spawn Point
      if (mapData['spawnPoint'] != null) {
        final sp = mapData['spawnPoint'] as Map<String, dynamic>;
        if (sp.containsKey('y')) {
          final int oldY = sp['y'] as int;
          sp['y'] = h - 1 - oldY;
        }
      }

      // Transitions
      if (mapData['transitions'] != null) {
        final transitions = mapData['transitions'] as List<dynamic>;
        for (final t in transitions) {
          final tMap = t as Map<String, dynamic>;
          if (tMap.containsKey('y')) {
            final int oldY = tMap['y'] as int;
            tMap['y'] = h - 1 - oldY;
          }

          final targetMapId = tMap['targetMap'] as String;
          if (heights.containsKey(targetMapId) && tMap.containsKey('targetY')) {
            final targetH = heights[targetMapId]!;
            final int oldTargetY = tMap['targetY'] as int;
            tMap['targetY'] = targetH - 1 - oldTargetY;
          }
        }
      }

      // NPCs
      if (mapData['npcs'] != null) {
        final npcs = mapData['npcs'] as List<dynamic>;
        for (final npc in npcs) {
          final nMap = npc as Map<String, dynamic>;
          
          int? oldY = nMap['y'] as int?;
          if (oldY == null && nMap.containsKey('row')) {
             oldY = nMap['row'] as int?;
          }
           
          int? oldX = nMap['x'] as int?;
          if (oldX == null && nMap.containsKey('col')) {
             oldX = nMap['col'] as int?;
          }

          if (oldY != null) {
            nMap['y'] = h - 1 - oldY;
          }
          if (oldX != null) {
            nMap['x'] = oldX;
          }
          
          nMap.remove('row');
          nMap.remove('col');
        }
      }
    }
  }

  // 3. Write back neatly
  final newContent = JsonEncoder.withIndent('    ').convert(mapsArray);
  await file.writeAsString(newContent);
  print('Successfully converted maps.json to Top-Down Y coords and migrated row/col to y/x.');
}
