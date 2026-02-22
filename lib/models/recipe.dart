// lib/models/recipe.dart
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

  // Predefined recipes
  static const List<Recipe> allRecipes = [
    Recipe(
      id: 'recipe_strength_charm',
      resultTalismanId: 'strength_charm',
      requiredLoot: {'Fur': 3, 'Horn': 2, 'Fang': 1},
    ),
    Recipe(
      id: 'recipe_iron_ward',
      resultTalismanId: 'iron_ward',
      requiredLoot: {'Scales': 4, 'Shell': 2},
    ),
    Recipe(
      id: 'recipe_swift_rune',
      resultTalismanId: 'swift_rune',
      requiredLoot: {'Feather': 5, 'Claw': 2, 'Antler': 1},
    ),
    Recipe(
      id: 'recipe_vitality_stone',
      resultTalismanId: 'vitality_stone',
      requiredLoot: {'Shell': 3, 'Scales': 3, 'Pearl': 1},
    ),
    Recipe(
      id: 'recipe_power_crystal',
      resultTalismanId: 'power_crystal',
      requiredLoot: {'Fang': 4, 'Claw': 3, 'Venom': 2},
    ),
    Recipe(
      id: 'recipe_guardian_shell',
      resultTalismanId: 'guardian_shell',
      requiredLoot: {'Shell': 5, 'Scales': 4},
    ),
    Recipe(
      id: 'recipe_lucky_claw',
      resultTalismanId: 'lucky_claw',
      requiredLoot: {'Claw': 5, 'Feather': 3, 'Pearl': 1},
    ),
  ];

  static final Map<String, Recipe> _byId = {
    for (final r in allRecipes) r.id: r,
  };

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
