import 'dart:math';

// Mocking the classes from biometric_service.dart for testing logic
class OrganismFeature {
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

double featureSimilarityLogic(OrganismFeature f1, OrganismFeature f2) {
    // 1. Color Match
    double globalColorMatch = 0;
    f1.hueBins.forEach((key, val) {
      if (val == 0) return;
      int hue = int.tryParse(key.replaceAll('h', '')) ?? -1;
      double exact = f2.hueBins[key] ?? 0;
      int prevHue = (hue - 10) % 360; if (prevHue < 0) prevHue += 360;
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
      int gridCount = 0;
      f1.spatialHueBins!.forEach((key, val) {
        if (f2.spatialHueBins!.containsKey(key)) {
          spatialSum += min(val, f2.spatialHueBins![key]!);
          gridCount++;
        }
      });
      if (gridCount > 0) spatialMatch = (spatialSum / 9.0).clamp(0.0, 1.0);
    }
    
    final colorMatch = (globalColorMatch * 0.5 + spatialMatch * 0.5).clamp(0.0, 1.0);

    // 2. Shape Match
    final aspectDiff = (log(f1.aspectRatio) - log(f2.aspectRatio)).abs();
    final solidityDiff = (f1.solidity - f2.solidity).abs();
    
    final aspectScore = pow((1.0 - (aspectDiff * 0.8)).clamp(0.0, 1.0), 1.5).toDouble();
    final solidityScore = pow((1.0 - (solidityDiff * 2.0)).clamp(0.0, 1.0), 1.5).toDouble();
    
    final shapeMatch = (aspectScore * 0.6) + (solidityScore * 0.4);

    // 3. Pattern
    final symDiff = (f1.verticalSymmetry - f2.verticalSymmetry).abs() +
                    (f1.horizontalSymmetry - f2.horizontalSymmetry).abs();
    final edgeDiff = (f1.edgeDensity - f2.edgeDensity).abs();
    final edgeScore = (1.0 - (edgeDiff * 3.0)).clamp(0.0, 1.0);
    final patternMatch = (1.0 - (symDiff / 2.0)).clamp(0.0, 1.0) * 0.3 + (edgeScore * 0.7);

    // 4. Shade
    final shadeMatch = (1.0 - (f1.avgBrightness - f2.avgBrightness).abs()).clamp(0.0, 1.0);
    final satMatch = (1.0 - (f1.avgSaturation - f2.avgSaturation).abs()).clamp(0.0, 1.0);
    final combinedShade = (shadeMatch * 0.7 + satMatch * 0.3).clamp(0.0, 1.0);

    // Weighted Total
    double total = (colorMatch * 0.45) + 
                   (combinedShade * 0.35) + 
                   (shapeMatch * 0.15) + 
                   (patternMatch * 0.05);
    
    if (colorMatch < 0.12) total *= 0.10; 
    if (total > 0.94) total = 1.0;
    if (total < 0.15) total = 0.0;

    return total;
}

void main() {
  final ref = OrganismFeature(
    hueBins: {'h60': 1.0}, // Yellow
    avgBrightness: 0.8,
    avgSaturation: 0.9,
    aspectRatio: 1.5,
    solidity: 0.6,
    verticalSymmetry: 0.5,
    horizontalSymmetry: 0.5,
    edgeDensity: 0.2,
  );

  print('--- Testing 1:1 Match ---');
  final identical = ref;
  print('Result: ${featureSimilarityLogic(ref, identical)} (Expected: 1.0)');

  print('\n--- Testing Robust Shape Match (Minor Mask Noise) ---');
  // Simulating minor masking noise that shifts aspect ratio and solidity
  final noisyShape = OrganismFeature(
    hueBins: {'h60': 1.0},
    avgBrightness: 0.8,
    avgSaturation: 0.9,
    aspectRatio: 1.4, // Slight shift
    solidity: 0.58,   // Slight shift
    verticalSymmetry: 0.5,
    horizontalSymmetry: 0.5,
    edgeDensity: 0.2,
  );
  print('Result: ${featureSimilarityLogic(ref, noisyShape)} (Expected: near 1.0)');

  print('\n--- Testing Color Importance ---');
  final wrongColor = OrganismFeature(
    hueBins: {'h180': 1.0}, // Cyan instead of Yellow
    avgBrightness: 0.8,
    avgSaturation: 0.9,
    aspectRatio: 1.5,
    solidity: 0.6,
    verticalSymmetry: 0.5,
    horizontalSymmetry: 0.5,
    edgeDensity: 0.2,
  );
  print('Result: ${featureSimilarityLogic(ref, wrongColor)} (Expected: low score)');

  print('\n--- Testing Shade Importance ---');
  final darkColor = OrganismFeature(
    hueBins: {'h60': 1.0},
    avgBrightness: 0.3, // Much darker
    avgSaturation: 0.9,
    aspectRatio: 1.5,
    solidity: 0.6,
    verticalSymmetry: 0.5,
    horizontalSymmetry: 0.5,
    edgeDensity: 0.2,
  );
  print('Result: ${featureSimilarityLogic(ref, darkColor)} (Expected: significantly lower score)');
}
