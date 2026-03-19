import 'dart:math';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:animal_warfare/models/npc_data.dart';


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
  semiSolid, // Renders over the player when they are on it
  floating, // Triggers a jump animation when moved onto
  oneway, // Directional blocking (e.g., jump down only)
  teleporter, // Map transition point
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
      case 'semiSolid':
        return TileCategory.semiSolid;
      case 'floating':
        return TileCategory.floating;
      case 'oneway':
        return TileCategory.oneway;
      case 'teleporter':
        return TileCategory.teleporter;
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

  final bool showInEditor;
  final double? encounterRate;
  final String biome;
  final String? interactionText;

  const TileDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.assetPath,
    required this.symbol,
    this.isAutotiled = false,
    this.layer = 'base',
    this.showInEditor = true,
    this.encounterRate,
    this.biome = 'any',
    this.interactionText,
  });

  bool get isWalkable {
    switch (category) {
      case TileCategory.solid:
      case TileCategory.water:
      case TileCategory.oneway:
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
      showInEditor: json['showInEditor'] ?? true,
      encounterRate: json['encounterRate'] != null
          ? (json['encounterRate'] as num).toDouble()
          : null,
      biome: json['biome'] ?? 'any',
      interactionText: json['interactionText'],
    );
  }
}

class BiomeConfig {
  final String id;
  final String name;
  final String defaultTileId;
  final String? biomeId;
  final Map<String, TileDefinition> tiles;

  final Map<String, List<String>>?
  layout; // e.g. {'base': [...], 'overlay': [...]}
  final Point<int>? spawnPoint;
  final List<MapTransition>? transitions;

  const BiomeConfig({
    required this.id,
    required this.name,
    required this.defaultTileId,
    required this.tiles,
    this.biomeId,
    this.layout,
    this.spawnPoint,
    this.transitions,
  });

  BiomeConfig copyWith({
    String? id,
    String? name,
    String? defaultTileId,
    String? biomeId,
    Map<String, TileDefinition>? tiles,
    Map<String, List<String>>? layout,
    Point<int>? spawnPoint,
    List<MapTransition>? transitions,
  }) {
    return BiomeConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultTileId: defaultTileId ?? this.defaultTileId,
      biomeId: biomeId ?? this.biomeId,
      tiles: tiles ?? this.tiles,
      layout: layout ?? this.layout,
      spawnPoint: spawnPoint ?? this.spawnPoint,
      transitions: transitions ?? this.transitions,
    );
  }

  factory BiomeConfig.fromJson(
    Map<String, dynamic> json,
    Map<String, TileDefinition> allTiles,
  ) {
    final Map<String, TileDefinition> biomeTiles = {};
    if (json['tiles'] != null && (json['tiles'] as List).isNotEmpty) {
      for (String tileId in json['tiles']) {
        if (allTiles.containsKey(tileId)) {
          biomeTiles[tileId] = allTiles[tileId]!;
        }
      }
    } else {
      // Default: include all tiles
      biomeTiles.addAll(allTiles);
    }
    Point<int>? spawn;
    if (json['spawnPoint'] != null) {
      spawn = Point(
        (json['spawnPoint']['x'] as num).toInt(),
        (json['spawnPoint']['y'] as num).toInt(),
      );
    }

    List<MapTransition>? parsedTransitions;
    if (json['transitions'] != null && (json['transitions'] as List).isNotEmpty) {
      parsedTransitions = (json['transitions'] as List)
          .map((t) => MapTransition.fromJson(t))
          .toList();
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
      biomeId: json['biomeId'],
      tiles: biomeTiles,
      layout: layout,
      spawnPoint: spawn,
      transitions: parsedTransitions,
    );
  }
}

class MapTransition {
  final int x;
  final int y;
  final String targetMap;
  final int targetX;
  final int targetY;

  const MapTransition({
    required this.x,
    required this.y,
    required this.targetMap,
    required this.targetX,
    required this.targetY,
  });

  factory MapTransition.fromJson(Map<String, dynamic> json) {
    return MapTransition(
      x: (json['x'] as num).toInt(),
      y: (json['y'] as num).toInt(),
      targetMap: json['targetMap'] as String,
      targetX: (json['targetX'] as num).toInt(),
      targetY: (json['targetY'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'targetMap': targetMap,
      'targetX': targetX,
      'targetY': targetY,
    };
  }
}

class OverworldSpawnData {
  final String pheno;
  final int maxSpawns;
  final double defaultSpeed;
  final double visionRange;
  final String moveTiles;

  const OverworldSpawnData({
    required this.pheno,
    required this.maxSpawns,
    required this.defaultSpeed,
    required this.visionRange,
    required this.moveTiles,
  });

  factory OverworldSpawnData.fromJson(Map<String, dynamic> json) {
    return OverworldSpawnData(
      pheno: json['pheno'] as String,
      maxSpawns: json['max_spawns'] as int? ?? 5,
      defaultSpeed: (json['default_speed'] as num?)?.toDouble() ?? 1.0,
      visionRange: (json['vision_range'] as num?)?.toDouble() ?? 5.0,
      moveTiles: json['move_tiles'] as String? ?? '',
    );
  }
}

class BiomeDataManager {
  static final Map<String, TileDefinition> allTiles = {};
  static final Map<String, BiomeConfig> biomes = {};
  static final Map<String, Map<String, ui.Image>> tileAssets = {};
  static final Map<String, OverworldSpawnData> phenoSpawnData = {};
  static final Set<String> assetBiomeIds = {};
  static final Map<String, Map<String, List<ui.Image>>> npcAssets = {};
  static final List<String> npcTypes = [];

  static const List<String> builtinBiomeIds = ['swamp', 'plains'];

  static Future<File> _getLocalMapsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}${Platform.pathSeparator}custom_maps.json');
  }

  static File? findMapsJsonFile() {
    if (kIsWeb) return null;
    
    // 1. Try common relative paths
    final List<String> commonPaths = [
      'assets/maps.json',
      '../assets/maps.json',
      '../../assets/maps.json',
    ];

    for (final path in commonPaths) {
      final f = File(path);
      if (f.existsSync()) return f;
    }

    // 2. Try to find project root by looking for pubspec.yaml
    try {
      Directory current = Directory.current;
      // Search up to 10 levels up
      for (int i = 0; i < 10; i++) {
        final pubspec = File('${current.path}${Platform.pathSeparator}pubspec.yaml');
        if (pubspec.existsSync()) {
          // Check common locations within project root
          final List<String> assetLocations = [
            'assets${Platform.pathSeparator}maps.json',
            'lib${Platform.pathSeparator}assets${Platform.pathSeparator}maps.json',
          ];
          
          for (final loc in assetLocations) {
            final target = File('${current.path}${Platform.pathSeparator}$loc');
            if (target.existsSync()) return target;
          }
          break; // Found root but no maps.json in expected asset folders
        }
        current = current.parent;
        if (current.path == current.parent.path) break;
      }
    } catch (_) {}

    return null;
  }

  static Future<bool> deleteMap(String mapId) async {
    if (kIsWeb) return false;
    
    // First try to delete from local storage
    try {
      final localFile = await _getLocalMapsFile();
      if (await localFile.exists()) {
        final content = await localFile.readAsString();
        final List<dynamic> maps = json.decode(content);
        final index = maps.indexWhere((m) => m['id'] == mapId);
        if (index != -1) {
          maps.removeAt(index);
          const encoder = JsonEncoder.withIndent('    ');
          await localFile.writeAsString(encoder.convert(maps));
          biomes.remove(mapId);
          return true;
        }
      }
    } catch (_) {}

    final file = findMapsJsonFile();
    if (file == null) return false;

    try {
      final content = await file.readAsString();
      final List<dynamic> maps = json.decode(content);
      final index = maps.indexWhere((m) => m['id'] == mapId);
      if (index != -1) {
        maps.removeAt(index);
        const encoder = JsonEncoder.withIndent('    ');
        await file.writeAsString(encoder.convert(maps));
        biomes.remove(mapId);
        return true;
      }
    } catch (_) {
      // Error handled silently
    }
    return false;
  }

  static Future<bool> saveLocalMap(Map<String, dynamic> mapData) async {
    if (kIsWeb) return false;
    try {
      final file = await _getLocalMapsFile();
      List<dynamic> maps = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        maps = json.decode(content);
      }
      
      final id = mapData['id'];
      final index = maps.indexWhere((m) => m['id'] == id);
      if (index != -1) {
        maps[index] = mapData;
      } else {
        maps.add(mapData);
      }
      
      const encoder = JsonEncoder.withIndent('    ');
      await file.writeAsString(encoder.convert(maps));
      
      // Update cache
      biomes[id] = BiomeConfig.fromJson(mapData, allTiles);
      return true;
    } catch (e) {
      debugPrint('Error saving local map: $e');
      return false;
    }
  }

  static Future<void> loadData() async {
    // Load Tiles
    final tilesJsonStr = await rootBundle.loadString('assets/tiles.json');
    final List<dynamic> tilesJson = json.decode(tilesJsonStr);
    for (var j in tilesJson) {
      final tile = TileDefinition.fromJson(j);
      allTiles[tile.id] = tile;
    }

    // Load Biomes from assets
    final mapsJsonStr = await rootBundle.loadString('assets/maps.json');
    final List<dynamic> mapsJson = json.decode(mapsJsonStr);
    for (var j in mapsJson) {
      final biome = BiomeConfig.fromJson(j, allTiles);
      biomes[biome.id] = biome;
      assetBiomeIds.add(biome.id);
    }

    // Load custom maps from local storage (Mobile Fallback)
    if (!kIsWeb) {
      try {
        final localFile = await _getLocalMapsFile();
        if (await localFile.exists()) {
          final localContent = await localFile.readAsString();
          final List<dynamic> localMapsJson = json.decode(localContent);
          for (var j in localMapsJson) {
            final biome = BiomeConfig.fromJson(j, allTiles);
            biomes[biome.id] = biome; // Overwrite or add
          }
        }
      } catch (e) {
        debugPrint('Error loading local custom maps: $e');
      }
    }

    // Pre-load all tile assets in parallel for better performance
    final List<Future<void>> loadTasks = [];
    for (final tile in allTiles.values) {
      tileAssets[tile.id] = {};

      Future<void> loadInto(String dir, String path) async {
        final img = await loadImage(path);
        if (img != null) {
          tileAssets[tile.id]![dir] = img;
        }
      }

      if (tile.isAutotiled) {
        for (final dir in ['center', 'up', 'down', 'left', 'right']) {
          final path = tile.assetPath.replaceAll('{dir}', dir);
          loadTasks.add(loadInto(dir, path));
        }
      } else {
        loadTasks.add(loadInto('center', tile.assetPath));
      }
    }
    await Future.wait(loadTasks);

    // Load Overworld Spawn Data
    try {
      final spawnsJsonStr = await rootBundle.loadString(
        'assets/overworld_spawns.json',
      );
      final List<dynamic> spawnsJson = json.decode(spawnsJsonStr);
      for (var s in spawnsJson) {
        final data = OverworldSpawnData.fromJson(s);
        phenoSpawnData[data.pheno] = data;
      }
    } catch (e) {
      debugPrint('Error loading spawns: $e');
    }

    // Load NPC Metadata
    try {
      final npcJsonStr = await rootBundle.loadString('assets/npc_sprite.json');
      final List<dynamic> npcJson = json.decode(npcJsonStr);
      npcTypes.clear();
      for (var n in npcJson) {
        npcTypes.add(n['id']);
      }
    } catch (e) {
      debugPrint('Error loading NPC metadata: $e');
      if (npcTypes.isEmpty) {
        npcTypes.addAll(['placeholder', 'shopkeeper', 'medic', 'villager']);
      }
    }

    // Load NPC assets
    for (var type in npcTypes) {
      npcAssets[type] = {};
      bool foundAny = false;
      for (var dir in ['up', 'down', 'left', 'right']) {
        npcAssets[type]![dir] = [];
        for (var frame = 0; frame <= 3; frame++) {
          final path = 'assets/overworld/npc/${type}_${dir}_$frame.png';
          final img = await loadImage(path);
          if (img != null) {
            npcAssets[type]![dir]!.add(img);
            foundAny = true;
          }
        }
      }
      
      // Fallback to placeholder if this type has no assets
      if (!foundAny && type != 'placeholder') {
        debugPrint('NPC type "$type" assets not found, falling back to placeholder.');
        final placeholder = npcAssets['placeholder'];
        if (placeholder != null) {
          npcAssets[type] = placeholder;
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
    if (biomes.containsKey(id)) {
      return biomes[id]!;
    }
    // Create a virtual biome config for unrecognized IDs.
    // This allows custom maps (like 'mangrove') to function with their correct name
    // for spawning even if they don't have a specific map entry in maps.json.
    final name = id
        .split('_')
        .map((s) {
          if (s.isEmpty) return '';
          return s[0].toUpperCase() + s.substring(1).toLowerCase();
        })
        .join(' ');

    return BiomeConfig(
      id: id,
      name: name,
      tiles:
          allTiles, // Fallback to all tiles if specifically filtered list is unavailable
      defaultTileId: allTiles.containsKey('${id}_ground')
          ? '${id}_ground'
          : (allTiles.isNotEmpty ? allTiles.keys.first : 'ground'),
    );
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
      config.tiles[tileId] ??
      BiomeDataManager.allTiles[tileId] ??
      config.tiles[config.defaultTileId] ??
      BiomeDataManager.allTiles[config.defaultTileId] ??
      BiomeDataManager.allTiles.values.first;

  TileCategory get category => definition.category;

  bool get isWalkable => walkabilityOverride ?? definition.isWalkable;

  bool get hasEncounter => definition.hasEncounter;

  double? get encounterRate => definition.encounterRate;

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
  final List<List<List<MapTile>>>? overlayGrid; // grid[row][col][layerIndex]
  final int height;
  final int width;
  final Point<int> spawnPoint;
  final BiomeConfig config;
  final String? name;
  final String? biomeId;
  final List<MapTransition>? transitions;
  final List<NPCData>? npcs;

  const BiomeMapData({
    required this.grid,
    this.overlayGrid,
    required this.height,
    required this.width,
    required this.spawnPoint,
    required this.config,
    this.name,
    this.biomeId,
    this.transitions,
    this.npcs,
  });
}

class MapStringParser {
  static BiomeMapData parse(
    dynamic data, {
    required BiomeConfig config,
    Point<int>? spawn,
    String? name,
    String? biomeId,
  }) {
    List<String> baseLines = [];
    List<String>? overlayLines;
    List<String>? walkLines;

    List<NPCData>? npcs;

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
      if (data.containsKey('name')) {
        name = data['name'] as String;
      }
      if (data.containsKey('biomeId')) {
        biomeId = data['biomeId'] as String;
      }
      if (data.containsKey('transitions')) {
        config = config.copyWith(
          transitions: (data['transitions'] as List)
              .map((t) => MapTransition.fromJson(t))
              .toList(),
        );
      }
      if (data.containsKey('npcs')) {
        npcs = (data['npcs'] as List)
            .map((n) => NPCData.fromJson(n))
            .toList();
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
        name: name,
        biomeId: biomeId,
        transitions: config.transitions,
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
    final List<List<List<MapTile>>>? overlayGrid = overlayLines != null
        ? List.generate(height, (_) => List.generate(width, (_) => <MapTile>[]))
        : null;

    for (int r = 0; r < height; r++) {
      final baseTiles = baseLines[r].split(',');
      final overlayTiles = overlayLines?[r].split(',');
      final walkValues = walkLines?[r].split(',');

      for (int c = 0; c < width; c++) {
        bool? walkOverride;
        if (walkValues != null && c < walkValues.length) {
          final val = walkValues[c].trim();
          if (val == '1') walkOverride = true;
          if (val == '0') walkOverride = false;
        }

        // Base layer
        if (c < baseTiles.length) {
          final tileId = baseTiles[c].trim();
          final def =
              config.tiles[tileId] ??
              BiomeDataManager.allTiles[tileId] ??
              config.tiles[config.defaultTileId] ??
              BiomeDataManager.allTiles[config.defaultTileId] ??
              BiomeDataManager.allTiles.values.first;

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
          final raw = overlayTiles[c].trim();
          if (raw != 'null' && raw.isNotEmpty && raw != '.') {
            final parts = raw.split('|');
            for (final p in parts) {
              final tileId = p.trim();
              if (tileId.isEmpty || tileId == '.') continue;
              final def =
                  config.tiles[tileId] ?? BiomeDataManager.allTiles[tileId];
              if (def != null) {
                overlayGrid[r][c].add(
                  MapTile(
                    tileId: def.id,
                    config: config,
                    walkabilityOverride: walkOverride,
                  ),
                );
              }
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
      name: name,
      biomeId: biomeId,
      transitions: config.transitions,
      npcs: npcs,
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

    // ── 6. Border – ring the map edges with solid border tiles ──
    for (int r = 0; r < height; r++) {
      setTile(r, 0, MapTile(tileId: 'border', config: config));
      setTile(r, width - 1, MapTile(tileId: 'border', config: config));
    }
    for (int c = 0; c < width; c++) {
      setTile(0, c, MapTile(tileId: 'border', config: config));
      setTile(height - 1, c, MapTile(tileId: 'border', config: config));
    }

    return BiomeMapData(
      grid: grid,
      height: height,
      width: width,
      spawnPoint: Point(spawnC, spawnR),
      config: config,
      name: config.name,
      biomeId: config.biomeId,
      transitions: config.transitions,
    );
  }
}
