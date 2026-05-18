// lib/models/organism.dart
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'dart:math';

enum AnimalClass {
  mammal,
  bird,
  reptile,
  amphibian,
  fish,
  insect,
  arachnid,
  crustacean,
  mollusk,
  annelid,
  cnidarian,
  echinoderm,
  otherInvertebrate,
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
  final double size; // NEW: Size in meters

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
    this.size = 1.0, // Default 1.0 m
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
      size: (json['size'] as num? ?? 1.0).toDouble(),
    );
  }

  String get formattedWeight {
    if (weight < 0.0001) {
      return weight
          .toStringAsFixed(12)
          .replaceAll(RegExp(r'0+$'), '')
          .replaceAll(RegExp(r'\.$'), '');
    }
    if (weight == weight.toInt().toDouble()) {
      return weight.toInt().toString();
    }
    return weight.toString();
  }

  int get bst => health + attack + defense + power + resistance + speed;

  double get robustness => weight / (size > 0 ? size : 1);

  String get formattedRobustness {
    return "${robustness.toStringAsFixed(2).replaceAll(RegExp(r'\.00$'), '')} λ";
  }

  String get formattedSize {
    if (size == size.toInt().toDouble()) {
      return size.toInt().toString();
    }
    return size.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  }

  String formattedWeightForSystem(String unitSystem) {
    if (unitSystem == 'imperial') {
      final lbs = weight * 2.20462;
      return "${lbs.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} LBS";
    }
    // Metric scaling
    if (weight >= 1000) {
      return "${(weight / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} TONS";
    } else if (weight >= 1) {
      return "$formattedWeight KG";
    } else if (weight >= 0.001) {
      return "${(weight * 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} G";
    } else if (weight >= 0.000001) {
      return "${(weight * 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} MG";
    } else if (weight >= 0.000000001) {
      return "${(weight * 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} UG";
    } else {
      return "${(weight * 1000000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} NG";
    }
  }

  String formattedSizeForSystem(String unitSystem) {
    if (unitSystem == 'imperial') {
      final totalInches = size * 39.3701;
      final feet = (totalInches / 12).floor();
      final inches = (totalInches % 12).round();

      if (feet > 0) {
        if (inches == 0) return "$feet FT";
        return "$feet FT $inches IN";
      }
      return "$inches IN";
    }
    // Metric scaling
    if (size >= 1000) {
      return "${(size / 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} KM";
    } else if (size >= 1) {
      return "$formattedSize M";
    } else if (size >= 0.01) {
      return "${(size * 100).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} CM";
    } else if (size >= 0.001) {
      return "${(size * 1000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} MM";
    } else if (size >= 0.000001) {
      return "${(size * 1000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} UM";
    } else {
      return "${(size * 1000000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')} NM";
    }
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

  /// Roll for loot drops directly from the JSON field.
  /// Returns a map of item ID to count (e.g., {"raw_meat": 5, "ambergris": 1}).
  /// It considers drop chances defined in talismans.json and scales counts by weight, size, and level.
  Map<String, int> rollLootDrops(int level) {
    if (drops.isEmpty || drops.trim().toLowerCase() == 'n/a') return {};

    final dropsList = drops
        .split(',')
        .map((e) {
          final trimmed = e.trim();
          if (trimmed.isEmpty) return '';
          return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
        })
        .where((e) => e.isNotEmpty)
        .toList();

    if (dropsList.isEmpty) return {};

    final random = Random();
    final Map<String, int> finalDrops = {};

    int dropSlots = _calculateDropSlots(level);

    for (final dropName in dropsList) {
      final dropId = dropName.toLowerCase().replaceAll(' ', '_');
      final talisman = Talisman.findById(dropId) ?? Talisman.findByName(dropName);
      final double dropChance = talisman?.dropChance ?? 1.0; 
      
      final itemKey = talisman?.id ?? dropId;
      
      int countForThisItem = 0;
      for (int i = 0; i < dropSlots; i++) {
        if (random.nextDouble() <= dropChance) {
          countForThisItem++;
        }
      }
      
      if (countForThisItem > 0) {
        finalDrops[itemKey] = (finalDrops[itemKey] ?? 0) + countForThisItem;
      }
    }

    return finalDrops;
  }

  int _calculateDropSlots(int level) {
    double wLog = weight > 0 ? (log(weight) / ln10) : 0; 
    double sLog = size > 0 ? (log(size) / ln10) : 0;
    
    double wNormalized = wLog + 10;
    if (wNormalized < 0) wNormalized = 0;
    double sNormalized = sLog + 5;
    if (sNormalized < 0) sNormalized = 0;
    
    double metric = wNormalized + sNormalized; 
    double baseItems = 1.0 + (metric / 22.0) * 8.0; 
    double levelBonus = (level / 100.0) * 6.0;
    
    int finalCount = (baseItems + levelBonus).floor();
    if (finalCount < 1) finalCount = 1;
    if (finalCount > 20) finalCount = 20;
    return finalCount;
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
    double? size,
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
      size: size ?? this.size,
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
      'size': size,
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
    size: 1.7,
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
    size: 1.0,
  );
}
