// lib/models/talisman.dart

enum TalismanEffectType {
  attackBoost,
  defenseBoost,
  speedBoost,
  healthBoost,
  damageMultiplier,
  resistanceBoost, // This is current 20% reduction
  powerBoost,      // NEW: Power stat boost
  resistanceStatBoost, // NEW: Resistance stat boost
  critBoost,
}

class TalismanEffect {
  final TalismanEffectType type;
  final double magnitude;

  const TalismanEffect({
    required this.type,
    required this.magnitude,
  });
}

class Talisman {
  final String id;
  final String name;
  final String description;
  final TalismanEffect effect;

  const Talisman({
    required this.id,
    required this.name,
    required this.description,
    required this.effect,
  });

  // Predefined talismans
  static const List<Talisman> allTalismans = [
    Talisman(
      id: 'strength_charm',
      name: 'Strength Charm',
      description: 'Increases attack power by 20%.',
      effect: TalismanEffect(type: TalismanEffectType.attackBoost, magnitude: 1.2),
    ),
    Talisman(
      id: 'iron_ward',
      name: 'Iron Ward',
      description: 'Increases defense by 25%.',
      effect: TalismanEffect(type: TalismanEffectType.defenseBoost, magnitude: 1.25),
    ),
    Talisman(
      id: 'swift_rune',
      name: 'Swift Rune',
      description: 'Increases speed by 30%.',
      effect: TalismanEffect(type: TalismanEffectType.speedBoost, magnitude: 1.3),
    ),
    Talisman(
      id: 'vitality_stone',
      name: 'Vitality Stone',
      description: 'Increases max health by 15%.',
      effect: TalismanEffect(type: TalismanEffectType.healthBoost, magnitude: 1.15),
    ),
    Talisman(
      id: 'power_crystal',
      name: 'Power Crystal',
      description: 'All attacks deal 15% more damage.',
      effect: TalismanEffect(type: TalismanEffectType.damageMultiplier, magnitude: 1.15),
    ),
    Talisman(
      id: 'guardian_shell',
      name: 'Guardian Shell',
      description: 'Reduces incoming damage by 20%.',
      effect: TalismanEffect(type: TalismanEffectType.resistanceBoost, magnitude: 0.8),
    ),
    Talisman(
      id: 'lucky_claw',
      name: 'Lucky Claw',
      description: 'Increases critical hit chance by 10%.',
      effect: TalismanEffect(type: TalismanEffectType.critBoost, magnitude: 10.0),
    ),
  ];

  static Talisman? findById(String id) {
    try {
      return allTalismans.firstWhere((talisman) => talisman.id == id);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
  };

  factory Talisman.fromJson(Map<String, dynamic> json) {
    return findById(json['id'] as String) ?? allTalismans[0];
  }
}
