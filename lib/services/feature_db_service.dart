// lib/services/feature_db_service.dart
//
// SQLite-backed feature database for organism biometric features.
// Replaces the old sprite_features.json approach with faster indexed queries.

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:animal_warfare/services/biometric_service.dart';

class FeatureDbService {
  static final FeatureDbService _instance = FeatureDbService._internal();
  factory FeatureDbService() => _instance;
  FeatureDbService._internal();

  Database? _db;
  bool _isInitialized = false;
  String? _customDbPath;

  bool get isInitialized => _isInitialized;

  /// Set a custom database path (useful for standalone tools interacting directly with source assets)
  void setCustomDbPath(String path) {
    _customDbPath = path;
  }

  /// Initialize the database. Copies bundled asset on first run unless a custom path is used.
  Future<void> initialize() async {
    if (_isInitialized) return;

    late String dbPath;
    if (_customDbPath != null) {
      dbPath = _customDbPath!;
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      dbPath = p.join(docsDir.path, 'animal_warfare', 'sprite_features.db');
    }

    // Ensure directory exists
    final dir = Directory(p.dirname(dbPath));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // Force copy bundled DB during development to ensure fixes are applied.
    // In production, we should probably check a version number.
    const bool forceUpdate = true;

    if (!File(dbPath).existsSync() || forceUpdate) {
      try {
        final data = await rootBundle.load('assets/ml/sprite_features.db');
        await File(dbPath).writeAsBytes(data.buffer.asUint8List(), flush: true);
        debugPrint(
          'FeatureDbService: Updated local DB from bundled asset at $dbPath',
        );
      } catch (e) {
        if (!File(dbPath).existsSync()) {
          debugPrint(
            'FeatureDbService: No bundled DB found and no local DB exists: $e',
          );
        }
      }
    }

    _db = await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await _createTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateToV2(db);
        }
      },
    );

    // Ensure new columns exist even if version wasn't bumped (e.g., forceUpdate copy)
    await _ensureNewColumns();

    _isInitialized = true;
    final count = await getFeatureCount();
    debugPrint('FeatureDbService: Initialized with $count features');
  }

  Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS organism_features (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        organism_name TEXT UNIQUE NOT NULL,
        scientific_name TEXT,
        hue_bins TEXT NOT NULL,
        spatial_hue_bins TEXT,
        dominant_colors TEXT,
        avg_brightness REAL NOT NULL,
        avg_saturation REAL NOT NULL,
        aspect_ratio REAL NOT NULL,
        solidity REAL NOT NULL,
        vertical_symmetry REAL NOT NULL,
        horizontal_symmetry REAL NOT NULL,
        edge_density REAL NOT NULL,
        core_solidity REAL NOT NULL DEFAULT 0.0,
        bottom_heavy_bias REAL NOT NULL DEFAULT 0.0,
        max_width_row_bias REAL NOT NULL DEFAULT 0.0,
        max_height_col_bias REAL NOT NULL DEFAULT 0.0,
        bottom_center_density REAL NOT NULL DEFAULT 0.0,
        corner_density REAL NOT NULL DEFAULT 0.0,
        diagonal_density REAL NOT NULL DEFAULT 0.0,
        lower_quadrant_symmetry REAL NOT NULL DEFAULT 0.0,
        horizontal_centroid_shift REAL NOT NULL DEFAULT 0.0,
        convex_hull_ratio REAL NOT NULL DEFAULT 0.0,
        vertical_mass_distribution REAL NOT NULL DEFAULT 0.0,
        color_granularity REAL NOT NULL DEFAULT 0.0,
        fringe_density REAL NOT NULL DEFAULT 0.0,
        vertical_thinning REAL NOT NULL DEFAULT 0.0,
        local_symmetry REAL NOT NULL DEFAULT 0.0,
        color_clustering REAL NOT NULL DEFAULT 0.0,
        y_gradient REAL NOT NULL DEFAULT 0.0,
        width_variance REAL NOT NULL DEFAULT 0.0,
        shell_index REAL NOT NULL DEFAULT 0.0,
        radial_overlap REAL NOT NULL DEFAULT 0.0,
        y_centroid REAL NOT NULL DEFAULT 0.0,
        jaggedness REAL NOT NULL DEFAULT 0.0,
        top_third_density REAL NOT NULL DEFAULT 0.0,
        bilateral_sym REAL NOT NULL DEFAULT 0.0,
        vertical_bias REAL NOT NULL DEFAULT 0.5,
        top_heavy_bias REAL NOT NULL DEFAULT 0.5,
        hue_complexity REAL NOT NULL DEFAULT 0.0,
        compactness REAL NOT NULL DEFAULT 1.0,
        limb_density REAL NOT NULL DEFAULT 0.0,
        directional_edge_bias REAL NOT NULL DEFAULT 0.0,
        animal_class TEXT,
        diet TEXT,
        weight REAL,
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        training_count INTEGER NOT NULL DEFAULT 1
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS taxonomy_metadata (
        key TEXT PRIMARY KEY,
        data TEXT NOT NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_scientific_name ON organism_features(scientific_name)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_organism_name ON organism_features(organism_name)',
    );

    // Taxonomy model storage
    await db.execute('''
      CREATE TABLE IF NOT EXISTS taxonomy_profiles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        animal_class TEXT UNIQUE NOT NULL,
        feature_means TEXT NOT NULL,
        feature_variances TEXT NOT NULL,
        sample_count INTEGER NOT NULL,
        updated_at TEXT NOT NULL DEFAULT (datetime('now'))
      )
    ''');
  }

  /// Migrate existing v1 databases to v2 (add class/diet/weight columns).
  Future<void> _migrateToV2(Database db) async {
    try {
      await db.execute(
        'ALTER TABLE organism_features ADD COLUMN animal_class TEXT',
      );
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE organism_features ADD COLUMN diet TEXT');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE organism_features ADD COLUMN weight REAL');
    } catch (_) {}
    debugPrint('FeatureDbService: Migrated to v2 (added class/diet/weight)');
  }

  /// Ensure new columns exist even on forceUpdate-copied databases.
  Future<void> _ensureNewColumns() async {
    if (_db == null) return;
    try {
      await _db!.rawQuery(
        'SELECT animal_class, diet, weight FROM organism_features LIMIT 1',
      );
    } catch (_) {
      await _migrateToV2(_db!);
    }
  }

  /// Get a single feature by organism name.
  Future<OrganismFeature?> getFeature(String organismName) async {
    if (_db == null) return null;
    final results = await _db!.query(
      'organism_features',
      where: 'organism_name = ?',
      whereArgs: [organismName],
    );
    if (results.isEmpty) return null;
    return _featureFromRow(results.first);
  }

  /// Get all features as a map keyed by organism name.
  Future<Map<String, OrganismFeature>> getAllFeatures() async {
    if (_db == null) return {};
    final results = await _db!.query('organism_features');
    final map = <String, OrganismFeature>{};
    for (final row in results) {
      final feature = _featureFromRow(row);
      map[feature.organismName] = feature;
    }
    return map;
  }

  /// Search features by scientific name (case-insensitive).
  Future<List<OrganismFeature>> searchByScientificName(String sciName) async {
    if (_db == null) return [];
    final results = await _db!.query(
      'organism_features',
      where: 'LOWER(scientific_name) = LOWER(?)',
      whereArgs: [sciName],
    );
    return results.map((r) => _featureFromRow(r)).toList();
  }

  /// Get total feature count.
  Future<int> getFeatureCount() async {
    if (_db == null) return 0;
    final result = await _db!.rawQuery(
      'SELECT COUNT(*) as count FROM organism_features',
    );
    if (result.isEmpty) return 0;
    return (result.first['count'] as int?) ?? 0;
  }

  /// Convert a database row to an OrganismFeature.
  OrganismFeature _featureFromRow(Map<String, dynamic> row) {
    final hueBins = Map<String, double>.from(
      jsonDecode(row['hue_bins'] as String),
    );

    final spatialHueBins = row['spatial_hue_bins'] != null
        ? Map<String, double>.from(
            jsonDecode(row['spatial_hue_bins'] as String),
          )
        : null;

    final dominantColors = row['dominant_colors'] != null
        ? (jsonDecode(row['dominant_colors'] as String) as List)
              .map((v) => Color(v as int))
              .toList()
        : <Color>[];

    return OrganismFeature(
      organismName: row['organism_name'] as String,
      dominantColors: dominantColors,
      hueBins: hueBins,
      spatialHueBins: spatialHueBins,
      avgBrightness: (row['avg_brightness'] as num).toDouble(),
      avgSaturation: (row['avg_saturation'] as num).toDouble(),
      aspectRatio: (row['aspect_ratio'] as num).toDouble(),
      solidity: (row['solidity'] as num).toDouble(),
      verticalSymmetry: (row['vertical_symmetry'] as num).toDouble(),
      horizontalSymmetry: (row['horizontal_symmetry'] as num).toDouble(),
      edgeDensity: (row['edge_density'] as num).toDouble(),
      coreSolidity: (row['core_solidity'] as num?)?.toDouble() ?? 0.0,
      bottomHeavyBias: (row['bottom_heavy_bias'] as num?)?.toDouble() ?? 0.0,
      maxWidthRowBias: (row['max_width_row_bias'] as num?)?.toDouble() ?? 0.0,
      maxHeightColBias: (row['max_height_col_bias'] as num?)?.toDouble() ?? 0.0,
      bottomCenterDensity:
          (row['bottom_center_density'] as num?)?.toDouble() ?? 0.0,
      cornerDensity: (row['corner_density'] as num?)?.toDouble() ?? 0.0,
      diagonalDensity: (row['diagonal_density'] as num?)?.toDouble() ?? 0.0,
      lowerQuadrantSymmetry:
          (row['lower_quadrant_symmetry'] as num?)?.toDouble() ?? 0.0,
      horizontalCentroidShift:
          (row['horizontal_centroid_shift'] as num?)?.toDouble() ?? 0.0,
      convexHullRatio: (row['convex_hull_ratio'] as num?)?.toDouble() ?? 0.0,
      verticalMassDistribution:
          (row['vertical_mass_distribution'] as num?)?.toDouble() ?? 0.0,
      colorGranularity: (row['color_granularity'] as num?)?.toDouble() ?? 0.0,
      fringeDensity: (row['fringe_density'] as num?)?.toDouble() ?? 0.0,
      verticalThinning: (row['vertical_thinning'] as num?)?.toDouble() ?? 0.0,
      localSymmetry: (row['local_symmetry'] as num?)?.toDouble() ?? 0.0,
      colorClustering: (row['color_clustering'] as num?)?.toDouble() ?? 0.0,
      yGradient: (row['y_gradient'] as num?)?.toDouble() ?? 0.0,
      widthVariance: (row['width_variance'] as num?)?.toDouble() ?? 0.0,
      shellIndex: (row['shell_index'] as num?)?.toDouble() ?? 0.0,
      radialOverlap: (row['radial_overlap'] as num?)?.toDouble() ?? 0.0,
      yCentroid: (row['y_centroid'] as num?)?.toDouble() ?? 0.0,
      jaggedness: (row['jaggedness'] as num?)?.toDouble() ?? 0.0,
      topThirdDensity: (row['top_third_density'] as num?)?.toDouble() ?? 0.0,
      bilateralSym: (row['bilateral_sym'] as num?)?.toDouble() ?? 0.0,
      verticalBias: (row['vertical_bias'] as num?)?.toDouble() ?? 0.5,
      topHeavyBias: (row['top_heavy_bias'] as num?)?.toDouble() ?? 0.5,
      hueComplexity: (row['hue_complexity'] as num?)?.toDouble() ?? 0.0,
      compactness: (row['compactness'] as num?)?.toDouble() ?? 1.0,
      limbDensity: (row['limb_density'] as num?)?.toDouble() ?? 0.0,
      directionalEdgeBias:
          (row['directional_edge_bias'] as num?)?.toDouble() ?? 0.0,
      animalClass: row['animal_class'] as String?,
    );
  }

  /// Upsert a newly trained feature. Averages with existing using training_count.
  /// Now also stores class/diet/weight metadata for biological plausibility matching.
  Future<void> upsertTrainedFeature({
    required String scientificName,
    required OrganismFeature newFeature,
    String? animalClass,
    String? diet,
    double? weight,
  }) async {
    if (_db == null) return;

    final organismName = newFeature.organismName;
    // Use metadata from feature object if not explicitly provided
    final effectiveClass = animalClass ?? newFeature.animalClass;

    final existing = await _db!.query(
      'organism_features',
      where: 'organism_name = ?',
      whereArgs: [organismName],
    );

    if (existing.isNotEmpty) {
      final oldRow = existing.first;
      final oldCount = (oldRow['training_count'] as int?) ?? 1;
      final newCount = oldCount + 1;

      double weightedAvg(double oldVal, double newVal, int oldCount) {
        return (oldVal * oldCount + newVal) / (oldCount + 1);
      }

      final mergedData = {
        'avg_brightness': weightedAvg(
          oldRow['avg_brightness'] as double,
          newFeature.avgBrightness,
          oldCount,
        ),
        'avg_saturation': weightedAvg(
          oldRow['avg_saturation'] as double,
          newFeature.avgSaturation,
          oldCount,
        ),
        'aspect_ratio': weightedAvg(
          oldRow['aspect_ratio'] as double,
          newFeature.aspectRatio,
          oldCount,
        ),
        'solidity': weightedAvg(
          oldRow['solidity'] as double,
          newFeature.solidity,
          oldCount,
        ),
        'vertical_symmetry': weightedAvg(
          oldRow['vertical_symmetry'] as double,
          newFeature.verticalSymmetry,
          oldCount,
        ),
        'horizontal_symmetry': weightedAvg(
          oldRow['horizontal_symmetry'] as double,
          newFeature.horizontalSymmetry,
          oldCount,
        ),
        'edge_density': weightedAvg(
          oldRow['edge_density'] as double,
          newFeature.edgeDensity,
          oldCount,
        ),
        'core_solidity': weightedAvg(
          oldRow['core_solidity'] as double? ?? 0.0,
          newFeature.coreSolidity,
          oldCount,
        ),
        'bottom_heavy_bias': weightedAvg(
          oldRow['bottom_heavy_bias'] as double? ?? 0.0,
          newFeature.bottomHeavyBias,
          oldCount,
        ),
        'max_width_row_bias': weightedAvg(
          oldRow['max_width_row_bias'] as double? ?? 0.0,
          newFeature.maxWidthRowBias,
          oldCount,
        ),
        'max_height_col_bias': weightedAvg(
          oldRow['max_height_col_bias'] as double? ?? 0.0,
          newFeature.maxHeightColBias,
          oldCount,
        ),
        'bottom_center_density': weightedAvg(
          oldRow['bottom_center_density'] as double? ?? 0.0,
          newFeature.bottomCenterDensity,
          oldCount,
        ),
        'corner_density': weightedAvg(
          oldRow['corner_density'] as double? ?? 0.0,
          newFeature.cornerDensity,
          oldCount,
        ),
        'diagonal_density': weightedAvg(
          oldRow['diagonal_density'] as double? ?? 0.0,
          newFeature.diagonalDensity,
          oldCount,
        ),
        'lower_quadrant_symmetry': weightedAvg(
          oldRow['lower_quadrant_symmetry'] as double? ?? 0.0,
          newFeature.lowerQuadrantSymmetry,
          oldCount,
        ),
        'horizontal_centroid_shift': weightedAvg(
          oldRow['horizontal_centroid_shift'] as double? ?? 0.0,
          newFeature.horizontalCentroidShift,
          oldCount,
        ),
        'convex_hull_ratio': weightedAvg(
          oldRow['convex_hull_ratio'] as double? ?? 0.0,
          newFeature.convexHullRatio,
          oldCount,
        ),
        'vertical_mass_distribution': weightedAvg(
          oldRow['vertical_mass_distribution'] as double? ?? 0.0,
          newFeature.verticalMassDistribution,
          oldCount,
        ),
        'color_granularity': weightedAvg(
          oldRow['color_granularity'] as double? ?? 0.0,
          newFeature.colorGranularity,
          oldCount,
        ),
        'fringe_density': weightedAvg(
          oldRow['fringe_density'] as double? ?? 0.0,
          newFeature.fringeDensity,
          oldCount,
        ),
        'vertical_thinning': weightedAvg(
          oldRow['vertical_thinning'] as double? ?? 0.0,
          newFeature.verticalThinning,
          oldCount,
        ),
        'local_symmetry': weightedAvg(
          oldRow['local_symmetry'] as double? ?? 0.0,
          newFeature.localSymmetry,
          oldCount,
        ),
        'color_clustering': weightedAvg(
          oldRow['color_clustering'] as double? ?? 0.0,
          newFeature.colorClustering,
          oldCount,
        ),
        'y_gradient': weightedAvg(
          oldRow['y_gradient'] as double? ?? 0.0,
          newFeature.yGradient,
          oldCount,
        ),
        'width_variance': weightedAvg(
          oldRow['width_variance'] as double? ?? 0.0,
          newFeature.widthVariance,
          oldCount,
        ),
        'shell_index': weightedAvg(
          oldRow['shell_index'] as double? ?? 0.0,
          newFeature.shellIndex,
          oldCount,
        ),
        'radial_overlap': weightedAvg(
          oldRow['radial_overlap'] as double? ?? 0.0,
          newFeature.radialOverlap,
          oldCount,
        ),
        'y_centroid': weightedAvg(
          oldRow['y_centroid'] as double? ?? 0.0,
          newFeature.yCentroid,
          oldCount,
        ),
        'jaggedness': weightedAvg(
          oldRow['jaggedness'] as double? ?? 0.0,
          newFeature.jaggedness,
          oldCount,
        ),
        'top_third_density': weightedAvg(
          oldRow['top_third_density'] as double? ?? 0.0,
          newFeature.topThirdDensity,
          oldCount,
        ),
        'bilateral_sym': weightedAvg(
          oldRow['bilateral_sym'] as double? ?? 0.0,
          newFeature.bilateralSym,
          oldCount,
        ),
        'vertical_bias': weightedAvg(
          oldRow['vertical_bias'] as double? ?? 0.5,
          newFeature.verticalBias,
          oldCount,
        ),
        'top_heavy_bias': weightedAvg(
          oldRow['top_heavy_bias'] as double? ?? 0.5,
          newFeature.topHeavyBias,
          oldCount,
        ),
        'hue_complexity': weightedAvg(
          oldRow['hue_complexity'] as double? ?? 0.0,
          newFeature.hueComplexity,
          oldCount,
        ),
        'compactness': weightedAvg(
          oldRow['compactness'] as double? ?? 1.0,
          newFeature.compactness,
          oldCount,
        ),
        'limb_density': weightedAvg(
          oldRow['limb_density'] as double? ?? 0.0,
          newFeature.limbDensity,
          oldCount,
        ),
        'directional_edge_bias': weightedAvg(
          oldRow['directional_edge_bias'] as double? ?? 0.0,
          newFeature.directionalEdgeBias,
          oldCount,
        ),
      };

      final oldHueBins = Map<String, double>.from(
        jsonDecode(oldRow['hue_bins'] as String),
      );
      final newHueBins = newFeature.hueBins;
      final mergedHueBins = <String, double>{};
      for (final key in {...oldHueBins.keys, ...newHueBins.keys}) {
        mergedHueBins[key] = weightedAvg(
          oldHueBins[key] ?? 0,
          newHueBins[key] ?? 0,
          oldCount,
        );
      }

      Map<String, double>? mergedSpatialBins;
      if (oldRow['spatial_hue_bins'] != null) {
        final oldSpatial = Map<String, double>.from(
          jsonDecode(oldRow['spatial_hue_bins'] as String),
        );
        final newSpatial = newFeature.spatialHueBins ?? {};
        mergedSpatialBins = <String, double>{};
        for (final key in {...oldSpatial.keys, ...newSpatial.keys}) {
          mergedSpatialBins[key] = weightedAvg(
            oldSpatial[key] ?? 0,
            newSpatial[key] ?? 0,
            oldCount,
          );
        }
      }

      await _db!.update(
        'organism_features',
        {
          'hue_bins': jsonEncode(mergedHueBins),
          if (mergedSpatialBins != null)
            'spatial_hue_bins': jsonEncode(mergedSpatialBins),
          'dominant_colors': jsonEncode(
            newFeature.dominantColors.map((c) => c.toARGB32()).toList(),
          ),
          ...mergedData,
          'animal_class': ?effectiveClass,
          'training_count': newCount,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'organism_name = ?',
        whereArgs: [organismName],
      );
    } else {
      await _db!.insert('organism_features', {
        'organism_name': organismName,
        'scientific_name': scientificName,
        'hue_bins': jsonEncode(newFeature.hueBins),
        'spatial_hue_bins': jsonEncode(newFeature.spatialHueBins),
        'dominant_colors': jsonEncode(
          newFeature.dominantColors.map((c) => c.toARGB32()).toList(),
        ),
        'avg_brightness': newFeature.avgBrightness,
        'avg_saturation': newFeature.avgSaturation,
        'aspect_ratio': newFeature.aspectRatio,
        'solidity': newFeature.solidity,
        'vertical_symmetry': newFeature.verticalSymmetry,
        'horizontal_symmetry': newFeature.horizontalSymmetry,
        'edge_density': newFeature.edgeDensity,
        'core_solidity': newFeature.coreSolidity,
        'bottom_heavy_bias': newFeature.bottomHeavyBias,
        'max_width_row_bias': newFeature.maxWidthRowBias,
        'max_height_col_bias': newFeature.maxHeightColBias,
        'bottom_center_density': newFeature.bottomCenterDensity,
        'corner_density': newFeature.cornerDensity,
        'diagonal_density': newFeature.diagonalDensity,
        'lower_quadrant_symmetry': newFeature.lowerQuadrantSymmetry,
        'horizontal_centroid_shift': newFeature.horizontalCentroidShift,
        'convex_hull_ratio': newFeature.convexHullRatio,
        'vertical_mass_distribution': newFeature.verticalMassDistribution,
        'color_granularity': newFeature.colorGranularity,
        'fringe_density': newFeature.fringeDensity,
        'vertical_thinning': newFeature.verticalThinning,
        'local_symmetry': newFeature.localSymmetry,
        'color_clustering': newFeature.colorClustering,
        'y_gradient': newFeature.yGradient,
        'width_variance': newFeature.widthVariance,
        'shell_index': newFeature.shellIndex,
        'radial_overlap': newFeature.radialOverlap,
        'y_centroid': newFeature.yCentroid,
        'jaggedness': newFeature.jaggedness,
        'top_third_density': newFeature.topThirdDensity,
        'bilateral_sym': newFeature.bilateralSym,
        'vertical_bias': newFeature.verticalBias,
        'top_heavy_bias': newFeature.topHeavyBias,
        'hue_complexity': newFeature.hueComplexity,
        'compactness': newFeature.compactness,
        'limb_density': newFeature.limbDensity,
        'directional_edge_bias': newFeature.directionalEdgeBias,
        'animal_class': effectiveClass,
        'training_count': 1,
      });
    }
  }

  /// Save a taxonomic profile to the database.
  Future<void> saveTaxonomyProfile({
    required String animalClass,
    required Map<String, double> means,
    required Map<String, double> variances,
    required int count,
  }) async {
    if (_db == null) return;
    await _db!.insert('taxonomy_profiles', {
      'animal_class': animalClass,
      'feature_means': jsonEncode(means),
      'feature_variances': jsonEncode(variances),
      'sample_count': count,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get all taxonomic profiles from the database.
  Future<List<Map<String, dynamic>>> getAllTaxonomyProfiles() async {
    if (_db == null) return [];
    final results = await _db!.query('taxonomy_profiles');
    return results
        .map(
          (r) => {
            'class': r['animal_class'] as String,
            'means': Map<String, double>.from(
              jsonDecode(r['feature_means'] as String),
            ),
            'variances': Map<String, double>.from(
              jsonDecode(r['feature_variances'] as String),
            ),
            'count': r['sample_count'] as int,
          },
        )
        .toList();
  }

  /// Get taxonomy metadata from the database.
  Future<Map<String, dynamic>?> getTaxonomyMetadata(String key) async {
    if (_db == null) return null;
    final results = await _db!.query(
      'taxonomy_metadata',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (results.isEmpty) return null;
    return jsonDecode(results.first['data'] as String) as Map<String, dynamic>;
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _isInitialized = false;
  }
}
