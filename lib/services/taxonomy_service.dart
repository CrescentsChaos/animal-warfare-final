
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
    return {
      'class': _heuristicClassification(imageBytes),
      'confidence': 0.4, // Heuristics are lower confidence
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
    
    return {
      'class': _mapIconicTaxonToClass(iconicTaxon),
      'confidence': (topResult['vision_score'] as num).toDouble(),
      'taxon': taxon['name'],
      'common_name': taxon['preferred_common_name'],
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
      case 'arachnida':
      case 'mollusca':
      case 'crustacea':
        return AnimalClass.invertebrate;
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
      
      // Fish often have high aspect ratio (long)
      if (aspect > 1.6) return AnimalClass.fish;
      
      // Insects are often small and have complex edges (hard to detect here without full feature extraction)
      
      // If we don't know, return unknown
      return AnimalClass.unknown;
    } catch (_) {
      return AnimalClass.unknown;
    }
  }
}
