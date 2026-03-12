import 'dart:math';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

// ───────────────────────────────────────────────────────────────────
// Core Definitions
// ───────────────────────────────────────────────────────────────────

enum TileCategory {
  ground, // Base walkable terrain (grass, dirt)
  path, // Distinct walkable trails
  water, // Base unwalkable/swimmable terrain
  solid, // Blocking objects (trees, rocks)
  mud, // Slowing terrain or specific encounters
  tallGrass, // Ambush/encounter zones
  decorative, // Non-blocking visual flair (flowers, lily pads)
}

extension TileCategoryExtension on TileCategory {
  static TileCategory fromString(String category) {
    switch (category) {
      case 'ground':
        return TileCategory.ground;
      case 'path':
        return TileCategory.path;
      case 'water':
        return TileCategory.water;
      case 'solid':
        return TileCategory.solid;
      case 'mud':
        return TileCategory.mud;
      case 'tallGrass':
        return TileCategory.tallGrass;
      case 'decorative':
        return TileCategory.decorative;
      default:
        return TileCategory.ground;
    }
  }
}

/// A definition of a specific tile's visual and category behavior.
class TileDefinition {
  final String id;
  final String name;
  final TileCategory category;
  final String assetPath;
  final bool isAutotiled;

  final String symbol;
  final String layer;

  const TileDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.assetPath,
    required this.symbol,
    this.isAutotiled = false,
    this.layer = 'base',
  });

  bool get isWalkable {
    switch (category) {
      case TileCategory.solid:
      case TileCategory.water: // Assuming water is unwalkable for now
        return false;
      default:
        return true;
    }
  }

  bool get hasEncounter {
    switch (category) {
      case TileCategory.tallGrass:
      case TileCategory.water: // Aquatic encounters if walkability changes
        return true;
      default:
        return false;
    }
  }

  factory TileDefinition.fromJson(Map<String, dynamic> json) {
    return TileDefinition(
      id: json['id'],
      name: json['name'],
      category: TileCategoryExtension.fromString(json['category']),
      assetPath: json['assetPath'],
      symbol: json['symbol'] ?? json['id'][0].toUpperCase(),
      isAutotiled: json['isAutotiled'] ?? false,
      layer: json['layer'] ?? 'base',
    );
  }
}

/// Holds the configuration for a biome's tiles.
class BiomeConfig {
  final String id;
  final String name;
  final String defaultTileId;
  final Map<String, TileDefinition> tiles;

  final Map<String, List<String>>?
  layout; // e.g. {'base': [...], 'overlay': [...]}
  final Point<int>? spawnPoint;

  const BiomeConfig({
    required this.id,
    required this.name,
    required this.defaultTileId,
    required this.tiles,
    this.layout,
    this.spawnPoint,
  });

  factory BiomeConfig.fromJson(
    Map<String, dynamic> json,
    Map<String, TileDefinition> allTiles,
  ) {
    final Map<String, TileDefinition> biomeTiles = {};
    for (String tileId in json['tiles']) {
      if (allTiles.containsKey(tileId)) {
        biomeTiles[tileId] = allTiles[tileId]!;
      }
    }
    Point<int>? spawn;
    if (json['spawnPoint'] != null) {
      spawn = Point(
        (json['spawnPoint']['x'] as num).toInt(),
        (json['spawnPoint']['y'] as num).toInt(),
      );
    }

    Map<String, List<String>>? layout;
    if (json['layout'] != null) {
      if (json['layout'] is Map) {
        layout = (json['layout'] as Map).map(
          (k, v) => MapEntry(k.toString(), List<String>.from(v)),
        );
      } else if (json['layout'] is List) {
        // Legacy fallback
        layout = {'base': List<String>.from(json['layout'])};
      }
    }

    return BiomeConfig(
      id: json['id'],
      name: json['name'],
      defaultTileId: json['defaultTileId'],
      tiles: biomeTiles,
      layout: layout,
      spawnPoint: spawn,
    );
  }
}

class BiomeDataManager {
  static final Map<String, TileDefinition> allTiles = {};
  static final Map<String, BiomeConfig> biomes = {};
  static final Map<String, Map<String, ui.Image>> tileAssets = {};

  static Future<void> loadData() async {
    // Load Tiles
    final tilesJsonStr = await rootBundle.loadString('assets/tiles.json');
    final List<dynamic> tilesJson = json.decode(tilesJsonStr);
    for (var j in tilesJson) {
      final tile = TileDefinition.fromJson(j);
      allTiles[tile.id] = tile;
    }

    // Load Biomes
    final mapsJsonStr = await rootBundle.loadString('assets/maps.json');
    final List<dynamic> mapsJson = json.decode(mapsJsonStr);
    for (var j in mapsJson) {
      final biome = BiomeConfig.fromJson(j, allTiles);
      biomes[biome.id] = biome;
    }

    // Pre-load all tile assets
    for (final tile in allTiles.values) {
      tileAssets[tile.id] = {};
      if (tile.isAutotiled) {
        for (final dir in ['center', 'up', 'down', 'left', 'right']) {
          final path = tile.assetPath.replaceAll('{dir}', dir);
          final img = await loadImage(path);
          if (img != null) {
            tileAssets[tile.id]![dir] = img;
          }
        }
      } else {
        final img = await loadImage(tile.assetPath);
        if (img != null) {
          tileAssets[tile.id]!['center'] = img;
        }
      }
    }
  }

  static Future<ui.Image?> loadImage(String path) async {
    try {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      return null;
    }
  }

  static BiomeConfig getBiome(String id) {
    // Fallback to the first available biome if not found (or swamp by default)
    return biomes[id] ?? biomes.values.first;
  }
}

/// A single cell on the grid map.
class MapTile {
  final String tileId;
  final BiomeConfig config;
  final bool? walkabilityOverride;

  const MapTile({
    required this.tileId,
    required this.config,
    this.walkabilityOverride,
  });

  TileDefinition get definition =>
      config.tiles[tileId] ?? config.tiles[config.defaultTileId]!;

  TileCategory get category => definition.category;

  bool get isWalkable => walkabilityOverride ?? definition.isWalkable;

  bool get hasEncounter => definition.hasEncounter;

  MapTile copyWith({
    String? tileId,
    BiomeConfig? config,
    bool? walkabilityOverride,
  }) {
    return MapTile(
      tileId: tileId ?? this.tileId,
      config: config ?? this.config,
      walkabilityOverride: walkabilityOverride ?? this.walkabilityOverride,
    );
  }
}

class BiomeMapData {
  final List<List<MapTile>> grid; // grid[row][col]
  final List<List<MapTile?>>? overlayGrid;
  final int height;
  final int width;
  final Point<int> spawnPoint;
  final BiomeConfig config;

  const BiomeMapData({
    required this.grid,
    this.overlayGrid,
    required this.height,
    required this.width,
    required this.spawnPoint,
    required this.config,
  });
}

class MapStringParser {
  static BiomeMapData parse(
    dynamic data, {
    required BiomeConfig config,
    Point<int>? spawn,
  }) {
    List<String> baseLines = [];
    List<String>? overlayLines;
    List<String>? walkLines;

    if (data is Map) {
      if (data.containsKey('layout')) {
        final layout = data['layout'] as Map;
        baseLines = List<String>.from(layout['base'] ?? []);
        if (layout.containsKey('overlay')) {
          overlayLines = List<String>.from(layout['overlay'] ?? []);
        }
      } else {
        // Fallback or flatter Map
        if (data.containsKey('base')) {
          baseLines = List<String>.from(data['base'] ?? []);
        }
        if (data.containsKey('overlay')) {
          overlayLines = List<String>.from(data['overlay'] ?? []);
        }
      }
      if (data.containsKey('walkability')) {
        walkLines = List<String>.from(data['walkability'] ?? []);
      }
      // NEW: Extract spawnPoint if present in the map data
      if (data.containsKey('spawnPoint')) {
        final sp = data['spawnPoint'];
        if (sp is Map) {
          spawn = Point((sp['x'] as num).toInt(), (sp['y'] as num).toInt());
        }
      }
    } else if (data is List) {
      baseLines = List<String>.from(data);
    }

    if (baseLines.isEmpty) {
      return BiomeMapData(
        grid: [],
        height: 0,
        width: 0,
        spawnPoint: spawn ?? const Point(0, 0),
        config: config,
      );
    }

    final int height = baseLines.length;
    int maxWidth = 0;
    for (final line in baseLines) {
      final w = line.split(',').length;
      if (w > maxWidth) maxWidth = w;
    }
    final int width = maxWidth;

    final grid = List.generate(
      height,
      (_) => List<MapTile>.generate(
        width,
        (_) => MapTile(tileId: config.defaultTileId, config: config),
      ),
    );
    final List<List<MapTile?>>? overlayGrid = overlayLines != null
        ? List.generate(height, (_) => List<MapTile?>.filled(width, null))
        : null;

    for (int r = 0; r < height; r++) {
      final baseTiles = baseLines[r].split(',');
      final overlayTiles = overlayLines?[r].split(',');
      final walkValues = walkLines?[r].split(',');

      for (int c = 0; c < width; c++) {
        // Base layer
        if (c < baseTiles.length) {
          final tileId = baseTiles[c].trim();
          final def =
              config.tiles[tileId] ??
              BiomeDataManager.allTiles[tileId] ??
              config.tiles[config.defaultTileId]!;

          bool? walkOverride;
          if (walkValues != null && c < walkValues.length) {
            final val = walkValues[c].trim();
            if (val == '1') walkOverride = true;
            if (val == '0') walkOverride = false;
          }

          grid[r][c] = MapTile(
            tileId: def.id,
            config: config,
            walkabilityOverride: walkOverride,
          );
        }

        // Overlay layer
        if (overlayGrid != null &&
            overlayTiles != null &&
            c < overlayTiles.length) {
          final tileId = overlayTiles[c].trim();
          if (tileId != 'null' && tileId.isNotEmpty) {
            final def =
                config.tiles[tileId] ?? BiomeDataManager.allTiles[tileId];
            if (def != null) {
              overlayGrid[r][c] = MapTile(tileId: def.id, config: config);
            }
          }
        }
      }
    }

    return BiomeMapData(
      grid: grid,
      overlayGrid: overlayGrid,
      height: height,
      width: width,
      spawnPoint: spawn ?? Point(width ~/ 2, height ~/ 2),
      config: config,
    );
  }
}

// ───────────────────────────────────────────────────────────────────
// Swamp map generator
// ───────────────────────────────────────────────────────────────────

class BiomeMapGenerator {
  /// Generates a procedural swamp map.
  ///
  /// The algorithm:
  /// 1. Fill with ground tiles.
  /// 2. Place several irregular water pools using a random-walk flood.
  /// 3. Scatter tall-grass encounter patches.
  /// 4. Place trees, dead trees, rocks, logs, mushrooms.
  /// 5. Carve a walkable path from spawn to ensure connectivity.
  /// 6. Place the player spawn on the path.
  static BiomeMapData generate({
    int width = 30,
    int height = 30,
    Random? rng,
    required BiomeConfig config,
  }) {
    final random = rng ?? Random();
    final grid = List.generate(
      height,
      (_) => List.generate(
        width,
        (_) => MapTile(tileId: config.defaultTileId, config: config),
      ),
    );

    // ── helpers ──
    bool inBounds(int r, int c) => r >= 0 && r < height && c >= 0 && c < width;

    void setTile(int r, int c, MapTile tile) {
      if (inBounds(r, c)) grid[r][c] = tile;
    }

    // ── 1. Water pools (random-walk flood) ──
    final poolCount = 4 + random.nextInt(4); // 4-7 pools
    for (int p = 0; p < poolCount; p++) {
      int pr = 3 + random.nextInt(height - 6);
      int pc = 3 + random.nextInt(width - 6);
      final poolSize = 8 + random.nextInt(15); // 8-22 tiles per pool
      for (int i = 0; i < poolSize; i++) {
        final isDeep = random.nextDouble() < 0.3;
        setTile(
          pr,
          pc,
          MapTile(tileId: isDeep ? 'deep_water' : 'water', config: config),
        );
        // Add lily pads on some water tiles
        if (random.nextDouble() < 0.2) {
          final lr = pr + (random.nextBool() ? 1 : -1);
          final lc = pc + (random.nextBool() ? 1 : -1);
          if (inBounds(lr, lc) &&
              (grid[lr][lc].tileId == 'water' ||
                  grid[lr][lc].tileId == 'deep_water')) {
            setTile(lr, lc, MapTile(tileId: 'lily_pad', config: config));
          }
        }
        // Random walk
        switch (random.nextInt(4)) {
          case 0:
            pr = (pr - 1).clamp(1, height - 2);
            break;
          case 1:
            pr = (pr + 1).clamp(1, height - 2);
            break;
          case 2:
            pc = (pc - 1).clamp(1, width - 2);
            break;
          case 3:
            pc = (pc + 1).clamp(1, width - 2);
            break;
        }
      }
    }

    // ── 2. Mud patches ──
    final mudPatches = 5 + random.nextInt(5);
    for (int m = 0; m < mudPatches; m++) {
      int mr = 1 + random.nextInt(height - 2);
      int mc = 1 + random.nextInt(width - 2);
      final size = 3 + random.nextInt(6);
      for (int i = 0; i < size; i++) {
        if (grid[mr][mc].tileId == config.defaultTileId) {
          setTile(mr, mc, MapTile(tileId: 'mud', config: config));
        }
        switch (random.nextInt(4)) {
          case 0:
            mr = (mr - 1).clamp(1, height - 2);
            break;
          case 1:
            mr = (mr + 1).clamp(1, height - 2);
            break;
          case 2:
            mc = (mc - 1).clamp(1, width - 2);
            break;
          case 3:
            mc = (mc + 1).clamp(1, width - 2);
            break;
        }
      }
    }

    // ── 3. Tall-grass encounter patches ──
    final grassPatches = 8 + random.nextInt(6);
    for (int g = 0; g < grassPatches; g++) {
      int gr = 2 + random.nextInt(height - 4);
      int gc = 2 + random.nextInt(width - 4);
      final size = 4 + random.nextInt(8);
      for (int i = 0; i < size; i++) {
        if (grid[gr][gc].tileId == config.defaultTileId ||
            grid[gr][gc].tileId == 'mud') {
          setTile(gr, gc, MapTile(tileId: 'tall_grass', config: config));
        }
        switch (random.nextInt(4)) {
          case 0:
            gr = (gr - 1).clamp(1, height - 2);
            break;
          case 1:
            gr = (gr + 1).clamp(1, height - 2);
            break;
          case 2:
            gc = (gc - 1).clamp(1, width - 2);
            break;
          case 3:
            gc = (gc + 1).clamp(1, width - 2);
            break;
        }
      }
    }

    // ── 4. Trees & obstacles ──
    for (int r = 0; r < height; r++) {
      for (int c = 0; c < width; c++) {
        if (grid[r][c].tileId != config.defaultTileId) continue;
        final roll = random.nextDouble();
        if (roll < 0.06) {
          setTile(r, c, MapTile(tileId: 'tree', config: config));
        } else if (roll < 0.10) {
          setTile(r, c, MapTile(tileId: 'dead_tree', config: config));
        } else if (roll < 0.12) {
          setTile(r, c, MapTile(tileId: 'rock', config: config));
        } else if (roll < 0.14) {
          setTile(r, c, MapTile(tileId: 'log', config: config));
        } else if (roll < 0.17) {
          setTile(r, c, MapTile(tileId: 'mushroom', config: config));
        } else if (roll < 0.19) {
          setTile(r, c, MapTile(tileId: 'vine', config: config));
        }
      }
    }

    // ── 5. Carve a main winding path for guaranteed connectivity ──
    final spawnR = height - 3;
    final spawnC = width ~/ 2;
    int cr = spawnR, cc = spawnC;
    // Wander upwards creating a path
    while (cr > 2) {
      setTile(cr, cc, MapTile(tileId: 'path', config: config));
      // Also clear adjacent tile for wider path
      if (inBounds(cr, cc + 1)) {
        setTile(cr, cc + 1, MapTile(tileId: 'path', config: config));
      }
      final dir = random.nextDouble();
      if (dir < 0.5) {
        cr--;
      } else if (dir < 0.75) {
        cc = (cc + 1).clamp(1, width - 2);
      } else {
        cc = (cc - 1).clamp(1, width - 2);
      }
    }

    // clear spawn area
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        final nr = spawnR + dr;
        final nc = spawnC + dc;
        if (inBounds(nr, nc)) {
          setTile(nr, nc, MapTile(tileId: 'path', config: config));
        }
      }
    }

    // ── 6. Border – ring the map edges with trees ──
    for (int r = 0; r < height; r++) {
      setTile(r, 0, MapTile(tileId: 'tree', config: config));
      setTile(r, width - 1, MapTile(tileId: 'tree', config: config));
    }
    for (int c = 0; c < width; c++) {
      setTile(0, c, MapTile(tileId: 'tree', config: config));
      setTile(height - 1, c, MapTile(tileId: 'tree', config: config));
    }

    return BiomeMapData(
      grid: grid,
      height: height,
      width: width,
      spawnPoint: Point(spawnC, spawnR),
      config: config,
    );
  }
}
