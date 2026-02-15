// lib/biome_detail_screen.dart
import 'package:flutter/material.dart';
import 'dart:math'; // Import Random
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/models/talisman.dart'; // Import Talisman model
import 'package:animal_warfare/battle_screen.dart'; // Ensure this is the correct path
import 'package:animal_warfare/game/battle_manager.dart'; // Import for BattleResult enum
import 'explore_screen.dart'; // Import to use getWeightedRandomOrganism and Organism List
import 'package:audioplayers/audioplayers.dart'; // Audio Player Import
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/achievement_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:animal_warfare/user_state.dart';

class BiomeDetailScreen extends StatefulWidget {
  final String biomeName;
  final List<Organism> allOrganisms; // Pass the data to avoid reloading
  final UserData
  currentUser; // ADDED: Current user data (Kept for now, but Provider is main source)
  final LocalAuthService authService; // ADDED: Auth service

  const BiomeDetailScreen({
    super.key,
    required this.biomeName,
    required this.allOrganisms,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<BiomeDetailScreen> createState() => _BiomeDetailScreenState();
}

class _BiomeDetailScreenState extends State<BiomeDetailScreen>
    with WidgetsBindingObserver {
  // Constants
  static const Color highlightColor = Color(
    0xFFDAA520,
  ); // Gold/Yellow (kept as fallback)

  // 🚨 NEW: Define a static Organism model for the Human fighter
  static final Organism HUMAN_ORGANISM = Organism(
    name: 'Human',
    scientificName: 'Homo sapiens',
    habitat: 'Everywhere',
    drops: 'N/A',
    attack: 100, // Base stats for a weak but non-zero fighter
    defense: 100,
    power: 0,
    resistance: 100,
    health: 100,
    speed: 50,
    abilities: 'None',
    category: 'Human',
    moves: 'Punch, Kick, Uppercut, Jab',
    sprite:
        'https://i.imgur.com/your_human_sprite.png', // Placeholder sprite URL
    rarity: 'Common',
    description: 'The dominant species.',
  );

  Organism? _currentEncounter;
  bool _isExploring = false;
  bool _isNameRevealed = false;

  // DYNAMIC COLORS
  late Color _biomeBaseColor;
  late Color _biomeDarkColor;
  late Color _biomeHighlightColor;
  late Color _rarityHighlightColor = highlightColor;

  // Audio Player Setup
  final AudioPlayer _audioPlayer = AudioPlayer();

  // ADDED: Achievement Service instance
  late AchievementService _achievementService;
  // ADDED: List of ALL organisms (in JSON format) for the service
  List<dynamic> _allOrganismsJson = [];

  // ADDED: Local state to hold current user data, which can be updated
  late UserData _currentUser;

  // Helper function to create a darker version of a color
  Color _getDarkerColor(Color color) {
    int r = (color.red * 0.6).round().clamp(0, 255);
    int g = (color.green * 0.6).round().clamp(0, 255);

    // 圷 FIX: Declare 'b' using 'int b =' instead of just 'b ='
    int b = (color.blue * 0.6).round().clamp(0, 255);

    return Color.fromARGB(color.alpha, r, g, b);
  }

  // REVISED: Helper function to determine biome-specific highlight color
  Color _getBiomeHighlightColor(String biomeName) {
    final biome = biomeName.toLowerCase();

    // Purple/Pink Accents
    if (biome.contains('swamp') || biome.contains('mangrove')) {
      return const Color(0xFFCE93D8); // Purple Accent
    }

    // Amber/Gold Accents
    if (biome.contains('desert') || biome.contains('savanna')) {
      return const Color(0xFFFFD740); // Amber Accent
    }

    // Light Blue/Cyan Accents (Cold)
    if (biome.contains('snow') ||
        biome.contains('ice') ||
        biome.contains('tundra') ||
        biome.contains('polar') ||
        biome.contains('frozen')) {
      return const Color(0xFF40C4FF); // Light Blue Accent
    }

    // Red Accents
    if (biome.contains('volcan')) {
      return const Color(0xFFFF5252); // Red Accent
    }

    // Grey/Silver Accents
    if (biome.contains('mountain') ||
        biome.contains('cave') ||
        biome.contains('urban') ||
        biome.contains('taiga')) {
      return const Color(0xFFB0BEC5); // Blue Grey
    }

    // Green Accents
    if (biome.contains('forest') ||
        biome.contains('jungle') ||
        biome.contains('rainforest') ||
        biome.contains('kelp')) {
      return const Color(0xFF69F0AE); // Green Accent
    }

    // Blue Accents (Water)
    if (biome.contains('ocean') ||
        biome.contains('beach') ||
        biome.contains('lake') ||
        biome.contains('river') ||
        biome.contains('deep sea') ||
        biome.contains('coral') ||
        biome.contains('coastal')) {
      return const Color(0xFF448AFF); // Blue Accent
    }

    return const Color(0xFFDAA520); // Default Goldenrod
  }

  // Helper to get the background image path
  String _getAssetPath(String biomeName) {
    final fileName = biomeName.toLowerCase().replaceAll(' ', '_');
    return 'assets/biomes/$fileName-bg.png';
  }

  // Helper to get the organism's local sprite path
  String _getOrganismLocalAssetPath(String organismName) {
    final fileName = organismName
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll("'", '_');
    return 'assets/sprites/$fileName.png';
  }

  // Helper to get the music path
  String _getMusicPath(String biomeName) {
    final fileName = biomeName.toLowerCase().replaceAll(' ', '_');
    return 'audio/${fileName}_theme.mp3';
  }

  int _getIdentifyStaminaCost(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 5;
      case 'uncommon':
        return 10;
      case 'rare':
        return 15;
      case 'epic':
        return 25;
      case 'legendary':
        return 40;
      case 'mythical':
        return 60;
      default:
        return 5; // Default cost
    }
  }

  void _displayMessage(String message) {
    // Ensure the context is available and the ScaffoldMessenger is accessible
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
      );
    }
  }

  void _onEncounterFound(Organism wildOrganism) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;

    if (user == null) {
      _displayMessage("You must be logged in to battle!");
      return;
    }

    CapturedOrganism playerFighter;
    if (user.capturedOrganisms.isEmpty) {
      _displayMessage("You have no organisms! Prepare to fight as Human!");
      playerFighter = CapturedOrganism.spawn(HUMAN_ORGANISM);
    } else {
      playerFighter = user.activeAttacker ?? user.capturedOrganisms.first;
    }

    // 2. Generate the Wild Organism with unique DNA (the opponent)
    final wildFighter = CapturedOrganism.spawn(wildOrganism);

    // Equip a random talisman (100% chance for wild encounters too)
    if (Talisman.allTalismans.isNotEmpty) {
      final randomTalisman =
          Talisman.allTalismans[Random().nextInt(Talisman.allTalismans.length)];
      wildFighter.equippedTalisman = randomTalisman;
    }

    // 3. Navigate to the Battle Screen
    AudioService.instance.pauseAll();
    final Object? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          playerOrganism: playerFighter,
          opponentOrganism: wildFighter,
          biomeName: widget.biomeName,
          playerTeam: user.teamOrganisms,
        ),
      ),
    );
    AudioService.instance.resumeAll();

    // 🚨 NEW LOGIC: Check the BattleResult
    if (result == BattleResult.capture) {
      // If captured, show success and keep exploring
      _displayMessage("Capture successful! Starting new exploration...");

      Future.delayed(const Duration(milliseconds: 500), () {
        _startExploration();
      });
    } else if (result == BattleResult.fled) {
      // If fled, show success and start new exploration (as requested)
      _displayMessage("Escaped safely! Searching for new opponent...");

      Future.delayed(const Duration(milliseconds: 500), () {
        _startExploration();
      });
    } else if (result == BattleResult.win) {
      // If won, show success and start new exploration
      _displayMessage("Victory! Searching for new opponent...");

      Future.delayed(const Duration(milliseconds: 500), () {
        _startExploration();
      });
    } else {
      // Loss or other (back to card)
    }
  }

  void _playBiomeMusic(String biomeName) {
    String musicPath = _getMusicPath(biomeName);
    AudioService.instance.playMusic(musicPath);
  }

  void _pauseMusic() {
    AudioService.instance.pauseAll();
  }

  void _stopAndDisposeMusic() {
    // No explicit dispose for singleton AudioPlayer usually, but we can stop it
    AudioService.instance.stopMusic();
  }

  // Helper to get the base color based on biome (More Immersive Palette)
  Color _getBiomeBaseColor(String biomeName) {
    switch (biomeName.toLowerCase()) {
      case 'swamp':
        return const Color(0xFF4B6F44); // Deep, Muted Olive
      case 'savanna':
        return const Color(0xFFC39C6B); // Dusty Gold
      case 'desert':
        return const Color(0xFFC17E45); // Rich Terracotta Brown
      case 'taiga':
        return const Color(0xFF5A6A6F); // Cool, Desaturated Grey-Blue
      case 'mountain':
        return const Color(0xFF757D75); // Slate Grey
      case 'coastal':
        return const Color(0xFF4C98A7); // Seafoam Teal
      case 'volcano':
        return const Color(0xFF8B0000); // Deep Dark Red
      case 'cave':
        return const Color(0xFF3A3A3A); // Very Dark Grey/Black
      case 'urban':
        return const Color(0xFF6C6C6C); // Industrial Mid-Grey
      case 'polar':
        return const Color(0xFFB0E0E6); // Powder Blue/Cyan
      case 'ocean':
        return const Color(0xFF005897); // Deep Ocean Blue
      case 'deep sea':
        return const Color(0xFF0D0D2E); // Almost Black Indigo
      case 'coral reef':
        return const Color(0xFFE9967A); // Light Salmon/Coral
      case 'rainforest':
        return const Color(0xFF1E5B3D); // Dark Jungle Green
      case 'kelp forest':
        return const Color(0xFF708F70); // Muted Seaweed Green
      case 'mangrove':
        return const Color(0xFF535C3E); // Deep Forest Green-Brown
      case 'frozen ocean':
        return const Color(0xFF8BA6C7); // Muted Light Blue
      case 'river':
        return const Color(0xFF488FB2); // Medium Cerulean Blue
      case 'lake':
        return const Color(0xFF6495ED); // Cornflower Blue
      case 'tundra':
        return const Color(0xFF909C90); // Muted Grey-Green
      case 'jungle':
        return const Color(0xFF38761D); // Primary Green (for general use)
      default:
        return highlightColor;
    }
  }

  // Helper to get a rarity-specific color for the encounter card highlight
  Color _getRarityHighlightColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade400;
      case 'uncommon':
        return const Color.fromARGB(255, 22, 254, 95);
      case 'rare':
        return const Color.fromARGB(255, 0, 175, 194);
      case 'epic':
        return const Color.fromARGB(255, 103, 0, 114);
      case 'legendary':
        return const Color.fromARGB(226, 227, 148, 0);
      case 'mythical':
        return Colors.redAccent.shade400;
      default:
        return highlightColor;
    }
  }

  // Fallback to load organisms data if not provided (needed for achievement check)
  Future<void> _loadOrganismsData() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/Organisms.json',
      );
      _allOrganismsJson = json.decode(response);
      _achievementService = AchievementService(
        // Re-initialize with data
        allOrganisms: _allOrganismsJson,
        authService: widget.authService,
      );
    } catch (e) {
      debugPrint('Error loading organisms for achievement check: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // INITIALIZE LOCAL STATE USER DATA FROM WIDGET
    _currentUser = widget.currentUser;

    // INITIALIZE DYNAMIC COLORS
    _biomeBaseColor = _getBiomeBaseColor(widget.biomeName);
    _biomeDarkColor = _getDarkerColor(_biomeBaseColor);
    // Initialize dynamic biome highlight
    _biomeHighlightColor = _getBiomeHighlightColor(widget.biomeName);

    // Initialize Achievement Service
    if (widget.allOrganisms.isNotEmpty) {
      // Convert Organism list to the required dynamic list for the service
      _allOrganismsJson = widget.allOrganisms.map((o) => o.toJson()).toList();
    }

    _achievementService = AchievementService(
      allOrganisms: _allOrganismsJson,
      authService: widget.authService,
    );

    // Fallback in case list was empty/not passed
    if (_allOrganismsJson.isEmpty) {
      _loadOrganismsData();
    }

    WidgetsBinding.instance.addObserver(this);
    // Do NOT call _startExploration here, let the user tap the button first.
    // We only call _playBiomeMusic here.
    _playBiomeMusic(widget.biomeName);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopAndDisposeMusic();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (!mounted) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseMusic();
    } else if (state == AppLifecycleState.resumed) {
      _playBiomeMusic(widget.biomeName);
    }
  }

  // Helper function to determine rarity color (used for text)
  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey;
      case 'uncommon':
        return Colors.green;
      case 'rare':
        return Colors.blue;
      case 'epic':
        return Colors.purple;
      case 'legendary':
        return Colors.orange;
      case 'mythical':
        return Colors.red;
      default:
        return Colors.white;
    }
  }

  /// Reloads user from disk and updates local state (e.g. after identify or discovery).
  Future<void> _refreshUserData() async {
    final user = await widget.authService.getCurrentUser();
    if (user != null && mounted) {
      setState(() => _currentUser = user);
    }
  }

  /// Identifies the organism: deducts stamina, marks discovered, checks achievements.
  void _revealName(Organism organism) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final cost = _getIdentifyStaminaCost(organism.rarity);
    if (userState.currentUser == null ||
        userState.currentUser!.stamina < cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Not enough stamina! Need $cost stamina to identify a ${organism.rarity} animal.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    await userState.decreaseStamina(cost);
    await widget.authService.markOrganismAsDiscovered(
      _currentUser.username,
      organism.name,
    );
    await _refreshUserData();

    final newAchievements = await _achievementService
        .checkAndUnlockAchievements(_currentUser);
    if (newAchievements.isNotEmpty) {
      _currentUser = _currentUser.copyWith(
        completedAchievements: [
          ..._currentUser.completedAchievements,
          ...newAchievements,
        ],
      );
      await widget.authService.updateUser(_currentUser);
    }
    userState.setCurrentUser(_currentUser);

    for (final title in newAchievements) {
      if (mounted) _achievementService.showAchievementSnackbar(context, title);
    }
    if (mounted) setState(() => _isNameRevealed = true);
  }

  // Helper to check if organism is discovered - UPDATED to use local state
  bool _isDiscovered(Organism organism) {
    return _currentUser.discoveredOrganisms.contains(organism.name);
  }

  void _startExploration() async {
    final userState = Provider.of<UserState>(context, listen: false);
    if (userState.currentUser == null || userState.currentUser!.stamina < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Not enough stamina! Need 10 stamina to explore.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    await userState.decreaseStamina(10);
    setState(() {
      _isExploring = true;
      _currentEncounter = null;
      _rarityHighlightColor = highlightColor;
      _isNameRevealed = false; // RESET on new encounter
    });

    Future.delayed(const Duration(seconds: 1), () {
      final Organism? encounter = getWeightedRandomOrganism(
        widget.biomeName,
        widget.allOrganisms,
      );

      setState(() {
        _currentEncounter = encounter;
        _isExploring = false;
        if (encounter != null) {
          _rarityHighlightColor = _getRarityHighlightColor(encounter.rarity);
          // Set _isNameRevealed based on persistent discovery status
          _isNameRevealed = _isDiscovered(encounter);
        }
      });

      if (encounter == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exploring ${widget.biomeName}. No organism data found.',
            ),
          ),
        );
      }
    });
  }

  // 圷 NEW: Utility to show the stats modal (used for the bar's onTap)
  void _showStatsModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return const _StatsModalContent(); // Use the modal content defined below
      },
    );
  }

  // 圷 NEW: Widget for the small stamina bar in the AppBar
  Widget _buildStaminaBarIcon(BuildContext context) {
    // 1. Use GestureDetector to make the bar clickable
    return GestureDetector(
      onTap: () => _showStatsModal(context), // Tapping opens the stats modal
      // 2. Use Consumer to listen to UserState and rebuild ONLY this small widget
      child: Consumer<UserState>(
        builder: (context, userState, child) {
          final user = userState.currentUser;
          final currentStamina = user?.stamina ?? 0;
          final progress = currentStamina / 100;

          // Only show the bar if a user is logged in
          if (user == null) {
            return const SizedBox.shrink();
          }

          return Container(
            width: 90, // Fixed width for the bar
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              border: Border.all(color: _biomeHighlightColor, width: 2),
              borderRadius: BorderRadius.circular(4),
              color: _biomeDarkColor,
            ),
            child: Stack(
              children: [
                // Stamina Fill
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      color: currentStamina > 25
                          ? Colors.greenAccent[400]
                          : Colors.redAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Stamina Text Overlay
                Center(
                  child: Text(
                    '${currentStamina.toString()}/100',
                    style: TextStyle(
                      color: currentStamina > 50 ? Colors.black : Colors.white,
                      fontFamily: 'PressStart2P',
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The title now displays only the biome name
        title: Text(widget.biomeName.toUpperCase()),
        backgroundColor: _biomeDarkColor,
        titleTextStyle: TextStyle(
          color: _biomeHighlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 16,
        ),
        // 圷 CRITICAL FIX: Add the stamina bar icon to the AppBar actions
        actions: [_buildStaminaBarIcon(context)],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: _biomeBaseColor,
          image: DecorationImage(
            image: AssetImage(_getAssetPath(widget.biomeName)),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              _biomeDarkColor.withOpacity(0.5),
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
                Column(
                  children: [
                    // USE DYNAMIC HIGHLIGHT COLOR
                    CircularProgressIndicator(color: _biomeHighlightColor),
                    const SizedBox(height: 10),
                    Text(
                      'EXPLORING...',
                      style: TextStyle(
                        // USE DYNAMIC HIGHLIGHT COLOR
                        color: _biomeHighlightColor,
                        fontFamily: 'PressStart2P',
                        fontSize: 18,
                        shadows: [
                          Shadow(
                            // USE DYNAMIC HIGHLIGHT COLOR
                            color: _biomeHighlightColor.withOpacity(0.5),
                            blurRadius: 5.0,
                            offset: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

              // Display Encounter Result
              if (!_isExploring && _currentEncounter != null)
                _buildEncounterResultCard(_currentEncounter!),

              // Initial State / Explore Button (Only shown before any encounter)
              if (!_isExploring && _currentEncounter == null)
                ElevatedButton(
                  onPressed: _startExploration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _biomeDarkColor,
                    shape: StadiumBorder(
                      // USE DYNAMIC HIGHLIGHT COLOR
                      side: BorderSide(color: _biomeHighlightColor, width: 2),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 40,
                    ),
                  ),
                  child: Text(
                    'START EXPLORING',
                    // USE DYNAMIC HIGHLIGHT COLOR
                    style: TextStyle(
                      color: _biomeHighlightColor,
                      fontFamily: 'PressStart2P',
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Method to build the encounter card
  Widget _buildEncounterResultCard(Organism organism) {
    // Determine the current state of discovery
    final bool isDiscovered = _isDiscovered(organism);
    // The name is revealed if it was pre-discovered OR if it was revealed in this encounter
    final bool isNameVisible = isDiscovered || _isNameRevealed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        // SEMI-TRANSPARENT CARD BACKGROUND (0.8 opacity)
        color: _biomeDarkColor.withOpacity(0.8),
        // Rarity color border
        border: Border.all(color: _rarityHighlightColor, width: 3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          // Rarity color glow shadow
          BoxShadow(
            color: _rarityHighlightColor.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Column(
        children: [
          // Encounter Header
          Text(
            isNameVisible
                ? 'ENCOUNTER:'
                : 'UNKNOWN ANIMAL DETECTED:', // UPDATED TEXT
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'PressStart2P',
              fontSize: 14,
              shadows: [
                Shadow(
                  color: _rarityHighlightColor.withOpacity(0.8),
                  blurRadius: 8.0,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),

          // Rarity Level
          Text(
            organism.rarity.toUpperCase(),
            style: TextStyle(
              color: _getRarityColor(organism.rarity),
              fontFamily: 'PressStart2P',
              fontSize: 20,
              shadows: [
                Shadow(
                  color: _getRarityHighlightColor(
                    organism.rarity,
                  ).withOpacity(0.8),
                  blurRadius: 10.0,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 10),
          Divider(color: _rarityHighlightColor, thickness: 2),
          const SizedBox(height: 10),

          // Organism Sprite (Conditional) - REPLACED WITH NEW WIDGET
          _OrganismSpriteDisplay(
            organism: organism,
            isNameVisible: isNameVisible,
            silhouetteColor: Colors.black, // Use black for the silhouette
            height: 200,
            fit: BoxFit.contain,
          ), // <--- MODIFIED HERE

          const SizedBox(height: 12),

          // Organism Name or Identify Button
          if (isNameVisible)
            // Organism Name - Primary Element (REVEALED STATE)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _biomeBaseColor.withOpacity(0.4),
                borderRadius: BorderRadius.circular(4),
                // USE DYNAMIC HIGHLIGHT COLOR
                border: Border.all(color: _biomeHighlightColor, width: 1),
              ),
              child: Text(
                organism.name.toUpperCase(),
                style: TextStyle(
                  // USE DYNAMIC HIGHLIGHT COLOR
                  color: _biomeHighlightColor,
                  fontFamily: 'PressStart2P',
                  fontSize: 16,
                  shadows: [
                    Shadow(
                      color: _rarityHighlightColor.withOpacity(0.6),
                      blurRadius: 4.0,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            )
          else
            // Identify Button (HIDDEN STATE)
            ElevatedButton(
              onPressed: () => _revealName(organism), // UPDATED: Pass organism
              style: ElevatedButton.styleFrom(
                // USE DYNAMIC HIGHLIGHT COLOR
                backgroundColor: _biomeHighlightColor.withOpacity(0.8),
                shape: const StadiumBorder(
                  side: BorderSide(color: Colors.black, width: 2),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
              ),
              child: Text(
                'IDENTIFY',
                style: TextStyle(
                  color: _biomeDarkColor,
                  fontFamily: 'PressStart2P',
                  fontSize: 14,
                  shadows: [
                    Shadow(
                      color: Colors.white.withOpacity(0.5),
                      blurRadius: 4.0,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 30), // Increased spacing before buttons
          // Action Buttons (Fight and Run)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: ElevatedButton(
                  // 🚨 FIX: Allow FIGHT only if identified
                  onPressed: isNameVisible
                      ? () => _onEncounterFound(organism)
                      : () => _displayMessage(
                          "You cannot fight an unidentified animal!",
                        ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isNameVisible
                        ? _rarityHighlightColor
                        : Colors.grey.shade600,
                    shape: const StadiumBorder(
                      side: BorderSide(color: Colors.black, width: 3),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      isNameVisible ? 'FIGHT' : 'LOCKED',
                      style: TextStyle(
                        color: Colors.black,
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  // 🚨 FIX: RUN button now behaves like "Explore" (Skip/Re-roll)
                  onPressed: _startExploration,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _biomeDarkColor.withOpacity(0.8),
                    shape: StadiumBorder(
                      // USE DYNAMIC HIGHLIGHT COLOR
                      side: BorderSide(color: _biomeHighlightColor, width: 2),
                    ),
                  ),
                  child: Text(
                    'RUN',
                    // USE DYNAMIC HIGHLIGHT COLOR
                    style: TextStyle(
                      color: _biomeHighlightColor,
                      fontFamily: 'PressStart2P',
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Explore Again Button inside the card
          ElevatedButton(
            onPressed: _startExploration,
            style: ElevatedButton.styleFrom(
              backgroundColor: _biomeDarkColor.withOpacity(0.7),
              shape: StadiumBorder(
                // Use rarity highlight color for the border
                side: BorderSide(color: _rarityHighlightColor, width: 2),
              ),
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
            ),
            child: Text(
              'EXPLORE',
              style: TextStyle(
                color: _rarityHighlightColor,
                fontFamily: 'PressStart2P',
                fontSize: 14,
                // Text Shadow using biome color for depth
                shadows: [
                  Shadow(
                    color: _biomeBaseColor,
                    blurRadius: 4.0,
                    offset: const Offset(1, 1),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------
// NEW WIDGET: _OrganismSpriteDisplay
// Handles the local asset check and network fallback.
// This must be placed OUTSIDE the main BiomeDetailScreenState class.
// ----------------------------------------------------------------------
class _OrganismSpriteDisplay extends StatefulWidget {
  final Organism organism;
  final bool isNameVisible;
  final Color silhouetteColor;
  final double height;
  final BoxFit fit;

  const _OrganismSpriteDisplay({
    required this.organism,
    required this.isNameVisible,
    required this.silhouetteColor,
    this.height = 200,
    this.fit = BoxFit.contain,
  });

  @override
  __OrganismSpriteDisplayState createState() => __OrganismSpriteDisplayState();
}

class __OrganismSpriteDisplayState extends State<_OrganismSpriteDisplay> {
  // null initially, 'local' if found, 'network' if not found locally
  String? _imageSourceType;

  // The determined path/url to use
  late String _imagePath;

  @override
  void initState() {
    super.initState();
    _determineImageSource();
  }

  // Helper to construct the local path (copied from _BiomeDetailScreenState)
  String _getLocalPath() {
    final fileName = widget.organism.name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll("-", '_');
    return 'assets/sprites/$fileName.png';
  }

  // Call this if the organism changes, but in this case, the widget is
  // rebuilt with a new organism, so the key is fine.
  @override
  void didUpdateWidget(covariant _OrganismSpriteDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organism.name != widget.organism.name) {
      _imageSourceType = null;
      _determineImageSource();
    }
  }

  Future<void> _determineImageSource() async {
    final localPath = _getLocalPath();

    // 1. Try to load the local asset
    try {
      // Use rootBundle.load to check for existence without rendering
      await rootBundle.load(localPath);
      // If load succeeds, the asset exists
      if (mounted) {
        setState(() {
          _imageSourceType = 'local';
          _imagePath = localPath;
        });
      }
    } catch (e) {
      // 2. If load fails (asset not found), fallback to network
      if (mounted) {
        // debugPrint('Local asset not found for ${widget.organism.name}. Falling back to network. Error: $e');
        setState(() {
          _imageSourceType = 'network';
          _imagePath = widget.organism.sprite; // Network URL
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_imageSourceType == null) {
      // Show a simple placeholder while determining the source
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Use the determined path/URL
    final String source = _imagePath;

    if (widget.isNameVisible) {
      // Normal Image Display
      if (_imageSourceType == 'local') {
        return Image.asset(
          source,
          height: widget.height,
          width: 400,
          fit: widget.fit,
        );
      } else {
        // Network Image
        return Image.network(
          source,
          height: widget.height,
          width: 400,
          fit: widget.fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            // Use a loading indicator for network fetching
            return SizedBox(
              height: widget.height,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              // Fallback for network error (Can't load sprite at all)
              SizedBox(
                height: widget.height,
                child: Center(
                  child: Text(
                    'IMAGE ERROR',
                    style: TextStyle(
                      color: Colors.red,
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
        );
      }
    } else {
      // Silhouette Display (Assumes buildSilhouetteSprite is globally available)
      return buildSilhouetteSprite(
        imageUrl: source, // Pass the determined local path or network URL
        silhouetteColor: widget.silhouetteColor,
        height: widget.height,
        width: 400,
        fit: widget.fit,
      );
    }
  }
}

// NEW WIDGET: _StatsModalContent
// This is required for the stamina bar's onTap functionality.
// ----------------------------------------------------------------------
class _StatsModalContent extends StatelessWidget {
  const _StatsModalContent();

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }

  // Same detailed stamina bar from the previous solution
  Widget _buildStaminaBar(BuildContext context, int currentStamina) {
    final progress = currentStamina / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STAMINA',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 5),

        Stack(
          children: [
            LinearProgressIndicator(
              value: 1.0,
              backgroundColor: Colors.grey[800],
              minHeight: 20,
              color: Colors.grey[600],
            ),

            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.transparent,
              color: currentStamina > 25
                  ? Colors.greenAccent[400]
                  : Colors.redAccent,
              minHeight: 20,
            ),

            Positioned.fill(
              child: Center(
                child: Text(
                  '$currentStamina / 100',
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),
        // Regeneration Info
        const Text(
          'Regenerates +20 every 5 seconds.',
          style: TextStyle(fontSize: 10, color: Colors.greenAccent),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use Consumer to listen to UserState and rebuild ONLY this part
    return Consumer<UserState>(
      builder: (context, userState, child) {
        final user = userState.currentUser;

        if (user == null) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Player Stats',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Divider(),

              _buildStatRow('Username:', user.username),
              _buildStatRow('Gender:', user.gender),
              _buildStatRow('Money:', '\$${user.money}'),

              const SizedBox(height: 20),

              _buildStaminaBar(context, user.stamina),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
