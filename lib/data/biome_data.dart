import 'package:flutter/material.dart';

/// Central registry for biome metadata.
/// Add new biomes here — UI screens stay "dumb" and data-driven.
class BiomeData {
  BiomeData._();

  /// Maps a biome name (case-insensitive) to its theme colour.
  static const Map<String, Color> _colorMap = {
    'volcano': Colors.redAccent,
    'cave': Colors.blueGrey,
    'coastal': Colors.yellowAccent,
    'coral reef': Colors.pinkAccent,
    'deep sea': Colors.indigoAccent,
    'frozen ocean': Color(0xFFB3E5FC), // Colors.lightBlue[100]
    'kelp forest': Colors.tealAccent,
    'swamp': Colors.purpleAccent,
    'lake': Colors.blueAccent,
    'mangrove': Color(0xFF8D6E63), // Colors.brown[400]
    'polar': Colors.white,
    'rainforest': Colors.greenAccent,
    'taiga': Color(0xFF80DEEA), // Colors.cyan[200]
    'tundra': Color(0xFFB0BEC5), // Colors.blueGrey[100]
    'urban': Colors.grey,
    'jungle': Colors.lightGreenAccent,
    'desert': Colors.orangeAccent,
    'savanna': Colors.orange,
    'river': Colors.cyanAccent,
    'ocean': Colors.blue,
    'mountain': Color(0xFFBDBDBD), // Colors.grey[300]
    'redwoods': Color(0xFF5D4037), // deep bark brown
    'plains': Color(0xFFD4A94B), // warm golden
    'wetlands': Color(0xFF6B7B3A), // muddy olive
  };

  /// Returns the theme [Color] for [biome], falling back to [Colors.white].
  static Color colorFor(String biome) =>
      _colorMap[biome.toLowerCase()] ?? Colors.white;

  /// All known biome names (display-cased).
  static const List<String> allBiomes = [
    'Volcano',
    'Cave',
    'Coastal',
    'Coral Reef',
    'Deep Sea',
    'Frozen Ocean',
    'Kelp Forest',
    'Swamp',
    'Lake',
    'Mangrove',
    'Polar',
    'Rainforest',
    'Taiga',
    'Tundra',
    'Urban',
    'Jungle',
    'Desert',
    'Savanna',
    'River',
    'Ocean',
    'Mountain',
    'Redwoods',
    'Plains',
    'Wetlands',
  ];
}
