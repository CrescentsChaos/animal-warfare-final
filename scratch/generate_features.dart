import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

class OrganismFeature {
  final String organismName;
  final List<List<int>> dominantColors;
  final Map<String, double> hueBins;
  final double avgBrightness;
  final double avgSaturation;
  final double aspectRatio;
  final double solidity;
  final double horizontalSymmetry;
  final double verticalSymmetry;
  final double edgeDensity;

  OrganismFeature({
    required this.organismName,
    required this.dominantColors,
    required this.hueBins,
    required this.avgBrightness,
    required this.avgSaturation,
    required this.aspectRatio,
    required this.solidity,
    required this.horizontalSymmetry,
    required this.verticalSymmetry,
    required this.edgeDensity,
  });

  Map<String, dynamic> toJson() => {
    'name': organismName,
    'colors': dominantColors,
    'hue_bins': hueBins,
    'brightness': avgBrightness,
    'saturation': avgSaturation,
    'aspect_ratio': aspectRatio,
    'solidity': solidity,
    'h_symmetry': horizontalSymmetry,
    'v_symmetry': verticalSymmetry,
    'edge_density': edgeDensity,
  };
}

// Minimal HSV implementation since we don't have flutter/material.dart
class HSV {
  final double hue;
  final double saturation;
  final double value;
  HSV(this.hue, this.saturation, this.value);

  static HSV fromRgb(int r, int g, int b) {
    double rf = r / 255.0;
    double gf = g / 255.0;
    double bf = b / 255.0;
    double maxV = max(rf, max(gf, bf));
    double minV = min(rf, min(gf, bf));
    double delta = maxV - minV;

    double h = 0;
    if (delta == 0) {
      h = 0;
    } else if (maxV == rf)
      h = 60 * (((gf - bf) / delta) % 6);
    else if (maxV == gf)
      h = 60 * (((bf - rf) / delta) + 2);
    else
      h = 60 * (((rf - gf) / delta) + 4);

    if (h < 0) h += 360;

    double s = maxV == 0 ? 0 : delta / maxV;
    double v = maxV;

    return HSV(h, s, v);
  }
}

OrganismFeature extractFeatures(Uint8List imageBytes, String name) {
  final img.Image? decoded = img.decodeImage(imageBytes);
  if (decoded == null) throw "Failed to decode $name";

  final img.Image resized = img.copyResize(decoded, width: 64, height: 64);

  final List<HSV> hsvPixels = [];
  final Map<int, int> colorCounts = {};
  int objectPixelCount = 0;
  int minX = resized.width, maxX = 0;
  int minY = resized.height, maxY = 0;

  for (int y = 0; y < resized.height; y++) {
    for (int x = 0; x < resized.width; x++) {
      final pixel = resized.getPixel(x, y);
      if (pixel.a < 128) continue;

      objectPixelCount++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;

      final r = pixel.r.toInt();
      final g = pixel.g.toInt();
      final b = pixel.b.toInt();

      final quantized = ((r >> 4) << 8) | ((g >> 4) << 4) | (b >> 4);
      colorCounts[quantized] = (colorCounts[quantized] ?? 0) + 1;

      hsvPixels.add(HSV.fromRgb(r, g, b));
    }
  }

  if (hsvPixels.isEmpty) {
    return OrganismFeature(
      organismName: name,
      dominantColors: [],
      hueBins: {},
      avgBrightness: 0.5,
      avgSaturation: 0.5,
      aspectRatio: 1.0,
      solidity: 0.5,
      horizontalSymmetry: 0.5,
      verticalSymmetry: 0.5,
      edgeDensity: 0.1,
    );
  }

  final sortedColors = colorCounts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final dominantColors = sortedColors.take(8).map((e) {
    final q = e.key;
    return [((q >> 8) & 0xF) * 17, ((q >> 4) & 0xF) * 17, (q & 0xF) * 17];
  }).toList();

  final hueBins = <String, double>{};
  for (int i = 0; i < 12; i++) {
    hueBins['h${i * 30}'] = 0;
  }
  double totalBrightness = 0;
  double totalSaturation = 0;

  for (final hsv in hsvPixels) {
    final binIndex = (hsv.hue / 30).floor().clamp(0, 11);
    hueBins['h${binIndex * 30}'] = (hueBins['h${binIndex * 30}'] ?? 0) + 1;
    totalBrightness += hsv.value;
    totalSaturation += hsv.saturation;
  }

  final total = hsvPixels.length.toDouble();
  for (final key in hueBins.keys) {
    hueBins[key] = hueBins[key]! / total;
  }

  final bboxW = (maxX - minX + 1).toDouble();
  final bboxH = (maxY - minY + 1).toDouble();
  final aspectRatio = bboxW / bboxH;
  final solidity = objectPixelCount / (bboxW * bboxH);

  // Symmetry
  int hMatches = 0, vMatches = 0, hTotal = 0, vTotal = 0;
  for (int y = minY; y <= maxY; y++) {
    for (int x = minX; x <= (minX + maxX) ~/ 2; x++) {
      final x2 = maxX - (x - minX);
      if (x2 < minX || x2 > maxX) continue;
      final p1 = resized.getPixel(x, y);
      final p2 = resized.getPixel(x2, y);
      hTotal++;
      // Color distance check for symmetry
      final d = (p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs();
      if (d < 80) hMatches++; // Consistent threshold
    }
  }
  for (int x = minX; x <= maxX; x++) {
    for (int y = minY; y <= (minY + maxY) ~/ 2; y++) {
      final y2 = maxY - (y - minY);
      if (y2 < minY || y2 > maxY) continue;
      final p1 = resized.getPixel(x, y);
      final p2 = resized.getPixel(x, y2);
      vTotal++;
      final d = (p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs();
      if (d < 80) vMatches++;
    }
  }

  // Edge Density
  int edgePixels = 0, totalEdgeArea = 0;
  for (int y = 1; y < resized.height - 1; y++) {
    for (int x = 1; x < resized.width - 1; x++) {
      final p = resized.getPixel(x, y);
      if (p.a < 128) continue;
      final pR = resized.getPixel(x + 1, y);
      final pD = resized.getPixel(x, y + 1);
      final lum = (p.r + p.g + p.b) / 3.0;
      final lumR = (pR.r + pR.g + pR.b) / 3.0;
      final lumD = (pD.r + pD.g + pD.b) / 3.0;
      if (((lum - lumR).abs() + (lum - lumD).abs()) > 30) edgePixels++;
      totalEdgeArea++;
    }
  }

  return OrganismFeature(
    organismName: name,
    dominantColors: dominantColors,
    hueBins: hueBins,
    avgBrightness: totalBrightness / total,
    avgSaturation: totalSaturation / total,
    aspectRatio: aspectRatio,
    solidity: solidity,
    horizontalSymmetry: hTotal > 0 ? hMatches / hTotal : 0.5,
    verticalSymmetry: vTotal > 0 ? vMatches / vTotal : 0.5,
    edgeDensity: totalEdgeArea > 0 ? edgePixels / totalEdgeArea : 0.0,
  );
}

void main() async {
  final organismsJson = File('assets/Organisms.json').readAsStringSync();
  final List organisms = jsonDecode(organismsJson);
  final Map<String, dynamic> allFeatures = {};

  print("Processing ${organisms.length} organisms...");

  for (var org in organisms) {
    final name = org['name'];
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r"[''']"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final path = 'assets/sprites/$slug.png';

    if (File(path).existsSync()) {
      try {
        final bytes = File(path).readAsBytesSync();
        final feature = extractFeatures(bytes, name);
        allFeatures[name] = feature.toJson();
      } catch (e) {
        print("Error processing $name: $e");
      }
    }
  }

  File(
    'assets/ml/sprite_features.json',
  ).writeAsStringSync(jsonEncode(allFeatures));
  print("Saved features for ${allFeatures.length} organisms.");
}
