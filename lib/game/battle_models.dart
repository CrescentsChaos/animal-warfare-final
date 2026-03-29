import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/talisman.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';

class BattleOrganism {
  CapturedOrganism organism;
  final List<Ability> _baseAbilities;
  final List<Ability> tempAbilities = [];
  List<Ability> get abilities {
    if (isAbilitySuppressed) return [];

    // Start with basic abilities from the organism
    List<Ability> result = [..._baseAbilities];

    // If activeAbilityName is set and different from base, override/add it
    final activeName = organism.activeAbilityName;
    if (activeName != 'None') {
      final active = Ability.findByName(activeName);
      if (active != null) {
        result = [
          active,
        ]; // In most cases, it completely replaces for the battle mon
      }
    }

    return [...result, ...tempAbilities];
  }

  List<Move> get moves => organism.selectedMoveNames
      .map((name) => Move.findByName(name))
      .whereType<Move>()
      .toList();

  Weather weather = Weather.none;
  Terrain terrain = Terrain.none;

  String get name =>
      isOpponent ? 'Foe ${organism.displayName}' : organism.displayName;

  late int _health;
  int get health => _health;
  set health(int value) {
    _health = value;
    organism.currentHealth = value;
  }

  // Dynamic battle stats
  int _attackStage = 0;
  int get attackStage => _attackStage;
  set attackStage(int value) {
    _attackStage = value;
    if (isRogueMode) organism.attackStage = value;
  }

  int _defenseStage = 0;
  int get defenseStage => _defenseStage;
  set defenseStage(int value) {
    _defenseStage = value;
    if (isRogueMode) organism.defenseStage = value;
  }

  int _powerStage = 0;
  int get powerStage => _powerStage;
  set powerStage(int value) {
    _powerStage = value;
    if (isRogueMode) organism.powerStage = value;
  }

  int _resistanceStage = 0;
  int get resistanceStage => _resistanceStage;
  set resistanceStage(int value) {
    _resistanceStage = value;
    if (isRogueMode) organism.resistanceStage = value;
  }

  int _speedStage = 0;
  int get speedStage => _speedStage;
  set speedStage(int value) {
    _speedStage = value;
    if (isRogueMode) organism.speedStage = value;
  }

  int _accuracyStage = 0;
  int get accuracyStage => _accuracyStage;
  set accuracyStage(int value) {
    _accuracyStage = value;
    if (isRogueMode) organism.accuracyStage = value;
  }

  int _evasionStage = 0;
  int get evasionStage => _evasionStage;
  set evasionStage(int value) {
    _evasionStage = value;
    if (isRogueMode) organism.evasionStage = value;
  }

  int tauntTurns = 0;
  int encoreTurns = 0;
  bool isShieldForm = true;
  bool isKingsShieldActive = false;
  Move? lastMove;
  bool isImprisoning = false;
  Move? rolloutMove;
  String? activeForm;
  bool magicCoatActive = false;
  int stockpileCount = 0;
  bool isLeechSeeded = false;
  bool isJawLocked = false;
  bool batonPassPending = false;

  // ============================================================
  // DOUBLE BATTLE FIELDS
  // ============================================================
  bool helpingHandBoosted = false;
  bool isFollowMeTarget = false;
  int slotIndex = 0; // 0 for left, 1 for right
  bool isPartner = false; // Is this organism in slot 1?

  /// Reset battle-specific flags (called when switching out or starting battle)
  void resetBattleState() {
    isChoiceLocked = false;
    lockedMove = null;
    isProtected = false;
    isKingsShieldActive = false;
    mustRecharge = false;
    chargeMove = null;
    chargingMove = null;
    protectSuccessionCount = 0;
    tookDamageThisTurn = false;
    isInvulnerable = false;
    semiInvulnerable = null;
    damageDealtThisTurn = 0;
    tauntTurns = 0;
    encoreTurns = 0;
    lastMove = null;
    isImprisoning = false;
    lastHitById = null;

    // Advanced move state reset
    substituteHealth = 0;
    helpingHandBoosted = false;
    isFollowMeTarget = false;
    rolloutTurnCount = 0;
    usedDefenseCurl = false;
    futureSightTurns = 0;
    futureSightDamage = 0;
    rolloutMove = null;
    laserFocusTurns = 0;
    focusEnergyActive = false;
    magicCoatActive = false;
    thrashTurnCount = 0;
    thrashMove = null;
    throatChopTurns = 0;
    clampingTurns = 0;
    isFirstTurnOutOfBall = true;
    wasSwitchedInThisTurn = true;
    isSwitchingOut = false;
    wishTurns = 0;
    wishHealAmount = 0;
    healBlockTurns = 0;
    glaiveRushVulnerable = false;
    shellTrapActive = false;
    isShieldForm =
        (organism.baseOrganism.name ==
        'Aegislash'); // Default to Shield for Aegislash
    movesUsedInBattle.clear();
    lastPhysicalDamageTaken = 0;
    lastSpecialDamageTaken = 0;
    focusPunchFailed = false;
    statsLoweredThisTurn = false;
    isMiracleEyed = false;
    shellTrapTriggered = false;
    lastMoveName = null;
    tempAbilities.clear();
    anticipationShieldActive = false;
    lastMoveFailed = false;
    furyCutterCount = 0;
    stockpileCount = 0;
    isLeechSeeded = false;
    isJawLocked = false;

    // GIMMICK RESET: Prismorph persists.
    // NOTE: isPrismorphed/hasPrismorph/activeTeraType are NOT reset here;
    // they persist for the entire battle.

    itemDisabledTurns = 0;
    disabledMoves.clear();
    poisonTurnCount = 0;

    hasMovedThisTurn = false;

    // Complex Move States
    isBiding = false;
    bideDamage = 0;
    bideTurns = 0;
    isBurnedUp = false;
    isDestinyBondActive = false;
    isEnduring = false;
    isElectrified = false;
    isForesighted = false;
    hasForestsCurse = false;
    grudgeActive = false;
    isIngrained = false;
    yawnTurns = 0;
  }

  void resetStatStages() {
    _attackStage = 0;
    _defenseStage = 0;
    _powerStage = 0;
    _resistanceStage = 0;
    _speedStage = 0;
    _accuracyStage = 0;
    _evasionStage = 0;
    if (isRogueMode) {
      organism.attackStage = 0;
      organism.defenseStage = 0;
      organism.powerStage = 0;
      organism.resistanceStage = 0;
      organism.speedStage = 0;
      organism.accuracyStage = 0;
      organism.evasionStage = 0;
    }
  }

  /// Refreshes stats after a level-up or level change
  void recalculateStats() {
    if (_atLevel == null) {
      int prevMax = maxHealth;
      level = organism.level; // SYNC LEVEL FROM THE UPDATED ORGANISM
      int newMax = maxHealth;

      // Sync health from organism if it's higher (restored on level up)
      if (organism.currentHealth > _health) {
        _health = organism.currentHealth;
      } else if (newMax > prevMax) {
        // Heel the difference if health wasn't explicitly set in organism
        _health += (newMax - prevMax);
      }
      _health = _health.clamp(0, newMax);
    }
  }

  List<StatusEffect> _statusEffects = [];
  List<StatusEffect> get statusEffects => _statusEffects;
  set statusEffects(List<StatusEffect> value) {
    _statusEffects = value;
    organism.statusEffects = value;
  }

  // Compatibility getter/setter for single status check
  StatusEffect get statusEffect {
    if (_statusEffects.isEmpty) {
      return const StatusEffect(type: StatusEffectType.none);
    }
    return _statusEffects.last;
  }

  set statusEffect(StatusEffect value) {
    if (value.type == StatusEffectType.none) {
      _statusEffects = [];
    } else {
      _statusEffects = [value];
    }
    organism.statusEffects = _statusEffects;
  }

  void addStatusEffect(StatusEffect effect) {
    // Prevent duplicate status effects of the same type
    if (_statusEffects.any((se) => se.type == effect.type)) {
      return;
    }
    _statusEffects.add(effect);
    organism.statusEffects = _statusEffects;
  }

  void clearStatusEffects() {
    _statusEffects.clear();
    organism.statusEffects = _statusEffects;
    poisonTurnCount = 0;
  }

  // New flags for complex moves
  bool isInvulnerable = false;
  bool isProtected = false;
  // Removed rechargeTurn in favor of mustRecharge
  Move? chargeMove; // For Solar Beam etc
  String? chargeStatChanges; // Stat changes to apply after charge
  Move? chargingMove; // The move currently being charged
  bool mustRecharge = false;
  int protectSuccessionCount = 0;
  bool tookDamageThisTurn = false;
  String? semiInvulnerable; // e.g., 'underground'

  // Talisman effect tracking
  bool isChoiceLocked = false;
  Move? lockedMove;
  bool focusSashUsed = false;
  int damageDealtThisTurn = 0;
  int totalDamageDealt = 0;
  int totalDamageTaken = 0;
  bool isItemRevealed = false; // For lifesteal tracking
  bool talismanConsumed = false; // Berry/single-use item consumed this battle
  double critBoostFromBerry = 0.0; // Lansat Berry crit% boost

  // Disguise (Mimic/Illusion) state
  bool isDisguised = false;
  CapturedOrganism? disguisedAs;

  // Ability state
  bool isAbilityRevealed = false;

  double get currentWeight {
    double baseWeight = organism.baseOrganism.weight;
    if (abilities.any((a) => a.name == 'Heavy Metal')) return baseWeight * 2;
    if (abilities.any((a) => a.name == 'Light Metal')) return baseWeight * 0.5;
    return baseWeight;
  }

  bool hasMovedThisTurn = false;

  // ============================================================
  // GIMMICK STATE: Prismorph (Terastalize)
  // ============================================================
  bool isPrismorphed = false;
  bool hasPrismorphedThisBattle = false;
  ElementalType? activeTeraType; // set when Prismorph activates

  String? lastHitById;
  bool coilUpActive = false;
  bool partyMemberFaintedLastTurn = false;

  // New state variables for advanced mechanics
  int? perishTurnCount;
  bool isTrapped = false; // For trapping effects like Mean Look
  int throatChopTurns = 0;
  int clampingTurns = 0;
  int poisonTurnCount = 0;
  bool isFirstTurnOutOfBall = true;
  bool wasSwitchedInThisTurn = false;
  bool isSwitchingOut = false;

  // Disable effects
  int itemDisabledTurns = 0;
  final Map<String, int> disabledMoves = {};

  // Advanced move state
  int substituteHealth = 0;
  int rolloutTurnCount = 0;
  bool usedDefenseCurl = false;
  int futureSightTurns = 0;
  int futureSightDamage = 0;
  BattleOrganism? futureSightUser; // The attacker who used Future Sight
  int laserFocusTurns = 0;
  bool focusEnergyActive = false;
  int thrashTurnCount = 0;
  Move? thrashMove;

  // Advanced Move States
  int wishTurns = 0;
  int wishHealAmount = 0;
  int healBlockTurns = 0;
  bool glaiveRushVulnerable = false;
  bool shellTrapActive = false;
  final Set<String> movesUsedInBattle = {};
  int lastPhysicalDamageTaken = 0;
  int lastSpecialDamageTaken = 0;
  bool focusPunchFailed = false;
  bool statsLoweredThisTurn = false;
  bool isMiracleEyed = false;
  bool shellTrapTriggered = false;
  String? lastMoveName;
  bool truantSkipTurn = false;
  bool unburdenActive = false;
  bool isAbilitySuppressed = false;
  bool anticipationShieldActive = false;
  bool lastMoveFailed = false;
  int furyCutterCount = 0;

  // Ability-state fields for Gen 8 abilities
  bool iceFaceActive = false; // Ice Face protection is intact
  Move? gorillaTacticsLockedMove; // The locked move for Gorilla Tactics
  bool gorillaTacticsActive =
      false; // Gorilla Tactics is active (restricts moves)
  bool ripenActive = false; // Set externally based on ability possession
  bool neutralizingGasActive = false; // Disable all other abilities
  bool hasEatenBerry =
      false; // Tracks berry consumption for Power of Alchemy etc

  // Complex Move States
  bool isBiding = false;
  int bideDamage = 0;
  int bideTurns = 0;
  bool isBurnedUp = false;
  bool isDestinyBondActive = false;
  bool isEnduring = false;
  bool isElectrified = false;
  bool isForesighted = false;
  bool hasForestsCurse = false;
  bool grudgeActive = false;
  bool isIngrained = false;
  int yawnTurns = 0;

  String get displaySprite => isDisguised && disguisedAs != null
      ? disguisedAs!.baseOrganism.sprite
      : organism.baseOrganism.sprite;

  String get displayBaseName => isDisguised && disguisedAs != null
      ? disguisedAs!.baseOrganism.name
      : organism.baseOrganism.name;

  String get displayName => isDisguised && disguisedAs != null
      ? (isOpponent
            ? 'Foe ${disguisedAs!.baseOrganism.name}'
            : disguisedAs!.baseOrganism.name)
      : name;

  String get displayCategory => isDisguised && disguisedAs != null
      ? disguisedAs!.baseOrganism.category
      : organism.baseOrganism.category;

  List<String> get displayTypes => isDisguised && disguisedAs != null
      ? disguisedAs!.baseOrganism.types
      : organism.baseOrganism.types;

  final Set<String> revealedMoves = {};

  final bool isRogueMode;
  final bool isOpponent;
  bool get isPlayer => !isOpponent;
  int level;
  final int? _atLevel;

  BattleOrganism(
    this.organism, {
    this.isRogueMode = false,
    this.isOpponent = false,
    int? atLevel,
  }) : _atLevel = atLevel,
       level = atLevel ?? organism.level,
       _statusEffects = List.from(organism.statusEffects),
       _baseAbilities = organism.abilities
           .map((name) => Ability.findByName(name))
           .where((a) => a != null)
           .cast<Ability>()
           .toList(),
       _attackStage = organism.attackStage,
       _defenseStage = organism.defenseStage,
       _powerStage = organism.powerStage,
       _resistanceStage = organism.resistanceStage,
       _speedStage = organism.speedStage,
       _accuracyStage = organism.accuracyStage,
       _evasionStage = organism.evasionStage {
    final int battleMax = maxHealth;
    _health = organism.currentHealth.clamp(0, battleMax);
    wasSwitchedInThisTurn = true;
  }

  List<ElementalType>? _battleTypes;
  List<ElementalType> get types {
    // Prismorph overrides the type completely
    if (isPrismorphed && activeTeraType != null) {
      return [activeTeraType!];
    }

    // Multitype / Plates

    if (abilities.any((a) => a.name == 'Multitype') && _isItemValid) {
      final itemName = organism.equippedTalisman!.name.toLowerCase();
      if (itemName.contains('plate')) {
        if (itemName.contains('flame')) return [ElementalType.blaze];
        if (itemName.contains('splash')) return [ElementalType.aquatic];
        if (itemName.contains('zap')) return [ElementalType.electric];
        if (itemName.contains('meadow')) return [ElementalType.grass];
        if (itemName.contains('icicle')) return [ElementalType.cryo];
        if (itemName.contains('fist')) return [ElementalType.martial];
        if (itemName.contains('toxic')) return [ElementalType.toxic];
        if (itemName.contains('earth')) return [ElementalType.earth];
        if (itemName.contains('sky')) return [ElementalType.flying];
        if (itemName.contains('mind')) return [ElementalType.mystic];
        if (itemName.contains('insect')) return [ElementalType.arthropod];
        if (itemName.contains('stone')) return [ElementalType.rock];
        if (itemName.contains('spooky')) return [ElementalType.spectral];
        if (itemName.contains('dread')) return [ElementalType.darkness];
        if (itemName.contains('iron')) return [ElementalType.metal];
        if (itemName.contains('pixie')) return [ElementalType.aura];
      }
    }

    List<ElementalType> finalTypes =
        _battleTypes ?? List.from(organism.baseOrganism.elementalTypes);

    // Burn Up removes Fire typing
    if (isBurnedUp) {
      finalTypes.remove(ElementalType.blaze);
    }

    // Forest's Curse adds Grass typing
    if (hasForestsCurse && !finalTypes.contains(ElementalType.grass)) {
      finalTypes.add(ElementalType.grass);
    }

    return finalTypes.isEmpty ? [ElementalType.basic] : finalTypes;
  }

  set battleTypes(List<ElementalType> value) => _battleTypes = value;

  bool get _isItemValid =>
      organism.equippedTalisman != null &&
      !talismanConsumed &&
      itemDisabledTurns <= 0 &&
      !organism.equippedTalisman!.name.contains('(used)');

  bool get isGrounded {
    if (types.contains(ElementalType.flying)) return false;
    if (abilities.any((a) => a.name == 'True Flight' || a.name == 'Levitate')) {
      return false;
    }
    if (_isItemValid) {
      if (organism.equippedTalisman!.effects.any(
        (e) => e.type == TalismanEffectType.airBalloon,
      )) {
        return false;
      }
    }
    return true;
  }

  // Helper for stat stage multipliers (e.g., +1 stage is 1.5x)
  static double _getStatStageMultiplier(int stage) {
    if (stage > 0) return (2 + stage) / 2;
    if (stage < 0) return 2 / (2 + stage.abs());
    return 1.0;
  }

  // This will be replaced by property-based logic in next phase
  double getAbilityStatMultiplier(String statName) {
    double totalMultiplier = 1.0;
    for (final ability in abilities) {
      // Relaxed trigger check: If targetStat matches, we likely want to process it here
      // especially for test abilities that might have 'none' trigger
      if (ability.trigger != AbilityTrigger.onCalculateStat &&
          ability.trigger != AbilityTrigger.none) {
        continue;
      }
      if (ability.targetStat != statName) {
        continue;
      }

      // Skip hardcoded conditional checks for now as they depend on BattleManager global state
      // We will properly implement this with the new trigger system
      if (ability.conditions.isEmpty &&
          !const [
            'Iron Fist',
            'Strong Jaw',
            'Tough Claws',
            'Sand Rush',
            'Swift Swim',
            'Slush Rush',
            'Chlorophyll',
            'Surge Surfer',
            'Toxic Boost',
            'Flare Boost',
            'Guts',
            'Marvel Scale',
            'Quick Feet',
            'Solar Power',
            'Sand Force',
            'Big Pecks',
            'Analytic',
            'Illusion',
          ].contains(ability.name)) {
        totalMultiplier *= ability.magnitude;
      }

      // --- Phase 1: Pure Stat Multipliers (No conditions or simple stat conditions) ---
      if (ability.name == 'Fur Coat' && statName == 'defense') {
        totalMultiplier *= 2.0;
      } else if ((ability.name == 'Huge Power' ||
              ability.name == 'Pure Power') &&
          statName == 'attack') {
        totalMultiplier *= 2.0;
      } else if (ability.name == 'Gorilla Tactics' && statName == 'attack') {
        totalMultiplier *= 1.5;
      } else if (ability.name == 'Hustle' &&
          (statName == 'attack' || statName == 'power')) {
        totalMultiplier *= 1.4;
      } else if (ability.name == 'Swift Hunter' && statName == 'speed') {
        totalMultiplier *= 1.2;
      } else if ((ability.name == 'Compound Eyes' ||
              ability.name == 'Compoundeyes') &&
          statName == 'accuracy') {
        totalMultiplier *= 1.3;
      } else if (ability.name == 'Illuminate' && statName == 'accuracy') {
        totalMultiplier *= 1.2;
      }

      // --- Phase 2: Status-based Multipliers ---
      if (statusEffects.isNotEmpty) {
        if (ability.name == 'Guts' && statName == 'attack') {
          totalMultiplier *= 1.5;
        } else if (ability.name == 'Marvel Scale' && statName == 'defense') {
          totalMultiplier *= 1.5;
        } else if (ability.name == 'Quick Feet' && statName == 'speed') {
          totalMultiplier *= 1.5;
        } else if (ability.name == 'Toxic Boost' &&
            statName == 'attack' &&
            statusEffects.any((se) => se.type == StatusEffectType.poison)) {
          totalMultiplier *= 1.5;
        } else if (ability.name == 'Flare Boost' &&
            statName == 'power' &&
            statusEffects.any((se) => se.type == StatusEffectType.burn)) {
          totalMultiplier *= 1.5;
        }
      }

      // --- Phase 3: Weather/Terrain Based Multipliers ---
      if (weather == Weather.sandstorm &&
          ability.name == 'Sand Rush' &&
          statName == 'speed') {
        totalMultiplier *= 1.5;
      }
      if (weather == Weather.rain &&
          ability.name == 'Swift Swim' &&
          statName == 'speed') {
        totalMultiplier *= 2.0;
      }
      if (weather == Weather.snowstorm &&
          ability.name == 'Slush Rush' &&
          statName == 'speed') {
        totalMultiplier *= 1.5;
      }
      if (weather == Weather.sunny &&
          ability.name == 'Chlorophyll' &&
          statName == 'speed') {
        totalMultiplier *= 2.0;
      }
      if (terrain == Terrain.electric &&
          ability.name == 'Surge Surfer' &&
          statName == 'speed') {
        totalMultiplier *= 1.5;
      }
    }
    return totalMultiplier;
  }

  int get currentAttack {
    double attack = organism.getAttack(atLevel: level).toDouble();
    attack *= _getStatStageMultiplier(attackStage);
    attack *= getAbilityStatMultiplier('attack');

    for (final se in statusEffects) {
      if (se.type == StatusEffectType.burn) attack *= 0.5;
      if (se.type == StatusEffectType.fear) attack *= 0.9;
    }

    // Apply talisman effects (multi-effect support)
    if (_isItemValid) {
      for (final effect in organism.equippedTalisman!.effects) {
        // Legacy support
        if (effect.type == TalismanEffectType.attackBoost) {
          attack *= effect.magnitude;
        }
        // New generic stat boost
        if (effect.type == TalismanEffectType.statBoost &&
            effect.stat == 'attack') {
          attack *= effect.magnitude;
        }
        // Choice lock boost
        if (effect.type == TalismanEffectType.choiceLock &&
            effect.stat == 'attack' &&
            isChoiceLocked) {
          attack *= effect.magnitude;
        }
      }
    }

    // Defeatist
    if (abilities.any((a) => a.name == 'Defeatist') && !isAbilitySuppressed) {
      if (health <= (maxHealth / 3)) {
        attack = attack * 0.5;
      }
    }

    return attack.round();
  }

  int get currentDefense {
    int baseDefense = organism.getDefense(atLevel: level);
    double defense = (baseDefense * _getStatStageMultiplier(defenseStage))
        .toDouble();
    defense *= getAbilityStatMultiplier('defense');

    for (final se in statusEffects) {
      if (se.type == StatusEffectType.fear) defense *= 0.9;
    }

    // Apply talisman effects
    if (_isItemValid) {
      for (final effect in organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.defenseBoost) {
          defense *= effect.magnitude;
        }
        if (effect.type == TalismanEffectType.statBoost &&
            effect.stat == 'defense') {
          defense *= effect.magnitude;
        }
      }
    }
    return defense.round();
  }

  int get currentPower {
    double power = organism.getPower(atLevel: level).toDouble();
    power *= _getStatStageMultiplier(powerStage);
    power *= getAbilityStatMultiplier('power');

    for (final se in statusEffects) {
      if (se.type == StatusEffectType.fear) power *= 0.9;
    }

    // Apply talisman effects
    if (_isItemValid) {
      for (final effect in organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.powerBoost) {
          power *= effect.magnitude;
        }
        if (effect.type == TalismanEffectType.statBoost &&
            effect.stat == 'power') {
          power *= effect.magnitude;
        }
        if (effect.type == TalismanEffectType.choiceLock &&
            effect.stat == 'power' &&
            isChoiceLocked) {
          power *= effect.magnitude;
        }
      }
    }

    // Defeatist
    if (abilities.any((a) => a.name == 'Defeatist') && !isAbilitySuppressed) {
      if (health <= (maxHealth / 3)) {
        power = power * 0.5;
      }
    }

    return power.round();
  }

  int get currentResistance {
    int baseRes = organism.getResistance(atLevel: level);
    double resistance = (baseRes * _getStatStageMultiplier(resistanceStage))
        .toDouble();
    resistance *= getAbilityStatMultiplier('resistance');

    for (final se in statusEffects) {
      if (se.type == StatusEffectType.fear) resistance *= 0.9;
    }

    // Apply talisman effects
    if (_isItemValid) {
      for (final effect in organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.resistanceStatBoost) {
          resistance *= effect.magnitude;
        }
        if (effect.type == TalismanEffectType.statBoost &&
            effect.stat == 'resistance') {
          resistance *= effect.magnitude;
        }
      }
    }
    return resistance.round();
  }

  int get currentSpeed {
    double speed = organism.getSpeed(atLevel: level).toDouble();
    speed *= getAbilityStatMultiplier('speed');
    speed *= _getStatStageMultiplier(speedStage);

    // Unburden: doubles speed if item is consumed
    if (talismanConsumed && abilities.any((a) => a.name == 'Unburden')) {
      speed *= 2.0;
    }

    // Apply talisman effects
    if (_isItemValid) {
      for (final effect in organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.speedBoost) {
          speed *= effect.magnitude;
        }
        if (effect.type == TalismanEffectType.statBoost &&
            effect.stat == 'speed') {
          speed *= effect.magnitude;
        }
        if (effect.type == TalismanEffectType.choiceLock &&
            effect.stat == 'speed' &&
            isChoiceLocked) {
          speed *= effect.magnitude;
        }
      }
    }

    for (final se in statusEffects) {
      if (se.type == StatusEffectType.fear) speed *= 0.9;
      if (se.type == StatusEffectType.paralysis) speed *= 0.25;
    }
    return speed.round();
  }

  int get maxHealth {
    int baseMax = organism.getMaxHealth(atLevel: level);
    double hp = baseMax.toDouble();

    // Apply talisman effects
    if (_isItemValid) {
      for (final effect in organism.equippedTalisman!.effects) {
        if (effect.type == TalismanEffectType.healthBoost) {
          hp *= effect.magnitude;
        }
        if (effect.type == TalismanEffectType.statBoost &&
            effect.stat == 'health') {
          hp *= effect.magnitude;
        }
      }
    }
    return hp.round();
  }
}

class BattleTurn {
  final int turnNumber;
  final List<String> logEntries = [];
  BattleTurn(this.turnNumber);
}

class AbilityNotification {
  final String animalName;
  final String abilityName;
  final bool isPlayer;

  AbilityNotification({
    required this.animalName,
    required this.abilityName,
    required this.isPlayer,
  });
}

class DamageResult {
  final int damage;
  final double typeMultiplier;
  final bool isCrit;
  const DamageResult(this.damage, this.typeMultiplier, this.isCrit);
}

class BattleStats {
  int totalKills;
  int totalDamageDealt;
  int totalDamageTaken;
  bool isItemRevealed;
  bool isAbilityRevealed;
  bool isPrismorphed;
  bool hasPrismorphedThisBattle;
  ElementalType? activeTeraType;
  final Set<String> revealedMoves;

  BattleStats({
    this.totalKills = 0,
    this.totalDamageDealt = 0,
    this.totalDamageTaken = 0,
    this.isItemRevealed = false,
    this.isAbilityRevealed = false,
    this.isPrismorphed = false,
    this.hasPrismorphedThisBattle = false,
    this.activeTeraType,
    Set<String>? revealedMoves,
  }) : revealedMoves = revealedMoves ?? {};
}
