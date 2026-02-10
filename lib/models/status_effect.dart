// lib/models/status_effect.dart

enum StatusEffectType {
  none,
  poison,
  burn,
  sleep,
  paralysis,
  freeze,
  bleed,      // DoT, heavy
  confusion,  // Chance to hit self
  blind,      // Lower accuracy
  regen,      // Heal over time
  vulnerable, // Take extra damage
  stun,       // Skip turn (1 turn usually)
}

class StatusEffect {
  final StatusEffectType type;
  final int duration; // -1 for indefinite

  const StatusEffect({
    required this.type,
    this.duration = -1,
  });

  String get name {
    switch (type) {
      case StatusEffectType.poison: return 'Poison';
      case StatusEffectType.burn: return 'Burn';
      case StatusEffectType.sleep: return 'Sleep';
      case StatusEffectType.paralysis: return 'Paralysis';
      case StatusEffectType.freeze: return 'Freeze';
      case StatusEffectType.bleed: return 'Bleed';
      case StatusEffectType.confusion: return 'Confusion';
      case StatusEffectType.blind: return 'Blind';
      case StatusEffectType.regen: return 'Regen';
      case StatusEffectType.vulnerable: return 'Vulnerable';
      case StatusEffectType.stun: return 'Stunned';
      default: return 'None';
    }
  }

  String get startMessage {
    switch (type) {
      case StatusEffectType.poison: return 'was poisoned!';
      case StatusEffectType.burn: return 'was burned!';
      case StatusEffectType.sleep: return 'fell asleep!';
      case StatusEffectType.paralysis: return 'is paralyzed! It may be unable to move!';
      case StatusEffectType.freeze: return 'was frozen solid!';
      case StatusEffectType.bleed: return 'is bleeding profusely!';
      case StatusEffectType.confusion: return 'became confused!';
      case StatusEffectType.blind: return 'was blinded!';
      case StatusEffectType.regen: return 'started regenerating health!';
      case StatusEffectType.vulnerable: return 'became vulnerable to attacks!';
      case StatusEffectType.stun: return 'was stunned!';
      default: return '';
    }
  }
}
