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
import 'package:animal_warfare/widgets/organism_sprite_widget.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/widgets/game_clock_widget.dart';
import 'package:animal_warfare/shop_screen.dart';
import 'package:animal_warfare/phone_screen.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/achievement_service.dart';

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
  Offset _joystickOffset = Offset.zero;
  bool _encounterActive = false;
  SpawnResult? _currentEncounter;
  bool _isNameRevealed = false;
  late UserData _currentUser;

  // ── Asset state ──
  ui.Image? _playerImage;

  // ── Colors ──
  late Color _biomeBaseColor;
  late Color _biomeDarkColor;
  late Color _biomeHighlightColor;
  Color _rarityHighlightColor = const Color(0xFFDAA520);

  // ── Animation & Physics ──
  late AnimationController _playerBobController;
  late Animation<double> _playerBobAnim;
  late AnimationController _encounterSlideController;
  late Animation<Offset> _encounterSlideAnim;
  late AnimationController _grassShakeController;
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

  // ── Achievement ──
  late AchievementService _achievementService;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.currentUser;
    WidgetsBinding.instance.addObserver(this);

    // Colors
    _biomeBaseColor = _getBiomeBaseColor(widget.biomeName);
    _biomeDarkColor = _getDarkerColor(_biomeBaseColor);
    _biomeHighlightColor = _getBiomeHighlightColor(widget.biomeName);

    // Achievement
    final allOrganismsJson = widget.allOrganisms
        .map((o) => o.toJson())
        .toList();
    _achievementService = AchievementService(
      allOrganisms: allOrganismsJson,
      authService: widget.authService,
    );
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

    // Animations
    _playerBobController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _playerBobAnim = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _playerBobController, curve: Curves.easeInOut),
    );

    _encounterSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _encounterSlideAnim =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _encounterSlideController,
            curve: Curves.easeOutBack,
          ),
        );
    _grassShakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

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
      return;
    }
    if (_velX == 0 && _velY == 0) return;

    final speed = 5.0; // Snappier speed
    final nextX = _playerX + _velX * speed;
    final nextY = _playerY + _velY * speed;

    // Sliding collision Logic: Try moving in X and Y independently
    bool canMoveX = _canWalkAt(nextX, _playerY);
    bool canMoveY = _canWalkAt(_playerX, nextY);

    if (!canMoveX && !canMoveY) {
      // If fully blocked, check if we can actually move diagonally
      // (sometimes helpful for corner rounding)
      if (_canWalkAt(nextX, nextY)) {
        canMoveX = true;
        canMoveY = true;
      }
    }

    setState(() {
      if (canMoveX) _playerX = nextX;
      if (canMoveY) _playerY = nextY;

      // Determine direction
      if (_velX.abs() > _velY.abs()) {
        _playerDirection = _velX > 0 ? 'right' : 'left';
      } else if (_velY.abs() > 0) {
        _playerDirection = _velY > 0 ? 'down' : 'up';
      }

      // Handle walk animation Accumulator
      final actualMoveX = canMoveX ? _velX * speed : 0.0;
      final actualMoveY = canMoveY ? _velY * speed : 0.0;
      final dist = sqrt(actualMoveX * actualMoveX + actualMoveY * actualMoveY);

      if (dist > 0) {
        _walkAnimAccumulator += dist;
        if (_walkAnimAccumulator >= tileSize / 2) {
          _walkAnimAccumulator -= tileSize / 2;
          _walkFrame = (_walkFrame == 1) ? 2 : 1;
        }
      } else {
        _walkFrame = 0;
        _walkAnimAccumulator = 0.0;
      }

      _stepDistanceAccumulator += dist;
      if (_stepDistanceAccumulator >= tileSize) {
        _stepDistanceAccumulator -= tileSize;
        _stepCount++;
        _checkStepEncounter(
          (_playerY / tileSize).floor(),
          (_playerX / tileSize).floor(),
        );
      }
    });

    if (!_isPanning) {
      _scrollToPlayer();
    }
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
          _walkFrame = 0;
          _walkAnimAccumulator = 0.0;
        });

        _grassShakeController.forward(from: 0);
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) _triggerEncounter(activeTile.category);
        });
      }
    }
  }

  Future<void> _loadAssets() async {
    // Assets are now loaded centrally via BiomeDataManager, but we can load additional ones if needed.
    // However, for tiles, we rely on BiomeDataManager.tileAssets.

    // Load player image
    if (widget.playerSpritePath != null) {
      _playerImage = await BiomeDataManager.loadImage(widget.playerSpritePath!);

      final String basePath = widget.playerSpritePath!.replaceAll('.png', '');
      final directions = ['down', 'up', 'left', 'right'];
      for (final dir in directions) {
        final frames = <ui.Image>[];
        for (int i = 0; i < 3; i++) {
          final frameImg = await BiomeDataManager.loadImage(
            '${basePath}_${dir}_$i.png',
          );
          if (frameImg != null) {
            frames.add(frameImg);
          }
        }
        if (frames.isNotEmpty) {
          _playerSprites[dir] = frames;
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  // Redundant _loadImage removed.

  @override
  void dispose() {
    _playerBobController.dispose();
    _encounterSlideController.dispose();
    _grassShakeController.dispose();
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

  void _scrollToPlayer() {
    if (!mounted || _viewSize == Size.zero) return;

    // Target scroll position to keep player center at viewport center
    double targetX = (_playerX + tileSize / 2) - (_viewSize.width / 2);
    double targetY = (_playerY + tileSize / 2) - (_viewSize.height / 2);

    // If _isPanning is false, we want instantaneous following (no lag)
    _cameraX = targetX;
    _cameraY = targetY;
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

  void _dismissEncounter() {
    _encounterSlideController.reverse();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _encounterActive = false;
          _currentEncounter = null;
        });
      }
    });
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
        _currentEncounter = null;
      });
    }
  }

  void _revealName(Organism organism) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final cost = _getIdentifyStaminaCost(organism.rarity);
    if (userState.currentUser == null ||
        userState.currentUser!.stamina < cost) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Not enough stamina! Need $cost stamina.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }
    await userState.decreaseStamina(cost);
    await widget.authService.markOrganismAsDiscovered(
      _currentUser.username,
      organism.name,
    );
    final refreshedUser = await widget.authService.getCurrentUser();
    if (refreshedUser != null && mounted) {
      _currentUser = refreshedUser;
    }
    final newAchievements = await _achievementService
        .checkAndUnlockAchievements(_currentUser);
    if (newAchievements.isNotEmpty) {
      _currentUser = _currentUser.copyWith(
        completedAchievements: [
          ..._currentUser.completedAchievements,
          ...newAchievements,
        ],
      );
      await widget.authService.updateUser(_currentUser);
      userState.setCurrentUser(_currentUser);
      for (final title in newAchievements) {
        if (mounted)
          _achievementService.showAchievementSnackbar(context, title);
      }
    }
    if (mounted) {
      setState(() => _isNameRevealed = true);
      AudioService.instance.playOrganismCry(organism.cry);
    }
  }

  int _getIdentifyStaminaCost(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return 5;
      case 'uncommon':
        return 10;
      case 'rare':
        return 15;
      case 'epic':
        return 25;
      case 'legendary':
        return 40;
      case 'mythical':
        return 60;
      default:
        return 5;
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

  Color _getRarityHighlightColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey.shade400;
      case 'uncommon':
        return const Color.fromARGB(255, 22, 254, 95);
      case 'rare':
        return const Color.fromARGB(255, 0, 175, 194);
      case 'epic':
        return const Color.fromARGB(255, 103, 0, 114);
      case 'legendary':
        return const Color.fromARGB(226, 227, 148, 0);
      case 'mythical':
        return Colors.redAccent.shade400;
      default:
        return const Color(0xFFDAA520);
    }
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'common':
        return Colors.grey;
      case 'uncommon':
        return Colors.green;
      case 'rare':
        return Colors.blue;
      case 'epic':
        return Colors.purple;
      case 'legendary':
        return Colors.orange;
      case 'mythical':
        return Colors.red;
      default:
        return Colors.white;
    }
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    final weather = WeatherService().getCurrentWeather(widget.biomeName);
    return Scaffold(
      backgroundColor: _biomeBaseColor,
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
            // Joystick
            _buildJoystick(),
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

                _cameraX = _cameraX.clamp(
                  0.0,
                  max(0.0, mapWidth * tileSize - _viewSize.width),
                );
                _cameraY = _cameraY.clamp(
                  0.0,
                  max(0.0, mapHeight * tileSize - _viewSize.height),
                );
              });
            }
          },
          child: ClipRect(
            child: Transform.translate(
              offset: Offset(-_cameraX, -_cameraY),
              child: CustomPaint(
                size: Size(mapWidth * tileSize, mapHeight * tileSize),
                painter: _BiomeMapPainter(
                  mapData: _mapData,
                  playerX: _playerX,
                  playerY: _playerY,
                  playerBobOffset: _playerBobAnim.value,
                  tileSize: tileSize,
                  playerImage: _playerImage,
                  playerDirection: _playerDirection,
                  walkFrame: _walkFrame,
                  playerSprites: _playerSprites,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildJoystick() {
    return Positioned(
      bottom: 40,
      left: 40,
      child: GestureDetector(
        onPanUpdate: (details) {
          final radius = 60.0;
          final localPos = details.localPosition - const Offset(60, 60);
          final dist = localPos.distance;
          final normalized = dist > radius
              ? localPos / dist * radius
              : localPos;

          setState(() {
            _isPanning = false;
            _joystickOffset = normalized;
            _velX = normalized.dx / radius;
            _velY = normalized.dy / radius;
          });
        },
        onPanEnd: (_) {
          setState(() {
            _joystickOffset = Offset.zero;
            _velX = 0;
            _velY = 0;
          });
        },
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black26,
            shape: BoxShape.circle,
            border: Border.all(
              color: _biomeHighlightColor.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Transform.translate(
                  offset: _joystickOffset,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _biomeHighlightColor.withOpacity(0.8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.drag_handle, color: _biomeDarkColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaminaBar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, animation, __) =>
                PhoneScreen(initialBiome: widget.biomeName),
            transitionsBuilder: (_, animation, __, child) {
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

  Widget _buildEncounterOverlay() {
    final encounter = _currentEncounter!;
    final organism = encounter.organism;
    final bool isNameVisible =
        _currentUser.discoveredOrganisms.contains(organism.name) ||
        _isNameRevealed;

    return AnimatedBuilder(
      animation: _encounterSlideController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(
            0.6 * _encounterSlideController.value,
          ),
          child: SlideTransition(
            position: _encounterSlideAnim,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: _biomeDarkColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _rarityHighlightColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: _rarityHighlightColor.withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Text(
                      '⚠ WILD ENCOUNTER!',
                      style: TextStyle(
                        color: _rarityHighlightColor,
                        fontFamily: 'PressStart2P',
                        fontSize: 14,
                        shadows: [
                          Shadow(
                            color: _rarityHighlightColor.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Rarity badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _rarityHighlightColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        organism.rarity.toUpperCase(),
                        style: TextStyle(
                          color: _getRarityColor(organism.rarity),
                          fontFamily: 'PressStart2P',
                          fontSize: 12,
                          shadows: [
                            Shadow(
                              color: _getRarityHighlightColor(
                                organism.rarity,
                              ).withOpacity(0.6),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Sprite
                    SizedBox(
                      height: 140,
                      child: isNameVisible
                          ? buildSilhouetteSprite(
                              imageUrl: organism.sprite,
                              height: 140,
                              fit: BoxFit.contain,
                            )
                          : buildSilhouetteSprite(
                              imageUrl: organism.sprite,
                              silhouetteColor: Colors.black.withOpacity(0.8),
                              outlineColor: _rarityHighlightColor,
                              outlineWidth: 1.5,
                              height: 140,
                              fit: BoxFit.contain,
                            ),
                    ),
                    const SizedBox(height: 10),
                    // Name
                    if (isNameVisible)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _biomeBaseColor.withOpacity(0.6),
                              _biomeDarkColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _biomeHighlightColor,
                            width: 2,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            organism.name.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'PressStart2P',
                              fontSize: 16,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(2, 2),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        '???',
                        style: TextStyle(
                          color: _biomeHighlightColor,
                          fontFamily: 'PressStart2P',
                          fontSize: 20,
                        ),
                      ),
                    const SizedBox(height: 18),
                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (!isNameVisible)
                          _actionBtn(
                            'IDENTIFY',
                            Icons.search,
                            Colors.tealAccent,
                            () => _revealName(organism),
                          ),
                        if (!isNameVisible) const SizedBox(width: 10),
                        _actionBtn(
                          'FIGHT',
                          Icons.sports_mma,
                          Colors.redAccent,
                          () => _onFight(organism),
                        ),
                        const SizedBox(width: 10),
                        _actionBtn(
                          'RUN',
                          Icons.directions_run,
                          Colors.orangeAccent,
                          _dismissEncounter,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontFamily: 'PressStart2P',
                fontSize: 7,
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
  final double playerBobOffset;
  final double tileSize;
  final ui.Image? playerImage;
  final String playerDirection;
  final int walkFrame;
  final Map<String, List<ui.Image>> playerSprites;

  _BiomeMapPainter({
    required this.mapData,
    required this.playerX,
    required this.playerY,
    required this.playerBobOffset,
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
    final rect = Rect.fromLTWH(c * tileSize, r * tileSize, tileSize, tileSize);
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
        paint.color = Colors.green.withOpacity(0.5);
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
    final px = playerX + tileSize / 2;
    final py = playerY + tileSize / 2 + playerBobOffset;

    ui.Image? img;

    if (playerSprites.containsKey(playerDirection) &&
        playerSprites[playerDirection]!.isNotEmpty) {
      final frames = playerSprites[playerDirection]!;
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
        oldDelegate.playerBobOffset != playerBobOffset ||
        oldDelegate.walkFrame != walkFrame ||
        oldDelegate.playerDirection != playerDirection;
  }
}
