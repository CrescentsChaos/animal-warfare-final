// lib/services/biometric_service.dart
//
// Offline Biometric Scanner Service
// Uses sprite color-histogram matching + text-based keyword scoring
// to identify organisms from camera/gallery images.

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/services/segmentation_service.dart';
import 'package:animal_warfare/services/feature_db_service.dart';
import 'package:animal_warfare/services/taxonomy_service.dart';

/// A scored match result from the biometric scanner.
class ScanResult {
  final Organism organism;
  final double confidence; // 0.0 - 1.0
  final String matchReason;
  final bool isExternal;
  final Uint8List? maskedImage; // The segmented subject image
  final Map<String, double> featureScores; // Breakdown of match reasons
  final bool isGenusMate;
  final AnimalClass detectedClass;
  final bool isPinpointed;

  ScanResult({
    required this.organism,
    required this.confidence,
    required this.matchReason,
    this.isExternal = false,
    this.maskedImage,
    this.featureScores = const {},
    this.isGenusMate = false,
    this.detectedClass = AnimalClass.unknown,
    this.isPinpointed = false,
    this.predictedDiet = 'unknown',
    this.predictedWeight = 0.0,
  });
  final String predictedDiet;
  final double predictedWeight;
}

/// Feature set extracted from a sprite or photo, including color and shape.
class OrganismFeature {
  final String organismName;
  final List<Color> dominantColors;
  final Map<String, double> hueBins;
  final Map<String, double>? spatialHueBins; // Grid-based hue info
  final double avgBrightness;
  final double avgSaturation;
  final double aspectRatio;
  final double solidity;
  final double verticalSymmetry;
  final double horizontalSymmetry;
  final double edgeDensity;
  final double verticalBias;
  final double topHeavyBias;
  final double hueComplexity;
  final double compactness;
  final double limbDensity;
  final double directionalEdgeBias;
  final double coreSolidity;
  final double bottomHeavyBias;
  final double maxWidthRowBias;
  final double maxHeightColBias;
  final double bottomCenterDensity;
  final double cornerDensity;
  final double diagonalDensity;
  final double lowerQuadrantSymmetry;
  final double horizontalCentroidShift;
  final double convexHullRatio;
  final double verticalMassDistribution;
  final double colorGranularity;
  final double fringeDensity;
  final double verticalThinning;
  final double localSymmetry;
  final double colorClustering;
  final double yGradient;
  final double widthVariance;
  final double shellIndex;
  final double radialOverlap;
  final double yCentroid;
  final double jaggedness;
  final double topThirdDensity;
  final double bilateralSym;
  final String? animalClass;
  final String? diet;
  final double? weight;

  OrganismFeature({
    required this.organismName,
    required this.dominantColors,
    required this.hueBins,
    this.spatialHueBins,
    required this.avgBrightness,
    required this.avgSaturation,
    required this.aspectRatio,
    required this.solidity,
    required this.verticalSymmetry,
    required this.horizontalSymmetry,
    required this.edgeDensity,
    this.verticalBias = 0.5,
    this.topHeavyBias = 0.5,
    this.hueComplexity = 0.0,
    this.compactness = 1.0,
    this.limbDensity = 0.0,
    this.directionalEdgeBias = 0.0,
    this.coreSolidity = 0.0,
    this.bottomHeavyBias = 0.0,
    this.maxWidthRowBias = 0.0,
    this.maxHeightColBias = 0.0,
    this.bottomCenterDensity = 0.0,
    this.cornerDensity = 0.0,
    this.diagonalDensity = 0.0,
    this.lowerQuadrantSymmetry = 0.0,
    this.horizontalCentroidShift = 0.0,
    this.convexHullRatio = 0.0,
    this.verticalMassDistribution = 0.0,
    this.colorGranularity = 0.0,
    this.fringeDensity = 0.0,
    this.verticalThinning = 0.0,
    this.localSymmetry = 0.0,
    this.colorClustering = 0.0,
    this.yGradient = 0.0,
    this.widthVariance = 0.0,
    this.shellIndex = 0.0,
    this.radialOverlap = 0.0,
    this.yCentroid = 0.0,
    this.jaggedness = 0.0,
    this.topThirdDensity = 0.0,
    this.bilateralSym = 0.0,
    this.animalClass,
    this.diet,
    this.weight,
  });

  Map<String, dynamic> toJson() => {
    'organismName': organismName,
    'dominantColors': dominantColors.map((c) => c.value).toList(),
    'hueBins': hueBins,
    'spatialHueBins': spatialHueBins,
    'avgBrightness': avgBrightness,
    'avgSaturation': avgSaturation,
    'aspectRatio': aspectRatio,
    'solidity': solidity,
    'verticalSymmetry': verticalSymmetry,
    'horizontalSymmetry': horizontalSymmetry,
    'edgeDensity': edgeDensity,
    'verticalBias': verticalBias,
    'topHeavyBias': topHeavyBias,
    'hueComplexity': hueComplexity,
    'compactness': compactness,
    'limbDensity': limbDensity,
    'directionalEdgeBias': directionalEdgeBias,
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
    'animalClass': animalClass,
    'diet': diet,
    'weight': weight,
  };

  factory OrganismFeature.fromJson(Map<String, dynamic> json) {
    return OrganismFeature(
      organismName: json['organismName'] ?? 'Unknown',
      dominantColors:
          (json['dominantColors'] as List?)
              ?.map((v) => Color(v as int))
              .toList() ??
          [],
      hueBins: Map<String, double>.from(json['hueBins'] ?? {}),
      spatialHueBins: json['spatialHueBins'] != null
          ? Map<String, double>.from(json['spatialHueBins'])
          : null,
      avgBrightness: (json['avgBrightness'] as num?)?.toDouble() ?? 0.5,
      avgSaturation: (json['avgSaturation'] as num?)?.toDouble() ?? 0.5,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? 1.0,
      solidity: (json['solidity'] as num?)?.toDouble() ?? 0.5,
      verticalSymmetry: (json['verticalSymmetry'] as num?)?.toDouble() ?? 0.5,
      horizontalSymmetry:
          (json['horizontalSymmetry'] as num?)?.toDouble() ?? 0.5,
      edgeDensity: (json['edgeDensity'] as num?)?.toDouble() ?? 0.0,
      verticalBias: (json['verticalBias'] as num?)?.toDouble() ?? 0.5,
      topHeavyBias: (json['topHeavyBias'] as num?)?.toDouble() ?? 0.5,
      hueComplexity: (json['hueComplexity'] as num?)?.toDouble() ?? 0.0,
      compactness: (json['compactness'] as num?)?.toDouble() ?? 1.0,
      limbDensity: (json['limbDensity'] as num?)?.toDouble() ?? 0.0,
      directionalEdgeBias:
          (json['directionalEdgeBias'] as num?)?.toDouble() ?? 0.0,
      coreSolidity: (json['coreSolidity'] as num?)?.toDouble() ?? 0.0,
      bottomHeavyBias: (json['bottomHeavyBias'] as num?)?.toDouble() ?? 0.0,
      maxWidthRowBias: (json['maxWidthRowBias'] as num?)?.toDouble() ?? 0.0,
      maxHeightColBias: (json['maxHeightColBias'] as num?)?.toDouble() ?? 0.0,
      bottomCenterDensity:
          (json['bottomCenterDensity'] as num?)?.toDouble() ?? 0.0,
      cornerDensity: (json['cornerDensity'] as num?)?.toDouble() ?? 0.0,
      diagonalDensity: (json['diagonalDensity'] as num?)?.toDouble() ?? 0.0,
      lowerQuadrantSymmetry:
          (json['lowerQuadrantSymmetry'] as num?)?.toDouble() ?? 0.0,
      horizontalCentroidShift:
          (json['horizontalCentroidShift'] as num?)?.toDouble() ?? 0.0,
      convexHullRatio: (json['convexHullRatio'] as num?)?.toDouble() ?? 0.0,
      verticalMassDistribution:
          (json['verticalMassDistribution'] as num?)?.toDouble() ?? 0.0,
      colorGranularity: (json['colorGranularity'] as num?)?.toDouble() ?? 0.0,
      fringeDensity: (json['fringeDensity'] as num?)?.toDouble() ?? 0.0,
      verticalThinning: (json['verticalThinning'] as num?)?.toDouble() ?? 0.0,
      localSymmetry: (json['localSymmetry'] as num?)?.toDouble() ?? 0.0,
      colorClustering: (json['colorClustering'] as num?)?.toDouble() ?? 0.0,
      yGradient: (json['yGradient'] as num?)?.toDouble() ?? 0.0,
      widthVariance: (json['widthVariance'] as num?)?.toDouble() ?? 0.0,
      shellIndex: (json['shellIndex'] as num?)?.toDouble() ?? 0.0,
      radialOverlap: (json['radialOverlap'] as num?)?.toDouble() ?? 0.0,
      yCentroid: (json['yCentroid'] as num?)?.toDouble() ?? 0.0,
      jaggedness: (json['jaggedness'] as num?)?.toDouble() ?? 0.0,
      topThirdDensity: (json['topThirdDensity'] as num?)?.toDouble() ?? 0.0,
      bilateralSym: (json['bilateralSym'] as num?)?.toDouble() ?? 0.0,
      animalClass: json['animalClass'] as String?,
      diet: json['diet'] as String?,
      weight: (json['weight'] as num?)?.toDouble(),
    );
  }
}

/// Main biometric scanning engine.
class BiometricService {
  static final BiometricService _instance = BiometricService._internal();
  factory BiometricService() => _instance;
  BiometricService._internal();

  List<Organism>? _organisms;
  Map<String, OrganismFeature>? _spriteFeatures;
  bool _isInitialized = false;
  bool _isInitializing = false;

  /// Native ML segmentation service for remove.bg-quality results.
  final SegmentationService _segmentation = SegmentationService();

  /// SQLite-backed feature database.
  final FeatureDbService _featureDb = FeatureDbService();

  /// Taxonomic classification service.
  final TaxonomyService _taxonomy = TaxonomyService();

  /// Whether native ML segmentation is available on this device.
  bool get isNativeSegmentationAvailable => _segmentation.isAvailable;

  /// Initialize the service: load organisms and pre-compute sprite features.
  Future<void> initialize() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;

    try {
      // Load organisms database
      final String response = await rootBundle.loadString(
        'assets/Organisms.json',
      );
      final List<dynamic> animalsData = json.decode(response);
      _organisms = animalsData.map((j) => Organism.fromJson(j)).toList();

      // Load pre-computed sprite features from SQLite DB
      try {
        await _featureDb.initialize();
        _spriteFeatures = await _featureDb.getAllFeatures();
        debugPrint(
          'BiometricService: Loaded ${_spriteFeatures?.length ?? 0} features from DB',
        );
      } catch (e) {
        debugPrint(
          'BiometricService: DB load failed, trying JSON fallback: $e',
        );
        // Fallback: try loading from legacy JSON file
        try {
          final String featuresJson = await rootBundle.loadString(
            'assets/ml/sprite_features.json',
          );
          final Map<String, dynamic> featuresMap = json.decode(featuresJson);
          _spriteFeatures = {};
          for (final entry in featuresMap.entries) {
            _spriteFeatures![entry.key] = OrganismFeature.fromJson(entry.value);
          }
        } catch (_) {
          _spriteFeatures = {};
        }
      }

      // Initialize ML segmentation engine (non-blocking if model download needed)
      _segmentation.initialize().then((_) {
        debugPrint(
          'BiometricService: ML segmentation ready: ${_segmentation.isAvailable}',
        );
      });

      // Initialize taxonomic classification model
      await _taxonomy.initialize();

      _isInitialized = true;
    } catch (e) {
      debugPrint('BiometricService init error: $e');
    } finally {
      _isInitializing = false;
    }
  }

  /// Get the local sprite path for an organism name.
  static String spritePathForName(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r"[''']"), '')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'assets/sprites/$slug.png';
  }

  /// Extract features from raw image bytes, including color and shape.
  /// For input images (photos), this will attempt ML segmentation first,
  /// falling back to the color-distance algorithm if unavailable.
  Future<OrganismFeature> extractFeatures(
    Uint8List imageBytes, {
    String name = 'input',
    Uint8List? preSegmentedBytes,
  }) async {
    // If we already have a pre-segmented image (from scanImage's ML pass), use it
    final bytesToDecode = preSegmentedBytes ?? imageBytes;
    final img.Image? decoded = img.decodeImage(bytesToDecode);
    if (decoded == null) {
      return OrganismFeature(
        organismName: name,
        dominantColors: [],
        hueBins: {},
        avgBrightness: 0.5,
        avgSaturation: 0.5,
        aspectRatio: 1.0,
        solidity: 0.5,
        verticalSymmetry: 0.5,
        horizontalSymmetry: 0.5,
        edgeDensity: 0.0,
      );
    }

    // Resize for performance (now using higher resolution for better accuracy)
    img.Image resized;
    if (decoded.width == decoded.height) {
      resized = img.copyResize(decoded, width: 400, height: 200);
    } else {
      final size = max(decoded.width, decoded.height);
      // IMPORTANT: Must specify numChannels: 4 to avoid stripping alpha channel in package:image 4.x+
      final padded = img.Image(width: size, height: size, numChannels: 4);
      img.fill(padded, color: img.ColorRgba8(0, 0, 0, 0));

      final xOffset = (size - decoded.width) ~/ 2;
      final yOffset = (size - decoded.height) ~/ 2;
      img.compositeImage(padded, decoded, dstX: xOffset, dstY: yOffset);
      resized = img.copyResize(padded, width: 400, height: 200);
    }

    bool hasAlpha = false;
    for (final pixel in resized) {
      if (pixel.a < 128) {
        hasAlpha = true;
        break;
      }
    }

    List<bool>? mask;
    if (preSegmentedBytes != null || hasAlpha) {
      // Image already has alpha (from ML segmentation or sprite) — use alpha as mask
      mask = List.generate(resized.width * resized.height, (i) => true);
      for (int i = 0; i < resized.width * resized.height; i++) {
        final p = resized.getPixelSafe(i % resized.width, i ~/ resized.width);
        mask[i] = p.a >= 128;
      }
    } else if (name == 'input') {
      // No pre-segmented data and no alpha — fallback to color-distance masking
      mask = _detectBackgroundAndGetMask(resized);
    } else {
      mask = List.generate(resized.width * resized.height, (i) => true);
      for (int i = 0; i < resized.width * resized.height; i++) {
        final p = resized.getPixelSafe(i % resized.width, i ~/ resized.width);
        mask[i] = p.a >= 128;
      }
    }

    final List<HSVColor> hsvPixels = [];
    final Map<int, int> colorCounts = {};
    int objectPixelCount = 0;

    int minX = resized.width, maxX = 0;
    int minY = resized.height, maxY = 0;

    for (int y = 0; y < resized.height; y++) {
      for (int x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        if (!mask[y * resized.width + x]) continue;

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

        hsvPixels.add(HSVColor.fromColor(Color.fromARGB(255, r, g, b)));
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
        verticalSymmetry: 0.5,
        horizontalSymmetry: 0.5,
        edgeDensity: 0.0,
      );
    }

    final sortedColors = colorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dominantColors = sortedColors.take(8).map((e) {
      final q = e.key;
      return Color.fromARGB(
        255,
        ((q >> 8) & 0xF) * 17,
        ((q >> 4) & 0xF) * 17,
        (q & 0xF) * 17,
      );
    }).toList();

    final finalHueBins = <String, double>{};
    for (int i = 0; i < 36; i++) {
      finalHueBins['h${i * 10}'] = 0;
    }
    // Add Achromatic bins
    finalHueBins['hWhite'] = 0;
    finalHueBins['hBlack'] = 0;
    finalHueBins['hGrey'] = 0;

    double totalBrightness = 0;
    double totalSaturation = 0;

    for (final hsv in hsvPixels) {
      totalBrightness += hsv.value;
      totalSaturation += hsv.saturation;

      if (hsv.value < 0.15) {
        finalHueBins['hBlack'] = (finalHueBins['hBlack'] ?? 0) + 1;
      } else if (hsv.saturation < 0.15) {
        if (hsv.value > 0.8) {
          finalHueBins['hWhite'] = (finalHueBins['hWhite'] ?? 0) + 1;
        } else {
          finalHueBins['hGrey'] = (finalHueBins['hGrey'] ?? 0) + 1;
        }
      } else {
        final binIndex = (hsv.hue / 10).floor().clamp(0, 35);
        finalHueBins['h${binIndex * 10}'] =
            (finalHueBins['h${binIndex * 10}'] ?? 0) + 1;
      }
    }

    final total = hsvPixels.length.toDouble();
    for (final key in finalHueBins.keys) {
      finalHueBins[key] = finalHueBins[key]! / total;
    }

    final sym = _calculateSymmetry(resized, mask, minX, maxX, minY, maxY);
    final hSym = sym.$1;
    final vSym = sym.$2;

    // Spatial analysis (3x3 grid for basic layout matching)
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
              final hsv = HSVColor.fromColor(
                Color.fromARGB(255, p.r.toInt(), p.g.toInt(), p.b.toInt()),
              );
              final bin = ((hsv.hue % 360) / 10).floor();
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

    // NEW: Vertical Bias calculation
    int topHalf = 0;
    int bottomHalf = 0;
    for (int y = 0; y < resized.height; y++) {
      for (int x = 0; x < resized.width; x++) {
        if (!mask[y * resized.width + x]) continue;
        if (y > resized.height * 0.6) bottomHalf++;
        if (y < resized.height * 0.4) topHalf++;
      }
    }
    final double vBias = (topHalf + bottomHalf) > 0
        ? bottomHalf / (topHalf + bottomHalf)
        : 0.5;

    // NEW: Top Heavy Bias
    int topPixels = 0;
    for (int y = 0; y < (resized.height * 0.4).toInt(); y++) {
      for (int x = 0; x < resized.width; x++) {
        if (mask[y * resized.width + x]) topPixels++;
      }
    }
    final double topHeavyBias = objectPixelCount > 0
        ? topPixels / objectPixelCount
        : 0.0;

    // NEW: Hue Complexity
    int significantBins = 0;
    finalHueBins.forEach((key, val) {
      if (val > 0.02) significantBins++;
    });
    final double hueComplexity = significantBins / 39.0;

    // NEW: Perimeter and Compactness
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
    final double compactness = objectPixelCount > 0
        ? (perimeter * perimeter) / objectPixelCount
        : 1.0;

    // NEW: Limb Density (Pixels in outer 20% of bounding box)
    int limbPixels = 0;
    final int insetX = ((maxX - minX + 1) * 0.2).toInt();
    final int insetY = ((maxY - minY + 1) * 0.2).toInt();
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= maxX; x++) {
        if (!mask[y * resized.width + x]) continue;
        if (x < minX + insetX ||
            x > maxX - insetX ||
            y < minY + insetY ||
            y > maxY - insetY) {
          limbPixels++;
        }
      }
    }
    final double limbDensity = objectPixelCount > 0
        ? limbPixels / objectPixelCount
        : 0.0;

    // NEW: Directional Edge Bias
    int hEdges = 0;
    int vEdges = 0;
    for (int y = 1; y < resized.height - 1; y++) {
      for (int x = 1; x < resized.width - 1; x++) {
        if (!mask[y * resized.width + x]) continue;
        final p = resized.getPixel(x, y);
        final pR = resized.getPixel(x + 1, y);
        final pD = resized.getPixel(x, y + 1);
        final lum = (p.r + p.g + p.b) / 3.0;
        final lumR = (pR.r + pR.g + pR.b) / 3.0;
        final lumD = (pD.r + pD.g + pD.b) / 3.0;
        if ((lum - lumR).abs() > 30) hEdges++;
        if ((lum - lumD).abs() > 30) vEdges++;
      }
    }
    final double edgeBias = (hEdges + vEdges) > 0
        ? (hEdges - vEdges) / (hEdges + vEdges).toDouble()
        : 0.0;

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
                (((pt.r ~/ 32) << 16) | ((pt.g ~/ 32) << 8) | (pt.b ~/ 32)))
              clusteredPixels++;
          } else if (mask[y * resized.width + x - 1]) {
            final pl = resized.getPixel(x - 1, y);
            if (qc ==
                (((pl.r ~/ 32) << 16) | ((pl.g ~/ 32) << 8) | (pl.b ~/ 32)))
              clusteredPixels++;
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

    return OrganismFeature(
      organismName: name,
      dominantColors: dominantColors,
      hueBins: finalHueBins,
      spatialHueBins: spatialHueBins,
      avgBrightness: totalBrightness / objectPixelCount,
      avgSaturation: totalSaturation / objectPixelCount,
      aspectRatio: (maxX - minX + 1) / (maxY - minY + 1),
      solidity: objectPixelCount / ((maxX - minX + 1) * (maxY - minY + 1)),
      verticalSymmetry: vSym,
      horizontalSymmetry: hSym,
      edgeDensity: _calculateEdgeDensity(resized, mask),
      verticalBias: vBias,
      topHeavyBias: topHeavyBias,
      hueComplexity: hueComplexity,
      compactness: compactness,
      limbDensity: limbDensity,
      directionalEdgeBias: edgeBias,
      coreSolidity: coreSolidity,
      bottomHeavyBias: bottomHeavyBias,
      maxWidthRowBias: maxWidthRowBias,
      maxHeightColBias: maxHeightColBias,
      bottomCenterDensity: bottomCenterDensity,
      cornerDensity: cornerDensity,
      diagonalDensity: diagonalDensity,
      lowerQuadrantSymmetry: lowerQuadrantSymmetry,
      horizontalCentroidShift: horizontalCentroidShift,
      convexHullRatio: convexHullRatio,
      verticalMassDistribution: verticalMassDistribution,
      colorGranularity: colorGranularity,
      fringeDensity: fringeDensity,
      verticalThinning: verticalThinning,
      localSymmetry: localSymmetry,
      colorClustering: colorClustering,
      yGradient: yGradient,
      widthVariance: widthVariance,
      shellIndex: shellIndex,
      radialOverlap: radialOverlap,
      yCentroid: yCentroid,
      jaggedness: jaggedness,
      topThirdDensity: topThirdDensity,
      bilateralSym: bilateralSym,
    );
  }

  /// Detect likely background by sampling corners and looking for uniform color.
  List<bool> _detectBackgroundAndGetMask(img.Image image) {
    final mask = List<bool>.filled(image.width * image.height, true);

    // Sample perimeter points for background "prototypes"
    final List<List<int>> prototypes = [];
    final samples = [
      [0, 0],
      [image.width - 1, 0],
      [0, image.height - 1],
      [image.width - 1, image.height - 1],
      [image.width ~/ 2, 0],
      [image.width ~/ 2, image.height - 1],
      [0, image.height ~/ 2],
      [image.width - 1, image.height ~/ 2],
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
                pow(b - bp[2], 2) * 0.114,
          );
          if (d < minStatsDist) minStatsDist = d;
        }

        // Distance from center (0.0 at center, 1.0 at farthest corner)
        final distFromCenter =
            sqrt(pow(x - centerX, 2) + pow(y - centerY, 2)) / maxDist;

        // Subject Protection & Edge Aggression:
        // We use a parabolic threshold curve.
        // Near center (dist < 0.45), threshold is extremely strict (protect subject).
        // Near edges (dist > 0.65), threshold is loose (remove background).
        double threshold;
        if (distFromCenter < 0.45) {
          threshold = 6.0; // Extremely strict protection
        } else if (distFromCenter < 0.65) {
          threshold = 6.0 + pow((distFromCenter - 0.45) * 5.0, 2) * 20.0;
        } else {
          threshold = 26.0 + pow((distFromCenter - 0.65) * 3.0, 2) * 120.0;
        }

        if (minStatsDist < threshold) {
          mask[y * image.width + x] = false;
        }
      }
    }
    return mask;
  }

  /// Calculate horizontal and vertical symmetry scores.
  (double, double) _calculateSymmetry(
    img.Image img,
    List<bool>? mask,
    int minX,
    int maxX,
    int minY,
    int maxY,
  ) {
    int hMatches = 0, vMatches = 0, hTotal = 0, vTotal = 0;

    // Horizontal Symmetry
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= (minX + maxX) ~/ 2; x++) {
        final x2 = maxX - (x - minX);
        if (x2 < minX || x2 > maxX) continue;

        final p1 = img.getPixel(x, y);
        final p2 = img.getPixel(x2, y);

        hTotal++;
        final d =
            (p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs();
        if (d < 100) hMatches++;
      }
    }

    // Vertical Symmetry
    for (int x = minX; x <= maxX; x++) {
      for (int y = minY; y <= (minY + maxY) ~/ 2; y++) {
        final y2 = maxY - (y - minY);
        if (y2 < minY || y2 > maxY) continue;

        final p1 = img.getPixel(x, y);
        final p2 = img.getPixel(x, y2);

        vTotal++;
        final d =
            (p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs();
        if (d < 100) vMatches++;
      }
    }

    return (
      hTotal > 0 ? hMatches / hTotal : 0.5,
      vTotal > 0 ? vMatches / vTotal : 0.5,
    );
  }

  /// Calculate edge density (frequency of high contrast transitions).
  double _calculateEdgeDensity(img.Image image, List<bool>? mask) {
    int edgePixels = 0;
    int totalPixels = 0;

    for (int y = 1; y < image.height - 1; y++) {
      for (int x = 1; x < image.width - 1; x++) {
        if (mask != null && !mask[y * image.width + x]) continue;

        final p = image.getPixel(x, y);
        final pRight = image.getPixel(x + 1, y);
        final pDown = image.getPixel(x, y + 1);

        final lum = (p.r + p.g + p.b) / 3.0;
        final lumR = (pRight.r + pRight.g + pRight.b) / 3.0;
        final lumD = (pDown.r + pDown.g + pDown.b) / 3.0;

        final grad = (lum - lumR).abs() + (lum - lumD).abs();
        if (grad > 30) edgePixels++;
        totalPixels++;
      }
    }
    return totalPixels > 0 ? edgePixels / totalPixels : 0.0;
  }

  /// Extract Genus from scientific name (e.g. "Panthera tigris" -> "Panthera").
  String _getGenus(String scientificName) {
    if (scientificName.isEmpty) return "";
    return scientificName.split(' ')[0];
  }

  /// Score how well an organism name/description matches the photo context.
  double _textRelevanceScore(Organism org, List<String> detectedKeywords) {
    if (detectedKeywords.isEmpty) return 0.5;

    final nameLower = org.name.toLowerCase();
    final sciLower = org.scientificName.toLowerCase();
    final descLower = org.description.toLowerCase();
    final habitatLower = org.habitat.toLowerCase();
    final combinedText = '$nameLower $sciLower $descLower $habitatLower';

    double score = 0;
    int matchCount = 0;

    for (final keyword in detectedKeywords) {
      final isShort = keyword.length <= 3;
      final pattern = isShort ? RegExp('\\b$keyword\\b') : RegExp(keyword);

      if (pattern.hasMatch(nameLower)) {
        score += 3.0;
        matchCount++;
      } else if (pattern.hasMatch(sciLower)) {
        score += 2.0;
        matchCount++;
      } else if (pattern.hasMatch(combinedText)) {
        score += 1.0;
        matchCount++;
      }
    }

    if (matchCount == 0) return 0.0;
    return min(1.0, score / (detectedKeywords.length * 3.0));
  }

  /// Main scan method: analyze an image and return top matches.
  Future<List<ScanResult>> scanImage(
    Uint8List imageBytes, {
    int maxResults = 10,
    String? hint,
    Uint8List? preSegmentedBytes,
    void Function(
      String status,
      double progress, {
      AnimalClass? predictedClass,
      String? predictedDiet,
      double? predictedWeight,
    })?
    onProgress,
  }) async {
    if (!_isInitialized) await initialize();
    if (_organisms == null || _organisms!.isEmpty) return [];

    // Step 1: Segmentation (Prioritize manual -> ML -> Fallback)
    onProgress?.call('Segmenting subject...', 0.05);
    Uint8List? activeSegmentedBytes = preSegmentedBytes;
    bool usedAdvancedSegmentation = preSegmentedBytes != null;

    if (preSegmentedBytes != null) {
      activeSegmentedBytes = preSegmentedBytes;
      usedAdvancedSegmentation = true;
    } else if (_segmentation.isAvailable) {
      onProgress?.call('AI segmentation in progress...', 0.10);
      try {
        activeSegmentedBytes = await _segmentation
            .segment(imageBytes)
            .timeout(const Duration(seconds: 5));
        if (activeSegmentedBytes != null) {
          usedAdvancedSegmentation = true;
          debugPrint('BiometricService: Using ML segmentation result');
        }
      } catch (e) {
        debugPrint('BiometricService: ML Segmentation failed or timed out: $e');
      }
    }

    // Step 2: Extract features using segmented image or fallback
    onProgress?.call(
      usedAdvancedSegmentation
          ? 'Analyzing biometric signatures...'
          : 'Extracting features...',
      0.15,
    );
    final inputFeature = await extractFeatures(
      imageBytes,
      name: 'input',
      preSegmentedBytes: activeSegmentedBytes,
    );

    // Step 3: Taxonomic Classification (AI Engine)
    onProgress?.call('AI Categorization...', 0.20);
    final taxonomyResult = await _taxonomy.classifyImage(
      imageBytes,
      preExtractedFeatures: inputFeature,
    );
    final double classConfidence =
        (taxonomyResult['confidence'] as num?)?.toDouble() ?? 0.0;
    final String classSource = taxonomyResult['source'] ?? 'none';

    // CRITICAL: Only trust the classification if confidence is high.
    // Low-confidence local classification (AI engine / heuristic) is unreliable
    // and causes the class/diet gates to destroy correct matches.
    // High confidence = iNaturalist (> 0.7) or very strong AI match.
    AnimalClass detectedClass;
    if (classConfidence > 0.7) {
      detectedClass = taxonomyResult['class'] ?? AnimalClass.unknown;
      debugPrint(
        'BiometricService: HIGH confidence ($classSource): ${detectedClass.name} @ ${(classConfidence * 100).toStringAsFixed(0)}%',
      );
    } else {
      detectedClass = AnimalClass.unknown;
      debugPrint(
        'BiometricService: LOW confidence ($classSource) — gates DISABLED',
      );
    }

    // Always show the classification hint in the UI (even if gates are disabled)
    final AnimalClass displayClass =
        taxonomyResult['class'] ?? AnimalClass.unknown;
    final String predictedDiet = taxonomyResult['diet'] ?? 'unknown';
    final double predictedWeight =
        (taxonomyResult['weight'] as num?)?.toDouble() ?? 0.0;

    onProgress?.call(
      displayClass != AnimalClass.unknown
          ? 'SUBJECT TYPE: ${displayClass.name.toUpperCase()}'
          : 'IDENTIFYING SUBJECT TYPE...',
      0.25,
      predictedClass: displayClass,
      predictedDiet: predictedDiet,
      predictedWeight: predictedWeight,
    );

    onProgress?.call('Decoding image...', 0.25);
    final img.Image? fullImg = img.decodeImage(imageBytes);
    if (fullImg == null) return [];

    // Step 4: Create masked image for UI display
    Uint8List maskedBytes;
    if (usedAdvancedSegmentation && activeSegmentedBytes != null) {
      // Use the provided/ML-segmented image directly
      maskedBytes = activeSegmentedBytes;
    } else {
      // Fallback: use old color-distance masking for display
      onProgress?.call('Applying basic segmentation...', 0.15);
      final mask = _detectBackgroundAndGetMask(fullImg);
      final maskedImg = img.Image.from(fullImg);
      for (int y = 0; y < maskedImg.height; y++) {
        for (int x = 0; x < maskedImg.width; x++) {
          if (!mask[y * maskedImg.width + x]) {
            maskedImg.setPixelRgba(x, y, 0, 0, 0, 0); // Transparent background
          }
        }
      }
      maskedBytes = Uint8List.fromList(img.encodePng(maskedImg));
    }

    // Normalize hint
    final normalizedHint = hint?.toLowerCase().trim();

    // Step 4: Detect potential category keywords from image colors
    onProgress?.call('Running pattern recognition...', 0.20);
    final detectedCategories = _detectCategoriesFromColors(inputFeature);

    // Step 5: Score all organisms
    final results = <ScanResult>[];
    final totalOrgs = _organisms!.length;
    int processed = 0;

    for (final org in _organisms!) {
      processed++;
      if (processed % 100 == 0) {
        onProgress?.call(
          'Matching biometric signatures...',
          0.20 + (0.60 * (processed / totalOrgs)),
        );
      }

      var cachedFeature = _spriteFeatures?[org.name];
      if (cachedFeature == null) {
        // Fallback: compute features on-the-fly from local sprite
        cachedFeature = await _extractSpriteFeature(org.name);
        if (cachedFeature != null) {
          _spriteFeatures?[org.name] = cachedFeature;
        }
      }
      if (cachedFeature == null) continue;

      final result = _featureSimilarity(
        inputFeature,
        cachedFeature,
        org,
        detectedClass: detectedClass,
        predictedDiet: predictedDiet,
        predictedWeight: predictedWeight,
      );

      // Hint-based filter
      if (normalizedHint != null && normalizedHint.isNotEmpty) {
        bool matchHint =
            org.name.toLowerCase().contains(normalizedHint) ||
            org.scientificName.toLowerCase().contains(normalizedHint) ||
            _getGenus(org.scientificName).toLowerCase() == normalizedHint;

        if (!matchHint) continue;
      }

      if (result.confidence > 0.15) {
        results.add(
          ScanResult(
            organism: org,
            confidence: result.confidence,
            matchReason: 'Biometric Signature Match',
            maskedImage: maskedBytes,
            featureScores: result.featureScores,
            detectedClass: displayClass,
            isPinpointed: result.isPinpointed,
            predictedDiet: predictedDiet,
            predictedWeight: predictedWeight,
          ),
        );
      }
    }

    onProgress?.call('Ranking results...', 0.90);
    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Genus-based inclusion
    if (results.isNotEmpty &&
        (results.first.confidence < 0.6 || results.first.confidence >= 0.95) &&
        normalizedHint == null) {
      final topGenus = _getGenus(results.first.organism.scientificName);
      if (topGenus.isNotEmpty) {
        for (final org in _organisms!) {
          if (_getGenus(org.scientificName) == topGenus &&
              !results.any((r) => r.organism.name == org.name)) {
            var cachedFeature = _spriteFeatures?[org.name];
            if (cachedFeature == null) {
              cachedFeature = await _extractSpriteFeature(org.name);
              if (cachedFeature != null) {
                _spriteFeatures?[org.name] = cachedFeature;
              }
            }

            if (cachedFeature != null) {
              final result = _featureSimilarity(
                inputFeature,
                cachedFeature,
                org,
                detectedClass: detectedClass,
              );
              if (result.confidence > 0.2) {
                results.add(
                  ScanResult(
                    organism: org,
                    confidence: result.confidence,
                    matchReason: 'Similar Genus ($topGenus)',
                    maskedImage: maskedBytes,
                    featureScores: result.featureScores,
                    isGenusMate: true,
                    isPinpointed: result.isPinpointed,
                    predictedDiet: predictedDiet,
                    predictedWeight: predictedWeight,
                  ),
                );
              }
            }
          }
        }
        results.sort((a, b) => b.confidence.compareTo(a.confidence));
      }
    }

    // Step 5: External identification (iNaturalist)
    if (normalizedHint == null &&
        (results.isEmpty || results.first.confidence < 0.90)) {
      onProgress?.call('Consulting Global Registry...', 0.92);
      try {
        final externalResults = await identifyViaINaturalist(imageBytes);
        for (final ext in externalResults) {
          final existingIndex = results.indexWhere(
            (r) =>
                r.organism.name.toLowerCase() ==
                ext.organism.name.toLowerCase(),
          );
          if (existingIndex == -1) {
            results.add(ext);
          }
        }
      } catch (_) {}
    }

    onProgress?.call('Scan complete!', 1.0);
    return results.take(maxResults).toList();
  }

  /// Calculates a logical similarity breakdown between two features.
  ScanResult _featureSimilarity(
    OrganismFeature f1,
    OrganismFeature f2,
    Organism target, {
    required AnimalClass detectedClass,
    String predictedDiet = 'unknown',
    double predictedWeight = 0.0,
  }) {
    // 1. ADVANCED COLOR MATCH (Smoothing for lighting tolerance)
    double globalColorMatch = 0;
    f1.hueBins.forEach((key, val) {
      if (val == 0) return;

      // Handle Achromatic Bins (White, Black, Grey)
      if (key == 'hWhite' || key == 'hBlack' || key == 'hGrey') {
        globalColorMatch += min(val, f2.hueBins[key] ?? 0);
        return;
      }

      int hue = int.tryParse(key.replaceAll('h', '')) ?? -1;
      if (hue == -1) return;

      double exact = f2.hueBins[key] ?? 0;
      int prevHue = (hue - 10) % 360;
      if (prevHue < 0) prevHue += 360;
      int nextHue = (hue + 10) % 360;
      double prevVal = f2.hueBins['h$prevHue'] ?? 0;
      double nextVal = f2.hueBins['h$nextHue'] ?? 0;

      double effectiveF2 = exact + (prevVal * 0.4) + (nextVal * 0.4);
      globalColorMatch += min(val, effectiveF2);
    });
    final colorScore = globalColorMatch.clamp(0.0, 1.0);

    // 2. SPATIAL COLOR MATCH (Pattern/Distribution)
    double spatialScore = colorScore;
    if (f1.spatialHueBins != null && f2.spatialHueBins != null) {
      double spatialSum = 0;
      int activeCells = 0;
      f1.spatialHueBins!.forEach((key, val) {
        if (f2.spatialHueBins!.containsKey(key)) {
          spatialSum += min(val, f2.spatialHueBins![key]!);
        }
        activeCells++;
      });
      if (activeCells > 0) {
        spatialScore = (spatialSum / activeCells).clamp(0.0, 1.0);
      }
    }

    // 3. SHAPE ANALYSIS
    final aspectDiff = (log(f1.aspectRatio) - log(f2.aspectRatio)).abs();
    final solidityDiff = (f1.solidity - f2.solidity).abs();
    final shapeScore =
        pow((1.0 - (aspectDiff * 0.6)).clamp(0.0, 1.0), 1.5).toDouble() * 0.6 +
        pow((1.0 - (solidityDiff * 1.6)).clamp(0.0, 1.0), 1.5).toDouble() * 0.4;

    // 4. PATTERN (Symmetry & Edge Density)
    final symDiff =
        (f1.verticalSymmetry - f2.verticalSymmetry).abs() +
        (f1.horizontalSymmetry - f2.horizontalSymmetry).abs();
    final edgeDiff = (f1.edgeDensity - f2.edgeDensity).abs();
    // Texture boost: if both are highly textured, pattern is VERY important
    double patternImportance = 0.7;
    if (f1.edgeDensity > 0.15 && f2.edgeDensity > 0.15) {
      patternImportance = 0.85;
    }

    final patternScore =
        (1.0 - (symDiff / 2.0)).clamp(0.0, 1.0) * (1.0 - patternImportance) +
        (1.0 - (edgeDiff * 4.0)).clamp(0.0, 1.0) * patternImportance;

    // 5. SHADE & SATURATION
    final shadeScore = (1.0 - (f1.avgBrightness - f2.avgBrightness).abs())
        .clamp(0.0, 1.0);
    final satScore = (1.0 - (f1.avgSaturation - f2.avgSaturation).abs()).clamp(
      0.0,
      1.0,
    );
    final finalShadeScore = (shadeScore * 0.7 + satScore * 0.3).clamp(0.0, 1.0);

    // --- BIOLOGICAL GATES ---

    // Weight Gate
    double weightScore = 1.0;
    if (target.weight > 0 && detectedClass != AnimalClass.unknown) {
      final range = _expectedWeightRange(detectedClass);
      if (target.weight < range.$1 * 0.1 || target.weight > range.$2 * 10) {
        weightScore = 0.1;
      } else if (target.weight < range.$1 || target.weight > range.$2) {
        final distRatio = target.weight < range.$1
            ? (range.$1 / target.weight)
            : (target.weight / range.$2);
        weightScore = (1.0 / sqrt(distRatio)).clamp(0.2, 0.9);
      }
    }

    // Diet Gate: Soft penalty — unreliable when detectedClass is wrong
    double dietScore = 1.0;
    if (target.diet.isNotEmpty &&
        target.diet != 'unknown' &&
        detectedClass != AnimalClass.unknown) {
      final plausibleDiets = _plausibleDietsForClass(detectedClass);
      if (plausibleDiets.isNotEmpty &&
          !plausibleDiets.contains(target.diet.toLowerCase())) {
        dietScore = 0.9; // VERY soft penalty — AI class may be wrong
      }
    }

    // Class Gate: Soft penalty since AI classification is approximate
    // The organism's ground-truth class vs the detected class
    double classScore = 1.0;
    if (target.animalClass.isNotEmpty &&
        target.animalClass != 'unknown' &&
        detectedClass != AnimalClass.unknown) {
      if (target.animalClass.toLowerCase() !=
          detectedClass.name.toLowerCase()) {
        // Soft penalty — AI classification is not fully reliable
        classScore = 0.8;
      } else {
        // Class MATCH — small boost for agreement
        classScore = 1.1;
      }
    }

    // Combine visual scores with weighted importance
    // We prioritize Shape and Pattern over global Color to fix "Fish Bias"
    double visualWeightColor = 0.3;
    double visualWeightSpatial = 0.1;
    double visualWeightShape = 0.3;
    double visualWeightPattern = 0.2;
    double visualWeightShade = 0.1;

    // Aquatic Sensitivity: Fish need more spatial/pattern detail because they look similar
    if (target.animalClass.toLowerCase() == 'fish') {
      visualWeightSpatial = 0.2;
      visualWeightPattern = 0.25;
      visualWeightColor = 0.25; // Reduce color reliance
    }

    final double visualConfidence =
        (colorScore * visualWeightColor +
                spatialScore * visualWeightSpatial +
                finalShadeScore * visualWeightShade +
                shapeScore * visualWeightShape +
                patternScore * visualWeightPattern)
            .clamp(0.0, 1.0);

    // Numerosity Correction: only for fish (they have 799 samples vs 385 mammals)
    double numerosityCorrection = 1.0;
    if (detectedClass == AnimalClass.unknown && visualConfidence < 0.90) {
      if (target.animalClass.toLowerCase() == 'fish') {
        numerosityCorrection = 0.85;
      }
    }

    // Apply biological gates and numerosity correction
    final double finalConfidence =
        (visualConfidence *
                weightScore *
                dietScore *
                classScore *
                numerosityCorrection)
            .clamp(0.0, 1.0);

    // PINPOINT THRESHOLD (90%)
    final bool pinpointed = finalConfidence > 0.90;

    return ScanResult(
      organism: target,
      confidence: finalConfidence,
      matchReason: pinpointed
          ? 'PINPOINTED BIOMETRIC MATCH'
          : 'Biometric Analysis',
      featureScores: {
        'Color': colorScore,
        'Pattern': patternScore,
        'Shade': finalShadeScore,
        'Shape': shapeScore,
        'Weight': weightScore,
        'Diet': dietScore,
        'Class': classScore,
      },
      detectedClass: detectedClass,
      isPinpointed: pinpointed,
      predictedDiet: predictedDiet,
      predictedWeight: predictedWeight,
    );
  }

  /// Query the iNaturalist Computer Vision API for species identification.
  Future<List<ScanResult>> identifyViaINaturalist(Uint8List imageBytes) async {
    final url = Uri.parse(
      'https://api.inaturalist.org/v1/computervision/score',
    );

    // Pre-process: Composite onto white background to avoid transparent->black conversion hallucination
    Uint8List uploadBytes = imageBytes;
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        final whiteBg = img.Image(width: decoded.width, height: decoded.height);
        img.fill(whiteBg, color: img.ColorRgba8(255, 255, 255, 255));
        img.compositeImage(whiteBg, decoded);
        uploadBytes = img.encodeJpg(whiteBg, quality: 90);
      }
    } catch (_) {}

    final request = http.MultipartRequest('POST', url);
    request.files.add(
      http.MultipartFile.fromBytes('image', uploadBytes, filename: 'image.jpg'),
    );

    final response = await request.send().timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];

    final responseBody = await response.stream.bytesToString();
    final data = json.decode(responseBody);
    final results = data['results'] as List?;
    if (results == null) return [];

    final scanResults = <ScanResult>[];
    for (final res in results.take(5)) {
      final taxon = res['taxon'];
      if (taxon == null) continue;

      final name = taxon['preferred_common_name'] ?? taxon['name'];
      final scientificName = taxon['name'];
      final score = (res['vision_score'] as num).toDouble();
      final photoUrl = taxon['default_photo']?['medium_url'];

      // Find if we have a local match
      final localMatch = _organisms?.firstWhere(
        (o) =>
            o.name.toLowerCase() == name.toString().toLowerCase() ||
            o.scientificName.toLowerCase() ==
                scientificName.toString().toLowerCase(),
        orElse: () => _createExternalOrganism(taxon),
      );

      if (localMatch != null) {
        scanResults.add(
          ScanResult(
            organism: localMatch,
            confidence: score,
            matchReason: 'Global Registry Match',
            isExternal: localMatch.sprite.startsWith('http'),
          ),
        );
      }
    }
    return scanResults;
  }

  /// Extract features from a local sprite asset.
  Future<OrganismFeature?> _extractSpriteFeature(String organismName) async {
    try {
      final path = spritePathForName(organismName);
      final data = await rootBundle.load(path);
      return extractFeatures(data.buffer.asUint8List(), name: organismName);
    } catch (_) {
      return null;
    }
  }

  /// Create a synthetic Organism object from iNaturalist taxon data.
  Organism _createExternalOrganism(Map<String, dynamic> taxon) {
    final name = taxon['preferred_common_name'] ?? taxon['name'];
    final sciName = taxon['name'];
    final photoUrl = taxon['default_photo']?['medium_url'] ?? '';
    final wikiUrl = taxon['wikipedia_url'] ?? '';

    // Inferred types based on iconic_taxon_name
    final iconicTaxon = taxon['iconic_taxon_name']?.toString().toLowerCase();
    final types = <String>[];
    if (iconicTaxon == 'mammalia') {
      types.add('basic');
    } else if (iconicTaxon == 'aves')
      types.add('flying');
    else if (iconicTaxon == 'reptilia')
      types.add('earth');
    else if (iconicTaxon == 'amphibia')
      types.add('aquatic');
    else if (iconicTaxon == 'actinopterygii')
      types.add('aquatic');
    else if (iconicTaxon == 'insecta')
      types.add('arthropod');
    else if (iconicTaxon == 'arachnida')
      types.add('arthropod');
    else
      types.add('basic');

    return Organism(
      name: name,
      scientificName: sciName,
      habitat: 'Global Registry',
      drops: 'Unknown',
      attack: 50,
      defense: 50,
      power: 50,
      resistance: 50,
      health: 100,
      speed: 50,
      abilities: 'Unknown',
      category: iconicTaxon ?? 'Unknown',
      moves: 'Unknown',
      sprite: photoUrl, // Using remote URL
      rarity: 'Common',
      description:
          'Extracted from Global Registry data. Source: iNaturalist. $wikiUrl',
      types: types,
    );
  }

  /// Detect broad category keywords from image color characteristics.
  List<String> _detectCategoriesFromColors(OrganismFeature feature) {
    final keywords = <String>[];

    // Analyze dominant hues to infer environment/category
    final greenHue =
        (feature.hueBins['h90'] ?? 0) + (feature.hueBins['h120'] ?? 0);
    final blueHue =
        (feature.hueBins['h180'] ?? 0) +
        (feature.hueBins['h210'] ?? 0) +
        (feature.hueBins['h240'] ?? 0);
    final warmHue =
        (feature.hueBins['h0'] ?? 0) +
        (feature.hueBins['h30'] ?? 0) +
        (feature.hueBins['h330'] ?? 0);
    final yellowHue = (feature.hueBins['h60'] ?? 0);

    // High green → likely terrestrial
    if (greenHue > 0.3) {
      keywords.addAll(['green', 'forest', 'nature', 'terrestrial']);
    }
    // High blue → aquatic
    if (blueHue > 0.3) {
      keywords.addAll(['blue', 'water', 'marine', 'ocean', 'aquatic']);
    }
    // Warm tones → earth, dry environment
    if (warmHue > 0.3) {
      keywords.addAll(['brown', 'earth', 'warm', 'mammal', 'dry']);
    }
    // Yellow → bright, savanna
    if (yellowHue > 0.15) {
      keywords.addAll(['yellow', 'bright', 'savanna', 'sand']);
    }
    // Dark/low brightness → nocturnal
    if (feature.avgBrightness < 0.3) {
      keywords.addAll(['dark', 'nocturnal', 'shadow']);
    }
    // Very bright/saturated → tropical
    if (feature.avgSaturation > 0.7 && feature.avgBrightness > 0.6) {
      keywords.addAll(['tropical', 'vibrant', 'colorful']);
    }

    return keywords;
  }

  /// Pre-compute sprite features for ALL organisms (batch operation).
  /// For CLI generation, use: dart run scratch/generate_features_db.dart
  /// This in-app method is kept for compatibility.
  Future<Map<String, dynamic>> preComputeAllSpriteFeatures({
    void Function(int current, int total)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();

    final features = <String, dynamic>{};
    final total = _organisms?.length ?? 0;

    for (int i = 0; i < total; i++) {
      final org = _organisms![i];
      onProgress?.call(i + 1, total);

      final feature = await _extractSpriteFeature(org.name);
      if (feature != null) {
        features[org.name] = feature.toJson();
        _spriteFeatures?[org.name] = feature;
      }

      if (i % 50 == 0) {
        await Future.delayed(Duration.zero); // Yield
      }
    }

    return features;
  }

  /// Expected weight range (kg) for each animal class.
  /// Used as a biological plausibility filter during scanning.
  (double, double) _expectedWeightRange(AnimalClass cls) {
    switch (cls) {
      case AnimalClass.insect:
        return (0.0001, 0.5);
      case AnimalClass.amphibian:
        return (0.001, 10.0);
      case AnimalClass.fish:
        return (0.001, 1000.0);
      case AnimalClass.bird:
        return (0.002, 150.0);
      case AnimalClass.reptile:
        return (0.001, 1500.0);
      case AnimalClass.mammal:
        return (0.002, 6000.0);
      case AnimalClass.arachnid:
        return (0.0001, 0.2);
      case AnimalClass.crustacean:
        return (0.001, 20.0);
      case AnimalClass.mollusk:
        return (0.0001, 500.0);
      case AnimalClass.annelid:
        return (0.0001, 5.0);
      case AnimalClass.cnidarian:
        return (0.0001, 200.0);
      case AnimalClass.echinoderm:
        return (0.001, 10.0);
      case AnimalClass.otherInvertebrate:
        return (0.0001, 100.0);
      case AnimalClass.unknown:
        return (0.0001, 10000.0);
    }
  }

  /// Biologically plausible diets for each animal class.
  /// Empty set means all diets are plausible.
  Set<String> _plausibleDietsForClass(AnimalClass cls) {
    switch (cls) {
      case AnimalClass.insect:
        return {
          'herbivore',
          'omnivore',
          'carnivore',
          'detritivore',
          'nectarivore',
        };
      case AnimalClass.amphibian:
        return {'carnivore', 'insectivore', 'omnivore'};
      case AnimalClass.fish:
        return {
          'carnivore',
          'omnivore',
          'herbivore',
          'planktivore',
          'filter feeder',
        };
      case AnimalClass.bird:
        return {
          'carnivore',
          'omnivore',
          'herbivore',
          'insectivore',
          'granivore',
          'nectarivore',
          'piscivore',
          'scavenger',
        };
      case AnimalClass.reptile:
        return {'carnivore', 'omnivore', 'herbivore', 'insectivore'};
      case AnimalClass.mammal:
        return {}; // Mammals have all possible diets
      case AnimalClass.arachnid:
        return {'carnivore', 'insectivore'};
      case AnimalClass.crustacean:
        return {'omnivore', 'detritivore', 'carnivore', 'scavenger'};
      case AnimalClass.mollusk:
        return {'herbivore', 'omnivore', 'carnivore', 'filter feeder'};
      case AnimalClass.annelid:
        return {'detritivore', 'omnivore', 'herbivore'};
      case AnimalClass.cnidarian:
        return {'carnivore', 'planktivore'};
      case AnimalClass.echinoderm:
        return {'omnivore', 'detritivore', 'herbivore', 'carnivore'};
      case AnimalClass.otherInvertebrate:
        return {
          'herbivore',
          'omnivore',
          'carnivore',
          'detritivore',
          'filter feeder',
          'parasite',
        };
      case AnimalClass.unknown:
        return {}; // Unknown = all diets plausible
    }
  }
}
