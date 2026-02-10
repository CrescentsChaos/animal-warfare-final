enum ElementalType {
  normal, // Fallback
  flying,
  aquatic,
  arboreal,
  burrowing,
  armored,
  agile,
  scavenger,
  parasite,
  venomous,
  poisonous,
  social,
  solitary,
  prey,
  predator,
  tiny,
  giant,
}

class TypeChart {
  static double getEffectiveness(ElementalType moveType, ElementalType defenderType) {
    if (moveType == ElementalType.normal) return 1.0;

    // Define weaknesses (Attacker -> Defender = 2.0x)
    // Define resistances (Attacker -> Defender = 0.5x)
    
    switch (moveType) {
      case ElementalType.flying:
        if (defenderType == ElementalType.aquatic) return 2.0; // Birds eat fish
        if (defenderType == ElementalType.tiny) return 2.0; // Birds eat bugs
        if (defenderType == ElementalType.burrowing) return 0.5; // Can't reach
        if (defenderType == ElementalType.armored) return 0.5;
        break;
      case ElementalType.aquatic:
        if (defenderType == ElementalType.burrowing) return 2.0; // Floods
        if (defenderType == ElementalType.arboreal) return 0.5;
        if (defenderType == ElementalType.flying) return 0.5;
        break;
      case ElementalType.arboreal:
        if (defenderType == ElementalType.flying) return 0.5; // Birds live there
        if (defenderType == ElementalType.parasite) return 0.5;
        break;
      case ElementalType.burrowing:
        if (defenderType == ElementalType.armored) return 2.0; // Under armor
        if (defenderType == ElementalType.flying) return 0.5;
        if (defenderType == ElementalType.aquatic) return 0.5;
        break;
      case ElementalType.armored:
        if (defenderType == ElementalType.tiny) return 2.0; // Crush
        if (defenderType == ElementalType.agile) return 0.5; // Too slow
        if (defenderType == ElementalType.venomous) return 2.0; // Fangs can't pierce? Actually Venomous > Armored usually false. 
        // Let's say Armored resists Venomous
        break;
      case ElementalType.agile:
        if (defenderType == ElementalType.giant) return 2.0; // Run circles
        if (defenderType == ElementalType.flying) return 0.5;
        break;
      case ElementalType.scavenger:
        if (defenderType == ElementalType.prey) return 2.0; // Easy pickings
        if (defenderType == ElementalType.predator) return 0.5;
        break;
      case ElementalType.parasite:
        if (defenderType == ElementalType.giant) return 2.0; // More host
        if (defenderType == ElementalType.solitary) return 2.0; // No grooming
        if (defenderType == ElementalType.social) return 0.5; // Grooming
        if (defenderType == ElementalType.armored) return 0.5;
        break;
      case ElementalType.venomous:
        if (defenderType == ElementalType.giant) return 2.0; // Big target, potent toxin
        if (defenderType == ElementalType.prey) return 2.0;
        if (defenderType == ElementalType.armored) return 0.5; // Can't pierce
        break;
      case ElementalType.poisonous:
        if (defenderType == ElementalType.predator) return 2.0; // Don't eat me!
        break;
      case ElementalType.social:
        if (defenderType == ElementalType.solitary) return 2.0; // Gang up
        if (defenderType == ElementalType.giant) return 2.0; // Pack hunting
        break;
      case ElementalType.solitary:
        if (defenderType == ElementalType.social) return 0.5; // Outnumbered
        break;
      case ElementalType.prey:
        if (defenderType == ElementalType.predator) return 0.5;
        break;
      case ElementalType.predator:
        if (defenderType == ElementalType.prey) return 2.0;
        if (defenderType == ElementalType.tiny) return 0.5; // Hard to catch
        break;
      case ElementalType.tiny:
        if (defenderType == ElementalType.giant) return 2.0; // Inside/hard to hit
        if (defenderType == ElementalType.flying) return 0.5; // Eaten
        break;
      case ElementalType.giant:
        if (defenderType == ElementalType.tiny) return 0.5;
        if (defenderType == ElementalType.agile) return 0.5;
        if (defenderType == ElementalType.armored) return 2.0; // Smash
        break;
      default:
        break;
    }
    return 1.0;
  }
}
