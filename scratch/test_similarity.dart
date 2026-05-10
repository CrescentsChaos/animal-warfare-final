
import 'dart:math';

enum AnimalClass {
  mammal,
  bird,
  fish,
  amphibian,
  reptile,
  insect,
  invertebrate,
  unknown,
}

class OrganismFeature {
  final String organismName;
  final Map<String, double> hueBins;
  final Map<String, double>? spatialHueBins;
  final double avgBrightness;
  final double avgSaturation;
  final double aspectRatio;
  final double solidity;
  final double verticalSymmetry;
  final double horizontalSymmetry;
  final double edgeDensity;

  OrganismFeature({
    required this.organismName,
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
}

Map<String, double> featureSimilarity(
  OrganismFeature f1, 
  OrganismFeature f2, {
  AnimalClass? inputClass,
  AnimalClass? targetClass,
  double classConfidence = 0.0,
}) {
  double globalColorMatch = 0;
  f1.hueBins.forEach((key, val) {
    if (val == 0) return;
    int hue = int.tryParse(key.replaceAll('h', '')) ?? -1;
    if (hue == -1) return;
    double exact = f2.hueBins[key] ?? 0;
    int prevHue = (hue - 10) % 360;
    if (prevHue < 0) prevHue += 360;
    int nextHue = (hue + 10) % 360;
    double prevVal = f2.hueBins['h$prevHue'] ?? 0;
    double nextVal = f2.hueBins['h$nextHue'] ?? 0;
    double effectiveF2 = exact + (prevVal * 0.5) + (nextVal * 0.5);
    globalColorMatch += min(val, effectiveF2);
  });
  globalColorMatch = globalColorMatch.clamp(0.0, 1.0);

  double spatialMatch = globalColorMatch; 
  if (f1.spatialHueBins != null && f2.spatialHueBins != null) {
    double spatialSum = 0;
    f1.spatialHueBins!.forEach((key, val) {
      if (f2.spatialHueBins!.containsKey(key)) {
        spatialSum += min(val, f2.spatialHueBins![key]!);
      }
    });
    final cells1 = f1.spatialHueBins!.keys.map((k) => k.substring(0, 3)).toSet().length;
    final cells2 = f2.spatialHueBins!.keys.map((k) => k.substring(0, 3)).toSet().length;
    final maxCells = max(cells1, cells2);
    if (maxCells > 0) {
      spatialMatch = (spatialSum / maxCells).clamp(0.0, 1.0);
    }
  }
  
  final colorMatch = (globalColorMatch * 0.5 + spatialMatch * 0.5).clamp(0.0, 1.0);

  final aspectDiff = (f1.aspectRatio - f2.aspectRatio).abs();
  final solidityDiff = (f1.solidity - f2.solidity).abs();
  final aspectScore = (1.0 - (aspectDiff * 0.6)).clamp(0.0, 1.0);
  final solidityScore = (1.0 - (solidityDiff * 1.6)).clamp(0.0, 1.0);
  final shapeMatch = (aspectScore * 0.6) + (solidityScore * 0.4);

  final symDiff = (f1.verticalSymmetry - f2.verticalSymmetry).abs() +
                  (f1.horizontalSymmetry - f2.horizontalSymmetry).abs();
  final edgeDiff = (f1.edgeDensity - f2.edgeDensity).abs();
  final edgeScore = (1.0 - (edgeDiff * 3.0)).clamp(0.0, 1.0);
  final patternMatch = (1.0 - (symDiff / 2.0)).clamp(0.0, 1.0) * 0.3 + (edgeScore * 0.7);

  final shadeMatch = (1.0 - (f1.avgBrightness - f2.avgBrightness).abs()).clamp(0.0, 1.0);
  final satMatch = (1.0 - (f1.avgSaturation - f2.avgSaturation).abs()).clamp(0.0, 1.0);
  final combinedShade = (shadeMatch * 0.7 + satMatch * 0.3).clamp(0.0, 1.0);

  double total = (colorMatch * 0.45) + 
                 (combinedShade * 0.35) + 
                 (shapeMatch * 0.15) + 
                 (patternMatch * 0.05);
  
  // Biometric Gating
  if (colorMatch < 0.12) total *= 0.20; 

  // Taxonomic Gating
  if (inputClass != null && targetClass != null && 
      inputClass != AnimalClass.unknown && targetClass != AnimalClass.unknown) {
    if (inputClass != targetClass) {
      final penalty = 0.1 + (0.4 * (1.0 - classConfidence)); 
      total *= penalty.clamp(0.1, 0.8);
    } else {
      total *= (1.0 + (0.15 * classConfidence));
    }
  }

  return {
    'total': total,
    'Color': colorMatch,
    'Shape': shapeMatch,
    'Pattern': patternMatch,
    'TaxMatch': (inputClass == targetClass && inputClass != AnimalClass.unknown) ? 1.0 : 0.0,
  };
}

void main() {
  print('--- SCENARIO: Siberian Tiger vs. Toad ---');
  
  final tigerFeature = OrganismFeature(
    organismName: 'Siberian Tiger',
    hueBins: {'h30': 0.8, 'h0': 0.2}, // Orange/White
    avgBrightness: 0.6,
    avgSaturation: 0.7,
    aspectRatio: 1.5,
    solidity: 0.8,
    verticalSymmetry: 0.7,
    horizontalSymmetry: 0.5,
    edgeDensity: 0.2,
  );

  final toadFeature = OrganismFeature(
    organismName: 'Asian Common Toad',
    hueBins: {'h40': 0.7, 'h20': 0.3}, // Brownish
    avgBrightness: 0.4,
    avgSaturation: 0.3,
    aspectRatio: 1.2,
    solidity: 0.9,
    verticalSymmetry: 0.9,
    horizontalSymmetry: 0.8,
    edgeDensity: 0.4,
  );

  // Case 1: No taxonomic gating (Legacy)
  final legacyResult = featureSimilarity(tigerFeature, toadFeature);
  print('Legacy Score (Tiger vs Toad): ${legacyResult['total']!.toStringAsFixed(3)}');

  // Case 2: Taxonomic gating (Mammal vs Amphibian)
  final gatedResult = featureSimilarity(
    tigerFeature, 
    toadFeature,
    inputClass: AnimalClass.mammal,
    targetClass: AnimalClass.amphibian,
    classConfidence: 0.9,
  );
  print('Gated Score (Tiger vs Toad): ${gatedResult['total']!.toStringAsFixed(3)}');

  print('\n--- SCENARIO: Siberian Tiger vs. Siberian Tiger ---');
  final perfectResult = featureSimilarity(
    tigerFeature, 
    tigerFeature,
    inputClass: AnimalClass.mammal,
    targetClass: AnimalClass.mammal,
    classConfidence: 1.0,
  );
  print('Perfect Match Score: ${perfectResult['total']!.toStringAsFixed(3)}');
}
