// lib/models/captured_organism.dart
import 'dart:math';
import 'package:uuid/uuid.dart';
import 'package:animal_warfare/models/organism.dart'; // Import the base model
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/nature.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/game/time_service.dart'; // NEW: for GameTime

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

  Nature nature;
  List<StatusEffect> statusEffects;
  final int initialLevel; // NEW: Level at capture/spawn
  int level; // Actual derived level
  int xp; // Cumulative experience points

  // NEW: Stat Boost Persistence (for Roguelike mid-battle re-entry)
  int attackStage;
  int defenseStage;
  int powerStage;
  int resistanceStage;
  int speedStage;
  int accuracyStage;
  int evasionStage;
  final bool isAlpha;
  final bool isShiny;

  // KV system: Kill Values earned by defeating animals (like Pokémon EVs)
  // Max 252 per stat, 510 total. Each 4 KVs = +1 effective stat point.
  Map<String, int>
  killValues; // 'health', 'attack', 'defense', 'power', 'resistance', 'speed'

  // NEW: Satisfaction (0-255), affects obedience
  int satisfaction;

  // NEW: Single Active Ability
  String activeAbilityName;

  // Tera type for Prismorph gimmick (null = no tera type)
  ElementalType? teraType;

  // Nicknaming support
  final String? nickname;

  // NEW: Capture Metadata
  final DateTime? capturedAtReal;
  final GameTime? capturedAtGame;
  final String? captureLocation;

  String get displayName => nickname ?? baseOrganism.name;

  // NEW: Hunger and Nutrition
  int hungerLevel; // 0 (starving) to 100 (full)
  DateTime? lastFedTimeReal;
  DateTime? lastHungerUpdateReal;
  GameTime? lastFedTimeGame;

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
    this.initialLevel = 1,
    this.level = 1,
    this.xp = 1,
    this.attackStage = 0,
    this.defenseStage = 0,
    this.powerStage = 0,
    this.resistanceStage = 0,
    this.speedStage = 0,
    this.accuracyStage = 0,
    this.evasionStage = 0,
    this.isAlpha = false,
    this.isShiny = false,
    Map<String, int>? killValues,
    this.satisfaction = 120,
    this.hungerLevel = 100, // Starts full
    this.lastFedTimeReal,
    this.lastHungerUpdateReal,
    this.lastFedTimeGame,
    String? activeAbilityName,
    this.teraType,
    this.nickname,
    this.capturedAtReal,
    this.capturedAtGame,
    this.captureLocation,
  }) : activeAbilityName =
           activeAbilityName ??
           (baseOrganism.abilities.split(',').first.trim().isEmpty
               ? 'None'
               : baseOrganism.abilities.split(',').first.trim()),
       id = id ?? const Uuid().v4(),
       killValues =
           killValues ??
           {
             'health': 0,
             'attack': 0,
             'defense': 0,
             'power': 0,
             'resistance': 0,
             'speed': 0,
           },
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

  /// Feeds the animal and returns nutritional gain and message.
  Map<String, dynamic> feed(
    Talisman food, {
    DateTime? realTime,
    GameTime? gameTime,
  }) {
    if (!food.isFood) return {'success': false, 'message': 'That is not food!'};

    double multiplier = 1.0;
    bool isPreferred = false;

    // 1. Check Diet Preference
    if (food.dietType != null) {
      if (food.dietType!.toLowerCase() == baseOrganism.diet.toLowerCase()) {
        multiplier *= 1.2;
      } else if (baseOrganism.diet.toLowerCase() == 'omnivore') {
        multiplier *= 1.0; // Omnivores are okay with most things
      } else {
        multiplier *= 0.5; // Wrong diet type
      }
    }

    // 2. Check Class Preference
    if (food.preferredClass != null) {
      final preferredClasses = food.preferredClass!
          .split(',')
          .map((e) => e.trim().toLowerCase());
      if (preferredClasses.contains(baseOrganism.animalClass.toLowerCase())) {
        multiplier *= 1.5;
        isPreferred = true;
      }
    }

    // 3. Check Species Preference
    if (food.preferredSpecies != null) {
      final preferredSpecies = food.preferredSpecies!
          .split(',')
          .map((e) => e.trim().toLowerCase());
      if (preferredSpecies.contains(baseOrganism.name.toLowerCase())) {
        multiplier *= 2.0;
        isPreferred = true;
      }
    }

    int nutrition = (food.nutritionalValue * multiplier).round();
    int oldHunger = hungerLevel;
    hungerLevel = (hungerLevel + nutrition).clamp(0, 100);

    // Satisfaction boost
    int satisfactionGain = isPreferred ? 15 : 5;
    if (multiplier < 1.0) satisfactionGain = -5; // Dislikes wrong diet
    satisfaction = (satisfaction + satisfactionGain).clamp(0, 255);

    lastFedTimeReal = realTime ?? DateTime.now();
    lastHungerUpdateReal = lastFedTimeReal;
    lastFedTimeGame = gameTime;

    String message = "Your $displayName enjoyed the ${food.name}!";
    if (multiplier < 1.0) {
      message =
          "Your $displayName didn't seem to like the ${food.name} very much...";
    }
    if (isPreferred) {
      message = "Your $displayName absolutely LOVED the ${food.name}!";
    }

    return {
      'success': true,
      'nutrition': nutrition,
      'hungerGain': hungerLevel - oldHunger,
      'satisfactionGain': satisfactionGain,
      'isPreferred': isPreferred,
      'message': message,
    };
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
  List<String> get abilities => [activeAbilityName];

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
    int? initialLevel,
    int? level,
    int? xp,
    int? attackStage,
    int? defenseStage,
    int? powerStage,
    int? resistanceStage,
    int? speedStage,
    int? accuracyStage,
    int? evasionStage,
    bool? isAlpha,
    bool? isShiny,
    Map<String, int>? killValues,
    int? satisfaction,
    int? hungerLevel,
    DateTime? lastFedTimeReal,
    DateTime? lastHungerUpdateReal,
    GameTime? lastFedTimeGame,
    String? activeAbilityName,
    ElementalType? teraType,
    bool clearTeraType = false,
    String? nickname,
    bool clearNickname = false,
    DateTime? capturedAtReal,
    GameTime? capturedAtGame,
    String? captureLocation,
  }) {
    return CapturedOrganism(
      id: id ?? this.id,
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
      initialLevel: initialLevel ?? this.initialLevel,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      attackStage: attackStage ?? this.attackStage,
      defenseStage: defenseStage ?? this.defenseStage,
      powerStage: powerStage ?? this.powerStage,
      resistanceStage: resistanceStage ?? this.resistanceStage,
      speedStage: speedStage ?? this.speedStage,
      accuracyStage: accuracyStage ?? this.accuracyStage,
      evasionStage: evasionStage ?? this.evasionStage,
      isAlpha: isAlpha ?? this.isAlpha,
      isShiny: isShiny ?? this.isShiny,
      killValues: killValues ?? Map.from(this.killValues),
      satisfaction: satisfaction ?? this.satisfaction,
      hungerLevel: hungerLevel ?? this.hungerLevel,
      lastFedTimeReal: lastFedTimeReal ?? this.lastFedTimeReal,
      lastHungerUpdateReal: lastHungerUpdateReal ?? this.lastHungerUpdateReal,
      lastFedTimeGame: lastFedTimeGame ?? this.lastFedTimeGame,
      activeAbilityName: activeAbilityName ?? this.activeAbilityName,
      teraType: clearTeraType ? null : (teraType ?? this.teraType),
      nickname: clearNickname ? null : (nickname ?? this.nickname),
      capturedAtReal: capturedAtReal ?? this.capturedAtReal,
      capturedAtGame: capturedAtGame ?? this.capturedAtGame,
      captureLocation: captureLocation ?? this.captureLocation,
    );
  }

  CapturedOrganism changeAbility(String abilityName) {
    return copyWith(activeAbilityName: abilityName);
  }

  // --- XP and Leveling Logic ---

  /// Calculate XP required for next level: (Level^3)
  static int xpForLevel(int l) => (l * l * l);

  /// Awards XP to the organism, handles level ups and account level capping.
  /// Returns a map with 'leveledUp' (bool) and 'xp' (int) and 'level' (int).
  Map<String, dynamic> gainXP(int amount, {int? levelCap}) {
    int newXP = xp + amount;
    bool leveledUp = false;

    if (levelCap != null) {
      int maxXP = xpForLevel(levelCap + 1) - 1;
      if (newXP > maxXP) {
        newXP = max(xp, maxXP);
      }
    }

    // Calculate level from total XP
    int levelFromXP = 1;
    while (newXP >= xpForLevel(levelFromXP + 1)) {
      levelFromXP++;
    }

    int newLevel = max(level, levelFromXP); // FIX: Never de-level
    int finalHealth = currentHealth;

    if (newLevel > level) {
      leveledUp = true;
      final oldMax = getMaxHealth(atLevel: level);
      final newMax = getMaxHealth(atLevel: newLevel);
      if (oldMax > 0) {
        // Scale health proportionally (e.g. 50/100 -> 55/110)
        finalHealth = (currentHealth * newMax / oldMax).round();
        // Ensure we don't accidentally decrease HP due to rounding,
        // and cap at new max.
        finalHealth = finalHealth.clamp(currentHealth, newMax);
      }
    }

    return {
      'xp': newXP,
      'level': newLevel,
      'leveledUp': leveledUp,
      'health': finalHealth,
    };
  }

  /// Returns the percentage of XP gained towards the next level (0.0 to 1.0).
  double get xpRatio {
    int currentLevelXP = xpForLevel(level);
    int nextLevelXP = xpForLevel(level + 1);
    int progress = xp - currentLevelXP;
    int totalNeeded = nextLevelXP - currentLevelXP;
    if (totalNeeded <= 0) return 0.0;
    return (progress / totalNeeded).clamp(0.0, 1.0);
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
    Map<String, int>? ivs,
    String? ability,
    DateTime? capturedAtReal,
    GameTime? capturedAtGame,
    String? captureLocation,
  }) {
    final rng = Random();

    // Wild level: randomized around account level if not specified, but never exceeds accountLevel
    int wildLevel =
        level ?? (accountLevel + (rng.nextInt(5) - 2)).clamp(1, accountLevel);

    // ROLL FOR SHINY AND ALPHA
    final isShinyRoll = rng.nextInt(100) == 0; // 1/100
    final isAlphaRoll = rng.nextInt(20) == 0; // 1/20

    final Map<String, int> actualIvs =
        ivs ??
        {
          'health': rng.nextInt(maxIV + 1),
          'attack': rng.nextInt(maxIV + 1),
          'defense': rng.nextInt(maxIV + 1),
          'power': rng.nextInt(maxIV + 1),
          'resistance': rng.nextInt(maxIV + 1),
          'speed': rng.nextInt(maxIV + 1),
        };

    // Apply Stat Bonuses
    if (isAlphaRoll) {
      // Alphas: all IVs >= 15, at least two are 31
      actualIvs.updateAll((k, v) => max(15, v));
      final keys = actualIvs.keys.toList()..shuffle(rng);
      actualIvs[keys[0]] = 31;
      actualIvs[keys[1]] = 31;
    } else if (isShinyRoll) {
      // Shinies: at least one is 31
      final keys = actualIvs.keys.toList()..shuffle(rng);
      actualIvs[keys[0]] = 31;
    }

    // Calculate initial max HP
    final maxHp = calculateStat(
      'health',
      base.health,
      actualIvs['health']!,
      level: wildLevel,
    );

    final spawn = CapturedOrganism(
      baseOrganism: base,
      individualValues: actualIvs,
      currentHealth: maxHp, // Starts with full health
      nature: Nature.getRandom(),
      initialLevel: wildLevel,
      level: wildLevel,
      xp: xpForLevel(wildLevel),
      isAlpha: isAlphaRoll,
      isShiny: isShinyRoll,
      activeAbilityName: ability,
      // Every animal has a Tera Type.
      // 10% chance to roll a "unique" tera type that is NOT one of the animal's base types.
      // 90% chance to roll one of its base types.
      teraType: () {
        final baseTypes = base.elementalTypes;
        if (rng.nextInt(10) == 0) {
          final candidates = ElementalType.values
              .where((t) => !baseTypes.contains(t))
              .toList();
          if (candidates.isNotEmpty) {
            return candidates[rng.nextInt(candidates.length)];
          }
        }
        // Fallback or 90% case: pick from base types
        if (baseTypes.isNotEmpty) {
          return baseTypes[rng.nextInt(baseTypes.length)];
        }
        return ElementalType.basic; // Absolute fallback
      }(),
      capturedAtReal: capturedAtReal,
      capturedAtGame: capturedAtGame,
      captureLocation: captureLocation,
    );

    // Explicitly initialize moves now so they are set in stone
    spawn.initializeDefaultMoves();
    return spawn;
  }

  // Stat calculation: Pokémon-inspired formula.
  // HP:    floor((Base * 2 + IV) * Level / 100) + Level + 10
  // Other: floor((Base * 2 + IV) * Level / 100) + 5
  // This ensures stats grow meaningfully at every level (not too flat at low
  // levels, not too explosive at high levels) and Level 50 matches the
  // balanced "mid-game" baseline.
  static int calculateStat(
    String statName,
    int baseStat,
    int iv, {
    int level = 50,
    int kv = 0,
  }) {
    final int kvBonus = (kv / 4).floor();
    final int base = ((baseStat * 2 + iv) * level / 100).floor();
    if (statName == 'health') {
      return base + level + 10 + kvBonus;
    }
    return base + 5 + kvBonus;
  }

  // --- Getters for Effective Stats ---

  int getMaxHealth({int? atLevel}) => calculateStat(
    'health',
    baseOrganism.health,
    individualValues['health']!,
    level: atLevel ?? level,
    kv: killValues['health'] ?? 0,
  );

  int getAttack({int? atLevel}) =>
      (calculateStat(
                'attack',
                baseOrganism.attack,
                individualValues['attack']!,
                level: atLevel ?? level,
                kv: killValues['attack'] ?? 0,
              ) *
              nature.getMultiplier('attack'))
          .round();

  int getDefense({int? atLevel}) =>
      (calculateStat(
                'defense',
                baseOrganism.defense,
                individualValues['defense']!,
                level: atLevel ?? level,
                kv: killValues['defense'] ?? 0,
              ) *
              nature.getMultiplier('defense'))
          .round();

  int getPower({int? atLevel}) =>
      (calculateStat(
                'power',
                baseOrganism.power,
                individualValues['power']!,
                level: atLevel ?? level,
                kv: killValues['power'] ?? 0,
              ) *
              nature.getMultiplier('power'))
          .round();

  int getResistance({int? atLevel}) =>
      (calculateStat(
                'resistance',
                baseOrganism.resistance,
                individualValues['resistance']!,
                level: atLevel ?? level,
                kv: killValues['resistance'] ?? 0,
              ) *
              nature.getMultiplier('resistance'))
          .round();

  int getSpeed({int? atLevel}) =>
      (calculateStat(
                'speed',
                baseOrganism.speed,
                individualValues['speed']!,
                level: atLevel ?? level,
                kv: killValues['speed'] ?? 0,
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

    // --- Tera Type Consistency Check ---
    if (teraType != null) {
      final selectedMoves = selectedMoveNames
          .map((n) => Move.findByName(n))
          .whereType<Move>();
      bool hasMatchingMove = selectedMoves.any((m) => m.type == teraType);

      if (!hasMatchingMove) {
        // Try to find a matching move in the base organism's available pool first
        final matchingInPool = moves.where((m) => m.type == teraType).toList();
        if (matchingInPool.isNotEmpty) {
          matchingInPool.shuffle(rng);
          selectedMoveNames[rng.nextInt(selectedMoveNames.length)] =
              matchingInPool.first.name;
        }
      }
    }
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
    'level': level,
    'xp': xp,
    'initialLevel': initialLevel,
    'attackStage': attackStage,
    'defenseStage': defenseStage,
    'powerStage': powerStage,
    'resistanceStage': resistanceStage,
    'speedStage': speedStage,
    'accuracyStage': accuracyStage,
    'evasionStage': evasionStage,
    'isAlpha': isAlpha,
    'isShiny': isShiny,
    'killValues': killValues,
    'satisfaction': satisfaction,
    'hungerLevel': hungerLevel,
    'lastFedTimeReal': lastFedTimeReal?.toIso8601String(),
    'lastHungerUpdateReal': lastHungerUpdateReal?.toIso8601String(),
    'lastFedTimeGame': lastFedTimeGame?.toJson(),
    'activeAbilityName': activeAbilityName,
    'teraType': teraType?.toString().split('.').last,
    'nickname': nickname,
    'capturedAtReal': capturedAtReal?.toIso8601String(),
    'capturedAtGame': capturedAtGame?.toJson(),
    'captureLocation': captureLocation,
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

    final ivs = (json['ivs'] as Map).map(
      (k, v) => MapEntry(k.toString(), (v as num).toInt()),
    );
    final currentHealth = (json['currentHealth'] as num).toInt();

    Talisman? talisman;
    if (json['equippedTalisman'] != null) {
      talisman = Talisman.fromJsonWithId(
        json['equippedTalisman'] as Map<String, dynamic>,
      );
    }

    final moveStamina = json['moveStamina'] != null
        ? (json['moveStamina'] as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toInt()),
          )
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

    final level = (json['level'] as num?)?.toInt() ?? 50;
    final xp =
        (json['xp'] as num?)?.toInt() ?? (level > 1 ? xpForLevel(level) : 0);

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
      level: level,
      xp: xp,
      initialLevel: (json['initialLevel'] as num?)?.toInt() ?? level,
      attackStage: (json['attackStage'] as num?)?.toInt() ?? 0,
      defenseStage: (json['defenseStage'] as num?)?.toInt() ?? 0,
      powerStage: (json['powerStage'] as num?)?.toInt() ?? 0,
      resistanceStage: (json['resistanceStage'] as num?)?.toInt() ?? 0,
      speedStage: (json['speedStage'] as num?)?.toInt() ?? 0,
      accuracyStage: (json['accuracyStage'] as num?)?.toInt() ?? 0,
      evasionStage: (json['evasionStage'] as num?)?.toInt() ?? 0,
      isAlpha: json['isAlpha'] as bool? ?? false,
      isShiny: json['isShiny'] as bool? ?? false,
      killValues: json['killValues'] != null
          ? (json['killValues'] as Map).map(
              (k, v) => MapEntry(k.toString(), (v as num).toInt()),
            )
          : null,
      satisfaction: (json['satisfaction'] as num?)?.toInt() ?? 120,
      hungerLevel: (json['hungerLevel'] as num?)?.toInt() ?? 100,
      lastFedTimeReal: json['lastFedTimeReal'] != null
          ? DateTime.parse(json['lastFedTimeReal'] as String)
          : null,
      lastHungerUpdateReal: json['lastHungerUpdateReal'] != null
          ? DateTime.parse(json['lastHungerUpdateReal'] as String)
          : null,
      lastFedTimeGame: json['lastFedTimeGame'] != null
          ? GameTime.fromJson(json['lastFedTimeGame'] as Map<String, dynamic>)
          : null,
      activeAbilityName: json['activeAbilityName'] as String?,
      teraType: json['teraType'] != null
          ? ElementalTypeX.fromString(json['teraType'] as String)
          : null,
      nickname: json['nickname'] as String?,
      capturedAtReal: json['capturedAtReal'] != null
          ? DateTime.parse(json['capturedAtReal'] as String)
          : null,
      capturedAtGame: json['capturedAtGame'] != null
          ? GameTime.fromJson(json['capturedAtGame'] as Map<String, dynamic>)
          : null,
      captureLocation: json['captureLocation'] as String?,
    );
  }

  /// Reduces KV points for a specific stat and increases satisfaction.
  /// Used by specialized berries (Pomeg, Kelpsy, etc.).
  void applyBerry(String berryId) {
    String? statKey;
    switch (berryId.toLowerCase()) {
      case 'pomeg_berry':
        statKey = 'health';
        break;
      case 'kelpsy_berry':
        statKey = 'attack';
        break;
      case 'qualot_berry':
        statKey = 'defense';
        break;
      case 'hondew_berry':
        statKey = 'power';
        break;
      case 'grepa_berry':
        statKey = 'resistance';
        break;
      case 'tamato_berry':
        statKey = 'speed';
        break;
    }

    if (statKey != null) {
      final current = killValues[statKey] ?? 0;
      // Reduce by 10 (standard Pokémon value is lower but let's be generous)
      killValues[statKey] = max(0, current - 10);
    }

    // Always increase satisfaction by a bit (max 255)
    satisfaction = min(255, satisfaction + 10);
  }

  /// Returns the total KV points across all stats.
  int get totalKV => killValues.values.fold(0, (sum, v) => sum + v);

  /// Max allowed total KVs (510 like Pokémon EVs)
  static const int maxTotalKV = 510;
  static const int maxStatKV = 252;
}
