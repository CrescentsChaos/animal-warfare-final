// lib/models/ability.dart

enum AbilityTrigger {
  none,
  onEntry,
  onCalculateStat,
  onDamageTaken,
  onDamageDealt,
  onStatLoss,
  onCalculateDamage,
  onCalculatePriority,
  onStatusAttempt,
  onTurnEnd,
}

enum AbilityEffectType {
  none,
  statChange, // Self or Target stat change
  statusChange, // Self or Target status
  weatherChange,
  terrainChange,
  damageMultiplier,
  statMultiplier,
  priorityBoost,
  typeChange,
  preventStatLoss,
  preventStatus,
  preventCrit,
  wakeUpFaster,
}

class Ability {
  final String name;
  final String description;
  final AbilityTrigger trigger;
  final AbilityEffectType effectType;

  // Generic parameters for different effect types
  final String targetStat; // e.g., 'attack', 'defense', 'speed'
  final double magnitude; // Multiplier (e.g., 2.0) or stat stages (e.g., -1)
  final double chance; // 0.0 to 1.0
  final List<String> conditions; // e.g., 'at_full_hp', 'contact', 'poisoned'
  final String value; // e.g., 'rain', 'flying', status name

  const Ability({
    required this.name,
    required this.description,
    this.trigger = AbilityTrigger.none,
    this.effectType = AbilityEffectType.none,
    this.targetStat = '',
    this.magnitude = 1.0,
    this.chance = 1.0,
    this.conditions = const [],
    this.value = '',
  });

  static const List<Ability> allAbilities = [
    // --- Requested Abilities ---
    Ability(
      name: 'Adaptability',
      description:
          'Increases the STAB (Same Type Attack Bonus) multiplier from 1.5x to 2.0x.',
      trigger: AbilityTrigger.onCalculateDamage,
      effectType: AbilityEffectType.damageMultiplier,
      magnitude: 2.0,
      conditions: ['stab'],
    ),
    Ability(
      name: 'Anger Point',
      description: 'Maxes Attack stat if hit by a critical hit.',
      trigger: AbilityTrigger.onDamageTaken,
      effectType: AbilityEffectType.statChange,
      targetStat: 'attack',
      magnitude: 12, // Max stages
      conditions: ['crit'],
    ),
    Ability(
      name: 'Arena Trap',
      description: 'Prevents grounded opponents from fleeing.',
      trigger: AbilityTrigger.none, // Handled in flee logic check
      effectType: AbilityEffectType.none,
    ),
    Ability(
      name: 'Battle Armor',
      description: 'Protects the organism from critical hits.',
      trigger: AbilityTrigger.onDamageTaken,
      effectType: AbilityEffectType.preventCrit,
    ),
    Ability(
      name: 'Berserk',
      description: 'Boosts Attack when HP falls below 50% due to an attack.',
      trigger: AbilityTrigger.onDamageTaken,
      effectType: AbilityEffectType.statChange,
      targetStat: 'attack',
      magnitude: 1,
      conditions: ['hp_below_50'],
    ),
    Ability(
      name: 'Clear Body',
      description: 'Prevents other organisms from lowering its stats.',
      trigger: AbilityTrigger.onStatLoss,
      effectType: AbilityEffectType.preventStatLoss,
    ),
    Ability(
      name: 'Color Change',
      description:
          'Changes the organism\'s type to the type of the move it was hit by.',
      trigger: AbilityTrigger.onDamageTaken,
      effectType: AbilityEffectType.typeChange,
    ),
    Ability(
      name: 'Defiant',
      description: 'Boosts Attack by two stages when a stat is lowered.',
      trigger: AbilityTrigger.onStatLoss,
      effectType: AbilityEffectType.statChange,
      targetStat: 'attack',
      magnitude: 2,
    ),
    Ability(
      name: 'Dauntless Shield',
      description: 'Boosts Defense when entering battle.',
      trigger: AbilityTrigger.onEntry,
      effectType: AbilityEffectType.statChange,
      targetStat: 'defense',
      magnitude: 1,
    ),
    Ability(
      name: 'Drizzle',
      description: 'Summons rain when entering battle.',
      trigger: AbilityTrigger.onEntry,
      effectType: AbilityEffectType.weatherChange,
      value: 'rain',
    ),
    Ability(
      name: 'Early Bird',
      description: 'Awakens from sleep twice as fast.',
      trigger: AbilityTrigger.onTurnEnd,
      effectType: AbilityEffectType.wakeUpFaster,
    ),
    Ability(
      name: 'Poison Touch',
      description: 'May poison a target when using a contact move.',
      trigger: AbilityTrigger.onDamageDealt,
      effectType: AbilityEffectType.statusChange,
      value: 'poison',
      chance: 0.3,
      conditions: ['contact'],
    ),
    Ability(
      name: 'Poison Point',
      description: 'May poison a target on contact.',
      trigger: AbilityTrigger.onDamageTaken,
      effectType: AbilityEffectType.statusChange,
      value: 'poison',
      chance: 0.3,
      conditions: ['contact'],
    ),
    Ability(
      name: 'Fur Coat',
      description: 'Doubles the organism\'s Defense stat.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'defense',
      magnitude: 2.0,
    ),
    Ability(
      name: 'Gale Wings',
      description: 'Gives priority to Flying-type moves at full HP.',
      trigger: AbilityTrigger.onCalculatePriority,
      effectType: AbilityEffectType.priorityBoost,
      magnitude: 1,
      conditions: ['full_hp', 'type_flying'],
    ),
    Ability(
      name: 'Guts',
      description: 'Boosts Attack by 50% when having a status condition.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'attack',
      magnitude: 1.5,
      conditions: ['statused'],
    ),
    Ability(
      name: 'Intimidate',
      description: 'Lowers opponent\'s Attack when entering.',
      trigger: AbilityTrigger.onEntry,
      effectType: AbilityEffectType.statChange,
      targetStat: 'attack',
      magnitude: -1,
    ),
    Ability(
      name: 'Limber',
      description: 'Protects the organism from paralysis.',
      trigger: AbilityTrigger.onStatusAttempt,
      effectType: AbilityEffectType.preventStatus,
      value: 'paralysis',
    ),

    // --- Existing/Original Abilities ---
    Ability(
      name: 'Swift Hunter',
      description: 'Passively boosts the organism\'s speed by 20%.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'speed',
      magnitude: 1.2,
    ),
    Ability(
      name: 'Frenzy',
      description: 'Attack is boosted by 50% when HP falls below 30%.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'attack',
      magnitude: 1.5,
      conditions: ['hp_below_30'],
    ),
    Ability(
      name: 'Drought',
      description: 'Summons harsh sunlight when entering battle.',
      trigger: AbilityTrigger.onEntry,
      effectType: AbilityEffectType.weatherChange,
      value: 'sun',
    ),
    Ability(
      name: 'Electric Surge',
      description: 'Creates Electric Terrain when entering battle.',
      trigger: AbilityTrigger.onEntry,
      effectType: AbilityEffectType.terrainChange,
      value: 'electric',
    ),
    Ability(
      name: 'Sand Rush',
      description: 'Speed doubles in sandstorm.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'speed',
      magnitude: 2.0,
      conditions: ['weather_sandstorm'],
    ),
    Ability(
      name: 'Chlorophyll',
      description: 'Speed doubles in harsh sunlight.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'speed',
      magnitude: 2.0,
      conditions: ['weather_sun'],
    ),
    Ability(
      name: 'Swift Swim',
      description: 'Speed doubles in rain.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'speed',
      magnitude: 2.0,
      conditions: ['weather_rain'],
    ),
    Ability(
      name: 'Slush Rush',
      description: 'Speed doubles in snow.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'speed',
      magnitude: 2.0,
      conditions: ['weather_snow'],
    ),
    Ability(
      name: 'Cold-blooded',
      description:
          'Speed Raises by 1 stage during sunny weather and drops by 1 stage during rain or snow weather while entering the field.',
      trigger: AbilityTrigger.onEntry,
    ),
    Ability(
      name: 'Camouflage Carapace',
      description: 'In Swamp biome, user gains Stealth on entry.',
      trigger: AbilityTrigger.onEntry,
      effectType: AbilityEffectType.statusChange,
      value: 'stealth',
    ),
    Ability(
      name: 'Sticky Hold',
      description: 'Prevents the organism from being forced out of battle.',
      effectType: AbilityEffectType.none, // Handled in force-switch logic
    ),
  ];

  static Ability? findByName(String name) {
    try {
      return allAbilities.firstWhere(
        (a) => a.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
