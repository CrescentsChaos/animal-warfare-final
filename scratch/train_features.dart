// scratch/train_features.dart
//
// Standalone Dart CLI to train/update features for a specific organism.
// Takes scientific name and image path as input.
//
// Usage:
//   dart run scratch/train_features.dart --scientific-name "Panthera tigris" --image path/to/image.png
//   dart run scratch/train_features.dart   (interactive mode)
//
// The script:
//   1. Looks up the organism by scientific name in Organisms.json
//   2. Extracts biometric features from the provided image
//   3. Upserts into sprite_features.db (averages with existing if present)

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) async {
  // Parse CLI args
  String? scientificName;
  String? imagePath;

  for (int i = 0; i < args.length; i++) {
    if ((args[i] == '--scientific-name' || args[i] == '-s') &&
        i + 1 < args.length) {
      scientificName = args[++i];
    } else if ((args[i] == '--image' || args[i] == '-i') &&
        i + 1 < args.length) {
      imagePath = args[++i];
    } else if (args[i] == '--help' || args[i] == '-h') {
      _printUsage();
      exit(0);
    }
  }

  // Interactive mode if args not provided
  if (scientificName == null) {
    stdout.write('Enter scientific name: ');
    scientificName = stdin.readLineSync()?.trim();
  }
  if (imagePath == null) {
    stdout.write('Enter image path: ');
    imagePath = stdin.readLineSync()?.trim();
  }

  // Validate inputs
  if (scientificName == null || scientificName.isEmpty) {
    print('Error: Scientific name is required.');
    _printUsage();
    exit(1);
  }
  if (imagePath == null || !File(imagePath).existsSync()) {
    print('Error: Image file not found: $imagePath');
    exit(1);
  }

  // Look up organism by scientific name
  final organismsJson = File('assets/Organisms.json').readAsStringSync();
  final List organisms = jsonDecode(organismsJson);
  final org = organisms.cast<Map<String, dynamic>?>().firstWhere(
        (o) =>
            (o?['scientific_name'] as String?)?.toLowerCase() ==
            scientificName!.toLowerCase(),
        orElse: () => null,
      );

  if (org == null) {
    print('Error: No organism found with scientific name "$scientificName"');
    print('');
    // Show similar matches
    final firstWord = scientificName.split(' ').first.toLowerCase();
    final matches = organisms.where((o) =>
        ((o['scientific_name'] as String?) ?? '')
            .toLowerCase()
            .contains(firstWord));
    if (matches.isNotEmpty) {
      print('Did you mean one of these?');
      for (var m in matches.take(10)) {
        print('  - ${m['name']} (${m['scientific_name']})');
      }
    }
    exit(1);
  }

  final organismName = org['name'] as String;
  print('Found: $organismName ($scientificName)');

  // Open DB
  sqfliteFfiInit();
  final factory = databaseFactoryFfi;
  final dbPath = p.join(Directory.current.path, 'assets', 'ml', 'sprite_features.db');

  if (!File(dbPath).existsSync()) {
    print('Error: Database not found at $dbPath');
    print('Run "dart run scratch/generate_features_db.dart" first.');
    exit(1);
  }

  final db = await factory.openDatabase(dbPath);

  // Extract features from image
  print('Extracting features from $imagePath...');
  final imageBytes = File(imagePath).readAsBytesSync();
  final decoded = img.decodeImage(imageBytes);
  if (decoded == null) {
    print('Error: Could not decode image.');
    await db.close();
    exit(1);
  }

  final newFeatures = extractFeatures(decoded, organismName);
  print('Features extracted successfully.');

  await upsertFeatureToDb(db, organismName, scientificName: scientificName, newFeatures: newFeatures);
  print('Database updated successfully.');
  await db.close();
  print('');
  print('--- Biometric Training Summary ---');
  print('Species: $organismName');
  print('----------------------------------');
}

Future<void> upsertFeatureToDb(Database db, String organismName, {required String scientificName, required Map<String, dynamic> newFeatures}) async {
  // Check for existing entry
  final existing = await db.query(
    'organism_features',
    where: 'organism_name = ?',
    whereArgs: [organismName],
  );

  if (existing.isNotEmpty) {
    // Average with existing features (weighted by training count)
    final oldRow = existing.first;
    final oldCount = (oldRow['training_count'] as int?) ?? 1;
    final newCount = oldCount + 1;

    // Average numeric fields
    final mergedData = {
      'avg_brightness': _weightedAvg(
          oldRow['avg_brightness'] as double,
          newFeatures['avgBrightness'] as double,
          oldCount),
      'avg_saturation': _weightedAvg(
          oldRow['avg_saturation'] as double,
          newFeatures['avgSaturation'] as double,
          oldCount),
      'aspect_ratio': _weightedAvg(
          oldRow['aspect_ratio'] as double,
          newFeatures['aspectRatio'] as double,
          oldCount),
      'solidity': _weightedAvg(oldRow['solidity'] as double,
          newFeatures['solidity'] as double, oldCount),
      'vertical_symmetry': _weightedAvg(
          oldRow['vertical_symmetry'] as double,
          newFeatures['verticalSymmetry'] as double,
          oldCount),
      'horizontal_symmetry': _weightedAvg(
          oldRow['horizontal_symmetry'] as double,
          newFeatures['horizontalSymmetry'] as double,
          oldCount),
      'edge_density': _weightedAvg(
          oldRow['edge_density'] as double,
          newFeatures['edgeDensity'] as double,
          oldCount),
    };

    // Merge hue bins
    final oldHueBins =
        Map<String, double>.from(jsonDecode(oldRow['hue_bins'] as String));
    final newHueBins = newFeatures['hueBins'] as Map<String, double>;

    final mergedHueBins = <String, double>{};
    for (int hue = 0; hue < 360; hue += 10) {
      final key = 'h$hue';
      final oldVal = oldHueBins[key] ?? 0.0;
      final newVal = newHueBins[key] ?? 0.0;
      mergedHueBins[key] = _weightedAvg(oldVal, newVal, oldCount);
    }

    // Merge spatial hue bins
    final oldSpatial =
        Map<String, double>.from(jsonDecode(oldRow['spatial_hue_bins'] as String));
    final newSpatial = newFeatures['spatialHueBins'] as Map<String, double>;

    final mergedSpatial = <String, double>{};
    for (int gy = 0; gy < 3; gy++) {
      for (int gx = 0; gx < 3; gx++) {
        for (int hue = 0; hue < 360; hue += 10) {
          final key = 'g${gx}${gy}_h$hue';
          final oldVal = oldSpatial[key] ?? 0.0;
          final newVal = newSpatial[key] ?? 0.0;
          if (oldVal > 0 || newVal > 0) {
            mergedSpatial[key] = _weightedAvg(oldVal, newVal, oldCount);
          }
        }
      }
    }

    // Convert dominant colors safely
    String dominantColorsJson = jsonEncode(newFeatures['dominantColors']);
    
    // Attempt to merge dominant colors (naive approach: just take average of new if we want, or keep new)
    // Actually, keeping the most recent dominant colors is fine, or we could union them.
    // Let's just use the new ones for simplicity since they are less critical than bins.

    await db.update(
      'organism_features',
      {
        ...mergedData,
        'hue_bins': jsonEncode(mergedHueBins),
        'spatial_hue_bins': jsonEncode(mergedSpatial),
        'dominant_colors': dominantColorsJson,
        'training_count': newCount,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'organism_name = ?',
      whereArgs: [organismName],
    );
  } else {
    // Insert new entry
    await db.insert('organism_features', {
      'organism_name': organismName,
      'scientific_name': scientificName,
      'hue_bins': jsonEncode(newFeatures['hueBins']),
      'spatial_hue_bins': jsonEncode(newFeatures['spatialHueBins']),
      'dominant_colors': jsonEncode(newFeatures['dominantColors']),
      'avg_brightness': newFeatures['avgBrightness'],
      'avg_saturation': newFeatures['avgSaturation'],
      'aspect_ratio': newFeatures['aspectRatio'],
      'solidity': newFeatures['solidity'],
      'vertical_symmetry': newFeatures['verticalSymmetry'],
      'horizontal_symmetry': newFeatures['horizontalSymmetry'],
      'edge_density': newFeatures['edgeDensity'],
      'training_count': 1,
    });

    print('');
    print('=== Training Complete ===');
    print('Organism: $organismName');
    print('Scientific Name: $scientificName');
    print('New feature entry created.');
  }

  // Show final stats
  final result = await db.rawQuery('SELECT COUNT(*) as count FROM organism_features');
  final totalCount = result.first['count'] as int;
  print('Total features in DB: $totalCount');
}

/// Weighted average: (old * oldCount + new) / (oldCount + 1)
double _weightedAvg(double oldVal, double newVal, int oldCount) {
  return (oldVal * oldCount + newVal) / (oldCount + 1);
}

void _printUsage() {
  print('');
  print('Train Features - Add/update organism biometric features');
  print('');
  print('Usage:');
  print('  dart run scratch/train_features.dart [options]');
  print('');
  print('Options:');
  print('  -s, --scientific-name  Scientific name (e.g. "Panthera tigris")');
  print('  -i, --image            Path to image file');
  print('  -h, --help             Show this help');
  print('');
  print('Examples:');
  print('  dart run scratch/train_features.dart \\');
  print('    --scientific-name "Panthera tigris" \\');
  print('    --image photos/tiger.jpg');
  print('');
  print('  dart run scratch/train_features.dart  (interactive mode)');
}

// ============================================================
// Feature extraction (mirrors BiometricService logic exactly)
// ============================================================

Map<String, dynamic> extractFeatures(img.Image decoded, String name) {
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

  // Check for alpha channel
  bool hasAlpha = false;
  for (final pixel in resized) {
    if (pixel.a < 128) {
      hasAlpha = true;
      break;
    }
  }

  List<bool> mask;
  if (hasAlpha) {
    mask = List.generate(resized.width * resized.height, (i) => true);
    for (int i = 0; i < resized.width * resized.height; i++) {
      final p = resized.getPixelSafe(i % resized.width, i ~/ resized.width);
      mask[i] = p.a >= 128;
    }
  } else {
    // Fallback for photos: Detect background from corners
    mask = _detectBackgroundAndGetMask(resized);
  }

  int objectPixelCount = 0;
  int minX = resized.width, maxX = 0, minY = resized.height, maxY = 0;

  for (int i = 0; i < resized.width * resized.height; i++) {
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
  for (int i = 0; i < 36; i++) finalHueBins['h${i * 10}'] = 0;

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

  for (final key in finalHueBins.keys) {
    finalHueBins[key] = finalHueBins[key]! / objectPixelCount;
  }

  final sortedColors = colorCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final dominantColors = sortedColors.take(8).map((e) {
    final q = e.key;
    final r = ((q >> 8) & 0xF) * 17;
    final g = ((q >> 4) & 0xF) * 17;
    final b = (q & 0xF) * 17;
    return (0xFF << 24) | (r << 16) | (g << 8) | b;
  }).toList();

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
        spatialHueBins['g${gx}${gy}_h${bin * 10}'] =
            gridPixels > 0 ? count / gridPixels : 0;
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
    img.Image image, List<bool> mask, int minX, int maxX, int minY, int maxY) {
  int hMatches = 0, vMatches = 0, hTotal = 0, vTotal = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= (minX + maxX) ~/ 2; x++) {
      final x2 = maxX - (x - minX);
      if (x2 < minX || x2 > maxX) continue;
      final p1 = image.getPixel(x, y), p2 = image.getPixel(x2, y);
      hTotal++;
      if (((p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs()) <
          100) hMatches++;
    }
  }
  for (int x = minX; x <= maxX; x++) {
    for (int y = minY; y <= (minY + maxY) ~/ 2; y++) {
      final y2 = maxY - (y - minY);
      if (y2 < minY || y2 > maxY) continue;
      final p1 = image.getPixel(x, y), p2 = image.getPixel(x, y2);
      vTotal++;
      if (((p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs()) <
          100) vMatches++;
    }
  }
  return (
    hTotal > 0 ? hMatches / hTotal : 0.5,
    vTotal > 0 ? vMatches / vTotal : 0.5
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
      final grad = (lum - (pRight.r + pRight.g + pRight.b) / 3.0).abs() +
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
    if (maxV == rf) h = (gf - bf) / d + (gf < bf ? 6 : 0);
    else if (maxV == gf) h = (bf - rf) / d + 2;
    else h = (rf - gf) / d + 4;
    h /= 6;
  }
  return [h * 360, maxV == 0 ? 0 : d / maxV, maxV];
}

/// Detect background color and return a mask of non-background pixels.
/// Used for real-world photos where transparency is missing.
List<bool> _detectBackgroundAndGetMask(img.Image image) {
  final mask = List<bool>.filled(image.width * image.height, true);
  
  // Sample perimeter points for background "prototypes"
  final List<List<int>> prototypes = [];
  final samples = [
    [0, 0], [image.width - 1, 0], [0, image.height - 1], [image.width - 1, image.height - 1],
    [image.width ~/ 2, 0], [image.width ~/ 2, image.height - 1],
    [0, image.height ~/ 2], [image.width - 1, image.height ~/ 2]
  ];
  
  for (final s in samples) {
    final p = image.getPixel(s[0], s[1]);
    prototypes.add([p.r.toInt(), p.g.toInt(), p.b.toInt()]);
  }

  final double centerX = image.width / 2.0;
  final double centerY = image.height / 2.0;
  final double maxDist = sqrt(pow(centerX, 2) + pow(centerY, 2));

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      final r = p.r.toInt(), g = p.g.toInt(), b = p.b.toInt();

      double minStatsDist = 1000.0;
      for (final bp in prototypes) {
        // Weighted distance for human color perception
        final d = sqrt(
          pow(r - bp[0], 2) * 0.299 + 
          pow(g - bp[1], 2) * 0.587 + 
          pow(b - bp[2], 2) * 0.114
        );
        if (d < minStatsDist) minStatsDist = d;
      }

      // Distance from center (0.0 at center, 1.0 at farthest corner)
      final distFromCenter = sqrt(pow(x - centerX, 2) + pow(y - centerY, 2)) / maxDist;
      
      // Subject Protection: 
      // We use a parabolic threshold curve. 
      // Near center (dist < 0.4), threshold is extremely strict (protect subject).
      double threshold;
      if (distFromCenter < 0.4) {
        threshold = 8.0; // Very strict
      } else {
        threshold = 8.0 + pow(distFromCenter * 1.5, 3) * 60.0;
      }

      if (minStatsDist < threshold) {
        mask[y * image.width + x] = false;
      }
    }
  }
  return mask;
}
