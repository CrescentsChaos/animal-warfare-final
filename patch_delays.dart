import 'dart:io';

void main() {
  final file = File('lib/game/battle_manager.dart');
  final lines = file.readAsLinesSync();
  bool changed = false;

  for (int i = 0; i < lines.length; i++) {
    if (lines[i].contains('await Future.delayed(') &&
        !lines[i].contains('isTesting')) {
      bool safe = false;
      for (int j = i; j >= 0 && j >= i - 2; j--) {
        if (lines[j].contains('isTesting')) {
          safe = true;
          break;
        }
      }
      if (!safe) {
        // Simply prepend `if (!isTesting) ` preserving the leading whitespace
        final match = RegExp(r'^(\s*)(.*)$').firstMatch(lines[i]);
        if (match != null) {
          final whitespace = match.group(1);
          final rest = match.group(2);
          lines[i] = '\$whitespace' + 'if (!isTesting) ' + rest!;
          changed = true;
          print('Patched line \${i + 1}');
        }
      }
    }
  }

  if (changed) {
    file.writeAsStringSync(lines.join('\n') + '\n');
    print('File updated successfully.');
  } else {
    print('No changes needed.');
  }
}
