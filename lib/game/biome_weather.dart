// lib/game/biome_weather.dart
import 'dart:math';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/models/terrain.dart';

/// Maps biomes to weather probabilities and default terrains
class BiomeWeatherTable {
  /// Returns a random weather for the given biome based on probability
  static Weather getRandomWeatherForBiome(String biomeName) {
    final random = Random();
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
          Weather.clear: 60,
          Weather.heatwave: 30,
          Weather.sandstorm: 10,
        };
        
      case 'savanna':
        return {
          Weather.clear: 70,
          Weather.heatwave: 20,
          Weather.rain: 10,
        };
        
      case 'ocean':
      case 'deep sea':
        return {
          Weather.rain: 40,
          Weather.heavyRain: 30,
          Weather.clear: 20,
          Weather.thunderstorm: 10,
        };
        
      case 'polar':
      case 'frozen ocean':
        return {
          Weather.snow: 50,
          Weather.blizzard: 30,
          Weather.clear: 20,
        };
        
      case 'rainforest':
      case 'jungle':
        return {
          Weather.rain: 60,
          Weather.heavyRain: 20,
          Weather.clear: 15,
          Weather.thunderstorm: 5,
        };
        
      case 'swamp':
      case 'mangrove':
        return {
          Weather.rain: 50,
          Weather.fog: 30,
          Weather.clear: 20,
        };
        
      case 'coastal':
      case 'river':
      case 'lake':
        return {
          Weather.clear: 40,
          Weather.drizzle: 35,
          Weather.rain: 15,
          Weather.fog: 10,
        };
        
      case 'cave':
        return {
          Weather.clear: 80,
          Weather.fog: 20,
        };
        
      case 'mountain':
        return {
          Weather.clear: 30,
          Weather.windstorm: 30,
          Weather.snow: 20,
          Weather.fog: 20,
        };
        
      case 'taiga':
        return {
          Weather.snow: 40,
          Weather.clear: 30,
          Weather.blizzard: 20,
          Weather.fog: 10,
        };
        
      case 'urban':
        return {
          Weather.clear: 70,
          Weather.rain: 20,
          Weather.fog: 10,
        };
        
      case 'volcano':
        return {
          Weather.heatwave: 60,
          Weather.clear: 30,
          Weather.sandstorm: 10,
        };
        
      case 'tundra':
        return {
          Weather.snow: 50,
          Weather.blizzard: 30,
          Weather.clear: 20,
        };
      
      case 'coral reef':
      case 'kelp forest':
        return {
          Weather.clear: 50,
          Weather.drizzle: 30,
          Weather.rain: 20,
        };
        
      // Default for unknown biomes
      default:
        return {
          Weather.clear: 100,
        };
    }
  }
}
