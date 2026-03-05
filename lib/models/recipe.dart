import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/models/talisman.dart';

class Recipe {
  final String id;
  final String resultTalismanId;
  final Map<String, int> requiredLoot; // loot_id -> quantity

  const Recipe({
    required this.id,
    required this.resultTalismanId,
    required this.requiredLoot,
  });

  Talisman? get resultTalisman => Talisman.findById(resultTalismanId);

  // Constructor for loading Recipe from JSON
  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String? ?? '',
      resultTalismanId: json['resultTalismanId'] as String? ?? '',
      requiredLoot:
          (json['requiredLoot'] as Map<String, dynamic>?)?.map(
            (key, value) => MapEntry(key, value as int),
          ) ??
          {},
    );
  }

  static List<Recipe> _allRecipes = [];

  static List<Recipe> get allRecipes => _allRecipes;

  static final Map<String, Recipe> _byId = {};

  /// Loads recipes from the JSON asset file.
  static Future<void> loadFromJson() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/recipes.json',
      );
      final data = json.decode(response);
      if (data is List) {
        _allRecipes = data
            .map((r) => Recipe.fromJson(r as Map<String, dynamic>))
            .toList();
        _byId.clear();
        for (final r in _allRecipes) {
          _byId[r.id] = r;
        }
        print('Loaded ${_allRecipes.length} recipes from JSON.');
      }
    } catch (e) {
      print('Error loading recipes from JSON: $e');
    }
  }

  static Recipe? findById(String id) {
    return _byId[id];
  }

  /// Check if player has enough materials to craft this recipe
  bool canCraft(Map<String, int> inventory) {
    for (final entry in requiredLoot.entries) {
      final required = entry.value;
      final owned = inventory[entry.key] ?? 0;
      if (owned < required) return false;
    }
    return true;
  }

  /// Get missing materials for display
  Map<String, int> getMissingMaterials(Map<String, int> inventory) {
    final missing = <String, int>{};
    for (final entry in requiredLoot.entries) {
      final required = entry.value;
      final owned = inventory[entry.key] ?? 0;
      if (owned < required) {
        missing[entry.key] = required - owned;
      }
    }
    return missing;
  }
}
