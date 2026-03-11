// lib/game/biome_weather.dart
import 'dart:math';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';

/// Maps biomes to weather probabilities and default terrains
class BiomeWeatherTable {
  /// Returns a random weather for the given biome based on probability
  /// If [seed] is provided, the weather generation is deterministic for that seed and biome.
  static Weather getRandomWeatherForBiome(String biomeName, {int? seed}) {
    final random = seed != null ? Random(seed ^ biomeName.hashCode) : Random();
    final roll = random.nextDouble() * 100; // 0-100

    final biome = biomeName.toLowerCase();
    double cumulative = 0;

    // Get weather probabilities for this biome
    final probabilities = _getWeatherProbabilities(biome);

    for (final entry in probabilities.entries) {
      cumulative += entry.value;
      if (roll < cumulative) {
        return entry.key;
      }
    }

    // Fallback
    return Weather.clear;
  }

  /// Returns the default terrain for a biome (if any)
  static Terrain getDefaultTerrainForBiome(String biomeName) {
    final biome = biomeName.toLowerCase();

    switch (biome) {
      case 'rainforest':
      case 'jungle':
      case 'swamp':
      case 'mangrove':
        return Terrain.grassy;
      case 'mountain':
        return Terrain.none; // Could add rocky terrain
      case 'cave':
        return Terrain.none;
      case 'urban':
        return Terrain.none;
      default:
        return Terrain.none;
    }
  }

  /// Internal: Weather probability mappings
  static Map<Weather, double> _getWeatherProbabilities(String biome) {
    switch (biome) {
      case 'desert':
        return {
          Weather.clear: 49.5,
          Weather.sunny: 30,
          Weather.sandstorm: 20,
          Weather.tornado: 0.5,
        };

      case 'savanna':
        return {
          Weather.clear: 69.5,
          Weather.sunny: 20,
          Weather.rain: 10,
          Weather.tornado: 0.5,
        };

      case 'ocean':
        return {
          Weather.rain: 39.5,
          Weather.heavyRain: 29.5,
          Weather.clear: 19.5,
          Weather.thunderstorm: 10,
          Weather.typhoon: 0.5,
          Weather.hurricane: 0.5,
          Weather.tsunami: 0.5,
        };

      case 'polar':
      case 'frozen ocean':
        return {
          Weather.snowstorm: 49.5,
          Weather.hail: 29.5,
          Weather.clear: 20,
          Weather.blizzard: 1.0,
        };

      case 'rainforest':
        return {
          Weather.rain: 59,
          Weather.heavyRain: 20,
          Weather.clear: 15,
          Weather.thunderstorm: 5,
          Weather.hurricane: 0.5,
          Weather.typhoon: 0.5,
        };
      case 'redwoods':
      case 'jungle':
        return {
          Weather.rain: 29.5,
          Weather.clear: 59.5,
          Weather.thunderstorm: 10,
          Weather.tornado: 0.5,
          Weather.typhoon: 0.5,
        };
      case 'swamp':
      case 'mangrove':
      case 'wetlands':
        return {
          Weather.rain: 39.5,
          Weather.fog: 19.5,
          Weather.clear: 29.5,
          Weather.heavyRain: 10,
          Weather.typhoon: 0.5,
          Weather.hurricane: 0.5,
          Weather.tsunami: 0.5,
        };

      case 'coastal':
      case 'river':
      case 'lake':
        return {
          Weather.clear: 39,
          Weather.rain: 49,
          Weather.fog: 10,
          Weather.typhoon: 0.5,
          Weather.tsunami: 0.5,
          Weather.hurricane: 1.0,
        };

      case 'cave':
        return {Weather.clear: 79.5, Weather.fog: 20, Weather.earthquake: 0.5};

      case 'mountain':
        return {
          Weather.clear: 29,
          Weather.windstorm: 29,
          Weather.snowstorm: 19.5,
          Weather.fog: 20,
          Weather.earthquake: 1.5,
          Weather.blizzard: 1.0,
        };

      case 'taiga':
        return {
          Weather.snowstorm: 40,
          Weather.clear: 30,
          Weather.hail: 19,
          Weather.fog: 10,
          Weather.blizzard: 1.0,
        };
      case 'plains':
      case 'urban':
        return {
          Weather.clear: 69,
          Weather.rain: 15,
          Weather.fog: 10,
          Weather.thunderstorm: 5,
          Weather.earthquake: 1.0,
        };

      case 'volcano':
        return {
          Weather.sunny: 59,
          Weather.clear: 30,
          Weather.sandstorm: 10,
          Weather.volcanoEruption: 0.5,
          Weather.earthquake: 0.5,
        };

      case 'tundra':
        return {
          Weather.snowstorm: 49.5,
          Weather.hail: 29.5,
          Weather.clear: 20,
          Weather.blizzard: 1.0,
        };

      case 'coral reef':
      case 'kelp forest':
        return {
          Weather.clear: 49.5,
          Weather.rain: 39.5,
          Weather.thunderstorm: 10,
          Weather.tsunami: 0.5,
          Weather.typhoon: 0.5,
        };

      // Default for unknown biomes
      default:
        return {Weather.clear: 100};
    }
  }
}
