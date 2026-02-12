// lib/models/captured_organism.dart
import 'dart:math';
import 'organism.dart'; // Import the base model
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/move.dart';

// Represents an individual instance of a captured or wild organism.
// This is the model that holds the unique DNA (IVs).
class CapturedOrganism {
  final Organism baseOrganism;
  
  // Unique DNA/IVs: Individual Values (0-31 for each stat)
  // These are the "genes" that make this animal unique.
  final Map<String, int> individualValues; // 'health', 'attack', 'defense', 'power', 'resistance', 'speed'
  
  // Current Battle State
  int currentHealth;

  // Equipped Talisman
  Talisman? equippedTalisman;
  
  // NEW: Move Selection and Stamina
  List<String> selectedMoveNames;
  Map<String, int> moveStamina; // current stamina for each selected move
  
  CapturedOrganism({
    required this.baseOrganism,
    required this.individualValues,
    required this.currentHealth,
    this.equippedTalisman,
    this.selectedMoveNames = const [],
    this.moveStamina = const {},
  }) {
    // Ensure moves are initialized if empty (for legacy data)
    if (selectedMoveNames.isEmpty) {
      initializeDefaultMoves();
    } else {
      // Sync stamina map keys if missing (new system on old data)
      for (final moveName in selectedMoveNames) {
        if (!moveStamina.containsKey(moveName)) {
           final move = Move.findByName(moveName);
           moveStamina[moveName] = move?.stamina ?? Move.defaultStamina;
        }
      }
    }
    // Ensure all IVs exist (for legacy data)
    final stats = ['health', 'attack', 'defense', 'power', 'resistance', 'speed'];
    for (final stat in stats) {
      if (!individualValues.containsKey(stat)) {
        individualValues[stat] = Random().nextInt(maxIV + 1);
      }
    }
  }

  // NEW: Convenience getter for the organism's name
  String get name => baseOrganism.name; 

  CapturedOrganism copyWith({
    Organism? baseOrganism,
    Map<String, int>? individualValues,
    int? currentHealth,
    Talisman? equippedTalisman,
    List<String>? selectedMoveNames,
    Map<String, int>? moveStamina,
  }) {
    return CapturedOrganism(
      baseOrganism: baseOrganism ?? this.baseOrganism,
      individualValues: individualValues ?? this.individualValues,
      currentHealth: currentHealth ?? this.currentHealth,
      equippedTalisman: equippedTalisman ?? this.equippedTalisman,
      selectedMoveNames: selectedMoveNames ?? this.selectedMoveNames,
      moveStamina: moveStamina ?? this.moveStamina,
    );
  }
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
      'power': rng.nextInt(maxIV + 1),
      'resistance': rng.nextInt(maxIV + 1),
      'speed': rng.nextInt(maxIV + 1),
    };

    // Calculate initial max HP
    final maxHp = calculateStat('health', base.health, ivs['health']!);
    
    final spawn = CapturedOrganism(
      baseOrganism: base,
      individualValues: ivs,
      currentHealth: maxHp, // Starts with full health
    );
    
    // Explicitly initialize moves now so they are set in stone
    spawn.initializeDefaultMoves();
    return spawn;
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

  int get effectivePower => calculateStat(
    'power', 
    baseOrganism.power, 
    individualValues['power']!
  );
  
  int get effectiveResistance => calculateStat(
    'resistance', 
    baseOrganism.resistance, 
    individualValues['resistance']!
  );
  
  int get effectiveSpeed => calculateStat(
    'speed', 
    baseOrganism.speed, 
    individualValues['speed']!
  );

  /// Initializes the move selection with 4 moves from the base organism.
  /// Uses a deterministic approach (first 4) to avoid order jitter.
  void initializeDefaultMoves() {
    final allPossibleMoves = baseOrganism.moves
        .split(',')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toList();
    
    // Take the first 4 unique moves
    final List<String> selected = [];
    for (final moveName in allPossibleMoves) {
      if (!selected.contains(moveName)) {
        selected.add(moveName);
      }
      if (selected.length >= 4) break;
    }
    
    // Fallback if no moves listed
    if (selected.isEmpty) {
      selected.add('Struggle');
    }
    
    selectedMoveNames = selected;
    
    // Initialize stamina for these moves
    moveStamina = {};
    for (final moveName in selectedMoveNames) {
      final move = Move.findByName(moveName);
      moveStamina[moveName] = move?.stamina ?? Move.defaultStamina;
    }
  }

  // --- Serialization for Storage ---

  Map<String, dynamic> toJson() => {
    // Only store the name and IVs, the base stats are looked up from the base Organism list
    'name': baseOrganism.name, 
    'ivs': individualValues,
    'currentHealth': currentHealth,
    'equippedTalisman': equippedTalisman?.toJson(),
    'selectedMoveNames': selectedMoveNames,
    'moveStamina': moveStamina,
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
    
    final moveStamina = json['moveStamina'] != null 
        ? Map<String, int>.from(json['moveStamina'] as Map)
        : <String, int>{};
    final selectedMoves = json['selectedMoveNames'] != null
        ? List<String>.from(json['selectedMoveNames'] as List)
        : <String>[];

    return CapturedOrganism(
      baseOrganism: baseOrganism,
      individualValues: ivs,
      currentHealth: currentHealth,
      equippedTalisman: talisman,
      selectedMoveNames: selectedMoves,
      moveStamina: moveStamina,
    );
  }
}