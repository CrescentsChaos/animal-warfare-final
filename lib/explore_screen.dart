// lib/explore_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:animal_warfare/services/weather_service.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/models/organism.dart'; // Must import the model
import 'biome_detail_screen.dart';
import 'package:animal_warfare/local_auth_service.dart'; // ADDED: Import service
import 'package:animal_warfare/game/biome_map_data.dart'; // ADDED: For TileCategory

// --- Biome Spawning Logic (Uses Organism.habitat and Organism.rarity) ---

/// Result of a spawn attempt, carrying the organism and flags like isRare.
class SpawnResult {
  final Organism organism;
  final bool isRare;

  SpawnResult({required this.organism, this.isRare = false});
}

/// Maps rarity string to a weight integer. Higher weight means higher probability.
int _getRarityWeight(String rarity) {
  // ... (Logic remains the same)
  switch (rarity.toLowerCase()) {
    case 'common':
      return 150;
    case 'uncommon':
      return 50;
    case 'rare':
      return 30;
    case 'epic':
      return 15;
    case 'legendary':
      return 7;
    case 'mythical':
      return 1;
    default:
      return 1;
  }
}

/// Selects a random organism from the biome by filtering on Organism.habitat,
/// active_time, and weighting by Organism.rarity.
SpawnResult? getWeightedRandomOrganism(
  String biomeName,
  List<Organism> allOrganisms, {
  int accountLevel = 1,
  Map<String, int> inventory = const {},
  List<String> teamMoveNames = const [],
  required String currentTimeOfDay,
  String? encounterType, // e.g., 'water', 'tallgrass', 'land'
  String? currentTileId,
  TileCategory? currentTileCategory,
  String? biomeId,
}) {
  // Normalize the selected biome name for case-insensitive search
  final String searchBiome = (biomeId ?? biomeName).toLowerCase();
  final bool isCave = searchBiome.contains('cave');

  final hasOldRod = inventory.containsKey('old_rod');
  final hasGoodRod = inventory.containsKey('good_rod');
  final hasSuperRod = inventory.containsKey('super_rod');
  final hasSurf = teamMoveNames.contains('Surf');

  // 1. Filter organisms by biome and rarity gate
  final biomeOrganisms = allOrganisms.where((org) {
    final habitat = org.habitat.toLowerCase();
    final categories = org.category.toLowerCase();

    // Biome Check
    if (!habitat.contains(searchBiome)) return false;

    // Encounter Type Filtering
    if (encounterType != null) {
      final isAquatic =
          categories.contains('aquatic') ||
          habitat.contains('water') ||
          habitat.contains('river') ||
          habitat.contains('lake') ||
          habitat.contains('ocean') ||
          habitat.contains('sea');

      if (encounterType == 'water') {
        if (!isAquatic) return false;
      } else if (encounterType == 'tallgrass') {
        // Tallgrass usually has land/ambush creatures
        if (isAquatic &&
            !habitat.contains('swamp') &&
            !habitat.contains('marsh')) {
          return false;
        }
      } else if (encounterType == 'land') {
        if (isAquatic) return false;
      }
    }

    // Tile-specific spawning
    if (currentTileId != null &&
        org.spawnTiles != 'any' &&
        org.spawnTiles.isNotEmpty) {
      final validTiles = org.spawnTiles
          .toLowerCase()
          .split(',')
          .map((e) => e.trim())
          .toList();
      bool isMatch = false;

      // Match ID
      if (validTiles.contains(currentTileId.toLowerCase())) {
        isMatch = true;
      }

      // Match Category
      if (!isMatch && currentTileCategory != null) {
        final catName = currentTileCategory
            .toString()
            .split('.')
            .last
            .toLowerCase();
        if (validTiles.contains(catName)) {
          isMatch = true;
        }
        // Handle generic 'grass' user requested
        if (validTiles.contains('grass') &&
            (catName == 'tallgrass' || catName == 'ground')) {
          isMatch = true;
        }
      }

      if (!isMatch) return false;
    }

    // Rarity Gates
    final rarity = org.rarity.toLowerCase();
    if (rarity == 'mythical' && accountLevel < 100) return false;
    if (rarity == 'legendary' && accountLevel < 50) return false;
    if (rarity == 'epic' && accountLevel < 40) return false;
    if (rarity == 'rare' && accountLevel < 20) return false;
    if (rarity == 'uncommon' && accountLevel < 10) return false;

    // Fishing Logic
    final drops = org.drops.toLowerCase();

    final isAquaticOrg =
        categories.contains('aquatic') ||
        habitat.contains('river') ||
        habitat.contains('lake') ||
        habitat.contains('ocean') ||
        habitat.contains('coastal') ||
        habitat.contains('swamp') ||
        habitat.contains('coral') ||
        habitat.contains('mangrove');

    final isFishDrop = drops.contains('fillet') || drops.contains('shark fin');

    if (isAquaticOrg && isFishDrop && !hasSurf) {
      if (rarity == 'common') {
        if (!hasOldRod && !hasGoodRod && !hasSuperRod) return false;
      } else if (rarity == 'uncommon' || rarity == 'rare') {
        if (!hasGoodRod && !hasSuperRod) return false;
      } else if (rarity == 'epic' ||
          rarity == 'mythical' ||
          rarity == 'legendary') {
        if (!hasSuperRod) return false;
      }
    }

    // --- Active Time Filtering ---
    final activeTime = org.activeTime.toLowerCase();
    bool timeMatches = false;

    if (activeTime == 'any' || activeTime == currentTimeOfDay) {
      timeMatches = true;
    } else if (isCave && activeTime == 'night' && currentTimeOfDay == 'day') {
      timeMatches = true;
    } else if (activeTime == 'day' && currentTimeOfDay == 'night') {
      timeMatches = true;
    }

    // Rare Encounter: 5% chance to allow off-time animals
    final bool isRareEncounter = math.Random().nextDouble() < 0.05;

    if (!timeMatches && !isRareEncounter) return false;

    return true;
  }).toList();

  if (biomeOrganisms.isEmpty) return null;

  // 2. Calculate total weight
  final totalWeight = biomeOrganisms.fold<int>(
    0,
    (sum, org) => sum + _getRarityWeight(org.rarity),
  );

  if (totalWeight == 0) return null;

  // 3. Select a random weight value
  final math.Random random = math.Random();
  int randomWeight = random.nextInt(totalWeight);

  // 4. Find the organism corresponding to the random weight
  Organism? selectedOrganism;
  for (final organism in biomeOrganisms) {
    int weight = _getRarityWeight(organism.rarity);
    if (randomWeight < weight) {
      selectedOrganism = organism;
      break;
    }
    randomWeight -= weight;
  }

  // Fallback
  selectedOrganism ??= biomeOrganisms[random.nextInt(biomeOrganisms.length)];

  final activeTime = selectedOrganism.activeTime.toLowerCase();
  bool timeMatches = false;
  if (activeTime == 'any' || activeTime == currentTimeOfDay) {
    timeMatches = true;
  } else if (isCave && activeTime == 'night' && currentTimeOfDay == 'day') {
    timeMatches = true;
  }

  return SpawnResult(organism: selectedOrganism, isRare: !timeMatches);
}

// ------------------------------------------------------------------
// ExploreScreen Widget
// ------------------------------------------------------------------

class ExploreScreen extends StatefulWidget {
  // ADDED: Required fields to pass down user data and service
  final UserData currentUser;
  final LocalAuthService authService;

  const ExploreScreen({
    super.key,
    required this.currentUser, // ADDED
    required this.authService, // ADDED
  });

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  // Define colors
  static const Color secondaryButtonColor = Color(0xFF1E3F2A);
  static const Color highlightColor = Color(0xFFDAA520);

  List<Organism> _allOrganisms = [];
  List<String> biomes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // Load organisms
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> animalsData = json.decode(response);

      final loadedOrganisms = animalsData
          .map((json) => Organism.fromJson(json))
          .toList();

      // Extract unique biomes
      final uniqueBiomes = loadedOrganisms
          .map((o) => o.habitat)
          .expand(
            (habitatString) => habitatString.split(',').map((h) => h.trim()),
          )
          .where((h) => h.isNotEmpty)
          .toSet()
          .toList();

      // Sort biomes alphabetically
      uniqueBiomes.sort();

      setState(() {
        _allOrganisms = loadedOrganisms;
        biomes = uniqueBiomes;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  // UPDATED: Navigation function to BiomeDetailScreen
  void _navigateToBiomeDetail(BuildContext context, String biomeName) {
    // Pass the biome name, the full list of organisms, the current user, and the auth service
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BiomeDetailScreen(
          biomeName: biomeName,
          allOrganisms: _allOrganisms,
          currentUser: widget.currentUser, // PASSING
          authService: widget.authService, // PASSING
        ),
      ),
    );
  }

  // Helper function to get biome image path
  String _getAssetPath(String biomeName) {
    final fileName = biomeName.toLowerCase().replaceAll(' ', '_');
    return 'assets/biomes/$fileName.png';
  }

  String _getTimeOfDay() {
    final gameTime = TimeService().currentGameTime;
    final hour = gameTime.hour;
    if (hour >= 6 && hour < 17) return 'day';
    if (hour >= 17 && hour < 20) return 'evening';
    return 'night';
  }

  Widget _buildWeatherAndTemp(String biomeName) {
    final weather = WeatherService().getCurrentWeather(biomeName);
    final forecast = WeatherService().getForecast(biomeName);
    final today = forecast.first;

    IconData icon;
    Color color;

    switch (weather) {
      case Weather.clear:
        icon = Icons.wb_sunny_outlined;
        color = Colors.yellow;
        break;
      case Weather.rain:
        icon = Icons.umbrella;
        color = Colors.blue;
        break;
      case Weather.heavyRain:
        icon = Icons.beach_access;
        color = Colors.blueAccent;
        break;
      case Weather.sunny:
        icon = Icons.wb_sunny;
        color = Colors.orange;
        break;
      case Weather.snowstorm:
        icon = Icons.ac_unit;
        color = Colors.lightBlueAccent;
        break;
      case Weather.hail:
        icon = Icons.grain;
        color = Colors.white;
        break;
      case Weather.sandstorm:
        icon = Icons.waves;
        color = Colors.brown;
        break;
      case Weather.windstorm:
        icon = Icons.air;
        color = Colors.white70;
        break;
      case Weather.thunderstorm:
        icon = Icons.bolt;
        color = Colors.yellowAccent;
        break;
      case Weather.fog:
        icon = Icons.cloud_queue;
        color = Colors.grey;
        break;
      default:
        icon = Icons.wb_cloudy;
        color = Colors.white;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(
            "${today.temperatureCelsius.toStringAsFixed(0)}°C",
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'PressStart2P',
              fontSize: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiomeButton(BuildContext context, String biomeName) {
    final timeOfDay = _getTimeOfDay();

    return InkWell(
      onTap: () => _navigateToBiomeDetail(context, biomeName),
      child: Container(
        decoration: BoxDecoration(
          color: secondaryButtonColor.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: highlightColor, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Biome Image (Day/Evening/Night Filtered)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(
                _getAssetPath(biomeName),
                fit: BoxFit.cover,
                color: timeOfDay == 'day'
                    ? Colors.black.withValues(alpha: 0.3)
                    : (timeOfDay == 'evening'
                          ? Colors.orangeAccent.withValues(alpha: 0.3)
                          : Colors.indigo[900]!.withValues(alpha: 0.7)),
                colorBlendMode: timeOfDay == 'night'
                    ? BlendMode.multiply
                    : BlendMode.darken,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.red),
                  ),
                ),
              ),
            ),
            // Weather & Temp Indicator
            Positioned(
              top: 8,
              right: 8,
              child: _buildWeatherAndTemp(biomeName),
            ),
            // Text Overlay
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    biomeName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: highlightColor,
                      fontFamily: 'PressStart2P',
                      fontSize: 14,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4.0,
                          offset: Offset(2, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EXPLORE BIOMES'),
        backgroundColor: secondaryButtonColor,
        titleTextStyle: const TextStyle(
          color: highlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 16,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: secondaryButtonColor,
          image: DecorationImage(
            image: const AssetImage('assets/main.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.7),
              BlendMode.darken,
            ),
          ),
        ),
        padding: const EdgeInsets.all(10.0),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: highlightColor),
              )
            : StreamBuilder<math.Random?>(
                // Rebuild periodically or on timer if needed, but for now
                // we'll just listen to the time stream to update visuals
                stream: Stream.periodic(
                  const Duration(seconds: 60),
                ).map((_) => null),
                builder: (context, _) {
                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: biomes.length,
                    itemBuilder: (context, index) {
                      return _buildBiomeButton(context, biomes[index]);
                    },
                  );
                },
              ),
      ),
    );
  }
}
