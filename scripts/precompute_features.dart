// scripts/precompute_features.dart
//
// Pure Dart script to pre-compute color features for all sprites.
// Run with: dart scripts/precompute_features.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;

void main() async {
  final spriteDir = Directory('assets/sprites');
  final outputFile = File('assets/ml/sprite_features.json');

  if (!spriteDir.existsSync()) {
    print('Error: assets/sprites directory not found.');
    return;
  }

  final organismsFile = File('assets/Organisms.json');
  final organismsJson = jsonDecode(organismsFile.readAsStringSync()) as List;
  final filenameToName = <String, String>{};
  for (final org in organismsJson) {
    final name = org['name'] as String;
    final filename = name.toLowerCase().replaceAll(RegExp(r"['\-\s]"), '_') + '.png';
    filenameToName[filename] = name;
  }

  final entities = spriteDir.listSync().whereType<File>().toList();
  print('Found ${entities.length} sprites. Starting computation...');

  final features = <String, dynamic>{};
  int count = 0;

  for (final file in entities) {
    if (!file.path.endsWith('.png')) continue;

    final filename = file.uri.pathSegments.last;
    final name = filenameToName[filename] ??
        filename.replaceAll('.png', '')
            .split('_')
            .map((s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1))
            .join(' ');

    try {
      final bytes = file.readAsBytesSync();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) continue;

      final resized = img.copyResize(decoded, width: 64, height: 64);
      final feature = extractFeatures(resized, name);
      features[name] = feature;

      count++;
      if (count % 100 == 0) {
        print('Processed $count / ${entities.length}...');
      }
    } catch (e) {
      print('Error processing ${file.path}: $e');
    }
  }

  print('Writing results to ${outputFile.path}...');
  outputFile.writeAsStringSync(JsonEncoder.withIndent('  ').convert(features));
  print('Done! Successfully processed $count sprites.');
}

Map<String, dynamic> extractFeatures(img.Image decoded, String name) {
  // 1. Resize with padding to maintain aspect ratio (Matching BiometricService)
  img.Image resized;
  if (decoded.width == decoded.height) {
    resized = img.copyResize(decoded, width: 64, height: 64);
  } else {
    final size = max(decoded.width, decoded.height);
    final padded = img.Image(width: size, height: size);
    img.fill(padded, color: img.ColorRgba8(0, 0, 0, 0)); 
    final xOffset = (size - decoded.width) ~/ 2;
    final yOffset = (size - decoded.height) ~/ 2;
    img.compositeImage(padded, decoded, dstX: xOffset, dstY: yOffset);
    resized = img.copyResize(padded, width: 64, height: 64);
  }

  final mask = List.generate(resized.width * resized.height, (i) => true);
  int objectPixelCount = 0;
  int minX = resized.width, maxX = 0, minY = resized.height, maxY = 0;

  for (int i=0; i < resized.width * resized.height; i++) {
      final p = resized.getPixelSafe(i % resized.width, i ~/ resized.width);
      mask[i] = p.a >= 128;
      if (mask[i]) {
        objectPixelCount++;
        final x = i % resized.width;
        final y = i ~/ resized.width;
        if (x < minX) minX = x; if (x > maxX) maxX = x;
        if (y < minY) minY = y; if (y > maxY) maxY = y;
      }
  }

  if (objectPixelCount == 0) return {'name': name};

  final Map<int, int> colorCounts = {};
  double totalBrightness = 0, totalSaturation = 0;
  final finalHueBins = <String, double>{};
  for (int i = 0; i < 36; i++) finalHueBins['h${i * 10}'] = 0;

  for (int y = 0; y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      if (!mask[y * resized.width + x]) continue;
      final p = resized.getPixel(x, y);
      final hsv = rgbToHsv(p.r.toInt(), p.g.toInt(), p.b.toInt());
      final binIndex = (hsv[0] / 10).floor().clamp(0, 35);
      finalHueBins['h${binIndex * 10}'] = (finalHueBins['h${binIndex * 10}'] ?? 0) + 1;
      totalSaturation += hsv[1];
      totalBrightness += hsv[2];

      final quantized = ((p.r.toInt() >> 4) << 8) | ((p.g.toInt() >> 4) << 4) | (p.b.toInt() >> 4);
      colorCounts[quantized] = (colorCounts[quantized] ?? 0) + 1;
    }
  }

  for (final key in finalHueBins.keys) finalHueBins[key] = finalHueBins[key]! / objectPixelCount;

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
          if (mask[y * resized.width + x]) {
            final p = resized.getPixel(x, y);
            final hsv = rgbToHsv(p.r.toInt(), p.g.toInt(), p.b.toInt());
            final bin = ((hsv[0] % 360) / 10).floor();
            gridBins[bin] = (gridBins[bin] ?? 0) + 1;
            gridPixels++;
          }
        }
      }
      gridBins.forEach((bin, count) {
        spatialHueBins['g${gx}${gy}_h${bin * 10}'] = gridPixels > 0 ? count / gridPixels : 0;
      });
    }
  }

  final sym = _calculateSymmetry(resized, mask, minX, maxX, minY, maxY);

  return {
    'organismName': name,
    'hueBins': finalHueBins,
    'spatialHueBins': spatialHueBins,
    'avgBrightness': totalBrightness / objectPixelCount,
    'avgSaturation': totalSaturation / objectPixelCount,
    'aspectRatio': (maxX - minX + 1) / (maxY - minY + 1),
    'solidity': objectPixelCount / ((maxX - minX + 1) * (maxY - minY + 1)),
    'verticalSymmetry': sym.$2,
    'horizontalSymmetry': sym.$1,
    'edgeDensity': _calculateEdgeDensity(resized, mask),
  };
}

(double, double) _calculateSymmetry(img.Image image, List<bool> mask, int minX, int maxX, int minY, int maxY) {
  int hMatches = 0, vMatches = 0, hTotal = 0, vTotal = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= (minX + maxX) ~/ 2; x++) {
      final x2 = maxX - (x - minX);
      if (x2 < minX || x2 > maxX) continue;
      final p1 = image.getPixel(x, y), p2 = image.getPixel(x2, y);
      hTotal++;
      if (((p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs()) < 100) hMatches++;
    }
  }
  for (int x = minX; x <= maxX; x++) {
    for (int y = minY; y <= (minY + maxY) ~/ 2; y++) {
      final y2 = maxY - (y - minY);
      if (y2 < minY || y2 > maxY) continue;
      final p1 = image.getPixel(x, y), p2 = image.getPixel(x, y2);
      vTotal++;
      if (((p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs()) < 100) vMatches++;
    }
  }
  return (hTotal > 0 ? hMatches / hTotal : 0.5, vTotal > 0 ? vMatches / vTotal : 0.5);
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
      final grad = (lum - (pRight.r + pRight.g + pRight.b) / 3.0).abs() + (lum - (pDown.r + pDown.g + pDown.b) / 3.0).abs();
      if (grad > 30) edgePixels++;
      totalPixels++;
    }
  }
  return totalPixels > 0 ? edgePixels / totalPixels : 0.0;
}

List<double> rgbToHsv(int r, int g, int b) {
  double rf = r / 255.0, gf = g / 255.0, bf = b / 255.0;
  double max = [rf, gf, bf].reduce((a, b) => a > b ? a : b);
  double min = [rf, gf, bf].reduce((a, b) => a < b ? a : b);
  double d = max - min;
  double h = 0;
  if (d != 0) {
    if (max == rf) h = (gf - bf) / d + (gf < bf ? 6 : 0);
    else if (max == gf) h = (bf - rf) / d + 2;
    else h = (rf - gf) / d + 4;
    h /= 6;
  }
  return [h * 360, max == 0 ? 0 : d / max, max];
}
