// lib/anidex_screen.dart

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/ability.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/theme.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/elemental_type.dart';

class AnidexScreen extends StatefulWidget {
  // User data must be passed to check discovery status
  final UserData currentUser;
  final LocalAuthService authService;

  const AnidexScreen({
    super.key,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<AnidexScreen> createState() => _AnidexScreenState();
}

class _AnidexScreenState extends State<AnidexScreen> {
  List<Organism> _allOrganisms = [];
  List<Organism> _searchResults = [];
  final TextEditingController _searchController = TextEditingController();

  // Helper to check if organism is discovered
  bool _isDiscovered(BuildContext context, Organism organism) {
    // Retrieve the UserData from the Provider without listening
    // (the Consumer around the search results list will handle rebuilding)
    final userState = Provider.of<UserState>(context, listen: false);
    // Use null-aware operator if currentUser can be null
    return userState.currentUser?.discoveredOrganisms.contains(organism.name) ??
        false;
  }

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
      case 'elite': // Added for completeness
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
        _allOrganisms = animalsData
            .map((json) => Organism.fromJson(json))
            .toList();
        _searchResults = [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          // 🚨 EDITED: Use AppTextStyles.small for SnackBar content
          SnackBar(
            content: Text(
              'Error loading data. Check JSON format and asset path. Error: $e',
              style: AppTextStyles.small(context, color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      // Autocomplete removal: Only clear search results if query is empty
      setState(() {
        _searchResults = [];
      });
      return;
    }

    // Autocomplete removal: The logic to find and set suggestion is removed.
  }

  void _performSearch() {
    final query = _searchController.text.trim().toLowerCase();

    // Autocomplete removal: Logic for handling _autocompleteSuggestion is removed.

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _searchResults = _allOrganisms
          .where(
            (org) =>
                org.name.toLowerCase().contains(query) ||
                org.scientificName.toLowerCase().contains(query),
          )
          .toList();

      // FIX: Sort by name descending (Z-A)
      _searchResults.sort((a, b) => a.name.compareTo(b.name));
    });
  }

  // --- UI Builders ---
  Widget _buildSearchBar() {
    // ... (unchanged)
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      // Autocomplete removal: Stack and the autocomplete overlay Text widget are removed.
      child: TextField(
        controller: _searchController,
        // 🚨 EDITED: Use AppTextStyles.body
        style: AppTextStyles.body(context, baseSize: 16, color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search Animal Name...',
          // 🚨 EDITED: Use AppTextStyles.body
          hintStyle: AppTextStyles.body(
            context,
            baseSize: 16,
            color: Colors.white.withOpacity(0.5),
          ),
          filled: true,
          // 🚨 EDITED: Use AppColors.secondaryButtonColor
          fillColor: AppColors.secondaryButtonColor.withOpacity(0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4.0),
            // 🚨 EDITED: Use AppColors.highlightColor
            borderSide: const BorderSide(
              color: AppColors.highlightColor,
              width: 2.0,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4.0),
            // 🚨 EDITED: Use AppColors.highlightColor
            borderSide: const BorderSide(
              color: AppColors.highlightColor,
              width: 3.0,
            ),
          ),
          suffixIcon: IconButton(
            // 🚨 EDITED: Use AppColors.highlightColor
            icon: const Icon(Icons.search, color: AppColors.highlightColor),
            onPressed: _performSearch,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 15,
          ),
        ),
        onSubmitted: (_) => _performSearch(),
      ),
    );
  }

  Widget _buildResultList() {
    if (_allOrganisms.isEmpty) {
      // 🚨 EDITED: Use AppTextStyles.small
      return Center(
        child: Text(
          'Loading Data...',
          style: AppTextStyles.small(context, color: AppColors.highlightColor),
        ),
      );
    }

    if (_searchResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        // 🚨 EDITED: Use AppTextStyles.body
        child: Text(
          'NO ANIMALS FOUND.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(context, baseSize: 14, color: Colors.red),
        ),
      );
    }
    if (_searchResults.isEmpty) {
      return Center(
        // 🚨 EDITED: Use AppTextStyles.body
        child: Text(
          'SEARCH FOR AN ANIMAL TO BEGIN.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            context,
            baseSize: 14,
            color: AppColors.highlightColor,
          ),
        ),
      );
    }

    return ListView.builder(
      // FIX: Use the list with current search results
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final organism = _searchResults[index];

        // 💡 FIX: Pass the 'context' to the _buildOrganismTile function.
        return _buildOrganismTile(context, organism);
      },
    );
  }

  // lib/anidex_screen.dart

  // ... (inside _AnidexScreenState)

  // 💡 FIX: Add 'BuildContext context' as the first argument
  Widget _buildOrganismTile(BuildContext context, Organism organism) {
    // 💡 FIX: Pass 'context' to the _isDiscovered helper function
    final bool isDiscovered = _isDiscovered(context, organism);

    // Conditional display for title/subtitle if not discovered
    final String titleText = isDiscovered ? organism.name.toUpperCase() : '???';
    final String subtitleText = isDiscovered
        ? 'Rarity: ${organism.rarity}'
        : 'Status: UNDISCOVERED';
    final Color titleColor = isDiscovered ? Colors.white : Colors.grey.shade600;

    return Card(
      // 🚨 EDITED: Use AppColors.secondaryButtonColor
      color: AppColors.secondaryButtonColor.withOpacity(0.9),
      elevation: 5,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(
          isDiscovered ? Icons.pets : Icons.question_mark_rounded,
          // 🚨 EDITED: Use AppColors.highlightColor
          color: isDiscovered ? AppColors.highlightColor : Colors.grey.shade800,
        ),
        title: Text(
          titleText,
          // 🚨 EDITED: Use AppTextStyles.body
          // The context is now available here
          style: AppTextStyles.body(context, baseSize: 16, color: titleColor),
        ),
        subtitle: Text(
          subtitleText,
          // 🚨 EDITED: Use AppTextStyles.small
          // The context is now available here
          style: AppTextStyles.small(
            context,
            baseSize: 12,
            color: AppColors.highlightColor,
          ),
        ),
        // 🚨 EDITED: Use AppColors.highlightColor
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.highlightColor,
        ),
        // 💡 FIX: Pass 'context' to the _showOrganismDetails function.
        onTap: () => _showOrganismDetails(context, organism),
      ),
    );
  }

  // ------------------------------------------------------------------
  // Immersive Modal Bottom Sheet for Details
  // ------------------------------------------------------------------
  void _showOrganismDetails(BuildContext context, Organism organism) {
    // Check discovery status once
    final bool isDiscovered = _isDiscovered(context, organism);

    // Stat color logic to determine the text color based on value,
    // now separate from the bar color.
    Color getStatTextColor(int stat) {
      if (stat >= 400)
        return Colors
            .white; // Keep white for high visibility against dark background
      if (stat >= 300) return Colors.white.withOpacity(0.9);
      // 🚨 EDITED: Use AppColors.highlightColor
      if (stat >= 200) return AppColors.highlightColor;
      return Colors.blueGrey;
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
                // 🚨 EDITED: Use AppColors.secondaryButtonColor
                color: AppColors.secondaryButtonColor.withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                border: Border.all(color: rarityColor, width: 3.0),
              ),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.all(0),
                children: <Widget>[
                  // 1. Header Section (Image, Name, Rarity)
                  _buildDetailsHeader(
                    organism,
                    rarityColor,
                    isDiscovered,
                  ), // UPDATED: Pass discovery status
                  // 2. Main Content
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 10.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Discovery Status Message
                        if (!isDiscovered)
                          Column(
                            children: [
                              _buildSectionTitle('CLASSIFIED DATA'),
                              const SizedBox(height: 10),
                              Text(
                                'ANIMAL IDENTIFICATION REQUIRED. DATA BLOCKED.',
                                textAlign: TextAlign.center,
                                // 🚨 EDITED: Use AppTextStyles.body
                                style: AppTextStyles.body(
                                  context,
                                  baseSize: 14,
                                  color: Colors.red.shade400,
                                ),
                              ),
                              const Divider(color: Colors.red),
                              const SizedBox(height: 10),
                            ],
                          ),

                        // Description/Brief
                        _buildSectionTitle('MISSION BRIEF'),
                        const SizedBox(height: 5),
                        Text(
                          isDiscovered
                              ? organism.description
                              : 'Description is classified until identification.',
                          // 🚨 EDITED: Use AppTextStyles.small
                          style: AppTextStyles.small(
                            context,
                            baseSize: 12,
                            color: Colors.white70,
                          ),
                        ),

                        // General Details
                        // 🚨 EDITED: Use AppColors.highlightColor
                        const Divider(color: AppColors.highlightColor),

                        // FIX: Rarity remains visible as a general, non-classified detail.
                        _buildDetailRow(
                          'Rarity:',
                          organism.rarity,
                          isRarity: true,
                        ),

                        // 🟢 MOVED: Habitat row to outside the conditional block
                        _buildDetailRow('Habitat:', organism.habitat),

                        // Conditional Details (Stats and classified info)
                        if (isDiscovered) ...[
                          // This block only runs IF discovered.
                          _buildDetailRow('Drops:', organism.drops),
                          _buildSectionTitle('ANIMAL CLASSIFICATION'),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: organism.category.split(',').map((cat) {
                              final typeStr = cat.trim().toLowerCase();
                              final type = ElementalType.values.firstWhere(
                                (e) => e.toString().split('.').last == typeStr,
                                orElse: () => ElementalType.normal,
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getAnimalTypeColor(type),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  cat.trim().toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontFamily: 'PressStart2P',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 10),

                          // Stats Section
                          // 🚨 EDITED: Use AppColors.highlightColor
                          const Divider(color: AppColors.highlightColor),
                          // Removed ' (MAX: 500)'
                          _buildSectionTitle('BATTLE STATS'),

                          // Stat bars with specific colors and glow
                          _buildStatBar(
                            'HEALTH',
                            organism.health,
                            500,
                            getStatTextColor(organism.health),
                            // 🚨 EDITED: Use AppColors.statHealthColor
                            const Color.fromARGB(255, 51, 255, 0),
                          ),
                          _buildStatBar(
                            'ATTACK',
                            organism.attack,
                            150,
                            getStatTextColor(organism.attack),
                            // 🚨 EDITED: Use AppColors.statAttackColor
                            AppColors.statAttackColor,
                          ),
                          _buildStatBar(
                            'DEFENSE',
                            organism.defense,
                            150,
                            getStatTextColor(organism.defense),
                            // 🚨 EDITED: Use AppColors.statDefenseColor
                            const Color.fromARGB(255, 255, 187, 0),
                          ),
                          _buildStatBar(
                            'POWER',
                            organism.power,
                            150,
                            getStatTextColor(organism.power),
                            // 🚨 EDITED: Use AppColors.statPowerColor
                            AppColors.statPowerColor,
                          ),
                          _buildStatBar(
                            'RESISTANCE',
                            organism.resistance,
                            150,
                            getStatTextColor(organism.resistance),
                            // 🚨 EDITED: Use AppColors.statResistanceStatColor
                            const Color.fromARGB(255, 224, 221, 0),
                          ),
                          _buildStatBar(
                            'SPEED',
                            organism.speed,
                            120,
                            getStatTextColor(organism.speed),
                            // 🚨 EDITED: Use AppColors.statSpeedColor
                            AppColors.statSpeedColor,
                          ),

                          // Abilities and Moves
                          // 🚨 EDITED: Use AppColors.highlightColor
                          const Divider(color: AppColors.highlightColor),
                          _buildSectionTitle('ABILITIES'),
                          // --- Multi-Ability Support: Display all abilities ---
                          ...(() {
                            final abilityNames = organism.abilities
                                .split(',')
                                .map((s) => s.trim())
                                .where((s) => s.isNotEmpty);
                            if (abilityNames.isEmpty)
                              return [const Text('No abilities.')];

                            return abilityNames.map((name) {
                              final ab = Ability.findByName(name);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8.0,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ab?.name.toUpperCase() ??
                                          name.toUpperCase(),
                                      style: AppTextStyles.body(
                                        context,
                                        baseSize: 14,
                                        color: AppColors.highlightColor,
                                      ).copyWith(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      ab?.description ??
                                          'No description available.',
                                      style: AppTextStyles.small(
                                        context,
                                        baseSize: 12,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList();
                          })(),

                          // 🚨 EDITED: Use AppColors.highlightColor
                          const Divider(color: AppColors.highlightColor),
                          _buildSectionTitle('COMBAT MOVES'),
                          // NEW: Chip/Tag style for moves
                          _buildMovesChips(organism.moves),
                        ],

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
  Widget _buildDetailsHeader(
    Organism organism,
    Color rarityColor,
    bool isDiscovered,
  ) {
    // Conditional values
    final String nameText = isDiscovered
        ? organism.name.toUpperCase()
        : 'CLASSIFIED ANIMAL';
    final String scientificNameText = isDiscovered
        ? organism.scientificName
        : '[Redacted]';
    final Color nameColor = isDiscovered ? rarityColor : Colors.grey.shade600;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: rarityColor.withOpacity(0.4),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        // 🚨 EDITED: Use AppColors.highlightColor
        border: const Border(
          bottom: BorderSide(color: AppColors.highlightColor, width: 3.0),
        ),
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
            // START MODIFIED IMAGE LOADING BLOCK
            child: _OrganismSpriteDisplay(
              organism: organism,
              isDiscovered: isDiscovered,
              silhouetteColor: Colors.black, // Use black for the silhouette
              height: 200,
              width: 400,
              fit: BoxFit.contain,
            ),
            // END MODIFIED IMAGE LOADING BLOCK
          ),
          // Name
          Text(
            nameText,
            textAlign: TextAlign.center,
            // 🚨 EDITED: Use AppTextStyles.headline
            style: AppTextStyles.headline(
              context,
              baseSize: 18,
              color: nameColor,
            ).copyWith(height: 1.2),
          ),
          // Scientific Name
          Text(
            scientificNameText,
            // 🚨 EDITED: Use AppTextStyles.small
            style: AppTextStyles.small(
              context,
              baseSize: 10,
              color: nameColor,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
          // Drag handle for modal
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              // 🚨 EDITED: Use AppColors.highlightColor
              color: AppColors.highlightColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  // --- HELPER: Section Title ---
  Widget _buildSectionTitle(String title) {
    // ... (unchanged)
    return Padding(
      padding: const EdgeInsets.only(top: 15.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        // 🚨 EDITED: Use AppTextStyles.body
        style:
            AppTextStyles.body(
              context,
              baseSize: 14,
              color: AppColors.highlightColor,
            ).copyWith(
              decoration: TextDecoration.underline,
              decorationColor: AppColors.highlightColor,
              decorationThickness: 2,
            ),
      ),
    );
  }

  // --- HELPER: Row with Expanded (General Details) ---
  Widget _buildDetailRow(
    String label,
    String value, {
    bool isHighlight = false,
    Color? statColor,
    bool isScientificName = false,
    bool isRarity = false,
  }) {
    // Determine text color and style
    // 🚨 EDITED: Use AppColors.primaryButtonColor
    Color textColor =
        statColor ??
        (isHighlight ? AppColors.primaryButtonColor : Colors.white);

    if (isRarity) {
      textColor = _getRarityColor(value); // Use rarity color for rarity value
    }

    FontStyle fontStyle = isScientificName
        ? FontStyle.italic
        : FontStyle.normal; // Italic for scientific name

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🚨 EDITED: Use AppTextStyles.small
          Text(
            label,
            style: AppTextStyles.small(
              context,
              baseSize: 12,
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              // 🚨 EDITED: Use AppTextStyles.small
              style:
                  AppTextStyles.small(
                    context,
                    baseSize: 12,
                    color: textColor,
                  ).copyWith(
                    fontStyle: fontStyle, // Apply font style
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // --- MODIFIED HELPER: Horizontal Stat Bar with Glow ---
  // Note: Only called if isDiscovered is true in _showOrganismDetails, so no conditional logic needed here.
  Widget _buildStatBar(
    String label,
    int statValue,
    double maxStat,
    Color statTextColor,
    Color barColor,
  ) {
    // Ensure the fraction is between 0.0 and 1.0
    double fraction = (statValue / maxStat).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // 🚨 EDITED: Use AppTextStyles.small
              Text(
                label,
                style: AppTextStyles.small(
                  context,
                  baseSize: 10,
                  color: Colors.white,
                ),
              ),
              Text(
                statValue.toString(),
                // 🚨 EDITED: Use AppTextStyles.small
                style:
                    AppTextStyles.small(
                      context,
                      baseSize: 10,
                      color: barColor,
                    ).copyWith(
                      shadows: [
                        // Add a slight glow/shadow to the number too
                        Shadow(
                          blurRadius: 2.0,
                          color: barColor.withOpacity(0.8),
                        ),
                      ],
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // The actual bar visualization
          Stack(
            children: [
              // Background bar (max value)
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              // Foreground bar (actual stat value)
              FractionallySizedBox(
                widthFactor: fraction,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: barColor, // Specific stat color
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      // Glow Effect
                      BoxShadow(
                        color: barColor.withOpacity(0.8),
                        blurRadius: 8, // Stronger blur for glow
                        spreadRadius: 2, // Slight spread
                      ),
                      BoxShadow(
                        // Inner shadow for intense glow
                        color: barColor,
                        blurRadius: 4,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- MODIFIED HELPER: Multi-line detail block (for Abilities) ---
  Widget _buildTextDetail(String value) {
    // ... (unchanged)
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      // 🚨 EDITED: Use AppTextStyles.body
      child: Text(
        value,
        style: AppTextStyles.body(context, baseSize: 14, color: Colors.white70),
      ),
    );
  }

  // --- NEW HELPER: Moves displayed as chips/tags ---
  Widget _buildMovesChips(String moves) {
    // Split the comma-separated string into a list of move names
    List<String> moveList = moves
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Padding(
      padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
      child: Wrap(
        spacing: 8.0, // horizontal spacing
        runSpacing: 8.0, // vertical spacing
        children: moveList.map((move) {
          return Chip(
            padding: const EdgeInsets.all(8.0),
            // 🚨 EDITED: Use AppColors.primaryButtonColor
            backgroundColor: AppColors.primaryButtonColor.withOpacity(0.8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
              // 🚨 EDITED: Use AppColors.highlightColor
              side: const BorderSide(
                color: AppColors.highlightColor,
                width: 1.0,
              ),
            ),
            label: Text(
              move.toUpperCase(),
              // 🚨 EDITED: Use AppTextStyles.small
              style: AppTextStyles.small(
                context,
                baseSize: 10,
                color: Colors.white,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🚨 EDITED: Scaffold background color is handled by ThemeData/Container below
    return Scaffold(
      appBar: AppBar(
        title: const Text('ANIMAL INDEX'),
        // 🚨 EDITED: Use AppColors.secondaryButtonColor and AppColors.highlightColor (though ThemeData should handle this, repeating for safety)
        backgroundColor: AppColors.secondaryButtonColor,
        titleTextStyle: AppTextStyles.headline(
          context,
          baseSize: 16.0,
          color: AppColors.highlightColor,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          // 🚨 EDITED: Use AppColors.secondaryButtonColor
          color: AppColors.secondaryButtonColor,
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
            Expanded(child: _buildResultList()),
          ],
        ),
      ),
    );
  }

  Color _getAnimalTypeColor(ElementalType type) {
    switch (type) {
      case ElementalType.normal:
        return const Color(0xFFA8A878);
      case ElementalType.flying:
        return const Color(0xFFA890F0);
      case ElementalType.aquatic:
        return const Color(0xFF6890F0);
      case ElementalType.arboreal:
        return const Color(0xFF78C850);
      case ElementalType.burrowing:
        return const Color(0xFFE0C068);
      case ElementalType.armored:
        return const Color(0xFFB8B8D0);
      case ElementalType.agile:
        return const Color(0xFFF08030);
      case ElementalType.venomous:
        return const Color(0xFFA040A0);
      case ElementalType.scavenger:
        return const Color(0xFF705848);
      case ElementalType.parasite:
      case ElementalType.poisonous:
        return const Color(0xFFA33EA1);
      case ElementalType.social:
        return const Color(0xFFF95587);
      case ElementalType.solitary:
        return const Color(0xFF7038F8);
      case ElementalType.prey:
        return const Color(0xFFD685AD);
      case ElementalType.predator:
        return const Color(0xFFC22E28);
      case ElementalType.tiny:
        return const Color(0xFFEE99AC);
      case ElementalType.giant:
        return const Color(0xFF705848);
      case ElementalType.rock:
        return const Color.fromARGB(255, 158, 97, 5);
      case ElementalType.arthropod:
        return const Color.fromARGB(255, 111, 207, 0);
      case ElementalType.electric:
        return const Color.fromARGB(255, 255, 251, 27);
      case ElementalType.nocturnal:
        return const Color.fromARGB(255, 39, 0, 110);
    }
  }
}

// ----------------------------------------------------------------------
// NEW WIDGET: _OrganismSpriteDisplay
// Handles the local asset check and network fallback for the Anidex screen.
// ----------------------------------------------------------------------
class _OrganismSpriteDisplay extends StatefulWidget {
  final Organism organism;
  final bool isDiscovered;
  final Color silhouetteColor;
  final double height;
  final double width;
  final BoxFit fit;

  const _OrganismSpriteDisplay({
    required this.organism,
    required this.isDiscovered,
    required this.silhouetteColor,
    this.height = 200,
    this.width = 400,
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

  // Helper to construct the local path
  String _getLocalPath() {
    // Organism name logic: lowercase and replace spaces with underscores.
    final fileName = widget.organism.name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll("'", '_')
        .replaceAll("-", '_');
    return 'assets/sprites/$fileName.png';
  }

  @override
  void didUpdateWidget(covariant _OrganismSpriteDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.organism.name != widget.organism.name) {
      // Reset state if the organism changes
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
      // Show a simple loading indicator while determining the source
      return SizedBox(
        height: widget.height,
        // 🚨 EDITED: Use AppColors.highlightColor
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.highlightColor),
        ),
      );
    }

    final String source = _imagePath;

    if (widget.isDiscovered) {
      final imageWidget = _imageSourceType == 'local'
          ? Image.asset(
              source,
              height: widget.height,
              width: widget.width,
              fit: widget.fit,
            )
          : Image.network(
              source,
              height: widget.height,
              width: widget.width,
              fit: widget.fit,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  height: widget.height,
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.highlightColor,
                    ),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) =>
                  const Icon(Icons.broken_image, color: Colors.red, size: 80),
            );

      // --- SPRITE OUTLINE LOGIC ---
      final spriteOutlineColor = Colors.black.withOpacity(0.8);
      const double outlineOffset = 1.0;

      final outlineImage = ColorFiltered(
        colorFilter: ColorFilter.mode(spriteOutlineColor, BlendMode.srcIn),
        child: imageWidget,
      );

      return SizedBox(
        height: widget.height,
        width: widget.width,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Outline Layers (4 directions)
            Transform.translate(
              offset: const Offset(-outlineOffset, -outlineOffset),
              child: outlineImage,
            ),
            Transform.translate(
              offset: const Offset(outlineOffset, -outlineOffset),
              child: outlineImage,
            ),
            Transform.translate(
              offset: const Offset(-outlineOffset, outlineOffset),
              child: outlineImage,
            ),
            Transform.translate(
              offset: const Offset(outlineOffset, outlineOffset),
              child: outlineImage,
            ),

            // Saturation Boost (matching battle_screen)
            ColorFiltered(
              colorFilter: const ColorFilter.matrix(<double>[
                1.12,
                0,
                0,
                0,
                0,
                0,
                1.12,
                0,
                0,
                0,
                0,
                0,
                1.12,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
              ]),
              child: imageWidget,
            ),
          ],
        ),
      );
    } else {
      // Undiscovered: Silhouette
      return buildSilhouetteSprite(
        imageUrl: source,
        silhouetteColor: widget.silhouetteColor,
        organismName: widget.organism.name,
        height: widget.height,
        width: widget.width,
        fit: widget.fit,
      );
    }
  }
}
