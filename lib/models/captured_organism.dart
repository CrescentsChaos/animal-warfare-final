// lib/models/captured_organism.dart
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'organism.dart'; // Import the base model
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/nature.dart';
import 'package:animal_warfare/models/status_effect.dart';

// Represents an individual instance of a captured or wild organism.
// This is the model that holds the unique DNA (IVs).
class CapturedOrganism {
  final String id;
  final Organism baseOrganism;

  // Unique DNA/IVs: Individual Values (0-31 for each stat)
  // These are the "genes" that make this animal unique.
  final Map<String, int>
  individualValues; // 'health', 'attack', 'defense', 'power', 'resistance', 'speed'

  // Current Battle State
  int currentHealth;

  // Equipped Talisman
  Talisman? equippedTalisman;

  // NEW: Move Selection and Stamina
  List<String> selectedMoveNames;
  Map<String, int> moveStamina; // current stamina for each selected move

  final Nature nature;
  List<StatusEffect> statusEffects;
  final int level; // NEW: Level of the organism

  CapturedOrganism({
    required this.baseOrganism,
    required this.individualValues,
    required this.currentHealth,
    this.equippedTalisman,
    this.selectedMoveNames = const [],
    Map<String, int>? initialMoveStamina,
    this.nature = const Nature(
      name: 'Hardy',
      increasedStat: NatureStat.attack,
      decreasedStat: NatureStat.attack,
    ),
    List<StatusEffect>? statusEffects,
    StatusEffect? statusEffect, // Legacy support
    String? id,
    this.level = 50, // Default level to 50
  }) : id = id ?? const Uuid().v4(),
       statusEffects =
           statusEffects ?? (statusEffect != null ? [statusEffect] : []),
       moveStamina = initialMoveStamina != null
           ? Map.from(initialMoveStamina)
           : {} {
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
    final stats = [
      'health',
      'attack',
      'defense',
      'power',
      'resistance',
      'speed',
    ];
    for (final stat in stats) {
      if (!individualValues.containsKey(stat)) {
        individualValues[stat] = Random().nextInt(maxIV + 1);
      }
    }
  }

  // NEW: Convenience getter for the organism's name
  String get name => baseOrganism.name;

  // Backward compatibility getter/setter
  StatusEffect get statusEffect => statusEffects.isNotEmpty
      ? statusEffects.first
      : const StatusEffect(type: StatusEffectType.none);

  set statusEffect(StatusEffect value) {
    if (value.type == StatusEffectType.none) {
      statusEffects = [];
    } else {
      statusEffects = [value];
    }
  }

  CapturedOrganism copyWith({
    Organism? baseOrganism,
    Map<String, int>? individualValues,
    int? currentHealth,
    Talisman? equippedTalisman,
    List<String>? selectedMoveNames,
    Map<String, int>? moveStamina,
    Nature? nature,
    List<StatusEffect>? statusEffects,
    String? id,
    int? level, // Added level to copyWith
  }) {
    return CapturedOrganism(
      baseOrganism: baseOrganism ?? this.baseOrganism,
      individualValues: individualValues ?? Map.from(this.individualValues),
      currentHealth: currentHealth ?? this.currentHealth,
      equippedTalisman: equippedTalisman ?? this.equippedTalisman,
      selectedMoveNames: selectedMoveNames ?? List.from(this.selectedMoveNames),
      initialMoveStamina: moveStamina ?? Map.from(this.moveStamina),
      nature: nature ?? this.nature,
      statusEffects: statusEffects ?? List.from(this.statusEffects),
      id: id ?? this.id,
      level: level ?? this.level, // Pass level to constructor
    );
  }
  // --- DNA Generation and Stat Calculation ---

  // Maximum IV value (0 to 31)
  static const int maxIV = 31;
  // Stat formula constant (to ensure stats are meaningful)
  static const int statConstant = 10;

  // Factory constructor for generating a new wild organism with random IVs
  factory CapturedOrganism.spawn(Organism base, {int level = 5}) {
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
    final maxHp = calculateStat(
      'health',
      base.health,
      ivs['health']!,
      level: level,
    );

    final spawn = CapturedOrganism(
      baseOrganism: base,
      individualValues: ivs,
      currentHealth: maxHp, // Starts with full health
      nature: Nature.getRandom(),
      level: level, // Pass level to constructor
    );

    // Explicitly initialize moves now so they are set in stone
    spawn.initializeDefaultMoves();
    return spawn;
  }

  // Stat calculation formula: BaseStat + (IV / 2) + Constant
  // The 'IV/2' makes the IVs noticeable but not overwhelmingly dominant.
  static int calculateStat(
    String statName,
    int baseStat,
    int iv, {
    int level = 50, // Default level for static calculation
  }) {
    // Standard Formula: ((Base * 2 + IV + (EV/4)) * Level / 100) + N
    // But since we don't have EVs yet and statConstant was 10.
    // Let's adapt closer to standard Pokemon formula logic but simplified.
    // HP: ((Base + IV) * 2 * Level / 100) + Level + 10
    // Others: ((Base + IV) * 2 * Level / 100) + 5

    // Using simple version for balance continuity with previous logic if level was 50-ish?
    // Old formula was (Base + IV/2)*2 + 10.
    // If we assume old logic was "Level 50", let's make it scale linearly.

    final double levelMultiplier = level / 50.0;

    if (statName == 'health') {
      // HP Formula: (Base + IV/2) * 2 * Multiplier + Constant (scaled?)
      // Keeping it simple so it doesn't break balance:
      return ((baseStat + (iv / 2).floor()) * 2 * levelMultiplier).floor() +
          statConstant +
          level;
    }
    // Other Stats Formula: (Base + IV/2) * Multiplier + Constant
    return ((baseStat + (iv / 2).floor()) * levelMultiplier).floor() +
        statConstant;
  }

  // --- Getters for Effective Stats ---

  int getMaxHealth({int? atLevel}) => calculateStat(
    'health',
    baseOrganism.health,
    individualValues['health']!,
    level: atLevel ?? level,
  );

  int getAttack({int? atLevel}) =>
      (calculateStat(
                'attack',
                baseOrganism.attack,
                individualValues['attack']!,
                level: atLevel ?? level,
              ) *
              nature.getMultiplier('attack'))
          .round();

  int getDefense({int? atLevel}) =>
      (calculateStat(
                'defense',
                baseOrganism.defense,
                individualValues['defense']!,
                level: atLevel ?? level,
              ) *
              nature.getMultiplier('defense'))
          .round();

  int getPower({int? atLevel}) =>
      (calculateStat(
                'power',
                baseOrganism.power,
                individualValues['power']!,
                level: atLevel ?? level,
              ) *
              nature.getMultiplier('power'))
          .round();

  int getResistance({int? atLevel}) =>
      (calculateStat(
                'resistance',
                baseOrganism.resistance,
                individualValues['resistance']!,
                level: atLevel ?? level,
              ) *
              nature.getMultiplier('resistance'))
          .round();

  int getSpeed({int? atLevel}) =>
      (calculateStat(
                'speed',
                baseOrganism.speed,
                individualValues['speed']!,
                level: atLevel ?? level,
              ) *
              nature.getMultiplier('speed'))
          .round();

  // --- Getters for Effective Stats (Default to instance level) ---

  int get maxHealth => getMaxHealth();
  int get effectiveAttack => getAttack();
  int get effectiveDefense => getDefense();
  int get effectivePower => getPower();
  int get effectiveResistance => getResistance();
  int get effectiveSpeed => getSpeed();

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

  /// RESTORES ALL MOVE STAMINA to max
  void restoreAllStamina() {
    for (final moveName in selectedMoveNames) {
      final move = Move.findByName(moveName);
      moveStamina[moveName] = move?.stamina ?? Move.defaultStamina;
    }
  }

  // --- Serialization for Storage ---

  Map<String, dynamic> toJson() => {
    'id': id, // Add id to JSON
    // Only store the name and IVs, the base stats are looked up from the base Organism list
    'name': baseOrganism.name,
    'ivs': individualValues,
    'currentHealth': currentHealth,
    'equippedTalisman': equippedTalisman?.toJson(),
    'selectedMoveNames': selectedMoveNames,
    'moveStamina': moveStamina,
    'nature': nature.name,
    'statusEffects': statusEffects.map((e) => e.toJson()).toList(),
    'level': level, // Added level to toJson
  };

  /// Create CapturedOrganism from JSON
  static CapturedOrganism? fromJson(
    Map<String, dynamic> json,
    List<Organism> allOrganisms,
  ) {
    final id = json['id'] as String?; // Read id from JSON
    final name = json['name'] as String;
    final baseOrganism = allOrganisms.firstWhere(
      (o) => o.name == name,
      orElse: () => allOrganisms[0],
    );

    final ivs = Map<String, int>.from(json['ivs'] as Map);
    final currentHealth = json['currentHealth'] as int;

    Talisman? talisman;
    if (json['equippedTalisman'] != null) {
      talisman = Talisman.fromJson(
        json['equippedTalisman'] as Map<String, dynamic>,
      );
    }

    final moveStamina = json['moveStamina'] != null
        ? Map<String, int>.from(json['moveStamina'] as Map)
        : <String, int>{};
    final selectedMoves = json['selectedMoveNames'] != null
        ? List<String>.from(json['selectedMoveNames'] as List)
        : <String>[];

    final natureName = json['nature'] as String? ?? 'Hardy';
    final nature = Nature.findByName(natureName);

    StatusEffect? status;
    if (json['statusEffect'] != null) {
      status = StatusEffect.fromJson(
        json['statusEffect'] as Map<String, dynamic>,
      );
    }

    final level =
        json['level'] as int? ?? 50; // Read level from JSON, default to 50

    return CapturedOrganism(
      id: id, // Pass id to constructor
      baseOrganism: baseOrganism,
      individualValues: ivs,
      currentHealth: currentHealth,
      equippedTalisman: talisman,
      selectedMoveNames: selectedMoves,
      initialMoveStamina: moveStamina,
      nature: nature,
      statusEffects: json['statusEffects'] != null
          ? (json['statusEffects'] as List)
                .map((e) => StatusEffect.fromJson(e as Map<String, dynamic>))
                .toList()
          : (status != null ? [status] : []),
      level: level, // Pass level to constructor
    );
  }
}
