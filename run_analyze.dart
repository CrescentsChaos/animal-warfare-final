import 'dart:io';

void main() async {
  print('Running flutter analyze...');
  final result = await Process.run('flutter', [
    'analyze',
    'lib/battle_screen.dart',
    'lib/user_state.dart',
  ]);
  final output = result.stdout.toString() + '\n' + result.stderr.toString();
  final lines = output.split('\n');
  for (final line in lines) {
    if (line.contains('error -')) {
      print('FOUND ERROR: ${line.trim()}');
    }
  }
}
