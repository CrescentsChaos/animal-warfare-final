// lib/models/loot_item.dart

enum LootRarity {
  common,
  uncommon,
  rare,
  epic,
}

class LootDrop {
  final String lootId;
  final double dropChance; // 0.0 to 1.0

  const LootDrop({
    required this.lootId,
    required this.dropChance,
  });
}

class LootItem {
  final String id;
  final String name;
  final String description;
  final LootRarity rarity;

  const LootItem({
    required this.id,
    required this.name,
    required this.description,
    required this.rarity,
  });

  // Predefined loot items
  static const List<LootItem> allLoot = [
    // Common Materials
    LootItem(
      id: 'hide',
      name: 'Hide',
      description: 'Tough animal hide, useful for crafting.',
      rarity: LootRarity.common,
    ),
    LootItem(
      id: 'horn',
      name: 'Horn',
      description: 'Sharp horn from a defeated creature.',
      rarity: LootRarity.common,
    ),
    LootItem(
      id: 'feather',
      name: 'Feather',
      description: 'Soft feather from a bird.',
      rarity: LootRarity.common,
    ),
    LootItem(
      id: 'fang',
      name: 'Fang',
      description: 'Sharp fang from a predator.',
      rarity: LootRarity.common,
    ),
    LootItem(
      id: 'claw',
      name: 'Claw',
      description: 'Razor-sharp claw.',
      rarity: LootRarity.common,
    ),
    
    // Uncommon Materials
    LootItem(
      id: 'scale',
      name: 'Scale',
      description: 'Protective scale from a reptile.',
      rarity: LootRarity.uncommon,
    ),
    LootItem(
      id: 'shell',
      name: 'Shell',
      description: 'Sturdy shell fragment.',
      rarity: LootRarity.uncommon,
    ),
    LootItem(
      id: 'venom_sac',
      name: 'Venom Sac',
      description: 'Potent venom gland.',
      rarity: LootRarity.uncommon,
    ),
    
    // Rare Materials
    LootItem(
      id: 'antler',
      name: 'Antler',
      description: 'Majestic antler from a deer.',
      rarity: LootRarity.rare,
    ),
    LootItem(
      id: 'pearl',
      name: 'Pearl',
      description: 'Gleaming pearl from the ocean.',
      rarity: LootRarity.rare,
    ),
    
    // Epic Materials
    LootItem(
      id: 'dragon_scale',
      name: 'Dragon Scale',
      description: 'Legendary scale from a mythical beast.',
      rarity: LootRarity.epic,
    ),
  ];

  static LootItem? findById(String id) {
    try {
      return allLoot.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }

  String get rarityColor {
    switch (rarity) {
      case LootRarity.common:
        return '#CCCCCC';
      case LootRarity.uncommon:
        return '#4CAF50';
      case LootRarity.rare:
        return '#2196F3';
      case LootRarity.epic:
        return '#9C27B0';
    }
  }
}
