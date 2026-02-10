// lib/models/recipe.dart
import 'package:animal_warfare/models/loot_item.dart';
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
      requiredLoot: {
        'hide': 3,
        'horn': 2,
        'fang': 1,
      },
    ),
    Recipe(
      id: 'recipe_iron_ward',
      resultTalismanId: 'iron_ward',
      requiredLoot: {
        'scale': 4,
        'shell': 2,
      },
    ),
    Recipe(
      id: 'recipe_swift_rune',
      resultTalismanId: 'swift_rune',
      requiredLoot: {
        'feather': 5,
        'claw': 2,
        'antler': 1,
      },
    ),
    Recipe(
      id: 'recipe_vitality_stone',
      resultTalismanId: 'vitality_stone',
      requiredLoot: {
        'shell': 3,
        'scale': 3,
        'pearl': 1,
      },
    ),
    Recipe(
      id: 'recipe_power_crystal',
      resultTalismanId: 'power_crystal',
      requiredLoot: {
        'fang': 4,
        'claw': 3,
        'venom_sac': 2,
      },
    ),
    Recipe(
      id: 'recipe_guardian_shell',
      resultTalismanId: 'guardian_shell',
      requiredLoot: {
        'shell': 5,
        'scale': 4,
      },
    ),
    Recipe(
      id: 'recipe_lucky_claw',
      resultTalismanId: 'lucky_claw',
      requiredLoot: {
        'claw': 5,
        'feather': 3,
        'pearl': 1,
      },
    ),
  ];

  static Recipe? findById(String id) {
    try {
      return allRecipes.firstWhere((recipe) => recipe.id == id);
    } catch (e) {
      return null;
    }
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
