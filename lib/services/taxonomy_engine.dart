import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/services/biometric_service.dart';
import 'package:animal_warfare/services/feature_db_service.dart';

/// A statistical profile for an animal class (e.g., Mammal).
class TaxonomicProfile {
  final AnimalClass animalClass;
  final Map<String, double> featureMeans;
  final Map<String, double> featureVariances;
  final int sampleCount;
  TaxonomicProfile({
    required this.animalClass,
    required this.featureMeans,
    required this.featureVariances,
    required this.sampleCount,
  });

  factory TaxonomicProfile.fromJson(Map<String, dynamic> json) {
    return TaxonomicProfile(
      animalClass: AnimalClass.values.firstWhere(
        (e) => e.name == json['class'],
        orElse: () => AnimalClass.unknown,
      ),
      featureMeans: Map<String, double>.from(json['means']),
      featureVariances: Map<String, double>.from(json['variances']),
      sampleCount: json['count'] ?? 0,
    );
  }
}

/// Gaussian Naive Bayes classifier for taxonomic classification.
/// Uses log-likelihood scoring with class priors and feature importance weighting.
class TaxonomyEngine {
  static final TaxonomyEngine _instance = TaxonomyEngine._internal();
  factory TaxonomyEngine() => _instance;
  TaxonomyEngine._internal();

  Map<AnimalClass, List<TaxonomicProfile>>? _profiles;
  Map<String, double>? _globalMeans;
  Map<String, double>? _globalStdDevs;
  int _totalSamples = 0;
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      final dbService = FeatureDbService();
      await dbService.initialize();

      final profilesData = await dbService.getAllTaxonomyProfiles();
      _profiles = {};
      _totalSamples = 0;

      if (profilesData.isNotEmpty) {
        // Load Global Normalization Params from SQL
        final metaData = await dbService.getTaxonomyMetadata('global_stats');
        if (metaData != null) {
          _globalMeans = Map<String, double>.from(metaData['means']);
          _globalStdDevs = Map<String, double>.from(metaData['stdDevs']);
        }

        for (var item in profilesData) {
          String clsName = item['class'] as String;
          // Strip component suffix (e.g. mammal_0 -> mammal)
          if (clsName.contains('_')) {
            clsName = clsName.substring(0, clsName.lastIndexOf('_'));
          }

          final cls = AnimalClass.values.firstWhere(
            (e) => e.name == clsName,
            orElse: () => AnimalClass.unknown,
          );

          if (cls != AnimalClass.unknown) {
            final profile = TaxonomicProfile(
              animalClass: cls,
              featureMeans: Map<String, double>.from(item['means']),
              featureVariances: Map<String, double>.from(item['variances']),
              sampleCount: item['count'] as int,
            );
            _profiles!.putIfAbsent(cls, () => []).add(profile);
            _totalSamples += profile.sampleCount;
          }
        }
      }

      _isInitialized = true;
      debugPrint(
        'TaxonomyEngine: Loaded ${_profiles!.length} class profiles ($_totalSamples total samples)',
      );
    } catch (e) {
      debugPrint('TaxonomyEngine init error: $e');
    }
  }

  /// The key features used for classification, and their importance weights.
  /// Higher weight = more influence on the classification decision.
  static const Map<String, double> _featureWeights = {
    'aspectRatio': 200.0,
    'solidity': 500.0,
    'compactness': 100.0,
    'limbDensity': 40.0,
    'edgeDensity': 100.0,
    'verticalBias': 40.0,
    'topHeavyBias': 100.0,
    'hueComplexity': 0.0,
    'hSymmetry': 100.0,
    'vSymmetry': 100.0,
    'coreSolidity': 100.0,
    'bottomHeavyBias': 100.0,
    'maxWidthRowBias': 20.0,
    'maxHeightColBias': 20.0,
    'bottomCenterDensity': 100.0,
    'cornerDensity': 50.0,
    'radialOverlap': 100.0,
    'yCentroid': 100.0,
    'jaggedness': 100.0,
    'topThirdDensity': 100.0,
    'bilateralSym': 500.0,
    'diagonalDensity': 100.0,
    'convexHullRatio': 100.0,
    'verticalMassDistribution': 100.0,
    'colorGranularity': 0.0,
  };

  /// Classifies a subject using Gaussian Mixture Model log-likelihood.
  Map<String, dynamic> classify(OrganismFeature feature) {
    if (!_isInitialized || _profiles == null || _profiles!.isEmpty) {
      return {'class': AnimalClass.unknown, 'confidence': 0.0};
    }

    Map<AnimalClass, double> classScores = {};

    _profiles!.forEach((cls, componentList) {
      double bestComponentScore = double.negativeInfinity;

      for (var profile in componentList) {
        double score = 0.0;

        // Distance-based matching (GNB)
        _featureWeights.forEach((key, weight) {
          if (weight == 0) return;
          double val = _getFeatureValue(feature, key);
          double mean = profile.featureMeans[key] ?? 0.0;
          double variance = profile.featureVariances[key] ?? 0.05;

          // Standardize using global stats
          if (_globalMeans != null && _globalStdDevs != null) {
            double gMean = _globalMeans![key] ?? 0.5;
            double gStd = (_globalStdDevs![key] ?? 1.0).clamp(0.05, 10.0);
            val = ((val - gMean) / gStd).clamp(-5.0, 5.0);
          }

          // Proper GNB likelihood (stabilized by removing log-variance term)
          score -= (0.5 * pow(val - mean, 2) / (variance + 0.1)) * weight;
        });

        // HIGH-WEIGHT COLOR BINS for species-specific signatures
        feature.hueBins.forEach((bin, val) {
          double mean = profile.featureMeans[bin] ?? 0.0;
          double variance = profile.featureVariances[bin] ?? 0.01;
          score -= (0.5 * pow(val - mean, 2) / (variance + 0.01)) * 200.0;
        });

        if (score > bestComponentScore) {
          bestComponentScore = score;
        }
      }
      classScores[cls] = bestComponentScore;
    });

    AnimalClass bestClass = AnimalClass.unknown;
    double bestLogLikelihood = double.negativeInfinity;

    classScores.forEach((cls, score) {
      if (score > bestLogLikelihood) {
        bestLogLikelihood = score;
        bestClass = cls;
      }
    });

    final posteriors = classScores.map((k, v) => MapEntry(k.name, v));

    // Use a softer softmax (temperature scaling) for more human-friendly confidence
    double temperature = 2.0;
    double maxScore = posteriors.values.reduce(max);
    double sumExp = 0;
    posteriors.forEach((cls, s) {
      sumExp += exp((s - maxScore) / temperature);
    });
    double confidence =
        exp((bestLogLikelihood - maxScore) / temperature) / sumExp;

    debugPrint(
      'TaxonomyEngine: Distance-based classification: ${bestClass.name} (${(confidence * 100).toStringAsFixed(1)}%)',
    );

    return {
      'class': bestClass,
      'confidence': confidence,
      'allScores': posteriors,
    };
  }

  double _getFeatureValue(OrganismFeature f, String key) {
    switch (key) {
      case 'aspectRatio':
        return f.aspectRatio;
      case 'solidity':
        return f.solidity;
      case 'avgBrightness':
        return f.avgBrightness;
      case 'avgSaturation':
        return f.avgSaturation;
      case 'edgeDensity':
        return f.edgeDensity;
      case 'vSymmetry':
        return f.verticalSymmetry;
      case 'hSymmetry':
        return f.horizontalSymmetry;
      case 'verticalBias':
        return f.verticalBias;
      case 'topHeavyBias':
        return f.topHeavyBias;
      case 'hueComplexity':
        return f.hueComplexity;
      case 'compactness':
        return f.compactness;
      case 'limbDensity':
        return f.limbDensity;
      case 'directionalEdgeBias':
        return f.directionalEdgeBias;
      case 'coreSolidity':
        return f.coreSolidity;
      case 'bottomHeavyBias':
        return f.bottomHeavyBias;
      case 'maxWidthRowBias':
        return f.maxWidthRowBias;
      case 'maxHeightColBias':
        return f.maxHeightColBias;
      case 'bottomCenterDensity':
        return f.bottomCenterDensity;
      case 'cornerDensity':
        return f.cornerDensity;
      case 'diagonalDensity':
        return f.diagonalDensity;
      case 'lowerQuadrantSymmetry':
        return f.lowerQuadrantSymmetry;
      case 'horizontalCentroidShift':
        return f.horizontalCentroidShift;
      case 'convexHullRatio':
        return f.convexHullRatio;
      case 'verticalMassDistribution':
        return f.verticalMassDistribution;
      case 'colorGranularity':
        return f.colorGranularity;
      case 'fringeDensity':
        return f.fringeDensity;
      case 'verticalThinning':
        return f.verticalThinning;
      case 'localSymmetry':
        return f.localSymmetry;
      case 'colorClustering':
        return f.colorClustering;
      case 'yGradient':
        return f.yGradient;
      case 'widthVariance':
        return f.widthVariance;
      case 'shellIndex':
        return f.shellIndex;
      case 'radialOverlap':
        return f.radialOverlap;
      case 'yCentroid':
        return f.yCentroid;
      case 'jaggedness':
        return f.jaggedness;
      case 'topThirdDensity':
        return f.topThirdDensity;
      case 'bilateralSym':
        return f.bilateralSym;
      default:
        return 0.5;
    }
  }
}
