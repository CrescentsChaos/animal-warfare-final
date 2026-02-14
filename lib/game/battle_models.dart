import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/models/status_effect.dart';
import 'package:animal_warfare/models/move.dart';
import 'package:animal_warfare/models/elemental_type.dart';
import 'package:animal_warfare/models/talisman.dart';

class BattleOrganism {
  final CapturedOrganism organism;
  final List<Ability> abilities;
  int _health;
  int get health => _health;
  set health(int value) {
    _health = value;
    organism.currentHealth = value;
  }

  // Dynamic battle stats
  int attackStage = 0; // -6 to +6 stages
  int defenseStage = 0;
  int powerStage = 0; // NEW
  int resistanceStage = 0; // NEW
  int speedStage = 0; // Added speed stage
  int accuracyStage = 0; // Added accuracy stage

  List<StatusEffect> _statusEffects = [];
  List<StatusEffect> get statusEffects => _statusEffects;
  set statusEffects(List<StatusEffect> value) {
    _statusEffects = value;
    organism.statusEffects = value;
  }

  // Compatibility getter/setter for single status check
  StatusEffect get statusEffect {
    if (_statusEffects.isEmpty)
      return const StatusEffect(type: StatusEffectType.none);
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
  bool rechargeTurn = false; // For Hyper Beam etc
  Move? chargeMove; // For Solar Beam etc
  String? chargeStatChanges; // Stat changes to apply after charge
  Move? chargingMove; // The move currently being charged
  bool mustRecharge = false;
  int protectSuccessionCount = 0;
  bool tookDamageThisTurn = false;
  String? semiInvulnerable; // e.g., 'underground'

  final bool isRogueMode;
  final int level;

  BattleOrganism(this.organism, {this.isRogueMode = false})
    : level = isRogueMode ? organism.level : 50,
      _health =
          (isRogueMode
                  ? organism.currentHealth
                  : organism.getMaxHealth(atLevel: 50))
              .clamp(
                0,
                (isRogueMode
                    ? organism.maxHealth
                    : organism.getMaxHealth(atLevel: 50)),
              ),
      _statusEffects = List.from(organism.statusEffects),
      abilities = organism.baseOrganism.abilities
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .map((name) => Ability.findByName(name))
          .where((a) => a != null)
          .cast<Ability>()
          .toList();

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

    if (organism.equippedTalisman?.effect.type ==
        TalismanEffectType.attackBoost) {
      attack *= organism.equippedTalisman!.effect.magnitude;
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

    if (organism.equippedTalisman?.effect.type ==
        TalismanEffectType.defenseBoost) {
      defense *= organism.equippedTalisman!.effect.magnitude;
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

    if (organism.equippedTalisman?.effect.type ==
        TalismanEffectType.resistanceStatBoost) {
      resistance *= organism.equippedTalisman!.effect.magnitude;
    }
    return resistance.round();
  }

  int get currentSpeed {
    double speed =
        (isRogueMode ? organism.effectiveSpeed : organism.getSpeed(atLevel: 50))
            .toDouble();
    speed *= _getAbilityStatMultiplier('speed');
    speed *= _getStatStageMultiplier(speedStage);

    if (organism.equippedTalisman?.effect.type ==
        TalismanEffectType.speedBoost) {
      speed *= organism.equippedTalisman!.effect.magnitude;
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

    if (organism.equippedTalisman?.effect.type ==
        TalismanEffectType.healthBoost) {
      hp *= organism.equippedTalisman!.effect.magnitude;
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
