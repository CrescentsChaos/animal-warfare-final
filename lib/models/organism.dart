// lib/models/organism.dart
import 'package:flutter/material.dart';

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

  // FIX: Added the missing toJson method for JSON serialization.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'scientific_name': scientificName, 
      'habitat': habitat,
      'drops': drops,
      'attack': attack,
      'defense': defense,
      'health': health,
      'speed': speed,
      'abilities': abilities,
      'category': category,
      'moves': moves,
      'sprite': sprite,
      'rarity': rarity,
      'description': description,
    };
  }
}


/// A utility function to display a network image as a solid-colored silhouette.
Widget buildSilhouetteSprite({
  required String imageUrl,
  required Color silhouetteColor,
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
}) {
  return ColorFiltered(
    // The ColorFilter.mode constructor is used to blend a single color 
    // with the child widget (your image).
    colorFilter: ColorFilter.mode(
      silhouetteColor,
      // BlendMode.srcIn uses the alpha channel of the image (the source) 
      // and replaces the color with the filter color, creating a perfect silhouette.
      BlendMode.srcIn,
    ),
    child: Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      // You can add a loadingBuilder and errorBuilder here for better UX
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            color: silhouetteColor,
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: Colors.grey.shade800,
        child: const Icon(Icons.broken_image, color: Colors.white),
      ),
    ),
  );
}