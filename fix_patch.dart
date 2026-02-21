import 'dart:io';

void main() {
  final file = File('lib/game/battle_manager.dart');
  String contents = file.readAsStringSync();
  contents = contents.replaceAll(
    r'$whitespaceif (!isTesting) await Future.delayed',
    '    if (!isTesting) await Future.delayed',
  );
  file.writeAsStringSync(contents);
  print('Done fixing battle_manager!');
}
