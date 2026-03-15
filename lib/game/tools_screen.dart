import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/game/map_editor.dart';
import 'package:animal_warfare/game/tile_designer.dart';
import 'package:animal_warfare/game/tile_wiki_screen.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  State<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends State<ToolsScreen> {
  List<Map<String, dynamic>> _recentProjects = [];

  @override
  void initState() {
    super.initState();
    _loadRecentProjects();
  }

  Future<void> _loadRecentProjects() async {
    final projects = await AWStudio.loadProjectList();
    if (mounted) setState(() => _recentProjects = projects);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('TOOLS', style: GoogleFonts.pressStart2p(fontSize: 14, color: AppColors.highlight)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Creator Suite', style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            _ToolCard(
              icon: Icons.grid_on,
              title: 'Map Editor',
              description: 'Design custom biome maps with tiles, teleporters, and overlay layers.',
              gradient: const [Color(0xFF1B5E20), Color(0xFF388E3C)],
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MapEditor(biomeId: 'swamp')));
              },
            ),
            const SizedBox(height: 16),
            _ToolCard(
              icon: Icons.brush,
              title: 'AW Studio',
              description: 'Draw pixel art tiles from scratch or edit existing images with pro tools.',
              gradient: const [Color(0xFF4A148C), Color(0xFF7B1FA2)],
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AWStudio()));
                _loadRecentProjects(); // Refresh after returning
              },
            ),
            const SizedBox(height: 16),
            _ToolCard(
              icon: Icons.auto_stories,
              title: 'Tile Wiki',
              description: 'Browse, search, and view all available game tiles and their properties.',
              gradient: const [Color(0xFF0D47A1), Color(0xFF1976D2)],
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TileWikiScreen()));
              },
            ),
            // Recent Projects
            if (_recentProjects.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text('Recent Projects', style: GoogleFonts.pressStart2p(fontSize: 10, color: Colors.white70)),
              const SizedBox(height: 12),
              ..._recentProjects.take(5).map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => AWStudio(projectId: p['id'])),
                      );
                      _loadRecentProjects();
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141420),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2A2A3A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_open, color: Color(0xFFFFD740), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['name'] ?? 'Untitled',
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 2),
                                Text('${p['canvasW']}×${p['canvasH']} • ${p['layerCount'] ?? 1} layers',
                                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                            onPressed: () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF141420),
                                  title: Text('Delete Project', style: GoogleFonts.pressStart2p(fontSize: 10, color: const Color(0xFFFFD740))),
                                  content: Text('Are you sure you want to delete "${p['name']}"?', style: const TextStyle(color: Colors.white70)),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('DELETE', style: TextStyle(color: Colors.white)),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                await AWStudio.deleteProject(p['id']);
                                _loadRecentProjects();
                              }
                            },
                          ),
                          const Icon(Icons.chevron_right, color: Colors.white24, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              )),
            ],
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
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [gradient[0].withValues(alpha: 0.25), gradient[1].withValues(alpha: 0.15)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: gradient[1].withValues(alpha: 0.4), width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradient),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: gradient[1].withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)],
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.pressStart2p(fontSize: 11, color: Colors.white)),
              const SizedBox(height: 8),
              Text(description, style: GoogleFonts.inter(color: AppColors.textMuted, fontSize: 12, height: 1.4)),
            ])),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ]),
        ),
      ),
    );
  }
}
