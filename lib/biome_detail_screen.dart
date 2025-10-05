// lib/biome_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:animal_warfare/models/organism.dart'; // Ensure this is the correct path
import 'explore_screen.dart'; // Import to use getWeightedRandomOrganism and Organism List
import 'package:audioplayers/audioplayers.dart'; // <<< ADDED: Audio Player Import

class BiomeDetailScreen extends StatefulWidget {
  final String biomeName;
  final List<Organism> allOrganisms; // Pass the data to avoid reloading

  const BiomeDetailScreen({
    super.key,
    required this.biomeName,
    required this.allOrganisms,
  });

  @override
  State<BiomeDetailScreen> createState() => _BiomeDetailScreenState();
}

class _BiomeDetailScreenState extends State<BiomeDetailScreen> {
  // Constants copied from ExploreScreen for consistent styling
  static const Color secondaryButtonColor = Color(0xFF1E3F2A); 
  static const Color highlightColor = Color(0xFFDAA520); 
  static const Color primaryButtonColor = Color(0xFF38761D); 
  
  Organism? _currentEncounter;
  bool _isExploring = false;

  // <<< ADDED: Audio Player Setup
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Helper to get the background image path (copied from ExploreScreen)
  String _getAssetPath(String biomeName) {
    final fileName = biomeName.toLowerCase().replaceAll(' ', '_');
    return 'assets/biomes/$fileName-bg.png';
  }

  // <<< ADDED: Helper to get the music path
  String _getMusicPath(String biomeName) {
    final fileName = biomeName.toLowerCase().replaceAll(' ', '_');
    return 'assets/audio/${fileName}_theme.mp3'; 
  }
  
  // <<< ADDED: Music Control Function
  void _playBiomeMusic(String biomeName) async {
    String musicPath = _getMusicPath(biomeName);
    try {
      await _audioPlayer.setSourceAsset(musicPath);
      await _audioPlayer.setReleaseMode(ReleaseMode.loop); 
      await _audioPlayer.resume();
    } catch (e) {
      if (mounted) {
        // Show a warning if music fails to load/play
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Warning: Could not play music for $biomeName. Check asset path: $musicPath')),
        );
      }
    }
  }
  
  // <<< ADDED: Stop Music Function
  void _stopMusic() async {
    await _audioPlayer.stop();
    await _audioPlayer.dispose();
  }
  
  @override
  void initState() {
    super.initState();
    _startExploration(); // <<< ADDED: Start exploration on load
    _playBiomeMusic(widget.biomeName); // <<< ADDED: Start music on load
  }

  @override
  void dispose() {
    _stopMusic(); // <<< ADDED: Stop music when screen is closed
    super.dispose();
  }

  // Helper function to determine rarity color (copied from ExploreScreen)
  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common': return Colors.grey;
      case 'uncommon': return Colors.green;
      case 'rare': return Colors.blue;
      case 'epic': return Colors.purple;
      case 'legendary': return Colors.orange;
      case 'mythical': return Colors.red;
      default: return Colors.white;
    }
  }

  void _startExploration() {
    setState(() {
      _isExploring = true;
      _currentEncounter = null;
    });

    // Simulate an exploration delay for better user experience
    Future.delayed(const Duration(seconds: 1), () {
      final Organism? encounter = getWeightedRandomOrganism(
        widget.biomeName, 
        widget.allOrganisms,
      );

      setState(() {
        _currentEncounter = encounter;
        _isExploring = false;
      });

      if (encounter == null) {
         // Show message if no organism is found for the habitat
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exploring ${widget.biomeName}. No organism data found.')),
         );
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.biomeName.toUpperCase()}'),
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
            image: AssetImage(_getAssetPath(widget.biomeName)), // Use biome-specific asset
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withOpacity(0.5),
              BlendMode.darken,
            ),
          ),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Display Exploration Status
              if (_isExploring)
                const Column(
                  children: [
                    CircularProgressIndicator(color: highlightColor),
                    SizedBox(height: 10),
                    Text(
                      'EXPLORING...',
                      style: TextStyle(color: highlightColor, fontFamily: 'PressStart2P', fontSize: 18),
                    ),
                  ],
                ),

              // Display Encounter Result
              if (!_isExploring && _currentEncounter != null)
                _buildEncounterResultCard(_currentEncounter!),

              // Initial State / Explore Button
              if (!_isExploring && _currentEncounter == null)
                ElevatedButton(
                  onPressed: _startExploration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryButtonColor, 
                    shape: const StadiumBorder(
                      side: BorderSide(color: highlightColor, width: 2),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
                  ),
                  child: Text(
                    _currentEncounter == null ? 'START EXPLORING' : 'EXPLORE AGAIN',
                    style: const TextStyle(color: highlightColor, fontFamily: 'PressStart2P', fontSize: 16),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Method to build the encounter card (simplified version of the modal content)
  Widget _buildEncounterResultCard(Organism organism) {
     return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: secondaryButtonColor.withOpacity(0.9),
        border: Border.all(color: highlightColor, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Encounter Header
          Text(
            'ENCOUNTER: ${organism.rarity.toUpperCase()}!',
            style: TextStyle(
              color: _getRarityColor(organism.rarity), 
              fontFamily: 'PressStart2P',
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const Divider(color: highlightColor),

          // Organism Sprite and Name
          Image.network(
            organism.sprite, 
            height: 100, 
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              // Placeholder only, no spinner
              return Image.asset(
                'assets/placeholder_400x200.png', 
                height: 100, 
                width: 200, 
                fit: BoxFit.contain, 
              );
            },
            errorBuilder: (context, error, stackTrace) => 
              Image.asset('assets/placeholder_400x200.png', height: 100),
          ),
          const SizedBox(height: 8),
          Text(
            organism.name.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'PressStart2P',
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 20),

          // Action Buttons (Fight and Run)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement navigation to the Battle Screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('BATTLE STARTED! (Unimplemented)')),
                    );
                    _startExploration(); 
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryButtonColor, 
                    shape: const StadiumBorder(
                      side: BorderSide(color: highlightColor, width: 2),
                    ),
                  ),
                  child: const Text('FIGHT', style: TextStyle(color: highlightColor, fontFamily: 'PressStart2P', fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement run logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${organism.name} ESCAPED!')),
                    );
                    _startExploration(); 
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: secondaryButtonColor, 
                    shape: const StadiumBorder(
                      side: BorderSide(color: Colors.white70, width: 2),
                    ),
                  ),
                  child: const Text('RUN', style: TextStyle(color: Colors.white70, fontFamily: 'PressStart2P', fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}