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