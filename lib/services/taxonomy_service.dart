
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:animal_warfare/models/organism.dart';

class TaxonomyService {
  static final TaxonomyService _instance = TaxonomyService._internal();
  factory TaxonomyService() => _instance;
  TaxonomyService._internal();

  /// Classifies an image into a biological category.
  /// Returns a probable AnimalClass and a confidence score.
  Future<Map<String, dynamic>> classifyImage(Uint8List imageBytes) async {
    // 1. Try iNaturalist (if online)
    try {
      final iNatResult = await _queryINaturalist(imageBytes);
      if (iNatResult != null) {
        return iNatResult;
      }
    } catch (e) {
      // Offline or error
    }

    // 2. Fallback to Heuristics
    final cls = _heuristicClassification(imageBytes);
    return {
      'class': cls,
      'confidence': 0.4,
      'diet': _predictDiet(cls, imageBytes),
      'weight': _predictTypicalWeight(cls),
      'source': 'heuristic'
    };
  }

  Future<Map<String, dynamic>?> _queryINaturalist(Uint8List imageBytes) async {
    final url = Uri.parse('https://api.inaturalist.org/v1/computervision/score');
    
    // Composite onto white background for better API performance
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
    request.files.add(http.MultipartFile.fromBytes('image', uploadBytes, filename: 'image.jpg'));

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
      'source': 'inaturalist'
    };
  }

  AnimalClass _mapIconicTaxonToClass(String? iconic) {
    switch (iconic) {
      case 'mammalia': return AnimalClass.mammal;
      case 'aves': return AnimalClass.bird;
      case 'actinopterygii': return AnimalClass.fish;
      case 'amphibia': return AnimalClass.amphibian;
      case 'reptilia': return AnimalClass.reptile;
      case 'insecta': return AnimalClass.insect;
      case 'arachnida': return AnimalClass.arachnid;
      case 'mollusca': return AnimalClass.mollusk;
      case 'crustacea': return AnimalClass.crustacean;
      default: return AnimalClass.unknown;
    }
  }

  AnimalClass _heuristicClassification(Uint8List imageBytes) {
    // Basic heuristic based on aspect ratio and color
    // This is very rough and should be improved over time
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

      // 1. MAMMAL/LARGE LAND ANIMAL
      bool isEarthTone = (dominantHue >= 15 && dominantHue <= 55);
      // If it has legs and mammal aspect, it's a mammal (even if not brown, e.g. white cow)
      if (hasLegGaps && aspect < 2.2 && aspect > 0.5) return AnimalClass.mammal;
      if (isEarthTone && hasLegGaps && aspect < 2.5) return AnimalClass.mammal;
      if (verticalBias > 0.7 && hasLegGaps) return AnimalClass.mammal;

      // 2. BIRD: Small/Square with vertical bias
      if (aspect < 1.0 && verticalBias > 0.6) return AnimalClass.bird;

      // 3. FISH: Horizontal bias + Aquatic tones
      bool isAquaticTone = (dominantHue > 165 && dominantHue < 255);
      if (aspect > 1.5 && isAquaticTone && verticalBias < 0.4) return AnimalClass.fish;

      // 4. INVERTEBRATES (Granular)
      
      // ARACHNID: High edge complexity + Square aspect
      if (aspect > 0.8 && aspect < 1.2 && hasLegGaps) return AnimalClass.arachnid;

      // CRUSTACEAN: Hard shell (High solidity) + Red/Orange/Earth
      if (solidity > 0.7 && (dominantHue < 35 || isEarthTone) && aspect > 1.2) return AnimalClass.crustacean;

      // CNIDARIAN (Jellyfish): Low saturation (transparent) + Radial/Vertical + Aquatic Tone
      if (avgSaturation < 0.25 && isAquaticTone && verticalBias < 0.5) return AnimalClass.cnidarian;

      // ECHINODERM (Starfish): Radial symmetry + Low solidity
      if (solidity < 0.6 && aspect > 0.9 && aspect < 1.1) return AnimalClass.echinoderm;

      // ANNELID (Worm): Very high aspect + low solidity
      if (aspect > 3.0 && solidity < 0.5) return AnimalClass.annelid;

      // MOLLUSK: High solidity (Shells) or Slugs
      if (solidity > 0.8 && aspect > 0.8 && aspect < 1.4) return AnimalClass.mollusk; // Snails/Clams
      if (aspect > 2.0 && solidity < 0.6 && !hasLegGaps) return AnimalClass.mollusk; // Slugs

      // INSECT: Small, horizontal or square, often green/black
      if (aspect > 0.5 && aspect < 2.0 && solidity < 0.8) return AnimalClass.insect;

      // 5. REPTILE/AMPHIBIAN
      if (aspect > 1.4 && (dominantHue > 45 && dominantHue < 100) && verticalBias < 0.4) {
        return AnimalClass.reptile;
      }
      
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
    final domHue = hueCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key.toDouble();
    return (hue: domHue, saturation: totalSat / count);
  }

  bool _detectLegGaps(img.Image image) {
    int distinctGaps = 0;
    bool inGap = false;
    int gapWidth = 0;
    
    final startY = (image.height * 0.85).toInt();
    for (int x = 2; x < image.width - 2; x++) {
      bool columnEmpty = true;
      for (int y = startY; y < image.height; y++) {
        if (image.getPixel(x, y).a > 100) {
          columnEmpty = false;
          break;
        }
      }
      
      if (columnEmpty) {
        gapWidth++;
        if (!inGap && gapWidth >= 2) {
          inGap = true;
          distinctGaps++;
        }
      } else {
        inGap = false;
        gapWidth = 0;
      }
    }
    return distinctGaps >= 2; // At least two leg-like gaps
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
      if (maxV == rf) h = (gf - bf) / d + (gf < bf ? 6 : 0);
      else if (maxV == gf) h = (bf - rf) / d + 2;
      else h = (rf - gf) / d + 4;
      h /= 6;
    }
    return [h * 360, maxV == 0 ? 0 : d / maxV, maxV];
  }
  String _predictDiet(AnimalClass cls, Uint8List bytes) {
    switch (cls) {
      case AnimalClass.mammal: return 'omnivore';
      case AnimalClass.bird: return 'omnivore';
      case AnimalClass.fish: return 'carnivore';
      case AnimalClass.reptile: return 'carnivore';
      case AnimalClass.insect: return 'herbivore';
      case AnimalClass.arachnid: return 'carnivore';
      case AnimalClass.crustacean: return 'omnivore';
      case AnimalClass.mollusk: return 'herbivore';
      case AnimalClass.cnidarian: return 'carnivore';
      case AnimalClass.echinoderm: return 'detritivore';
      case AnimalClass.annelid: return 'detritivore';
      default: return 'unknown'; 
    }
  }

  double _predictTypicalWeight(AnimalClass cls) {
    switch (cls) {
      case AnimalClass.mammal: return 25.0;
      case AnimalClass.bird: return 1.5;
      case AnimalClass.fish: return 5.0;
      case AnimalClass.reptile: return 2.0;
      case AnimalClass.amphibian: return 0.2;
      case AnimalClass.insect: return 0.01;
      case AnimalClass.arachnid: return 0.02;
      case AnimalClass.crustacean: return 0.5;
      case AnimalClass.mollusk: return 0.1;
      case AnimalClass.cnidarian: return 1.0;
      case AnimalClass.echinoderm: return 0.2;
      case AnimalClass.annelid: return 0.05;
      default: return 0.0;
    }
  }
}
