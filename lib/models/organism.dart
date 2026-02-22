// lib/models/organism.dart
import 'package:animal_warfare/models/elemental_type.dart';
import 'dart:math';

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
      name: (json['name'] ?? 'Unknown') as String,
      scientificName: (json['scientific_name'] ?? 'Unknown') as String,
      habitat: (json['habitat'] ?? 'Unknown') as String,
      drops: (json['drops'] ?? '') as String,
      attack: (json['attack'] as int? ?? 10),
      defense: (json['defense'] as int? ?? 10),
      power: (json['power'] as int? ?? 10),
      resistance: (json['resistance'] as int? ?? 10),
      health: (json['health'] as int? ?? 50),
      speed: (json['speed'] as int? ?? 10),
      abilities: (json['abilities'] ?? '') as String,
      category: (json['category'] ?? '') as String,
      moves: (json['moves'] ?? '') as String,
      sprite: (json['sprite'] ?? '') as String,
      rarity: (json['rarity'] as String? ?? 'Common'),
      description: (json['description'] as String? ?? ''),
      types: typeList,
    );
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
    };
  }

  // Helper to convert String types to Enum
  List<ElementalType> get elementalTypes {
    return types.map((t) => ElementalTypeX.fromString(t)).toList();
  }
}
