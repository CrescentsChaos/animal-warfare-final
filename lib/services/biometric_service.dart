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

  ScanResult({
    required this.organism,
    required this.confidence,
    required this.matchReason,
    this.isExternal = false,
    this.maskedImage,
    this.featureScores = const {},
    this.isGenusMate = false,
    this.detectedClass = AnimalClass.unknown,
  });
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
      };

  factory OrganismFeature.fromJson(Map<String, dynamic> json) {
    return OrganismFeature(
      organismName: json['organismName'] ?? 'Unknown',
      dominantColors: (json['dominantColors'] as List?)
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
      horizontalSymmetry: (json['horizontalSymmetry'] as num?)?.toDouble() ?? 0.5,
      edgeDensity: (json['edgeDensity'] as num?)?.toDouble() ?? 0.0,
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
      final String response = await rootBundle.loadString('assets/Organisms.json');
      final List<dynamic> animalsData = json.decode(response);
      _organisms = animalsData.map((j) => Organism.fromJson(j)).toList();

      // Load pre-computed sprite features from SQLite DB
      try {
        await _featureDb.initialize();
        _spriteFeatures = await _featureDb.getAllFeatures();
        debugPrint('BiometricService: Loaded ${_spriteFeatures?.length ?? 0} features from DB');
      } catch (e) {
        debugPrint('BiometricService: DB load failed, trying JSON fallback: $e');
        // Fallback: try loading from legacy JSON file
        try {
          final String featuresJson = await rootBundle.loadString('assets/ml/sprite_features.json');
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
        debugPrint('BiometricService: ML segmentation ready: ${_segmentation.isAvailable}');
      });

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
  Future<OrganismFeature> extractFeatures(Uint8List imageBytes, {String name = 'input', Uint8List? preSegmentedBytes}) async {
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

    // Resize for performance
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
        if (x < minX) minX = x; if (x > maxX) maxX = x;
        if (y < minY) minY = y; if (y > maxY) maxY = y;

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
        organismName: name, dominantColors: [], hueBins: {}, avgBrightness: 0.5, avgSaturation: 0.5,
        aspectRatio: 1.0, solidity: 0.5, verticalSymmetry: 0.5, horizontalSymmetry: 0.5, edgeDensity: 0.0,
      );
    }

    final sortedColors = colorCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final dominantColors = sortedColors.take(8).map((e) {
      final q = e.key;
      return Color.fromARGB(255, ((q >> 8) & 0xF) * 17, ((q >> 4) & 0xF) * 17, (q & 0xF) * 17);
    }).toList();

    final finalHueBins = <String, double>{};
    for (int i = 0; i < 36; i++) finalHueBins['h${i * 10}'] = 0;
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
        finalHueBins['h${binIndex * 10}'] = (finalHueBins['h${binIndex * 10}'] ?? 0) + 1;
      }
    }

    final total = hsvPixels.length.toDouble();
    for (final key in finalHueBins.keys) finalHueBins[key] = finalHueBins[key]! / total;

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
              final hsv = HSVColor.fromColor(Color.fromARGB(255, p.r.toInt(), p.g.toInt(), p.b.toInt()));
              final bin = ((hsv.hue % 360) / 10).floor();
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
    );
  }

  /// Detect likely background by sampling corners and looking for uniform color.
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
        // Near edges (dist > 0.7), threshold is loose (remove background).
        double threshold;
        if (distFromCenter < 0.4) {
          threshold = 8.0; // Very strict: only mask if ALMOST EXACTLY background color
        } else {
          // Exponentially increase threshold as we move away from center
          threshold = 8.0 + pow(distFromCenter * 1.5, 3) * 60.0;
        }

        if (minStatsDist < threshold) {
          mask[y * image.width + x] = false;
        }
      }
    }
    return mask;
  }

  /// Calculate horizontal and vertical symmetry scores.
  (double, double) _calculateSymmetry(img.Image img, List<bool>? mask, int minX, int maxX, int minY, int maxY) {
    int hMatches = 0, vMatches = 0, hTotal = 0, vTotal = 0;
    
    // Horizontal Symmetry
    for (int y = minY; y <= maxY; y++) {
      for (int x = minX; x <= (minX + maxX) ~/ 2; x++) {
        final x2 = maxX - (x - minX);
        if (x2 < minX || x2 > maxX) continue;
        
        final p1 = img.getPixel(x, y);
        final p2 = img.getPixel(x2, y);
        
        hTotal++;
        final d = (p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs();
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
        final d = (p1.r - p2.r).abs() + (p1.g - p2.g).abs() + (p1.b - p2.b).abs();
        if (d < 100) vMatches++;
      }
    }
    
    return (
      hTotal > 0 ? hMatches / hTotal : 0.5,
      vTotal > 0 ? vMatches / vTotal : 0.5
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
    void Function(String status, double progress)? onProgress,
  }) async {
    if (!_isInitialized) await initialize();
    if (_organisms == null || _organisms!.isEmpty) return [];

    // 0. Taxonomic Classification (Early Gate)
    onProgress?.call('Categorizing Subject...', 0.02);
    final taxonomyResult = await _taxonomy.classifyImage(imageBytes);
    final AnimalClass detectedClass = taxonomyResult['class'] ?? AnimalClass.unknown;
    final double classConfidence = taxonomyResult['confidence'] ?? 0.0;
    
    if (detectedClass != AnimalClass.unknown) {
      onProgress?.call('Subject Type: ${detectedClass.name.toUpperCase()}', 0.05);
    }

    onProgress?.call('Decoding image...', 0.05);
    final img.Image? fullImg = img.decodeImage(imageBytes);
    if (fullImg == null) return [];

    // Step 1: Segmentation (Prioritize manual -> ML -> Fallback)
    Uint8List? activeSegmentedBytes = preSegmentedBytes;
    bool usedAdvancedSegmentation = preSegmentedBytes != null;
    
    if (activeSegmentedBytes == null && _segmentation.isAvailable) {
      onProgress?.call('AI segmentation in progress...', 0.10);
      activeSegmentedBytes = await _segmentation.segment(imageBytes);
      if (activeSegmentedBytes != null) {
        usedAdvancedSegmentation = true;
        debugPrint('BiometricService: Using ML segmentation result');
      }
    }

    // Step 2: Extract features using segmented image or fallback
    onProgress?.call(usedAdvancedSegmentation ? 'Analyzing segmented subject...' : 'Segmenting subject...', 0.15);
    final inputFeature = await extractFeatures(
      imageBytes,
      name: 'input',
      preSegmentedBytes: activeSegmentedBytes,
    );

    // Step 3: Create masked image for UI display
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
        onProgress?.call('Matching biometric signatures...', 0.20 + (0.60 * (processed / totalOrgs)));
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

      final targetClass = _mapStringToAnimalClass(org.animalClass);
      final similarity = _featureSimilarity(
        inputFeature, 
        cachedFeature,
        inputClass: detectedClass,
        targetClass: targetClass,
        classConfidence: classConfidence,
      );
      
      // Strict Feature Filter: "Grey" threshold is 0.4
      // If any core feature (Color, Shape, Pattern, Shade) is ≤ 0.4, discard the species.
      bool hasGreyFeature = (similarity['Color'] ?? 0) <= 0.4 ||
                            (similarity['Shape'] ?? 0) <= 0.4 ||
                            (similarity['Pattern'] ?? 0) <= 0.4 ||
                            (similarity['Shade'] ?? 0) <= 0.4;
      
      if (hasGreyFeature) {
        continue;
      }

      double biometricScore = similarity['total'] ?? 0;
      double textScore = _textRelevanceScore(org, detectedCategories);

      // Final score formula: heavily weight biometrics
      double score = (biometricScore * 0.95) + (textScore * 0.05);

      // Hint-based filter
      if (normalizedHint != null && normalizedHint.isNotEmpty) {
        bool matchHint = org.name.toLowerCase().contains(normalizedHint) || 
                         org.scientificName.toLowerCase().contains(normalizedHint) ||
                         _getGenus(org.scientificName).toLowerCase() == normalizedHint;
        
        if (matchHint) {
          // It matches the hint, so we keep it. 
          // We don't boost it much because we want the percentage to reflect visual reality.
          score = (score + 0.01).clamp(0.0, 1.0);
        } else {
          // Exclude non-matching results
          continue; 
        }
      }

      if (score > 0.15) {
        results.add(ScanResult(
        organism: org,
        confidence: score,
        matchReason: 'Biometric Signature Match',
        maskedImage: maskedBytes,
        featureScores: similarity,
        detectedClass: detectedClass,
      ));
      }
    }

    onProgress?.call('Ranking results...', 0.90);
    results.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Genus-based inclusion (Fallback for low match OR Cluster for high match)
    if (results.isNotEmpty && (results.first.confidence < 0.6 || results.first.confidence >= 0.95) && normalizedHint == null) {
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
              final similarity = _featureSimilarity(inputFeature, cachedFeature);
              bool hasGreyFeature = (similarity['Color'] ?? 0) <= 0.5 ||
                                    (similarity['Shape'] ?? 0) <= 0.5 ||
                                    (similarity['Pattern'] ?? 0) <= 0.5 ||
                                    (similarity['Shade'] ?? 0) <= 0.5;
              
              if (!hasGreyFeature) {
                results.add(ScanResult(
                  organism: org,
                  confidence: similarity['total'] ?? 0,
                  matchReason: 'Similar Genus ($topGenus)',
                  maskedImage: maskedBytes,
                  featureScores: similarity,
                  isGenusMate: true,
                ));
              }
            }
          }
        }
        results.sort((a, b) => b.confidence.compareTo(a.confidence));
      }
    }

    // Step 5: External identification (iNaturalist) - Skip if hint is present to focus on user request
    if (normalizedHint == null && (results.isEmpty || results.first.confidence < 0.90)) {
      onProgress?.call('Consulting Global Registry...', 0.92);
      try {
        final externalResults = await identifyViaINaturalist(imageBytes);
        for (final ext in externalResults) {
          // Cross-verify external result with our own biometrics
          var cachedFeature = _spriteFeatures?[ext.organism.name];
          if (cachedFeature == null) {
            cachedFeature = await _extractSpriteFeature(ext.organism.name);
            if (cachedFeature != null) {
              _spriteFeatures?[ext.organism.name] = cachedFeature;
            }
          }
          // Default to 0.5 for unverified external results to prioritize local matches
          double biometricVerification = 0.5;
          Map<String, double> verificationScores = {};
          
          if (cachedFeature != null) {
            final sim = _featureSimilarity(inputFeature, cachedFeature);
            biometricVerification = sim['total'] ?? 0;
            verificationScores = sim;
            
            // If iNaturalist is highly confident (>80%), our local masking might have just failed
            // due to a complex background (like coral reefs). We boost the verification score
            // to ensure true positives aren't discarded by strict local biometric matching.
            if (ext.confidence > 0.8 && biometricVerification > 0.05) {
              biometricVerification = (biometricVerification * 2.0).clamp(0.6, 1.0);
            }
          }

          final existingIndex = results.indexWhere((r) => r.organism.name.toLowerCase() == ext.organism.name.toLowerCase());
          if (existingIndex != -1) {
            final existing = results[existingIndex];
            results[existingIndex] = ScanResult(
              organism: existing.organism,
              confidence: (existing.confidence * 0.7 + ext.confidence * 0.3).clamp(0.0, 1.0),
              matchReason: '${existing.matchReason} + External Verify',
              isExternal: false,
              maskedImage: maskedBytes,
              featureScores: existing.featureScores,
            );
          } else {
            // Only add external results that aren't a total biometric mismatch
            if (biometricVerification > 0.1 || ext.confidence > 0.8) {
              results.add(ScanResult(
                organism: ext.organism,
                // Combine external confidence with our boosted biometric verification
                confidence: (ext.confidence * biometricVerification).clamp(0.0, 1.0),
                matchReason: ext.matchReason,
                isExternal: true,
                maskedImage: maskedBytes,
                featureScores: verificationScores,
              ));
            }
          }
        }
      } catch (_) {}
    }

    // Step 6: Genus Affinity Grouping
    // If we have a very high confidence match (> 95%), group other species in the same genus
    if (results.isNotEmpty && results.first.confidence >= 0.95) {
      final topResult = results.first;
      final topGenus = _getGenus(topResult.organism.scientificName);
      
      for (int i = 1; i < results.length; i++) {
        final r = results[i];
        if (_getGenus(r.organism.scientificName) == topGenus) {
          // Mark as a genus-mate for UI grouping, but DO NOT boost the score
          results[i] = ScanResult(
            organism: r.organism,
            confidence: r.confidence, 
            matchReason: '${r.matchReason} (Genus Affiliate)',
            isExternal: r.isExternal,
            maskedImage: r.maskedImage,
            featureScores: r.featureScores,
            isGenusMate: true, // Flag for grouping
          );
        }
      }
    }

    onProgress?.call('Scan complete!', 1.0);
    return results.take(maxResults).toList();
  }

  /// Calculates a logical similarity breakdown between two features.
  Map<String, double> _featureSimilarity(
    OrganismFeature f1, 
    OrganismFeature f2, {
    AnimalClass? inputClass,
    AnimalClass? targetClass,
    double classConfidence = 0.0,
  }) {
    // 1. Global Color Match (with adjacent bin smoothing for lighting tolerance)
    double globalColorMatch = 0;
    f1.hueBins.forEach((key, val) {
      if (val == 0) return;
      int hue = int.tryParse(key.replaceAll('h', '')) ?? -1;
      if (hue == -1) return;

      // Check current bin and neighbors for fuzzy matching
      double exact = f2.hueBins[key] ?? 0;
      int prevHue = (hue - 10) % 360;
      if (prevHue < 0) prevHue += 360;
      int nextHue = (hue + 10) % 360;
      double prevVal = f2.hueBins['h$prevHue'] ?? 0;
      double nextVal = f2.hueBins['h$nextHue'] ?? 0;

      // Effective target mass for this hue
      double effectiveF2 = exact + (prevVal * 0.5) + (nextVal * 0.5);
      globalColorMatch += min(val, effectiveF2);
    });
    globalColorMatch = globalColorMatch.clamp(0.0, 1.0);

    // 2. Spatial Color Match (Grid-based verification)
    double spatialMatch = globalColorMatch; 
    if (f1.spatialHueBins != null && f2.spatialHueBins != null) {
      double spatialSum = 0;
      f1.spatialHueBins!.forEach((key, val) {
        if (f2.spatialHueBins!.containsKey(key)) {
          spatialSum += min(val, f2.spatialHueBins![key]!);
        }
      });
      
      // Count active grid cells (e.g. "g00", "g11")
      final cells1 = f1.spatialHueBins!.keys.map((k) => k.substring(0, 3)).toSet().length;
      final cells2 = f2.spatialHueBins!.keys.map((k) => k.substring(0, 3)).toSet().length;
      final maxCells = max(cells1, cells2);
      
      if (maxCells > 0) {
        spatialMatch = (spatialSum / maxCells).clamp(0.0, 1.0);
      }
    }
    
    // Weighted color score
    final colorMatch = (globalColorMatch * 0.5 + spatialMatch * 0.5).clamp(0.0, 1.0);

    // 3. Shape Analysis (Aspect Ratio & Solidity)
    final aspectDiff = (log(f1.aspectRatio) - log(f2.aspectRatio)).abs();
    final solidityDiff = (f1.solidity - f2.solidity).abs();
    
    // Parabolic penalty for shape mismatch
    final aspectScore = pow((1.0 - (aspectDiff * 0.6)).clamp(0.0, 1.0), 1.5).toDouble();
    final solidityScore = pow((1.0 - (solidityDiff * 1.6)).clamp(0.0, 1.0), 1.5).toDouble();
    final shapeMatch = (aspectScore * 0.6) + (solidityScore * 0.4);

    // 4. Pattern Analysis (Symmetry & Edge Density)
    final symDiff = (f1.verticalSymmetry - f2.verticalSymmetry).abs() +
                    (f1.horizontalSymmetry - f2.horizontalSymmetry).abs();
    final edgeDiff = (f1.edgeDensity - f2.edgeDensity).abs();
    final edgeScore = (1.0 - (edgeDiff * 3.0)).clamp(0.0, 1.0);
    final patternMatch = (1.0 - (symDiff / 2.0)).clamp(0.0, 1.0) * 0.3 + (edgeScore * 0.7);

    // 5. Shade & Saturation Match
    final shadeMatch = (1.0 - (f1.avgBrightness - f2.avgBrightness).abs()).clamp(0.0, 1.0);
    final satMatch = (1.0 - (f1.avgSaturation - f2.avgSaturation).abs()).clamp(0.0, 1.0);
    final combinedShade = (shadeMatch * 0.7 + satMatch * 0.3).clamp(0.0, 1.0);

    // 6. Aggregate Score Calculation
    double total = (colorMatch * 0.45) + 
                  (combinedShade * 0.35) + 
                  (shapeMatch * 0.15) + 
                  (patternMatch * 0.05);
    
    // Biometric Gating: Strict filter for impossible matches
    if (colorMatch < 0.12) total *= 0.20; // Color mismatch is fatal
    
    // Taxonomic Gating: Penalty for biological class mismatch
    if (inputClass != null && targetClass != null && 
        inputClass != AnimalClass.unknown && targetClass != AnimalClass.unknown) {
      if (inputClass != targetClass) {
        // Massive penalty if classes are different and we are confident
        final penalty = 0.1 + (0.4 * (1.0 - classConfidence)); 
        total *= penalty.clamp(0.1, 0.8);
      } else {
        // Boost if classes match and we are confident
        total *= (1.0 + (0.15 * classConfidence));
      }
    }

    if (total > 0.95) total = 1.0;
    if (total < 0.15) total = 0.0;

    return {
      'total': total,
      'Color': colorMatch,
      'Shape': shapeMatch,
      'Pattern': patternMatch,
      'Shade': combinedShade,
    };
  }

  /// Query the iNaturalist Computer Vision API for species identification.
  Future<List<ScanResult>> identifyViaINaturalist(Uint8List imageBytes) async {
    final url = Uri.parse('https://api.inaturalist.org/v1/computervision/score');
    
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
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      uploadBytes,
      filename: 'image.jpg',
    ));

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
        (o) => o.name.toLowerCase() == name.toString().toLowerCase() ||
               o.scientificName.toLowerCase() == scientificName.toString().toLowerCase(),
        orElse: () => _createExternalOrganism(taxon),
      );

      if (localMatch != null) {
        scanResults.add(ScanResult(
          organism: localMatch,
          confidence: score,
          matchReason: 'Global Registry Match',
          isExternal: localMatch.sprite.startsWith('http'),
        ));
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
    if (iconicTaxon == 'mammalia') types.add('basic');
    else if (iconicTaxon == 'aves') types.add('flying');
    else if (iconicTaxon == 'reptilia') types.add('earth');
    else if (iconicTaxon == 'amphibia') types.add('aquatic');
    else if (iconicTaxon == 'actinopterygii') types.add('aquatic');
    else if (iconicTaxon == 'insecta') types.add('arthropod');
    else if (iconicTaxon == 'arachnida') types.add('arthropod');
    else types.add('basic');

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
      description: 'Extracted from Global Registry data. Source: iNaturalist. $wikiUrl',
      types: types,
    );
  }

  /// Detect broad category keywords from image color characteristics.
  List<String> _detectCategoriesFromColors(OrganismFeature feature) {
    final keywords = <String>[];

    // Analyze dominant hues to infer environment/category
    final greenHue = (feature.hueBins['h90'] ?? 0) + (feature.hueBins['h120'] ?? 0);
    final blueHue = (feature.hueBins['h180'] ?? 0) + (feature.hueBins['h210'] ?? 0) + (feature.hueBins['h240'] ?? 0);
    final warmHue = (feature.hueBins['h0'] ?? 0) + (feature.hueBins['h30'] ?? 0) + (feature.hueBins['h330'] ?? 0);
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

  AnimalClass _mapStringToAnimalClass(String? s) {
    switch (s?.toLowerCase()) {
      case 'mammal': return AnimalClass.mammal;
      case 'bird': return AnimalClass.bird;
      case 'fish': return AnimalClass.fish;
      case 'amphibian': return AnimalClass.amphibian;
      case 'reptile': return AnimalClass.reptile;
      case 'insect': return AnimalClass.insect;
      case 'invertebrate': return AnimalClass.invertebrate;
      default: return AnimalClass.unknown;
    }
  }
}
