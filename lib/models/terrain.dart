// lib/models/terrain.dart

enum Terrain {
  none,
  electric, // Prevents Sleep
  grassy,   // Heals slightly
  misty,    // Prevents Status Effects
  psychic,  // Boosts Psychic API (if we had types, for now just a placeholder)
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
      default:
        return '';
    }
  }
}
