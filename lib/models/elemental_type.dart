enum ElementalType {
  basic, // Fallback
  flying,
  aquatic,
  earth,
  cryo,
  toxic,
  rock,
  arthropod,
  electric,
  darkness,
  martial,
  blaze,
  grass,
  mystic,
  spectral,
  drake,
  metal,
  aura,
  sound,
  holy,
}

class TypeChart {
  static double getEffectiveness(
    ElementalType moveType,
    ElementalType defenderType,
  ) {
    if (moveType == ElementalType.basic) return 1.0;

    // Define weaknesses (Attacker -> Defender = 2.0x)
    // Define resistances (Attacker -> Defender = 0.5x)

    switch (moveType) {
      case ElementalType.electric:
        if (defenderType == ElementalType.flying) return 2.0;
        if (defenderType == ElementalType.aquatic) return 2.0;
        if (defenderType == ElementalType.electric) return 0.5;
        if (defenderType == ElementalType.sound) return 2.0;
        if (defenderType == ElementalType.grass) return 0.5;
        if (defenderType == ElementalType.drake) return 0.5;
        if (defenderType == ElementalType.earth) return 0;
        break;
      case ElementalType.sound:
        if (defenderType == ElementalType.flying) return 2.0;
        if (defenderType == ElementalType.aquatic) return 2.0;
        if (defenderType == ElementalType.aura) return 2.0;
        if (defenderType == ElementalType.metal) return 0.5;
        if (defenderType == ElementalType.rock) return 0.5;
        if (defenderType == ElementalType.electric) return 0.5;
        if (defenderType == ElementalType.spectral) return 0;
        break;
      case ElementalType.arthropod:
        if (defenderType == ElementalType.grass) return 2.0;
        if (defenderType == ElementalType.flying) return 0.5;
        if (defenderType == ElementalType.rock) return 0.5;
        if (defenderType == ElementalType.blaze) return 0.5;
        if (defenderType == ElementalType.toxic) return 0.5;
        break;
      case ElementalType.blaze:
        if (defenderType == ElementalType.arthropod) return 2.0;
        if (defenderType == ElementalType.grass) return 2.0;
        if (defenderType == ElementalType.cryo) return 2.0;
        if (defenderType == ElementalType.blaze) return 0.5;
        if (defenderType == ElementalType.rock) return 0.5;
        if (defenderType == ElementalType.aquatic) return 0.5;
        if (defenderType == ElementalType.drake) return 0.5;
        break;
      case ElementalType.rock:
        if (defenderType == ElementalType.flying) return 2.0;
        if (defenderType == ElementalType.arthropod) return 2.0;
        if (defenderType == ElementalType.cryo) return 2.0;
        if (defenderType == ElementalType.earth) return 0.5;
        if (defenderType == ElementalType.martial) return 0.5;
        break;
      case ElementalType.holy:
        if (defenderType == ElementalType.spectral) return 2.0;
        if (defenderType == ElementalType.darkness) return 2.0;
        if (defenderType == ElementalType.drake) return 2.0;
        if (defenderType == ElementalType.metal) return 0.5;
        if (defenderType == ElementalType.blaze) return 0.5;
        if (defenderType == ElementalType.mystic) return 0.5;
        break;
      case ElementalType.flying:
        if (defenderType == ElementalType.arthropod) return 2.0;
        if (defenderType == ElementalType.grass) return 2.0;
        if (defenderType == ElementalType.martial) return 2.0; // Can't reach
        if (defenderType == ElementalType.rock) return 0.5;
        if (defenderType == ElementalType.sound) return 0.5;
        if (defenderType == ElementalType.electric) return 0.5;
        if (defenderType == ElementalType.cryo) return 0.5;
        break;
      case ElementalType.aquatic:
        if (defenderType == ElementalType.earth) return 2.0;
        if (defenderType == ElementalType.rock) return 2.0;
        if (defenderType == ElementalType.blaze) return 2.0;
        if (defenderType == ElementalType.aquatic) return 0.5;
        if (defenderType == ElementalType.grass) return 0.5;
        if (defenderType == ElementalType.sound) return 0.5;
        if (defenderType == ElementalType.drake) return 0.5;
        break;
      case ElementalType.metal:
        if (defenderType == ElementalType.cryo) return 2.0;
        if (defenderType == ElementalType.rock) return 2.0;
        if (defenderType == ElementalType.mystic) return 2.0;
        if (defenderType == ElementalType.holy) return 2.0;
        if (defenderType == ElementalType.aquatic) return 0.5;
        if (defenderType == ElementalType.blaze) return 0.5;
        if (defenderType == ElementalType.metal) return 0.5;
        if (defenderType == ElementalType.electric) return 0.5;
        break;
      case ElementalType.martial:
        if (defenderType == ElementalType.cryo) return 2.0;
        if (defenderType == ElementalType.rock) return 2.0;
        if (defenderType == ElementalType.basic) return 2.0;
        if (defenderType == ElementalType.darkness) return 2.0;
        if (defenderType == ElementalType.arthropod) return 0.5;
        if (defenderType == ElementalType.metal) return 2.0;
        if (defenderType == ElementalType.flying) return 0.5;
        if (defenderType == ElementalType.toxic) return 0.5;
        if (defenderType == ElementalType.spectral) return 0;
        if (defenderType == ElementalType.aura) return 0.5;
        if (defenderType == ElementalType.mystic) return 0.5;
        break;
      case ElementalType.basic:
        if (defenderType == ElementalType.rock) return 0.5;
        if (defenderType == ElementalType.metal) return 0.5;
        if (defenderType == ElementalType.spectral) return 0;
        break;
      case ElementalType.earth:
        if (defenderType == ElementalType.cryo) return 2.0; // Under armor
        if (defenderType == ElementalType.electric) return 2.0;
        if (defenderType == ElementalType.sound) return 2.0;
        if (defenderType == ElementalType.rock) return 2.0;
        if (defenderType == ElementalType.toxic) return 2.0;
        if (defenderType == ElementalType.blaze) return 2.0;
        if (defenderType == ElementalType.flying) return 0;
        if (defenderType == ElementalType.grass) return 0.5;
        if (defenderType == ElementalType.arthropod) return 0.5;
        break;
      case ElementalType.cryo:
        if (defenderType == ElementalType.flying) return 2.0;
        if (defenderType == ElementalType.grass) return 2.0;
        if (defenderType == ElementalType.drake) return 2.0;
        if (defenderType == ElementalType.earth) return 2.0;
        if (defenderType == ElementalType.sound) return 2.0;
        if (defenderType == ElementalType.blaze) return 0.5;
        if (defenderType == ElementalType.aquatic) return 0.5;
        if (defenderType == ElementalType.cryo) return 0.5;
        break;
      case ElementalType.darkness:
        if (defenderType == ElementalType.mystic) return 2.0;
        if (defenderType == ElementalType.holy) return 2.0;
        if (defenderType == ElementalType.spectral) return 2.0;
        if (defenderType == ElementalType.darkness) return 0.5;
        if (defenderType == ElementalType.martial) return 0.5;
        break;
      case ElementalType.drake:
        if (defenderType == ElementalType.drake) return 2;
        if (defenderType == ElementalType.mystic) return 0;
        if (defenderType == ElementalType.metal) return 0.5;
        break;
      case ElementalType.aura:
        if (defenderType == ElementalType.martial) return 2;
        if (defenderType == ElementalType.toxic) return 2;
        if (defenderType == ElementalType.metal) return 0.5;
        if (defenderType == ElementalType.aura) return 0.5;
        if (defenderType == ElementalType.darkness) return 0;
        break;
      case ElementalType.mystic:
        if (defenderType == ElementalType.drake) return 2;
        if (defenderType == ElementalType.toxic) return 0.5;
        if (defenderType == ElementalType.martial) return 2.0;
        if (defenderType == ElementalType.metal) return 0.5;
        if (defenderType == ElementalType.blaze) return 0.5;
        if (defenderType == ElementalType.darkness) return 2;
        if (defenderType == ElementalType.sound) return 0.5;
        break;
      case ElementalType.toxic:
        if (defenderType == ElementalType.grass) return 2;
        if (defenderType == ElementalType.holy) return 2;
        if (defenderType == ElementalType.toxic) return 0.5;
        if (defenderType == ElementalType.mystic) return 2.0;
        if (defenderType == ElementalType.metal) return 0;
        if (defenderType == ElementalType.earth) return 0.5;
        if (defenderType == ElementalType.rock) return 0.5;
        if (defenderType == ElementalType.spectral) return 0.5;
        break;
      case ElementalType.grass:
        if (defenderType == ElementalType.aquatic) return 2.0;
        if (defenderType == ElementalType.earth) return 2.0;
        if (defenderType == ElementalType.rock) return 2.0;
        if (defenderType == ElementalType.blaze) return 0.5;
        if (defenderType == ElementalType.grass) return 0.5;
        if (defenderType == ElementalType.toxic) return 0.5;
        if (defenderType == ElementalType.flying) return 0.5;
        if (defenderType == ElementalType.arthropod) return 0.5;
        if (defenderType == ElementalType.metal) return 0.5;
        if (defenderType == ElementalType.drake) return 0.5;
        break;
      case ElementalType.spectral:
        if (defenderType == ElementalType.spectral) return 2;
        if (defenderType == ElementalType.aura) return 2;
        if (defenderType == ElementalType.basic) return 0;
        if (defenderType == ElementalType.darkness) return 0.5;
        if (defenderType == ElementalType.holy) return 0;
        break;
    }
    return 1.0;
  }
}
