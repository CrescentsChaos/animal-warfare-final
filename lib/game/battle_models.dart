import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/talisman.dart';

class BattleOrganism {
  CapturedOrganism organism;
  final List<Ability> abilities;

  String get name => isOpponent
      ? 'Foe ${organism.baseOrganism.name}'
      : organism.baseOrganism.name;

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
  Move? lastMove;
  bool isImprisoning = false;
  Move? rolloutMove;

  /// Reset battle-specific flags (called when switching out or starting battle)
  void resetBattleState() {
    isChoiceLocked = false;
    lockedMove = null;
    isProtected = false;
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

    // Advanced move state reset
    substituteHealth = 0;
    rolloutTurnCount = 0;
    usedDefenseCurl = false;
    futureSightTurns = 0;
    futureSightDamage = 0;
    rolloutMove = null;
    laserFocusTurns = 0;
    focusEnergyActive = false;
    thrashTurnCount = 0;
    thrashMove = null;
    throatChopTurns = 0;
    clampingTurns = 0;
    isFirstTurnOutOfBall = true;
    wishTurns = 0;
    wishHealAmount = 0;
    healBlockTurns = 0;
    glaiveRushVulnerable = false;
    shellTrapActive = false;
    movesUsedInBattle.clear();
    lastPhysicalDamageTaken = 0;
    lastSpecialDamageTaken = 0;
    focusPunchFailed = false;
    statsLoweredThisTurn = false;
    isMiracleEyed = false;
    shellTrapTriggered = false;
    lastMoveName = null;

    // GIMMICK RESET: Titanize ends on switch, Prismorph persists.
    isTitanized = false;
    titanizeTurnsLeft = 0;
    // NOTE: isPrismorphed/hasTitanized/hasPrismorph/activeTeraType are NOT reset here;
    // they persist for the entire battle.
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

  // ============================================================
  // GIMMICK STATE: Titanize (Dynamax) and Prismorph (Terastalize)
  // ============================================================
  bool isTitanized = false;
  int titanizeTurnsLeft = 0;
  bool hasTitanizedThisBattle = false;
  bool isPrismorphed = false;
  bool hasPrismorphedThisBattle = false;
  ElementalType? activeTeraType; // set when Prismorph activates

  // New state variables for advanced mechanics
  int? perishTurnCount;
  bool isTrapped = false; // For trapping effects like Mean Look
  int throatChopTurns = 0;
  int clampingTurns = 0;
  bool isFirstTurnOutOfBall = true;

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
  bool helpingHandBoosted = false;
  bool isFollowMeTarget = false;
  String? lastMoveName;

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
       abilities = organism.abilities
           .map((name) => Ability.findByName(name))
           .where((a) => a != null)
           .cast<Ability>()
           .toList(),
       _attackStage = isRogueMode ? organism.attackStage : 0,
       _defenseStage = isRogueMode ? organism.defenseStage : 0,
       _powerStage = isRogueMode ? organism.powerStage : 0,
       _speedStage = isRogueMode ? organism.speedStage : 0,
       _accuracyStage = isRogueMode ? organism.accuracyStage : 0 {
    final int battleMax = maxHealth;
    _health = organism.currentHealth.clamp(0, battleMax);
  }

  List<ElementalType>? _battleTypes;
  List<ElementalType> get types {
    // Prismorph overrides the type completely
    if (isPrismorphed && activeTeraType != null) {
      return [activeTeraType!];
    }
    return _battleTypes ?? organism.baseOrganism.elementalTypes;
  }

  set battleTypes(List<ElementalType> value) => _battleTypes = value;

  bool get isGrounded {
    if (types.contains(ElementalType.flying)) return false;
    if (abilities.any((a) => a.name == 'True Flight' || a.name == 'Levitate'))
      return false;
    if (organism.equippedTalisman != null && !talismanConsumed) {
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
  double _getAbilityStatMultiplier(String statName) {
    double totalMultiplier = 1.0;
    for (final ability in abilities) {
      if (ability.trigger != AbilityTrigger.onCalculateStat ||
          ability.targetStat != statName) {
        continue;
      }

      // Skip hardcoded conditional checks for now as they depend on BattleManager global state
      // We will properly implement this with the new trigger system
      if (ability.conditions.isEmpty &&
          ability.name != 'Iron Fist' &&
          ability.name != 'Strong Jaw' &&
          ability.name != 'Tough Claws') {
        totalMultiplier *= ability.magnitude;
      }

      // --- Batch 2 Ability Logic ---
      if (ability.name == 'Fur Coat' && statName == 'defense') {
        totalMultiplier *= 2.0;
      } else if (ability.name == 'Huge Power' && statName == 'attack') {
        totalMultiplier *= 2.0;
      } else if (ability.name == 'Gorilla Tactics' && statName == 'attack') {
        totalMultiplier *= 1.5;
      } else if (ability.name == 'Hustle' && statName == 'attack') {
        totalMultiplier *= 1.5;
      } else if (ability.name == 'Guts' &&
          statName == 'attack' &&
          statusEffects.isNotEmpty) {
        totalMultiplier *= 1.5;
      } else if (ability.name == 'Marvel Scale' &&
          statName == 'defense' &&
          statusEffects.isNotEmpty) {
        totalMultiplier *= 1.5;
      }
    }
    return totalMultiplier;
  }

  int get currentAttack {
    double attack = organism.getAttack(atLevel: level).toDouble();
    attack *= _getStatStageMultiplier(attackStage);
    attack *= _getAbilityStatMultiplier('attack');

    for (final se in statusEffects) {
      if (se.type == StatusEffectType.burn) attack *= 0.5;
      if (se.type == StatusEffectType.fear) attack *= 0.9;
    }

    // Apply talisman effects (multi-effect support)
    if (organism.equippedTalisman != null) {
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
    return attack.round();
  }

  int get currentDefense {
    int baseDefense = organism.getDefense(atLevel: level);
    double defense = (baseDefense * _getStatStageMultiplier(defenseStage))
        .toDouble();
    defense *= _getAbilityStatMultiplier('defense');

    for (final se in statusEffects) {
      if (se.type == StatusEffectType.fear) defense *= 0.9;
    }

    // Apply talisman effects
    if (organism.equippedTalisman != null) {
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
    power *= _getAbilityStatMultiplier('power');

    for (final se in statusEffects) {
      if (se.type == StatusEffectType.fear) power *= 0.9;
    }

    // Apply talisman effects
    if (organism.equippedTalisman != null) {
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
    return power.round();
  }

  int get currentResistance {
    int baseRes = organism.getResistance(atLevel: level);
    double resistance = (baseRes * _getStatStageMultiplier(resistanceStage))
        .toDouble();
    resistance *= _getAbilityStatMultiplier('resistance');

    for (final se in statusEffects) {
      if (se.type == StatusEffectType.fear) resistance *= 0.9;
    }

    // Apply talisman effects
    if (organism.equippedTalisman != null) {
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
    speed *= _getAbilityStatMultiplier('speed');
    speed *= _getStatStageMultiplier(speedStage);

    // Unburden: doubles speed if item is consumed
    if (talismanConsumed && abilities.any((a) => a.name == 'Unburden')) {
      speed *= 2.0;
    }

    // Apply talisman effects
    if (organism.equippedTalisman != null) {
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

    // Titanize doubles max HP
    if (isTitanized) hp *= 2.0;

    // Apply talisman effects
    if (organism.equippedTalisman != null) {
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
  final Set<String> revealedMoves;

  BattleStats({
    this.totalKills = 0,
    this.totalDamageDealt = 0,
    this.totalDamageTaken = 0,
    this.isItemRevealed = false,
    this.isAbilityRevealed = false,
    Set<String>? revealedMoves,
  }) : revealedMoves = revealedMoves ?? {};
}
