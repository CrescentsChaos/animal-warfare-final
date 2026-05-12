import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/services/taxonomy_engine.dart';
import 'package:animal_warfare/services/biometric_service.dart';

class TaxonomyService {
  static final TaxonomyService _instance = TaxonomyService._internal();
  factory TaxonomyService() => _instance;
  TaxonomyService._internal();

  final TaxonomyEngine _engine = TaxonomyEngine();
  bool _isInitialized = false;

  /// Initializes the taxonomic engine.
  Future<void> initialize() async {
    if (!_isInitialized) {
      await _engine.initialize();
      _isInitialized = true;
    }
  }

  /// Classifies an image into a biological category.
  /// Uses a multi-stage pipeline:
  ///   1. iNaturalist API (if online, high confidence only)
  ///   2. AI Engine (Gaussian Naive Bayes trained on sprites)
  ///   3. Heuristic fallback (shape + color rules)
  ///
  /// The AI engine provides a "soft" classification hint that feeds
  /// into the biometric matching pipeline. The actual class gating in
  /// BiometricService uses the organism's ground-truth animalClass field.
  Future<Map<String, dynamic>> classifyImage(
    Uint8List imageBytes, {
    OrganismFeature? preExtractedFeatures,
  }) async {
    await initialize();

    // 1. Try iNaturalist (if online) — highest authority
    try {
      final iNatResult = await _queryINaturalist(imageBytes);
      if (iNatResult != null && (iNatResult['confidence'] ?? 0) > 0.8) {
        return iNatResult;
      }
    } catch (e) {
      // Offline or error — continue to local classification
    }

    // 2. AI Engine (trained on sprite features)
    AnimalClass aiClass = AnimalClass.unknown;
    double aiConfidence = 0.0;

    if (preExtractedFeatures != null) {
      final aiResult = _engine.classify(preExtractedFeatures);
      aiClass = aiResult['class'] ?? AnimalClass.unknown;
      aiConfidence = (aiResult['confidence'] as num?)?.toDouble() ?? 0.0;
    }

    // 3. Heuristic fallback (always computed as a second opinion)
    final heuristicClass = _heuristicClassification(imageBytes);

    // Decision logic: trust AI if confident, otherwise heuristic
    AnimalClass finalClass;
    double finalConfidence;
    String source;

    if (aiClass != AnimalClass.unknown && aiConfidence > 0.35) {
      finalClass = aiClass;
      finalConfidence = aiConfidence;
      source = 'ai_engine';
    } else if (heuristicClass != AnimalClass.unknown) {
      finalClass = heuristicClass;
      finalConfidence = 0.4;
      source = 'heuristic';
    } else if (aiClass != AnimalClass.unknown) {
      // Low-confidence AI is better than nothing
      finalClass = aiClass;
      finalConfidence = aiConfidence;
      source = 'ai_engine_low';
    } else {
      finalClass = AnimalClass.unknown;
      finalConfidence = 0.0;
      source = 'none';
    }

    debugPrint(
      'TaxonomyService: AI=${aiClass.name}(${(aiConfidence * 100).toStringAsFixed(0)}%) '
      'Heuristic=${heuristicClass.name} → Final=${finalClass.name} via $source',
    );

    return {
      'class': finalClass,
      'confidence': finalConfidence,
      'diet': _predictDiet(finalClass, imageBytes),
      'weight': _predictTypicalWeight(finalClass),
      'source': source,
    };
  }

  Future<Map<String, dynamic>?> _queryINaturalist(Uint8List imageBytes) async {
    final url = Uri.parse(
      'https://api.inaturalist.org/v1/computervision/score',
    );

    Uint8List uploadBytes = imageBytes;
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded != null) {
        final whiteBg = img.Image(width: decoded.width, height: decoded.height);
        img.fill(whiteBg, color: img.ColorRgba8(255, 255, 255, 255));
        img.compositeImage(whiteBg, decoded);
        uploadBytes = img.encodeJpg(whiteBg, quality: 85);
      }
    } catch (_) {}

    final request = http.MultipartRequest('POST', url);
    request.files.add(
      http.MultipartFile.fromBytes('image', uploadBytes, filename: 'image.jpg'),
    );

    try {
      final response = await request.send().timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return null;

      final responseBody = await response.stream.bytesToString();
      final data = json.decode(responseBody);
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;

      final topResult = results.first;
      final taxon = topResult['taxon'];
      if (taxon == null) return null;

      final iconicTaxon = taxon['iconic_taxon_name']?.toString().toLowerCase();
      final cls = _mapIconicTaxonToClass(iconicTaxon);

      return {
        'class': cls,
        'confidence': (topResult['vision_score'] as num).toDouble(),
        'taxon': taxon['name'],
        'common_name': taxon['preferred_common_name'],
        'diet': _predictDiet(cls, imageBytes),
        'weight': _predictTypicalWeight(cls),
        'source': 'inaturalist',
      };
    } catch (_) {
      return null;
    }
  }

  AnimalClass _mapIconicTaxonToClass(String? iconic) {
    switch (iconic) {
      case 'mammalia':
        return AnimalClass.mammal;
      case 'aves':
        return AnimalClass.bird;
      case 'actinopterygii':
        return AnimalClass.fish;
      case 'amphibia':
        return AnimalClass.amphibian;
      case 'reptilia':
        return AnimalClass.reptile;
      case 'insecta':
        return AnimalClass.insect;
      case 'arachnida':
        return AnimalClass.arachnid;
      case 'mollusca':
        return AnimalClass.mollusk;
      case 'crustacea':
        return AnimalClass.crustacean;
      default:
        return AnimalClass.unknown;
    }
  }

  AnimalClass _heuristicClassification(Uint8List imageBytes) {
    try {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) return AnimalClass.unknown;

      final aspect = decoded.width / decoded.height;
      final hsvInfo = _calculateHsvStats(decoded);
      final dominantHue = hsvInfo.hue;
      final avgSaturation = hsvInfo.saturation;
      final verticalBias = _calculateVerticalBias(decoded);
      final hasLegGaps = _detectLegGaps(decoded);
      final solidity = _calculateSolidity(decoded);

      // --- TAXONOMIC SCORING ENGINE ---
      bool isEarthTone =
          (dominantHue >= 10 && dominantHue <= 60 && avgSaturation > 0.15);
      bool isAchromatic = (avgSaturation < 0.15);

      // MAMMAL SCORE
      double mammalScore = 0;
      if (isEarthTone) mammalScore += 0.4;
      if (isAchromatic) mammalScore += 0.4;
      if (hasLegGaps) mammalScore += 0.5;
      if (aspect > 0.8 && aspect < 2.2) mammalScore += 0.3;
      if (solidity > 0.5) mammalScore += 0.3;

      if (mammalScore >= 0.7) return AnimalClass.mammal;

      // FISH SCORE
      bool isAquaticTone = (dominantHue > 165 && dominantHue < 255);
      if (aspect > 1.3 && isAquaticTone && verticalBias < 0.45)
        return AnimalClass.fish;
      if (aspect > 1.4 && !hasLegGaps && verticalBias < 0.4)
        return AnimalClass.fish;

      // BIRD
      if (aspect < 1.0 && verticalBias > 0.6) return AnimalClass.bird;

      // INSECT (Strictly low solidity)
      if (solidity < 0.4 && aspect > 0.5 && aspect < 2.5 && !hasLegGaps)
        return AnimalClass.insect;

      // REPTILE/AMPHIBIAN
      if (aspect > 1.4 &&
          (dominantHue > 45 && dominantHue < 100) &&
          verticalBias < 0.4)
        return AnimalClass.reptile;
      if (aspect > 2.5 && !hasLegGaps) return AnimalClass.reptile;

      // FALLBACKS
      if (isEarthTone || isAchromatic) return AnimalClass.mammal;
      if (solidity > 0.8 && aspect > 0.8 && aspect < 1.4)
        return AnimalClass.mollusk;

      return AnimalClass.unknown;
    } catch (_) {
      return AnimalClass.unknown;
    }
  }

  double _calculateSolidity(img.Image image) {
    int objectPixels = 0;
    for (var pixel in image) {
      if (pixel.a > 100) objectPixels++;
    }
    return objectPixels / (image.width * image.height);
  }

  ({double hue, double saturation}) _calculateHsvStats(img.Image image) {
    final Map<int, int> hueCounts = {};
    double totalSat = 0;
    int count = 0;
    for (var pixel in image) {
      if (pixel.a < 128) continue;
      final hsv = _rgbToHsv(pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt());
      final h = (hsv[0] / 10).floor() * 10;
      hueCounts[h] = (hueCounts[h] ?? 0) + 1;
      totalSat += hsv[1];
      count++;
    }
    if (count == 0) return (hue: 0, saturation: 0);
    final domHue = hueCounts.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key
        .toDouble();
    return (hue: domHue, saturation: totalSat / count);
  }

  bool _detectLegGaps(img.Image image) {
    int xStart = (image.width * 0.2).toInt();
    int xEnd = (image.width * 0.8).toInt();
    int yStart = (image.height * 0.75).toInt();
    int gaps = 0;

    for (int x = xStart; x < xEnd; x++) {
      bool isGap = true;
      for (int y = yStart; y < image.height; y++) {
        if (image.getPixel(x, y).a > 20) {
          isGap = false;
          break;
        }
      }
      if (isGap) gaps++;
    }
    return gaps > (image.width * 0.15);
  }

  double _calculateVerticalBias(img.Image image) {
    int topHalf = 0;
    int bottomHalf = 0;
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final p = image.getPixel(x, y);
        if (p.a < 128) continue;
        if (y > image.height * 0.6) bottomHalf++;
        if (y < image.height * 0.4) topHalf++;
      }
    }
    final total = topHalf + bottomHalf;
    return total > 0 ? bottomHalf / total : 0.5;
  }

  List<double> _rgbToHsv(int r, int g, int b) {
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

  String _predictDiet(AnimalClass cls, Uint8List bytes) {
    switch (cls) {
      case AnimalClass.mammal:
        return 'omnivore';
      case AnimalClass.bird:
        return 'omnivore';
      case AnimalClass.fish:
        return 'carnivore';
      case AnimalClass.reptile:
        return 'carnivore';
      case AnimalClass.insect:
        return 'herbivore';
      case AnimalClass.arachnid:
        return 'carnivore';
      case AnimalClass.crustacean:
        return 'omnivore';
      case AnimalClass.mollusk:
        return 'herbivore';
      case AnimalClass.cnidarian:
        return 'carnivore';
      case AnimalClass.echinoderm:
        return 'detritivore';
      case AnimalClass.annelid:
        return 'detritivore';
      default:
        return 'unknown';
    }
  }

  double _predictTypicalWeight(AnimalClass cls) {
    switch (cls) {
      case AnimalClass.mammal:
        return 25.0;
      case AnimalClass.bird:
        return 1.5;
      case AnimalClass.fish:
        return 5.0;
      case AnimalClass.reptile:
        return 2.0;
      case AnimalClass.amphibian:
        return 0.2;
      case AnimalClass.insect:
        return 0.01;
      case AnimalClass.arachnid:
        return 0.02;
      case AnimalClass.crustacean:
        return 0.5;
      case AnimalClass.mollusk:
        return 0.1;
      case AnimalClass.cnidarian:
        return 1.0;
      case AnimalClass.echinoderm:
        return 0.2;
      case AnimalClass.annelid:
        return 0.05;
      default:
        return 0.0;
    }
  }
}
