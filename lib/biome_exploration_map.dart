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
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/widgets/weather_overlay.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/widgets/game_clock_widget.dart';
import 'package:animal_warfare/shop_screen.dart';
import 'package:animal_warfare/phone_screen.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/game/overworld_sprite.dart';

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
  int _stepCount = 0; // internal counter for encounter logic
  late Ticker _ticker;
  // double _stepDistanceAccumulator = 0; // REMOVED

  // ── Camera ──
  double _cameraX = 0;
  double _cameraY = 0;
  Size _viewSize = Size.zero;
  final GlobalKey _mapBoundaryKey = GlobalKey();
  bool _isPanning = false;
  double _zoomScale = 1.0;

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

  // ── Interaction ──
  String? _bubbleText;
  Timer? _bubbleTimer;
  Offset? _interactionTilePos;

  // ── Swimming ──
  bool _isSwimming = false;
  double _swimBobTime = 0;
  double _jumpTime = 0;
  double _jumpOffset = 0;
  Duration _lastElapsedTime = Duration.zero;
  String? _confirmationTitle;
  VoidCallback? _onConfirm;

  // ── Overworld Pheno Sprites ──
  final List<OverworldSprite> _overworldSprites = [];
  Timer? _phenoSpawnTimer;
  double _phenoTickAccumulator = 0;

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

    // Start pheno spawn timer
    _phenoSpawnTimer = Timer.periodic(
      const Duration(seconds: 2), // INCREASED FREQUENCY
      (_) => _trySpawnPhenoSprite(),
    );
  }

  void _onTick(Duration elapsed) {
    final double dt = (elapsed - _lastElapsedTime).inMilliseconds / 1000.0;
    _lastElapsedTime = elapsed;

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

    if (_isSwimming) {
      _swimBobTime += dt;
    }

    if (_jumpTime > 0) {
      _jumpTime -= dt;
      if (_jumpTime < 0) {
        _jumpTime = 0;
      }
      // Parabolic jump: y = 4 * height * (t/total) * (1 - t/total)
      const double jumpDuration = 0.3;
      const double jumpHeight = 20.0;
      double t = (jumpDuration - _jumpTime) / jumpDuration;
      if (t < 0) t = 0;
      if (t > 1) t = 1;
      _jumpOffset = -4 * jumpHeight * t * (1 - t);
      setState(() {});
    } else {
      _jumpOffset = 0;
    }

    // ── Overworld sprite AI ──
    _phenoTickAccumulator += dt;
    if (_phenoTickAccumulator >= 0.05) {
      // ~20fps for AI
      bool anyChanged = false;
      for (final sprite in _overworldSprites) {
        // Feed player position for nature affinity logic
        sprite.playerPixelX = _playerX;
        sprite.playerPixelY = _playerY;

        if (sprite.tick(_phenoTickAccumulator, _mapData, tileSize)) {
          anyChanged = true;
        }
      }
      // Remove expired sprites
      _overworldSprites.removeWhere((s) => s.isExpired);
      _phenoTickAccumulator = 0;
      if (anyChanged && mounted) setState(() {});

      // Check collision constantly (in case a sprite walks into the player)
      _checkPhenoCollision();
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
    if (direction == 'up') {
      vy = -1;
    } else if (direction == 'down') {
      vy = 1;
    } else if (direction == 'left') {
      vx = -1;
    } else if (direction == 'right') {
      vx = 1;
    }

    final double nextX = _playerX + vx * tileSize;
    final double nextY = _playerY + vy * tileSize;

    if (_canWalkAt(nextX, nextY)) {
      // Check for floating jump
      final int currentR = (_playerY / tileSize).round();
      final int currentC = (_playerX / tileSize).round();
      final int targetR = (nextY / tileSize).round();
      final int targetC = (nextX / tileSize).round();

      final currentBase = _mapData.grid[currentR][currentC];
      final currentOverlay = _mapData.overlayGrid?[currentR][currentC];
      final targetBase = _mapData.grid[targetR][targetC];
      final targetOverlay = _mapData.overlayGrid?[targetR][targetC];

      final bool fromFloating =
          currentBase.category == TileCategory.floating ||
          (currentOverlay?.any((t) => t.category == TileCategory.floating) ??
              false);
      final bool toFloating =
          targetBase.category == TileCategory.floating ||
          (targetOverlay?.any((t) => t.category == TileCategory.floating) ??
              false);

      if (fromFloating || toFloating) {
        _jumpTime = 0.3; // 300ms jump
      }

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
    final double speed = _isSwimming
        ? 2.5
        : (_isRunning ? 8.0 : 4.0); // Px per frame
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

        // Check collision with overworld sprites
        _checkPhenoCollision();
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

      final bool isWater =
          baseTile.category == TileCategory.water ||
          (overlayTile?.any((t) => t.category == TileCategory.water) ?? false);
      final bool isSolid =
          baseTile.category == TileCategory.solid ||
          (overlayTile?.any((t) => t.category == TileCategory.solid) ?? false);
      final bool isFloating =
          baseTile.category == TileCategory.floating ||
          (overlayTile?.any((t) => t.category == TileCategory.floating) ??
              false);
      final bool isOneWay =
          baseTile.category == TileCategory.oneway ||
          (overlayTile?.any((t) => t.category == TileCategory.oneway) ?? false);

      if (isSolid) return false;

      // Oneway logic: jump over from above but not from below
      if (isOneWay) {
        final currentR = (_playerY / tileSize).floor();
        if (currentR > r) {
          // Attempting to move UP onto a oneway tile
          return false;
        }
      }

      if (_isSwimming) {
        // Must stay in water, but cannot swim THROUGH a lily pad (floating)
        if (!isWater || isFloating) return false;
      } else {
        // If it's a floating tile, we can walk on it regardless of base tile (water)
        if (isFloating) continue;

        // Cannot enter water while walking
        if (isWater) return false;

        // Standard walkability check for land
        bool walkable;
        if (baseTile.walkabilityOverride != null) {
          walkable = baseTile.walkabilityOverride!;
        } else {
          bool overlaysWalkable = true;
          if (overlayTile != null) {
            for (final ot in overlayTile) {
              if (!ot.isWalkable) {
                overlaysWalkable = false;
                break;
              }
            }
          }
          walkable = baseTile.isWalkable && overlaysWalkable;
        }
        if (!walkable) return false;
      }
    }
    return true;
  }

  void _checkStepEncounter(int row, int col) {
    if (_encounterActive) return;

    // Check both base and overlay for encounter tiles (like tallgrass)
    final baseTile = _mapData.grid[row][col];
    final overlayTiles = _mapData.overlayGrid?[row][col];

    MapTile? encounterTile;
    if (overlayTiles != null) {
      for (final t in overlayTiles) {
        if (t.hasEncounter) {
          encounterTile = t;
          break; // Use the first encounter tile found in overlays
        }
      }
    }

    final activeTile = encounterTile ?? baseTile;

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

        _triggerEncounter(activeTile);
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

  void _disposeTimers() {
    _bubbleTimer?.cancel();
    _phenoSpawnTimer?.cancel();
  }

  @override
  void dispose() {
    _disposeTimers();
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

    // Center camera on player, accounting for zoom
    double targetX =
        (_playerX + tileSize / 2) - (_viewSize.width / (2 * _zoomScale));
    double targetY =
        (_playerY + tileSize / 2) - (_viewSize.height / (2 * _zoomScale));

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

  void _triggerEncounter(MapTile activeTile) {
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
    if (activeTile.category == TileCategory.water) {
      encounterType = 'water';
    } else if (activeTile.category == TileCategory.tallGrass) {
      encounterType = 'tallgrass';
    } else if (activeTile.category == TileCategory.ground ||
        activeTile.category == TileCategory.path) {
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
      currentTileId: activeTile.tileId,
      currentTileCategory: activeTile.category,
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
            // Interaction Bubble
            if (_bubbleText != null && _interactionTilePos != null)
              _buildInteractionBubble(),
            // Confirmation Dialog
            if (_confirmationTitle != null) _buildConfirmationDialog(),
            // Run Button
            _buildRunButton(),
            // Interact Button
            _buildInteractButton(),
            // D-Pad
            _buildDPad(),
            _buildZoomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final currentHour = TimeService().currentGameTime.hour;
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
                _cameraX -= details.focalPointDelta.dx / _zoomScale;
                _cameraY -= details.focalPointDelta.dy / _zoomScale;

                // Restrict panning to player range
                final double idealX =
                    (_playerX + tileSize / 2) -
                    (_viewSize.width / (2 * _zoomScale));
                final double idealY =
                    (_playerY + tileSize / 2) -
                    (_viewSize.height / (2 * _zoomScale));
                final double panRange = 200.0 / _zoomScale;
                _cameraX = _cameraX.clamp(idealX - panRange, idealX + panRange);
                _cameraY = _cameraY.clamp(idealY - panRange, idealY + panRange);
              });
            }
          },
          onScaleEnd: (details) {
            _isPanning = false;
          },
          child: CustomPaint(
            size: viewSize,
            painter: _BiomeMapPainter(
              currentHour: currentHour,
              mapData: _mapData,
              playerX: _playerX,
              playerY: _playerY,
              cameraX: _cameraX,
              cameraY: _cameraY,
              tileSize: tileSize,
              zoomScale: _zoomScale,
              playerImage: _playerImage,
              playerDirection: _playerDirection,
              walkFrame: _walkFrame,
              playerSprites: _playerSprites,
              isSwimming: _isSwimming,
              //up and down during swimming
              bobbingOffset: _isSwimming ? (sin(_swimBobTime * 1.2) * 0.8) : 0,
              jumpOffset: _jumpOffset,
              isOnFloating: () {
                // If moving, check both source and destination to keep height consistent
                final int r1 = (_playerY / tileSize).floor();
                final int c1 = (_playerX / tileSize).floor();
                final int r2 = (_targetY / tileSize).floor();
                final int c2 = (_targetX / tileSize).floor();

                bool isFloat(int r, int c) {
                  if (r < 0 ||
                      r >= _mapData.height ||
                      c < 0 ||
                      c >= _mapData.width) {
                    return false;
                  }
                  final base = _mapData.grid[r][c];
                  final overlay = _mapData.overlayGrid?[r][c];
                  return base.category == TileCategory.floating ||
                      (overlay?.any(
                            (t) => t.category == TileCategory.floating,
                          ) ??
                          false);
                }

                if (_isMovingToTarget) {
                  // If either is floating, keep the height up during the transition
                  return isFloat(r1, c1) || isFloat(r2, c2);
                }
                return isFloat(r1, c1);
              }(),
              overworldSprites: _overworldSprites,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDPad() {
    const double padSize = 160.0;
    const double btnSize = 48.0;

    return Positioned(
      bottom: 24,
      left: 16,
      child: Container(
        width: padSize,
        height: padSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.black.withValues(alpha: 0.5),
              Colors.black.withValues(alpha: 0.2),
            ],
          ),
          border: Border.all(
            color: _biomeHighlightColor.withValues(alpha: 0.15),
            width: 1,
          ),
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
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _biomeHighlightColor.withValues(alpha: 0.08),
                    border: Border.all(
                      color: _biomeHighlightColor.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                ),
              ),
              // Directional Buttons
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
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
                  padding: const EdgeInsets.only(bottom: 6),
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
                  padding: const EdgeInsets.only(left: 6),
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
                  padding: const EdgeInsets.only(right: 6),
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
      bottom: 100,
      right: 90,
      child: GestureDetector(
        onTap: () {
          if (_isSwimming) return; // Cannot toggle run while swimming
          setState(() => _isRunning = !_isRunning);
        },
        child: Opacity(
          opacity: _isSwimming ? 0.3 : 1.0,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _isRunning
                    ? [Colors.orangeAccent, Colors.redAccent]
                    : [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.black.withValues(alpha: 0.3),
                      ],
              ),
              border: Border.all(
                color: _isRunning
                    ? Colors.white
                    : _biomeHighlightColor.withValues(alpha: 0.4),
                width: 2.5,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.bolt,
                color: _isRunning ? Colors.white : _biomeHighlightColor,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInteractButton() {
    return Positioned(
      bottom: 36,
      right: 24,
      child: GestureDetector(
        onTap: _handleInteract,
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(color: _biomeHighlightColor, width: 3),
          ),
          child: Center(
            child: Text(
              'A',
              style: TextStyle(
                color: _biomeDarkColor,
                fontFamily: 'PressStart2P',
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildZoomButtons() {
    return Positioned(
      top: 80,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _zoomButton(Icons.add, () {
            setState(() {
              _zoomScale = (_zoomScale + 0.1).clamp(0.5, 3.0);
              _scrollToPlayer(insideSetState: true);
            });
          }),
          const SizedBox(height: 12),
          _zoomButton(Icons.remove, () {
            setState(() {
              _zoomScale = (_zoomScale - 0.1).clamp(0.5, 3.0);
              _scrollToPlayer(insideSetState: true);
            });
          }),
        ],
      ),
    );
  }

  Widget _zoomButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.5),
          border: Border.all(color: _biomeHighlightColor, width: 1.5),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }

  void _handleInteract() {
    if (_encounterActive || _isMovingToTarget) return;

    // Determine target coordinate based on facing direction
    int targetR = (_playerY / tileSize).floor();
    int targetC = (_playerX / tileSize).floor();

    if (_playerDirection == 'up') {
      targetR -= 1;
    }
    if (_playerDirection == 'down') {
      targetR += 1;
    }
    if (_playerDirection == 'left') {
      targetC -= 1;
    }
    if (_playerDirection == 'right') {
      targetC += 1;
    }

    // Bounds check
    if (targetR < 0 ||
        targetR >= mapHeight ||
        targetC < 0 ||
        targetC >= mapWidth) {
      return;
    }

    // Check overlay then base
    final baseTileInfo = _mapData.grid[targetR][targetC];
    final overlayTiles = _mapData.overlayGrid?[targetR][targetC];

    final baseDef = BiomeDataManager.allTiles[baseTileInfo.tileId];

    bool isWater = baseDef?.category == TileCategory.water;
    bool isLand =
        baseDef?.category == TileCategory.ground ||
        baseDef?.category == TileCategory.path;
    bool isFloating = baseDef?.category == TileCategory.floating;
    String? textToShow = baseDef?.interactionText;

    if (overlayTiles != null) {
      for (final ot in overlayTiles) {
        final def = BiomeDataManager.allTiles[ot.tileId];
        if (def?.category == TileCategory.water) {
          isWater = true;
        }
        if (def?.category == TileCategory.ground ||
            def?.category == TileCategory.path)
          isLand = true;
        if (def?.category == TileCategory.floating) isFloating = true;
        if (def?.interactionText != null) textToShow = def!.interactionText;
      }
    }

    if (!_isSwimming && isWater) {
      _showConfirmationDialog("Swim here?", () {
        setState(() {
          _isSwimming = true;
          _isRunning = false; // Cannot run in water
          _jumpTime = 0.3; // Jump into water animation
          _playerX = targetC * tileSize;
          _playerY = targetR * tileSize;
          _isMovingToTarget = false;
        });
      });
      return;
    } else if (_isSwimming && isLand) {
      _showConfirmationDialog("Get out of water?", () {
        setState(() {
          _isSwimming = false;
          _jumpTime = 0.3; // Jump out of water animation
          _playerX = targetC * tileSize;
          _playerY = targetR * tileSize;
          _isMovingToTarget = false;
        });
      });
      return;
    } else if (_isSwimming && isFloating) {
      _showConfirmationDialog("Jump on?", () {
        setState(() {
          _isSwimming = false;
          _jumpTime = 0.3;
          _playerX = targetC * tileSize;
          _playerY = targetR * tileSize;
          _isMovingToTarget = false;
        });
      });
      return;
    }

    if (textToShow != null) {
      setState(() {
        _bubbleText = textToShow;
        // Tile pos is targetR, targetC. We'll render it above the player or tile. Let's render above player.
        _interactionTilePos = Offset(_playerX, _playerY - tileSize);
      });

      _bubbleTimer?.cancel();
      _bubbleTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _bubbleText = null;
          });
        }
      });
    }
  }

  Widget _buildInteractionBubble() {
    if (_bubbleText == null ||
        _interactionTilePos == null ||
        _viewSize == Size.zero) {
      return const SizedBox.shrink();
    }

    // Map world coords back to screen coordinates
    double screenX =
        (_interactionTilePos!.dx - _cameraX) * _zoomScale +
        (tileSize * _zoomScale) / 2;
    double screenY = (_interactionTilePos!.dy - _cameraY) * _zoomScale - 10;

    return Positioned(
      left: screenX - 100, // Roughly center max width 200
      top: screenY - 50, // Height offset
      child: IgnorePointer(
        child: Container(
          width: 200,
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _biomeDarkColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              _bubbleText!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _biomeDarkColor,
                fontFamily: 'PressStart2P',
                fontSize: 8,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showConfirmationDialog(String title, VoidCallback onConfirm) {
    setState(() {
      _confirmationTitle = title;
      _onConfirm = onConfirm;
    });
  }

  Widget _buildConfirmationDialog() {
    return Center(
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _biomeHighlightColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _confirmationTitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 10,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDialogButton("YES", () {
                  _onConfirm?.call();
                  setState(() {
                    _confirmationTitle = null;
                    _onConfirm = null;
                  });
                }),
                _buildDialogButton("NO", () {
                  setState(() {
                    _confirmationTitle = null;
                    _onConfirm = null;
                  });
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogButton(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _biomeDarkColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _biomeHighlightColor, width: 1),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'PressStart2P',
            fontSize: 10,
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
      if (_activeDirections.isNotEmpty) {
        setState(() => _activeDirections.clear());
      }
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

    if (_activeDirections.isEmpty || _activeDirections.last != newDir) {
      setState(() {
        _isPanning = false;
        _activeDirections.clear();
        _activeDirections.add(newDir!);
      });
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
            _getWeatherIcon(weather),
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

  Widget _getWeatherIcon(Weather weather) {
    switch (weather) {
      case Weather.clear:
        return const Icon(
          Icons.wb_sunny_outlined,
          color: Colors.yellow,
          size: 16,
        );
      case Weather.rain:
        return const Icon(Icons.umbrella, color: Colors.blue, size: 16);
      case Weather.heavyRain:
        return const Icon(
          Icons.beach_access,
          color: Colors.blueAccent,
          size: 16,
        );
      case Weather.sunny:
        return const Icon(Icons.wb_sunny, color: Colors.orange, size: 16);
      case Weather.snowstorm:
        return const Icon(
          Icons.ac_unit,
          color: Colors.lightBlueAccent,
          size: 16,
        );
      case Weather.hail:
        return const Icon(Icons.grain, color: Colors.white, size: 16);
      case Weather.sandstorm:
        return const Icon(Icons.waves, color: Colors.brown, size: 16);
      case Weather.windstorm:
        return const Icon(Icons.air, color: Colors.white70, size: 16);
      case Weather.thunderstorm:
        return const Icon(Icons.bolt, color: Colors.yellowAccent, size: 16);
      case Weather.fog:
        return const Icon(Icons.cloud_queue, color: Colors.grey, size: 16);
      default:
        return const Icon(Icons.wb_cloudy, color: Colors.white, size: 16);
    }
  }

  // Step counter removed per user request.

  // ── Pheno Sprite Spawning ──
  void _trySpawnPhenoSprite() {
    if (!mounted || _encounterActive) return;
    // Total overworld spawn limit
    if (_overworldSprites.length >= 10) return;

    final rng = Random();
    final eligibleOrgs = widget.allOrganisms
        .where((org) => org.pheno != 'none' && org.pheno.isNotEmpty)
        .toList();
    eligibleOrgs.shuffle(rng);

    for (final org in eligibleOrgs) {
      final habitats = org.habitat
          .split(',')
          .map((e) => e.trim().toLowerCase())
          .toSet();
      if (!habitats.contains(widget.biomeName.toLowerCase())) continue;

      // Max of the same phenotype based on config or default 5
      final spawnData = BiomeDataManager.phenoSpawnData[org.pheno];
      final maxSpawns = spawnData?.maxSpawns ?? 5;

      final currentPhenoCount = _overworldSprites
          .where((s) => s.organism.pheno == org.pheno)
          .length;
      if (currentPhenoCount >= maxSpawns) continue;

      // Rarity-based spawn chance (Increased for higher frequency)
      double chance;
      switch (org.rarity.toLowerCase()) {
        case 'common':
          chance = 0.20;
          break;
        case 'uncommon':
          chance = 0.15;
          break;
        case 'rare':
          chance = 0.10;
          break;
        case 'epic':
          chance = 0.05;
          break;
        case 'legendary':
          chance = 0.02;
          break;
        case 'mythical':
          chance = 0.01;
          break;
        default:
          chance = 0.10;
      }

      if (rng.nextDouble() > chance) {
        continue;
      }

      // Find a valid tile on the map
      final validTiles = _findValidPhenoTiles(org);
      if (validTiles.isEmpty) continue;

      final pos = validTiles[rng.nextInt(validTiles.length)];
      final sprite = OverworldSprite(
        organism: org,
        row: pos[0],
        col: pos[1],
        tileSize: tileSize,
      );

      // Load sprites
      _loadPhenoSprites(sprite);
      _overworldSprites.add(sprite);
      if (mounted) setState(() {});
      break; // One spawn per tick
    }
  }

  List<List<int>> _findValidPhenoTiles(Organism org) {
    final tiles = <List<int>>[];
    final spawnSet = org.spawnTiles
        .split(',')
        .map((e) => e.trim().toLowerCase().replaceAll('_', ''))
        .toSet();
    final isAny = spawnSet.contains('any');

    for (int r = 0; r < _mapData.height; r++) {
      for (int c = 0; c < _mapData.width; c++) {
        final base = _mapData.grid[r][c];
        final overlay = _mapData.overlayGrid?[r][c];
        if (base.category == TileCategory.solid ||
            (overlay?.any((t) => t.category == TileCategory.solid) ?? false))
          continue;

        if (isAny) {
          tiles.add([r, c]);
          continue;
        }

        bool match = false;
        if (spawnSet.contains(base.tileId.toLowerCase().replaceAll('_', '')) ||
            spawnSet.contains(
              base.category.name.toLowerCase().replaceAll('_', ''),
            )) {
          match = true;
        } else if (overlay != null) {
          for (final ot in overlay) {
            if (spawnSet.contains(
                  ot.tileId.toLowerCase().replaceAll('_', ''),
                ) ||
                spawnSet.contains(
                  ot.category.name.toLowerCase().replaceAll('_', ''),
                )) {
              match = true;
              break;
            }
          }
        }

        if (match) {
          tiles.add([r, c]);
        }
      }
    }
    return tiles;
  }

  Future<void> _loadPhenoSprites(OverworldSprite sprite) async {
    final pheno = sprite.organism.pheno;
    for (final dir in ['up', 'down', 'left', 'right']) {
      final img = await BiomeDataManager.loadImage(
        'assets/overworld/${pheno}_$dir.png',
      );
      if (img != null) {
        sprite.sprites[dir] = img;
      }
    }
    if (mounted) setState(() {});
  }

  void _checkPhenoCollision() {
    if (_encounterActive) return;
    final toRemove = <OverworldSprite>[];
    for (final sprite in _overworldSprites) {
      if (sprite.isCollidingWith(_playerX, _playerY, tileSize)) {
        toRemove.add(sprite);
        // Trigger encounter with this organism
        AudioService.instance.playOrganismCry(sprite.organism.cry);
        setState(() => _encounterActive = true);
        _onFight(sprite.organism);
        break;
      }
    }
    _overworldSprites.removeWhere((s) => toRemove.contains(s));
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
  final bool isSwimming;
  final double bobbingOffset;
  final double jumpOffset;
  final bool isOnFloating;
  final List<OverworldSprite> overworldSprites;
  final int currentHour;
  final double zoomScale;

  _BiomeMapPainter({
    required this.currentHour,
    required this.mapData,
    required this.playerX,
    required this.playerY,
    required this.cameraX,
    required this.cameraY,
    required this.tileSize,
    required this.zoomScale,
    this.playerImage,
    required this.playerDirection,
    required this.walkFrame,
    required this.playerSprites,
    this.isSwimming = false,
    this.bobbingOffset = 0,
    this.jumpOffset = 0,
    this.isOnFloating = false,
    this.overworldSprites = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(zoomScale);
    // Removed duplicate canvas.translate since manual offsets (- cameraX) are calculated per tile/sprite

    // 1. Ground Layer (Base Terrain + Floating Tiles)
    for (int r = 0; r < mapData.height; r++) {
      for (int c = 0; c < mapData.width; c++) {
        // Draw base terrain
        _drawTileAt(canvas, r, c, mapData.grid[r][c], mapData.grid);

        // Draw floating tiles from overlay (lilypads, etc.) here so they are behind agents
        if (mapData.overlayGrid != null) {
          final overlays = mapData.overlayGrid![r][c];
          for (final tile in overlays) {
            if (tile.category == TileCategory.floating) {
              _drawTileAt(canvas, r, c, tile, mapData.overlayGrid!);
            }
          }
        }
      }
    }

    // 2. Object & Player Sorting Layer
    for (int r = 0; r < mapData.height; r++) {
      // Draw non-tallgrass, non-floating overlay objects
      if (mapData.overlayGrid != null) {
        for (int c = 0; c < mapData.width; c++) {
          final overlays = mapData.overlayGrid![r][c];
          for (final tile in overlays) {
            if (tile.category != TileCategory.tallGrass &&
                tile.category != TileCategory.floating) {
              _drawTileAt(canvas, r, c, tile, mapData.overlayGrid!);
            }
          }
        }
      }

      // Draw player
      final py = playerY + tileSize / 2;
      if (py >= r * tileSize && py < (r + 1) * tileSize) {
        _drawPlayer(canvas);

        // Draw Semi-Solid OVER player
        if (mapData.overlayGrid != null) {
          final int playerC = (playerX / tileSize).floor();
          if (playerC >= 0 && playerC < mapData.width) {
            final overlays = mapData.overlayGrid![r][playerC];
            for (final tile in overlays) {
              if (tile.category == TileCategory.semiSolid) {
                _drawTileAt(canvas, r, playerC, tile, mapData.overlayGrid!);
              }
            }
          }
        }
      }

      // Draw overworld sprites on this row (using pixel position for sorting)
      for (final sprite in overworldSprites) {
        final double sy = sprite.pixelY + tileSize / 2;
        if (sy >= r * tileSize && sy < (r + 1) * tileSize) {
          _drawOverworldSprite(canvas, sprite);
        }
      }

      // Draw Tallgrass & other "above-player" overlays
      if (mapData.overlayGrid != null) {
        for (int c = 0; c < mapData.width; c++) {
          final overlays = mapData.overlayGrid![r][c];
          for (final tile in overlays) {
            if (tile.category == TileCategory.tallGrass) {
              _drawTileAt(canvas, r, c, tile, mapData.overlayGrid!);
            }
          }
        }
      }
    }

    canvas.restore();

    // 3. Daylight Filter Overlay
    if (currentHour >= 18 && currentHour < 21) {
      // Evening / Sunset
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..color = Colors.deepOrange.withValues(alpha: 0.2)
          ..blendMode = BlendMode.srcOver,
      );
    } else if (currentHour >= 21 || currentHour < 6) {
      // Night
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..color = Colors.indigo.shade900.withValues(alpha: 0.4)
          ..blendMode = BlendMode.srcOver,
      );
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

      // Proportional scaling for all assets relative to a 32px base, matching Editor logic.
      final double drawW = tileSize * (assetW / 32.0);
      final double drawH = tileSize * (assetH / 32.0);

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
    bool up = r > 0 && _getTileId(grid[r - 1][c], matchId: tileId) == tileId;
    bool down =
        r < grid.length - 1 &&
        _getTileId(grid[r + 1][c], matchId: tileId) == tileId;
    bool left = c > 0 && _getTileId(grid[r][c - 1], matchId: tileId) == tileId;
    bool right =
        c < grid[r].length - 1 &&
        _getTileId(grid[r][c + 1], matchId: tileId) == tileId;

    if (!up && down) return 'up';
    if (up && !down) return 'down';
    if (!left && right) return 'left';
    if (left && !right) return 'right';
    return 'center';
  }

  String? _getTileId(dynamic tile, {String? matchId}) {
    if (tile is MapTile) return tile.tileId;
    if (tile is List<MapTile>) {
      if (matchId == null) {
        return tile.isNotEmpty ? tile.first.tileId : null;
      }
      return tile.any((t) => t.tileId == matchId) ? matchId : null;
    }
    return null;
  }

  void _drawPlayer(Canvas canvas) {
    double px = (playerX - cameraX) + tileSize / 2;
    double py = (playerY - cameraY) + tileSize / 2;

    py += jumpOffset;

    if (isSwimming) {
      py += bobbingOffset;
    }

    if (isOnFloating) {
      py -= 11.0; // Shift up exactly 11 pixels as requested
    }

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

      if (isSwimming) {
        canvas.save();
        // Submerge player
        canvas.clipRect(Rect.fromLTWH(x, y, drawW, drawH * 0.6));
      }

      final destRect = Rect.fromLTWH(x, y, drawW, drawH);
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, assetW, assetH),
        destRect,
        Paint(),
      );

      if (isSwimming) {
        canvas.restore();
      }
    } else {
      // Vector player
      final paint = Paint()..color = Colors.blue;
      canvas.drawCircle(Offset(px, py), tileSize * 0.4, paint);
    }
  }

  void _drawOverworldSprite(Canvas canvas, OverworldSprite sprite) {
    final double px = sprite.pixelX - cameraX + tileSize / 2;
    final double py = sprite.pixelY - cameraY + tileSize / 2;

    ui.Image? img = sprite.sprites[sprite.direction];
    if (img == null) return;

    final double assetW = img.width.toDouble();
    final double assetH = img.height.toDouble();
    final double drawW = tileSize;
    final double drawH = tileSize;
    final double x = px - drawW / 2;
    final double y = py - drawH / 2;

    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, assetW, assetH),
      Rect.fromLTWH(x, y, drawW, drawH),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant _BiomeMapPainter oldDelegate) {
    return true; // Always repaint (overworld sprites move independently)
  }
}
