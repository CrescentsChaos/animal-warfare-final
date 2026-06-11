// lib/models/terrain.dart

enum Terrain {
  none,
  electric, // Prevents Sleep
  grassy,   // Heals slightly
  misty,    // Prevents Status Effects
  psychic,  // Boosts Mystic moves
  ashenWaste, // Burns non-fire types, halves healing
}

extension TerrainExtension on Terrain {
  String get iconPath {
    switch (this) {
      case Terrain.electric:
        return 'assets/icon/electric_terrain.png';
      case Terrain.grassy:
        return 'assets/icon/grassy_terrain.png';
      case Terrain.misty:
        return 'assets/icon/misty_terrain.png';
      case Terrain.psychic:
        return 'assets/icon/psychic_terrain.png';
      case Terrain.ashenWaste:
        return 'assets/icon/ashen_waste.png';
      default:
        return '';
    }
  }

  String get name {
    return toString().split('.').last;
  }
}

class TerrainEffect {
  final Terrain terrain;
  final int duration; // in turns

  const TerrainEffect({
    required this.terrain,
    this.duration = 5,
  });

  String get description {
    switch (terrain) {
      case Terrain.electric:
        return 'An electric current runs across the battlefield!';
      case Terrain.grassy:
        return 'Grass grew on the battlefield!';
      case Terrain.misty:
        return 'Mist covered the battlefield!';
      case Terrain.psychic:
        return 'The battlefield got weird!';
      case Terrain.ashenWaste:
        return 'The battlefield turned into an Ashen Waste!';
      default:
        return '';
    }
  }

  String get endMessage {
    switch (terrain) {
      case Terrain.electric:
        return 'The electricity disappeared.';
      case Terrain.grassy:
        return 'The grass withered.';
      case Terrain.misty:
        return 'The mist lifted.';
      case Terrain.psychic:
        return 'The weirdness cleared.';
      case Terrain.ashenWaste:
        return 'The ashes blew away.';
      default:
        return '';
    }
  }
}
