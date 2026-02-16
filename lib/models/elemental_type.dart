enum ElementalType {
  normal, // Fallback
  flying,
  aquatic,
  ground,
  ice,
  toxic,
  rock,
  arthropod,
  electric,
  nocturnal,
  martial,
  fire,
  grass,
}

class TypeChart {
  static double getEffectiveness(
    ElementalType moveType,
    ElementalType defenderType,
  ) {
    if (moveType == ElementalType.normal) return 1.0;

    // Define weaknesses (Attacker -> Defender = 2.0x)
    // Define resistances (Attacker -> Defender = 0.5x)

    switch (moveType) {
      case ElementalType.electric:
        if (defenderType == ElementalType.flying) return 2.0;
        if (defenderType == ElementalType.aquatic) return 2.0;
        if (defenderType == ElementalType.ground) return 0;
        break;
      case ElementalType.rock:
        if (defenderType == ElementalType.flying) return 2.0;
        if (defenderType == ElementalType.arthropod) return 2.0;
        if (defenderType == ElementalType.ice) return 0.5;
        break;
      case ElementalType.flying:
        if (defenderType == ElementalType.aquatic) return 2.0; // Birds eat fish
        if (defenderType == ElementalType.arthropod) return 2.0;
        if (defenderType == ElementalType.ground) return 0.5; // Can't reach
        if (defenderType == ElementalType.ice) return 0.5;
        break;
      case ElementalType.aquatic:
        if (defenderType == ElementalType.ground) return 2.0;
        if (defenderType == ElementalType.flying) return 0.5;
        break;
      case ElementalType.ground:
        if (defenderType == ElementalType.ice) return 2.0; // Under armor
        if (defenderType == ElementalType.electric) return 2.0;
        if (defenderType == ElementalType.flying) return 0;
        if (defenderType == ElementalType.aquatic) return 0.5;
        break;
      case ElementalType.ice:
        if (defenderType == ElementalType.flying) return 2;
        break;
      default:
        break;
    }
    return 1.0;
  }
}
