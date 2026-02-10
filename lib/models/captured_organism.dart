// lib/models/captured_organism.dart
import 'dart:math';
import 'organism.dart'; // Import the base model
import 'package:animal_warfare/models/talisman.dart';

// Represents an individual instance of a captured or wild organism.
// This is the model that holds the unique DNA (IVs).
class CapturedOrganism {
  final Organism baseOrganism;
  
  // Unique DNA/IVs: Individual Values (0-31 for each stat)
  // These are the "genes" that make this animal unique.
  final Map<String, int> individualValues; // 'health', 'attack', 'defense', 'speed'
  
  // Current Battle State
  int currentHealth;
  
  // Equipped Talisman
  Talisman? equippedTalisman;
  
  CapturedOrganism({
    required this.baseOrganism,
    required this.individualValues,
    required this.currentHealth,
    this.equippedTalisman,
  });

  // NEW: Convenience getter for the organism's name
  String get name => baseOrganism.name; 

  // --- DNA Generation and Stat Calculation ---
  
  // Maximum IV value (0 to 31)
  static const int maxIV = 31;
  // Stat formula constant (to ensure stats are meaningful)
  static const int statConstant = 10; 

  // Factory constructor for generating a new wild organism with random IVs
  factory CapturedOrganism.spawn(Organism base) {
    final rng = Random();
    final ivs = {
      'health': rng.nextInt(maxIV + 1), // 0 to 31
      'attack': rng.nextInt(maxIV + 1),
      'defense': rng.nextInt(maxIV + 1),
      'speed': rng.nextInt(maxIV + 1),
    };

    // Calculate initial max HP
    final maxHp = calculateStat('health', base.health, ivs['health']!);
    
    return CapturedOrganism(
      baseOrganism: base,
      individualValues: ivs,
      currentHealth: maxHp, // Starts with full health
    );
  }
  
  // Stat calculation formula: BaseStat + (IV / 2) + Constant
  // The 'IV/2' makes the IVs noticeable but not overwhelmingly dominant.
  static int calculateStat(String statName, int baseStat, int iv, {int level = 50}) {
    if (statName == 'health') {
      // HP Formula: (Base + IV/2) * 2 + Constant
      return (baseStat + (iv / 2).floor()) * 2 + statConstant; 
    }
    // Other Stats Formula: Base + IV/2 + Constant
    return baseStat + (iv / 2).floor() + statConstant;
  }

  // --- Getters for Effective Stats ---
  
  int get maxHealth => calculateStat(
    'health', 
    baseOrganism.health, 
    individualValues['health']!
  );
  
  int get effectiveAttack => calculateStat(
    'attack', 
    baseOrganism.attack, 
    individualValues['attack']!
  );
  
  int get effectiveDefense => calculateStat(
    'defense', 
    baseOrganism.defense, 
    individualValues['defense']!
  );
  
  int get effectiveSpeed => calculateStat(
    'speed', 
    baseOrganism.speed, 
    individualValues['speed']!
  );

  // --- Serialization for Storage ---

  Map<String, dynamic> toJson() => {
    // Only store the name and IVs, the base stats are looked up from the base Organism list
    'name': baseOrganism.name, 
    'ivs': individualValues,
    'currentHealth': currentHealth,
    'equippedTalisman': equippedTalisman?.toJson(),
  };
  
  /// Create CapturedOrganism from JSON
  static CapturedOrganism? fromJson(Map<String, dynamic> json, List<Organism> allOrganisms) {
    final name = json['name'] as String;
    final baseOrganism = allOrganisms.firstWhere(
      (o) => o.name == name,
      orElse: () => allOrganisms[0],
    );
    
    final ivs = Map<String, int>.from(json['ivs'] as Map);
    final currentHealth = json['currentHealth'] as int;
    
    Talisman? talisman;
    if (json['equippedTalisman'] != null) {
      talisman = Talisman.fromJson(json['equippedTalisman'] as Map<String, dynamic>);
    }
    
    return CapturedOrganism(
      baseOrganism: baseOrganism,
      individualValues: ivs,
      currentHealth: currentHealth,
      equippedTalisman: talisman,
    );
  }
}