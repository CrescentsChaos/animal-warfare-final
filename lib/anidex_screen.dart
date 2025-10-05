// lib/anidex_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/models/organism.dart'; // Ensure this path is correct

class AnidexScreen extends StatefulWidget {
  const AnidexScreen({super.key});

  @override
  State<AnidexScreen> createState() => _AnidexScreenState();
}

class _AnidexScreenState extends State<AnidexScreen> {
  // Define High-Contrast Retro/Military-themed colors
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod

  List<Organism> _allOrganisms = [];
  List<Organism> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  // Variable _autocompleteSuggestion removed
  
  @override
  void initState() {
    super.initState();
    _loadOrganisms();
    _searchController.addListener(_onSearchChanged);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  // --- Helper function to get color based on rarity ---
  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return const Color.fromARGB(255, 188, 188, 188).withOpacity(0.8);
      case 'uncommon':
        return const Color.fromARGB(255, 117, 210, 117);
      case 'rare':
        return Colors.blueAccent;
      case 'epic':
        return const Color.fromARGB(255, 169, 20, 195);
      case 'legendary':
        return Colors.orange;
      case 'mythical':
        return const Color.fromARGB(255, 229, 18, 131);
      default:
        return Colors.grey;
    }
  }
  
  // --- Data Loading & Search Logic ---
  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    try {
      final String response = await rootBundle.loadString(assetPath);
      final List<dynamic> animalsData = json.decode(response);
      
      setState(() {
        _allOrganisms = animalsData.map((json) => Organism.fromJson(json)).toList();
        _searchResults = [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data. Check JSON format and asset path. Error: $e')),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    
    if (query.isEmpty) {
      // Autocomplete removal: Only clear search results if query is empty
      setState(() { _searchResults = []; });
      return;
    }

    // Autocomplete removal: The logic to find and set suggestion is removed.
  }

  void _performSearch() {
    final query = _searchController.text.trim().toLowerCase();
    
    // Autocomplete removal: Logic for handling _autocompleteSuggestion is removed.
    
    if (query.isEmpty) { setState(() { _searchResults = []; }); return; }
    
    setState(() {
      _searchResults = _allOrganisms.where(
        (org) => org.name.toLowerCase().contains(query) || org.scientificName.toLowerCase().contains(query)
      ).toList();

      // FIX: Sort by name descending (Z-A)
      _searchResults.sort((a, b) => a.name.compareTo(b.name));
    });
  }

  // --- UI Builders ---
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      // Autocomplete removal: Stack and the autocomplete overlay Text widget are removed.
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontFamily: 'PressStart2P',
        ),
        decoration: InputDecoration(
          hintText: 'Search Unit Name...',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.5),
            fontFamily: 'PressStart2P',
            fontSize: 16,
          ),
          filled: true,
          fillColor: secondaryButtonColor.withOpacity(0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4.0),
            borderSide: BorderSide(color: highlightColor, width: 2.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4.0),
            borderSide: BorderSide(color: highlightColor, width: 3.0),
          ),
          suffixIcon: IconButton(
            icon: const Icon(Icons.search, color: highlightColor),
            onPressed: _performSearch,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        ),
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  Widget _buildResultList() {
    if (_allOrganisms.isEmpty) {
      return const Center(child: Text('Loading Data...', style: TextStyle(color: highlightColor, fontFamily: 'PressStart2P')));
    }
    
    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return const Center(
        child: Text(
          'NO UNITS FOUND.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.red, fontFamily: 'PressStart2P', fontSize: 14),
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'SEARCH FOR A UNIT TO BEGIN.',
          textAlign: TextAlign.center,
          style: TextStyle(color: highlightColor, fontFamily: 'PressStart2P', fontSize: 14),
        ),
      );
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final organism = _searchResults[index];
        return _buildOrganismTile(organism);
      },
    );
  }
  
  Widget _buildOrganismTile(Organism organism) {
    return Card(
      color: secondaryButtonColor.withOpacity(0.9),
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: const Icon(Icons.pets, color: highlightColor),
        title: Text(
          organism.name.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontFamily: 'PressStart2P', fontSize: 16),
        ),
        subtitle: Text(
          'Rarity: ${organism.rarity}',
          style: TextStyle(color: highlightColor, fontFamily: 'PressStart2P', fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right, color: highlightColor),
        onTap: () => _showOrganismDetails(organism),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Immersive Modal Bottom Sheet for Details
  // ------------------------------------------------------------------
  void _showOrganismDetails(Organism organism) {
    Color getStatColor(int stat) {
      if (stat >= 80) return Colors.greenAccent;
      if (stat >= 60) return highlightColor;
      return Colors.redAccent;
    }

    final rarityColor = _getRarityColor(organism.rarity); // Get color once

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) {
            return Container(
              decoration: BoxDecoration(
                color: secondaryButtonColor.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: rarityColor, width: 3.0),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(0),
                children: <Widget>[
                  // 1. Header Section (Image, Name, Rarity)
                  _buildDetailsHeader(organism, rarityColor),
                  
                  // 2. Main Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description/Brief
                        _buildSectionTitle('MISSION BRIEF'),
                        const SizedBox(height: 5),
                        Text(
                          organism.description,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        
                        // General Details
                        const Divider(color: highlightColor),
                        
                        // FIX: Swapped order of Rarity and Scientific Name again
                        // The Rarity line itself is implicitly "removed" by not being here twice.
                        _buildDetailRow('Rarity:', organism.rarity, isRarity: true),
                        
                        _buildDetailRow('Habitat:', organism.habitat),
                        _buildDetailRow('Drops:', organism.drops),
                        _buildDetailRow('Category:', organism.category),

                        // Stats Section
                        const Divider(color: highlightColor),
                        _buildSectionTitle('BATTLE STATS'),
                        _buildDetailRow('HEALTH:', organism.health.toString(), statColor: getStatColor(organism.health)),
                        _buildDetailRow('ATTACK:', organism.attack.toString(), statColor: getStatColor(organism.attack)),
                        _buildDetailRow('DEFENSE:', organism.defense.toString(), statColor: getStatColor(organism.defense)),
                        _buildDetailRow('SPEED:', organism.speed.toString(), statColor: getStatColor(organism.speed)),
                        
                        // Abilities and Moves
                        const Divider(color: highlightColor),
                        _buildSectionTitle('ABILITIES & MOVES'),
                        _buildTextDetail('Abilities:', organism.abilities),
                        _buildTextDetail('Moves:', organism.moves.replaceAll(',', ', ')), 

                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- HELPER: Immersive Header ---
  Widget _buildDetailsHeader(Organism organism, Color rarityColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: rarityColor.withOpacity(0.4), 
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: const Border(bottom: BorderSide(color: highlightColor, width: 3.0)),
      ),
      child: Column(
        children: [
          // Image/Sprite
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 41, 48, 68).withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: organism.sprite.isNotEmpty 
                ? Image.network(
                    organism.sprite,
                    height: 200, 
                    width: 400, // Removed width to let Image.network respect size constraints if needed, but it's optional.
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      
                      // --- MODIFIED LOADING BUILDER: Placeholder only, no spinner ---
                      return Image.asset(
                        'assets/placeholder_400x200.png', // <-- Ensure this is your correct placeholder path
                        height: 200, // Keep height consistent
                        width: 400,  // Re-added width for placeholder consistency
                        fit: BoxFit.contain, // Changed to 'contain' to match network image fit
                      );
                      // --- END MODIFIED LOADING BUILDER ---
                    },
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red, size: 80),
                  )
                : const Icon(Icons.image_not_supported, color: Colors.grey, size: 80),
          ),
          // Name
          Text(
            organism.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(color: rarityColor, fontFamily: 'PressStart2P', fontSize: 18, height: 1.2),
          ),
          // Rarity (This is the primary display of Rarity, so we'll style it well)
          // No separate "Rarity: " label here to keep it concise, just the value styled with its color
          Text(
              organism.scientificName, // Displays the Scientific Name
              style: TextStyle(
                  color: rarityColor, 
                  fontFamily: 'PressStart2P', 
                  fontSize: 10,
                  fontStyle: FontStyle.italic, // Sets the text to italic
              ),
          ),
          // Drag handle for modal
          const SizedBox(height: 10),
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: highlightColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
              ),
          ),
        ],
      ),
    );
  }

  // --- HELPER: Section Title ---
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          color: highlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 14,
          decoration: TextDecoration.underline,
          decorationColor: highlightColor,
          decorationThickness: 2,
        ),
      ),
    );
  }
  
  // --- HELPER: Row with Expanded (Handles rarity color and italics) ---
  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, Color? statColor, bool isScientificName = false, bool isRarity = false}) {
    
    // Determine text color and style
    Color textColor = statColor ?? (isHighlight ? primaryButtonColor : Colors.white);
    
    if (isRarity) {
      textColor = _getRarityColor(value); // Use rarity color for rarity value
    }

    FontStyle fontStyle = isScientificName ? FontStyle.italic : FontStyle.normal; // Italic for scientific name

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontFamily: 'PressStart2P', fontSize: 12),
          ),
          Expanded( 
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: textColor,
                fontFamily: 'PressStart2P',
                fontSize: 12,
                fontStyle: fontStyle, // Apply font style
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER: Multi-line detail block ---
  Widget _buildTextDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontFamily: 'PressStart2P', fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ANIMAL INDEX'),
        backgroundColor: secondaryButtonColor,
        titleTextStyle: const TextStyle(color: highlightColor, fontFamily: 'PressStart2P', fontSize: 16),
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
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            _buildSearchBar(),
            Expanded(
              child: _buildResultList(),
            ),
          ],
        ),
      ),
    );
  }
}