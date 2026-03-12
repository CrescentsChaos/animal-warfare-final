// lib/biome_exploration_map.dart
//
// Tile-based walkable map for biome exploration.
// Currently supports Swamp; other biomes can add their own generators.

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import 'package:animal_warfare/game/biome_map_data.dart';
import 'package:animal_warfare/explore_screen.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/battle_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/user_state.dart';
import 'package:animal_warfare/services/audio_service.dart';
import 'package:animal_warfare/services/weather_service.dart';
import 'package:animal_warfare/widgets/weather_overlay.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/widgets/game_clock_widget.dart';
import 'package:animal_warfare/shop_screen.dart';
import 'package:animal_warfare/phone_screen.dart';
import 'package:animal_warfare/theme.dart';

class BiomeExplorationMap extends StatefulWidget {
  final String biomeName;
  final List<Organism> allOrganisms;
  final UserData currentUser;
  final LocalAuthService authService;
  final BiomeMapData? customMapData;

  final String? playerSpritePath;

  const BiomeExplorationMap({
    super.key,
    required this.biomeName,
    required this.allOrganisms,
    required this.currentUser,
    required this.authService,
    this.customMapData,
    this.playerSpritePath,
  });

  @override
  State<BiomeExplorationMap> createState() => _BiomeExplorationMapState();
}

class _BiomeExplorationMapState extends State<BiomeExplorationMap>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ── Constants ──
  static const double tileSize = 32.0;

  // ── Map Dimensions ──
  late int mapWidth;
  late int mapHeight;

  // ── Map state ──
  late BiomeMapData _mapData;
  late double _playerX;
  late double _playerY;
  double _velX = 0;
  double _velY = 0;
  bool _encounterActive = false;

  // ── Asset state ──
  ui.Image? _playerImage;

  // ── Colors ──
  late Color _biomeBaseColor;
  late Color _biomeDarkColor;
  late Color _biomeHighlightColor;

  // ── Animation & Physics ──
  int _stepCount = 0;
  late Ticker _ticker;
  double _stepDistanceAccumulator = 0;

  // ── Camera ──
  double _cameraX = 0;
  double _cameraY = 0;
  Size _viewSize = Size.zero;
  final GlobalKey _mapBoundaryKey = GlobalKey();
  bool _isPanning = false;

  // ── Directional Animation ──
  String _playerDirection = 'down';
  int _walkFrame = 0;
  double _walkAnimAccumulator = 0.0;
  final Map<String, List<ui.Image>> _playerSprites = {};

  final Set<String> _activeDirections = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Colors
    _biomeBaseColor = _getBiomeBaseColor(widget.biomeName);
    _biomeDarkColor = _getDarkerColor(_biomeBaseColor);
    _biomeHighlightColor = _getBiomeHighlightColor(widget.biomeName);
    // Generate or load map
    if (widget.customMapData != null) {
      _mapData = widget.customMapData!;
    } else {
      final config = BiomeDataManager.getBiome(widget.biomeName.toLowerCase());
      if (config.layout != null) {
        _mapData = MapStringParser.parse(
          config.layout!,
          config: config,
          spawn: config.spawnPoint,
        );
      } else {
        _mapData = BiomeMapGenerator.generate(
          width: 80,
          height: 80,
          config: config,
        );
      }
    }
    mapWidth = _mapData.width;
    mapHeight = _mapData.height;

    _playerX = _mapData.spawnPoint.x * tileSize;
    _playerY = _mapData.spawnPoint.y * tileSize;

    // Play biome music
    final fileName = widget.biomeName.toLowerCase().replaceAll(' ', '_');
    AudioService.instance.playMusic('audio/${fileName}_theme.mp3');

    // Camera initialization will happen in _scrollToPlayer or build

    // Ticker for smooth movement
    _ticker = createTicker(_onTick);
    _ticker.start();

    // Load PNG assets
    _loadAssets();

    // Scroll to player after first build
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToPlayer());
  }

  void _onTick(Duration elapsed) {
    if (_encounterActive) {
      // Force stop player when encounter begins
      _velX = 0;
      _velY = 0;
      _walkFrame = 0;
      _walkAnimAccumulator = 0.0;
      // We still update camera if not panning
      if (!_isPanning) _scrollToPlayer(insideSetState: true);
      setState(() {});
      return;
    }

    // Handle movement based on DPad
    double vx = 0;
    double vy = 0;
    if (_activeDirections.isNotEmpty) {
      // Prioritize the last pressed direction
      final dir = _activeDirections.last;
      _playerDirection = dir;
      if (dir == 'up') {
        vy = -1.0;
      } else if (dir == 'down') {
        vy = 1.0;
      } else if (dir == 'left') {
        vx = -1.0;
      } else if (dir == 'right') {
        vx = 1.0;
      }
    }
    _velX = vx;
    _velY = vy;

    if (_velX == 0 && _velY == 0) {
      // Always ensure camera follows if not panning (even if stopped)
      if (!_isPanning) {
        _scrollToPlayer(insideSetState: true);
      }
      // Reset walk animation when stopped
      if (_walkFrame != 0) {
        setState(() {
          _walkFrame = 0;
          _walkAnimAccumulator = 0.0;
        });
      } else {
        setState(() {});
      }
      return;
    }

    const double speed = 5.0; // Snappier speed
    final nextX = _playerX + _velX * speed;
    final nextY = _playerY + _velY * speed;

    // Discrete 4-way collision
    bool canMove = _canWalkAt(nextX, nextY);

    setState(() {
      if (canMove) {
        _playerX = nextX;
        _playerY = nextY;
      }

      // Handle walk animation Accumulator
      const double dist = speed;

      _walkAnimAccumulator += dist;
      if (_walkAnimAccumulator >= tileSize / 2) {
        _walkAnimAccumulator -= tileSize / 2;
        // Cycle: 1 -> 2 -> 1 (frame 0 is idle)
        _walkFrame = (_walkFrame == 1) ? 2 : 1;
      }

      _stepDistanceAccumulator += dist;
      if (_stepDistanceAccumulator >= tileSize) {
        _stepDistanceAccumulator -= tileSize;
        _stepCount++;
        _checkStepEncounter(
          ((_playerY + tileSize / 2) / tileSize).floor(),
          ((_playerX + tileSize / 2) / tileSize).floor(),
        );
      }

      if (!_isPanning) {
        _scrollToPlayer(insideSetState: true);
      }
    });
  }

  bool _canWalkAt(double x, double y) {
    const margin = 10.0;
    final corners = [
      Offset(x + margin, y + margin),
      Offset(x + tileSize - margin, y + margin),
      Offset(x + margin, y + tileSize - margin),
      Offset(x + tileSize - margin, y + tileSize - margin),
    ];

    for (final p in corners) {
      final r = (p.dy / tileSize).floor();
      final c = (p.dx / tileSize).floor();

      if (r < 0 || r >= _mapData.height || c < 0 || c >= _mapData.width) {
        return false;
      }

      final baseTile = _mapData.grid[r][c];
      final overlayTile = _mapData.overlayGrid?[r][c];

      bool walkable = baseTile.isWalkable && (overlayTile?.isWalkable ?? true);
      if (!walkable) return false;
    }
    return true;
  }

  void _checkStepEncounter(int row, int col) {
    if (_encounterActive) return;

    // Check both base and overlay for encounter tiles (like tallgrass)
    final baseTile = _mapData.grid[row][col];
    final overlayTile = _mapData.overlayGrid?[row][col];
    final activeTile = (overlayTile != null && overlayTile.hasEncounter)
        ? overlayTile
        : baseTile;

    if (activeTile.hasEncounter) {
      final roll = Random().nextDouble();
      if (roll < 0.40) {
        setState(() {
          _encounterActive = true;
          _velX = 0;
          _velY = 0;
          _playerX = col * tileSize;
          _playerY = row * tileSize;
          _walkFrame = 0;
          _walkAnimAccumulator = 0.0;
        });

        _triggerEncounter(activeTile.category);
      }
    }
  }

  Future<void> _loadAssets() async {
    // 1. Try specified path or default
    final String mainPath = widget.playerSpritePath ?? 'assets/player.png';
    _playerImage = await BiomeDataManager.loadImage(mainPath);
    if (_playerImage == null && widget.playerSpritePath != null) {
      _playerImage = await BiomeDataManager.loadImage('assets/player.png');
    }

    // 2. Load directional animations
    final String basePath = mainPath.replaceAll('.png', '');
    final directions = ['down', 'up', 'left', 'right'];

    for (final dir in directions) {
      final List<ui.Image> frames = [];
      for (int i = 0; i < 3; i++) {
        final frameImg = await BiomeDataManager.loadImage(
          '${basePath}_${dir}_$i.png',
        );
        if (frameImg != null) {
          frames.add(frameImg);
        }
      }

      // Fallback: If no frames for this direction, use main player image as frame 0 if nothing else
      if (frames.isEmpty && _playerImage != null) {
        // No directional frames found
      } else if (frames.isNotEmpty) {
        _playerSprites[dir] = frames;
      }
    }

    if (mounted) setState(() {});
  }

  // Redundant _loadImage removed.

  @override
  void dispose() {
    AudioService.instance.stopAll();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      AudioService.instance.pauseAll();
    } else if (state == AppLifecycleState.resumed) {
      final fileName = widget.biomeName.toLowerCase().replaceAll(' ', '_');
      AudioService.instance.playMusic('audio/${fileName}_theme.mp3');
    }
  }

  void _scrollToPlayer({bool insideSetState = false}) {
    if (!mounted || _viewSize == Size.zero) return;

    // Target scroll position to keep player center at viewport center
    double targetX = (_playerX + tileSize / 2) - (_viewSize.width / 2);
    double targetY = (_playerY + tileSize / 2) - (_viewSize.height / 2);

    if (insideSetState) {
      _cameraX = targetX;
      _cameraY = targetY;
    } else {
      setState(() {
        _cameraX = targetX;
        _cameraY = targetY;
      });
    }
  }

  void _triggerEncounter(TileCategory category) {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    final hour = TimeService().currentGameTime.hour;
    String timeOfDay;
    if (hour >= 6 && hour < 18) {
      timeOfDay = 'day';
    } else if (hour >= 18 && hour < 21) {
      timeOfDay = 'evening';
    } else {
      timeOfDay = 'night';
    }

    // Map TileCategory to encounterType string
    String? encounterType;
    if (category == TileCategory.water) {
      encounterType = 'water';
    } else if (category == TileCategory.tallGrass) {
      encounterType = 'tallgrass';
    } else if (category == TileCategory.ground ||
        category == TileCategory.path) {
      encounterType = 'land';
    }

    final encounter = getWeightedRandomOrganism(
      widget.biomeName,
      widget.allOrganisms,
      accountLevel: user.accountLevel,
      inventory: user.inventory,
      teamMoveNames: user.teamOrganisms
          .expand((o) => o.selectedMoveNames)
          .toList(),
      currentTimeOfDay: timeOfDay,
      encounterType: encounterType,
    );

    if (encounter != null) {
      AudioService.instance.playOrganismCry(encounter.organism.cry);
      setState(() => _encounterActive = true);
      // Immediately start the battle (no popup)
      _onFight(encounter.organism);
    } else {
      setState(() => _encounterActive = false);
    }
  }

  Future<ui.Image?> _captureMapScreenshot() async {
    try {
      final boundary =
          _mapBoundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary != null) {
        return await boundary.toImage(pixelRatio: 1.0);
      }
    } catch (_) {}
    return null;
  }

  void _onFight(Organism wildOrganism) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    CapturedOrganism playerFighter;
    if (user.teamOrganisms.isNotEmpty) {
      playerFighter = user.teamOrganisms.first;
    } else if (user.capturedOrganisms.isNotEmpty) {
      playerFighter = user.capturedOrganisms.first;
    } else {
      playerFighter = CapturedOrganism.spawn(
        Organism.HUMAN_ORGANISM.copyWith(name: user.username),
        level: user.accountLevel,
      );
    }

    final wildFighter = CapturedOrganism.spawn(
      wildOrganism,
      accountLevel: user.accountLevel,
    );

    final hour = TimeService().currentGameTime.hour;
    String timeOfDay;
    if (hour >= 6 && hour < 18) {
      timeOfDay = 'day';
    } else if (hour >= 18 && hour < 21) {
      timeOfDay = 'evening';
    } else {
      timeOfDay = 'night';
    }

    // Capture map as screenshot for battle background
    final mapScreenshot = await _captureMapScreenshot();

    AudioService.instance.pauseAll();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          playerOrganism: playerFighter,
          opponentOrganism: wildFighter,
          biomeName: widget.biomeName,
          playerTeam: user.teamOrganisms,
          timeOfDay: timeOfDay,
          mapScreenshot: mapScreenshot,
        ),
      ),
    );
    AudioService.instance.resumeAll();

    if (mounted) {
      setState(() {
        _encounterActive = false;
      });
    }
  }

  // ── Colors (same as biome_detail_screen) ──
  Color _getBiomeBaseColor(String biomeName) {
    switch (biomeName.toLowerCase()) {
      case 'swamp':
        return const Color(0xFF4B6F44);
      default:
        return const Color(0xFFDAA520);
    }
  }

  Color _getDarkerColor(Color color) {
    int r = (color.r * 255.0 * 0.6).round().clamp(0, 255);
    int g = (color.g * 255.0 * 0.6).round().clamp(0, 255);
    int b = (color.b * 255.0 * 0.6).round().clamp(0, 255);
    return Color.fromARGB((color.a * 255.0).round().clamp(0, 255), r, g, b);
  }

  Color _getBiomeHighlightColor(String biomeName) {
    final biome = biomeName.toLowerCase();
    if (biome.contains('swamp')) return const Color(0xFFCE93D8);
    return const Color(0xFFDAA520);
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    final weather = WeatherService().getCurrentWeather(widget.biomeName);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        centerTitle: true,
        title: Text(widget.biomeName.toUpperCase()),
        backgroundColor: _biomeDarkColor,
        titleTextStyle: TextStyle(
          color: _biomeHighlightColor,
          fontFamily: 'PressStart2P',
          fontSize: 14,
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 4.0, bottom: 4.0),
          child: GameClockWidget(highlightColor: _biomeHighlightColor),
        ),
        leadingWidth: 120,
        actions: [
          IconButton(
            icon: Icon(Icons.shopping_cart, color: AppColors.highlightColor),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ShopScreen(biome: widget.biomeName),
              ),
            ),
          ),
          _buildStaminaBar(context),
        ],
      ),
      body: RepaintBoundary(
        key: _mapBoundaryKey,
        child: Stack(
          children: [
            // Map
            _buildMapView(),
            // Weather overlay
            IgnorePointer(child: WeatherOverlay(weather: weather)),
            // Weather indicator chip
            _buildWeatherChip(weather),
            // Step counter
            _buildStepCounter(),
            // D-Pad
            _buildDPad(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewSize = Size(constraints.maxWidth, constraints.maxHeight);
        if (_viewSize != viewSize) {
          _viewSize = viewSize;
          // Trigger first camera update
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _scrollToPlayer(),
          );
        }

        return GestureDetector(
          onScaleStart: (details) {
            _isPanning = true;
          },
          onScaleUpdate: (details) {
            if (_isPanning && details.pointerCount == 1) {
              setState(() {
                _cameraX -= details.focalPointDelta.dx;
                _cameraY -= details.focalPointDelta.dy;

                // We allow panning slightly beyond bounds now if user wants infinite black,
                // but let's keep some loose clamping or allow it for better feel.
              });
            }
          },
          child: CustomPaint(
            size: viewSize,
            painter: _BiomeMapPainter(
              mapData: _mapData,
              playerX: _playerX,
              playerY: _playerY,
              cameraX: _cameraX,
              cameraY: _cameraY,
              tileSize: tileSize,
              playerImage: _playerImage,
              playerDirection: _playerDirection,
              walkFrame: _walkFrame,
              playerSprites: _playerSprites,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDPad() {
    const double btnSize = 60.0;
    const double spacing = 10.0;

    return Positioned(
      bottom: 40,
      left: 30,
      child: GestureDetector(
        onPanStart: (details) =>
            _handleDPadGesture(details.localPosition, btnSize, spacing),
        onPanUpdate: (details) =>
            _handleDPadGesture(details.localPosition, btnSize, spacing),
        onPanEnd: (_) {
          setState(() {
            _activeDirections.clear();
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Up
            Row(
              children: [
                const SizedBox(width: btnSize + spacing),
                _dpadButtonVisual('up', Icons.arrow_upward, btnSize),
                const SizedBox(width: btnSize + spacing),
              ],
            ),
            const SizedBox(height: spacing),
            // Left, Empty, Right
            Row(
              children: [
                _dpadButtonVisual('left', Icons.arrow_back, btnSize),
                const SizedBox(width: btnSize + spacing),
                _dpadButtonVisual('right', Icons.arrow_forward, btnSize),
              ],
            ),
            const SizedBox(height: spacing),
            // Down
            Row(
              children: [
                const SizedBox(width: btnSize + spacing),
                _dpadButtonVisual('down', Icons.arrow_downward, btnSize),
                const SizedBox(width: btnSize + spacing),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleDPadGesture(Offset localPos, double btnSize, double spacing) {
    String? newDir;

    // 3x3 grid detection logic
    // Row 0: Up is at (1, 0)
    // Row 1: Left at (0, 1), Right at (2, 1)
    // Row 2: Down at (1, 2)

    final double gridW = btnSize * 3 + spacing * 2;
    final double gridH = btnSize * 3 + spacing * 2;

    if (localPos.dx < 0 ||
        localPos.dx > gridW ||
        localPos.dy < 0 ||
        localPos.dy > gridH) {
      if (_activeDirections.isNotEmpty) {
        setState(() => _activeDirections.clear());
      }
      return;
    }

    final int col = (localPos.dx / (btnSize + spacing)).floor().clamp(0, 2);
    final int row = (localPos.dy / (btnSize + spacing)).floor().clamp(0, 2);

    if (row == 0 && col == 1) {
      newDir = 'up';
    } else if (row == 1 && col == 0) {
      newDir = 'left';
    } else if (row == 1 && col == 2) {
      newDir = 'right';
    } else if (row == 2 && col == 1) {
      newDir = 'down';
    }

    if (newDir != null) {
      if (_activeDirections.isEmpty || _activeDirections.last != newDir) {
        setState(() {
          _isPanning = false;
          _activeDirections.clear();
          _activeDirections.add(newDir!);
        });
      }
    } else {
      if (_activeDirections.isNotEmpty) {
        setState(() => _activeDirections.clear());
      }
    }
  }

  Widget _dpadButtonVisual(String direction, IconData icon, double size) {
    final bool isActive = _activeDirections.contains(direction);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isActive
            ? _biomeHighlightColor.withValues(alpha: 0.4)
            : Colors.black45,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isActive
              ? _biomeHighlightColor
              : _biomeHighlightColor.withValues(alpha: 0.5),
          width: isActive ? 3 : 2,
        ),
      ),
      child: Icon(
        icon,
        color: isActive ? Colors.white : _biomeHighlightColor,
        size: size * 0.6,
      ),
    );
  }

  Widget _buildStaminaBar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, animation, _) =>
                PhoneScreen(initialBiome: widget.biomeName),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      },
      child: Consumer<UserState>(
        builder: (context, userState, child) {
          final user = userState.currentUser;
          if (user == null) return const SizedBox.shrink();
          final progress = user.stamina / 100;
          return Container(
            width: 100,
            height: 24,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              border: Border.all(color: _biomeHighlightColor, width: 2),
              borderRadius: BorderRadius.circular(12),
              color: _biomeDarkColor,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: user.stamina > 25
                            ? [Colors.greenAccent, Colors.green]
                            : [Colors.redAccent, Colors.red],
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    '${user.stamina}/100',
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'PressStart2P',
                      fontSize: 7,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildWeatherChip(dynamic weather) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _biomeHighlightColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud, color: _biomeHighlightColor, size: 16),
            const SizedBox(width: 6),
            Text(
              "${WeatherService().getForecast(widget.biomeName).first.temperatureCelsius.toStringAsFixed(1)}°C",
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCounter() {
    return Positioned(
      top: 12,
      left: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _biomeHighlightColor, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.directions_walk, color: _biomeHighlightColor, size: 14),
            const SizedBox(width: 4),
            Text(
              '$_stepCount',
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Custom Painter — renders the tile map & player
// ────────────────────────────────────────────────────────────────────

class _BiomeMapPainter extends CustomPainter {
  final BiomeMapData mapData;
  final double playerX;
  final double playerY;
  final double cameraX;
  final double cameraY;
  final double tileSize;
  final ui.Image? playerImage;
  final String playerDirection;
  final int walkFrame;
  final Map<String, List<ui.Image>> playerSprites;

  _BiomeMapPainter({
    required this.mapData,
    required this.playerX,
    required this.playerY,
    required this.cameraX,
    required this.cameraY,
    required this.tileSize,
    this.playerImage,
    required this.playerDirection,
    required this.walkFrame,
    required this.playerSprites,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Ground Layer (Base Terrain)
    for (int r = 0; r < mapData.height; r++) {
      for (int c = 0; c < mapData.width; c++) {
        _drawTileAt(canvas, r, c, mapData.grid[r][c], mapData.grid);
      }
    }

    // 2. Object & Player Sorting Layer
    for (int r = 0; r < mapData.height; r++) {
      // Draw non-tallgrass overlay objects
      if (mapData.overlayGrid != null) {
        for (int c = 0; c < mapData.width; c++) {
          final tile = mapData.overlayGrid![r][c];
          if (tile != null && tile.category != TileCategory.tallGrass) {
            _drawTileAt(canvas, r, c, tile, mapData.overlayGrid!);
          }
        }
      }

      // Draw player
      final py = playerY + tileSize / 2;
      if (py >= r * tileSize && py < (r + 1) * tileSize) {
        _drawPlayer(canvas);
      }

      // Draw Tallgrass & other "above-player" overlays
      if (mapData.overlayGrid != null) {
        for (int c = 0; c < mapData.width; c++) {
          final tile = mapData.overlayGrid![r][c];
          if (tile != null && tile.category == TileCategory.tallGrass) {
            _drawTileAt(canvas, r, c, tile, mapData.overlayGrid!);
          }
        }
      }
    }
  }

  void _drawTileAt(
    Canvas canvas,
    int r,
    int c,
    MapTile tile,
    List<List<dynamic>> grid,
  ) {
    final rect = Rect.fromLTWH(
      c * tileSize - cameraX,
      r * tileSize - cameraY,
      tileSize,
      tileSize,
    );
    final assets = BiomeDataManager.tileAssets[tile.tileId];

    if (assets != null && assets.isNotEmpty) {
      ui.Image? img;
      if (tile.definition.isAutotiled) {
        final dir = _getDirection(r, c, tile.tileId, grid);
        img = assets[dir] ?? assets['center'] ?? assets.values.first;
      } else {
        img = assets['center'] ?? assets.values.first;
      }

      final double assetW = img.width.toDouble();
      final double assetH = img.height.toDouble();

      // Match Editor logic: bottom-center anchoring
      final double drawW = assetW;
      final double drawH = assetH;

      final double drawX = rect.center.dx - drawW / 2;
      final double drawY = rect.bottom - drawH;

      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, assetW, assetH),
        Rect.fromLTWH(drawX, drawY, drawW, drawH),
        Paint(),
      );
      return;
    }

    // Fallback Vectors (if PNG not found)
    final paint = Paint();
    switch (tile.category) {
      case TileCategory.ground:
        paint.color = const Color(0xFF3D5E37);
        canvas.drawRect(rect, paint);
        break;
      case TileCategory.water:
        paint.color = const Color(0xFF1A3A35);
        canvas.drawRect(rect, paint);
        break;
      case TileCategory.path:
        paint.color = const Color(0xFF5A7854);
        canvas.drawRect(rect, paint);
        break;
      case TileCategory.tallGrass:
        paint.color = Colors.green.withValues(alpha: 0.5);
        canvas.drawRect(rect, paint);
        break;
      default:
        // No block drawing here to avoid cluttering base layer
        break;
    }
  }

  String _getDirection(int r, int c, String tileId, List<List<dynamic>> grid) {
    bool up = r > 0 && _getTileId(grid[r - 1][c]) == tileId;
    bool down = r < grid.length - 1 && _getTileId(grid[r + 1][c]) == tileId;
    bool left = c > 0 && _getTileId(grid[r][c - 1]) == tileId;
    bool right = c < grid[r].length - 1 && _getTileId(grid[r][c + 1]) == tileId;

    if (!up && down) return 'up';
    if (up && !down) return 'down';
    if (!left && right) return 'left';
    if (left && !right) return 'right';
    return 'center';
  }

  String? _getTileId(dynamic tile) {
    if (tile is MapTile) return tile.tileId;
    return null;
  }

  void _drawPlayer(Canvas canvas) {
    final px = (playerX - cameraX) + tileSize / 2;
    final py = (playerY - cameraY) + tileSize / 2;

    ui.Image? img;

    if (playerSprites.containsKey(playerDirection) &&
        playerSprites[playerDirection]!.isNotEmpty) {
      final frames = playerSprites[playerDirection]!;
      // walkFrame 0=idle, 1,2=walking
      if (walkFrame < frames.length) {
        img = frames[walkFrame];
      } else {
        img = frames[0];
      }
    } else {
      img = playerImage;
    }

    if (img != null) {
      final double assetW = img.width.toDouble();
      final double assetH = img.height.toDouble();

      // Player sprite is typically 1 tile wide, 1 tile tall (as per user request: "32x32")
      final double drawW = tileSize;
      final double drawH = tileSize;

      // Center player in the tile (px, py are already centers)
      final double x = px - drawW / 2;
      final double y = py - drawH / 2;

      final destRect = Rect.fromLTWH(x, y, drawW, drawH);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, assetW, assetH),
        destRect,
        Paint(),
      );
    } else {
      // Vector player
      final paint = Paint()..color = Colors.blue;
      canvas.drawCircle(Offset(px, py), tileSize * 0.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BiomeMapPainter oldDelegate) {
    return oldDelegate.playerX != playerX ||
        oldDelegate.playerY != playerY ||
        oldDelegate.cameraX != cameraX ||
        oldDelegate.cameraY != cameraY ||
        oldDelegate.walkFrame != walkFrame ||
        oldDelegate.playerDirection != playerDirection;
  }
}
