import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/biome_exploration_map.dart';
import 'package:animal_warfare/game/map_editor.dart';
import 'package:animal_warfare/game/biome_map_data.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class ExploreSelectionScreen extends StatefulWidget {
  final UserData currentUser;
  final LocalAuthService authService;

  const ExploreSelectionScreen({
    super.key,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<ExploreSelectionScreen> createState() => _ExploreSelectionScreenState();
}

class _ExploreSelectionScreenState extends State<ExploreSelectionScreen> {
  List<Organism> _allOrganisms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      await BiomeDataManager.loadData();
      final String response = await rootBundle.loadString(
        'assets/Organisms.json',
      );
      final List<dynamic> data = json.decode(response);
      _allOrganisms = data.map((j) => Organism.fromJson(j)).toList();
    } catch (e) {
      debugPrint('Error loading organisms: $e');
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _enterBiome(String biomeName, {BiomeMapData? customData}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BiomeExplorationMap(
          biomeName: biomeName,
          allOrganisms: _allOrganisms,
          currentUser: widget.currentUser,
          authService: widget.authService,
          customMapData: customData,
        ),
      ),
    );
  }

  void _showCustomMapDialog() {
    final controller = TextEditingController();
    String selectedBiomeId = 'swamp';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(
                'Import Custom Map',
                style: GoogleFonts.pressStart2p(
                  color: AppColors.highlight,
                  fontSize: 12,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButton<String>(
                    value: selectedBiomeId,
                    dropdownColor: AppColors.surface,
                    style: const TextStyle(color: Colors.white),
                    items: BiomeDataManager.biomes.keys.map((id) {
                      return DropdownMenuItem(
                        value: id,
                        child: Text(id.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null)
                        setDialogState(() => selectedBiomeId = val);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    maxLines: 5,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Paste Map Data String here...\n(e.g. W,T,G,P,...)',
                      hintStyle: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'CANCEL',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.highlight,
                  ),
                  onPressed: () {
                    try {
                      final lines = controller.text.trim().split('\n');
                      if (lines.isEmpty || lines[0].isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Invalid map data or empty string'),
                          ),
                        );
                        return;
                      }

                      // Handle potential JSON string from editor export (v2 format)
                      dynamic mapData;
                      try {
                        mapData = jsonDecode(controller.text.trim());
                      } catch (_) {
                        // Fallback to treating it as just the base layer strings (old format)
                        mapData = {'base': lines};
                      }

                      final config = BiomeDataManager.getBiome(selectedBiomeId);
                      final customData = MapStringParser.parse(
                        mapData,
                        config: config,
                      );
                      Navigator.of(context).pop();
                      _enterBiome(config.name, customData: customData);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error parsing map: $e')),
                      );
                    }
                  },
                  child: const Text(
                    'PLAY',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'EXPLORE REGIONS',
          style: GoogleFonts.pressStart2p(
            fontSize: 14,
            color: AppColors.highlight,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.build_circle, color: Colors.orangeAccent),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MapEditor(biomeId: 'swamp'),
                ),
              );
            },
            tooltip: 'Open Map Editor',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a biome to explore:',
                    style: GoogleFonts.inter(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildBiomeCard(
                    name: 'Swamp',
                    description:
                        'Misty wetlands teeming with reptiles and mysterious flora.',
                    icon: Icons.water,
                    color: Colors.green.shade800,
                    onTap: () => _enterBiome('Swamp'),
                  ),
                  const SizedBox(height: 16),
                  _buildBiomeCard(
                    name: 'Plains (Locked)',
                    description:
                        'Vast grasslands with high visibility. Coming soon.',
                    icon: Icons.grass,
                    color: Colors.grey,
                    onTap: null,
                  ),
                  const SizedBox(height: 24),
                  _buildBiomeCard(
                    name: 'Play Custom Map',
                    description:
                        'Import a map string created in the Map Editor and play immediately.',
                    icon: Icons.map,
                    color: Colors.blueAccent,
                    onTap: _showCustomMapDialog,
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBiomeCard({
    required String name,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    final bool isLocked = onTap == null;
    return Opacity(
      opacity: isLocked ? 0.6 : 1.0,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 2),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.pressStart2p(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: GoogleFonts.inter(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLocked)
                  const Icon(Icons.chevron_right, color: Colors.white54),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
