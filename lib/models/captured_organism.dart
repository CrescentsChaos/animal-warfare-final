// lib/models/captured_organism.dart
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:animal_warfare/models/organism.dart'; // Import the base model
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
  final int xp; // NEW: Experience points

  // NEW: Stat Boost Persistence (for Roguelike mid-battle re-entry)
  int attackStage;
  int defenseStage;
  int powerStage;
  int resistanceStage;
  int speedStage;
  int accuracyStage;
  int evasionStage;

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
    this.xp = 0,
    this.attackStage = 0,
    this.defenseStage = 0,
    this.powerStage = 0,
    this.resistanceStage = 0,
    this.speedStage = 0,
    this.accuracyStage = 0,
    this.evasionStage = 0,
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

  // Compatibility getters for tests
  int get health => currentHealth;
  set health(int value) => currentHealth = value;
  List<String> get abilities =>
      baseOrganism.abilities.split(',').map((e) => e.trim()).toList();
  bool get isAlpha => false; // Placeholder for tests
  bool get isShiny => false; // Placeholder for tests

  CapturedOrganism copyWith({
    Organism? baseOrganism,
    Map<String, int>? individualValues,
    int? currentHealth,
    Talisman? equippedTalisman,
    bool clearTalisman = false, // Added to allow unequipping
    List<String>? selectedMoveNames,
    Map<String, int>? moveStamina,
    Nature? nature,
    List<StatusEffect>? statusEffects,
    String? id,
    int? level, // Added level to copyWith
    int? xp,
    int? attackStage,
    int? defenseStage,
    int? powerStage,
    int? resistanceStage,
    int? speedStage,
    int? accuracyStage,
    int? evasionStage,
  }) {
    return CapturedOrganism(
      baseOrganism: baseOrganism ?? this.baseOrganism,
      individualValues: individualValues ?? Map.from(this.individualValues),
      currentHealth: currentHealth ?? this.currentHealth,
      equippedTalisman: clearTalisman
          ? null
          : (equippedTalisman ?? this.equippedTalisman),
      selectedMoveNames: selectedMoveNames ?? List.from(this.selectedMoveNames),
      initialMoveStamina: moveStamina ?? Map.from(this.moveStamina),
      nature: nature ?? this.nature,
      statusEffects: statusEffects ?? List.from(this.statusEffects),
      id: id ?? this.id,
      level: level ?? this.level, // Pass level to constructor
      xp: xp ?? this.xp,
      attackStage: attackStage ?? this.attackStage,
      defenseStage: defenseStage ?? this.defenseStage,
      powerStage: powerStage ?? this.powerStage,
      resistanceStage: resistanceStage ?? this.resistanceStage,
      speedStage: speedStage ?? this.speedStage,
      accuracyStage: accuracyStage ?? this.accuracyStage,
      evasionStage: evasionStage ?? this.evasionStage,
    );
  }

  // --- XP and Leveling Logic ---

  /// Calculate XP required for next level: (Level^3)
  static int xpForLevel(int l) => (l * l * l);

  /// Awards XP to the organism, handles level ups and account level capping.
  /// Returns a map with 'leveledUp' (bool) and 'xp' (int) and 'level' (int).
  Map<String, dynamic> gainXP(int amount, int accountLevelCap) {
    int currentXP = xp + amount;
    int currentLevel = level;
    bool leveledUp = false;

    while (currentLevel < accountLevelCap &&
        currentXP >= xpForLevel(currentLevel + 1)) {
      currentLevel++;
      leveledUp = true;
    }

    // If we reached the cap, we pause XP gain at the threshold of the next level.
    if (currentLevel >= accountLevelCap) {
      int capXP = xpForLevel(currentLevel + 1) - 1;
      if (currentXP > capXP) {
        currentXP = capXP;
      }
    }

    return {'xp': currentXP, 'level': currentLevel, 'leveledUp': leveledUp};
  }

  // --- DNA Generation and Stat Calculation ---

  // Maximum IV value (0 to 31)
  static const int maxIV = 31;
  // Stat formula constant (to ensure stats are meaningful)
  static const int statConstant = 10;

  // Factory constructor for generating a new wild organism with random IVs
  factory CapturedOrganism.spawn(
    Organism base, {
    int? level,
    int accountLevel = 1,
  }) {
    final rng = Random();

    // Wild level: randomized around account level if not specified
    int wildLevel =
        level ?? (accountLevel + (rng.nextInt(5) - 2)).clamp(1, 100);

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
      level: wildLevel,
    );

    final spawn = CapturedOrganism(
      baseOrganism: base,
      individualValues: ivs,
      currentHealth: maxHp, // Starts with full health
      nature: Nature.getRandom(),
      level: wildLevel, // Pass level to constructor
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
  /// Randomizes selection if more than 4 moves are available, favoring a balanced set.
  void initializeDefaultMoves() {
    final allPossibleMoveNames = baseOrganism.moves
        .split(',')
        .map((m) => m.trim())
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();

    if (allPossibleMoveNames.isEmpty) {
      selectedMoveNames = ['Struggle'];
      _initializeStamina();
      return;
    }

    if (allPossibleMoveNames.length <= 4) {
      selectedMoveNames = allPossibleMoveNames;
      _initializeStamina();
      return;
    }

    // Balanced selection logic
    final List<Move> moves = allPossibleMoveNames
        .map((name) => Move.findByName(name))
        .whereType<Move>()
        .toList();

    // 1. Determine primary stat orientation
    final isPhysical = getAttack() >= getPower();

    // 2. Categorize moves
    final List<Move> mandatoryAttacks =
        []; // Primary category STAB (if we had STAB) or just primary damage
    final List<Move> secondaryAttacks = []; // Special if physical, etc.
    final List<Move> utilityMoves = []; // Status, Heal, etc.

    for (final m in moves) {
      if (m.category == MoveCategory.status || m.baseDamage == 0) {
        utilityMoves.add(m);
      } else if (isPhysical && m.category == MoveCategory.physical) {
        mandatoryAttacks.add(m);
      } else if (!isPhysical && m.category == MoveCategory.special) {
        mandatoryAttacks.add(m);
      } else {
        secondaryAttacks.add(m);
      }
    }

    // 3. Select balanced set
    final List<String> result = [];
    final rng = Random();

    // Always try to take 1-2 mandatory attacks
    mandatoryAttacks.shuffle(rng);
    for (int i = 0; i < min(2, mandatoryAttacks.length); i++) {
      result.add(mandatoryAttacks[i].name);
    }

    // Try to take 1 utility move
    if (utilityMoves.isNotEmpty) {
      utilityMoves.shuffle(rng);
      result.add(utilityMoves.first.name);
    }

    // Fill the rest from remaining moves
    final remainingPool = moves.where((m) => !result.contains(m.name)).toList();
    remainingPool.shuffle(rng);

    while (result.length < 4 && remainingPool.isNotEmpty) {
      result.add(remainingPool.removeAt(0).name);
    }

    // Fallback if logic somehow failed to fill 4 (e.g. only 3 unique moves)
    selectedMoveNames = result.take(4).toList();
    _initializeStamina();
  }

  void _initializeStamina() {
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
    'xp': xp, // Added xp to toJson
    'attackStage': attackStage,
    'defenseStage': defenseStage,
    'powerStage': powerStage,
    'resistanceStage': resistanceStage,
    'speedStage': speedStage,
    'accuracyStage': accuracyStage,
    'evasionStage': evasionStage,
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
      talisman = Talisman.fromJsonWithId(
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
      xp: json['xp'] as int? ?? 0, // Pass xp to constructor
      attackStage: json['attackStage'] as int? ?? 0,
      defenseStage: json['defenseStage'] as int? ?? 0,
      powerStage: json['powerStage'] as int? ?? 0,
      resistanceStage: json['resistanceStage'] as int? ?? 0,
      speedStage: json['speedStage'] as int? ?? 0,
      accuracyStage: json['accuracyStage'] as int? ?? 0,
      evasionStage: json['evasionStage'] as int? ?? 0,
    );
  }
}
