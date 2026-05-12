import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

void main() async {
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;
  final dbPath = p.join(
    Directory.current.path,
    'assets',
    'ml',
    'sprite_features.db',
  );
  final db = await databaseFactory.openDatabase(dbPath);

  final results = await db.query('taxonomy_profiles');
  for (var r in results) {
    print('Class: ${r['animal_class']}');
    print('  Means: ${r['feature_means']}');
    print('  Count: ${r['sample_count']}');
  }
  await db.close();
}
