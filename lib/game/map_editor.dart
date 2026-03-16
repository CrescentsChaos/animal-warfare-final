import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animal_warfare/models/npc_data.dart';
import 'biome_map_data.dart';

// ────────────────────────────────────────────────────────────────────
// Editor Modes & Undo System
// ────────────────────────────────────────────────────────────────────

enum EditorMode {
  pan,
  draw,
  eraser,
  bucket,
  eyedropper,
  walkability,
  spawnPoint,
  teleporter,
  npc,
  move,
}

enum PaletteState { compact, full }

/// Snapshot for undo/redo
class _EditorSnapshot {
  final List<List<String>> grid;
  final List<List<List<String>>> overlayGrid;
  final List<List<bool>> isWalkable;
  final int spawnR;
  final int spawnC;
  final List<MapTransition> teleporters;
  final List<NPCData> npcs;

  _EditorSnapshot({
    required this.grid,
    required this.overlayGrid,
    required this.isWalkable,
    required this.spawnR,
    required this.spawnC,
    required this.teleporters,
    required this.npcs,
  });

  _EditorSnapshot deepCopy() => _EditorSnapshot(
    grid: grid.map((r) => List<String>.from(r)).toList(),
    overlayGrid: overlayGrid
        .map((r) => r.map((c) => List<String>.from(c)).toList())
        .toList(),
    isWalkable: isWalkable.map((r) => List<bool>.from(r)).toList(),
    spawnR: spawnR,
    spawnC: spawnC,
    teleporters: teleporters.map((t) => MapTransition.fromJson(t.toJson())).toList(),
    npcs: npcs.map((n) => NPCData.fromJson(n.toJson())).toList(),
  );
}

// ────────────────────────────────────────────────────────────────────
// Map Editor Widget
// ────────────────────────────────────────────────────────────────────

class MapEditor extends StatefulWidget {
  final String biomeId;
  const MapEditor({super.key, this.biomeId = 'swamp'});

  // Premium Theme Constants
  static const Color premiumBg = Color(0xFF050505);
  static const Color premiumSurface = Color(0xFF121212);
  static const Color premiumGold = Color(0xFFFFD700);
  static const Color premiumGoldMuted = Color(0xFFB8860B);
  static const Color premiumGoldGlow = Color(0x4DFFD700); // 30% opacity

  @override
  State<MapEditor> createState() => _MapEditorState();
}

class _MapEditorState extends State<MapEditor> {
  // Grid
  int _rows = 20;
  int _cols = 20;
  late List<List<String>> _grid;
  late List<List<List<String>>> _overlayGrid;
  late List<List<bool>> _isWalkable;
  int _spawnR = 1;
  int _spawnC = 1;
  List<MapTransition> _teleporters = [];
  List<NPCData> _npcs = [];

  static const List<String> _biomeIds = [
    'Volcano',
    'Cave',
    'Coastal',
    'Coral Reef',
    'Deep Sea',
    'Frozen Ocean',
    'Kelp Forest',
    'Swamp',
    'Lake',
    'Mangrove',
    'Polar',
    'Rainforest',
    'Taiga',
    'Tundra',
    'Urban',
    'Jungle',
    'Desert',
    'Savanna',
    'River',
    'Ocean',
    'Mountain',
    'Redwoods',
    'Wetlands',
    'Plains',
  ];

  // Editor state
  String _selectedTile = 'swamp_ground';
  EditorMode _mode = EditorMode.pan;
  bool _showGrid = true;
  bool _autoBase = true;
  String _hoverInfo = '';
  bool?
  _dragWalkValue; // Store the target walkability for the current drag stroke
  NPCData? _draggingNPC;

  // Biome context
  late String _biomeId;
  late BiomeConfig _biomeConfig;
  late List<String> _baseTiles;
  late List<String> _overlayTiles;
  // String _borderTile = 'tree'; // REMOVED - using 'border' literal or per-tile config

  // Undo/Redo
  final List<_EditorSnapshot> _undoStack = [];
  final List<_EditorSnapshot> _redoStack = [];
  static const int _maxUndoSize = 50;

  // Transform
  final TransformationController _transController = TransformationController();
  int _pointerCount = 0;

  // Palette
  PaletteState _paletteState = PaletteState.compact;
  final ScrollController _paletteScrollController = ScrollController();
  final GlobalKey _selectedTileKey = GlobalKey();

  // Title Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _biomeId = widget.biomeId;
    _biomeConfig = BiomeDataManager.getBiome(_biomeId);
    _refreshTileCategories();

    _selectedTile = _biomeConfig.defaultTileId.isNotEmpty
        ? _biomeConfig.defaultTileId
        : (_baseTiles.isNotEmpty ? _baseTiles.first : 'swamp_ground');

    _initGrid();
    _loadFromPrefs();
  }

  void _refreshTileCategories() {
    _baseTiles = [];
    _overlayTiles = [];
    for (final entry in _biomeConfig.tiles.entries) {
      if (!entry.value.showInEditor) continue;

      // Multi-biome filter
      final tileBiome = entry.value.biome.toLowerCase();
      final bioList = tileBiome.split(',').map((s) => s.trim()).toList();
      final isAny = tileBiome == 'any';
      final isMatch = bioList.contains(_biomeId);

      if (!isAny && !isMatch) continue;

      if (entry.value.layer == 'overlay') {
        _overlayTiles.add(entry.key);
      } else {
        _baseTiles.add(entry.key);
      }
    }
  }

  void _initGrid() {
    final defaultBase = _biomeConfig.defaultTileId.isNotEmpty
        ? _biomeConfig.defaultTileId
        : (_baseTiles.isNotEmpty ? _baseTiles.first : 'swamp_ground');
    _grid = List.generate(
      _rows,
      (_) => List.generate(_cols, (_) => defaultBase),
    );
    _overlayGrid = List.generate(
      _rows,
      (_) => List.generate(_cols, (_) => <String>[]),
    );
    _isWalkable = List.generate(
      _rows,
      (_) => List.generate(_cols, (_) => true),
    );
    _spawnR = (_rows / 2).floor();
    _spawnC = (_cols / 2).floor();
    _teleporters = [];
    _npcs = [];
    _applyBorder();
    _pushUndo();
  }

  void _applyBorder() {
    // Fill outermost ring with border tile on BOTH layers
    for (int c = 0; c < _cols; c++) {
      // Top row
      _grid[0][c] = _biomeConfig.defaultTileId;
      if (!_overlayGrid[0][c].contains('border')) {
        _overlayGrid[0][c].add('border');
      }
      _isWalkable[0][c] = false;
      // Bottom row
      _grid[_rows - 1][c] = _biomeConfig.defaultTileId;
      if (!_overlayGrid[_rows - 1][c].contains('border')) {
        _overlayGrid[_rows - 1][c].add('border');
      }
      _isWalkable[_rows - 1][c] = false;
    }
    for (int r = 0; r < _rows; r++) {
      // Left col
      _grid[r][0] = _biomeConfig.defaultTileId;
      if (!_overlayGrid[r][0].contains('border')) {
        _overlayGrid[r][0].add('border');
      }
      _isWalkable[r][0] = false;
      // Right col
      _grid[r][_cols - 1] = _biomeConfig.defaultTileId;
      if (!_overlayGrid[r][_cols - 1].contains('border')) {
        _overlayGrid[r][_cols - 1].add('border');
      }
      _isWalkable[r][_cols - 1] = false;
    }
  }

  bool _isBorderCell(int r, int c) {
    return r == 0 || r == _rows - 1 || c == 0 || c == _cols - 1;
  }

  void _resetMap() {
    setState(() {
      final defaultBase = _biomeConfig.defaultTileId.isNotEmpty
          ? _biomeConfig.defaultTileId
          : (_baseTiles.isNotEmpty ? _baseTiles.first : 'swamp_ground');
      _grid = List.generate(
        _rows,
        (_) => List.generate(_cols, (_) => defaultBase),
      );
      _overlayGrid = List.generate(
        _rows,
        (_) => List.generate(_cols, (_) => <String>[]),
      );
      _isWalkable = List.generate(
        _rows,
        (_) => List.generate(_cols, (_) => true),
      );
      _spawnR = (_rows / 2).floor();
      _spawnC = (_cols / 2).floor();
      _teleporters = [];
      _npcs = [];
      _applyBorder();
      _undoStack.clear();
      _redoStack.clear();
      _pushUndo();
    });
    _saveToPrefs();
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Reset Map?', style: TextStyle(color: Colors.white)),
        content: const Text('This will clear everything.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              _resetMap();
              Navigator.pop(ctx);
            },
            child: const Text('RESET', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── Undo/Redo ─────────────────────────────────────────────────────
  void _pushUndo() {
    _undoStack.add(
      _EditorSnapshot(
        grid: _grid.map((r) => List<String>.from(r)).toList(),
        overlayGrid: _overlayGrid
            .map((r) => r.map((c) => List<String>.from(c)).toList())
            .toList(),
        isWalkable: _isWalkable.map((r) => List<bool>.from(r)).toList(),
        spawnR: _spawnR,
        spawnC: _spawnC,
        teleporters: _teleporters.map((t) => MapTransition.fromJson(t.toJson())).toList(),
        npcs: _npcs.map((n) => NPCData.fromJson(n.toJson())).toList(),
      ),
    );
    if (_undoStack.length > _maxUndoSize) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _undo() {
    if (_undoStack.length <= 1) return;
    _redoStack.add(_undoStack.removeLast());
    final snap = _undoStack.last.deepCopy();
    setState(() {
      _grid = snap.grid;
      _overlayGrid = snap.overlayGrid;
      _isWalkable = snap.isWalkable;
      _spawnR = snap.spawnR;
      _spawnC = snap.spawnC;
      _teleporters = snap.teleporters;
      _npcs = snap.npcs;
    });
    _saveToPrefs();
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final snap = _redoStack.removeLast().deepCopy();
    _undoStack.add(snap.deepCopy());
    setState(() {
      _grid = snap.grid;
      _overlayGrid = snap.overlayGrid;
      _isWalkable = snap.isWalkable;
      _spawnR = snap.spawnR;
      _spawnC = snap.spawnC;
      _teleporters = snap.teleporters;
      _npcs = snap.npcs;
    });
    _saveToPrefs();
  }

  // ── Persistence ───────────────────────────────────────────────────
  Future<void> _saveToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('map_editor_grid_v3', jsonEncode(_grid));
    await prefs.setString('map_editor_overlay_v3', jsonEncode(_overlayGrid));
    await prefs.setString('map_editor_walk_v3', jsonEncode(_isWalkable));
    await prefs.setString(
      'map_editor_spawn_v3',
      jsonEncode({'r': _spawnR, 'c': _spawnC}),
    );
    await prefs.setString(
      'map_editor_size_v3',
      jsonEncode({'rows': _rows, 'cols': _cols}),
    );
    await prefs.setString('map_editor_biome_v3', _biomeId);
    await prefs.setString('map_editor_teleporters_v3', jsonEncode(_teleporters.map((t) => t.toJson()).toList()));
    await prefs.setString('map_editor_npcs_v3', jsonEncode(_npcs.map((n) => n.toJson()).toList()));
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedBiome = prefs.getString('map_editor_biome_v3');

    final String? sizeData = prefs.getString('map_editor_size_v3');
    if (sizeData != null) {
      final s = jsonDecode(sizeData);
      _rows = s['rows'] ?? 20;
      _cols = s['cols'] ?? 20;
    }

    final String? baseData = prefs.getString('map_editor_grid_v3');
    final String? overlayData = prefs.getString('map_editor_overlay_v3');
    final String? walkableData = prefs.getString('map_editor_walk_v3');
    final String? spawnData = prefs.getString('map_editor_spawn_v3');
    final String? teleportsData = prefs.getString('map_editor_teleporters_v3');
    final String? npcsData = prefs.getString('map_editor_npcs_v3');

    setState(() {
      if (savedBiome != null && savedBiome != _biomeId) {
        _biomeId = savedBiome;
        _biomeConfig = BiomeDataManager.getBiome(_biomeId);
        _refreshTileCategories();

        _selectedTile = _biomeConfig.defaultTileId.isNotEmpty
            ? _biomeConfig.defaultTileId
            : (_baseTiles.isNotEmpty ? _baseTiles.first : 'swamp_ground');
      }

      if (baseData != null) {
        final List<dynamic> decoded = jsonDecode(baseData);
        _grid = decoded.map((row) => List<String>.from(row)).toList();
        _rows = _grid.length;
        _cols = _grid.isNotEmpty ? _grid[0].length : 20;
      }
      if (overlayData != null) {
        final List<dynamic> decoded = jsonDecode(overlayData);
        _overlayGrid = decoded.map((row) {
          return (row as List).map((cell) {
            if (cell is List) return List<String>.from(cell);
            if (cell is String) {
              return [cell]; // Migration for old single-string format
            }
            return <String>[];
          }).toList();
        }).toList();
      }
      if (walkableData != null) {
        final List<dynamic> decoded = jsonDecode(walkableData);
        _isWalkable = decoded.map((row) => List<bool>.from(row)).toList();
      }
      if (spawnData != null) {
        final sp = jsonDecode(spawnData);
        _spawnR = sp['r'] ?? _spawnR;
        _spawnC = sp['c'] ?? _spawnC;
      }
      if (teleportsData != null) {
        final List<dynamic> decoded = jsonDecode(teleportsData);
        _teleporters = decoded.map((t) => MapTransition.fromJson(t)).toList();
      }
      if (npcsData != null) {
        final List<dynamic> decoded = jsonDecode(npcsData);
        _npcs = decoded.map((n) => NPCData.fromJson(n)).toList();
      }
    });
  }

  // ── Tile Placement ────────────────────────────────────────────────
  bool _getDefaultWalkability(String tileId) {
    final def = BiomeDataManager.allTiles[tileId];
    return def?.isWalkable ?? true;
  }

  void _paintTile(int r, int c) {
    if (r < 0 || r >= _rows || c < 0 || c >= _cols) return;
    if (_isBorderCell(r, c)) return; // Don't draw on border

    final def = BiomeDataManager.allTiles[_selectedTile];
    if (def == null) return;

    setState(() {
      if (def.layer == 'overlay') {
        // Multi-overlay: only add if not already there (to avoid duplicates)
        if (!_overlayGrid[r][c].contains(_selectedTile)) {
          _overlayGrid[r][c].add(_selectedTile);
        }
        // Auto-base: ensure a ground tile is underneath
        if (_autoBase) {
          final currentBase = BiomeDataManager.allTiles[_grid[r][c]];
          if (currentBase == null ||
              currentBase.category == TileCategory.solid) {
            _grid[r][c] = _baseTiles.isNotEmpty
                ? _baseTiles.first
                : 'swamp_ground';
          }
        }
      } else {
        _grid[r][c] = _selectedTile;
      }
      _isWalkable[r][c] = _getDefaultWalkability(
        _overlayGrid[r][c].isNotEmpty ? _overlayGrid[r][c].last : _grid[r][c],
      );
    });
  }

  void _eraseTile(int r, int c) {
    if (r < 0 || r >= _rows || c < 0 || c >= _cols) return;
    if (_isBorderCell(r, c)) return;

    if (_mode == EditorMode.teleporter) {
       setState(() {
         _teleporters.removeWhere((t) => t.x == c && t.y == r);
       });
       return;
    }

    setState(() {
      // Erase overlay first by popping the stack; if empty, reset base
      if (_overlayGrid[r][c].isNotEmpty) {
        _overlayGrid[r][c].removeLast();
      } else {
        _grid[r][c] = _baseTiles.isNotEmpty ? _baseTiles.first : 'swamp_ground';
      }
      _isWalkable[r][c] = _getDefaultWalkability(
        _overlayGrid[r][c].isNotEmpty ? _overlayGrid[r][c].last : _grid[r][c],
      );
    });
  }

  void _handleBucket(int r, int c) {
    if (r < 0 || r >= _rows || c < 0 || c >= _cols) return;
    if (_isBorderCell(r, c)) return;

    final def = BiomeDataManager.allTiles[_selectedTile];
    if (def == null) return;

    final isOverlay = def.layer == 'overlay';
    // For overlay, we consider the "target" what's currently on top.
    final targetTile = isOverlay
        ? (_overlayGrid[r][c].isNotEmpty ? _overlayGrid[r][c].last : null)
        : _grid[r][c];

    if (targetTile == _selectedTile) return;

    setState(() {
      _floodFill(r, c, targetTile, _selectedTile, isOverlay);
    });
  }

  void _floodFill(
    int r,
    int c,
    String? target,
    String replacement,
    bool isOverlay,
  ) {
    if (r < 0 || r >= _rows || c < 0 || c >= _cols) return;
    if (_isBorderCell(r, c)) return;

    final current = isOverlay
        ? (_overlayGrid[r][c].isNotEmpty ? _overlayGrid[r][c].last : null)
        : _grid[r][c];
    if (current != target) return;

    if (isOverlay) {
      if (!_overlayGrid[r][c].contains(replacement)) {
        _overlayGrid[r][c].add(replacement);
      }
      if (_autoBase) {
        final currentBase = BiomeDataManager.allTiles[_grid[r][c]];
        if (currentBase == null || currentBase.category == TileCategory.solid) {
          _grid[r][c] = _baseTiles.isNotEmpty
              ? _baseTiles.first
              : 'swamp_ground';
        }
      }
    } else {
      _grid[r][c] = replacement;
    }
    _isWalkable[r][c] = _getDefaultWalkability(replacement);

    _floodFill(r - 1, c, target, replacement, isOverlay);
    _floodFill(r + 1, c, target, replacement, isOverlay);
    _floodFill(r, c - 1, target, replacement, isOverlay);
    _floodFill(r, c + 1, target, replacement, isOverlay);
  }

  void _handleEyedropper(int r, int c) {
    if (r < 0 || r >= _rows || c < 0 || c >= _cols) return;
    setState(() {
      // Pick top overlay first, then base
      final picked = _overlayGrid[r][c].isNotEmpty
          ? _overlayGrid[r][c].last
          : _grid[r][c];
      _selectedTile = picked;
      _mode = EditorMode.draw;
    });
  }

  void _handleInteraction(int r, int c, bool isStart) {
    if (_mode == EditorMode.pan) return;
    if (r < 0 || r >= _rows || c < 0 || c >= _cols) return;

    setState(() => _hoverInfo = '($r, $c)');

    switch (_mode) {
      case EditorMode.draw:
        _paintTile(r, c);
        break;
      case EditorMode.eraser:
        _eraseTile(r, c);
        break;
      case EditorMode.bucket:
        if (isStart) _handleBucket(r, c);
        break;
      case EditorMode.eyedropper:
        if (isStart) _handleEyedropper(r, c);
        break;
      case EditorMode.walkability:
        if (!_isBorderCell(r, c)) {
          if (isStart) {
            // Toggle the first tile and set the drag value for subsequent tiles in this stroke
            _dragWalkValue = !_isWalkable[r][c];
            setState(() => _isWalkable[r][c] = _dragWalkValue!);
          } else if (_dragWalkValue != null) {
            // Continue applying the same value throughout the drag
            if (_isWalkable[r][c] != _dragWalkValue) {
              setState(() => _isWalkable[r][c] = _dragWalkValue!);
            }
          }
        }
        break;
      case EditorMode.spawnPoint:
        if (isStart && !_isBorderCell(r, c)) {
          setState(() {
            _spawnR = r;
            _spawnC = c;
          });
        }
        break;
      case EditorMode.teleporter:
        if (isStart && !_isBorderCell(r, c)) {
          _showTeleporterDialog(r, c);
        }
        break;
      case EditorMode.npc:
        if (!_isBorderCell(r, c)) {
          _showNPCDialog(r, c, isStart);
        }
        break;
      case EditorMode.move:
        if (isStart) {
          try {
            _draggingNPC = _npcs.firstWhere((n) => n.row == r && n.col == c);
          } catch (_) {
            _draggingNPC = null;
          }
        } else if (_draggingNPC != null) {
          if (!_isBorderCell(r, c)) {
             setState(() {
               final idx = _npcs.indexOf(_draggingNPC!);
               if (idx != -1) {
                 _npcs[idx] = _draggingNPC!.copyWith(row: r, col: c);
                 _draggingNPC = _npcs[idx];
               }
             });
          }
        }
        break;
      default:
        break;
    }
}

  void _showTeleporterDialog(int r, int c) {
    final existing = _teleporters.firstWhere((t) => t.x == c && t.y == r, orElse: () => MapTransition(x: c, y: r, targetMap: _biomeId, targetX: 10, targetY: 10));
    final targetMapCtrl = TextEditingController(text: existing.targetMap);
    final targetXCtrl = TextEditingController(text: existing.targetX.toString());
    final targetYCtrl = TextEditingController(text: existing.targetY.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Configure Teleporter', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Target Map ID', style: TextStyle(color: Colors.white70, fontSize: 12)),
            DropdownButton<String>(
              isExpanded: true,
              value: BiomeDataManager.biomes.keys.contains(targetMapCtrl.text)
                  ? targetMapCtrl.text
                  : BiomeDataManager.biomes.keys.first,
              dropdownColor: const Color(0xFF2A2A2A),
              style: const TextStyle(color: Colors.white),
              items: BiomeDataManager.biomes.keys.map((id) {
                return DropdownMenuItem(
                  value: id,
                  child: Text(id),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  targetMapCtrl.text = val;
                  (ctx as Element).markNeedsBuild(); // Force rebuild of the dialog to show selection
                }
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: targetXCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Target X', labelStyle: TextStyle(color: Colors.white70)),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: targetYCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Target Y', labelStyle: TextStyle(color: Colors.white70)),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (_teleporters.any((t) => t.x == c && t.y == r))
            TextButton(
               onPressed: () {
                 setState(() {
                   _teleporters.removeWhere((t) => t.x == c && t.y == r);
                 });
                 Navigator.pop(ctx);
                 _onInteractionEnd();
               },
               child: const Text('REMOVE', style: TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              final mapId = targetMapCtrl.text.trim();
              final tx = int.tryParse(targetXCtrl.text) ?? 10;
              final ty = int.tryParse(targetYCtrl.text) ?? 10;
              setState(() {
                _teleporters.removeWhere((t) => t.x == c && t.y == r);
                _teleporters.add(MapTransition(x: c, y: r, targetMap: mapId, targetX: tx, targetY: ty));
              });
              Navigator.pop(ctx);
              _onInteractionEnd();
            },
            child: const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNPCDialog(int r, int c, bool isStart) {
    NPCData? existing;
    try {
      existing = _npcs.firstWhere((n) => n.row == r && n.col == c);
    } catch (_) {}

    if (!isStart) {
      return; // Tap and hold is not explicitly used for placement, just regular tap/longPress behavior in Flutter
    }

    // If tapping an empty tile in NPC mode, place a default NPC
    if (existing == null) {
      if (!isStart) return;
      final newNpc = NPCData(
        id: 'npc_${DateTime.now().millisecondsSinceEpoch}',
        name: 'New NPC',
        spriteKey: 'placeholder',
        row: r,
        col: c,
        dialogue: ['Hello!'],
      );
      setState(() {
        _npcs.add(newNpc);
      });
      _onInteractionEnd();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('NPC placed! Tap again to edit.')),
      );
      return;
    }

    // If tapping an existing NPC, open editor
    final nameCtrl = TextEditingController(text: existing.name);
    final scriptCtrl = TextEditingController(text: existing.scriptType);
    final dialogueCtrl = TextEditingController(text: existing.dialogue.join('\n'));
    final spriteCtrl = TextEditingController(text: existing.spriteKey);
    String movementType = existing.movementType;
    final rangeCtrl = TextEditingController(text: existing.movementRange.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Edit NPC', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name', labelStyle: TextStyle(color: Colors.white70)),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                const Text('Sprite Asset', style: TextStyle(color: Colors.white70, fontSize: 12)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: BiomeDataManager.npcTypes.contains(spriteCtrl.text) ? spriteCtrl.text : 'placeholder',
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  items: BiomeDataManager.npcTypes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => spriteCtrl.text = val);
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text('Script Type', style: TextStyle(color: Colors.white70, fontSize: 12)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: ['none', 'shopkeeper', 'medic'].contains(scriptCtrl.text) ? scriptCtrl.text : 'none',
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  items: ['none', 'shopkeeper', 'medic'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => scriptCtrl.text = val);
                    }
                  },
                ),
                const SizedBox(height: 8),
                const Text('Movement Type', style: TextStyle(color: Colors.white70, fontSize: 12)),
                DropdownButton<String>(
                  isExpanded: true,
                  value: movementType,
                  dropdownColor: const Color(0xFF2A2A2A),
                  style: const TextStyle(color: Colors.white),
                  items: ['still', 'random', 'pattern'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => movementType = val);
                    }
                  },
                ),
                if (movementType != 'still')
                  TextField(
                    controller: rangeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Range (blocks)', labelStyle: TextStyle(color: Colors.white70)),
                    style: const TextStyle(color: Colors.white),
                  ),
                TextField(
                  controller: dialogueCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Dialogue (one per line)', labelStyle: TextStyle(color: Colors.white70)),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _npcs.removeWhere((n) => n.row == r && n.col == c);
                });
                Navigator.pop(ctx);
                _onInteractionEnd();
              },
              child: const Text('DELETE', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                final updated = existing!.copyWith(
                  name: nameCtrl.text.trim(),
                  spriteKey: spriteCtrl.text.trim(),
                  scriptType: scriptCtrl.text,
                  dialogue: dialogueCtrl.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
                  movementType: movementType,
                  movementRange: int.tryParse(rangeCtrl.text) ?? 0,
                );
                setState(() {
                  final idx = _npcs.indexWhere((n) => n.row == r && n.col == c);
                  _npcs[idx] = updated;
                });
                Navigator.pop(ctx);
                _onInteractionEnd();
              },
              child: const Text('SAVE'),
            ),
          ],
        ),
      ),
    );
  }

  void _onInteractionEnd() {
    // Push undo after completing a paint stroke
    if (_mode != EditorMode.pan && _mode != EditorMode.eyedropper) {
      _pushUndo();
      _saveToPrefs();
    }
    _dragWalkValue = null; // Reset drag state
    _draggingNPC = null;
  }

  // ── Export: maps.json-compatible format ─────────────────────────
  String _exportForMapsJson() {
    final Map<String, dynamic> exportData = {
      "id": _biomeId,
      "name": _biomeConfig.name,
      "defaultTileId": _biomeConfig.defaultTileId,
      "layout": {
        "base": _grid.map((row) => row.join(',')).toList(),
        "overlay": _overlayGrid
            .map(
              (row) => row
                  .map((cell) => cell.isEmpty ? 'null' : cell.join('|'))
                  .join(','),
            )
            .toList(),
        "walkability": _isWalkable
            .map((row) => row.map((w) => w ? '1' : '0').join(','))
            .toList(),
      },
      "spawnPoint": {"x": _spawnC, "y": _spawnR},
      "transitions": _teleporters.map((t) => t.toJson()).toList(),
      "npcs": _npcs.map((n) => n.toJson()).toList(),
    };
    const encoder = JsonEncoder.withIndent('    ');
    return encoder.convert(exportData);
  }

  Future<void> _saveToFile() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Direct save not supported on Web')),
      );
      return;
    }

    try {
      final exportMapString = _exportForMapsJson();
      Map<String, dynamic> exportMap = json.decode(exportMapString);
      
      // Redirect if this is a built-in map from assets
      if (BiomeDataManager.assetBiomeIds.contains(_biomeId)) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final newId = 'custom_${_biomeId}_$timestamp';
        final newName = '${_biomeConfig.name} (Custom)';
        
        exportMap['id'] = newId;
        exportMap['name'] = newName;
        
        setState(() {
          _biomeId = newId;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Creating new custom map: $newName'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
      final file = BiomeDataManager.findMapsJsonFile();
      if (file == null) {
        // Fallback: Save to local app storage (Mobile/Emulator)
        final success = await BiomeDataManager.saveLocalMap(exportMap);
        if (success) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved to device storage! Map will persist.'),
              backgroundColor: Colors.blueAccent,
            ),
          );
          
          final newConfig = BiomeConfig.fromJson(exportMap, BiomeDataManager.allTiles);
          setState(() { _biomeConfig = newConfig; });
          return;
        }

        if (!mounted) return;
        showDialog(
           context: context,
           builder: (ctx) => AlertDialog(
             backgroundColor: const Color(0xFF141420),
             title: const Text('Export Map JSON', style: TextStyle(color: Colors.white)),
             content: SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 crossAxisAlignment: CrossAxisAlignment.stretch,
                 children: [
                   const Text(
                     'Direct save is not supported on this platform/build. Copy the JSON below and paste it into maps.json manually, or import it later string.',
                     style: TextStyle(color: Colors.white70, fontSize: 12),
                   ),
                   const SizedBox(height: 16),
                   Container(
                     padding: const EdgeInsets.all(8),
                     color: Colors.black26,
                     height: 150,
                     child: SelectableText(
                       exportMapString,
                       style: const TextStyle(color: Colors.white54, fontSize: 10, fontFamily: 'monospace'),
                     ),
                   ),
                 ],
               ),
             ),
             actions: [
               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CLOSE', style: TextStyle(color: Colors.white54))),
               ElevatedButton(
                 onPressed: () {
                   Clipboard.setData(ClipboardData(text: exportMapString));
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard!')));
                   Navigator.pop(ctx);
                 },
                 child: const Text('COPY'),
               )
             ],
           ),
         );
         return;
      }

      final content = await file.readAsString();
      final List<dynamic> maps = json.decode(content);
      
      final index = maps.indexWhere((m) => m['id'] == _biomeId);
      if (index != -1) {
        maps[index] = exportMap;
      } else {
        maps.add(exportMap);
      }

      const encoder = JsonEncoder.withIndent('    ');
      await file.writeAsString(encoder.convert(maps));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully saved to assets/maps.json!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Update the local cache in BiomeDataManager
      final newConfig = BiomeConfig.fromJson(exportMap, BiomeDataManager.allTiles);
      BiomeDataManager.biomes[_biomeId] = newConfig;
      setState(() {
        _biomeConfig = newConfig;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving to file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _switchBiome(String newName) {
    final String newId = newName.toLowerCase().replaceAll(' ', '_');
    // Try to get existing config, or create a mock one for selection
    final existing = BiomeDataManager.biomes[newId];

    setState(() {
      _biomeId = newId;
      if (existing != null) {
        _biomeConfig = existing;
      } else {
        // Create a default config for biomes that might not be in maps.json yet
        _biomeConfig = BiomeConfig(
          id: newId,
          name: newName,
          defaultTileId: '${newId}_ground',
          tiles: BiomeDataManager.allTiles, // fallback to all
        );
      }

      _refreshTileCategories();

      _selectedTile =
          _biomeConfig.defaultTileId.isNotEmpty &&
              _biomeConfig.tiles.containsKey(_biomeConfig.defaultTileId)
          ? _biomeConfig.defaultTileId
          : (_baseTiles.isNotEmpty ? _baseTiles.first : 'ground');

      // REMOVED _initGrid() to preserve current map state
    });
    _saveToPrefs();
  }

  void _showImportDialog() {
    final TextEditingController importController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Import Map JSON',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Paste map JSON (id, name, defaultTileId, layout, spawnPoint):',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: importController,
              maxLines: 8,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () {
              final jsonStr = importController.text.trim();
              if (jsonStr.isNotEmpty) {
                _handleImport(jsonStr);
              }
              Navigator.pop(ctx);
            },
            child: const Text('IMPORT', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleImport(String jsonStr) {
    try {
      final data = jsonDecode(jsonStr);

      // Update Biome if present
      if (data['name'] != null) {
        final importedName = data['name'] as String;
        // Verify if it's in our allowed list
        if (_biomeIds.contains(importedName)) {
          _switchBiome(importedName);
        } else {
          // Refresh config for custom IDs
          final String newId = data['id'] ?? 'custom';
          _biomeId = newId;
          _biomeConfig = BiomeDataManager.getBiome(_biomeId);
          _refreshTileCategories();
        }
      }

      final layout = data['layout'] as Map<String, dynamic>;
      final baseLines = List<String>.from(layout['base'] ?? []);
      final overlayLines = layout['overlay'] != null
          ? List<String>.from(layout['overlay'])
          : null;
      final walkLines = layout['walkability'] != null
          ? List<String>.from(layout['walkability'])
          : null;

      if (baseLines.isEmpty) return;

      setState(() {
        _rows = baseLines.length;
        _cols = baseLines[0].split(',').length;

        _grid = baseLines
            .map((line) => line.split(',').map((e) => e.trim()).toList())
            .toList();

        if (overlayLines != null && overlayLines.length == _rows) {
          _overlayGrid = overlayLines.map((line) {
            return line.split(',').map((e) {
              final s = e.trim();
              if (s == 'null' || s.isEmpty || s == '.') return <String>[];
              return s
                  .split('|')
                  .map((p) => p.trim())
                  .where((p) => p.isNotEmpty && p != '.')
                  .toList();
            }).toList();
          }).toList();
        } else {
          _overlayGrid = List.generate(
            _rows,
            (_) => List.generate(_cols, (_) => <String>[]),
          );
        }

        if (walkLines != null && walkLines.length == _rows) {
          _isWalkable = walkLines.map((line) {
            return line.split(',').map((e) => e.trim() == '1').toList();
          }).toList();
        } else {
          _isWalkable = List.generate(
            _rows,
            (_) => List.generate(_cols, (_) => true),
          );
        }

        if (data['spawnPoint'] != null) {
          _spawnC = data['spawnPoint']['x'] ?? _cols ~/ 2;
          _spawnR = data['spawnPoint']['y'] ?? _rows ~/ 2;
        }

        if (data['transitions'] != null) {
          _teleporters = (data['transitions'] as List)
              .map((t) => MapTransition.fromJson(t))
              .toList();
        } else {
          _teleporters = [];
        }

        if (data['npcs'] != null) {
          _npcs = (data['npcs'] as List).map((n) => NPCData.fromJson(n)).toList();
        } else {
          _npcs = [];
        }

        _pushUndo();
      });
      _saveToPrefs();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Map imported successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Import failed: Invalid JSON format ($e)'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Resize Map ────────────────────────────────────────────────────
  void _showResizeDialog() {
    int newRows = _rows;
    int newCols = _cols;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Resize Map', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Rows: ', style: TextStyle(color: Colors.white70)),
                Expanded(
                  child: DropdownButton<int>(
                    value: newRows,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white),
                    items: [10, 15, 20, 25, 30, 40, 50, 60, 100, 150]
                        .map(
                          (v) => DropdownMenuItem(value: v, child: Text('$v')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        newRows = v;
                        (ctx as Element).markNeedsBuild();
                      }
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Text('Cols: ', style: TextStyle(color: Colors.white70)),
                Expanded(
                  child: DropdownButton<int>(
                    value: newCols,
                    dropdownColor: const Color(0xFF2A2A2A),
                    style: const TextStyle(color: Colors.white),
                    items: [10, 15, 20, 25, 30, 40, 50, 60, 100, 150]
                        .map(
                          (v) => DropdownMenuItem(value: v, child: Text('$v')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        newCols = v;
                        (ctx as Element).markNeedsBuild();
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _rows = newRows;
                _cols = newCols;
                _initGrid();
              });
              _saveToPrefs();
            },
            child: const Text('APPLY', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MapEditor.premiumBg,
      appBar: AppBar(
        backgroundColor: MapEditor.premiumSurface,
        elevation: 0,
        shape: const Border(
          bottom: BorderSide(color: MapEditor.premiumGoldMuted, width: 0.5),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'MAP EDITOR',
          style: TextStyle(
            // Added const here
            fontFamily: 'PressStart2P',
            fontSize: 10,
            letterSpacing: 2,
            color: MapEditor.premiumGold,
            shadows: [
              Shadow(
                color: MapEditor.premiumGoldGlow,
                blurRadius: 8,
              ), // Added const here
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.undo,
              size: 20,
              color: _undoStack.length > 1
                  ? MapEditor.premiumGold
                  : MapEditor.premiumGold.withValues(alpha: 0.3),
            ),
            tooltip: 'Undo',
            onPressed: _undoStack.length > 1 ? _undo : null,
          ),
          IconButton(
            icon: Icon(
              Icons.redo,
              size: 20,
              color: _redoStack.isNotEmpty
                  ? MapEditor.premiumGold
                  : MapEditor.premiumGold.withValues(alpha: 0.3),
            ),
            tooltip: 'Redo',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          IconButton(
            icon: Icon(
              _showGrid ? Icons.grid_on : Icons.grid_off,
              size: 20,
              color: MapEditor.premiumGold.withValues(alpha: 0.7),
            ),
            tooltip: 'Toggle Grid',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
          IconButton(
            icon: const Icon(Icons.save, size: 20, color: Colors.lightBlueAccent),
            tooltip: 'Save Directly to maps.json',
            onPressed: _saveToFile,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20, color: MapEditor.premiumGold),
            color: MapEditor.premiumSurface,
            onSelected: (value) {
              switch (value) {
                case 'resize':
                  _showResizeDialog();
                  break;
                case 'import':
                  _showImportDialog();
                  break;
                case 'copy':
                  Clipboard.setData(ClipboardData(text: _exportForMapsJson()));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied! Paste into maps.json under layout/spawnPoint keys.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  break;
                case 'reset':
                  _showResetConfirmDialog();
                  break;
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'resize',
                child: ListTile(
                  leading: Icon(Icons.aspect_ratio, color: MapEditor.premiumGold, size: 18),
                  title: Text('Resize Map', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
              const PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_upload, color: Colors.orangeAccent, size: 18),
                  title: Text('Import JSON', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
              const PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  leading: Icon(Icons.copy_all, color: Colors.greenAccent, size: 18),
                  title: Text('Copy Layout', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
              const PopupMenuItem(
                value: 'reset',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep, color: Colors.redAccent, size: 18),
                  title: Text('Reset Map', style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            color: Colors.redAccent.withValues(alpha: 0.7),
            tooltip: 'Exit Editor',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildToolBar(),
          Expanded(
            child: InteractiveViewer(
              transformationController: _transController,
              constrained: false,
              scaleEnabled: true,
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(1000),
              minScale: 0.1,
              maxScale: 3.0,
              child: Listener(
                onPointerDown: (_) => setState(() => _pointerCount++),
                onPointerUp: (_) => setState(() => _pointerCount--),
                onPointerCancel: (_) => setState(() => _pointerCount--),
                child: GestureDetector(
                  onPanStart: (d) {
                    if (_pointerCount == 1) {
                      const cs = 40.0;
                      _handleInteraction(
                        (d.localPosition.dy / cs).floor(),
                        (d.localPosition.dx / cs).floor(),
                        true,
                      );
                    }
                  },
                  onPanUpdate: (d) {
                    if (_pointerCount == 1) {
                      const cs = 40.0;
                      _handleInteraction(
                        (d.localPosition.dy / cs).floor(),
                        (d.localPosition.dx / cs).floor(),
                        false,
                      );
                    }
                  },
                  onPanEnd: (_) => _onInteractionEnd(),
                  onTapDown: (d) {
                    if (_pointerCount == 1) {
                      const cs = 40.0;
                      _handleInteraction(
                        (d.localPosition.dy / cs).floor(),
                        (d.localPosition.dx / cs).floor(),
                        true,
                      );
                    }
                  },
                  onTapUp: (_) => _onInteractionEnd(),
                  onLongPressStart: (d) {
                    if (_pointerCount == 1) {
                      const cs = 40.0;
                      _handleInteraction(
                        (d.localPosition.dy / cs).floor(),
                        (d.localPosition.dx / cs).floor(),
                        true,
                      );
                    }
                  },
                  child: MouseRegion(
                    onHover: (d) {
                      const cs = 40.0;
                      final r = (d.localPosition.dy / cs).floor();
                      final c = (d.localPosition.dx / cs).floor();
                      if (r >= 0 && r < _rows && c >= 0 && c < _cols) {
                        setState(() => _hoverInfo = '($r, $c)');
                      }
                    },
                    child: CustomPaint(
                      size: Size(_cols * 40.0, _rows * 40.0),
                      painter: _EditorGridPainter(
                        grid: _grid,
                        overlayGrid: _overlayGrid,
                        isWalkable: _isWalkable,
                        mode: _mode,
                        showGrid: _showGrid,
                        spawnR: _spawnR,
                        spawnC: _spawnC,
                        teleporters: _teleporters,
                        npcs: _npcs,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_mode == EditorMode.draw ||
              _mode == EditorMode.bucket ||
              _mode == EditorMode.eraser)
            _buildPalette(),
        ],
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────────
  Widget _buildToolBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: MapEditor.premiumSurface,
        border: Border(
          bottom: BorderSide(
            color: MapEditor.premiumGold.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            // Biome Selection
            DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _biomeConfig.name,
                dropdownColor: MapEditor.premiumSurface,
                iconEnabledColor: MapEditor.premiumGold,
                style: const TextStyle(
                  color: MapEditor.premiumGold,
                  fontSize: 10,
                  fontFamily: 'PressStart2P',
                ),
                items: (_biomeIds.contains(_biomeConfig.name)
                        ? _biomeIds
                        : [..._biomeIds, _biomeConfig.name])
                    .map(
                      (b) => DropdownMenuItem(
                        value: b,
                        child: Text(
                          b.toUpperCase(),
                          style: const TextStyle(letterSpacing: 1),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) _switchBiome(v);
                },
              ),
            ),
            VerticalDivider(
              width: 32,
              color: MapEditor.premiumGold.withValues(alpha: 0.2),
              indent: 12,
              endIndent: 12,
            ),
            const SizedBox(width: 8),
            _toolBtn(EditorMode.pan, Icons.open_with, 'PAN'),
            const SizedBox(width: 8),
            _toolBtn(EditorMode.draw, Icons.edit, 'DRAW'),
            const SizedBox(width: 8),
            _toolBtn(EditorMode.eraser, Icons.auto_fix_high, 'ERASE'),
            const SizedBox(width: 8),
            _toolBtn(EditorMode.bucket, Icons.format_color_fill, 'FILL'),
            const SizedBox(width: 8),
            _toolBtn(EditorMode.eyedropper, Icons.colorize, 'PICK'),
            const SizedBox(width: 8),
            _toolBtn(EditorMode.walkability, Icons.directions_walk, 'WALK'),
            const SizedBox(width: 8),
            _toolBtn(EditorMode.spawnPoint, Icons.flag, 'SPAWN'),
            const SizedBox(width: 8),
            _toolBtn(EditorMode.teleporter, Icons.meeting_room, 'DOOR'),
            const SizedBox(width: 8),
            _toolBtn(EditorMode.npc, Icons.person, 'NPC'),
            const SizedBox(width: 8),
            _toolBtn(EditorMode.move, Icons.open_with, 'MOVE'),
            const SizedBox(width: 16),
            // Auto-base toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: MapEditor.premiumGold.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: MapEditor.premiumGold.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'AUTO-B',
                    style: TextStyle(
                      color: MapEditor.premiumGold,
                      fontSize: 9,
                      fontFamily: 'PressStart2P',
                    ),
                  ),
                  const SizedBox(width: 4),
                  Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: _autoBase,
                      onChanged: (v) => setState(() => _autoBase = v),
                      activeThumbColor: MapEditor.premiumGold,
                      activeTrackColor: MapEditor.premiumGold.withValues(alpha: 0.3),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.white10,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Coordinate display
            if (_hoverInfo.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _hoverInfo,
                  style: const TextStyle(
                    color: Colors.cyanAccent,
                    fontSize: 10,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _toolBtn(EditorMode mode, IconData icon, String label) {
    final isSelected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? MapEditor.premiumGold.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? MapEditor.premiumGold.withValues(alpha: 0.4)
                : Colors.transparent,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? MapEditor.premiumGold : Colors.white54,
              size: 18,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? MapEditor.premiumGold : Colors.white38,
                fontSize: 7,
                fontFamily: 'PressStart2P',
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tile Palette ──────────────────────────────────────────────────
  Map<String, List<String>> _getTilesByBiome() {
    final Map<String, List<String>> grouped = {};

    // Sort all tiles into biome buckets
    for (final tile in BiomeDataManager.allTiles.values) {
      if (!tile.showInEditor) continue;

      // Support comma-separated biomes (e.g. "Tundra, Mountain")
      final biomes = tile.biome
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty);

      for (final b in biomes) {
        grouped.putIfAbsent(b, () => []).add(tile.id);
      }
    }

    // Sort biomes alphabetically, but put 'any' (Universal) and current biome at top
    final sortedGrouped = <String, List<String>>{};

    // 1. Current Biome
    if (grouped.containsKey(_biomeId)) {
      sortedGrouped['CURRENT BIOME (${_biomeConfig.name})'] = grouped.remove(
        _biomeId,
      )!;
    }

    // 2. Universal
    if (grouped.containsKey('any')) {
      sortedGrouped['UNIVERSAL'] = grouped.remove('any')!;
    }

    // 3. The rest alphabetically
    final otherBiomes = grouped.keys.toList()..sort();
    for (final b in otherBiomes) {
      final label = b
          .split('_')
          .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : s)
          .join(' ');
      sortedGrouped[label] = grouped[b]!..sort();
    }

    return sortedGrouped;
  }

  void _cyclePaletteState() {
    setState(() {
      _paletteState = _paletteState == PaletteState.compact ? PaletteState.full : PaletteState.compact;
    });
    // Auto-scroll to selected tile when changing state
    Future.delayed(const Duration(milliseconds: 300), _scrollToSelectedTile);
  }

  void _scrollToSelectedTile() {
    if (!_paletteScrollController.hasClients) return;

    if (_selectedTileKey.currentContext != null) {
      Scrollable.ensureVisible(
        _selectedTileKey.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.5,
      );
    } else if (_paletteState == PaletteState.compact) {
      // Fallback for compact mode if context is null
      final allTiles = [..._getFilteredTiles(_baseTiles), ..._getFilteredTiles(_overlayTiles)];
      final index = allTiles.indexOf(_selectedTile);
      if (index != -1) {
        const double itemWidth = 48.0;
        _paletteScrollController.animateTo(
          (index * itemWidth),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  Widget _buildPalette() {
    final double height = (_paletteState == PaletteState.compact) ? 120 : 421;

    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      height: height + (height > 0 ? bottomPadding : 0),
      decoration: const BoxDecoration(
        color: MapEditor.premiumBg,
        border: Border(
          top: BorderSide(color: MapEditor.premiumGoldMuted, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
        children: [
          // Handle
          GestureDetector(
            onTap: _cyclePaletteState,
            child: Container(
              width: double.infinity,
              height: 28,
              color: MapEditor.premiumSurface,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _paletteState == PaletteState.compact
                        ? Icons.keyboard_double_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: MapEditor.premiumGold.withValues(alpha: 0.5),
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'TILES — ${_biomeConfig.name.toUpperCase()} (${_paletteState.name.toUpperCase()})',
                    style: const TextStyle(
                      color: MapEditor.premiumGold,
                      fontSize: 8,
                      fontFamily: 'PressStart2P',
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (true) ...[
            if (_paletteState == PaletteState.full)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Search all tiles...',
                      hintStyle: TextStyle(
                        color: MapEditor.premiumGold.withValues(alpha: 0.3),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: MapEditor.premiumGold.withValues(alpha: 0.3),
                        size: 16,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              color: MapEditor.premiumGold.withValues(alpha: 0.5),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: MapEditor.premiumGold.withValues(alpha: 0.05),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: MapEditor.premiumGold.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: MapEditor.premiumGoldMuted,
                        ),
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val.toLowerCase();
                      });
                    },
                  ),
                ),
              ),
            Expanded(
              child: _paletteState == PaletteState.compact
                  ? ListView(
                      controller: _paletteScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      children:
                          [
                                ..._getFilteredTiles(_baseTiles),
                                ..._getFilteredTiles(_overlayTiles),
                              ]
                              .map(
                                (tileId) =>
                                    _buildTileChip(tileId, compact: true),
                              )
                              .toList(),
                    )
                  : ListView(
                      controller: _paletteScrollController,
                      padding: const EdgeInsets.all(16),
                      physics: const BouncingScrollPhysics(),
                      children: _getTilesByBiome().entries.map((entry) {
                        final filtered = _getFilteredTiles(entry.value);
                        if (filtered.isEmpty) return const SizedBox.shrink();
                        return _buildTileSection(entry.key, filtered);
                      }).toList(),
                    ),
            ),
          ],
        ],
      ),
    ),
  );
}

  List<String> _getFilteredTiles(List<String> tiles) {
    if (_searchQuery.isEmpty) return tiles;
    return tiles.where((tileId) {
      final def = BiomeDataManager.allTiles[tileId];
      if (def == null) return false;
      return def.name.toLowerCase().contains(_searchQuery) ||
          def.id.toLowerCase().contains(_searchQuery) ||
          def.category.name.toLowerCase().contains(_searchQuery) ||
          def.biome.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _paletteScrollController.dispose();
    super.dispose();
  }

  Widget _buildTileSection(String label, List<String> tiles) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: MapEditor.premiumSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MapEditor.premiumGold.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center, // Center the header
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: MapEditor.premiumGoldMuted,
              fontSize: 9,
              fontFamily: 'PressStart2P',
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center, // CENTER THE TILES
            spacing: 12,
            runSpacing: 12,
            children: tiles.map((tileId) => _buildTileChip(tileId)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTileChip(String tileId, {bool compact = false}) {
    final isSelected = _selectedTile == tileId;
    final def = BiomeDataManager.allTiles[tileId];
    final assets = BiomeDataManager.tileAssets[tileId];
    final previewImg = assets?['center'] ?? assets?.values.firstOrNull;
    final isOverlay = def?.layer == 'overlay';

    return GestureDetector(
      key: isSelected ? _selectedTileKey : null,
      onTap: () {
        setState(() => _selectedTile = tileId);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: compact ? 44 : 72,
        height: compact ? 44 : null,
        padding: EdgeInsets.all(compact ? 4 : 6),
        margin: compact ? const EdgeInsets.only(right: 4) : null,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : Colors.white10,
            width: isSelected ? 2 : 0.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: compact ? 28 : 36,
              height: compact ? 28 : 36,
              child: previewImg != null
                  ? RawImage(image: previewImg, fit: BoxFit.contain)
                  : Container(
                      color: Colors.white10,
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 16,
                        color: Colors.white24,
                      ),
                    ),
            ),
            if (!compact) ...[
              const SizedBox(height: 3),
              Text(
                def?.name ?? tileId,
                style: const TextStyle(color: Colors.white60, fontSize: 7),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isOverlay)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: const Text(
                    'OVR',
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Custom Painter — renders the editor grid
// ────────────────────────────────────────────────────────────────────

class _EditorGridPainter extends CustomPainter {
  static const double cellSize = 40.0;
  final List<List<String>> grid;
  final List<List<List<String>>> overlayGrid;
  final List<List<bool>> isWalkable;
  final EditorMode mode;
  final bool showGrid;
  final int spawnR;
  final int spawnC;
  final List<MapTransition> teleporters;
  final List<NPCData> npcs;

  _EditorGridPainter({
    required this.grid,
    required this.overlayGrid,
    required this.isWalkable,
    required this.mode,
    required this.showGrid,
    required this.spawnR,
    required this.spawnC,
    required this.teleporters,
    required this.npcs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rows = grid.length;
    final cols = grid[0].length;

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          c * cellSize,
          r * cellSize,
          cellSize,
          cellSize,
        );

        // 1. Draw Base Layer
        _drawTileAsset(canvas, rect, grid[r][c]);

        // 2. Draw Overlay Layers
        final overlays = overlayGrid[r][c];
        for (final overlayId in overlays) {
          _drawTileAsset(canvas, rect, overlayId);
        }
      }
    }

    // Grid lines - MOVED to the end of the method for proper overlay

    // Overlays (Walkability, Spawn) - should be top-most
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          c * cellSize,
          r * cellSize,
          cellSize,
          cellSize,
        );

        // 3. Walkability overlay
        if (mode == EditorMode.walkability) {
          final isWalk = isWalkable[r][c];
          final paint = Paint()
            ..color = isWalk
                ? Colors.green.withValues(alpha: 0.25)
                : Colors.red.withValues(alpha: 0.4)
            ..style = PaintingStyle.fill;
          canvas.drawRect(rect.deflate(1), paint);

          final icon = isWalk ? Icons.check : Icons.block;
          final textPainter = TextPainter(
            text: TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                fontSize: 14,
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                color: Colors.white70,
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            rect.center - Offset(textPainter.width / 2, textPainter.height / 2),
          );
        }

        // 4. Spawn point marker
        if (r == spawnR && c == spawnC) {
          final spawnPaint = Paint()
            ..color = Colors.cyanAccent.withValues(alpha: 0.4)
            ..style = PaintingStyle.fill;
          canvas.drawRect(rect.deflate(2), spawnPaint);

          final borderPaint = Paint()
            ..color = Colors.cyanAccent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2;
          canvas.drawRect(rect.deflate(2), borderPaint);

          // Draw "S" marker
          final textPainter = TextPainter(
            text: const TextSpan(
              text: 'S',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.cyanAccent,
                fontFamily: 'PressStart2P',
              ),
            ),
            textDirection: TextDirection.ltr,
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            rect.center - Offset(textPainter.width / 2, textPainter.height / 2),
          );
        }

        // 5. Teleporter markers
        for (final t in teleporters) {
          if (r == t.y && c == t.x) {
            final telePaint = Paint()
              ..color = Colors.purpleAccent.withValues(alpha: 0.4)
              ..style = PaintingStyle.fill;
            canvas.drawRect(rect.deflate(2), telePaint);

            final borderPaint = Paint()
              ..color = Colors.purpleAccent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2;
            canvas.drawRect(rect.deflate(2), borderPaint);

            // Draw "T" marker
            final textPainter = TextPainter(
              text: const TextSpan(
                text: 'T',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purpleAccent,
                  fontFamily: 'PressStart2P',
                ),
              ),
              textDirection: TextDirection.ltr,
            );
            textPainter.layout();
            textPainter.paint(
              canvas,
              rect.center - Offset(textPainter.width / 2, textPainter.height / 2),
            );
          }
        }
      }
    }

    // 6. Draw NPCs
    for (final npc in npcs) {
      final rect = Rect.fromLTWH(
        npc.col * cellSize,
        npc.row * cellSize,
        cellSize,
        cellSize,
      );

      final assets = BiomeDataManager.npcAssets[npc.spriteKey];
      if (assets != null && assets['down'] != null && assets['down']!.isNotEmpty) {
        final img = assets['down']![0];
        final double assetW = img.width.toDouble();
        final double assetH = img.height.toDouble();
        
        canvas.drawImageRect(
          img,
          Rect.fromLTWH(0, 0, assetW, assetH),
          rect,
          Paint(),
        );
      } else {
        final paint = Paint()
          ..color = Colors.purpleAccent.withValues(alpha: 0.8)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(rect.center, cellSize * 0.35, paint);
      }

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: npc.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(rect.center.dx - tp.width / 2, rect.bottom - 10));

      // Script Indicator
      if (npc.scriptType != 'none') {
        final sym = npc.scriptType == 'shopkeeper' ? '\$' : '+';
        final symPaint = TextPainter(
          text: TextSpan(
            text: sym,
            style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        );
        symPaint.layout();
        symPaint.paint(canvas, rect.topLeft + const Offset(5, 5));
      }
    }

    // 7. Grid lines - Final overlay
    if (showGrid) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 1.0;
      for (int i = 0; i <= cols; i++) {
        canvas.drawLine(
          Offset(i * cellSize, 0),
          Offset(i * cellSize, rows * cellSize),
          paint,
        );
      }
      for (int i = 0; i <= rows; i++) {
        canvas.drawLine(
          Offset(0, i * cellSize),
          Offset(cols * cellSize, i * cellSize),
          paint,
        );
      }
    }
  }

  void _drawTileAsset(Canvas canvas, Rect rect, String tileId) {
    final assets = BiomeDataManager.tileAssets[tileId];
    if (assets != null && assets.isNotEmpty) {
      final img = assets['center'] ?? assets.values.first;
      final double assetW = img.width.toDouble();
      final double assetH = img.height.toDouble();

      // Proportional scaling for all assets (like tall trees) relative to a 32px base.
      double drawW = cellSize * (assetW / 32.0);
      double drawH = cellSize * (assetH / 32.0);

      final double drawX = rect.center.dx - drawW / 2;
      final double drawY = rect.bottom - drawH;

      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, assetW, assetH),
        Rect.fromLTWH(drawX, drawY, drawW, drawH),
        Paint()..isAntiAlias = true,
      );
    } else {
      // Fallback colors
      final def = BiomeDataManager.allTiles[tileId];
      final isOverlay = def?.layer == 'overlay';
      final paint = Paint()
        ..color = isOverlay
            ? Colors.blue.withValues(alpha: 0.3)
            : Colors.grey.withValues(alpha: 0.4);
      canvas.drawRect(rect, paint); // Removed deflate(3) to eliminate gaps

      // Draw tile ID text
      final textPainter = TextPainter(
        text: TextSpan(
          text: tileId.length > 3 ? tileId.substring(0, 3) : tileId,
          style: const TextStyle(color: Colors.white30, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        rect.center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EditorGridPainter oldDelegate) => true;
}
