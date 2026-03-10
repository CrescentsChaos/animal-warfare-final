import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Habitat Parsing Logic', () {
    test('filters out empty and blank habitat strings', () {
      final habitats = [
        'Urban',
        'Urban, ',
        ' Jungle',
        'Desert, ',
        ' , Savanna',
        '   ',
        '',
        'Ocean, , River',
      ];

      // This simulates the logic:
      // .expand((h) => h.split(',').map((s) => s.trim()))
      // .where((s) => s.isNotEmpty)
      // .toSet()
      // .toList()

      final result = habitats
          .expand((h) => h.split(',').map((s) => s.trim()))
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      expect(
        result,
        containsAll(['Urban', 'Jungle', 'Desert', 'Savanna', 'Ocean', 'River']),
      );
      expect(result.length, 6);
      expect(result.contains(''), isFalse);
      expect(result.any((s) => s.trim().isEmpty), isFalse);
    });

    test('handles single malformed entry', () {
      final habitat = ' , ';
      final result = habitat
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      expect(result, isEmpty);
    });
  });
}
