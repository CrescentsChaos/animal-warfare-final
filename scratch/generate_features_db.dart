// scratch/generate_features_db.dart
//
// Standalone Dart CLI to generate sprite_features.db from all sprites.
// Run with: dart run scratch/generate_features_db.dart
//
// This replaces the old JSON-based generate_features.dart.
// Uses sqflite_common_ffi for desktop SQLite access without Flutter.

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:path/path.dart' as p;

void main() async {
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;

  final dbPath = p.join(
    Directory.current.path,
    'assets',
    'ml',
    'sprite_features.db',
  );

  // Ensure ml directory exists
  Directory('assets/ml').createSync(recursive: true);

  final db = await factory.openDatabase(
    dbPath,
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
            CREATE TABLE organism_features (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              organism_name TEXT UNIQUE NOT NULL,
              scientific_name TEXT,
              hue_bins TEXT NOT NULL,
              spatial_hue_bins TEXT,
              dominant_colors TEXT,
              avg_brightness REAL NOT NULL,
              avg_saturation REAL NOT NULL,
              aspect_ratio REAL NOT NULL,
              solidity REAL NOT NULL,
              vertical_symmetry REAL NOT NULL,
              horizontal_symmetry REAL NOT NULL,
              edge_density REAL NOT NULL,
              updated_at TEXT NOT NULL DEFAULT (datetime('now')),
              training_count INTEGER NOT NULL DEFAULT 1
            )
          ''');
        await db.execute(
          'CREATE INDEX idx_scientific_name ON organism_features(scientific_name)',
        );
        await db.execute(
          'CREATE INDEX idx_organism_name ON organism_features(organism_name)',
        );
      },
    ),
  );

  // Force overwrite will replace existing features.
  // Set to false (default) to only add MISSING organisms, preserving manual training.
  const bool forceOverwrite = false;

  if (forceOverwrite) {
    await db.execute('DELETE FROM organism_features');
    print('Force Overwrite: Cleared existing features in $dbPath');
  } else {
    print('Incremental Mode: Only adding missing organisms to $dbPath');
  }

  // Load organisms for name→scientific_name mapping
  final organismsJson = File('assets/Organisms.json').readAsStringSync();
  final List organisms = jsonDecode(organismsJson);
  final nameToSciName = <String, String>{};
  for (final org in organisms) {
    nameToSciName[org['name'] as String] =
        (org['scientific_name'] ?? '') as String;
  }

  print('Processing ${organisms.length} organisms...');

  int count = 0;
  int errors = 0;
  final batch = db.batch();

  for (var org in organisms) {
    final name = org['name'] as String;
    final scientificName = (org['scientific_name'] ?? '') as String;
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r"['''']"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final path = 'assets/sprites/$slug.png';

    if (!File(path).existsSync()) continue;

    try {
      final bytes = File(path).readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;

      final features = extractFeatures(decoded, name);

      await db.insert('organism_features', {
        'organism_name': name,
        'scientific_name': scientificName,
        'hue_bins': jsonEncode(features['hueBins']),
        'spatial_hue_bins': jsonEncode(features['spatialHueBins']),
        'dominant_colors': jsonEncode(features['dominantColors']),
        'avg_brightness': features['avgBrightness'],
        'avg_saturation': features['avgSaturation'],
        'aspect_ratio': features['aspectRatio'],
        'solidity': features['solidity'],
        'vertical_symmetry': features['verticalSymmetry'],
        'horizontal_symmetry': features['horizontalSymmetry'],
        'edge_density': features['edgeDensity'],
        'training_count': 1,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      count++;
      if (count % 100 == 0) {
        print('Processed $count sprites...');
      }
    } catch (e) {
      errors++;
      print('Error processing $name: $e');
    }
  }

  print('Committing $count features to database...');
  await db.close();

  final fileSize = File(dbPath).lengthSync();
  print('');
  print('=== Generation Complete ===');
  print('Features saved: $count');
  print('Errors: $errors');
  print('Database size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
  print('Output: $dbPath');
}

// ============================================================
// Feature extraction (mirrors BiometricService logic exactly)
// ============================================================

Map<String, dynamic> extractFeatures(img.Image decoded, String name) {
  // Resize with padding to maintain aspect ratio
  img.Image resized;
  if (decoded.width == decoded.height) {
    resized = img.copyResize(decoded, width: 64, height: 64);
  } else {
    final size = max(decoded.width, decoded.height);
    // IMPORTANT: Must specify numChannels: 4 to avoid stripping alpha channel in package:image 4.x+
    final padded = img.Image(width: size, height: size, numChannels: 4);
    img.fill(padded, color: img.ColorRgba8(0, 0, 0, 0));
    final xOffset = (size - decoded.width) ~/ 2;
    final yOffset = (size - decoded.height) ~/ 2;
    img.compositeImage(padded, decoded, dstX: xOffset, dstY: yOffset);
    resized = img.copyResize(padded, width: 64, height: 64);
  }

  final mask = List.generate(resized.width * resized.height, (i) => true);
  int objectPixelCount = 0;
  int minX = resized.width, maxX = 0, minY = resized.height, maxY = 0;

  for (int i = 0; i < resized.width * resized.height; i++) {
    final p = resized.getPixelSafe(i % resized.width, i ~/ resized.width);
    mask[i] = p.a >= 128;
    if (mask[i]) {
      objectPixelCount++;
      final x = i % resized.width;
      final y = i ~/ resized.width;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }

  if (objectPixelCount == 0) {
    return {
      'organismName': name,
      'hueBins': <String, double>{},
      'spatialHueBins': <String, double>{},
      'dominantColors': <int>[],
      'avgBrightness': 0.5,
      'avgSaturation': 0.5,
      'aspectRatio': 1.0,
      'solidity': 0.5,
      'verticalSymmetry': 0.5,
      'horizontalSymmetry': 0.5,
      'edgeDensity': 0.0,
    };
  }

  final Map<int, int> colorCounts = {};
  double totalBrightness = 0, totalSaturation = 0;
  final finalHueBins = <String, double>{};
  for (int i = 0; i < 36; i++) {
    finalHueBins['h${i * 10}'] = 0;
  }

  for (int y = 0; y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      if (!mask[y * resized.width + x]) continue;
      final p = resized.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();

      final hsv = rgbToHsv(r, g, b);
      final binIndex = (hsv[0] / 10).floor().clamp(0, 35);
      finalHueBins['h${binIndex * 10}'] =
          (finalHueBins['h${binIndex * 10}'] ?? 0) + 1;
      totalSaturation += hsv[1];
      totalBrightness += hsv[2];

      final quantized = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      colorCounts[quantized] = (colorCounts[quantized] ?? 0) + 1;
    }
  }

  // Normalize hue bins
  for (final key in finalHueBins.keys) {
    finalHueBins[key] = finalHueBins[key]! / objectPixelCount;
  }

  // Dominant colors as Color.value ints
  final sortedColors = colorCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final dominantColors = sortedColors.take(8).map((e) {
    final q = e.key;
    final r = ((q >> 8) & 0xF) * 17;
    final g = ((q >> 4) & 0xF) * 17;
    final b = (q & 0xF) * 17;
    return (0xFF << 24) | (r << 16) | (g << 8) | b; // ARGB int
  }).toList();

  // Spatial analysis (3x3 grid)
  final spatialHueBins = <String, double>{};
  for (int gy = 0; gy < 3; gy++) {
    for (int gx = 0; gx < 3; gx++) {
      final startX = minX + (gx * (maxX - minX) ~/ 3);
      final endX = minX + ((gx + 1) * (maxX - minX) ~/ 3);
      final startY = minY + (gy * (maxY - minY) ~/ 3);
      final endY = minY + ((gy + 1) * (maxY - minY) ~/ 3);

      final gridBins = <int, int>{};
      int gridPixels = 0;
      for (int y = startY; y < endY; y++) {
        for (int x = startX; x < endX; x++) {
          final idx = y * resized.width + x;
          if (idx >= 0 && idx < mask.length && mask[idx]) {
            final p = resized.getPixel(x, y);
            final hsv = rgbToHsv(p.r.toInt(), p.g.toInt(), p.b.toInt());
            final bin = ((hsv[0] % 360) / 10).floor();
            gridBins[bin] = (gridBins[bin] ?? 0) + 1;
            gridPixels++;
          }
        }
      }
      gridBins.forEach((bin, count) {
        spatialHueBins['g$gx${gy}_h${bin * 10}'] = gridPixels > 0
            ? count / gridPixels
            : 0;
      });
    }
  }

  final sym = _calculateSymmetry(resized, mask, minX, maxX, minY, maxY);

  return {
    'organismName': name,
    'hueBins': finalHueBins,
    'spatialHueBins': spatialHueBins,
    'dominantColors': dominantColors,
    'avgBrightness': totalBrightness / objectPixelCount,
    'avgSaturation': totalSaturation / objectPixelCount,
    'aspectRatio': (maxX - minX + 1) / (maxY - minY + 1),
    'solidity': objectPixelCount / ((maxX - minX + 1) * (maxY - minY + 1)),
    'verticalSymmetry': sym.$2,
    'horizontalSymmetry': sym.$1,
    'edgeDensity': _calculateEdgeDensity(resized, mask),
  };
}

(double, double) _calculateSymmetry(
  img.Image image,
  List<bool> mask,
  int minX,
  int maxX,
  int minY,
  int maxY,
) {
  int hMatches = 0, vMatches = 0, hTotal = 0, vTotal = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= (minX + maxX) ~/ 2; x++) {
      final x2 = maxX - (x - minX);
      if (x2 < minX || x2 > maxX) continue;
      final p1 = image.getPixel(x, y), p2 = image.getPixel(x2, y);
      hTotal++;
      if (((p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs()) <
          100) {
        hMatches++;
      }
    }
  }
  for (int x = minX; x <= maxX; x++) {
    for (int y = minY; y <= (minY + maxY) ~/ 2; y++) {
      final y2 = maxY - (y - minY);
      if (y2 < minY || y2 > maxY) continue;
      final p1 = image.getPixel(x, y), p2 = image.getPixel(x, y2);
      vTotal++;
      if (((p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs()) <
          100) {
        vMatches++;
      }
    }
  }
  return (
    hTotal > 0 ? hMatches / hTotal : 0.5,
    vTotal > 0 ? vMatches / vTotal : 0.5,
  );
}

double _calculateEdgeDensity(img.Image image, List<bool> mask) {
  int edgePixels = 0, totalPixels = 0;
  for (int y = 1; y < image.height - 1; y++) {
    for (int x = 1; x < image.width - 1; x++) {
      if (!mask[y * image.width + x]) continue;
      final p = image.getPixel(x, y);
      final pRight = image.getPixel(x + 1, y);
      final pDown = image.getPixel(x, y + 1);
      final lum = (p.r + p.g + p.b) / 3.0;
      final grad =
          (lum - (pRight.r + pRight.g + pRight.b) / 3.0).abs() +
          (lum - (pDown.r + pDown.g + pDown.b) / 3.0).abs();
      if (grad > 30) edgePixels++;
      totalPixels++;
    }
  }
  return totalPixels > 0 ? edgePixels / totalPixels : 0.0;
}

List<double> rgbToHsv(int r, int g, int b) {
  double rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
  double maxV = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
  double minV = [rf, gf, bf].reduce((a, b) => a < b ? a : b);
  double d = maxV - minV;
  double h = 0;
  if (d != 0) {
    if (maxV == rf) {
      h = (gf - bf) / d + (gf < bf ? 6 : 0);
    } else if (maxV == gf)
      h = (bf - rf) / d + 2;
    else
      h = (rf - gf) / d + 4;
    h /= 6;
  }
  return [h * 360, maxV == 0 ? 0 : d / maxV, maxV];
}
