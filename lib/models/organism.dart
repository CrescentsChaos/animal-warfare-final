// lib/models/organism.dart
import 'package:flutter/material.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/loot_item.dart';
import 'dart:math';

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
  final List<String> types; // NEW: Supports multiple types

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
    this.types = const ['normal'], // Default
  });

  factory Organism.fromJson(Map<String, dynamic> json) {
    // Handle 'types' being a list of strings or a comma-separated string or null
    var typeList = <String>[];
    if (json['types'] is List) {
      typeList = List<String>.from(json['types']);
    } else if (json['types'] is String) {
       typeList = (json['types'] as String).split(',').map((e) => e.trim()).toList();
    } else {
      // Fallback: default to normal
      typeList = ['normal']; 
    }

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
      rarity: json['rarity'] as String? ?? 'Common',
      description: json['description'] as String? ?? '',
      types: typeList,
    );
  }

  /// Parse drops field (e.g., "hide, horn") into LootDrops with chances
  List<LootDrop> get lootDrops {
    if (drops.isEmpty) return [];
    
    final dropsList = drops.split(',').map((e) => e.trim().toLowerCase()).toList();
    final lootDropsList = <LootDrop>[];
    
    for (final dropName in dropsList) {
      // Map common drop names to loot IDs
      String? lootId;
      if (dropName.contains('hide') || dropName.contains('fur')) {
        lootId = 'hide';
      } else if (dropName.contains('horn')) {
        lootId = 'horn';
      } else if (dropName.contains('feather')) {
        lootId = 'feather';
      } else if (dropName.contains('fang') || dropName.contains('tooth')) {
        lootId = 'fang';
      } else if (dropName.contains('claw')) {
        lootId = 'claw';
      } else if (dropName.contains('scale')) {
        lootId = 'scale';
      } else if (dropName.contains('shell')) {
        lootId = 'shell';
      } else if (dropName.contains('venom')) {
        lootId = 'venom_sac';
      } else if (dropName.contains('antler')) {
        lootId = 'antler';
      } else if (dropName.contains('pearl')) {
        lootId = 'pearl';
      }
      
      if (lootId != null) {
        // Drop chance based on rarity: Common 60%, Uncommon 40%, Rare 25%, Epic 15%
        double chance = 0.6;
        if (rarity.toLowerCase().contains('uncommon')) chance = 0.4;
        if (rarity.toLowerCase().contains('rare')) chance = 0.25;
        if (rarity.toLowerCase().contains('epic') || rarity.toLowerCase().contains('legendary')) chance = 0.15;
        
        lootDropsList.add(LootDrop(lootId: lootId, dropChance: chance));
      }
    }
    
    return lootDropsList;
  }
  
  /// Roll for a random loot drop from this organism
  String? rollLootDrop() {
    final drops = lootDrops;
    if (drops.isEmpty) return null;
    
    final random = Random();
    for (final drop in drops) {
      if (random.nextDouble() < drop.dropChance) {
        return drop.lootId;
      }
    }
    return null; // No drop
  }
  Organism copyWith({
    String? name,
    String? scientificName,
    String? habitat,
    String? drops,
    int? attack,
    int? defense,
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
    return types.map((t) {
      return ElementalType.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == t.toLowerCase(),
        orElse: () => ElementalType.normal,
      );
    }).toList();
  }
}


/// A utility function to display an image (from network OR asset) as a solid-colored silhouette.
Widget buildSilhouetteSprite({
  required String imageUrl,
  required Color silhouetteColor,
  // Added optional organismName, though the path determination is done by the caller.
  String? organismName, 
  double? width,
  double? height,
  BoxFit fit = BoxFit.contain,
}) {
  
  // NEW LOGIC: Determine if the image should be loaded from a network or local asset
  final isNetworkImage = imageUrl.startsWith('http') || imageUrl.startsWith('https');

  // Common error widget
  final errorWidget = Container(
    width: width,
    height: height,
    color: Colors.grey.shade800,
    child: const Icon(Icons.broken_image, color: Colors.white),
  );

  // Function to create the base Image widget (either network or asset)
  Widget createImageWidget() {
    if (isNetworkImage) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        // Loading builder for network images
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
        errorBuilder: (context, error, stackTrace) => errorWidget,
      );
    } else {
      // Use Image.asset for local files (like 'assets/sprites/...')
      return Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        // Use the error builder to handle cases where the local asset path is incorrect/missing
        errorBuilder: (context, error, stackTrace) => errorWidget,
      );
    }
  }

  // Apply the ColorFilter to the resulting Image widget
  return ColorFiltered(
    // The ColorFilter.mode constructor is used to blend a single color 
    // with the child widget (your image).
    colorFilter: ColorFilter.mode(
      silhouetteColor,
      // BlendMode.srcIn uses the alpha channel of the image (the source) 
      // and replaces the color with the filter color, creating a perfect silhouette.
      BlendMode.srcIn,
    ),
    child: createImageWidget(),
  );
}