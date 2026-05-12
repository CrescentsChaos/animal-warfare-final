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
              core_solidity REAL NOT NULL DEFAULT 0.0,
              bottom_heavy_bias REAL NOT NULL DEFAULT 0.0,
              max_width_row_bias REAL NOT NULL DEFAULT 0.0,
              max_height_col_bias REAL NOT NULL DEFAULT 0.0,
              bottom_center_density REAL NOT NULL DEFAULT 0.0,
              corner_density REAL NOT NULL DEFAULT 0.0,
              diagonal_density REAL NOT NULL DEFAULT 0.0,
              lower_quadrant_symmetry REAL NOT NULL DEFAULT 0.0,
              horizontal_centroid_shift REAL NOT NULL DEFAULT 0.0,
              convex_hull_ratio REAL NOT NULL DEFAULT 0.0,
              vertical_mass_distribution REAL NOT NULL DEFAULT 0.0,
              color_granularity REAL NOT NULL DEFAULT 0.0,
              fringe_density REAL NOT NULL DEFAULT 0.0,
              vertical_thinning REAL NOT NULL DEFAULT 0.0,
              local_symmetry REAL NOT NULL DEFAULT 0.0,
              color_clustering REAL NOT NULL DEFAULT 0.0,
              y_gradient REAL NOT NULL DEFAULT 0.0,
              width_variance REAL NOT NULL DEFAULT 0.0,
              shell_index REAL NOT NULL DEFAULT 0.0,
              radial_overlap REAL NOT NULL DEFAULT 0.0,
              y_centroid REAL NOT NULL DEFAULT 0.0,
              jaggedness REAL NOT NULL DEFAULT 0.0,
              top_third_density REAL NOT NULL DEFAULT 0.0,
              bilateral_sym REAL NOT NULL DEFAULT 0.0,
              updated_at TEXT NOT NULL DEFAULT (datetime('now')),
              training_count INTEGER NOT NULL DEFAULT 1,
              animal_class TEXT DEFAULT 'unknown',
              diet TEXT DEFAULT 'unknown',
              weight REAL DEFAULT 0.0
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
  const bool forceOverwrite = true;

  if (forceOverwrite) {
    await db.execute('DROP TABLE IF EXISTS organism_features');
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
              core_solidity REAL NOT NULL DEFAULT 0.0,
              bottom_heavy_bias REAL NOT NULL DEFAULT 0.0,
              max_width_row_bias REAL NOT NULL DEFAULT 0.0,
              max_height_col_bias REAL NOT NULL DEFAULT 0.0,
              bottom_center_density REAL NOT NULL DEFAULT 0.0,
              corner_density REAL NOT NULL DEFAULT 0.0,
              diagonal_density REAL NOT NULL DEFAULT 0.0,
              lower_quadrant_symmetry REAL NOT NULL DEFAULT 0.0,
              horizontal_centroid_shift REAL NOT NULL DEFAULT 0.0,
              convex_hull_ratio REAL NOT NULL DEFAULT 0.0,
              vertical_mass_distribution REAL NOT NULL DEFAULT 0.0,
              color_granularity REAL NOT NULL DEFAULT 0.0,
              fringe_density REAL NOT NULL DEFAULT 0.0,
              vertical_thinning REAL NOT NULL DEFAULT 0.0,
              local_symmetry REAL NOT NULL DEFAULT 0.0,
              color_clustering REAL NOT NULL DEFAULT 0.0,
              y_gradient REAL NOT NULL DEFAULT 0.0,
              width_variance REAL NOT NULL DEFAULT 0.0,
              shell_index REAL NOT NULL DEFAULT 0.0,
              radial_overlap REAL NOT NULL DEFAULT 0.0,
              y_centroid REAL NOT NULL DEFAULT 0.0,
              jaggedness REAL NOT NULL DEFAULT 0.0,
              top_third_density REAL NOT NULL DEFAULT 0.0,
              bilateral_sym REAL NOT NULL DEFAULT 0.0,
              updated_at TEXT NOT NULL DEFAULT (datetime('now')),
              training_count INTEGER NOT NULL DEFAULT 1,
              animal_class TEXT DEFAULT 'unknown',
              diet TEXT DEFAULT 'unknown',
              weight REAL DEFAULT 0.0
            )
          ''');
    print('Force Overwrite: Cleared existing features in $dbPath');
  }

  // Load organisms and group by class for BALANCED TRAINING
  final organismsJson = File('assets/Organisms.json').readAsStringSync();
  final List allOrganisms = jsonDecode(organismsJson);

  const int maxSpeciesPerClass = 400; // Balancing threshold
  final Map<String, List<dynamic>> classGroups = {};

  for (var org in allOrganisms) {
    final cls = (org['class'] ?? org['animal_class'] ?? 'unknown')
        .toString()
        .toLowerCase();
    classGroups.putIfAbsent(cls, () => []).add(org);
  }

  final List balancedOrganisms = [];
  final random = Random(42); // Seeded for consistency

  classGroups.forEach((cls, species) {
    species.shuffle(random);
    final limit = species.length > maxSpeciesPerClass
        ? maxSpeciesPerClass
        : species.length;
    balancedOrganisms.addAll(species.take(limit));
    print('Class "$cls": Added $limit species (out of ${species.length})');
  });

  print('Total balanced species to process: ${balancedOrganisms.length}');

  int count = 0;
  int errors = 0;
  final batch = db.batch();

  for (var org in balancedOrganisms) {
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
        'core_solidity': features['coreSolidity'] ?? 0.0,
        'bottom_heavy_bias': features['bottomHeavyBias'] ?? 0.0,
        'max_width_row_bias': features['maxWidthRowBias'] ?? 0.0,
        'max_height_col_bias': features['maxHeightColBias'] ?? 0.0,
        'bottom_center_density': features['bottomCenterDensity'] ?? 0.0,
        'corner_density': features['cornerDensity'] ?? 0.0,
        'diagonal_density': features['diagonalDensity'] ?? 0.0,
        'lower_quadrant_symmetry': features['lowerQuadrantSymmetry'] ?? 0.0,
        'horizontal_centroid_shift': features['horizontalCentroidShift'] ?? 0.0,
        'convex_hull_ratio': features['convexHullRatio'] ?? 0.0,
        'vertical_mass_distribution':
            features['verticalMassDistribution'] ?? 0.0,
        'color_granularity': features['colorGranularity'] ?? 0.0,
        'fringe_density': features['fringeDensity'] ?? 0.0,
        'vertical_thinning': features['verticalThinning'] ?? 0.0,
        'local_symmetry': features['localSymmetry'] ?? 0.0,
        'color_clustering': features['colorClustering'] ?? 0.0,
        'y_gradient': features['yGradient'] ?? 0.0,
        'width_variance': features['widthVariance'] ?? 0.0,
        'shell_index': features['shellIndex'] ?? 0.0,
        'radial_overlap': features['radialOverlap'] ?? 0.0,
        'y_centroid': features['yCentroid'] ?? 0.0,
        'jaggedness': features['jaggedness'] ?? 0.0,
        'top_third_density': features['topThirdDensity'] ?? 0.0,
        'bilateral_sym': features['bilateralSym'] ?? 0.0,
        'training_count': 1,
        'animal_class':
            org['class'] ?? org['animal_class']?.toString() ?? 'unknown',
        'diet': org['diet']?.toString() ?? 'unknown',
        'weight': _parseWeight(org['weight']),
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

double _parseWeight(dynamic value) {
  if (value == null) return 1.0;
  if (value is num) return value.toDouble();
  if (value is String) {
    final cleaned = value
        .replaceAll(',', '')
        .replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned) ?? 1.0;
  }
  return 1.0;
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
      'coreSolidity': 0.0,
      'bottomHeavyBias': 0.0,
      'maxWidthRowBias': 0.0,
      'maxHeightColBias': 0.0,
      'bottomCenterDensity': 0.0,
      'cornerDensity': 0.0,
      'diagonalDensity': 0.0,
      'lowerQuadrantSymmetry': 0.0,
      'horizontalCentroidShift': 0.0,
      'convexHullRatio': 0.0,
      'verticalMassDistribution': 0.0,
      'colorGranularity': 0.0,
      'fringeDensity': 0.0,
      'verticalThinning': 0.0,
      'localSymmetry': 0.0,
      'colorClustering': 0.0,
      'yGradient': 0.0,
      'widthVariance': 0.0,
      'shellIndex': 0.0,
      'radialOverlap': 0.0,
      'yCentroid': 0.0,
      'jaggedness': 0.0,
      'topThirdDensity': 0.0,
      'bilateralSym': 0.0,
    };
  }

  final Map<int, int> colorCounts = {};
  double totalBrightness = 0, totalSaturation = 0;
  final finalHueBins = <String, double>{};
  for (int i = 0; i < 36; i++) {
    finalHueBins['h${i * 10}'] = 0;
  }
  finalHueBins['hWhite'] = 0;
  finalHueBins['hBlack'] = 0;
  finalHueBins['hGrey'] = 0;

  for (int y = 0; y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      if (!mask[y * resized.width + x]) continue;
      final p = resized.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();

      final hsv = rgbToHsv(r, g, b);
      final hue = hsv[0];
      final saturation = hsv[1];
      final value = hsv[2];

      if (value < 0.15) {
        finalHueBins['hBlack'] = (finalHueBins['hBlack'] ?? 0) + 1;
      } else if (saturation < 0.15) {
        if (value > 0.8) {
          finalHueBins['hWhite'] = (finalHueBins['hWhite'] ?? 0) + 1;
        } else {
          finalHueBins['hGrey'] = (finalHueBins['hGrey'] ?? 0) + 1;
        }
      } else {
        final binIndex = (hue / 10).floor().clamp(0, 35);
        finalHueBins['h${binIndex * 10}'] =
            (finalHueBins['h${binIndex * 10}'] ?? 0) + 1;
      }

      totalSaturation += saturation;
      totalBrightness += value;

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

  // NEW: Core Solidity
  int corePixels = 0;
  final int coreMinX = minX + ((maxX - minX) * 0.25).toInt();
  final int coreMaxX = maxX - ((maxX - minX) * 0.25).toInt();
  final int coreMinY = minY + ((maxY - minY) * 0.25).toInt();
  final int coreMaxY = maxY - ((maxY - minY) * 0.25).toInt();
  for (int y = coreMinY; y <= coreMaxY; y++) {
    for (int x = coreMinX; x <= coreMaxX; x++) {
      if (mask[y * resized.width + x]) corePixels++;
    }
  }
  final double coreArea = max(
    1,
    (coreMaxX - coreMinX + 1) * (coreMaxY - coreMinY + 1),
  ).toDouble();
  final double coreSolidity = corePixels / coreArea;

  // NEW: Bottom Heavy Bias
  int bottomHalf = 0;
  for (int y = 0; y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      if (!mask[y * resized.width + x]) continue;
      if (y > resized.height * 0.6) bottomHalf++;
    }
  }
  final double bottomHeavyBias = objectPixelCount > 0
      ? bottomHalf / objectPixelCount
      : 0.0;

  // NEW: Max Width Row Bias
  int maxRowPixels = -1;
  int maxRowY = minY;
  for (int y = minY; y <= maxY; y++) {
    int rowPixels = 0;
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) rowPixels++;
    }
    if (rowPixels > maxRowPixels) {
      maxRowPixels = rowPixels;
      maxRowY = y;
    }
  }
  final double maxWidthRowBias = (maxY > minY)
      ? (maxRowY - minY) / (maxY - minY)
      : 0.5;

  // NEW: Max Height Col Bias
  int maxColPixels = -1;
  int maxColX = minX;
  for (int x = minX; x <= maxX; x++) {
    int colPixels = 0;
    for (int y = minY; y <= maxY; y++) {
      if (mask[y * resized.width + x]) colPixels++;
    }
    if (colPixels > maxColPixels) {
      maxColPixels = colPixels;
      maxColX = x;
    }
  }
  final double colXNorm = (maxX > minX)
      ? (maxColX - minX) / (maxX - minX)
      : 0.5;
  final double maxHeightColBias = (colXNorm - 0.5).abs() * 2.0;

  // NEW: Bottom Center Density
  final int bcMinX = minX + ((maxX - minX) * 0.35).toInt();
  final int bcMaxX = maxX - ((maxX - minX) * 0.35).toInt();
  final int bcMinY = maxY - ((maxY - minY) * 0.3).toInt();
  final int bcMaxY = maxY;
  int bcPixels = 0;
  for (int y = bcMinY; y <= bcMaxY; y++) {
    for (int x = bcMinX; x <= bcMaxX; x++) {
      if (mask[y * resized.width + x]) bcPixels++;
    }
  }
  final double bcArea = max(
    1,
    (bcMaxX - bcMinX + 1) * (bcMaxY - bcMinY + 1),
  ).toDouble();
  final double bottomCenterDensity = bcPixels / bcArea;

  // NEW: Corner Density
  final int cornerW = max(1, (maxX - minX) * 0.2).toInt();
  final int cornerH = max(1, (maxY - minY) * 0.2).toInt();
  int cornerPixels = 0;
  for (int y = minY; y < minY + cornerH; y++) {
    for (int x = minX; x < minX + cornerW; x++) {
      if (mask[y * resized.width + x]) cornerPixels++;
    }
    for (int x = maxX - cornerW + 1; x <= maxX; x++) {
      if (mask[y * resized.width + x]) cornerPixels++;
    }
  }
  for (int y = maxY - cornerH + 1; y <= maxY; y++) {
    for (int x = minX; x < minX + cornerW; x++) {
      if (mask[y * resized.width + x]) cornerPixels++;
    }
    for (int x = maxX - cornerW + 1; x <= maxX; x++) {
      if (mask[y * resized.width + x]) cornerPixels++;
    }
  }
  final double cornerArea = max(1, cornerW * cornerH * 4).toDouble();
  final double cornerDensity = cornerPixels / cornerArea;

  // NEW: Diagonal Density
  int diagPixels = 0;
  int diagArea = 0;
  final int boxW = max(1, maxX - minX);
  final int boxH = max(1, maxY - minY);
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      double nx = (x - minX) / boxW;
      double ny = (y - minY) / boxH;
      if ((nx - ny).abs() < 0.1 || (nx - (1 - ny)).abs() < 0.1) {
        diagArea++;
        if (mask[y * resized.width + x]) diagPixels++;
      }
    }
  }
  final double diagonalDensity = diagArea > 0 ? diagPixels / diagArea : 0.0;

  // NEW: Lower Quadrant Symmetry
  int lqLeft = 0;
  int lqRight = 0;
  final int lqMidY = minY + ((maxY - minY) * 0.5).toInt();
  final int lqMidX = minX + ((maxX - minX) * 0.5).toInt();
  for (int y = lqMidY; y <= maxY; y++) {
    for (int x = minX; x < lqMidX; x++) {
      if (mask[y * resized.width + x]) lqLeft++;
    }
    for (int x = lqMidX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) lqRight++;
    }
  }
  final double lowerQuadrantSymmetry = (lqLeft + lqRight) > 0
      ? min(lqLeft, lqRight) / max(lqLeft, lqRight)
      : 0.0;

  // NEW: Horizontal Centroid Shift
  int totalX = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        totalX += x;
      }
    }
  }
  final double centroidX = objectPixelCount > 0
      ? totalX / objectPixelCount
      : lqMidX.toDouble();
  final double horizontalCentroidShift = (maxX > minX)
      ? (centroidX - minX) / (maxX - minX)
      : 0.5;

  // NEW: Convex Hull Ratio (Proxy using diamond area)
  final double diamondArea = (maxX - minX + 1) * (maxY - minY + 1) / 2.0;
  final double convexHullRatio = diamondArea > 0
      ? (objectPixelCount / diamondArea).clamp(0.0, 1.0)
      : 0.0;

  // NEW: Vertical Mass Distribution
  int edgeMass = 0;
  final int vmdQ1 = minY + ((maxY - minY) * 0.25).toInt();
  final int vmdQ3 = minY + ((maxY - minY) * 0.75).toInt();
  for (int y = minY; y <= maxY; y++) {
    if (y <= vmdQ1 || y >= vmdQ3) {
      for (int x = minX; x <= maxX; x++) {
        if (mask[y * resized.width + x]) edgeMass++;
      }
    }
  }
  final double verticalMassDistribution = objectPixelCount > 0
      ? edgeMass / objectPixelCount
      : 0.0;

  // NEW: Color Granularity
  int distinctColors = 0;
  final Set<int> uniqueColors = {};
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        final p = resized.getPixel(x, y);
        int qColor = ((p.r ~/ 16) << 16) | ((p.g ~/ 16) << 8) | (p.b ~/ 16);
        uniqueColors.add(qColor);
      }
    }
  }
  final double colorGranularity = (uniqueColors.length / 4096.0).clamp(
    0.0,
    1.0,
  );

  // NEW: Fringe Density (Alpha boundary pixels)
  int fringePixels = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        if (x == minX ||
            x == maxX ||
            y == minY ||
            y == maxY ||
            !mask[(y - 1) * resized.width + x] ||
            !mask[(y + 1) * resized.width + x] ||
            !mask[y * resized.width + (x - 1)] ||
            !mask[y * resized.width + (x + 1)]) {
          fringePixels++;
        }
      }
    }
  }
  final double fringeDensity = objectPixelCount > 0
      ? fringePixels / objectPixelCount
      : 0.0;

  // NEW: Vertical Thinning & Width Variance
  int minRowWidth = maxX - minX + 1;
  int maxRowWidth = 0;
  int totalRowWidth = 0;
  List<int> rowWidths = [];
  for (int y = minY; y <= maxY; y++) {
    int rowW = 0;
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) rowW++;
    }
    if (rowW > 0) {
      if (rowW < minRowWidth) minRowWidth = rowW;
      if (rowW > maxRowWidth) maxRowWidth = rowW;
      totalRowWidth += rowW;
      rowWidths.add(rowW);
    }
  }
  final double verticalThinning = maxRowWidth > 0
      ? minRowWidth / maxRowWidth
      : 0.0;
  double widthVariance = 0.0;
  if (rowWidths.isNotEmpty && maxRowWidth > 0) {
    double avgRow = totalRowWidth / rowWidths.length;
    double varSum = 0;
    for (int w in rowWidths) {
      varSum += (w - avgRow).abs();
    }
    widthVariance = (varSum / rowWidths.length) / maxRowWidth;
  }

  // NEW: Local Symmetry (Average symmetry of 4 horizontal slices)
  double localSymSum = 0;
  int slices = 4;
  int sliceH = max(1, (maxY - minY + 1) ~/ slices);
  for (int s = 0; s < slices; s++) {
    int sMinY = minY + s * sliceH;
    int sMaxY = (s == slices - 1) ? maxY : sMinY + sliceH - 1;
    int slLeft = 0, slRight = 0;
    for (int y = sMinY; y <= sMaxY; y++) {
      for (int x = minX; x < lqMidX; x++) {
        if (mask[y * resized.width + x]) slLeft++;
      }
      for (int x = lqMidX; x <= maxX; x++) {
        if (mask[y * resized.width + x]) slRight++;
      }
    }
    if (slLeft + slRight > 0) {
      localSymSum += min(slLeft, slRight) / max(slLeft, slRight);
    }
  }
  final double localSymmetry = localSymSum / slices;

  // NEW: Color Clustering
  int clusteredPixels = 0;
  for (int y = minY + 1; y <= maxY; y++) {
    for (int x = minX + 1; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        final p = resized.getPixel(x, y);
        int qc = ((p.r ~/ 32) << 16) | ((p.g ~/ 32) << 8) | (p.b ~/ 32);
        if (mask[(y - 1) * resized.width + x]) {
          final pt = resized.getPixel(x, y - 1);
          if (qc ==
              (((pt.r ~/ 32) << 16) | ((pt.g ~/ 32) << 8) | (pt.b ~/ 32))) {
            clusteredPixels++;
          }
        } else if (mask[y * resized.width + x - 1]) {
          final pl = resized.getPixel(x - 1, y);
          if (qc ==
              (((pl.r ~/ 32) << 16) | ((pl.g ~/ 32) << 8) | (pl.b ~/ 32))) {
            clusteredPixels++;
          }
        }
      }
    }
  }
  final double colorClustering = objectPixelCount > 0
      ? clusteredPixels / objectPixelCount
      : 0.0;

  // NEW: Y Gradient (Vertical Centroid)
  int totalY = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) totalY += y;
    }
  }
  final double centroidY = objectPixelCount > 0
      ? totalY / objectPixelCount
      : lqMidY.toDouble();
  final double yGradient = (maxY > minY)
      ? (centroidY - minY) / (maxY - minY)
      : 0.5;

  // NEW: Shell Index (Pixels within 15% of bounding box edge)
  int shellPixels = 0;
  int shEdgeX = max(1, (maxX - minX) * 0.15).toInt();
  int shEdgeY = max(1, (maxY - minY) * 0.15).toInt();
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        if (x <= minX + shEdgeX ||
            x >= maxX - shEdgeX ||
            y <= minY + shEdgeY ||
            y >= maxY - shEdgeY) {
          shellPixels++;
        }
      }
    }
  }
  final double shellIndex = objectPixelCount > 0
      ? shellPixels / objectPixelCount
      : 0.0;

  // NEW: Radial Overlap (Ellipse Area)
  final double ellipseArea =
      pi * ((maxX - minX + 1) / 2.0) * ((maxY - minY + 1) / 2.0);
  final double radialOverlap = ellipseArea > 0
      ? (objectPixelCount / ellipseArea).clamp(0.0, 1.0)
      : 0.0;

  // NEW: yCentroid (Absolute normalized vertical center of mass)
  final double yCentroid = objectPixelCount > 0
      ? centroidY / resized.height
      : 0.5;

  // NEW: Jaggedness (Perimeter proxy)
  final double jaggedness = objectPixelCount > 0
      ? fringePixels / sqrt(objectPixelCount)
      : 0.0;

  // NEW: Top Third Density
  int topThirdPixels = 0;
  int topThirdY = minY + (maxY - minY + 1) ~/ 3;
  for (int y = minY; y <= topThirdY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) topThirdPixels++;
    }
  }
  final double topThirdDensity = objectPixelCount > 0
      ? topThirdPixels / objectPixelCount
      : 0.0;

  // NEW: Bilateral Symmetry (Point-by-point matching)
  int matchedSymmetryPixels = 0;
  int totalSymmetryCheck = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x < lqMidX; x++) {
      int oppositeX = maxX - (x - minX);
      if (oppositeX >= 0 && oppositeX < resized.width) {
        totalSymmetryCheck++;
        if (mask[y * resized.width + x] ==
            mask[y * resized.width + oppositeX]) {
          matchedSymmetryPixels++;
        }
      }
    }
  }
  final double bilateralSym = totalSymmetryCheck > 0
      ? matchedSymmetryPixels / totalSymmetryCheck
      : 0.0;

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
    'coreSolidity': coreSolidity,
    'bottomHeavyBias': bottomHeavyBias,
    'maxWidthRowBias': maxWidthRowBias,
    'maxHeightColBias': maxHeightColBias,
    'bottomCenterDensity': bottomCenterDensity,
    'cornerDensity': cornerDensity,
    'diagonalDensity': diagonalDensity,
    'lowerQuadrantSymmetry': lowerQuadrantSymmetry,
    'horizontalCentroidShift': horizontalCentroidShift,
    'convexHullRatio': convexHullRatio,
    'verticalMassDistribution': verticalMassDistribution,
    'colorGranularity': colorGranularity,
    'fringeDensity': fringeDensity,
    'verticalThinning': verticalThinning,
    'localSymmetry': localSymmetry,
    'colorClustering': colorClustering,
    'yGradient': yGradient,
    'widthVariance': widthVariance,
    'shellIndex': shellIndex,
    'radialOverlap': radialOverlap,
    'yCentroid': yCentroid,
    'jaggedness': jaggedness,
    'topThirdDensity': topThirdDensity,
    'bilateralSym': bilateralSym,
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
    } else if (maxV == gf) {
      h = (bf - rf) / d + 2;
    } else {
      h = (rf - gf) / d + 4;
    }
    h /= 6;
  }
  return [h * 360, maxV == 0 ? 0 : d / maxV, maxV];
}
