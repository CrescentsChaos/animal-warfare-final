// lib/tool_screen.dart
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/biome_exploration_map.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/game/map_editor.dart';
import 'package:animal_warfare/game/tile_designer.dart';
import 'package:animal_warfare/game/tile_wiki_screen.dart';
import 'package:animal_warfare/user_state.dart';

class ToolScreen extends StatefulWidget {
  final UserData currentUser;
  final LocalAuthService authService;

  const ToolScreen({
    super.key,
    required this.currentUser,
    required this.authService,
  });

  @override
  State<ToolScreen> createState() => _ToolScreenState();
}

class _ToolScreenState extends State<ToolScreen> {
  List<Organism> _allOrganisms = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final String organismsResponse = await rootBundle.loadString('assets/Organisms.json');
      final List<dynamic> animalsData = json.decode(organismsResponse);
      _allOrganisms = animalsData.map((json) => Organism.fromJson(json)).toList();
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _launchEarthMap() {
    final userState = Provider.of<UserState>(context, listen: false);
    final currentMapId = userState.eventFlags.currentMapId; // defaults to 'littleroot_town'

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BiomeExplorationMap(
          biomeName: currentMapId,
          allOrganisms: _allOrganisms,
          currentUser: widget.currentUser,
          authService: widget.authService,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('MAP & TOOLS', style: GoogleFonts.pressStart2p(fontSize: 14, color: AppColors.highlight)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.highlight))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Earth Map (Primary) ---
                  Text('World', 
                      style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E3F2A),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        side: const BorderSide(color: AppColors.highlight, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _launchEarthMap,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.public, color: AppColors.highlight, size: 24),
                          const SizedBox(width: 12),
                          Consumer<UserState>(
                            builder: (context, userState, _) {
                              final mapId = userState.eventFlags.currentMapId;
                              final displayName = mapId.replaceAll('_', ' ').split(' ')
                                  .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                                  .join(' ');
                              return Column(
                                children: [
                                  Text('ENTER WORLD',
                                    style: GoogleFonts.pressStart2p(fontSize: 12, color: AppColors.highlight)),
                                  const SizedBox(height: 6),
                                  Text('Resume: $displayName',
                                    style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // --- Creator Tools ---
                  Text('Creator Tools', 
                      style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),
                  _ToolCard(
                    icon: Icons.grid_on,
                    title: 'Map Editor',
                    description: 'Design custom maps.',
                    gradient: const [Color(0xFF1B5E20), Color(0xFF388E3C)],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapEditor(biomeId: 'swamp'))),
                  ),
                  const SizedBox(height: 12),
                  _ToolCard(
                    icon: Icons.brush,
                    title: 'AW Studio',
                    description: 'Draw pixel art tiles.',
                    gradient: const [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AWStudio())),
                  ),
                  const SizedBox(height: 12),
                  _ToolCard(
                    icon: Icons.auto_stories,
                    title: 'Tile Wiki',
                    description: 'Browse available tiles.',
                    gradient: const [Color(0xFF0D47A1), Color(0xFF1976D2)],
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TileWikiScreen())),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon, required this.title, required this.description,
    required this.gradient, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: gradient[1].withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Icon(icon, color: gradient[1], size: 24),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white)),
              const SizedBox(height: 4),
              Text(description, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 11)),
            ])),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ]),
        ),
      ),
    );
  }
}
