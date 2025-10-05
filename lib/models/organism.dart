// lib/models/organism.dart

class Organism {
  final String name;
  final String scientificName;
  final String habitat;
  final String drops;
  final int attack;
  final int defense;
  final int health;
  final int speed;
  final String abilities;
  final String category;
  final String moves;
  final String sprite;
  final String rarity;
  final String description;

  Organism({
    required this.name,
    required this.scientificName,
    required this.habitat,
    required this.drops,
    required this.attack,
    required this.defense,
    required this.health,
    required this.speed,
    required this.abilities,
    required this.category,
    required this.moves,
    required this.sprite,
    required this.rarity,
    required this.description,
  });

  factory Organism.fromJson(Map<String, dynamic> json) {
    return Organism(
      name: json['name'] as String,
      scientificName: json['scientific_name'] as String, 
      habitat: json['habitat'] as String,
      drops: json['drops'] as String,
      attack: json['attack'] as int,
      defense: json['defense'] as int,
      health: json['health'] as int,
      speed: json['speed'] as int,
      abilities: json['abilities'] as String,
      category: json['category'] as String,
      moves: json['moves'] as String,
      sprite: json['sprite'] as String,
      rarity: json['rarity'] as String,
      description: json['description'] as String,
    );
  }
}