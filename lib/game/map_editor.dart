import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
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
}

/// Snapshot for undo/redo
class _EditorSnapshot {
  final List<List<String>> grid;
  final List<List<String?>> overlayGrid;
  final List<List<bool>> isWalkable;
  final int spawnR;
  final int spawnC;

  _EditorSnapshot({
    required this.grid,
    required this.overlayGrid,
    required this.isWalkable,
    required this.spawnR,
    required this.spawnC,
  });

  _EditorSnapshot deepCopy() => _EditorSnapshot(
    grid: grid.map((r) => List<String>.from(r)).toList(),
    overlayGrid: overlayGrid.map((r) => List<String?>.from(r)).toList(),
    isWalkable: isWalkable.map((r) => List<bool>.from(r)).toList(),
    spawnR: spawnR,
    spawnC: spawnC,
  );
}

// ────────────────────────────────────────────────────────────────────
// Map Editor Widget
// ────────────────────────────────────────────────────────────────────

class MapEditor extends StatefulWidget {
  final String biomeId;
  const MapEditor({super.key, this.biomeId = 'swamp'});

  @override
  State<MapEditor> createState() => _MapEditorState();
}

class _MapEditorState extends State<MapEditor> {
  // Grid
  int _rows = 20;
  int _cols = 20;
  late List<List<String>> _grid;
  late List<List<String?>> _overlayGrid;
  late List<List<bool>> _isWalkable;
  int _spawnR = 1;
  int _spawnC = 1;

  // Editor state
  String _selectedTile = 'swamp_ground';
  EditorMode _mode = EditorMode.draw;
  bool _showGrid = true;
  bool _autoBase = true;
  String _hoverInfo = '';
  bool?
  _dragWalkValue; // Store the target walkability for the current drag stroke

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

  // Palette
  bool _isPaletteExpanded = true;

  @override
  void initState() {
    super.initState();
    _biomeId = widget.biomeId;
    _biomeConfig = BiomeDataManager.getBiome(_biomeId);

    // Categorize tiles
    _baseTiles = [];
    _overlayTiles = [];
    for (final entry in _biomeConfig.tiles.entries) {
      if (!entry.value.showInEditor) continue;
      if (entry.value.layer == 'overlay') {
        _overlayTiles.add(entry.key);
      } else {
        _baseTiles.add(entry.key);
      }
    }

    // Determine the border tile (removed field, using 'border' literally)

    _selectedTile = _biomeConfig.defaultTileId.isNotEmpty
        ? _biomeConfig.defaultTileId
        : (_baseTiles.isNotEmpty ? _baseTiles.first : 'swamp_ground');

    _initGrid();
    _loadFromPrefs();
  }

  void _initGrid() {
    final defaultBase = _baseTiles.isNotEmpty
        ? _baseTiles.first
        : 'swamp_ground';
    _grid = List.generate(
      _rows,
      (_) => List.generate(_cols, (_) => defaultBase),
    );
    _overlayGrid = List.generate(
      _rows,
      (_) => List.generate(_cols, (_) => null),
    );
    _isWalkable = List.generate(
      _rows,
      (_) => List.generate(_cols, (_) => true),
    );
    _spawnR = (_rows / 2).floor();
    _spawnC = (_cols / 2).floor();
    _applyBorder();
    _pushUndo();
  }

  void _applyBorder() {
    // Fill outermost ring with border tile on BOTH layers
    for (int c = 0; c < _cols; c++) {
      // Top row
      _grid[0][c] = _biomeConfig.defaultTileId;
      _overlayGrid[0][c] = 'border';
      _isWalkable[0][c] = false;
      // Bottom row
      _grid[_rows - 1][c] = _biomeConfig.defaultTileId;
      _overlayGrid[_rows - 1][c] = 'border';
      _isWalkable[_rows - 1][c] = false;
    }
    for (int r = 0; r < _rows; r++) {
      // Left col
      _grid[r][0] = _biomeConfig.defaultTileId;
      _overlayGrid[r][0] = 'border';
      _isWalkable[r][0] = false;
      // Right col
      _grid[r][_cols - 1] = _biomeConfig.defaultTileId;
      _overlayGrid[r][_cols - 1] = 'border';
      _isWalkable[r][_cols - 1] = false;
    }
  }

  bool _isBorderCell(int r, int c) {
    return r == 0 || r == _rows - 1 || c == 0 || c == _cols - 1;
  }

  void _resetMap() {
    setState(() {
      final defaultBase = _baseTiles.isNotEmpty
          ? _baseTiles.first
          : 'swamp_ground';
      _grid = List.generate(
        _rows,
        (_) => List.generate(_cols, (_) => defaultBase),
      );
      _overlayGrid = List.generate(
        _rows,
        (_) => List.generate(_cols, (_) => null),
      );
      _isWalkable = List.generate(
        _rows,
        (_) => List.generate(_cols, (_) => true),
      );
      _spawnR = (_rows / 2).floor();
      _spawnC = (_cols / 2).floor();
      _applyBorder();
      _undoStack.clear();
      _redoStack.clear();
      _pushUndo();
    });
    _saveToPrefs();
  }

  // ── Undo/Redo ─────────────────────────────────────────────────────
  void _pushUndo() {
    _undoStack.add(
      _EditorSnapshot(
        grid: _grid.map((r) => List<String>.from(r)).toList(),
        overlayGrid: _overlayGrid.map((r) => List<String?>.from(r)).toList(),
        isWalkable: _isWalkable.map((r) => List<bool>.from(r)).toList(),
        spawnR: _spawnR,
        spawnC: _spawnC,
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
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final String? savedBiome = prefs.getString('map_editor_biome_v3');
    if (savedBiome != null && savedBiome != _biomeId)
      return; // Different biome, don't load

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

    setState(() {
      if (baseData != null) {
        final List<dynamic> decoded = jsonDecode(baseData);
        _grid = decoded.map((row) => List<String>.from(row)).toList();
        _rows = _grid.length;
        _cols = _grid.isNotEmpty ? _grid[0].length : 20;
      }
      if (overlayData != null) {
        final List<dynamic> decoded = jsonDecode(overlayData);
        _overlayGrid = decoded
            .map((row) => List<String?>.from(row.map((e) => e as String?)))
            .toList();
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
        _overlayGrid[r][c] = _selectedTile;
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
        _overlayGrid[r][c] ?? _grid[r][c],
      );
    });
  }

  void _eraseTile(int r, int c) {
    if (r < 0 || r >= _rows || c < 0 || c >= _cols) return;
    if (_isBorderCell(r, c)) return;
    setState(() {
      // Erase overlay first; if no overlay, reset base
      if (_overlayGrid[r][c] != null) {
        _overlayGrid[r][c] = null;
      } else {
        _grid[r][c] = _baseTiles.isNotEmpty ? _baseTiles.first : 'swamp_ground';
      }
      _isWalkable[r][c] = _getDefaultWalkability(_grid[r][c]);
    });
  }

  void _handleBucket(int r, int c) {
    if (r < 0 || r >= _rows || c < 0 || c >= _cols) return;
    if (_isBorderCell(r, c)) return;

    final def = BiomeDataManager.allTiles[_selectedTile];
    if (def == null) return;

    final isOverlay = def.layer == 'overlay';
    final targetTile = isOverlay ? _overlayGrid[r][c] : _grid[r][c];
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

    final current = isOverlay ? _overlayGrid[r][c] : _grid[r][c];
    if (current != target) return;

    if (isOverlay) {
      _overlayGrid[r][c] = replacement;
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
      // Pick overlay first, then base
      final picked = _overlayGrid[r][c] ?? _grid[r][c];
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
      default:
        break;
    }
  }

  void _onInteractionEnd() {
    // Push undo after completing a paint stroke
    if (_mode != EditorMode.pan && _mode != EditorMode.eyedropper) {
      _pushUndo();
      _saveToPrefs();
    }
    _dragWalkValue = null; // Reset drag state
  }

  // ── Export: maps.json-compatible format ─────────────────────────
  String _exportForMapsJson() {
    final Map<String, dynamic> exportData = {
      "layout": {
        "base": _grid.map((row) => row.join(',')).toList(),
        "overlay": _overlayGrid
            .map((row) => row.map((e) => e ?? 'null').join(','))
            .toList(),
        "walkability": _isWalkable
            .map((row) => row.map((w) => w ? '1' : '0').join(','))
            .toList(),
      },
      "spawnPoint": {"x": _spawnC, "y": _spawnR},
    };
    const encoder = JsonEncoder.withIndent('    ');
    return encoder.convert(exportData);
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
                    items: [10, 15, 20, 25, 30, 40, 50, 60]
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
                    items: [10, 15, 20, 25, 30, 40, 50, 60]
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
      backgroundColor: const Color(0xFF0D0D0D),
      appBar: AppBar(
        title: Text(
          'MAP EDITOR — ${_biomeConfig.name.toUpperCase()}',
          style: const TextStyle(
            fontFamily: 'PressStart2P',
            fontSize: 9,
            letterSpacing: 1,
          ),
        ),
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 4,
        actions: [
          // Undo
          IconButton(
            icon: Icon(
              Icons.undo,
              size: 20,
              color: _undoStack.length > 1 ? Colors.white : Colors.white24,
            ),
            tooltip: 'Undo',
            onPressed: _undoStack.length > 1 ? _undo : null,
          ),
          // Redo
          IconButton(
            icon: Icon(
              Icons.redo,
              size: 20,
              color: _redoStack.isNotEmpty ? Colors.white : Colors.white24,
            ),
            tooltip: 'Redo',
            onPressed: _redoStack.isNotEmpty ? _redo : null,
          ),
          const VerticalDivider(width: 1, color: Colors.white12),
          // Grid toggle
          IconButton(
            icon: Icon(
              _showGrid ? Icons.grid_on : Icons.grid_off,
              size: 20,
              color: Colors.white70,
            ),
            tooltip: 'Toggle Grid',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
          // Resize
          IconButton(
            icon: const Icon(
              Icons.aspect_ratio,
              size: 20,
              color: Colors.white70,
            ),
            tooltip: 'Resize Map ($_rows×$_cols)',
            onPressed: _showResizeDialog,
          ),
          const VerticalDivider(width: 1, color: Colors.white12),
          // Export
          IconButton(
            icon: const Icon(
              Icons.copy_all,
              size: 20,
              color: Colors.greenAccent,
            ),
            tooltip: 'Copy maps.json Layout',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _exportForMapsJson()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Copied! Paste into maps.json under a biome\'s layout/spawnPoint keys.',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
          ),
          // Reset
          IconButton(
            icon: const Icon(
              Icons.delete_sweep,
              color: Colors.redAccent,
              size: 20,
            ),
            tooltip: 'Reset Map',
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: const Text(
                    'Reset Map?',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'This will clear everything.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text(
                        'CANCEL',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _resetMap();
                        Navigator.pop(ctx);
                      },
                      child: const Text(
                        'RESET',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
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
              scaleEnabled: _mode == EditorMode.pan,
              panEnabled: _mode == EditorMode.pan,
              boundaryMargin: const EdgeInsets.all(1000),
              minScale: 0.1,
              maxScale: 3.0,
              child: AbsorbPointer(
                absorbing: _mode == EditorMode.pan,
                child: GestureDetector(
                  onPanStart: (d) {
                    const cs = 40.0;
                    _handleInteraction(
                      (d.localPosition.dy / cs).floor(),
                      (d.localPosition.dx / cs).floor(),
                      true,
                    );
                  },
                  onPanUpdate: (d) {
                    const cs = 40.0;
                    _handleInteraction(
                      (d.localPosition.dy / cs).floor(),
                      (d.localPosition.dx / cs).floor(),
                      false,
                    );
                  },
                  onPanEnd: (_) => _onInteractionEnd(),
                  onTapDown: (d) {
                    const cs = 40.0;
                    _handleInteraction(
                      (d.localPosition.dy / cs).floor(),
                      (d.localPosition.dx / cs).floor(),
                      true,
                    );
                  },
                  onTapUp: (_) => _onInteractionEnd(),
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
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A2E),
        border: Border(bottom: BorderSide(color: Colors.white10)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            _toolBtn(EditorMode.pan, Icons.open_with, 'PAN'),
            _toolBtn(EditorMode.draw, Icons.edit, 'DRAW'),
            _toolBtn(EditorMode.eraser, Icons.auto_fix_high, 'ERASE'),
            _toolBtn(EditorMode.bucket, Icons.format_color_fill, 'FILL'),
            _toolBtn(EditorMode.eyedropper, Icons.colorize, 'PICK'),
            _toolBtn(EditorMode.walkability, Icons.directions_walk, 'WALK'),
            _toolBtn(EditorMode.spawnPoint, Icons.person_pin_circle, 'SPAWN'),
            const SizedBox(width: 12),
            // Auto-base toggle
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Text(
                    'AUTO-B',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Transform.scale(
                    scale: 0.6,
                    child: Switch(
                      value: _autoBase,
                      onChanged: (v) => setState(() => _autoBase = v),
                      activeColor: Colors.cyanAccent,
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
                  color: Colors.white.withOpacity(0.05),
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
    final active = _mode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? Colors.cyanAccent.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? Colors.cyanAccent : Colors.white12,
              width: active ? 1.5 : 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: active ? Colors.cyanAccent : Colors.white38,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: active ? Colors.cyanAccent : Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Tile Palette ──────────────────────────────────────────────────
  Widget _buildPalette() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: _isPaletteExpanded ? 220 : 56,
      decoration: const BoxDecoration(
        color: Color(0xFF16213E),
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Column(
        children: [
          // Handle
          GestureDetector(
            onTap: () =>
                setState(() => _isPaletteExpanded = !_isPaletteExpanded),
            child: Container(
              width: double.infinity,
              height: 28,
              color: const Color(0xFF0F3460),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isPaletteExpanded
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    color: Colors.white38,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'TILES — ${_biomeConfig.name.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_isPaletteExpanded)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  _buildTileSection('BASE LAYER', _baseTiles),
                  const SizedBox(height: 12),
                  _buildTileSection('OVERLAY LAYER', _overlayTiles),
                ],
              ),
            )
          else
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                children: [..._baseTiles, ..._overlayTiles].map((tileId) {
                  return _buildTileChip(tileId, compact: true);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTileSection(String label, List<String> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.cyanAccent,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tiles.map((tileId) => _buildTileChip(tileId)).toList(),
        ),
      ],
    );
  }

  Widget _buildTileChip(String tileId, {bool compact = false}) {
    final isSelected = _selectedTile == tileId;
    final def = BiomeDataManager.allTiles[tileId];
    final assets = BiomeDataManager.tileAssets[tileId];
    final previewImg = assets?['center'] ?? assets?.values.firstOrNull;
    final isOverlay = def?.layer == 'overlay';

    return GestureDetector(
      onTap: () => setState(() => _selectedTile = tileId),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: compact ? 44 : 72,
        height: compact ? 44 : null,
        padding: EdgeInsets.all(compact ? 4 : 6),
        margin: compact ? const EdgeInsets.only(right: 4) : null,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
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
                    color: Colors.orange.withOpacity(0.2),
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
  final List<List<String?>> overlayGrid;
  final List<List<bool>> isWalkable;
  final EditorMode mode;
  final bool showGrid;
  final int spawnR;
  final int spawnC;

  _EditorGridPainter({
    required this.grid,
    required this.overlayGrid,
    required this.isWalkable,
    required this.mode,
    required this.showGrid,
    required this.spawnR,
    required this.spawnC,
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

        // 2. Draw Overlay Layer
        final overlayId = overlayGrid[r][c];
        if (overlayId != null) {
          _drawTileAsset(canvas, rect, overlayId);
        }
      }
    }

    // Grid lines - MOVED HERE to show above textures
    if (showGrid) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.2)
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
                ? Colors.green.withOpacity(0.25)
                : Colors.red.withOpacity(0.4)
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
            ..color = Colors.cyanAccent.withOpacity(0.4)
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
      }
    }

    // Grid lines
    if (showGrid) {
      final paint = Paint()
        ..color = Colors.white.withOpacity(0.06)
        ..strokeWidth = 0.5;
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

      // Bottom-anchored rendering with proportional scaling
      final double drawW = cellSize * (assetW / 40.0);
      final double drawH = cellSize * (assetH / 40.0);
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
            ? Colors.blue.withOpacity(0.3)
            : Colors.grey.withOpacity(0.4);
      canvas.drawRect(rect.deflate(3), paint);

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
