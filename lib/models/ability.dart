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
      name: 'Poison Skin',
      description: 'May poison a target on contact.',
      trigger: AbilityTrigger.onDamageTaken,
      effectType: AbilityEffectType.statusChange,
      value: 'poison',
      chance: 0.5,
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
    Ability(
      name: 'Immunity',
      description: 'Protects the organism from poison.',
      trigger: AbilityTrigger.onStatusAttempt,
      effectType: AbilityEffectType.preventStatus,
      value: 'poison',
    ),
    Ability(
      name: 'Static',
      description: 'May paralyze a target on contact.',
      trigger: AbilityTrigger.onDamageTaken,
      effectType: AbilityEffectType.statusChange,
      value: 'paralysis',
      chance: 0.3,
      conditions: ['contact'],
    ),
    Ability(
      name: 'Flame Body',
      description: 'May burn a target on contact.',
      trigger: AbilityTrigger.onDamageTaken,
      effectType: AbilityEffectType.statusChange,
      value: 'burn',
      chance: 0.3,
      conditions: ['contact'],
    ),
    Ability(
      name: 'Spiky Body',
      description: 'May cause bleeding on contact.',
      trigger: AbilityTrigger.onDamageTaken,
      effectType: AbilityEffectType.statusChange,
      value: 'bleed',
      chance: 0.3,
      conditions: ['contact'],
    ),
    Ability(
      name: 'Comatose',
      description:
          'The organism is always asleep and cannot be inflicted with other status conditions.',
      trigger: AbilityTrigger.onStatusAttempt,
      effectType: AbilityEffectType.preventStatus,
      value: 'all', // Special value for 'all' statuses
    ),
    Ability(
      name: 'Competitive',
      description:
          'Boosts Special Attack by two stages when a stat is lowered.',
      trigger: AbilityTrigger.onStatLoss,
      effectType: AbilityEffectType.statChange,
      targetStat: 'power', // Assuming 'power' is Special Attack equivalent
      magnitude: 2,
    ),
    Ability(
      name: 'Earth Eater',
      description: 'Restores HP when hit by a Ground-type move.',
      trigger: AbilityTrigger.onDamageTaken, // Special handling in logic
      effectType: AbilityEffectType.none,
    ),
    Ability(
      name: 'Gooey',
      description: 'Lowers the speed of the attacker on contact.',
      trigger: AbilityTrigger.onDamageTaken,
      effectType: AbilityEffectType.statChange,
      targetStat: 'speed',
      magnitude: -1,
      conditions: ['contact'],
    ),
    Ability(
      name: 'Gorilla Tactics',
      description:
          'Boosts Attack but only allows the use of the first selected move.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'attack',
      magnitude: 1.5,
    ),
    Ability(
      name: 'Guard Dog',
      description: 'Prevents the effect of Intimidate and forced switching.',
      trigger: AbilityTrigger.onStatLoss,
      effectType: AbilityEffectType.preventStatLoss,
    ),
    Ability(
      name: 'Heatproof',
      description: 'Halves the damage taken from Fire-type moves.',
      trigger: AbilityTrigger.onCalculateDamage,
      effectType: AbilityEffectType.damageMultiplier,
      magnitude: 0.5,
      conditions: ['type_fire'],
    ),
    Ability(
      name: 'Huge Power',
      description: 'Doubles the Attack stat.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'attack',
      magnitude: 2.0,
    ),
    Ability(
      name: 'Hustle',
      description: 'Boosts Attack by 50% but lowers accuracy.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'attack',
      magnitude: 1.5,
    ),
    Ability(
      name: 'Hydration',
      description:
          'Cures status conditions at the end of the turn if it is raining.',
      trigger: AbilityTrigger.onTurnEnd,
      effectType: AbilityEffectType.statusChange, // Cure
      conditions: ['weather_rain'],
    ),
    Ability(
      name: 'Mimic', // Renamed Illusion
      description: 'Disguises itself as the last animal in the party.',
      trigger: AbilityTrigger.onEntry,
      effectType: AbilityEffectType.none,
    ),
    Ability(
      name: 'Insomnia',
      description: 'Prevents the organism from falling asleep.',
      trigger: AbilityTrigger.onStatusAttempt,
      effectType: AbilityEffectType.preventStatus,
      value: 'sleep',
    ),
    Ability(
      name: 'Iron Barbs',
      description: 'Damages the attacker on contact.',
      trigger: AbilityTrigger.onDamageTaken,
      effectType: AbilityEffectType.none, // Special damage logic
      conditions: ['contact'],
    ),
    Ability(
      name: 'Marvel Scale',
      description:
          'Boosts Defense by 50% if the organism has a status condition.',
      trigger: AbilityTrigger.onCalculateStat,
      effectType: AbilityEffectType.statMultiplier,
      targetStat: 'defense',
      magnitude: 1.5,
      conditions: ['statused'],
    ),
    Ability(
      name: 'Merciless',
      description: 'Attacks become critical hits if the target is poisoned.',
      trigger: AbilityTrigger.onCalculateDamage, // Crit check
      effectType: AbilityEffectType.none,
    ),
    Ability(
      name: 'Moody',
      description:
          'Raises one stat and lowers another at the end of every turn.',
      trigger: AbilityTrigger.onTurnEnd,
      effectType: AbilityEffectType.none, // Special logic
    ),
    Ability(
      name: 'Multiscale',
      description: 'Reduces damage taken when HP is full.',
      trigger: AbilityTrigger.onCalculateDamage,
      effectType: AbilityEffectType.damageMultiplier,
      magnitude: 0.5,
      conditions: ['full_hp'],
    ),
    Ability(
      name: 'Natural Cure',
      description: 'Cures status conditions upon switching out.',
      trigger: AbilityTrigger.none, // Switch logic
      effectType: AbilityEffectType.none,
    ),
    Ability(
      name: 'No Guard',
      description:
          'Ensures that all moves used by or against the organism land.',
      trigger: AbilityTrigger.none, // Accuracy logic
      effectType: AbilityEffectType.none,
    ),
    Ability(
      name: 'Overcoat',
      description: 'Protects from weather damage and powder moves.',
      trigger: AbilityTrigger.onDamageTaken, // And move logic
      effectType: AbilityEffectType.none,
    ),
    Ability(
      name: 'Parental Bond',
      description: 'Allows the organism to attack twice in one turn.',
      trigger: AbilityTrigger.onDamageDealt, // Or move execution logic
      effectType: AbilityEffectType.none,
    ),
    Ability(
      name: 'Poison Heal',
      description:
          'Restores HP if the organism is poisoned instead of losing HP.',
      trigger: AbilityTrigger.onTurnEnd, // Or status damage logic
      effectType: AbilityEffectType.none,
    ),
    Ability(
      name: 'Prankster',
      description: 'Gives priority to status moves.',
      trigger: AbilityTrigger.onCalculatePriority,
      effectType: AbilityEffectType.priorityBoost,
      magnitude: 1,
      conditions: ['move_category_status'],
    ),
    Ability(
      name: 'Reckless',
      description: 'Boosts the power of recoil moves.',
      trigger: AbilityTrigger.onCalculateDamage,
      effectType: AbilityEffectType.damageMultiplier,
      magnitude: 1.2,
      conditions: ['move_recoil'], // Needs flag in Move
    ),
    Ability(
      name: 'Regenerator',
      description: 'Restores a little HP when withdrawn from battle.',
      trigger: AbilityTrigger.none, // Switch logic
      effectType: AbilityEffectType.none,
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
      name: 'Cornered Beast',
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
      value: 'sunny',
    ),
    Ability(
      name: 'Snow Warning',
      description: 'Summons snowstrom when entering battle.',
      trigger: AbilityTrigger.onEntry,
      effectType: AbilityEffectType.weatherChange,
      value: 'snowstorm',
    ),
    Ability(
      name: 'Sand Stream',
      description: 'Summons sandstorm when entering battle.',
      trigger: AbilityTrigger.onEntry,
      effectType: AbilityEffectType.weatherChange,
      value: 'sandstorm',
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
      name: 'Reef Camouflage',
      description: 'In Coral Reef biome, user gains Stealth on entry.',
      trigger: AbilityTrigger.onEntry,
      effectType: AbilityEffectType.statusChange,
      value: 'stealth',
    ),
    Ability(
      name: 'Sticky Hold',
      description: 'Prevents the organism from being forced out of battle.',
      effectType: AbilityEffectType.none, // Handled in force-switch logic
    ),
    Ability(
      name: 'True Flight',
      description:
          'Grants all offensive advantages of Flying type but ignores their disadvantages.',
      effectType: AbilityEffectType.none, // Handled in battle logic
    ),
    Ability(
      name: 'Abyss Dweller',
      description:
          'Prevents moves that force a switch and grants immunity to Stun status.',
      trigger: AbilityTrigger.onStatusAttempt,
      effectType: AbilityEffectType.preventStatus,
      value: 'stun',
    ),
    Ability(
      name: 'Echolocation',
      description:
          'Prevents accuracy from being lowered and ignores enemy stealth effects.',
      effectType: AbilityEffectType.none, // Handled in battle logic
    ),
    Ability(
      name: 'Harvest',
      description:
          'May create a new Berry to replace one the organism has already used.',
      trigger: AbilityTrigger.onTurnEnd,
    ),
    Ability(
      name: 'Unburden',
      description:
          'Doubles the Speed stat if the organism\'s held item is used or lost.',
      trigger: AbilityTrigger.onCalculateStat,
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
