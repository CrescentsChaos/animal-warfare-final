import re

with open("scratch/generate_features_db.dart", "r") as f:
    code = f.read()

# We need to replace the return statement and add the missing calculations

# 1. Add hueComplexity
hue_complex = """
  int significantBins = 0;
  finalHueBins.forEach((key, val) {
    if (val > 0.02) significantBins++;
  });
  final double hueComplexity = significantBins / 39.0;
"""

# 2. Add cornerDensity, diagonalDensity, lowerQuadrantSymmetry
missing_spatial = """
  final int cornerW = max(1, (maxX - minX) * 0.2).toInt();
  final int cornerH = max(1, (maxY - minY) * 0.2).toInt();
  int cornerPixels = 0;
  for (int y = minY; y < minY + cornerH; y++) {
    for (int x = minX; x < minX + cornerW; x++) if (mask[y * resized.width + x]) cornerPixels++;
    for (int x = maxX - cornerW + 1; x <= maxX; x++) if (mask[y * resized.width + x]) cornerPixels++;
  }
  for (int y = maxY - cornerH + 1; y <= maxY; y++) {
    for (int x = minX; x < minX + cornerW; x++) if (mask[y * resized.width + x]) cornerPixels++;
    for (int x = maxX - cornerW + 1; x <= maxX; x++) if (mask[y * resized.width + x]) cornerPixels++;
  }
  final double cornerDensity = cornerPixels / max(1, cornerW * cornerH * 4.0);

  int diagPixels = 0, diagArea = 0;
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

  final lowerSym = _calculateSymmetry(resized, mask, minX, maxX, midY, maxY);
  final double lowerQuadrantSymmetry = lowerSym.$1;

  int hEdges = 0, vEdges = 0;
  for (int y = 1; y < resized.height - 1; y++) {
    for (int x = 1; x < resized.width - 1; x++) {
      if (!mask[y * resized.width + x]) continue;
      final p = resized.getPixel(x, y), pR = resized.getPixel(x+1, y), pD = resized.getPixel(x, y+1);
      final lum = (p.r + p.g + p.b)/3, lumR = (pR.r + pR.g + pR.b)/3, lumD = (pD.r + pD.g + pD.b)/3;
      if ((lum - lumR).abs() > 30) hEdges++;
      if ((lum - lumD).abs() > 30) vEdges++;
    }
  }
  final double edgeBias = (hEdges + vEdges) > 0 ? (hEdges - vEdges) / (hEdges + vEdges) : 0.0;
"""

return_map = """
  return {
    'organismName': name,
    'hueBins': finalHueBins, 'spatialHueBins': spatialHueBins, 'dominantColors': dominantColors,
    'avgBrightness': totalBrightness / objectPixelCount, 'avgSaturation': totalSaturation / objectPixelCount,
    'aspectRatio': (maxX - minX + 1) / (maxY - minY + 1), 'solidity': objectPixelCount / ((maxX - minX + 1) * (maxY - minY + 1)),
    'verticalSymmetry': vSym, 'horizontalSymmetry': hSym, 'edgeDensity': _calculateEdgeDensity(resized, mask),
    'coreSolidity': coreSolidity, 'bottomHeavyBias': bottomHalf / objectPixelCount, 'maxWidthRowBias': maxWidthRowBias,
    'maxHeightColBias': maxHeightColBias, 'bottomCenterDensity': bottomCenterDensity,
    'cornerDensity': cornerDensity, 'diagonalDensity': diagonalDensity, 'lowerQuadrantSymmetry': lowerQuadrantSymmetry,
    'horizontalCentroidShift': (maxX > minX) ? (centroidX - minX) / (maxX - minX) : 0.5,
    'convexHullRatio': (objectPixelCount / ((maxX - minX + 1) * (maxY - minY + 1) / 2.0)).clamp(0.0, 1.0),
    'verticalMassDistribution': verticalMassDistribution, 'colorGranularity': (uniqueColors.length / 4096.0).clamp(0.0, 1.0),
    'fringeDensity': fringe / objectPixelCount, 'verticalThinning': verticalThinning, 'localSymmetry': localSymmetry,
    'colorClustering': clustered / objectPixelCount, 'yGradient': (maxY > minY) ? (centroidY - minY) / (maxY - minY) : 0.5,
    'widthVariance': 0.0, 'shellIndex': 0.0, 'radialOverlap': 0.0, 'yCentroid': centroidY / resized.height,
    'jaggedness': fringe / sqrt(objectPixelCount), 'topThirdDensity': top40 / objectPixelCount,
    'bilateralSym': hSym, 'verticalBias': verticalBias, 'topHeavyBias': top40 / objectPixelCount,
    'hueComplexity': hueComplexity, 'compactness': (perim * perim) / objectPixelCount, 'limbDensity': limbPix / objectPixelCount,
    'directionalEdge_bias': edgeBias,
    'directionalEdgeBias': edgeBias,
  };
"""

# Inject before return
idx = code.rfind("return {")
if idx != -1:
    code = code[:idx] + hue_complex + missing_spatial + return_map + code[code.find("}", idx)+2:]

with open("scratch/generate_features_db.dart", "w") as f:
    f.write(code)

print("Patched dart file")
