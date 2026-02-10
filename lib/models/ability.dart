// lib/models/ability.dart

enum AbilityEffectType {
  none,
  passiveStatBoost,  // Always boosts a specific stat (e.g., Swift Hunter)
  onLowHP,           // Triggers when HP is low (e.g., Frenzy)
  onBattleStart,     // Triggers at start (e.g., Intimidate)
  onTurnEnd,         // Triggers at end of turn (e.g., Shed Skin)
  weatherChange,     // Changes weather on entry
  terrainChange,     // Changes terrain on entry
  statusImmunity,    // Immune to specific status
  weatherBoost,      // Stat boost in specific weather
  weatherImmunity,   // No damage from weather
  weatherHeal,       // Heal each turn in specific weather
  terrainBoost,      // Stat boost on specific terrain
}

class Ability {
  final String name;
  final String description;
  final AbilityEffectType effectType;
  final String targetStat; // e.g., 'attack', 'speed'
  final double magnitude;  // e.g., 1.2 for a 20% boost

  const Ability({
    required this.name,
    required this.description,
    required this.effectType,
    this.targetStat = '',
    this.magnitude = 0.0,
  });

  // Example list of abilities (in a real app, this would be loaded from JSON)
  static const List<Ability> allAbilities = [
    Ability(
      name: 'Swift Hunter',
      description: 'Passively boosts the organism\'s speed by 20%.',
      effectType: AbilityEffectType.passiveStatBoost,
      targetStat: 'speed',
      magnitude: 1.2,
    ),
    Ability(
      name: 'Frenzy',
      description: 'Attack is boosted by 50% when HP falls below 30%.',
      effectType: AbilityEffectType.onLowHP,
      targetStat: 'attack',
      magnitude: 1.5,
    ),
    Ability(
      name: 'Drizzle',
      description: 'Summons rain when entering battle.',
      effectType: AbilityEffectType.weatherChange,
      targetStat: 'rain',
    ),
    Ability(
      name: 'Drought',
      description: 'Summons harsh sunlight when entering battle.',
      effectType: AbilityEffectType.weatherChange,
      targetStat: 'sun',
    ),
    Ability(
      name: 'Electric Surge',
      description: 'Creates Electric Terrain when entering battle.',
      effectType: AbilityEffectType.terrainChange,
      targetStat: 'electric',
    ),
    Ability(
      name: 'Intimidate',
      description: 'Lowers opponent\'s Attack when entering.',
      effectType: AbilityEffectType.onBattleStart,
      targetStat: 'attack',
      magnitude: -1,
    ),
    // Weather-boosted abilities
    Ability(
      name: 'Sand Rush',
      description: 'Speed doubles in sandstorm.',
      effectType: AbilityEffectType.weatherBoost,
      targetStat: 'speed',
      magnitude: 2.0,
    ),
    Ability(
      name: 'Chlorophyll',
      description: 'Speed doubles in harsh sunlight.',
      effectType: AbilityEffectType.weatherBoost,
      targetStat: 'speed',
      magnitude: 2.0,
    ),
    Ability(
      name: 'Swift Swim',
      description: 'Speed doubles in rain.',
      effectType: AbilityEffectType.weatherBoost,
      targetStat: 'speed',
      magnitude: 2.0,
    ),
    Ability(
      name: 'Slush Rush',
      description: 'Speed doubles in snow.',
      effectType: AbilityEffectType.weatherBoost,
      targetStat: 'speed',
      magnitude: 2.0,
    ),
    // Weather healing/immunity
    Ability(
      name: 'Rain Dish',
      description: 'Heals 1/16 HP per turn in rain.',
      effectType: AbilityEffectType.weatherHeal,
      targetStat: 'rain',
      magnitude: 0.0625,
    ),
    Ability(
      name: 'Ice Body',
      description: 'Heals 1/16 HP per turn in snow or blizzard.',
      effectType: AbilityEffectType.weatherHeal,
      targetStat: 'snow',
      magnitude: 0.0625,
    ),
    Ability(
      name: 'Solar Power',
      description:'Boosts attack by 50% in harsh sun.',
      effectType: AbilityEffectType.weatherBoost,
      targetStat: 'attack',
      magnitude: 1.5,
    ),
  ];
  
  // Helper to find an ability by name
  static Ability? findByName(String name) {
    try {
      return allAbilities.firstWhere((a) => a.name.toLowerCase() == name.toLowerCase());
    } catch (_) {
      return null;
    }
  }
}