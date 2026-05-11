// lib/models/organism.dart
import 'package:animal_warfare/models/elemental_type.dart';
import 'dart:math';

enum AnimalClass {
  mammal,
  bird,
  fish,
  amphibian,
  reptile,
  insect,
  invertebrate,
  unknown,
}

class Organism {
  final String name;
  final String scientificName;
  final String habitat;
  final String drops;
  final int attack;
  final int defense;
  final int power; // NEW: Special Attack
  final int resistance; // NEW: Special Defense
  final int health;
  final int speed;
  final String abilities;
  final String category;
  final String moves;
  final String sprite;
  final String rarity;
  final String description;
  final List<String> types; // NEW: Supports multiple types
  final double weight; // NEW: Weight in kg
  final String activeTime; // NEW: Spawning time (any, day, night)
  final String cry; // NEW: Audio file for name for cry
  final String
  spawnTiles; // NEW: Spawning tiles (comma-separated, e.g., "tall_grass,water,any")
  final String
  pheno; // NEW: Overworld sprite prefix (e.g., "giant_water_bug"), or "none"
  final String animalClass; // NEW: Taxonomic class (mammal, bird, etc.)
  final String diet; // NEW: Diet (carnivore, herbivore, etc.)

  Organism({
    required this.name,
    required this.scientificName,
    required this.habitat,
    required this.drops,
    required this.attack,
    required this.defense,
    required this.power,
    required this.resistance,
    required this.health,
    required this.speed,
    required this.abilities,
    required this.category,
    required this.moves,
    required this.sprite,
    required this.rarity,
    required this.description,
    this.types = const ['basic'], // Default
    this.weight = 1.0, // Default 1.0 kg
    this.activeTime = 'any', // Default
    this.cry = 'default', // Default
    this.spawnTiles = 'any', // Default
    this.pheno = 'none', // Default
    this.animalClass = 'unknown', // Default
    this.diet = 'unknown', // Default
  });

  factory Organism.fromJson(Map<String, dynamic> json) {
    // Handle 'types' being a list of strings or a comma-separated string or null
    var typeList = <String>[];
    if (json['types'] is List) {
      typeList = List<String>.from(json['types']);
    } else if (json['types'] is String) {
      typeList = (json['types'] as String)
          .split(',')
          .map((e) => e.trim())
          .toList();
    }

    // FALLBACK: Use 'category' if types is still empty
    if (typeList.isEmpty && json['category'] is String) {
      typeList = (json['category'] as String)
          .split(',')
          .map((e) => e.trim())
          .toList();
    }

    if (typeList.isEmpty) {
      // Final Fallback: always have at least 'basic'
      typeList = ['basic'];
    }

    return Organism(
      name: (json['name'] ?? 'Unknown').toString(),
      scientificName: (json['scientific_name'] ?? 'Unknown').toString(),
      habitat: (json['habitat'] ?? 'Unknown').toString(),
      drops: (json['drops'] ?? '').toString(),
      attack: (json['attack'] as num? ?? 10).toInt(),
      defense: (json['defense'] as num? ?? 10).toInt(),
      power: (json['power'] as num? ?? 10).toInt(),
      resistance: (json['resistance'] as num? ?? 10).toInt(),
      health: (json['health'] as num? ?? 50).toInt(),
      speed: (json['speed'] as num? ?? 10).toInt(),
      abilities: (json['abilities'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      moves: (json['moves'] ?? '').toString(),
      sprite: (json['sprite'] ?? '').toString(),
      rarity: (json['rarity']?.toString() ?? 'Common'),
      description: (json['description']?.toString() ?? ''),
      types: typeList,
      weight: _parseWeight(json['weight']),
      activeTime: (json['active_time']?.toString() ?? 'any'),
      cry: (json['cry']?.toString() ?? 'default'),
      spawnTiles: (json['spawn_tiles']?.toString() ?? 'any'),
      pheno: (json['pheno']?.toString() ?? 'none'),
      animalClass:
          (json['class'] ?? json['animal_class'])?.toString() ?? 'unknown',
      diet: (json['diet']?.toString() ?? 'unknown'),
    );
  }

  String get formattedWeight {
    if (weight < 0.0001) {
      // For very small weights (like microbes), use scientific or fixed with many decimals
      // but let's just use a clean string representation.
      return weight
          .toStringAsFixed(12)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    // For normal weights, if it's a whole number, show it as such
    if (weight == weight.toInt().toDouble()) {
      return weight.toInt().toString();
    }
    return weight.toString();
  }

  static double _parseWeight(dynamic value) {
    if (value == null) return 1.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      // Remove commas and try to parse
      final cleaned = value.replaceAll(',', '');
      return double.tryParse(cleaned) ?? 1.0;
    }
    return 1.0;
  }

  /// Roll for a random loot drop directly from the JSON field.
  /// Returns a Title Case string (e.g., "Fur", "Meat").
  String? rollLootDrop() {
    if (drops.isEmpty) return null;

    final dropsList = drops
        .split(',')
        .map((e) {
          final trimmed = e.trim();
          if (trimmed.isEmpty) return '';
          // Simple Title Case: capitalize first letter, lowercase rest
          return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
        })
        .where((e) => e.isNotEmpty)
        .toList();

    if (dropsList.isEmpty) return null;

    // Pick one at random
    return dropsList[Random().nextInt(dropsList.length)];
  }

  Organism copyWith({
    String? name,
    String? scientificName,
    String? habitat,
    String? drops,
    int? attack,
    int? defense,
    int? power,
    int? resistance,
    int? health,
    int? speed,
    String? abilities,
    String? category,
    String? moves,
    String? sprite,
    String? rarity,
    String? description,
    List<String>? types,
    double? weight,
    String? activeTime,
    String? cry,
    String? spawnTiles,
    String? pheno,
    String? animalClass,
    String? diet,
  }) {
    return Organism(
      name: name ?? this.name,
      scientificName: scientificName ?? this.scientificName,
      habitat: habitat ?? this.habitat,
      drops: drops ?? this.drops,
      attack: attack ?? this.attack,
      defense: defense ?? this.defense,
      power: power ?? this.power,
      resistance: resistance ?? this.resistance,
      health: health ?? this.health,
      speed: speed ?? this.speed,
      abilities: abilities ?? this.abilities,
      category: category ?? this.category,
      moves: moves ?? this.moves,
      sprite: sprite ?? this.sprite,
      rarity: rarity ?? this.rarity,
      description: description ?? this.description,
      types: types ?? this.types,
      weight: weight ?? this.weight,
      activeTime: activeTime ?? this.activeTime,
      cry: cry ?? this.cry,
      spawnTiles: spawnTiles ?? this.spawnTiles,
      pheno: pheno ?? this.pheno,
      animalClass: animalClass ?? this.animalClass,
      diet: diet ?? this.diet,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'scientific_name': scientificName,
      'habitat': habitat,
      'drops': drops,
      'attack': attack,
      'defense': defense,
      'power': power,
      'resistance': resistance,
      'health': health,
      'speed': speed,
      'abilities': abilities,
      'category': category,
      'moves': moves,
      'sprite': sprite,
      'rarity': rarity,
      'description': description,
      'types': types,
      'weight': weight,
      'active_time': activeTime,
      'cry': cry,
      'spawn_tiles': spawnTiles,
      'pheno': pheno,
      'class': animalClass,
      'diet': diet,
    };
  }

  // Helper to convert String types to Enum
  List<ElementalType> get elementalTypes {
    return types.map((t) => ElementalTypeX.fromString(t)).toList();
  }

  /// Returns the name of the stat with the highest base value.
  /// Used by the KV system to determine which KV to award on kill.
  String get highestBaseStat {
    final stats = {
      'health': health,
      'attack': attack,
      'defense': defense,
      'power': power,
      'resistance': resistance,
      'speed': speed,
    };
    return stats.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  /// Returns the Base Stat Total (BST).
  int get bst => health + attack + defense + power + resistance + speed;

  /// Returns KV yield based on rarity.
  static int kvYield(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 1;
      case 'uncommon':
        return 2;
      case 'rare':
        return 3;
      case 'epic':
        return 5;
      case 'legendary':
        return 8;
      case 'mythical':
        return 12;
      default:
        return 1;
    }
  }

  static final Organism humanOrganism = Organism(
    name: 'Human',
    scientificName: 'Homo sapiens',
    habitat: 'Everywhere',
    drops: 'N/A',
    attack: 100,
    defense: 100,
    power: 0,
    resistance: 100,
    health: 100,
    speed: 50,
    abilities: 'None',
    category: 'Human',
    moves: 'Punch, Kick, Uppercut, Jab',
    sprite: 'https://i.imgur.com/your_human_sprite.png',
    rarity: 'Common',
    description: 'The dominant species.',
    weight: 70.0,
    activeTime: 'any',
    cry: 'default',
    spawnTiles: 'any',
    animalClass: 'mammal',
    diet: 'omnivore',
  );

  static final Organism trainingDummy = Organism(
    name: 'Training Dummy',
    scientificName: 'Testus Dumbo',
    habitat: 'AW Labs',
    drops: 'N/A',
    attack: 0,
    defense: 100,
    power: 0,
    resistance: 100,
    health: 9999,
    speed: 0,
    abilities: 'Neutralizing Gas,Inner Focus',
    category: 'Dummy',
    moves: 'Splash',
    sprite:
        'assets/overworld/scarecrow.png', // Using an existing overworld asset as dummy sprite
    rarity: 'Common',
    description:
        'A sturdy straw dummy designed for training. It does not attack.',
    weight: 100.0,
    activeTime: 'any',
    cry: 'default',
    spawnTiles: 'any',
    animalClass: 'unknown',
    diet: 'unknown',
  );
}
