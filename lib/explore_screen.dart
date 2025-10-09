// lib/explore_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/models/organism.dart'; // Must import the model
import 'biome_detail_screen.dart'; 
import 'package:animal_warfare/local_auth_service.dart'; // ADDED: Import service

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

  // 1. Filter organisms by biome
  final biomeOrganisms = allOrganisms.where(
    (org) => org.habitat.toLowerCase().contains(searchBiome)
  ).toList();

  if (biomeOrganisms.isEmpty) return null;

  // 2. Calculate total weight
  final totalWeight = biomeOrganisms.fold<int>(
    0, 
    (sum, org) => sum + _getRarityWeight(org.rarity)
  );

  // If total weight is 0 (shouldn't happen with default weight of 1), return null
  if (totalWeight == 0) return null;

  // 3. Select a random weight value
  final Random random = Random();
  int randomWeight = random.nextInt(totalWeight);

  // 4. Find the organism corresponding to the random weight
  for (final organism in biomeOrganisms) {
    int weight = _getRarityWeight(organism.rarity);
    if (randomWeight < weight) {
      return organism;
    }
    randomWeight -= weight;
  }
  
  // Fallback (should not be reached if totalWeight > 0)
  return biomeOrganisms[random.nextInt(biomeOrganisms.length)];
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
      
      final loadedOrganisms = animalsData.map((json) => Organism.fromJson(json)).toList();
      
      // Extract unique biomes
      final uniqueBiomes = loadedOrganisms
          .map((o) => o.habitat)
          .expand((habitatString) => habitatString.split(',').map((h) => h.trim()))
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
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

  Widget _buildBiomeButton(BuildContext context, String biomeName) {
    // ... (button UI logic remains the same)
    return InkWell(
      onTap: () => _navigateToBiomeDetail(context, biomeName), // UPDATED
      child: Container(
        decoration: BoxDecoration(
          color: secondaryButtonColor.withOpacity(0.8),
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(color: highlightColor, width: 2),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Biome Image (Faded)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(
                _getAssetPath(biomeName),
                fit: BoxFit.cover,
                // Darken the image for better text readability
                colorBlendMode: BlendMode.darken,
                color: Colors.black.withOpacity(0.5),
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.black26, 
                  child: const Center(child: Icon(Icons.broken_image, color: Colors.red)),
                ),
              ),
            ),
            // Text Overlay
            Center(
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
                    )
                  ]
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