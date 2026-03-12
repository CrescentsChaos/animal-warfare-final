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
  // double _stepDistanceAccumulator = 0; // REMOVED

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

  // ── Grid Movement ──
  bool _isMovingToTarget = false;
  double _targetX = 0;
  double _targetY = 0;
  bool _isRunning = false;
  String? _queuedDirection;
  Duration? _directionHoldStart;

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
      // Force stop player
      _velX = 0;
      _velY = 0;
      _isMovingToTarget = false;
      _walkFrame = 0;
      _walkAnimAccumulator = 0.0;
      // We still update camera if not panning
      if (!_isPanning) _scrollToPlayer(insideSetState: true);
      setState(() {});
      return;
    }

    if (_isMovingToTarget) {
      _moveTowardsTarget();
      return;
    }

    // Handle movement initiation
    if (_activeDirections.isNotEmpty || _queuedDirection != null) {
      final dir = _queuedDirection ?? _activeDirections.last;
      _queuedDirection = null;

      // Tap-to-turn: If new direction, set it and start hold timer
      if (dir != _playerDirection) {
        _directionHoldStart = elapsed;
        setState(() {
          _playerDirection = dir;
          _walkFrame = 0;
        });
        return; // Wait for hold to step
      }

      // If already facing the direction, check if we should initiate move
      if (_directionHoldStart == null) {
        // Fresh touch on same direction -> move immediately
        _directionHoldStart = elapsed;
        _initiateMove(dir);
      } else {
        // Continuous hold
        final holdTime = elapsed - _directionHoldStart!;
        if (holdTime.inMilliseconds > 100) {
          _initiateMove(dir);
        }
      }
    } else {
      // No active directions
      _directionHoldStart = null;
    }
  }

  void _initiateMove(String direction) {
    double vx = 0;
    double vy = 0;
    if (direction == 'up')
      vy = -1;
    else if (direction == 'down')
      vy = 1;
    else if (direction == 'left')
      vx = -1;
    else if (direction == 'right')
      vx = 1;

    final double nextX = _playerX + vx * tileSize;
    final double nextY = _playerY + vy * tileSize;

    if (_canWalkAt(nextX, nextY)) {
      setState(() {
        _isMovingToTarget = true;
        _targetX = nextX;
        _targetY = nextY;
        _playerDirection = direction;
        _velX = vx;
        _velY = vy;
      });
    } else {
      setState(() {
        _playerDirection = direction;
        _velX = 0;
        _velY = 0;
      });
    }
  }

  void _moveTowardsTarget() {
    final double speed = _isRunning ? 8.0 : 4.0; // Px per frame
    double dx = _targetX - _playerX;
    double dy = _targetY - _playerY;
    double dist = sqrt(dx * dx + dy * dy);

    if (dist <= speed) {
      // Reached target
      setState(() {
        _playerX = _targetX;
        _playerY = _targetY;
        _isMovingToTarget = false;
        _velX = 0;
        _velY = 0;
        _walkFrame = 0; // Reset to idle frame

        // Check encounter and count step exactly on tile
        _stepCount++;
        _checkStepEncounter(
          ((_playerY + tileSize / 2) / tileSize).floor(),
          ((_playerX + tileSize / 2) / tileSize).floor(),
        );

        if (!_isPanning) {
          _scrollToPlayer(insideSetState: true);
        }
      });
    } else {
      // Move closer
      setState(() {
        _playerX += _velX * speed;
        _playerY += _velY * speed;

        // Walk animation
        _walkAnimAccumulator += speed;
        if (_walkAnimAccumulator >= tileSize / 2) {
          _walkAnimAccumulator -= tileSize / 2;
          _walkFrame = (_walkFrame == 1) ? 2 : 1;
        }

        if (!_isPanning) {
          _scrollToPlayer(insideSetState: true);
        }
      });
    }
  }

  // ── Collision ──
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

      // Prioritize explicit walkability overrides from the map data
      // If either layer has an override, it's a cell-wide permission
      bool walkable;
      if (baseTile.walkabilityOverride != null) {
        walkable = baseTile.walkabilityOverride!;
      } else {
        // Fallback to inherent tile solidity
        walkable = baseTile.isWalkable && (overlayTile?.isWalkable ?? true);
      }

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
      final double rate = activeTile.encounterRate ?? 0.40;

      final roll = Random().nextDouble();
      if (roll < rate) {
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
            // Run Button
            _buildRunButton(),
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
    const double padSize = 180.0;
    const double btnSize = 54.0;

    return Positioned(
      bottom: 40,
      left: 30,
      child: Container(
        width: padSize,
        height: padSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.black.withValues(alpha: 0.3),
            ],
          ),
          border: Border.all(
            color: _biomeHighlightColor.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: GestureDetector(
          onPanStart: (details) =>
              _handleDPadGesture(details.localPosition, padSize),
          onPanUpdate: (details) =>
              _handleDPadGesture(details.localPosition, padSize),
          onPanEnd: (_) {
            setState(() {
              _activeDirections.clear();
            });
          },
          child: Stack(
            children: [
              // Visual center
              Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _biomeHighlightColor.withValues(alpha: 0.1),
                    border: Border.all(
                      color: _biomeHighlightColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                ),
              ),
              // Directional Buttons
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _dpadButtonVisual(
                    'up',
                    Icons.keyboard_arrow_up,
                    btnSize,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _dpadButtonVisual(
                    'down',
                    Icons.keyboard_arrow_down,
                    btnSize,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _dpadButtonVisual(
                    'left',
                    Icons.keyboard_arrow_left,
                    btnSize,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _dpadButtonVisual(
                    'right',
                    Icons.keyboard_arrow_right,
                    btnSize,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunButton() {
    return Positioned(
      bottom: 70,
      right: 40,
      child: GestureDetector(
        onTap: () => setState(() => _isRunning = !_isRunning),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isRunning
                  ? [Colors.orangeAccent, Colors.redAccent]
                  : [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.black.withValues(alpha: 0.4),
                    ],
            ),
            border: Border.all(
              color: _isRunning
                  ? Colors.white
                  : _biomeHighlightColor.withValues(alpha: 0.5),
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: (_isRunning ? Colors.redAccent : Colors.black)
                    .withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(2, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt,
                  color: _isRunning ? Colors.white : _biomeHighlightColor,
                  size: 30,
                ),
                Text(
                  'RUN',
                  style: TextStyle(
                    color: _isRunning ? Colors.white : _biomeHighlightColor,
                    fontFamily: 'PressStart2P',
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleDPadGesture(Offset localPos, double padSize) {
    String? newDir;
    final center = padSize / 2;
    final dx = localPos.dx - center;
    final dy = localPos.dy - center;
    final angle = atan2(dy, dx);
    final dist = sqrt(dx * dx + dy * dy);

    // Deadzone and outer boundaries
    if (dist < 15) {
      if (_activeDirections.isNotEmpty)
        setState(() => _activeDirections.clear());
      return;
    }
    if (dist > padSize * 0.8) return; // Too far out

    // Convert angle to direction
    // Angles in radians: Right (0), Down (PI/2), Left (PI or -PI), Up (-PI/2)
    const pi = 3.1415926535897932;

    if (angle > -pi / 4 && angle <= pi / 4) {
      newDir = 'right';
    } else if (angle > pi / 4 && angle <= 3 * pi / 4) {
      newDir = 'down';
    } else if (angle > 3 * pi / 4 || angle <= -3 * pi / 4) {
      newDir = 'left';
    } else {
      newDir = 'up';
    }

    if (newDir != null) {
      if (_activeDirections.isEmpty || _activeDirections.last != newDir) {
        setState(() {
          _isPanning = false;
          _activeDirections.clear();
          _activeDirections.add(newDir!);
        });
      }
    }
  }

  Widget _dpadButtonVisual(String direction, IconData icon, double size) {
    final bool isActive = _activeDirections.contains(direction);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isActive
            ? _biomeHighlightColor.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.05),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive
              ? _biomeHighlightColor
              : _biomeHighlightColor.withValues(alpha: 0.2),
          width: isActive ? 2.5 : 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: _biomeHighlightColor.withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Icon(
        icon,
        color: isActive
            ? Colors.white
            : _biomeHighlightColor.withValues(alpha: 0.7),
        size: size * 0.7,
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
          final user = userState.currentUser!;
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
