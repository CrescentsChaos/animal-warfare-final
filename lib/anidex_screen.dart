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
  // Define High-Contrast Retro/Military-themed colors inside the State class
  static const Color primaryButtonColor = Color(0xFF38761D); // Bright Jungle Green
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); // Deep Forest Green
  static const Color highlightColor = Color(0xFFDAA520); // Goldenrod

  List<Organism> _allOrganisms = [];
  List<Organism> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();
  String _autocompleteSuggestion = '';
  
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
  
  // --- Data Loading ---
  Future<void> _loadOrganisms() async {
    const String assetPath = 'assets/Organisms.json';
    
    try {
      final String response = await rootBundle.loadString(assetPath);
      
      // FIX: Decode directly as a List, as the JSON starts with [
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

  // --- Search and Autocomplete Logic ---
  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    
    if (query.isEmpty) {
      setState(() { _autocompleteSuggestion = ''; _searchResults = []; });
      return;
    }

    final suggestion = _allOrganisms.firstWhere(
      (org) => org.name.toLowerCase().startsWith(query),
      orElse: () => Organism(name: '', scientificName: '', habitat: '', drops: '', attack: 0, defense: 0, health: 0, speed: 0, abilities: '', category: '', moves: '', sprite: '', rarity: '', description: ''),
    );
    
    setState(() {
      _autocompleteSuggestion = suggestion.name.isNotEmpty ? suggestion.name.substring(query.length) : '';
    });
  }

  void _performSearch() {
    final query = _searchController.text.trim().toLowerCase();
    
    if (_autocompleteSuggestion.isNotEmpty) {
      _searchController.text = _searchController.text + _autocompleteSuggestion;
      _searchController.selection = TextSelection.fromPosition(TextPosition(offset: _searchController.text.length));
      final fullQuery = _searchController.text.trim().toLowerCase();
      setState(() {
        _searchResults = _allOrganisms.where(
          (org) => org.name.toLowerCase().contains(fullQuery) || org.scientificName.toLowerCase().contains(fullQuery)
        ).toList();
      });
      _autocompleteSuggestion = '';
      return;
    }
    
    if (query.isEmpty) { setState(() { _searchResults = []; }); return; }
    
    setState(() {
      _searchResults = _allOrganisms.where(
        (org) => org.name.toLowerCase().contains(query) || org.scientificName.toLowerCase().contains(query)
      ).toList();
    });
  }
  
  // --- UI Builders ---
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12.0),
            child: Text(
              _searchController.text + _autocompleteSuggestion,
              style: TextStyle(
                color: highlightColor.withOpacity(0.3),
                fontSize: 16,
                fontFamily: 'PressStart2P',
              ),
            ),
          ),
          TextField(
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
        ],
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

  void _showOrganismDetails(Organism organism) {
    Color getStatColor(int stat) {
      if (stat >= 80) return Colors.greenAccent;
      if (stat >= 60) return highlightColor;
      return Colors.redAccent;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: secondaryButtonColor,
          shape: RoundedRectangleBorder(
             side: const BorderSide(color: highlightColor, width: 3.0),
             borderRadius: BorderRadius.circular(4.0)
          ),
          title: Text(
            organism.name.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: highlightColor, fontFamily: 'PressStart2P', fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: organism.sprite.isNotEmpty 
                        ? Image.network(
                            organism.sprite,
                            height: 100, 
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(child: CircularProgressIndicator(color: highlightColor));
                            },
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.red, size: 50),
                          )
                        : const Icon(Icons.image_not_supported, color: Colors.grey, size: 50),
                  ),
                ),
                  
                _buildDetailRow('Scientific Name:', organism.scientificName),
                _buildDetailRow('Habitat:', organism.habitat),
                _buildDetailRow('Drops:', organism.drops),
                _buildDetailRow('Rarity:', organism.rarity, isHighlight: true),
                _buildDetailRow('Category:', organism.category),

                const Divider(color: highlightColor),
                const Text(
                  'BATTLE STATS:',
                  style: TextStyle(color: highlightColor, fontFamily: 'PressStart2P', fontSize: 12),
                ),
                _buildDetailRow('HEALTH:', organism.health.toString(), statColor: getStatColor(organism.health)),
                _buildDetailRow('ATTACK:', organism.attack.toString(), statColor: getStatColor(organism.attack)),
                _buildDetailRow('DEFENSE:', organism.defense.toString(), statColor: getStatColor(organism.defense)),
                _buildDetailRow('SPEED:', organism.speed.toString(), statColor: getStatColor(organism.speed)),
                
                const Divider(color: highlightColor),
                _buildDetailRow('Abilities:', organism.abilities),
                _buildDetailRow('Moves:', organism.moves.replaceAll(',', ', ')),

                const Divider(color: highlightColor),
                const Text(
                  'MISSION BRIEF:',
                  style: TextStyle(color: Colors.white, fontFamily: 'PressStart2P', fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  organism.description,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('DISMISS', style: TextStyle(color: primaryButtonColor, fontFamily: 'PressStart2P')),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------
  // FIXED: The buildDetailRow method to prevent horizontal overflow
  // ------------------------------------------------------------------
  Widget _buildDetailRow(String label, String value, {bool isHighlight = false, Color? statColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start, // Align to top for multiline
        children: [
          // Label is fixed width
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontFamily: 'PressStart2P', fontSize: 12),
          ),
          
          // Value is Expanded, allowing it to wrap within the remaining space
          Expanded( 
            child: Text(
              value,
              textAlign: TextAlign.right, // Align text to the right 
              style: TextStyle(
                color: statColor ?? (isHighlight ? primaryButtonColor : Colors.white),
                fontFamily: 'PressStart2P',
                fontSize: 12,
              ),
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