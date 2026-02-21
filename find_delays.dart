import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    if (file.path.contains('battle_screen')) continue; // Ignore UI screens
    final lines = file.readAsLinesSync();
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('Future.delayed')) {
        bool safe = false;
        // Check current line and previous 3 lines for 'isTesting'
        for (int j = i; j >= 0 && j >= i - 3; j--) {
          if (lines[j].contains('isTesting')) {
            safe = true;
            break;
          }
        }
        if (!safe) {
          print(
            file.path + ' Line ' + (i + 1).toString() + ': ' + lines[i].trim(),
          );
        }
      }
    }
  }
}
