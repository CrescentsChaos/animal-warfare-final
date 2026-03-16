import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:animal_warfare/game/biome_map_data.dart';
// ─────────────────────────────────────────────────────────────
// Constants & Enums
// ─────────────────────────────────────────────────────────────

enum DesignerTool { pencil, eraser, fill, eraseFill, eyedropper, line, rect, circle, select, lassoSelect }
enum ShapeFill { outline, filled }
enum CanvasBgMode { darkTransparent, lightTransparent, white }

const Color _bg = Color(0xFF0A0A0F);
const Color _surface = Color(0xFF141420);
const Color _accent = Color(0xFF7C4DFF);
const Color _accentDim = Color(0xFF5E35B1);
const Color _gold = Color(0xFFFFD740);
const Color _border = Color(0xFF2A2A3A);

// ─────────────────────────────────────────────────────────────
// Layer Model
// ─────────────────────────────────────────────────────────────

class AWLayer {
  final String id;
  String name;
  List<List<Color>> pixels;
  bool visible;
  double opacity;

  AWLayer({
    required this.id,
    required this.name,
    required int width,
    required int height,
    this.visible = true,
    this.opacity = 1.0,
    List<List<Color>>? existingPixels,
  }) : pixels = existingPixels ??
            List.generate(height, (_) => List.generate(width, (_) => Colors.transparent));

  Map<String, dynamic> toJson(int w, int h) {
    final pixelData = <String>[];
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final c = pixels[y][x];
        pixelData.add(
            '${(c.a * 255).round().toRadixString(16).padLeft(2, '0')}'
            '${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
            '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
            '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}');
      }
    }
    return {
      'id': id,
      'name': name,
      'visible': visible,
      'opacity': opacity,
      'pixels': pixelData,
    };
  }

  static AWLayer fromJson(Map<String, dynamic> json, int w, int h) {
    final pixelData = (json['pixels'] as List).cast<String>();
    final pixels = List.generate(h, (y) => List.generate(w, (x) {
      final hex = pixelData[y * w + x];
      final value = int.parse(hex, radix: 16);
      return Color(value);
    }));
    return AWLayer(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString() + Random().nextInt(1000).toString(),
      name: json['name'] ?? 'Layer',
      width: w,
      height: h,
      visible: json['visible'] ?? true,
      opacity: (json['opacity'] ?? 1.0).toDouble(),
      existingPixels: pixels,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// AW Studio Widget
// ─────────────────────────────────────────────────────────────

class AWStudio extends StatefulWidget {
  final String? projectId;
  const AWStudio({super.key, this.projectId});

  static Future<List<Map<String, dynamic>>> loadProjectList() async {
    final prefs = await SharedPreferences.getInstance();
    final listJson = prefs.getStringList('aw_studio_projects') ?? [];
    return listJson.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
  }

  static Future<void> deleteProject(String projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('aw_project_$projectId');

    final listJson = prefs.getStringList('aw_studio_projects') ?? [];
    final projects = listJson.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    projects.removeWhere((p) => p['id'] == projectId);
    await prefs.setStringList('aw_studio_projects', projects.map((p) => jsonEncode(p)).toList());
  }

  @override
  State<AWStudio> createState() => _AWStudioState();
}

class _AWStudioState extends State<AWStudio> with TickerProviderStateMixin {
  // Canvas
  int _canvasW = 32;
  int _canvasH = 32;

  // Layers
  List<AWLayer> _layers = [];
  int _activeLayerIndex = 0;
  List<List<Color>> get _pixels => _layers[_activeLayerIndex].pixels;

  // Tool
  DesignerTool _tool = DesignerTool.pencil;
  ShapeFill _shapeFill = ShapeFill.outline;
  Color _primaryColor = Colors.white;
  int _brushSize = 1;

  // Expandable Panel
  bool _isExpanded = false;

  // Shape drawing temps
  Point<int>? _shapeStart;
  List<List<Color>>? _previewPixels;

  // Selection
  Rect? _selectionRect;
  List<Point<int>>? _lassoPath;
  List<List<Color>>? _clipboardPixels;
  bool _isMovingSelection = false;
  List<List<Color>>? _movingPixels;
  Point<int>? _lastMovePixel;

  // Undo/Redo (stores full layer snapshots)
  final List<List<Map<String, dynamic>>> _undoStack = [];
  final List<List<Map<String, dynamic>>> _redoStack = [];
  static const int _maxUndo = 50;

  // Color picker
  double _r = 255, _g = 255, _b = 255, _a = 255;
  List<Color> _recentColors = [];
  final TextEditingController _hexController = TextEditingController();

  // Grid / Zoom
  bool _showGrid = true;
  CanvasBgMode _bgMode = CanvasBgMode.darkTransparent;
  final TransformationController _zoomController = TransformationController();
  int _pointerCount = 0;

  // Tabs
  late TabController _tabController;

  // Project
  String _projectId = '';
  String _projectName = 'Untitled';
  bool _isDirty = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _hexController.text = 'FFFFFF';
    if (widget.projectId != null) {
      _projectId = widget.projectId!;
      _loadProject(_projectId);
    } else {
      _projectId = DateTime.now().millisecondsSinceEpoch.toString();
      _initFreshCanvas();
    }
    _loadRecentColors();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _zoomController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  void _initFreshCanvas() {
    _layers = [AWLayer(id: 'layer_1', name: 'Layer 1', width: _canvasW, height: _canvasH)];
    _activeLayerIndex = 0;
    _undoStack.clear();
    _redoStack.clear();
  }

  // ── Persistence ─────────────────────────────────────────────

  Future<void> _loadRecentColors() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('aw_studio_recent_colors') ?? [];
    setState(() {
      _recentColors = list.map((h) => Color(int.parse(h, radix: 16))).toList();
    });
  }

  Future<void> _saveRecentColors() async {
    final prefs = await SharedPreferences.getInstance();
    final list = _recentColors.take(10).map((c) {
      return '${(c.a * 255).round().toRadixString(16).padLeft(2, '0')}'
          '${(c.r * 255).round().toRadixString(16).padLeft(2, '0')}'
          '${(c.g * 255).round().toRadixString(16).padLeft(2, '0')}'
          '${(c.b * 255).round().toRadixString(16).padLeft(2, '0')}';
    }).toList();
    await prefs.setStringList('aw_studio_recent_colors', list);
  }

  Future<void> _autoSave() async {
    if (!_isDirty) return;
    await _saveProject();
  }

  Future<void> _saveProject() async {
    final prefs = await SharedPreferences.getInstance();
    final projectData = {
      'id': _projectId,
      'name': _projectName,
      'canvasW': _canvasW,
      'canvasH': _canvasH,
      'activeLayer': _activeLayerIndex,
      'layers': _layers.map((l) => l.toJson(_canvasW, _canvasH)).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    await prefs.setString('aw_project_$_projectId', jsonEncode(projectData));

    // Update project list
    final listJson = prefs.getStringList('aw_studio_projects') ?? [];
    final projects = listJson.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
    projects.removeWhere((p) => p['id'] == _projectId);
    projects.insert(0, {
      'id': _projectId,
      'name': _projectName,
      'canvasW': _canvasW,
      'canvasH': _canvasH,
      'layerCount': _layers.length,
      'timestamp': DateTime.now().toIso8601String(),
    });
    if (projects.length > 20) projects.removeLast();
    await prefs.setStringList(
        'aw_studio_projects', projects.map((p) => jsonEncode(p)).toList());
    _isDirty = false;

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Project "$_projectName" saved'),
          backgroundColor: Colors.green.shade800,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _loadProject(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('aw_project_$id');
    if (raw == null) {
      _initFreshCanvas();
      return;
    }
    final data = jsonDecode(raw) as Map<String, dynamic>;
    setState(() {
      _canvasW = data['canvasW'] ?? 32;
      _canvasH = data['canvasH'] ?? 32;
      _projectName = data['name'] ?? 'Untitled';
      _activeLayerIndex = data['activeLayer'] ?? 0;
      _layers = (data['layers'] as List)
          .map((l) => AWLayer.fromJson(l as Map<String, dynamic>, _canvasW, _canvasH))
          .toList();
      if (_layers.isEmpty) {
        _layers = [AWLayer(id: 'layer_1', name: 'Layer 1', width: _canvasW, height: _canvasH)];
      }
      if (_activeLayerIndex >= _layers.length) _activeLayerIndex = 0;
      _undoStack.clear();
      _redoStack.clear();
      _pushUndo();
    });
  }
  // -- Undo / Redo (Layer Snapshots) ---------------------------

  List<Map<String, dynamic>> _snapshotLayers() {
    return _layers.map((l) => l.toJson(_canvasW, _canvasH)).toList();
  }

  void _restoreSnapshot(List<Map<String, dynamic>> snapshot) {
    _layers = snapshot.map((s) => AWLayer.fromJson(s, _canvasW, _canvasH)).toList();
    if (_activeLayerIndex >= _layers.length) _activeLayerIndex = _layers.length - 1;
  }

  void _pushUndo() {
    _undoStack.add(_snapshotLayers());
    if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
    _redoStack.clear();
    _isDirty = true;
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    final currentState = _snapshotLayers();
    _redoStack.add(currentState);
    final previousState = _undoStack.removeLast();
    setState(() {
      _restoreSnapshot(previousState);
      _isDirty = true;
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    final currentState = _snapshotLayers();
    _undoStack.add(currentState);
    final nextState = _redoStack.removeLast();
    setState(() {
      _restoreSnapshot(nextState);
      _isDirty = true;
    });
  }

  List<List<Color>> _copyPixels([List<List<Color>>? source]) {
    final src = source ?? _pixels;
    return src.map((row) => List<Color>.from(row)).toList();
  }

  // -- Drawing ----------------------------------------------

  void _setPixel(int x, int y, Color color, {List<List<Color>>? target}) {
    final t = target ?? _pixels;
    if (x < 0 || x >= _canvasW || y < 0 || y >= _canvasH) return;
    t[y][x] = color;
  }

  void _drawBrush(int x, int y, Color color, {List<List<Color>>? target}) {
    if (_brushSize <= 1) {
      _setPixel(x, y, color, target: target);
    } else {
      final half = _brushSize ~/ 2;
      for (int dy = -half; dy < _brushSize - half; dy++) {
        for (int dx = -half; dx < _brushSize - half; dx++) {
          _setPixel(x + dx, y + dy, color, target: target);
        }
      }
    }
  }

  void _floodFill(int x, int y, Color newColor) {
    if (x < 0 || x >= _canvasW || y < 0 || y >= _canvasH) return;
    final targetColor = _pixels[y][x];
    if (targetColor == newColor) return;
    final stack = <Point<int>>[Point(x, y)];
    while (stack.isNotEmpty) {
      final p = stack.removeLast();
      if (p.x < 0 || p.x >= _canvasW || p.y < 0 || p.y >= _canvasH) continue;
      if (_pixels[p.y][p.x] != targetColor) continue;
      _pixels[p.y][p.x] = newColor;
      stack.add(Point(p.x + 1, p.y));
      stack.add(Point(p.x - 1, p.y));
      stack.add(Point(p.x, p.y + 1));
      stack.add(Point(p.x, p.y - 1));
    }
  }

  List<Point<int>> _bresenhamLine(int x0, int y0, int x1, int y1) {
    final points = <Point<int>>[];
    int dx = (x1 - x0).abs(), dy = (y1 - y0).abs();
    int sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
    int err = dx - dy;
    while (true) {
      points.add(Point(x0, y0));
      if (x0 == x1 && y0 == y1) break;
      int e2 = 2 * err;
      if (e2 > -dy) { err -= dy; x0 += sx; }
      if (e2 < dx) { err += dx; y0 += sy; }
    }
    return points;
  }

  void _drawLine(int x0, int y0, int x1, int y1, Color color, {List<List<Color>>? target}) {
    for (final p in _bresenhamLine(x0, y0, x1, y1)) {
      _drawBrush(p.x, p.y, color, target: target);
    }
  }

  void _drawRect(int x0, int y0, int x1, int y1, Color color, bool filled, {List<List<Color>>? target}) {
    final minX = min(x0, x1), maxX = max(x0, x1);
    final minY = min(y0, y1), maxY = max(y0, y1);
    if (filled) {
      for (int y = minY; y <= maxY; y++) {
        for (int x = minX; x <= maxX; x++) {
          _drawBrush(x, y, color, target: target);
        }
      }
    } else {
      for (int x = minX; x <= maxX; x++) { _drawBrush(x, minY, color, target: target); _drawBrush(x, maxY, color, target: target); }
      for (int y = minY; y <= maxY; y++) { _drawBrush(minX, y, color, target: target); _drawBrush(maxX, y, color, target: target); }
    }
  }

  void _drawCircle(int cx, int cy, int rx, int ry, Color color, bool filled, {List<List<Color>>? target}) {
    if (filled) {
      for (int y = cy - ry; y <= cy + ry; y++) {
        for (int x = cx - rx; x <= cx + rx; x++) {
          final ddx = (x - cx).toDouble() / max(rx, 1);
          final ddy = (y - cy).toDouble() / max(ry, 1);
          if (ddx * ddx + ddy * ddy <= 1.0) _drawBrush(x, y, color, target: target);
        }
      }
    } else {
      const steps = 360;
      for (int i = 0; i < steps; i++) {
        final angle = i * pi * 2 / steps;
        final x = (cx + rx * cos(angle)).round();
        final y = (cy + ry * sin(angle)).round();
        _drawBrush(x, y, color, target: target);
      }
    }
  }

  // -- Touch Handling ---------------------------------------

  Point<int>? _lastDragPixel;

  void _onCanvasTap(Offset local, double cellSize) {
    final x = (local.dx / cellSize).floor();
    final y = (local.dy / cellSize).floor();
    if (x < 0 || x >= _canvasW || y < 0 || y >= _canvasH) return;

    if (_tool != DesignerTool.eraser && _tool != DesignerTool.eyedropper) {
      _addToRecent(_primaryColor);
    }

    switch (_tool) {
      case DesignerTool.pencil:
        _pushUndo(); _drawBrush(x, y, _primaryColor); _lastDragPixel = Point(x, y); break;
      case DesignerTool.eraser:
        _pushUndo(); _drawBrush(x, y, Colors.transparent); _lastDragPixel = Point(x, y); break;
      case DesignerTool.fill:
        _pushUndo(); _floodFill(x, y, _primaryColor); break;
      case DesignerTool.eraseFill:
        _pushUndo(); _floodFill(x, y, Colors.transparent); break;
      case DesignerTool.eyedropper:
        _pickColor(_pixels[y][x]); break;
      case DesignerTool.line:
      case DesignerTool.rect:
      case DesignerTool.circle:
        _shapeStart = Point(x, y); _previewPixels = _copyPixels(); break;
      case DesignerTool.select:
      case DesignerTool.lassoSelect:
        if (_selectionRect != null && _selectionRect!.contains(Offset(x.toDouble(), y.toDouble()))) {
          if (!_isMovingSelection) {
            _isMovingSelection = true;
            _movingPixels = _snapshotRect(_selectionRect!, mask: (_lassoPath != null) ? _lassoPath : null);
            _pushUndo();
            if (_lassoPath != null) {
              _fillTargetMask(_lassoPath!, Colors.transparent);
            } else {
              _fillTargetRect(_selectionRect!, Colors.transparent);
            }
          }
          _lastMovePixel = Point(x, y);
        } else {
          _commitMovingSelection();
          if (_tool == DesignerTool.select) {
            _lassoPath = null;
            _shapeStart = Point(x, y);
            _selectionRect = Rect.fromLTRB(x.toDouble(), y.toDouble(), x.toDouble() + 1, y.toDouble() + 1);
          } else {
            _lassoPath = [Point(x, y)];
            _selectionRect = null;
          }
        }
        break;
    }
    setState(() {});
  }

  void _onCanvasDrag(Offset local, double cellSize) {
    final x = (local.dx / cellSize).floor();
    final y = (local.dy / cellSize).floor();
    if (x < 0 || x >= _canvasW || y < 0 || y >= _canvasH) return;
    if (_tool == DesignerTool.pencil) {
      if (_lastDragPixel != null && (_lastDragPixel!.x != x || _lastDragPixel!.y != y)) {
        _drawLine(_lastDragPixel!.x, _lastDragPixel!.y, x, y, _primaryColor);
      }
      _lastDragPixel = Point(x, y); setState(() {});
    } else if (_tool == DesignerTool.eraser) {
      if (_lastDragPixel != null && (_lastDragPixel!.x != x || _lastDragPixel!.y != y)) {
        _drawLine(_lastDragPixel!.x, _lastDragPixel!.y, x, y, Colors.transparent);
      }
      _lastDragPixel = Point(x, y); setState(() {});
    } else if (_tool == DesignerTool.select || _tool == DesignerTool.lassoSelect) {
      if (_isMovingSelection && _lastMovePixel != null) {
        final dx = x - _lastMovePixel!.x;
        final dy = y - _lastMovePixel!.y;
        if (dx != 0 || dy != 0) {
          _selectionRect = _selectionRect!.shift(Offset(dx.toDouble(), dy.toDouble()));
          _lastMovePixel = Point(x, y);
          setState(() {});
        }
      } else if (_tool == DesignerTool.select && _shapeStart != null) {
        final sx = _shapeStart!.x.toDouble();
        final sy = _shapeStart!.y.toDouble();
        final ex = x.toDouble() + (x >= sx ? 1 : 0);
        final ey = y.toDouble() + (y >= sy ? 1 : 0);
        _selectionRect = Rect.fromLTRB(min(sx, ex), min(sy, ey), max(sx, ex), max(sy, ey));
        _lassoPath = null;
        setState(() {});
      } else if (_tool == DesignerTool.lassoSelect && _lassoPath != null) {
        if (_lassoPath!.isEmpty || _lassoPath!.last != Point(x, y)) {
          _lassoPath!.add(Point(x, y));
          setState(() {});
        }
      }
    } else if (_shapeStart != null && _previewPixels != null) {
      _layers[_activeLayerIndex].pixels = _copyPixels(_previewPixels!).map((r) => List<Color>.from(r)).toList();
      // Reassign reference
      final sx = _shapeStart!.x, sy = _shapeStart!.y;
      switch (_tool) {
        case DesignerTool.line: _drawLine(sx, sy, x, y, _primaryColor); break;
        case DesignerTool.rect: _drawRect(sx, sy, x, y, _primaryColor, _shapeFill == ShapeFill.filled); break;
        case DesignerTool.circle:
          final rrx = (x - sx).abs(); final rry = (y - sy).abs();
          _drawCircle(sx, sy, rrx, rry, _primaryColor, _shapeFill == ShapeFill.filled); break;
        default: break;
      }
      setState(() {});
    } else if (_tool == DesignerTool.lassoSelect && _lassoPath != null) {
      if (_lassoPath!.isEmpty || _lassoPath!.last != Point(x, y)) {
        _lassoPath!.add(Point(x, y));
        setState(() {});
      }
    }
  }



  bool _isPointInPolygon(Point<int> p, List<Point<int>> polygon) {
    if (polygon.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      if (((polygon[i].y > p.y) != (polygon[j].y > p.y)) &&
          (p.x < (polygon[j].x - polygon[i].x) * (p.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x)) {
        inside = !inside;
      }
    }
    return inside;
  }

  void _onCanvasDragEnd() {
    // We no longer commit immediately here. 
    // This allows the selection to stay "floating" (moving) until user clicks away or changes tool.
    
    if (_tool == DesignerTool.lassoSelect && _lassoPath != null && _lassoPath!.length > 2) {
      // Calculate bounding box
      int minX = _lassoPath![0].x, maxX = _lassoPath![0].x;
      int minY = _lassoPath![0].y, maxY = _lassoPath![0].y;
      for (final p in _lassoPath!) {
        minX = min(minX, p.x); maxX = max(maxX, p.x);
        minY = min(minY, p.y); maxY = max(maxY, p.y);
      }
      
      _selectionRect = Rect.fromLTRB(minX.toDouble(), minY.toDouble(), maxX.toDouble() + 1, maxY.toDouble() + 1);
      
      // We don't lift immediately here, we just set the _selectionRect.
      // Copy/Cut/Move will need to know about the lasso path to mask properly.
      // For now, setting the rect allows basic rectangular operations on the bounding box.
      // But we should probably keep the _lassoPath to use as a mask.
    }

    if (_shapeStart != null) {
      if (_tool != DesignerTool.select) {
        _undoStack.add(_snapshotLayers());
        if (_undoStack.length > _maxUndo) _undoStack.removeAt(0);
        _redoStack.clear();
        _isDirty = true;
      }
      _shapeStart = null;
      _previewPixels = null;
    }
    _lastDragPixel = null;
    // _lastMovePixel can be cleared too if not dragging
    if (!_isMovingSelection) _lastMovePixel = null;
    setState(() {});
  }

  // -- Selection Logic --------------------------------------

  void _copySelection() {
    if (_selectionRect == null) return;
    if (_isMovingSelection && _movingPixels != null) {
      _clipboardPixels = _copyPixels(_movingPixels!);
    } else {
      final sx = _selectionRect!.left.toInt().clamp(0, _canvasW);
      final sy = _selectionRect!.top.toInt().clamp(0, _canvasH);
      final ex = _selectionRect!.right.toInt().clamp(0, _canvasW);
      final ey = _selectionRect!.bottom.toInt().clamp(0, _canvasH);
      
      _clipboardPixels = [];
      for (int y = sy; y < ey; y++) {
        final row = <Color>[];
        for (int x = sx; x < ex; x++) {
          if (_tool == DesignerTool.lassoSelect && _lassoPath != null) {
            if (_isPointInPolygon(Point(x, y), _lassoPath!)) {
              row.add(_pixels[y][x]);
            } else {
              row.add(Colors.transparent);
            }
          } else {
            row.add(_pixels[y][x]);
          }
        }
        _clipboardPixels!.add(row);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selection copied'), duration: Duration(milliseconds: 500)));
  }

  void _cutSelection() {
    if (_selectionRect == null) return;
    if (_isMovingSelection && _movingPixels != null) {
       _clipboardPixels = _copyPixels(_movingPixels!);
       _isMovingSelection = false;
       _movingPixels = null;
    } else {
      _copySelection();
      _pushUndo();
      final sx = _selectionRect!.left.toInt().clamp(0, _canvasW);
      final sy = _selectionRect!.top.toInt().clamp(0, _canvasH);
      final ex = _selectionRect!.right.toInt().clamp(0, _canvasW);
      final ey = _selectionRect!.bottom.toInt().clamp(0, _canvasH);
      
      for (int y = sy; y < ey; y++) {
        for (int x = sx; x < ex; x++) {
          if (_tool == DesignerTool.lassoSelect && _lassoPath != null) {
            if (_isPointInPolygon(Point(x, y), _lassoPath!)) {
              _pixels[y][x] = Colors.transparent;
            }
          } else {
            _pixels[y][x] = Colors.transparent;
          }
        }
      }
    }
    setState(() {});
  }

  void _pasteSelection() {
    if (_clipboardPixels == null || _clipboardPixels!.isEmpty) return;
    _commitMovingSelection();
    _pushUndo();
    final startX = _selectionRect?.left.toInt() ?? 0;
    final startY = _selectionRect?.top.toInt() ?? 0;
    
    // Auto-lift into moving state immediately after paste
    _isMovingSelection = true;
    _movingPixels = _copyPixels(_clipboardPixels!);
    
    _selectionRect = Rect.fromLTWH(
      startX.toDouble(),
      startY.toDouble(),
      _movingPixels![0].length.toDouble(),
      _movingPixels!.length.toDouble()
    );
    _tool = DesignerTool.select;
    setState(() {});
  }

  void _commitMovingSelection() {
    if (!_isMovingSelection || _selectionRect == null || _movingPixels == null) return;
    
    final startX = _selectionRect!.left.toInt();
    final startY = _selectionRect!.top.toInt();
    
    for (int cy = 0; cy < _movingPixels!.length; cy++) {
      for (int cx = 0; cx < _movingPixels![cy].length; cx++) {
        final tx = startX + cx;
        final ty = startY + cy;
        if (tx >= 0 && tx < _canvasW && ty >= 0 && ty < _canvasH) {
          _layers[_activeLayerIndex].pixels[ty][tx] = _movingPixels![cy][cx];
        }
      }
    }
    
    _isMovingSelection = false;
    _movingPixels = null;
    _lastMovePixel = null;
    setState(() {});
  }

  List<List<Color>> _snapshotRect(Rect rect, {List<Point<int>>? mask}) {
    final sx = rect.left.toInt().clamp(0, _canvasW);
    final sy = rect.top.toInt().clamp(0, _canvasH);
    final ex = rect.right.toInt().clamp(0, _canvasW);
    final ey = rect.bottom.toInt().clamp(0, _canvasH);
    final w = ex - sx;
    final h = ey - sy;
    if (w <= 0 || h <= 0) return [];
    return List.generate(h, (y) => List.generate(w, (x) {
      final tx = sx + x;
      final ty = sy + y;
      if (mask != null) {
        return _isPointInPolygon(Point(tx, ty), mask) ? _layers[_activeLayerIndex].pixels[ty][tx] : Colors.transparent;
      }
      return _layers[_activeLayerIndex].pixels[ty][tx];
    }));
  }

  void _fillTargetRect(Rect rect, Color color) {
    final sx = rect.left.toInt().clamp(0, _canvasW);
    final sy = rect.top.toInt().clamp(0, _canvasH);
    final ex = rect.right.toInt().clamp(0, _canvasW);
    final ey = rect.bottom.toInt().clamp(0, _canvasH);
    for (int y = sy; y < ey; y++) {
      for (int x = sx; x < ex; x++) {
        _layers[_activeLayerIndex].pixels[y][x] = color;
      }
    }
  }

  void _fillTargetMask(List<Point<int>> mask, Color color) {
    for (int y = 0; y < _canvasH; y++) {
      for (int x = 0; x < _canvasW; x++) {
        if (_isPointInPolygon(Point(x, y), mask)) {
          _layers[_activeLayerIndex].pixels[y][x] = color;
        }
      }
    }
  }
  
  // -- Layer Operations ------------------------------------

  void _mergeLayerDown(int index) {
    if (index <= 0 || index >= _layers.length) return;
    _pushUndo();
    final top = _layers[index];
    final bottom = _layers[index - 1];
    
    for (int y = 0; y < _canvasH; y++) {
      for (int x = 0; x < _canvasW; x++) {
        final topCol = top.pixels[y][x];
        if (topCol.a == 0) continue;
        
        final bottomCol = bottom.pixels[y][x];
        // Simple alpha blending (top over bottom)
        if (topCol.a == 1.0 || bottomCol.a == 0) {
          bottom.pixels[y][x] = topCol;
        } else {
          // Porter-Duff source-over blending
          final outA = topCol.a + bottomCol.a * (1 - topCol.a);
          final outR = (topCol.r * topCol.a + bottomCol.r * bottomCol.a * (1 - topCol.a)) / outA;
          final outG = (topCol.g * topCol.a + bottomCol.g * bottomCol.a * (1 - topCol.a)) / outA;
          final outB = (topCol.b * topCol.a + bottomCol.b * bottomCol.a * (1 - topCol.a)) / outA;
          bottom.pixels[y][x] = Color.from(alpha: outA, red: outR, green: outG, blue: outB);
        }
      }
    }
    
    _layers.removeAt(index);
    if (_activeLayerIndex >= index) _activeLayerIndex--;
    if (_activeLayerIndex < 0) _activeLayerIndex = 0;
    
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Merged ${top.name} into ${bottom.name}'), duration: const Duration(milliseconds: 800)));
  }

  // -- Color Helpers ----------------------------------------

  void _pickColor(Color c) {
    setState(() {
      _primaryColor = c;
      _r = (c.r * 255).roundToDouble();
      _g = (c.g * 255).roundToDouble();
      _b = (c.b * 255).roundToDouble();
      _a = (c.a * 255).roundToDouble();
      _hexController.text = _colorToHex(c);
    });
  }

  void _updateColorFromHex(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return;
    try {
      final value = int.parse(hex, radix: 16);
      final c = Color(value);
      _pickColor(c);
    } catch (_) {}
  }

  void _updateColorFromSliders() {
    setState(() {
      _primaryColor = Color.fromARGB(_a.round(), _r.round(), _g.round(), _b.round());
      _hexController.text = _colorToHex(_primaryColor);
    });
  }

  String _colorToHex(Color c) {
    return [
      (c.a * 255).round(),
      (c.r * 255).round(),
      (c.g * 255).round(),
      (c.b * 255).round(),
    ].map((v) => v.toRadixString(16).padLeft(2, '0')).join().toUpperCase();
  }

  void _addToRecent(Color c) {
    _recentColors.remove(c);
    _recentColors.insert(0, c);
    if (_recentColors.length > 10) _recentColors.removeLast();
    _saveRecentColors();
  }

  // -- Filters ----------------------------------------------

  void _applyFilter(String filter) {
    _pushUndo();
    final px = _pixels;
    switch (filter) {
      case 'grayscale':
        _forEachPixel(px, (x, y, c) {
          if (c.a == 0) return c;
          final gray = (c.r * 0.299 + c.g * 0.587 + c.b * 0.114);
          return Color.fromARGB((c.a * 255).round(), (gray * 255).round(), (gray * 255).round(), (gray * 255).round());
        }); break;
      case 'invert':
        _forEachPixel(px, (x, y, c) {
          if (c.a == 0) return c;
          return Color.fromARGB((c.a * 255).round(), 255 - (c.r * 255).round(), 255 - (c.g * 255).round(), 255 - (c.b * 255).round());
        }); break;
      case 'brightness+':
        _forEachPixel(px, (x, y, c) {
          if (c.a == 0) return c;
          return Color.fromARGB((c.a * 255).round(), min(255, (c.r * 255).round() + 20), min(255, (c.g * 255).round() + 20), min(255, (c.b * 255).round() + 20));
        }); break;
      case 'brightness-':
        _forEachPixel(px, (x, y, c) {
          if (c.a == 0) return c;
          return Color.fromARGB((c.a * 255).round(), max(0, (c.r * 255).round() - 20), max(0, (c.g * 255).round() - 20), max(0, (c.b * 255).round() - 20));
        }); break;
      case 'contrast+':
        _forEachPixel(px, (x, y, c) {
          if (c.a == 0) return c;
          double adj(double v) => ((v - 0.5) * 1.25 + 0.5).clamp(0, 1);
          return Color.from(alpha: c.a, red: adj(c.r), green: adj(c.g), blue: adj(c.b));
        }); break;
      case 'contrast-':
        _forEachPixel(px, (x, y, c) {
          if (c.a == 0) return c;
          double adj(double v) => ((v - 0.5) * 0.8 + 0.5).clamp(0, 1);
          return Color.from(alpha: c.a, red: adj(c.r), green: adj(c.g), blue: adj(c.b));
        }); break;
      case 'blur': {
        final isMov = _isMovingSelection && _movingPixels != null;
        final targetPx = isMov ? _movingPixels! : px;
        int sx = 0, sy = 0, ex = targetPx[0].length, ey = targetPx.length;
        if (!isMov && _selectionRect != null) {
          sx = _selectionRect!.left.toInt().clamp(0, _canvasW);
          sy = _selectionRect!.top.toInt().clamp(0, _canvasH);
          ex = _selectionRect!.right.toInt().clamp(0, _canvasW);
          ey = _selectionRect!.bottom.toInt().clamp(0, _canvasH);
        }
        
        final copy = targetPx.map((r) => List<Color>.from(r)).toList();
        final tw = targetPx[0].length, th = targetPx.length;
        
        for (int y = sy; y < ey; y++) {
          for (int x = sx; x < ex; x++) {
            double rr = 0, gg = 0, bb = 0, aa = 0; int count = 0;
            for (int dy = -1; dy <= 1; dy++) {
              for (int dx = -1; dx <= 1; dx++) {
                final nx = x + dx, ny = y + dy;
                if (nx >= 0 && nx < tw && ny >= 0 && ny < th) {
                  final cc = copy[ny][nx]; rr += cc.r; gg += cc.g; bb += cc.b; aa += cc.a; count++;
                }
              }
            }
            targetPx[y][x] = Color.from(alpha: aa / count, red: rr / count, green: gg / count, blue: bb / count);
          }
        }
        break;
      }
      case 'outline': {
        final isMov = _isMovingSelection && _movingPixels != null;
        final targetPx = isMov ? _movingPixels! : px;
        int sx = 0, sy = 0, ex = targetPx[0].length, ey = targetPx.length;
        if (!isMov && _selectionRect != null) {
          sx = _selectionRect!.left.toInt().clamp(0, _canvasW);
          sy = _selectionRect!.top.toInt().clamp(0, _canvasH);
          ex = _selectionRect!.right.toInt().clamp(0, _canvasW);
          ey = _selectionRect!.bottom.toInt().clamp(0, _canvasH);
        }
        
        final copy = targetPx.map((r) => List<Color>.from(r)).toList();
        final tw = targetPx[0].length, th = targetPx.length;
        
        for (int y = sy; y < ey; y++) {
          for (int x = sx; x < ex; x++) {
            if (copy[y][x].a > 0) continue;
            bool adj = false;
            for (int dy = -1; dy <= 1 && !adj; dy++) {
              for (int dx = -1; dx <= 1 && !adj; dx++) {
                if (dx == 0 && dy == 0) continue;
                final nx = x + dx, ny = y + dy;
                if (nx >= 0 && nx < tw && ny >= 0 && ny < th && copy[ny][nx].a > 0) adj = true;
              }
            }
            if (adj) targetPx[y][x] = _primaryColor;
          }
        }
        break;
      }
      case 'mirror_h':
        if (_isMovingSelection && _movingPixels != null) {
          for (int y = 0; y < _movingPixels!.length; y++) {
            _movingPixels![y] = _movingPixels![y].reversed.toList();
          }
        } else {
          int sx = 0, sy = 0, ex = _canvasW, ey = _canvasH;
          if (_selectionRect != null) {
            sx = _selectionRect!.left.toInt().clamp(0, _canvasW);
            sy = _selectionRect!.top.toInt().clamp(0, _canvasH);
            ex = _selectionRect!.right.toInt().clamp(0, _canvasW);
            ey = _selectionRect!.bottom.toInt().clamp(0, _canvasH);
          }
          for (int y = sy; y < ey; y++) {
            final reversedRow = px[y].sublist(sx, ex).reversed.toList();
            px[y].replaceRange(sx, ex, reversedRow);
          }
        }
        break;
      case 'mirror_v':
        if (_isMovingSelection && _movingPixels != null) {
          _movingPixels = _movingPixels!.reversed.toList();
        } else {
          int sx = 0, sy = 0, ex = _canvasW, ey = _canvasH;
          if (_selectionRect != null) {
            sx = _selectionRect!.left.toInt().clamp(0, _canvasW);
            sy = _selectionRect!.top.toInt().clamp(0, _canvasH);
            ex = _selectionRect!.right.toInt().clamp(0, _canvasW);
            ey = _selectionRect!.bottom.toInt().clamp(0, _canvasH);
          }
          final height = ey - sy;
          for (int y = 0; y < height ~/ 2; y++) {
            final topY = sy + y;
            final bottomY = ey - 1 - y;
            final temp = List<Color>.from(px[topY].sublist(sx, ex));
            px[topY].replaceRange(sx, ex, px[bottomY].sublist(sx, ex));
            px[bottomY].replaceRange(sx, ex, temp);
          }
        }
        break;
      case 'rotate_cw':
        if (_isMovingSelection && _movingPixels != null) {
          final h = _movingPixels!.length, w = _movingPixels![0].length;
          _movingPixels = List.generate(w, (nx) => List.generate(h, (ny) => _movingPixels![h - 1 - ny][nx]));
          _selectionRect = Rect.fromLTWH(_selectionRect!.left, _selectionRect!.top, h.toDouble(), w.toDouble());
        } else if (_selectionRect != null) {
          // Auto-lift and rotate
          _isMovingSelection = true;
          _movingPixels = _snapshotRect(_selectionRect!);
          _fillTargetRect(_selectionRect!, Colors.transparent);
          final h = _movingPixels!.length, w = _movingPixels![0].length;
          _movingPixels = List.generate(w, (nx) => List.generate(h, (ny) => _movingPixels![h - 1 - ny][nx]));
          _selectionRect = Rect.fromLTWH(_selectionRect!.left, _selectionRect!.top, h.toDouble(), w.toDouble());
        } else {
          final np = List.generate(_canvasW, (ny) => List.generate(_canvasH, (nx) => px[_canvasH - 1 - nx][ny]));
          final tmp = _canvasW; _canvasW = _canvasH; _canvasH = tmp;
          _layers[_activeLayerIndex].pixels = np;
        } break;
      case 'rotate_ccw':
        if (_isMovingSelection && _movingPixels != null) {
          final h = _movingPixels!.length, w = _movingPixels![0].length;
          _movingPixels = List.generate(w, (nx) => List.generate(h, (ny) => _movingPixels![ny][w - 1 - nx]));
          _selectionRect = Rect.fromLTWH(_selectionRect!.left, _selectionRect!.top, h.toDouble(), w.toDouble());
        } else if (_selectionRect != null) {
          _isMovingSelection = true;
          _movingPixels = _snapshotRect(_selectionRect!);
          _fillTargetRect(_selectionRect!, Colors.transparent);
          final h = _movingPixels!.length, w = _movingPixels![0].length;
          _movingPixels = List.generate(w, (nx) => List.generate(h, (ny) => _movingPixels![ny][w - 1 - nx]));
          _selectionRect = Rect.fromLTWH(_selectionRect!.left, _selectionRect!.top, h.toDouble(), w.toDouble());
        } else {
          final np = List.generate(_canvasW, (ny) => List.generate(_canvasH, (nx) => px[nx][_canvasW - 1 - ny]));
          final tmp = _canvasW; _canvasW = _canvasH; _canvasH = tmp;
          _layers[_activeLayerIndex].pixels = np;
        } break;
    }
    setState(() {});
  }

  void _forEachPixel(List<List<Color>> px, Color Function(int x, int y, Color c) fn) {
    if (_isMovingSelection && _movingPixels != null) {
      for (int y = 0; y < _movingPixels!.length; y++) {
        for (int x = 0; x < _movingPixels![y].length; x++) {
          _movingPixels![y][x] = fn(x, y, _movingPixels![y][x]);
        }
      }
      return;
    }
    int sx = 0, sy = 0, ex = _canvasW, ey = _canvasH;
    if (_selectionRect != null) {
      sx = _selectionRect!.left.toInt().clamp(0, _canvasW);
      sy = _selectionRect!.top.toInt().clamp(0, _canvasH);
      ex = _selectionRect!.right.toInt().clamp(0, _canvasW);
      ey = _selectionRect!.bottom.toInt().clamp(0, _canvasH);
    }
    for (int y = sy; y < ey; y++) {
      for (int x = sx; x < ex; x++) { px[y][x] = fn(x, y, px[y][x]); }
    }
  }

  // -- Import / Export --------------------------------------

  Future<void> _importImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path == null) return;
    final bytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return;
    final resized = img.copyResize(decoded, width: _canvasW, height: _canvasH, interpolation: img.Interpolation.nearest);
    _pushUndo();
    for (int y = 0; y < _canvasH; y++) {
      for (int x = 0; x < _canvasW; x++) {
        final p = resized.getPixel(x, y);
        _pixels[y][x] = Color.fromARGB(p.a.toInt().clamp(0, 255), p.r.toInt().clamp(0, 255), p.g.toInt().clamp(0, 255), p.b.toInt().clamp(0, 255));
      }
    }
    setState(() { _isDirty = true; });
  }

  void _showImportTileDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      isScrollControlled: true,
      builder: (ctx) => _TileImportSheet(
        onTileSelected: (tile) async {
          Navigator.pop(ctx);
          await _importTilePixels(tile);
        },
      ),
    );
  }

  Future<void> _importTilePixels(TileDefinition tile) async {
    final String path = tile.isAutotiled ? tile.assetPath.replaceAll('{dir}', 'center') : tile.assetPath;
    try {
      final bytes = await rootBundle.load(path);
      final decoded = img.decodeImage(bytes.buffer.asUint8List());
      if (decoded == null) return;

      setState(() {
        _pushUndo();
        _canvasW = decoded.width;
        _canvasH = decoded.height;
        _projectName = '${tile.name} (Edit)';
        _isDirty = true;
        
        _layers = [AWLayer(id: DateTime.now().millisecondsSinceEpoch.toString(), name: 'Imported', width: _canvasW, height: _canvasH, opacity: 1.0, visible: true)];
        _activeLayerIndex = 0;

        for (int y = 0; y < _canvasH; y++) {
          for (int x = 0; x < _canvasW; x++) {
            final p = decoded.getPixel(x, y);
            _pixels[y][x] = Color.fromARGB(p.a.toInt().clamp(0, 255), p.r.toInt().clamp(0, 255), p.g.toInt().clamp(0, 255), p.b.toInt().clamp(0, 255));
          }
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Imported ${tile.name}'), backgroundColor: Colors.green.shade800));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load tile: $e'), backgroundColor: Colors.redAccent));
    }
  }

  Future<void> _exportImage() async {
    // Draw each layer onto a canvas using dart:ui, then encode to PNG
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint();

    for (final layer in _layers) {
      if (!layer.visible || layer.opacity <= 0) continue;
      for (int y = 0; y < _canvasH; y++) {
        for (int x = 0; x < _canvasW; x++) {
          final c = layer.pixels[y][x];
          if (c.a == 0) continue;
          paint.color = c.withValues(alpha: c.a * layer.opacity);
          canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1.0, 1.0), paint);
        }
      }
    }

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(_canvasW, _canvasH);
    final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final pngBytes = byteData.buffer.asUint8List();

    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Tile',
      fileName: 'tile_${_canvasW}x$_canvasH.png',
      type: FileType.image,
      bytes: Uint8List.fromList(pngBytes),
    );
    if (outputPath != null) {
      try {
        final file = File(outputPath);
        await file.writeAsBytes(pngBytes);
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to: $outputPath'), backgroundColor: Colors.green.shade800),
      );
    }
  }
  // -- Canvas Size Dialog -----------------------------------

  void _showCanvasSizeDialog() {
    int newW = _canvasW, newH = _canvasH;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
          title: Text('Canvas Size', style: GoogleFonts.pressStart2p(fontSize: 10, color: _gold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final size in [[16, 16], [32, 32], [48, 48], [64, 64], [96, 96], [128, 128]])
                RadioListTile<String>(
                  title: Text('${size[0]} x ${size[1]}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  value: '${size[0]}x${size[1]}',
                  groupValue: '${newW}x${newH}',
                  activeColor: _accent,
                  onChanged: (v) { setD(() { newW = size[0]; newH = size[1]; }); },
                ),
              const Divider(color: _border),
              Row(children: [
                Expanded(child: TextField(
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'W', labelStyle: TextStyle(color: Colors.white54), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border))),
                  onChanged: (v) { final val = int.tryParse(v); if (val != null && val > 0 && val <= 256) setD(() => newW = val); },
                )),
                const SizedBox(width: 12),
                Expanded(child: TextField(
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(labelText: 'H', labelStyle: TextStyle(color: Colors.white54), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border))),
                  onChanged: (v) { final val = int.tryParse(v); if (val != null && val > 0 && val <= 256) setD(() => newH = val); },
                )),
              ]),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _accent),
              onPressed: () {
                Navigator.pop(ctx);
                setState(() { _canvasW = newW; _canvasH = newH; _initFreshCanvas(); });
              },
              child: const Text('APPLY', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // -- Rename Project Dialog --------------------------------

  void _showRenameDialog() {
    final ctrl = TextEditingController(text: _projectName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _border)),
        title: Text('Project Name', style: GoogleFonts.pressStart2p(fontSize: 10, color: _gold)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border)), focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: _accent))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _accent),
            onPressed: () { Navigator.pop(ctx); setState(() { _projectName = ctrl.text.isNotEmpty ? ctrl.text : 'Untitled'; _isDirty = true; }); },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // -- BUILD ------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        await _autoSave();
        if (mounted) {
          navigator.pop(result);
        }
      },
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: GestureDetector(
            onTap: _showRenameDialog,
            child: Column(
              children: [
                Text('AW STUDIO', style: GoogleFonts.pressStart2p(fontSize: 9, color: _gold, letterSpacing: 1.5)),
                const SizedBox(height: 2),
                Text(_projectName, style: GoogleFonts.inter(fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(icon: Icon(Icons.image_search, color: _gold), onPressed: _showImportTileDialog, tooltip: 'Import Built-in Tile'),
            IconButton(icon: Icon(Icons.undo, color: _undoStack.length > 1 ? _gold : _gold.withValues(alpha: 0.3)), onPressed: _undoStack.length > 1 ? _undo : null, tooltip: 'Undo'),
            IconButton(icon: Icon(Icons.redo, color: _redoStack.isNotEmpty ? _gold : _gold.withValues(alpha: 0.3)), onPressed: _redoStack.isNotEmpty ? _redo : null, tooltip: 'Redo'),
            IconButton(icon: const Icon(Icons.close, color: Colors.redAccent), onPressed: () => Navigator.of(context).maybePop(), tooltip: 'Exit'),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _buildCanvas()),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  // -- Canvas -----------------------------------------------

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxCellW = constraints.maxWidth / _canvasW;
        final maxCellH = constraints.maxHeight / _canvasH;
        final cellSize = min(maxCellW, maxCellH).clamp(2.0, 40.0);
        final totalW = cellSize * _canvasW;
        final totalH = cellSize * _canvasH;
        return InteractiveViewer(
          transformationController: _zoomController,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(200),
          minScale: 0.5,
          maxScale: 20.0,
          child: Center(
            child: Listener(
              onPointerDown: (_) => setState(() => _pointerCount++),
              onPointerUp: (_) => setState(() => _pointerCount--),
              onPointerCancel: (_) => setState(() => _pointerCount--),
              child: GestureDetector(
                onPanStart: (d) {
                  if (_pointerCount == 1) _onCanvasTap(d.localPosition, cellSize);
                },
                onPanUpdate: (d) {
                  if (_pointerCount == 1) _onCanvasDrag(d.localPosition, cellSize);
                },
                onPanEnd: (_) => _onCanvasDragEnd(),
                onTapDown: (d) {
                  if (_pointerCount == 1) _onCanvasTap(d.localPosition, cellSize);
                },
                onTapUp: (_) => _onCanvasDragEnd(),
                child: CustomPaint(
                  size: Size(totalW, totalH),
                  painter: _PixelCanvasPainter(
                    layers: _layers,
                    cellSize: cellSize,
                    canvasW: _canvasW,
                    canvasH: _canvasH,
                    showGrid: _showGrid,
                    bgMode: _bgMode,
                    selectionRect: _selectionRect,
                    movingPixels: _movingPixels,
                    isMoving: _isMovingSelection,
                    tool: _tool,
                    lassoPath: _lassoPath,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
  // -- Bottom Panel -----------------------------------------

  Widget _buildBottomPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: _isExpanded ? 460 : 260,
      decoration: const BoxDecoration(color: _surface, border: Border(top: BorderSide(color: _border, width: 1))),
      child: Column(children: [
        Row(children: [
          Expanded(child: TabBar(
            controller: _tabController, indicatorColor: _accent, labelColor: _gold,
            unselectedLabelColor: Colors.white38, labelStyle: GoogleFonts.pressStart2p(fontSize: 6),
            tabs: const [Tab(text: 'TOOLS'), Tab(text: 'COLOR'), Tab(text: 'LAYERS'), Tab(text: 'MORE')],
          )),
          IconButton(
            icon: Icon(_isExpanded ? Icons.expand_more : Icons.expand_less, color: _gold, size: 20),
            onPressed: () => setState(() => _isExpanded = !_isExpanded),
            tooltip: _isExpanded ? 'Collapse' : 'Expand',
          ),
        ]),
        Expanded(child: TabBarView(
          controller: _tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [_buildToolsTab(), _buildColorTab(), _buildLayersTab(), _buildMoreTab()],
        )),
      ]),
    );
  }

  // -- Tools Tab --------------------------------------------

  Widget _buildToolsTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _toolBtn(DesignerTool.pencil, Icons.mode_edit, 'Draw'),
            _toolBtn(DesignerTool.eraser, Icons.cleaning_services, 'Erase'),
            _toolBtn(DesignerTool.fill, Icons.format_color_fill, 'Fill'),
            _toolBtn(DesignerTool.eraseFill, Icons.format_color_reset, 'EraseFill'),
            _toolBtn(DesignerTool.eyedropper, Icons.colorize, 'Pick'),
            _toolBtn(DesignerTool.select, Icons.select_all, 'Select'),
            _toolBtn(DesignerTool.lassoSelect, Icons.gesture, 'Lasso'),
            _toolBtn(DesignerTool.line, Icons.timeline, 'Line'),
            _toolBtn(DesignerTool.rect, Icons.rectangle_outlined, 'Rect'),
            _toolBtn(DesignerTool.circle, Icons.circle_outlined, 'Circle'),
          ]),
        ),
        const SizedBox(height: 8),
        if (_tool == DesignerTool.rect || _tool == DesignerTool.circle)
          Row(children: [
            const Text('Fill:', style: TextStyle(color: Colors.white54, fontSize: 11)),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('Outline', style: TextStyle(fontSize: 10)), selected: _shapeFill == ShapeFill.outline, selectedColor: _accent, backgroundColor: _bg, labelStyle: TextStyle(color: _shapeFill == ShapeFill.outline ? Colors.white : Colors.white54), onSelected: (_) => setState(() => _shapeFill = ShapeFill.outline)),
            const SizedBox(width: 6),
            ChoiceChip(label: const Text('Filled', style: TextStyle(fontSize: 10)), selected: _shapeFill == ShapeFill.filled, selectedColor: _accent, backgroundColor: _bg, labelStyle: TextStyle(color: _shapeFill == ShapeFill.filled ? Colors.white : Colors.white54), onSelected: (_) => setState(() => _shapeFill = ShapeFill.filled)),
          ]),
        Row(children: [
          const Text('Brush:', style: TextStyle(color: Colors.white54, fontSize: 11)),
          Expanded(child: Slider(value: _brushSize.toDouble(), min: 1, max: 8, divisions: 7, activeColor: _accent, inactiveColor: _border, label: '${_brushSize}px', onChanged: (v) => setState(() => _brushSize = v.round()))),
          Text('${_brushSize}px', style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        Row(children: [
          const Text('Grid:', style: TextStyle(color: Colors.white54, fontSize: 11)),
          Switch(value: _showGrid, onChanged: (v) => setState(() => _showGrid = v), activeThumbColor: _accent),
          const SizedBox(width: 8),
          const Text('BG:', style: TextStyle(color: Colors.white54, fontSize: 11)),
          const SizedBox(width: 4),
          _bgModeBtn(CanvasBgMode.darkTransparent, Icons.grid_3x3, 'Dark'),
          _bgModeBtn(CanvasBgMode.lightTransparent, Icons.grid_3x3, 'Light'),
          _bgModeBtn(CanvasBgMode.white, Icons.square, 'White'),
          const Spacer(),
          Container(width: 30, height: 30, decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(6), border: Border.all(color: _gold, width: 1.5))),
          const SizedBox(width: 4),
          Text('#${_colorToHex(_primaryColor)}', style: const TextStyle(color: Colors.white54, fontFamily: 'monospace', fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _bgModeBtn(CanvasBgMode mode, IconData icon, String tooltip) {
    final selected = _bgMode == mode;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: IconButton(
        icon: Icon(icon, size: 16, color: selected ? _gold : Colors.white24),
        onPressed: () => setState(() => _bgMode = mode),
        tooltip: tooltip,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }

  Widget _toolBtn(DesignerTool tool, IconData icon, String label) {
    final selected = _tool == tool;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () {
          if (_tool != tool) {
            if (_tool == DesignerTool.select) _commitMovingSelection();
            setState(() => _tool = tool);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? _accent.withValues(alpha: 0.25) : _bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? _accent : _border, width: selected ? 1.5 : 1),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: selected ? _gold : Colors.white54, size: 20),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: selected ? _gold : Colors.white38, fontSize: 7, fontFamily: 'PressStart2P')),
          ]),
        ),
      ),
    );
  }
  // -- Color Tab --------------------------------------------

  Widget _buildColorTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        ColorPicker(
          pickerColor: _primaryColor,
          onColorChanged: (color) {
            setState(() {
              _primaryColor = color;
              _r = (color.r * 255).roundToDouble();
              _g = (color.g * 255).roundToDouble();
              _b = (color.b * 255).roundToDouble();
              _a = (color.a * 255).roundToDouble();
              _hexController.text = _colorToHex(_primaryColor);
            });
          },
          pickerAreaHeightPercent: 0.8,
          enableAlpha: false,
          displayThumbColor: true,
          paletteType: PaletteType.hueWheel,
          labelTypes: const [],
          colorPickerWidth: 220,
        ),
        const SizedBox(height: 12),
        Row(children: [
          const Text('#', style: TextStyle(color: _gold, fontSize: 14, fontFamily: 'monospace')),
          const SizedBox(width: 4),
          SizedBox(width: 90, child: TextField(
            controller: _hexController,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: _border)), focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: _accent))),
            onSubmitted: _updateColorFromHex,
          )),
          const SizedBox(width: 8),
          Container(width: 24, height: 24, decoration: BoxDecoration(color: _primaryColor, borderRadius: BorderRadius.circular(4), border: Border.all(color: _gold))),
        ]),
        const SizedBox(height: 12),
        if (_recentColors.isNotEmpty) ...[
          const Text('Recent:', style: TextStyle(color: Colors.white38, fontSize: 9)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: _recentColors.map((c) => GestureDetector(
            onTap: () => _pickColor(c),
            child: Container(width: 34, height: 34, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(6), border: Border.all(color: c == _primaryColor ? _gold : _border, width: c == _primaryColor ? 2 : 1))),
          )).toList()),
        ],
        const SizedBox(height: 8),
        const Text('Swatches:', style: TextStyle(color: Colors.white38, fontSize: 9)),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: [
          Colors.white, Colors.black, Colors.red, Colors.pink, Colors.purple, Colors.deepPurple,
          Colors.indigo, Colors.blue, Colors.cyan, Colors.teal, Colors.green, Colors.lightGreen,
          Colors.lime, Colors.yellow, Colors.amber, Colors.orange, Colors.deepOrange, Colors.brown,
          Colors.grey, Colors.blueGrey, const Color(0xFF8D6E63), const Color(0xFFFFCC80),
          const Color(0xFF80DEEA), const Color(0xFFCE93D8),
        ].map((c) => GestureDetector(
          onTap: () => _pickColor(c),
          child: Container(
            width: 34, 
            height: 34, 
            decoration: BoxDecoration(
              color: c, 
              borderRadius: BorderRadius.circular(6), 
              border: Border.all(color: c == _primaryColor ? _gold : _border, width: c == _primaryColor ? 2 : 1),
            ),
          ),
        )).toList()),
        const SizedBox(height: 12),
        _colorSlider('R', _r, Colors.redAccent, (v) => setState(() { _r = v; _updateColorFromSliders(); })),
        _colorSlider('G', _g, Colors.greenAccent, (v) => setState(() { _g = v; _updateColorFromSliders(); })),
        _colorSlider('B', _b, Colors.lightBlueAccent, (v) => setState(() { _b = v; _updateColorFromSliders(); })),
        _colorSlider('A', _a, Colors.white70, (v) => setState(() { _a = v; _updateColorFromSliders(); })),
      ]),
    );
  }

  Widget _colorSlider(String lbl, double val, Color color, ValueChanged<double> onChanged) {
    return Row(children: [
      SizedBox(width: 16, child: Text(lbl, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold))),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), trackHeight: 2),
          child: Slider(value: val, min: 0, max: 255, activeColor: color, inactiveColor: _border, onChanged: onChanged),
        ),
      ),
      SizedBox(width: 24, child: Text(val.round().toString(), style: const TextStyle(color: Colors.white70, fontSize: 10))),
    ]);
  }

  // -- Layers Tab -------------------------------------------

  Widget _buildLayersTab() {
    // Show layers in reverse order (top layer at top of UI list)
    final reversedLayers = _layers.reversed.toList();

    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(children: [
          Text('Layers (${_layers.length})', style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.add, color: _gold, size: 18),
            onPressed: () {
              setState(() {
                _pushUndo();
                final newId = 'layer_${DateTime.now().millisecondsSinceEpoch}';
                _layers.add(AWLayer(id: newId, name: 'Layer ${_layers.length + 1}', width: _canvasW, height: _canvasH));
                _activeLayerIndex = _layers.length - 1;
              });
            },
            tooltip: 'Add Layer',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          if (_layers.length > 1)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
              onPressed: () {
                setState(() {
                  _pushUndo();
                  _layers.removeAt(_activeLayerIndex);
                  if (_activeLayerIndex >= _layers.length) _activeLayerIndex = _layers.length - 1;
                });
              },
              tooltip: 'Delete Layer',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ]),
      ),
      Expanded(
        child: ReorderableListView.builder(
          itemCount: _layers.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              _pushUndo();
              // Adjust indices for internal list (which is reversed in UI)
              int actualOld = _layers.length - 1 - oldIndex;
              int actualNew = _layers.length - 1 - newIndex;
              if (oldIndex < newIndex) actualNew++;

              final item = _layers.removeAt(actualOld);
              if (actualNew > _layers.length) {
                _layers.add(item);
              } else {
                _layers.insert(actualNew, item);
              }

              // Update active layer index
              _activeLayerIndex = _layers.indexOf(item);
            });
          },
          itemBuilder: (ctx, i) {
            final layer = reversedLayers[i];
            final actualIndex = _layers.indexOf(layer);
            final active = actualIndex == _activeLayerIndex;

            return InkWell(
              key: ValueKey(layer.id),
              onTap: () {
                _commitMovingSelection();
                setState(() => _activeLayerIndex = actualIndex);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: active ? _accent.withValues(alpha: 0.2) : _bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: active ? _accent : _border, width: active ? 1.5 : 1),
                ),
                child: Row(children: [
                  const Icon(Icons.drag_handle, color: Colors.white24, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(layer.name, style: TextStyle(color: active ? _gold : Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 120,
                    child: SliderTheme(
                      data: SliderTheme.of(context).copyWith(thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), trackHeight: 2),
                      child: Slider(
                        value: layer.opacity,
                        min: 0,
                        max: 1,
                        activeColor: _accent,
                        inactiveColor: _border,
                        onChanged: (v) => setState(() {
                          layer.opacity = v;
                          _isDirty = true;
                        }),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(layer.visible ? Icons.visibility : Icons.visibility_off, color: layer.visible ? _gold : Colors.white24, size: 16),
                    onPressed: () => setState(() {
                      layer.visible = !layer.visible;
                      _isDirty = true;
                    }),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  if (actualIndex > 0)
                    IconButton(
                      icon: const Icon(Icons.merge_type, color: _gold, size: 16),
                      onPressed: () => _mergeLayerDown(actualIndex),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Merge Down',
                    ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }
  // -- More Tab (Filters / Actions) -------------------------

  Widget _buildMoreTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('EDIT SELECTION', style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 2)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _actionChip('Select All', Icons.select_all, () { 
            _commitMovingSelection(); 
            setState(() { 
              _selectionRect = Rect.fromLTRB(0, 0, _canvasW.toDouble(), _canvasH.toDouble()); 
              _tool = DesignerTool.select; 
            }); 
          }),
          _actionChip('Deselect', Icons.deselect, () { 
            _commitMovingSelection(); 
            setState(() => _selectionRect = null); 
          }),
          if (_selectionRect != null) _actionChip('Cut', Icons.cut, _cutSelection),
          if (_selectionRect != null) _actionChip('Copy', Icons.copy, _copySelection),
          if (_clipboardPixels != null) _actionChip('Paste', Icons.paste, _pasteSelection),
        ]),
        const SizedBox(height: 10),
        const Text('CANVAS ACTIONS', style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 2)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _actionChip('New Canvas', Icons.add, _showCanvasSizeDialog),
          _actionChip('Import PNG', Icons.file_open, _importImage),
          _actionChip('Save PNG', Icons.save_alt, _exportImage),
          _actionChip('Save Project', Icons.save, _saveProject),
          _actionChip('Clear All', Icons.delete_outline, () { _pushUndo(); _initFreshCanvas(); setState(() {}); }),
        ]),
        const SizedBox(height: 10),
        const Text('FILTERS', style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 2)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _filterChip('Grayscale', 'grayscale'), _filterChip('Invert', 'invert'),
          _filterChip('Bright +', 'brightness+'), _filterChip('Bright -', 'brightness-'),
          _filterChip('Contrast +', 'contrast+'), _filterChip('Contrast -', 'contrast-'),
          _filterChip('Blur', 'blur'), _filterChip('Outline', 'outline'),
        ]),
        const SizedBox(height: 10),
        const Text('TRANSFORM', style: TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 2)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _filterChip('Mirror H', 'mirror_h'), _filterChip('Mirror V', 'mirror_v'),
          _filterChip('Rotate CW', 'rotate_cw'), _filterChip('Rotate CCW', 'rotate_ccw'),
        ]),
        const SizedBox(height: 6),
        Text('Canvas: x | Layers: ',
          style: const TextStyle(color: Colors.white24, fontSize: 9, fontFamily: 'monospace')),
      ]),
    );
  }

  Widget _actionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: _gold),
      label: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      backgroundColor: _bg, side: const BorderSide(color: _border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: onTap,
    );
  }

  Widget _filterChip(String label, String filter) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      backgroundColor: _accentDim.withValues(alpha: 0.15),
      side: BorderSide(color: _accent.withValues(alpha: 0.3)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onPressed: () => _applyFilter(filter),
    );
  }
}

// -------------------------------------------------------------
// Canvas Painter - Composites all visible layers
// -------------------------------------------------------------

class _PixelCanvasPainter extends CustomPainter {
  final List<AWLayer> layers;
  final double cellSize;
  final int canvasW;
  final int canvasH;
  final bool showGrid;
  final CanvasBgMode bgMode;
  final Rect? selectionRect;
  final List<List<Color>>? movingPixels;
  final bool isMoving;
  final DesignerTool tool;
  final List<Point<int>>? lassoPath;

  _PixelCanvasPainter({
    required this.layers, required this.cellSize,
    required this.canvasW, required this.canvasH, required this.showGrid,
    required this.bgMode, required this.tool, this.selectionRect, this.movingPixels, this.isMoving = false, this.lassoPath,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final lightGrey = Paint()..color = bgMode == CanvasBgMode.lightTransparent ? Colors.white : const Color(0xFF3A3A3A);
    final darkGrey = Paint()..color = bgMode == CanvasBgMode.lightTransparent ? const Color(0xFFE0E0E0) : const Color(0xFF2A2A2A);

    for (int y = 0; y < canvasH; y++) {
      for (int x = 0; x < canvasW; x++) {
        final rect = Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize);
        
        if (bgMode == CanvasBgMode.white) {
          canvas.drawRect(rect, Paint()..color = Colors.white);
        } else {
          final isLight = (x + y) % 2 == 0;
          canvas.drawRect(rect, isLight ? lightGrey : darkGrey);
        }

        // Composite layers bottom to top
        for (final layer in layers) {
          if (!layer.visible || layer.opacity <= 0) continue;
          final color = layer.pixels[y][x];
          if (color.a > 0) {
            paint.color = color.withValues(alpha: color.a * layer.opacity);
            canvas.drawRect(rect, paint);
          }
        }
      }
    }

    if (showGrid && cellSize >= 4) {
      final gridPaint = Paint()..color = const Color(0x20FFFFFF)..strokeWidth = 0.5;
      for (int x = 0; x <= canvasW; x++) {
        canvas.drawLine(Offset(x * cellSize, 0), Offset(x * cellSize, canvasH * cellSize), gridPaint);
      }
      for (int y = 0; y <= canvasH; y++) {
        canvas.drawLine(Offset(0, y * cellSize), Offset(canvasW * cellSize, y * cellSize), gridPaint);
      }
    }

    if (selectionRect != null) {
      final sRect = Rect.fromLTRB(
        selectionRect!.left * cellSize,
        selectionRect!.top * cellSize,
        selectionRect!.right * cellSize,
        selectionRect!.bottom * cellSize,
      );
      
      if (isMoving && movingPixels != null) {
        for (int y = 0; y < movingPixels!.length; y++) {
          for (int x = 0; x < movingPixels![y].length; x++) {
            final col = movingPixels![y][x];
            if (col.a > 0) {
              final pRect = Rect.fromLTWH(
                (selectionRect!.left + x) * cellSize,
                (selectionRect!.top + y) * cellSize,
                cellSize,
                cellSize,
              );
              paint.color = col;
              canvas.drawRect(pRect, paint);
            }
          }
        }
      }
      
      canvas.drawRect(sRect, Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 2.0);
      canvas.drawRect(sRect, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.0);
    }

    // -- Draw Lasso Path --
    final lp = lassoPath;
    if (tool == DesignerTool.lassoSelect && lp != null && lp.length > 1) {
      final lassoPaint = Paint()
        ..color = Colors.cyanAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
        
      final path = Path();
      path.moveTo(lp[0].x * cellSize + cellSize / 2, lp[0].y * cellSize + cellSize / 2);
      for (int i = 1; i < lp.length; i++) {
        path.lineTo(lp[i].x * cellSize + cellSize / 2, lp[i].y * cellSize + cellSize / 2);
      }
      
      canvas.drawPath(path, lassoPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PixelCanvasPainter oldDelegate) => true;
}

// -- Tile Import Sheet ------------------------------------------------

class _TileImportSheet extends StatefulWidget {
  final ValueChanged<TileDefinition> onTileSelected;

  const _TileImportSheet({required this.onTileSelected});

  @override
  State<_TileImportSheet> createState() => _TileImportSheetState();
}

class _TileImportSheetState extends State<_TileImportSheet> {
  String _search = '';
  List<TileDefinition> _tiles = [];

  @override
  void initState() {
    super.initState();
    _tiles = BiomeDataManager.allTiles.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<TileDefinition> get _filteredTiles {
    if (_search.isEmpty) return _tiles;
    return _tiles.where((t) => t.name.toLowerCase().contains(_search.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF141420),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text('Import Built-in Tile', style: GoogleFonts.pressStart2p(fontSize: 10, color: const Color(0xFFFFD740))),
          const SizedBox(height: 16),
          TextField(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Search tiles...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search, color: Colors.white54, size: 20),
              filled: true,
              fillColor: Colors.white.withOpacity(0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (val) => setState(() => _search = val),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              itemCount: _filteredTiles.length,
              itemBuilder: (ctx, i) {
                final t = _filteredTiles[i];
                final path = t.isAutotiled ? t.assetPath.replaceAll('{dir}', 'center') : t.assetPath;
                return InkWell(
                  onTap: () => widget.onTileSelected(t),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Center(
                            child: Image.asset(path, filterQuality: FilterQuality.none,
                              errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white24)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          t.name,
                          style: GoogleFonts.inter(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}