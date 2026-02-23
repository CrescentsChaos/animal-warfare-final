import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/talisman.dart';

class BattleOrganism {
  final CapturedOrganism organism;
  final List<Ability> abilities;

  String get name => isOpponent
      ? 'Foe ${organism.baseOrganism.name}'
      : organism.baseOrganism.name;

  late int _health;
  int get health => _health;
  set health(int value) {
    _health = value;
    if (isRogueMode) {
      organism.currentHealth = value;
    } else {
      // Scale back down to the actual organism level
      final double ratio = value / maxHealth;
      final int actualMax = organism.maxHealth;
      organism.currentHealth = (actualMax * ratio).round().clamp(0, actualMax);
    }
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

  int tauntTurns = 0;
  int encoreTurns = 0;
  Move? lastMove;
  bool isImprisoning = false;

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
    // lastMove resets on switch or start of battle?
    // In Pokemon lastMove is cleared on switch.
    lastMove = null;
    isImprisoning = false;
    // We do NOT reset focusSashUsed or talismanConsumed here as they are
    // once per battle. Choice lock DOES reset on switch in Pokemon.
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
  final int level;

  BattleOrganism(
    this.organism, {
    this.isRogueMode = false,
    this.isOpponent = false,
  }) : level = isRogueMode ? organism.level : 50,
       _statusEffects = List.from(organism.statusEffects),
       abilities = organism.baseOrganism.abilities
           .split(',')
           .map((s) => s.trim())
           .where((s) => s.isNotEmpty)
           .map((name) => Ability.findByName(name))
           .where((a) => a != null)
           .cast<Ability>()
           .toList(),
       _attackStage = isRogueMode ? organism.attackStage : 0,
       _defenseStage = isRogueMode ? organism.defenseStage : 0,
       _powerStage = isRogueMode ? organism.powerStage : 0,
       _resistanceStage = isRogueMode ? organism.resistanceStage : 0,
       _speedStage = isRogueMode ? organism.speedStage : 0,
       _accuracyStage = isRogueMode ? organism.accuracyStage : 0 {
    // Initialize health based on boosted max health
    // We use a ratio to ensure health is correctly scaled between the animal's
    // actual level and the fixed level 50 baseline used in non-rogue modes.
    final int battleMax = maxHealth;

    if (isRogueMode) {
      _health = organism.currentHealth.clamp(0, battleMax);
    } else {
      final int actualMax = organism.maxHealth;
      if (organism.currentHealth >= actualMax) {
        _health = battleMax;
      } else {
        final double ratio = organism.currentHealth / actualMax;
        _health = (battleMax * ratio).round().clamp(0, battleMax);
      }
    }
  }

  List<ElementalType>? _battleTypes;
  List<ElementalType> get types =>
      _battleTypes ?? organism.baseOrganism.elementalTypes;
  set battleTypes(List<ElementalType> value) => _battleTypes = value;

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
      if (ability.conditions.isEmpty) {
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
    double attack =
        (isRogueMode
                ? organism.effectiveAttack
                : organism.getAttack(atLevel: 50))
            .toDouble();
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
    int baseDefense = isRogueMode
        ? organism.effectiveDefense
        : organism.getDefense(atLevel: 50);
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
    double power =
        (isRogueMode ? organism.effectivePower : organism.getPower(atLevel: 50))
            .toDouble();
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
    int baseRes = isRogueMode
        ? organism.effectiveResistance
        : organism.getResistance(atLevel: 50);
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
    double speed =
        (isRogueMode ? organism.effectiveSpeed : organism.getSpeed(atLevel: 50))
            .toDouble();
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
    int baseMax = isRogueMode
        ? organism.maxHealth
        : organism.getMaxHealth(atLevel: 50);
    double hp = baseMax.toDouble();

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
  int totalDamageDealt;
  int totalDamageTaken;
  bool isItemRevealed;
  bool isAbilityRevealed;
  final Set<String> revealedMoves;

  BattleStats({
    this.totalDamageDealt = 0,
    this.totalDamageTaken = 0,
    this.isItemRevealed = false,
    this.isAbilityRevealed = false,
    Set<String>? revealedMoves,
  }) : revealedMoves = revealedMoves ?? {};
}
