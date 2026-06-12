// scratch/generate_features_db.dart
//
// Standalone Dart CLI to generate sprite_features.db from all sprites.
// Run with: dart run scratch/generate_features_db.dart
//
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
              vertical_bias REAL NOT NULL DEFAULT 0.5,
              top_heavy_bias REAL NOT NULL DEFAULT 0.5,
              hue_complexity REAL NOT NULL DEFAULT 0.0,
              compactness REAL NOT NULL DEFAULT 1.0,
              limb_density REAL NOT NULL DEFAULT 0.0,
              directional_edge_bias REAL NOT NULL DEFAULT 0.0,
              updated_at TEXT NOT NULL DEFAULT (datetime('now')),
              training_count INTEGER NOT NULL DEFAULT 1,
              animal_class TEXT DEFAULT 'unknown',
              diet TEXT DEFAULT 'unknown',
              weight REAL DEFAULT 0.0
            )
          ''');
      },
    ),
  );

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
              vertical_bias REAL NOT NULL DEFAULT 0.5,
              top_heavy_bias REAL NOT NULL DEFAULT 0.5,
              hue_complexity REAL NOT NULL DEFAULT 0.0,
              compactness REAL NOT NULL DEFAULT 1.0,
              limb_density REAL NOT NULL DEFAULT 0.0,
              directional_edge_bias REAL NOT NULL DEFAULT 0.0,
              updated_at TEXT NOT NULL DEFAULT (datetime('now')),
              training_count INTEGER NOT NULL DEFAULT 1,
              animal_class TEXT DEFAULT 'unknown',
              diet TEXT DEFAULT 'unknown',
              weight REAL DEFAULT 0.0
            )
          ''');
  }

  final organismsJson = File('assets/Organisms.json').readAsStringSync();
  final List allOrganisms = jsonDecode(organismsJson);
  int count = 0;
  int errors = 0;
  for (var org in allOrganisms) {
    final name = org['name'] as String;
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r"[''']"), '')
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
        'scientific_name': org['scientific_name'] ?? '',
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
        'core_solidity': features['coreSolidity'],
        'bottom_heavy_bias': features['bottomHeavyBias'],
        'max_width_row_bias': features['maxWidthRowBias'],
        'max_height_col_bias': features['maxHeightColBias'],
        'bottom_center_density': features['bottomCenterDensity'],
        'corner_density': features['cornerDensity'],
        'diagonal_density': features['diagonalDensity'],
        'lower_quadrant_symmetry': features['lowerQuadrantSymmetry'],
        'horizontal_centroid_shift': features['horizontalCentroidShift'],
        'convex_hull_ratio': features['convexHullRatio'],
        'vertical_mass_distribution': features['verticalMassDistribution'],
        'color_granularity': features['colorGranularity'],
        'fringe_density': features['fringeDensity'],
        'vertical_thinning': features['verticalThinning'],
        'local_symmetry': features['localSymmetry'],
        'color_clustering': features['colorClustering'],
        'y_gradient': features['yGradient'],
        'width_variance': features['widthVariance'],
        'shell_index': features['shellIndex'],
        'radial_overlap': features['radialOverlap'],
        'y_centroid': features['yCentroid'],
        'jaggedness': features['jaggedness'],
        'top_third_density': features['topThirdDensity'],
        'bilateral_sym': features['bilateralSym'],
        'vertical_bias': features['verticalBias'],
        'top_heavy_bias': features['topHeavyBias'],
        'hue_complexity': features['hueComplexity'],
        'compactness': features['compactness'],
        'limb_density': features['limbDensity'],
        'directional_edge_bias': features['directionalEdgeBias'],
        'animal_class':
            org['class'] ?? org['animal_class']?.toString() ?? 'unknown',
        'diet': org['diet']?.toString() ?? 'unknown',
        'weight': _parseWeight(org['weight']),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);

      count++;
      if (count % 100 == 0) print('Processed $count sprites...');
    } catch (e) {
      errors++;
      print('Error processing $name: $e');
    }
  }

  await db.close();
  print('=== Generation Complete ===');
  print('Features saved: $count, Errors: $errors');
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

Map<String, dynamic> extractFeatures(img.Image decoded, String name) {
  img.Image resized;
  if (decoded.width == decoded.height) {
    resized = img.copyResize(decoded, width: 128, height: 128);
  } else {
    final size = max(decoded.width, decoded.height);
    final padded = img.Image(width: size, height: size, numChannels: 4);
    img.fill(padded, color: img.ColorRgba8(0, 0, 0, 0));
    final xOffset = (size - decoded.width) ~/ 2;
    final yOffset = (size - decoded.height) ~/ 2;
    img.compositeImage(padded, decoded, dstX: xOffset, dstY: yOffset);
    resized = img.copyResize(padded, width: 128, height: 128);
  }

  final mask = List.generate(resized.width * resized.height, (i) => true);
  int objectPixelCount = 0;
  int minX = resized.width, maxX = 0, minY = resized.height, maxY = 0;

  for (int i = 0; i < resized.width * resized.height; i++) {
    final p = resized.getPixelSafe(i % resized.width, i ~/ resized.width);
    mask[i] = p.a >= 128;
    if (mask[i]) {
      objectPixelCount++;
      final x = i % resized.width, y = i ~/ resized.width;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }

  if (objectPixelCount == 0) {
    return {'organismName': name, 'error': 'Empty sprite'};
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
      final hsv = rgbToHsv(p.r.toInt(), p.g.toInt(), p.b.toInt());
      final h = hsv[0], s = hsv[1], v = hsv[2];

      if (v < 0.15) {
        finalHueBins['hBlack'] = (finalHueBins['hBlack'] ?? 0) + 1;
      } else if (s < 0.15) {
        if (v > 0.8) {
          finalHueBins['hWhite'] = (finalHueBins['hWhite'] ?? 0) + 1;
        } else {
          finalHueBins['hGrey'] = (finalHueBins['hGrey'] ?? 0) + 1;
        }
      } else {
        final bin = (h / 10).floor().clamp(0, 35);
        finalHueBins['h${bin * 10}'] = (finalHueBins['h${bin * 10}'] ?? 0) + 1;
      }
      totalSaturation += s;
      totalBrightness += v;
      final quantized =
          ((p.r.toInt() >> 4) << 8) |
          ((p.g.toInt() >> 4) << 4) |
          (p.b.toInt() >> 4);
      colorCounts[quantized] = (colorCounts[quantized] ?? 0) + 1;
    }
  }

  for (final key in finalHueBins.keys) {
    finalHueBins[key] = finalHueBins[key]! / objectPixelCount;
  }
  final sortedColors = colorCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final dominantColors = sortedColors.take(8).map((e) {
    final q = e.key;
    final r = ((q >> 8) & 0xF) * 17,
        g = ((q >> 4) & 0xF) * 17,
        b = (q & 0xF) * 17;
    return (0xFF << 24) | (r << 16) | (g << 8) | b;
  }).toList();

  final spatialHueBins = <String, double>{};
  for (int gy = 0; gy < 3; gy++) {
    for (int gx = 0; gx < 3; gx++) {
      final sX = minX + (gx * (maxX - minX) ~/ 3),
          eX = minX + ((gx + 1) * (maxX - minX) ~/ 3);
      final sY = minY + (gy * (maxY - minY) ~/ 3),
          eY = minY + ((gy + 1) * (maxY - minY) ~/ 3);
      int gridPix = 0;
      final Map<int, int> bins = {};
      for (int y = sY; y < eY; y++) {
        for (int x = sX; x < eX; x++) {
          final idx = y * resized.width + x;
          if (idx >= 0 && idx < mask.length && mask[idx]) {
            final p = resized.getPixel(x, y);
            final hsv = rgbToHsv(p.r.toInt(), p.g.toInt(), p.b.toInt());
            final b = ((hsv[0] % 360) / 10).floor();
            bins[b] = (bins[b] ?? 0) + 1;
            gridPix++;
          }
        }
      }
      bins.forEach(
        (b, c) => spatialHueBins['g$gx${gy}_h${b * 10}'] = gridPix > 0
            ? c / gridPix
            : 0,
      );
    }
  }

  final cMinX = minX + ((maxX - minX) * 0.25).toInt(),
      cMaxX = maxX - ((maxX - minX) * 0.25).toInt();
  final cMinY = minY + ((maxY - minY) * 0.25).toInt(),
      cMaxY = maxY - ((maxY - minY) * 0.25).toInt();
  int corePix = 0;
  for (int y = cMinY; y <= cMaxY; y++) {
    for (int x = cMinX; x <= cMaxX; x++) {
      if (mask[y * resized.width + x]) corePix++;
    }
  }
  final coreSolidity =
      corePix / max(1, (cMaxX - cMinX + 1) * (cMaxY - cMinY + 1));

  int top40 = 0, bottom60 = 0, bottomHalf = 0;
  for (int y = 0; y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      if (!mask[y * resized.width + x]) continue;
      if (y < resized.height * 0.4) top40++;
      if (y > resized.height * 0.6) bottom60++;
      if (y > resized.height * 0.5) bottomHalf++;
    }
  }
  final verticalBias = (top40 + bottom60) > 0
      ? bottom60 / (top40 + bottom60)
      : 0.5;

  int maxRW = 0, maxRY = minY, minRW = maxX - minX + 1;
  List<int> rowWs = [];
  for (int y = minY; y <= maxY; y++) {
    int rw = 0;
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) rw++;
    }
    if (rw > 0) {
      if (rw > maxRW) {
        maxRW = rw;
        maxRY = y;
      }
      if (rw < minRW) minRW = rw;
      rowWs.add(rw);
    }
  }
  final maxWidthRowBias = (maxY > minY) ? (maxRY - minY) / (maxY - minY) : 0.5;
  final verticalThinning = maxRW > 0 ? minRW / maxRW : 0.0;

  int maxCH = 0, maxCX = minX;
  for (int x = minX; x <= maxX; x++) {
    int ch = 0;
    for (int y = minY; y <= maxY; y++) {
      if (mask[y * resized.width + x]) ch++;
    }
    if (ch > maxCH) {
      maxCH = ch;
      maxCX = x;
    }
  }
  final maxHeightColBias = (maxX > minX) ? (maxCX - minX) / (maxX - minX) : 0.5;

  final bcMinX = minX + ((maxX - minX) * 0.35).toInt(),
      bcMaxX = maxX - ((maxX - minX) * 0.35).toInt();
  final bcMinY = maxY - ((maxY - minY) * 0.3).toInt();
  int bcPix = 0;
  for (int y = bcMinY; y <= maxY; y++) {
    for (int x = bcMinX; x <= bcMaxX; x++) {
      if (mask[y * resized.width + x]) bcPix++;
    }
  }
  final bottomCenterDensity =
      bcPix / max(1, (bcMaxX - bcMinX + 1) * (maxY - bcMinY + 1));

  final sym = _calculateSymmetry(resized, mask, minX, maxX, minY, maxY);
  final hSym = sym.$1,
      vSym = sym.$2,
      midX = minX + (maxX - minX) ~/ 2,
      midY = minY + (maxY - minY) ~/ 2;
  int qM = 0;
  for (int qy = 0; qy < 2; qy++) {
    for (int qx = 0; qx < 2; qx++) {
      final qsX = qx == 0 ? minX : midX, qeX = qx == 0 ? midX : maxX;
      final qsY = qy == 0 ? minY : midY, qeY = qy == 0 ? midY : maxY;
      final qS = _calculateSymmetry(resized, mask, qsX, qeX, qsY, qeY);
      qM += (qS.$1 * 100).toInt() + (qS.$2 * 100).toInt();
    }
  }
  final localSymmetry = qM / 800.0;

  int perim = 0, fringe = 0;
  for (int y = 0; y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      if (!mask[y * resized.width + x]) continue;
      bool isE =
          (x == 0 ||
          x == resized.width - 1 ||
          y == 0 ||
          y == resized.height - 1 ||
          !mask[(y - 1) * resized.width + x] ||
          !mask[(y + 1) * resized.width + x] ||
          !mask[y * resized.width + (x - 1)] ||
          !mask[y * resized.width + (x + 1)]);
      if (isE) {
        perim++;
        fringe++;
      }
    }
  }

  int tXPos = 0, tYPos = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        tXPos += x;
        tYPos += y;
      }
    }
  }
  final centroidX = objectPixelCount > 0 ? tXPos / objectPixelCount : 0.0;
  final centroidY = objectPixelCount > 0 ? tYPos / objectPixelCount : 0.0;
  double sumYDist = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) sumYDist += pow(y - centroidY, 2);
    }
  }
  final verticalMassDistribution = (maxY > minY)
      ? sqrt(sumYDist / objectPixelCount) / (maxY - minY)
      : 0.0;

  int clustered = 0;
  for (int y = minY + 1; y <= maxY; y++) {
    for (int x = minX + 1; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        final p = resized.getPixel(x, y);
        int qc =
            ((p.r.toInt() ~/ 32) << 16) |
            ((p.g.toInt() ~/ 32) << 8) |
            (p.b.toInt() ~/ 32);
        if (mask[(y - 1) * resized.width + x]) {
          final pt = resized.getPixel(x, y - 1);
          if (qc ==
              (((pt.r.toInt() ~/ 32) << 16) |
                  ((pt.g.toInt() ~/ 32) << 8) |
                  (pt.b.toInt() ~/ 32))) {
            clustered++;
          }
        }
      }
    }
  }

  int limbPix = 0;
  final iX = ((maxX - minX + 1) * 0.2).toInt(),
      iY = ((maxY - minY + 1) * 0.2).toInt();
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        if (x < minX + iX || x > maxX - iX || y < minY + iY || y > maxY - iY) {
          limbPix++;
        }
      }
    }
  }

  final Set<int> uniqueColors = {};
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        final p = resized.getPixel(x, y);
        uniqueColors.add(
          ((p.r.toInt() ~/ 16) << 16) |
              ((p.g.toInt() ~/ 16) << 8) |
              (p.b.toInt() ~/ 16),
        );
      }
    }
  }

  int significantBins = 0;
  finalHueBins.forEach((key, val) {
    if (val > 0.02) significantBins++;
  });
  final double hueComplexity = significantBins / 39.0;

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
  final double cornerDensity = cornerPixels / max(1, cornerW * cornerH * 4.0);

  int diagPixels = 0, diagArea = 0;
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

  final lowerSym = _calculateSymmetry(resized, mask, minX, maxX, midY, maxY);
  final double lowerQuadrantSymmetry = lowerSym.$1;

  int hEdges = 0, vEdges = 0;
  for (int y = 1; y < resized.height - 1; y++) {
    for (int x = 1; x < resized.width - 1; x++) {
      if (!mask[y * resized.width + x]) continue;
      final p = resized.getPixel(x, y),
          pR = resized.getPixel(x + 1, y),
          pD = resized.getPixel(x, y + 1);
      final lum = (p.r + p.g + p.b) / 3,
          lumR = (pR.r + pR.g + pR.b) / 3,
          lumD = (pD.r + pD.g + pD.b) / 3;
      if ((lum - lumR).abs() > 30) hEdges++;
      if ((lum - lumD).abs() > 30) vEdges++;
    }
  }
  final double edgeBias = (hEdges + vEdges) > 0
      ? (hEdges - vEdges) / (hEdges + vEdges)
      : 0.0;

  return {
    'organismName': name,
    'hueBins': finalHueBins,
    'spatialHueBins': spatialHueBins,
    'dominantColors': dominantColors,
    'avgBrightness': totalBrightness / objectPixelCount,
    'avgSaturation': totalSaturation / objectPixelCount,
    'aspectRatio': (maxX - minX + 1) / (maxY - minY + 1),
    'solidity': objectPixelCount / ((maxX - minX + 1) * (maxY - minY + 1)),
    'verticalSymmetry': vSym,
    'horizontalSymmetry': hSym,
    'edgeDensity': _calculateEdgeDensity(resized, mask),
    'coreSolidity': coreSolidity,
    'bottomHeavyBias': bottomHalf / objectPixelCount,
    'maxWidthRowBias': maxWidthRowBias,
    'maxHeightColBias': maxHeightColBias,
    'bottomCenterDensity': bottomCenterDensity,
    'cornerDensity': cornerDensity,
    'diagonalDensity': diagonalDensity,
    'lowerQuadrantSymmetry': lowerQuadrantSymmetry,
    'horizontalCentroidShift': (maxX > minX)
        ? (centroidX - minX) / (maxX - minX)
        : 0.5,
    'convexHullRatio':
        (objectPixelCount / ((maxX - minX + 1) * (maxY - minY + 1) / 2.0))
            .clamp(0.0, 1.0),
    'verticalMassDistribution': verticalMassDistribution,
    'colorGranularity': (uniqueColors.length / 4096.0).clamp(0.0, 1.0),
    'fringeDensity': fringe / objectPixelCount,
    'verticalThinning': verticalThinning,
    'localSymmetry': localSymmetry,
    'colorClustering': clustered / objectPixelCount,
    'yGradient': (maxY > minY) ? (centroidY - minY) / (maxY - minY) : 0.5,
    'widthVariance': 0.0,
    'shellIndex': 0.0,
    'radialOverlap': 0.0,
    'yCentroid': centroidY / resized.height,
    'jaggedness': fringe / sqrt(objectPixelCount),
    'topThirdDensity': top40 / objectPixelCount,
    'bilateralSym': hSym,
    'verticalBias': verticalBias,
    'topHeavyBias': top40 / objectPixelCount,
    'hueComplexity': hueComplexity,
    'compactness': (perim * perim) / objectPixelCount,
    'limbDensity': limbPix / objectPixelCount,
    'directionalEdge_bias': edgeBias,
    'directionalEdgeBias': edgeBias,
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
      final p = image.getPixel(x, y),
          pR = image.getPixel(x + 1, y),
          pD = image.getPixel(x, y + 1);
      final lum = (p.r + p.g + p.b) / 3.0,
          lR = (pR.r + pR.g + pR.b) / 3.0,
          lD = (pD.r + pD.g + pD.b) / 3.0;
      if (((lum - lR).abs() + (lum - lD).abs()) > 40) edgePixels++;
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
