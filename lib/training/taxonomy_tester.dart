import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

/// Standalone taxonomy tester.
/// Usage: dart run lib/training/taxonomy_tester.dart <animal_name> <expected_class>
/// Example: dart run lib/training/taxonomy_tester.dart lion mammal
void main(List<String> args) async {
  if (args.length < 2) {
    print(
      'Usage: dart run lib/training/taxonomy_tester.dart <animal_name> <expected_class>',
    );
    return;
  }

  final String animalName = args[0];
  final String expectedClass = args[1];

  // Initialize SQLite FFI
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;

  final dbPath = p.join(
    Directory.current.path,
    'assets',
    'ml',
    'sprite_features.db',
  );

  if (!File(dbPath).existsSync()) {
    print(
      'Error: Database not found at $dbPath. Please run the trainer first.',
    );
    return;
  }

  final db = await databaseFactory.openDatabase(dbPath);

  // Load profiles from SQL
  final List<Map<String, dynamic>> profilesData = await db.query(
    'taxonomy_profiles',
  );
  if (profilesData.isEmpty) {
    print('Error: No taxonomy profiles found in database.');
    await db.close();
    return;
  }

  List<_Profile> profiles = [];
  int totalSamples = 0;
  for (var row in profilesData) {
    profiles.add(
      _Profile(
        cls: row['animal_class'] as String,
        means: Map<String, double>.from(json.decode(row['feature_means'])),
        variances: Map<String, double>.from(
          json.decode(row['feature_variances']),
        ),
        count: row['sample_count'] as int,
      ),
    );
    totalSamples += row['sample_count'] as int;
  }

  await db.close();

  // Find sprite file
  final spriteFile = File('assets/sprites/$animalName.png');
  if (!spriteFile.existsSync()) {
    print('Error: Sprite not found at ${spriteFile.path}');
    return;
  }

  print('Testing $animalName (Expected: $expectedClass)...');

  // Process image
  final decoded = img.decodeImage(spriteFile.readAsBytesSync());
  if (decoded == null) {
    print('Error: Failed to decode image.');
    return;
  }

  final resized = _preprocessToMatch(decoded);
  final mask = _buildAlphaMask(resized);
  final features = _extractFeatures(resized, mask);

  if (features.isEmpty) {
    print('Error: No features extracted (possibly empty mask).');
    return;
  }

  // Feature weights (must match TaxonomyEngine and TaxonomyTrainer)
  final featureWeights = {
    'aspectRatio': 15.0,
    'solidity': 15.0,
    'compactness': 15.0,
    'limbDensity': 6.0,
    'edgeDensity': 4.0,
    'verticalBias': 4.0,
    'topHeavyBias': 8.0,
    'hueComplexity': 8.0,
    'directionalEdgeBias': 6.0,
    'hSymmetry': 2.0,
    'vSymmetry': 2.0,
    'coreSolidity': 10.0,
    'bottomHeavyBias': 4.0,
    'maxWidthRowBias': 5.0,
    'maxHeightColBias': 5.0,
    'bottomCenterDensity': 6.0,
    'cornerDensity': 4.0,
    'radialOverlap': 6.0,
    'yCentroid': 8.0,
    'jaggedness': 10.0,
    'topThirdDensity': 10.0,
    'bilateralSym': 12.0,
    'solidity': 15.0,
    'diagonalDensity': 12.0,
    'edgeDensity': 8.0,
    'hSymmetry': 10.0,
    'vSymmetry': 10.0,
    'convexHullRatio': 10.0,
  };

  // Distance-based classification (GNB)
  String bestClass = 'unknown';
  double bestScore = double.negativeInfinity;
  Map<String, double> posteriors = {};

  for (var profile in profiles) {
    // Prior influence reduced to 2.0 so physical features matter more
    double score = log(profile.count / totalSamples) * 2.0;

    // Distance-based scoring with CLASS-SPECIFIC Variance (Proper Gaussian NB)
    featureWeights.forEach((key, defaultWeight) {
      double weight = defaultWeight;
      // Increase topHeavyBias for Birds
      if (key == 'topHeavyBias' && profile.cls == 'bird') {
        weight = 15.0; // Increased weight for birds
      }

      double val = features[key] ?? 0.5;
      double mean = profile.means[key] ?? 0.5;
      double variance = profile.variances[key] ?? 0.04;

      if (key == 'aspectRatio') {
        val = log(val.clamp(0.1, 10.0));
        mean = log(mean.clamp(0.1, 10.0));
      }

      double dist = (val - mean);
      score -= 0.5 * (dist * dist / variance) * weight;
    });

    // Hue bins (Color profile) - Use a lower weight to prioritize structure
    double colorScore = 0;
    for (var key in features.keys.where(
      (k) => k.startsWith('h') && k != 'hSymmetry' && k != 'hWhite',
    )) {
      double val = features[key] ?? 0;
      double mean = profile.means[key] ?? 0;
      double variance = profile.variances[key] ?? 0.005;

      colorScore -= 0.5 * (pow(val - mean, 2) / variance);
    }
    score += colorScore * 0.2; // Reduced color influence

    posteriors[profile.cls] = score;

    if (score > bestScore) {
      bestScore = score;
      bestClass = profile.cls;
    }
  }

  print('\nRESULT:');
  bool pass = bestClass == expectedClass;
  if (pass) {
    print('  ✓ SUCCESS: Predicted $bestClass');
  } else {
    print('  ✗ FAILURE: Predicted $bestClass, Expected $expectedClass');
  }

  print('\nTop Scores:');
  final sorted = posteriors.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (var s in sorted.take(5)) {
    print('  ${s.key.padRight(12)}: ${s.value.toStringAsFixed(2)}');
  }
}

// --- SHARED UTILS (Duplicated from Trainer for standalone convenience) ---

img.Image _preprocessToMatch(img.Image decoded) {
  img.Image resized;
  if (decoded.width == decoded.height) {
    resized = img.copyResize(decoded, width: 400, height: 400);
  } else {
    final size = max(decoded.width, decoded.height);
    final padded = img.Image(width: size, height: size, numChannels: 4);
    img.fill(padded, color: img.ColorRgba8(0, 0, 0, 0));
    final xOffset = (size - decoded.width) ~/ 2;
    final yOffset = (size - decoded.height) ~/ 2;
    img.compositeImage(padded, decoded, dstX: xOffset, dstY: yOffset);
    resized = img.copyResize(padded, width: 400, height: 400);
  }
  return resized;
}

List<bool> _buildAlphaMask(img.Image resized) {
  return List.generate(resized.width * resized.height, (i) {
    final p = resized.getPixel(i % resized.width, i ~/ resized.width);
    return p.a >= 128;
  });
}

Map<String, double> _extractFeatures(img.Image resized, List<bool> mask) {
  Map<String, double> f = {};

  int objectPixelCount = 0;
  int minX = resized.width, maxX = 0, minY = resized.height, maxY = 0;

  // Hue bins: 36 chromatic + 3 achromatic
  Map<String, double> hueBins = {};
  for (int i = 0; i < 36; i++) {
    hueBins['h${i * 10}'] = 0;
  }
  hueBins['hWhite'] = 0;
  hueBins['hBlack'] = 0;
  hueBins['hGrey'] = 0;

  double totalBrightness = 0;
  double totalSaturation = 0;

  for (int y = 0; y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      if (!mask[y * resized.width + x]) continue;

      final pixel = resized.getPixel(x, y);
      objectPixelCount++;

      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;

      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      final hsv = _rgbToHsv(r, g, b);
      double hue = hsv[0];
      double sat = hsv[1];
      double val = hsv[2];

      totalBrightness += val;
      totalSaturation += sat;

      if (val < 0.15) {
        hueBins['hBlack'] = (hueBins['hBlack'] ?? 0) + 1;
      } else if (sat < 0.15) {
        if (val > 0.8) {
          hueBins['hWhite'] = (hueBins['hWhite'] ?? 0) + 1;
        } else {
          hueBins['hGrey'] = (hueBins['hGrey'] ?? 0) + 1;
        }
      } else {
        final binIndex = (hue / 10).floor().clamp(0, 35);
        hueBins['h${binIndex * 10}'] = (hueBins['h${binIndex * 10}'] ?? 0) + 1;
      }
    }
  }

  if (objectPixelCount == 0) return {};

  for (final key in hueBins.keys) {
    hueBins[key] = hueBins[key]! / objectPixelCount;
    f[key] = hueBins[key]!;
  }

  f['aspectRatio'] = (maxX - minX + 1) / (maxY - minY + 1);
  f['solidity'] = objectPixelCount / ((maxX - minX + 1) * (maxY - minY + 1));
  f['avgBrightness'] = totalBrightness / objectPixelCount;
  f['avgSaturation'] = totalSaturation / objectPixelCount;
  f['edgeDensity'] = _calculateEdgeDensity(resized, mask);

  final sym = _calculateSymmetry(resized, mask, minX, maxX, minY, maxY);
  f['hSymmetry'] = sym.$1;
  f['vSymmetry'] = sym.$2;

  f['verticalBias'] = _calculateVerticalBias(resized, mask);

  int topPixels = 0;
  for (int y = 0; y < (resized.height * 0.4).toInt(); y++) {
    for (int x = 0; x < resized.width; x++) {
      if (mask[y * resized.width + x]) topPixels++;
    }
  }
  f['topHeavyBias'] = objectPixelCount > 0 ? topPixels / objectPixelCount : 0.0;

  int bottomPixels = 0;
  for (int y = (resized.height * 0.6).toInt(); y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      if (mask[y * resized.width + x]) bottomPixels++;
    }
  }
  f['bottomHeavyBias'] = objectPixelCount > 0 ? bottomPixels / objectPixelCount : 0.0;

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
  final double coreArea = max(1, (coreMaxX - coreMinX + 1) * (coreMaxY - coreMinY + 1)).toDouble();
  f['coreSolidity'] = corePixels / coreArea;

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
  f['maxWidthRowBias'] = (maxY > minY) ? (maxRowY - minY) / (maxY - minY) : 0.5;

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
  final double colXNorm = (maxX > minX) ? (maxColX - minX) / (maxX - minX) : 0.5;
  f['maxHeightColBias'] = (colXNorm - 0.5).abs() * 2.0;

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
  final double bcArea = max(1, (bcMaxX - bcMinX + 1) * (bcMaxY - bcMinY + 1)).toDouble();
  f['bottomCenterDensity'] = bcPixels / bcArea;

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
  f['cornerDensity'] = cornerPixels / cornerArea;

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
  f['diagonalDensity'] = diagonalDensity;

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
  f['lowerQuadrantSymmetry'] = (lqLeft + lqRight) > 0 ? 
    min(lqLeft, lqRight) / max(lqLeft, lqRight) : 0.0;

  // NEW: Horizontal Centroid Shift
  int totalX = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        totalX += x;
      }
    }
  }
  final double centroidX = objectPixelCount > 0 ? totalX / objectPixelCount : lqMidX.toDouble();
  f['horizontalCentroidShift'] = (maxX > minX) ? (centroidX - minX) / (maxX - minX) : 0.5;

  // NEW: Convex Hull Ratio (Proxy using diamond area)
  final double diamondArea = (maxX - minX + 1) * (maxY - minY + 1) / 2.0;
  f['convexHullRatio'] = diamondArea > 0 ? (objectPixelCount / diamondArea).clamp(0.0, 1.0) : 0.0;

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
  f['verticalMassDistribution'] = objectPixelCount > 0 ? edgeMass / objectPixelCount : 0.0;

  // NEW: Color Granularity
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
  f['colorGranularity'] = (uniqueColors.length / 4096.0).clamp(0.0, 1.0);

  // NEW: Fringe Density (Alpha boundary pixels)
  int fringePixels = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        if (x == minX || x == maxX || y == minY || y == maxY ||
            !mask[(y - 1) * resized.width + x] || !mask[(y + 1) * resized.width + x] ||
            !mask[y * resized.width + (x - 1)] || !mask[y * resized.width + (x + 1)]) {
          fringePixels++;
        }
      }
    }
  }
  f['fringeDensity'] = objectPixelCount > 0 ? fringePixels / objectPixelCount : 0.0;

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
  f['verticalThinning'] = maxRowWidth > 0 ? minRowWidth / maxRowWidth : 0.0;
  double widthVariance = 0.0;
  if (rowWidths.isNotEmpty && maxRowWidth > 0) {
    double avgRow = totalRowWidth / rowWidths.length;
    double varSum = 0;
    for (int w in rowWidths) varSum += (w - avgRow).abs();
    widthVariance = (varSum / rowWidths.length) / maxRowWidth;
  }
  f['widthVariance'] = widthVariance;

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
  f['localSymmetry'] = localSymSum / slices;

  // NEW: Color Clustering
  int clusteredPixels = 0;
  for (int y = minY + 1; y <= maxY; y++) {
    for (int x = minX + 1; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
        final p = resized.getPixel(x, y);
        int qc = ((p.r ~/ 32) << 16) | ((p.g ~/ 32) << 8) | (p.b ~/ 32);
        if (mask[(y - 1) * resized.width + x]) {
           final pt = resized.getPixel(x, y - 1);
           if (qc == (((pt.r ~/ 32) << 16) | ((pt.g ~/ 32) << 8) | (pt.b ~/ 32))) clusteredPixels++;
        } else if (mask[y * resized.width + x - 1]) {
           final pl = resized.getPixel(x - 1, y);
           if (qc == (((pl.r ~/ 32) << 16) | ((pl.g ~/ 32) << 8) | (pl.b ~/ 32))) clusteredPixels++;
        }
      }
    }
  }
  f['colorClustering'] = objectPixelCount > 0 ? clusteredPixels / objectPixelCount : 0.0;

  // NEW: Y Gradient (Vertical Centroid)
  int totalY = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) totalY += y;
    }
  }
  final double centroidY = objectPixelCount > 0 ? totalY / objectPixelCount : lqMidY.toDouble();
  f['yGradient'] = (maxY > minY) ? (centroidY - minY) / (maxY - minY) : 0.5;

  // NEW: Shell Index (Pixels within 15% of bounding box edge)
  int shellPixels = 0;
  int shEdgeX = max(1, (maxX - minX) * 0.15).toInt();
  int shEdgeY = max(1, (maxY - minY) * 0.15).toInt();
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) {
         if (x <= minX + shEdgeX || x >= maxX - shEdgeX || y <= minY + shEdgeY || y >= maxY - shEdgeY) {
           shellPixels++;
         }
      }
    }
  }
  f['shellIndex'] = objectPixelCount > 0 ? shellPixels / objectPixelCount : 0.0;

  // NEW: Radial Overlap (Ellipse Area)
  final double ellipseArea = pi * ((maxX - minX + 1) / 2.0) * ((maxY - minY + 1) / 2.0);
  f['radialOverlap'] = ellipseArea > 0 ? (objectPixelCount / ellipseArea).clamp(0.0, 1.0) : 0.0;

  // NEW: yCentroid (Absolute normalized vertical center of mass)
  f['yCentroid'] = objectPixelCount > 0 ? centroidY / resized.height : 0.5;

  // NEW: Jaggedness (Perimeter proxy)
  f['jaggedness'] = objectPixelCount > 0 ? fringePixels / sqrt(objectPixelCount) : 0.0;

  // NEW: Top Third Density
  int topThirdPixels = 0;
  int topThirdY = minY + (maxY - minY + 1) ~/ 3;
  for (int y = minY; y <= topThirdY; y++) {
    for (int x = minX; x <= maxX; x++) {
      if (mask[y * resized.width + x]) topThirdPixels++;
    }
  }
  f['topThirdDensity'] = objectPixelCount > 0 ? topThirdPixels / objectPixelCount : 0.0;

  // NEW: Bilateral Symmetry (Point-by-point matching)
  int matchedSymmetryPixels = 0;
  int totalSymmetryCheck = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x < lqMidX; x++) {
      int oppositeX = maxX - (x - minX);
      if (oppositeX >= 0 && oppositeX < resized.width) {
        totalSymmetryCheck++;
        if (mask[y * resized.width + x] == mask[y * resized.width + oppositeX]) {
          matchedSymmetryPixels++;
        }
      }
    }
  }
  f['bilateralSym'] = totalSymmetryCheck > 0 ? matchedSymmetryPixels / totalSymmetryCheck : 0.0;


  int significantBins = 0;
  hueBins.forEach((key, val) {
    if (val > 0.02) significantBins++;
  });
  f['hueComplexity'] = significantBins / 39.0;

  int perimeter = 0;
  for (int y = 1; y < resized.height - 1; y++) {
    for (int x = 1; x < resized.width - 1; x++) {
      if (!mask[y * resized.width + x]) continue;
      if (!mask[(y - 1) * resized.width + x] ||
          !mask[(y + 1) * resized.width + x] ||
          !mask[y * resized.width + (x - 1)] ||
          !mask[y * resized.width + (x + 1)]) {
        perimeter++;
      }
    }
  }
  f['compactness'] = objectPixelCount > 0
      ? (perimeter * perimeter) / objectPixelCount
      : 1.0;

  int limbPixels = 0;
  for (int y = 1; y < resized.height - 1; y++) {
    for (int x = 1; x < resized.width - 1; x++) {
      if (!mask[y * resized.width + x]) continue;
      int neighbors = 0;
      for (int dy = -2; dy <= 2; dy++) {
        for (int dx = -2; dx <= 2; dx++) {
          int nx = x + dx, ny = y + dy;
          if (nx >= 0 &&
              nx < resized.width &&
              ny >= 0 &&
              ny < resized.height &&
              mask[ny * resized.width + nx]) {
            neighbors++;
          }
        }
      }
      if (neighbors < 18) limbPixels++;
    }
  }
  f['limbDensity'] = objectPixelCount > 0 ? limbPixels / objectPixelCount : 0.0;

  double hEdges = 0, vEdges = 0;
  for (int y = 0; y < resized.height - 1; y++) {
    for (int x = 0; x < resized.width - 1; x++) {
      if (!mask[y * resized.width + x]) continue;
      final p = resized.getPixel(x, y);
      final pRight = resized.getPixel(x + 1, y);
      final pDown = resized.getPixel(x, y + 1);
      hEdges += (p.luminance - pRight.luminance).abs();
      vEdges += (p.luminance - pDown.luminance).abs();
    }
  }
  f['directionalEdgeBias'] = (hEdges - vEdges) / (hEdges + vEdges + 0.001);

  return f;
}

List<double> _rgbToHsv(int r, int g, int b) {
  final rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
  final maxV = max(rf, max(gf, bf)), minV = min(rf, min(gf, bf));
  final d = maxV - minV;
  double h = 0;
  if (d != 0) {
    if (maxV == rf)
      h = (gf - bf) / d + (gf < bf ? 6 : 0);
    else if (maxV == gf)
      h = (bf - rf) / d + 2;
    else
      h = (rf - gf) / d + 4;
    h /= 6;
  }
  return [h * 360, maxV == 0 ? 0 : d / maxV, maxV];
}

double _calculateEdgeDensity(img.Image image, List<bool> mask) {
  int edgePixels = 0;
  int totalPixels = 0;
  for (int y = 1; y < image.height - 1; y++) {
    for (int x = 1; x < image.width - 1; x++) {
      if (!mask[y * image.width + x]) continue;
      final p = image.getPixel(x, y);
      final pRight = image.getPixel(x + 1, y);
      final pDown = image.getPixel(x, y + 1);
      double lum = (p.r + p.g + p.b) / 3.0;
      double lumR = (pRight.r + pRight.g + pRight.b) / 3.0;
      double lumD = (pDown.r + pDown.g + pDown.b) / 3.0;
      if ((lum - lumR).abs() + (lum - lumD).abs() > 30) edgePixels++;
      totalPixels++;
    }
  }
  return totalPixels > 0 ? edgePixels / totalPixels : 0;
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
      hTotal++;
      if (mask[y * image.width + x] == mask[y * image.width + x2]) hMatches++;
    }
  }
  for (int x = minX; x <= maxX; x++) {
    for (int y = minY; y <= (minY + maxY) ~/ 2; y++) {
      final y2 = maxY - (y - minY);
      if (y2 < minY || y2 > maxY) continue;
      vTotal++;
      if (mask[y * image.width + x] == mask[y2 * image.width + x]) vMatches++;
    }
  }
  return (
    hTotal > 0 ? hMatches / hTotal : 0.5,
    vTotal > 0 ? vMatches / vTotal : 0.5,
  );
}

double _calculateVerticalBias(img.Image image, List<bool> mask) {
  int topHalfPixels = 0, totalPixels = 0;
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      if (mask[y * image.width + x]) {
        totalPixels++;
        if (y < image.height / 2) topHalfPixels++;
      }
    }
  }
  return totalPixels > 0 ? topHalfPixels / totalPixels : 0.5;
}

class _Profile {
  final String cls;
  final Map<String, double> means;
  final Map<String, double> variances;
  final int count;
  _Profile({
    required this.cls,
    required this.means,
    required this.variances,
    required this.count,
  });
}
