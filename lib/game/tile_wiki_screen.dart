import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/game/biome_map_data.dart';

class TileWikiScreen extends StatefulWidget {
  const TileWikiScreen({super.key});

  @override
  State<TileWikiScreen> createState() => _TileWikiScreenState();
}

class _TileWikiScreenState extends State<TileWikiScreen> {
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<TileDefinition> _tiles = [];

  @override
  void initState() {
    super.initState();
    _loadTiles();
  }

  void _loadTiles() {
    _tiles = BiomeDataManager.allTiles.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<TileDefinition> get _filteredTiles {
    return _tiles.where((tile) {
      final matchesSearch = tile.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            tile.id.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || 
                              tile.category.name.toLowerCase() == _selectedCategory.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ['All'] + TileCategory.values.map((c) => c.name).toSet().toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('TILE WIKI', style: GoogleFonts.pressStart2p(fontSize: 14, color: AppColors.highlight)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white70),
      ),
      body: Column(
        children: [
          _buildFilters(categories),
          Expanded(
            child: _filteredTiles.isEmpty
                ? const Center(child: Text('No tiles found.', style: TextStyle(color: Colors.white54)))
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.65,
                    ),
                    itemCount: _filteredTiles.length,
                    itemBuilder: (context, index) {
                      final tile = _filteredTiles[index];
                      return _TileCard(tile: tile);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(List<String> categories) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF141420),
      child: Column(
        children: [
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search tiles...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: categories.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      cat[0].toUpperCase() + cat.substring(1),
                      style: TextStyle(
                        color: isSelected ? Colors.black : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.highlight,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    onSelected: (selected) {
                      setState(() => _selectedCategory = cat);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TileCard extends StatelessWidget {
  final TileDefinition tile;

  const _TileCard({required this.tile});

  ImageProvider _getTileImage() {
    final path = tile.isAutotiled ? tile.assetPath.replaceAll('{dir}', 'center') : tile.assetPath;
    return AssetImage(path);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                color: Colors.black26,
                child: Center(
                  child: Image(
                    image: _getTileImage(),
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    errorBuilder: (ctx, err, stack) => const Icon(Icons.broken_image, color: Colors.white24, size: 40),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tile.name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildInfoRow('Cat:', tile.category.name),
                        _buildInfoRow('Layer:', tile.layer),
                        _buildInfoRow('Biome:', tile.biome),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
