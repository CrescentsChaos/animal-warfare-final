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
        debugPrint('FeatureDbService: Updated local DB from bundled asset at $dbPath');
      } catch (e) {
        if (!File(dbPath).existsSync()) {
          debugPrint('FeatureDbService: No bundled DB found and no local DB exists: $e');
        }
      }
    }

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );

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
        updated_at TEXT NOT NULL DEFAULT (datetime('now')),
        training_count INTEGER NOT NULL DEFAULT 1
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_scientific_name ON organism_features(scientific_name)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_organism_name ON organism_features(organism_name)');
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
    final result =
        await _db!.rawQuery('SELECT COUNT(*) as count FROM organism_features');
    if (result.isEmpty) return 0;
    return (result.first['count'] as int?) ?? 0;
  }

  /// Convert a database row to an OrganismFeature.
  OrganismFeature _featureFromRow(Map<String, dynamic> row) {
    final hueBins =
        Map<String, double>.from(jsonDecode(row['hue_bins'] as String));

    final spatialHueBins = row['spatial_hue_bins'] != null
        ? Map<String, double>.from(
            jsonDecode(row['spatial_hue_bins'] as String))
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
    );
  }

  /// Upsert a newly trained feature. Averages with existing using training_count.
  Future<void> upsertTrainedFeature({
    required String scientificName,
    required OrganismFeature newFeature,
  }) async {
    if (_db == null) return;
    
    final organismName = newFeature.organismName;

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
            oldCount),
        'avg_saturation': weightedAvg(
            oldRow['avg_saturation'] as double,
            newFeature.avgSaturation,
            oldCount),
        'aspect_ratio': weightedAvg(
            oldRow['aspect_ratio'] as double,
            newFeature.aspectRatio,
            oldCount),
        'solidity': weightedAvg(oldRow['solidity'] as double,
            newFeature.solidity, oldCount),
        'vertical_symmetry': weightedAvg(
            oldRow['vertical_symmetry'] as double,
            newFeature.verticalSymmetry,
            oldCount),
        'horizontal_symmetry': weightedAvg(
            oldRow['horizontal_symmetry'] as double,
            newFeature.horizontalSymmetry,
            oldCount),
        'edge_density': weightedAvg(
            oldRow['edge_density'] as double,
            newFeature.edgeDensity,
            oldCount),
      };

      final oldHueBins =
          Map<String, double>.from(jsonDecode(oldRow['hue_bins'] as String));
      final newHueBins = newFeature.hueBins;
      final mergedHueBins = <String, double>{};
      for (final key in {...oldHueBins.keys, ...newHueBins.keys}) {
        mergedHueBins[key] = weightedAvg(
            oldHueBins[key] ?? 0, newHueBins[key] ?? 0, oldCount);
      }

      Map<String, double>? mergedSpatialBins;
      if (oldRow['spatial_hue_bins'] != null) {
        final oldSpatial = Map<String, double>.from(
            jsonDecode(oldRow['spatial_hue_bins'] as String));
        final newSpatial = newFeature.spatialHueBins ?? {};
        mergedSpatialBins = <String, double>{};
        for (final key in {...oldSpatial.keys, ...newSpatial.keys}) {
          mergedSpatialBins[key] = weightedAvg(
              oldSpatial[key] ?? 0, newSpatial[key] ?? 0, oldCount);
        }
      }

      await _db!.update(
        'organism_features',
        {
          'hue_bins': jsonEncode(mergedHueBins),
          if (mergedSpatialBins != null)
            'spatial_hue_bins': jsonEncode(mergedSpatialBins),
          'dominant_colors': jsonEncode(newFeature.dominantColors.map((c) => c.value).toList()),
          ...mergedData,
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
        'dominant_colors': jsonEncode(newFeature.dominantColors.map((c) => c.value).toList()),
        'avg_brightness': newFeature.avgBrightness,
        'avg_saturation': newFeature.avgSaturation,
        'aspect_ratio': newFeature.aspectRatio,
        'solidity': newFeature.solidity,
        'vertical_symmetry': newFeature.verticalSymmetry,
        'horizontal_symmetry': newFeature.horizontalSymmetry,
        'edge_density': newFeature.edgeDensity,
        'training_count': 1,
      });
    }
  }

  /// Close the database.
  Future<void> close() async {
    await _db?.close();
    _db = null;
    _isInitialized = false;
  }
}
