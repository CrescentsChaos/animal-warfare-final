// lib/explore_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/models/organism.dart'; // Must import the model
import 'biome_detail_screen.dart'; // <<< ADDED IMPORT for navigation

// --- Biome Spawning Logic (Uses Organism.habitat and Organism.rarity) ---

/// Maps rarity string to a weight integer. Higher weight means higher probability.
int _getRarityWeight(String rarity) {
// ... (Logic remains the same)
  switch (rarity.toLowerCase()) {
    case 'common':
      return 50;
    case 'uncommon':
      return 35;
    case 'rare':
      return 20;
    case 'epic':
      return 10;
    case 'legendary':
      return 5;
    case 'mythical':
      return 1;
    default:
      return 1; 
  }
}

/// Selects a random organism from the biome by filtering on Organism.habitat 
/// and weighting by Organism.rarity.
Organism? getWeightedRandomOrganism(String biomeName, List<Organism> allOrganisms) {
// ... (Logic remains the same)
  // Normalize the selected biome name for case-insensitive search
  final String searchBiome = biomeName.toLowerCase();

  // 1. Filter organisms by habitat, handling multi-habitat strings
  final List<Organism> habitatOrganisms = allOrganisms
      .where((org) {
        // Split the habitat string by comma, trim spaces, and convert all parts to lowercase
        final List<String> organismHabitats = org.habitat
            .split(',')
            .map((h) => h.trim().toLowerCase())
            .toList();
        
        // Check if the current biomeName is in the organism's list of habitats
        return organismHabitats.contains(searchBiome);
      })
      .toList();

  if (habitatOrganisms.isEmpty) {
    return null; 
  }

  // 2. Create a list of organisms with their calculated weights
  final List<({Organism organism, int weight})> weightedSpawns = habitatOrganisms
      .map((org) => (organism: org, weight: _getRarityWeight(org.rarity)))
      .toList();

  // 3. Calculate total weight
  final int totalWeight = weightedSpawns.fold(0, (sum, item) => sum + item.weight);

  if (totalWeight <= 0) return null;

  // 4. Weighted random selection
  int randomWeight = Random().nextInt(totalWeight);
  
  for (final spawn in weightedSpawns) {
    randomWeight -= spawn.weight;
    if (randomWeight < 0) {
      return spawn.organism; // Return the full Organism object
    }
  }
  
  return null;
}
// ----------------------------------------------------------------------


class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); 
  static const Color highlightColor = Color(0xFFDAA520); 
  static const Color primaryButtonColor = Color(0xFF38761D); 
  
  List<Organism> _allOrganisms = [];
  bool _isLoading = true;

  final List<String> biomes = const [
    'Swamp', 'Savanna', 'Desert', 'Taiga', 'Mountain', 'Coastal', 
    'Volcano', 'Cave', 'Urban', 'Polar', 'Ocean', 'Deep Sea', 
    'Coral Reef', 'Rainforest', 'Kelp Forest', 'Mangrove', 
    'Frozen Ocean', 'River', 'Lake', 'Tundra', 'Jungle'
  ];
  
  @override
  void initState() {
    super.initState();
    _loadOrganisms();
  }
  
  @override
  void dispose() {
    super.dispose();
  }

  // --- Data Loading Logic ---
  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> animalsData = json.decode(response);
      
      setState(() {
        _allOrganisms = animalsData.map((json) => Organism.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading organism data. Error: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper function to generate the local asset path
  String _getAssetPath(String biomeName) {
    final fileName = biomeName.toLowerCase().replaceAll(' ', '_');
    return 'assets/biomes/$fileName.png';
  }

  // --- Encounter Modal Function (REMOVED) ---
  // The _showEncounterModal function is removed as the logic is now handled 
  // in BiomeDetailScreen.

  void _navigateToBiome(BuildContext context, String biomeName) {
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data is still loading, please wait.')),
      );
      return;
    }
    
    // --- MODIFIED: Navigate to BiomeDetailScreen ---
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BiomeDetailScreen(
          biomeName: biomeName,
          allOrganisms: _allOrganisms,
        ),
      ),
    );
    // The previous encounter finding logic is removed.
  }

  Widget _buildBiomeButton(BuildContext context, String biome) {
    final assetPath = _getAssetPath(biome);

    return Card(
      color: secondaryButtonColor.withOpacity(0.95),
      elevation: 5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: const BorderSide(color: highlightColor, width: 2.0),
      ),
      child: InkWell(
        onTap: () => _navigateToBiome(context, biome),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 1. Local Asset Image
            Image.asset(
                assetPath,
                fit: BoxFit.cover,
                colorBlendMode: BlendMode.darken,
                color: Colors.black.withOpacity(0.6), 
                errorBuilder: (context, error, stackTrace) => Container(
                  color: secondaryButtonColor.withOpacity(0.5),
                  alignment: Alignment.center,
                  child: Text(
                    'MISSING: $assetPath',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red, fontSize: 10),
                  ),
                ),
              ),

            // 2. Text Overlay
            Center(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  biome.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: highlightColor,
                    fontFamily: 'PressStart2P',
                    fontSize: 12,
                    shadows: [
                      Shadow(
                        offset: Offset(1.0, 1.0),
                        blurRadius: 3.0,
                        color: Colors.black,
                      ),
                    ],
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
          fontSize: 16
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: secondaryButtonColor,
          image: DecorationImage(
            image: const AssetImage('assets/main.png'), 
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.7),
              BlendMode.darken,
            ),
          ),
        ),
        padding: const EdgeInsets.all(10.0),
        child: _isLoading 
            ? const Center(
                child: CircularProgressIndicator(color: highlightColor)
              )
            : GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, 
                  childAspectRatio: 1.5, 
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: biomes.length,
                itemBuilder: (context, index) {
                  return _buildBiomeButton(context, biomes[index]);
                },
              ),
      ),
    );
  }
}