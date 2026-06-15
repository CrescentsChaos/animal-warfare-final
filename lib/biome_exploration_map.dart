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
import 'package:animal_warfare/game/battle_manager.dart';
import 'package:animal_warfare/explore_screen.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/captured_organism.dart';
import 'package:animal_warfare/battle_screen.dart';
import 'package:animal_warfare/local_auth_service.dart';
import 'package:animal_warfare/models/saved_map_state.dart';
import 'user_state.dart';
import 'services/audio_service.dart';
import 'package:animal_warfare/services/weather_service.dart';
import 'package:animal_warfare/models/weather.dart';
import 'package:animal_warfare/widgets/weather_overlay.dart';
import 'package:animal_warfare/game/time_service.dart';
import 'package:animal_warfare/widgets/game_clock_widget.dart';
import 'package:animal_warfare/shop_screen.dart';
import 'package:animal_warfare/phone_screen.dart';
import 'package:animal_warfare/theme.dart';
import 'package:animal_warfare/animal_box_screen.dart';
import 'package:animal_warfare/anidex_screen.dart';
import 'package:animal_warfare/crafting_screen.dart';
import 'package:animal_warfare/game/overworld_sprite.dart';
import 'package:animal_warfare/game/overworld_npc.dart';
import 'package:animal_warfare/game/npc_team_loader.dart';
import 'package:animal_warfare/game/archetype_teams.dart';
import 'package:animal_warfare/models/quest.dart';
import 'package:animal_warfare/game/trainer_data.dart';
import 'package:animal_warfare/widgets/exploration_event_dialog.dart';
import 'package:animal_warfare/widgets/fishing_minigame_overlay.dart';

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
    this.initialDirection,
  });

  final String? initialDirection;

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
  late Ticker _ticker;

  // ── Camera ──
  double _cameraX = 0;
  double _cameraY = 0;
  Size _viewSize = Size.zero;
  final GlobalKey _mapBoundaryKey = GlobalKey();
  bool _isPanning = false;
  double _zoomScale = 2.0; //default camera zoom

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
  bool _cameraSnapped = true;

  // ── Interaction ──
  String? _bubbleText;
  Timer? _bubbleTimer;
  Offset? _interactionWorldPos;
  OverworldNPC? _interactionNPC;

  // ── Swimming ──
  bool _isSwimming = false;
  double _swimBobTime = 0;
  double _jumpTime = 0;
  double _jumpOffset = 0;
  Duration _lastElapsedTime = Duration.zero;
  String? _confirmationTitle;
  VoidCallback? _onConfirm;
  bool _showSleepMenu = false;
  double _sleepFadeOpacity = 0.0;
  bool _isSleeping = false;
  VoidCallback? _onBubbleDismiss;
  List<String> _dialogueQueue = [];
  int _dialogueIndex = 0;

  // ── Overworld Pheno Sprites ──
  final List<OverworldSprite> _overworldSprites = [];
  final List<OverworldNPC> _gameNPCs = [];
  Timer? _phenoSpawnTimer;
  double _phenoTickAccumulator = 0;
  late UserState _userState;
  double _regrowthCheckAccumulator = 0;

  // ── Firefly Effect ──
  final List<_FireflyParticle> _fireflies = [];
  final List<_GrassParticle> _grassParticles = [];
  double _grassAnimTime = 0;
  final List<Offset> _waterEdgeTiles = [];
  double _loaderFadeOpacity = 0.0;
  bool _isMapLoading = false;
  bool _isTransitioning = false;
  late String _currentBiomeName;
  late String _currentMapId;
  late String _currentMapName;
  bool _isIndoor = false;

  // ── Headbutt / Tree Shake ──
  /// Maps tile position "row:col" to remaining shake time (seconds).
  final Map<String, double> _tileShakeTimers = {};

  /// Maps tile position "row:col" to current horizontal shake offset (pixels).
  final Map<String, double> _tileShakeOffsets = {};

  // ── Survival Mechanics ──
  final List<Point<int>> _deployedCampfires = [];

  // ── Shared Random ──
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen for unstuck requests from the phone app
    _userState = Provider.of<UserState>(context, listen: false);
    _userState.addListener(_onUserStateChange);

    // Initial map load
    BiomeMapData initialData;
    debugPrint('EXPLORATION: Loading map: ${widget.biomeName}');
    if (widget.customMapData != null) {
      initialData = widget.customMapData!;
    } else {
      final config = BiomeDataManager.getBiome(widget.biomeName);
      if (config.layout != null) {
        initialData = MapStringParser.parse(
          config.layout!,
          config: config,
          spawn: config.spawnPoint,
          npcs: config.npcs,
          name: config.name,
          biomeId: config.biomeId,
          transitions: config.transitions,
        );
      } else {
        initialData = BiomeMapGenerator.generate(
          width: 80,
          height: 80,
          config: config,
        );
      }
    }

    _initializeMapData(initialData);

    // Play biome music
    final fileName = widget.biomeName.toLowerCase().replaceAll(' ', '_');
    AudioService.instance.playMusic('audio/${fileName}_theme.mp3');

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

  void _onUserStateChange() {
    if (_userState.unstuckRequested) {
      _handleUnstuck();
      _userState.consumeUnstuckRequest();
    }
  }

  void _handleUnstuck() {
    setState(() {
      _playerX = _mapData.spawnPoint.x * tileSize;
      _playerY = (_mapData.height - 1 - _mapData.spawnPoint.y) * tileSize;
      _targetX = _playerX;
      _targetY = _playerY;
      _isMovingToTarget = false;
      _velX = 0;
      _velY = 0;
      _activeDirections.clear();
      _scrollToPlayer(insideSetState: true);
    });

    _showInteractionBubble('Sent to spawn point.');
  }

  void _initializeMapData(BiomeMapData data, {bool fromTeleport = false}) {
    _mapData = data;
    _currentMapId = data.config.id;
    _currentMapName = data.name ?? data.config.name;
    _currentBiomeName = data.biomeId ?? data.config.id;
    _isIndoor = data.isIndoor;

    debugPrint(
      'EXPLORATION: Initializing map $_currentMapId (${data.width}x${data.height}) with ${data.npcs?.length ?? 0} NPCs',
    );
    mapWidth = _mapData.width;
    mapHeight = _mapData.height;

    _playerX = _mapData.spawnPoint.x * tileSize;
    _playerY = (_mapData.height - 1 - _mapData.spawnPoint.y) * tileSize;
    _targetX = _playerX;
    _targetY = _playerY;
    _velX = 0;
    _velY = 0;
    _walkFrame = 0;
    _isMovingToTarget = false;
    _overworldSprites.clear();

    _biomeBaseColor = _getBiomeBaseColor(_currentMapName);
    _biomeDarkColor = _getDarkerColor(_biomeBaseColor);
    _biomeHighlightColor = _getBiomeHighlightColor(_currentMapName);

    // Load saved state if available, unless we are teleporting to a specific target
    if (!fromTeleport) {
      _loadSavedState();
    }

    // Initialize NPCs from map data
    _gameNPCs.clear();
    if (_mapData.npcs != null) {
      for (final npcData in _mapData.npcs!) {
        // Skip blocker NPCs whose requiredFlag is already satisfied
        if (npcData.scriptType == 'blocker' &&
            npcData.requiredFlag.isNotEmpty &&
            _userState.hasFlag(npcData.requiredFlag)) {
          continue;
        }
        // Skip trainers that disappear on defeat
        if (npcData.disappearsOnDefeat &&
            _userState.isTrainerDefeated(npcData.id)) {
          continue;
        }
        // Skip event NPCs whose event is already completed
        if ((npcData.scriptType == 'event_trainer' ||
                npcData.scriptType == 'event_npc') &&
            npcData.setsFlag.isNotEmpty &&
            _userState.hasFlag(npcData.setsFlag)) {
          continue;
        }
        final npc = OverworldNPC(
          data: npcData.copyWith(y: _mapData.height - 1 - npcData.y),
        );
        // Restore defeated state from persistent event flags
        if ((npcData.scriptType == 'trainer' ||
                npcData.scriptType == 'rival' ||
                npcData.scriptType == 'major_trainer' ||
                npcData.scriptType == 'evil_team' ||
                npcData.scriptType == 'event_trainer') &&
            _userState.isTrainerDefeated(npcData.id)) {
          npc.isDefeated = true;
          npc.hasTriggeredBattle = true;
        }
        _gameNPCs.add(npc);
      }
    }

    // Initialize firefly spawn points
    _initializeFireflyPoints();

    // Apply cut grass states
    if (_mapData.overlayGrid != null) {
      final userState = _userState;
      final cutTiles = userState.currentUser?.eventFlags.cutGrassTiles ?? {};
      final mapId = _currentMapId;

      for (int r = 0; r < _mapData.height; r++) {
        for (int c = 0; c < _mapData.width; c++) {
          final key = '$mapId:$r:$c';
          if (cutTiles.containsKey(key)) {
            // Replace tall grass with cutdown_grass, ensuring no duplicates
            _mapData.overlayGrid![r][c].removeWhere((t) {
              final def = BiomeDataManager.allTiles[t.tileId];
              return def?.category == TileCategory.tallGrass ||
                  t.tileId == 'cutdown_grass';
            });
            _mapData.overlayGrid![r][c].add(
              MapTile(tileId: 'cutdown_grass', config: _mapData.config),
            );
          }
        }
      }
    }
  }

  void _initializeFireflyPoints() {
    if (widget.biomeName.toLowerCase() != 'swamp') return;
    if (_isIndoor) return; // No fireflies indoors

    _waterEdgeTiles.clear();
    for (int r = 0; r < _mapData.height; r++) {
      for (int c = 0; c < _mapData.width; c++) {
        final tile = _mapData.grid[r][c];
        final overlays = _mapData.overlayGrid?[r][c];

        bool isLand =
            tile.category == TileCategory.ground ||
            tile.category == TileCategory.path ||
            (overlays?.any((t) => t.category == TileCategory.tallGrass) ??
                false);

        if (isLand) {
          // Check neighbors for water
          bool nearWater = false;
          for (int dr = -1; dr <= 1; dr++) {
            for (int dc = -1; dc <= 1; dc++) {
              if (dr == 0 && dc == 0) continue;
              int nr = r + dr;
              int nc = c + dc;
              if (nr >= 0 &&
                  nr < _mapData.height &&
                  nc >= 0 &&
                  nc < _mapData.width) {
                final nTile = _mapData.grid[nr][nc];
                final nOverlays = _mapData.overlayGrid?[nr][nc];
                if (nTile.category == TileCategory.water ||
                    (nOverlays?.any((t) => t.category == TileCategory.water) ??
                        false)) {
                  nearWater = true;
                  break;
                }
              }
            }
            if (nearWater) break;
          }
          if (nearWater) {
            _waterEdgeTiles.add(Offset(c.toDouble(), r.toDouble()));
          }
        }
      }
    }

    // Spawn initial fireflies
    final random = Random();
    if (_waterEdgeTiles.isNotEmpty) {
      for (int i = 0; i < 40; i++) {
        final baseTile =
            _waterEdgeTiles[random.nextInt(_waterEdgeTiles.length)];
        _fireflies.add(
          _FireflyParticle(
            x: baseTile.dx * tileSize + random.nextDouble() * tileSize,
            y: baseTile.dy * tileSize + random.nextDouble() * tileSize,
            phase: random.nextDouble() * pi * 2,
            speed: 0.2 + random.nextDouble() * 0.3,
            driftDir: random.nextDouble() * pi * 2,
          ),
        );
      }
    }
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
      // Removed early return to allow world simulation (like trainer approach)
      // to continue while player is frozen.
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

    // ── Grass Regrowth Check (every 5 seconds) ──
    _regrowthCheckAccumulator += dt;
    if (_regrowthCheckAccumulator >= 5.0) {
      _regrowthCheckAccumulator = 0;
      final userState = _userState;
      final initialCutCount =
          userState.currentUser?.eventFlags.cutGrassTiles.length ?? 0;

      userState.clearExpiredGrass().then((_) {
        // If some grass regrew, we might need to refresh the map view
        final newCutCount =
            userState.currentUser?.eventFlags.cutGrassTiles.length ?? 0;
        if (newCutCount != initialCutCount) {
          // Re-sync the local map data for the current map
          // This is a bit expensive but ensures consistency
          _initializeMapData(_mapData, fromTeleport: true);
          setState(() {});
        }
      });
    }

    // ── Overworld sprite AI ──
    _phenoTickAccumulator += dt;

    // Apply campfire warmth buff if near a campfire
    if (_deployedCampfires.isNotEmpty) {
      final pr = (_playerY / tileSize).floor();
      final pc = (_playerX / tileSize).floor();
      bool nearCampfire = false;
      for (final cf in _deployedCampfires) {
        // Range 3 tiles
        if ((cf.x - pc).abs() <= 3 && (cf.y - pr).abs() <= 3) {
          nearCampfire = true;
          break;
        }
      }
      if (nearCampfire) {
        // Campfires restore stamina and hunger slightly if nearby, prevents freezing
        _userState.addStamina(dt * 2.0); // Recover 2 stamina per second
        // Freezing prevention is done implicitly by adding survival effects or restoring stamina faster than it drains
      }
    }
    if (_phenoTickAccumulator >= 0.05) {
      // ~20fps for AI
      bool anyChanged = false;

      // Only tick sprites if no encounter is active
      if (!_encounterActive) {
        for (final sprite in _overworldSprites) {
          // Feed player position for nature affinity logic
          sprite.playerPixelX = _playerX;
          sprite.playerPixelY = _playerY;

          if (sprite.tick(
            _phenoTickAccumulator,
            _mapData,
            tileSize,
            otherSprites: _overworldSprites,
            pTargetX: _isMovingToTarget ? _targetX : _playerX,
            pTargetY: _isMovingToTarget ? _targetY : _playerY,
          )) {
            anyChanged = true;
          }

          // Handle ambient cries
          if (sprite.shouldPlayCry) {
            sprite.shouldPlayCry = false;
            // Only play if within hearing range (e.g. 15 tiles)
            final dx = sprite.pixelX - _playerX;
            final dy = sprite.pixelY - _playerY;
            final distSq = dx * dx + dy * dy;
            final maxDist = 15 * tileSize;
            if (distSq < maxDist * maxDist) {
              AudioService.instance.playOrganismCry(sprite.organism.cry);
            }
          }
        }

        // ▶ Player-priority: If any sprite's TARGET tile is where the player
        // currently stands, snap it back to its origin tile immediately.
        final int playerRow = ((_playerY + tileSize / 2) / tileSize).floor();
        final int playerCol = ((_playerX + tileSize / 2) / tileSize).floor();
        for (final sprite in _overworldSprites) {
          if (sprite.isMoving &&
              sprite.targetRow == playerRow &&
              sprite.targetCol == playerCol) {
            // Snap it back — cancel move and return to current row/col
            sprite.pixelX = sprite.col * tileSize;
            sprite.pixelY = sprite.row * tileSize;
            sprite.targetPixelX = sprite.pixelX;
            sprite.targetPixelY = sprite.pixelY;
            sprite.isMoving = false;
            sprite.walkFrame = 0;
            sprite.attackCalculated = false;
            sprite.attackDecision = false;
          }
        }

        // Remove expired sprites
        _overworldSprites.removeWhere((s) {
          if (s.isExpired) return true;
          // Spawn grass particles if sprite is moving in tall grass
          if (s.isMoving) {
            final int sr = ((s.pixelY + tileSize / 2) / tileSize).floor();
            final int sc = ((s.pixelX + tileSize / 2) / tileSize).floor();
            if (sr >= 0 &&
                sr < _mapData.height &&
                sc >= 0 &&
                sc < _mapData.width &&
                (_mapData.overlayGrid?[sr][sc].any(
                      (t) => t.category == TileCategory.tallGrass,
                    ) ??
                    false)) {
              if (_rng.nextDouble() < 0.2) {
                _spawnGrassParticles(
                  s.pixelX + tileSize / 2,
                  s.pixelY + tileSize,
                );
              }
            }
          }
          return false;
        });
      }

      final currentTickDt = _phenoTickAccumulator;
      _phenoTickAccumulator = 0;
      if ((anyChanged || _encounterActive) && mounted) setState(() {});

      // ── NPC AI ──
      final walkGrid = List.generate(
        _mapData.height,
        (r) => List.generate(_mapData.width, (c) {
          // Point check - tiles only
          return _canWalkAt(c * tileSize, r * tileSize, ignoreEntities: true);
        }),
      );

      final totalTime = elapsed.inMilliseconds / 1000.0;
      final int pR = ((_playerY + tileSize / 2) / tileSize).floor();
      final int pC = ((_playerX + tileSize / 2) / tileSize).floor();

      for (final npc in _gameNPCs) {
        // If an encounter is active, ONLY tick the approaching NPC
        if (_encounterActive && npc != _approachingNPC) continue;

        npc.tick(
          currentTickDt,
          totalTime,
          walkGrid,
          playerRow: pR,
          playerCol: pC,
          otherNPCs: _gameNPCs,
        );
      }

      // Check collision constantly
      if (!_encounterActive) {
        _checkPhenoCollision();
      }

      // ── NPC Vision Check (Trainer Battle Trigger) ──
      if (!_encounterActive) {
        _checkNPCVision(pR, pC);
      }

      // ── NPC Approach Completion ──
      if (_approachingNPC != null &&
          !_approachingNPC!.isApproaching &&
          !_approachingNPC!.isMoving &&
          !_approachingNPC!.hasTriggeredBattle) {
        final npc = _approachingNPC!;
        npc.hasTriggeredBattle = true;
        _startTrainerBattle(npc);
      }
    }

    // ── Update Grass Particles ──
    _grassAnimTime += dt;
    for (int i = _grassParticles.length - 1; i >= 0; i--) {
      final p = _grassParticles[i];
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.life -= dt * 1.5;
      p.angle += p.vx * dt * 0.1;
      if (p.life <= 0) {
        _grassParticles.removeAt(i);
      }
    }

    // ── Update Tree Shake Offsets ──
    final keysToRemove = <String>[];
    for (final key in _tileShakeTimers.keys.toList()) {
      _tileShakeTimers[key] = _tileShakeTimers[key]! - dt;
      if (_tileShakeTimers[key]! <= 0) {
        keysToRemove.add(key);
        _tileShakeOffsets.remove(key);
      } else {
        // Oscillate: sin wave that decays over the shake duration
        final remaining = _tileShakeTimers[key]!;
        _tileShakeOffsets[key] = sin(remaining * 30) * remaining * 4.0;
      }
    }
    for (final key in keysToRemove) {
      _tileShakeTimers.remove(key);
    }

    // ── Update Fireflies ──
    if (widget.biomeName.toLowerCase() == 'swamp') {
      final hour = TimeService().currentGameTime.hour;
      final bool isNight = hour >= 21 || hour < 6;
      if (isNight) {
        for (final f in _fireflies) {
          f.x += cos(f.driftDir) * f.speed;
          f.y += sin(f.driftDir) * f.speed;
          f.driftDir += (_rng.nextDouble() - 0.5) * 0.1;
          f.phase += dt * 2;
        }
      }
    }

    if (mounted) setState(() {});

    // Player controls (only if not in an encounter, not in dialogue, and not transitioning)
    if (!_encounterActive && _bubbleText == null && !_isTransitioning) {
      if (_isMovingToTarget) {
        _walkAnimAccumulator += (_isRunning ? 4.4 : 2.2) * 0.05;
        _moveTowardsTarget();

        // Spawn grass particles if moving through tall grass
        final int pr = ((_playerY + tileSize / 2) / tileSize).floor();
        final int pc = ((_playerX + tileSize / 2) / tileSize).floor();
        if (pr >= 0 &&
            pr < _mapData.height &&
            pc >= 0 &&
            pc < _mapData.width &&
            (_mapData.overlayGrid?[pr][pc].any(
                  (t) => t.category == TileCategory.tallGrass,
                ) ??
                false)) {
          if (_rng.nextDouble() < 0.3) {
            _spawnGrassParticles(_playerX + tileSize / 2, _playerY + tileSize);
          }
        }

        // Camera update AFTER movement — this frame's position, zero lag
        _updateCamera();
        return;
      }

      // Advance animation if directions are held
      if (_activeDirections.isNotEmpty) {
        final double speed = _isRunning ? 3.04 : 1.52;
        _walkAnimAccumulator += speed;
        if (_walkAnimAccumulator >= tileSize / 2) {
          _walkAnimAccumulator -= tileSize / 2;
          _walkFrame = (_walkFrame == 1) ? 2 : 1;
        }
        setState(() {});
      }

      // Handle movement initiation
      if (_activeDirections.isNotEmpty || _queuedDirection != null) {
        final dir = _queuedDirection ?? _activeDirections.last;
        _queuedDirection = null;

        // Tap-to-turn: face direction first
        if (dir != _playerDirection) {
          _directionHoldStart = elapsed;
          setState(() {
            _playerDirection = dir;
            _walkFrame = 0;
          });
          _updateCamera();
          return;
        }

        if (_directionHoldStart == null) {
          _directionHoldStart = elapsed;
          _initiateMove(dir);
        } else {
          final holdTime = elapsed - _directionHoldStart!;
          if (holdTime.inMilliseconds > 100) {
            _initiateMove(dir);
          }
        }
      } else {
        _directionHoldStart = null;
        if (!_isMovingToTarget && _walkFrame != 0) {
          setState(() {
            _walkFrame = 0;
          });
        }
      }
    }

    _updateCamera();

    // ── Encounter Alert Check (delay) ──
    for (final sprite in _overworldSprites) {
      if (sprite.isAlerted && sprite.alertTimer <= 0) {
        // Alert animation finished, start encounter
        sprite.isAlerted = false;
        AudioService.instance.playOrganismCry(sprite.organism.cry);
        setState(() => _encounterActive = true);

        final pr = (_playerY / tileSize).floor().clamp(0, _mapData.height - 1);
        final pc = (_playerX / tileSize).floor().clamp(0, _mapData.width - 1);
        final tileId = _mapData.grid[pr][pc].tileId;
        _onFight(sprite.organism, tileId);

        // Clean up: remove the sprite from map
        _overworldSprites.remove(sprite);
        break; // Only start one battle
      }
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
      final int currentR = (_playerY / tileSize).floor();
      final int currentC = (_playerX / tileSize).floor();
      final int targetR = (nextY / tileSize).floor();
      final int targetC = (nextX / tileSize).floor();

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
    } else if (direction == 'down') {
      // Special: Jump over oneway ledges if moving down
      final int targetR = (nextY / tileSize).floor();
      final int targetC = (nextX / tileSize).floor();
      if (targetR >= 0 &&
          targetR < _mapData.height &&
          targetC >= 0 &&
          targetC < _mapData.width) {
        final tile = _mapData.grid[targetR][targetC];
        final overlays = _mapData.overlayGrid?[targetR][targetC];
        final bool isOneWay =
            tile.category == TileCategory.oneway ||
            (overlays?.any((t) => t.category == TileCategory.oneway) ?? false);

        if (isOneWay) {
          final double jumpX = nextX;
          final double jumpY = nextY + tileSize;
          if (_canWalkAt(jumpX, jumpY)) {
            setState(() {
              _isMovingToTarget = true;
              _targetX = jumpX;
              _targetY = jumpY;
              _playerDirection = direction;
              _velX = 0;
              _velY = vy; // Move at normal speed but over 2 tiles
              _jumpTime = 0.4; // Slightly longer jump
            });
            return;
          }
        }
      }

      setState(() {
        _playerDirection = direction;
        _velX = 0;
        _velY = 0;
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
        ? 0.76 // Half speed for swimming
        : (_isRunning ? 4.4 : 2.2); // Px per frame
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
      });

      // Check encounter and count step exactly on tile
      _checkStepEncounter(
        ((_playerY + tileSize / 2) / tileSize).floor(),
        ((_playerX + tileSize / 2) / tileSize).floor(),
      );
      _checkTileEvents(
        ((_playerY + tileSize / 2) / tileSize).floor(),
        ((_playerX + tileSize / 2) / tileSize).floor(),
      );

      // Check collision with overworld sprites
      _checkPhenoCollision();
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
      });
    }
  }

  // ── Collision ──
  bool _canWalkAt(
    double x,
    double y, {
    bool? isSwimmingOverride,
    bool ignoreEntities = false,
  }) {
    final bool isSwimming = isSwimmingOverride ?? _isSwimming;
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
      final bool isFloating =
          baseTile.category == TileCategory.floating ||
          (overlayTile?.any((t) => t.category == TileCategory.floating) ??
              false);
      final bool isSolid =
          baseTile.category == TileCategory.solid ||
          (overlayTile?.any((t) => t.category == TileCategory.solid) ?? false);
      final bool isTeleporter =
          baseTile.category == TileCategory.teleporter ||
          (overlayTile?.any((t) => t.category == TileCategory.teleporter) ??
              false);

      bool hasTransition = false;
      final transitions = _mapData.transitions ?? _mapData.config.transitions;
      if (transitions != null) {
        for (final t in transitions) {
          if (t.x == c && (_mapData.height - 1 - t.y) == r) {
            hasTransition = true;
            break;
          }
        }
      }

      if (isTeleporter || hasTransition) {
        continue; // Teleporters are always walkable
      }
      if (isSolid) return false;

      if (isSwimming) {
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

      if (ignoreEntities) continue;

      // ── Overworld Sprite Hitbox Check ──
      // Only block on the sprite's CURRENT pixel tile, not its target.
      // This lets the player immediately walk onto a tile the animal is leaving.
      for (final sprite in _overworldSprites) {
        final int sr = (sprite.pixelY / tileSize).floor();
        final int sc = (sprite.pixelX / tileSize).floor();
        if (sr == r && sc == c) {
          return false; // Blocked by animal
        }
      }

      // ── NPC Hitbox Check ──
      for (final npc in _gameNPCs) {
        if (npc.gridRow == r && npc.gridCol == c) {
          return false; // Blocked by NPC
        }
        if (npc.isMoving && npc.targetRow == r && npc.targetCol == c) {
          return false; // Tile is reserved by moving NPC
        }
      }
    }
    return true;
  }

  void _checkStepEncounter(int row, int col) {
    if (_encounterActive) return;

    if (_handleTeleport(row, col)) {
      return;
    }

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

      final roll = _rng.nextDouble();
      if (roll < rate) {
        if (_rng.nextDouble() < 0.15) {
          // 15% chance of the encounter being an event instead
          _triggerChoiceEvent();
          return;
        }

        setState(() {
          _encounterActive = true;
          _velX = 0;
          _velY = 0;
          _isMovingToTarget = false;
          _activeDirections.clear();
          _playerX = col * tileSize;
          _playerY = row * tileSize;
          _walkFrame = 0;
          _walkAnimAccumulator = 0.0;
        });

        _triggerEncounter(activeTile);
      }
    }
  }

  void _triggerChoiceEvent() async {
    setState(() {
      _encounterActive = true;
      _velX = 0;
      _velY = 0;
      _isMovingToTarget = false;
      _walkFrame = 0;
    });

    final eventType = _rng.nextInt(3);
    String title = '';
    String description = '';
    Map<String, EventOutcome> choices = {};

    if (eventType == 0) {
      title = 'Suspicious Rock';
      description = 'You spot a loose rock that seems slightly out of place.';
      choices = {
        'Flip it over': EventOutcome.loot,
        'Leave it be': EventOutcome.nothing,
      };
    } else if (eventType == 1) {
      title = 'Rustling Bushes';
      description =
          'You hear a strange rustling sound coming from nearby bushes.';
      choices = {
        'Investigate': EventOutcome.loot,
        'Keep walking': EventOutcome.nothing,
      };
    } else {
      title = 'Glint in the Dirt';
      description = 'Something shiny catches your eye half-buried in the dirt.';
      choices = {
        'Dig it out': EventOutcome.loot,
        'Not worth it': EventOutcome.nothing,
      };
    }

    final choice = await showDialog<EventOutcome>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ExplorationEventDialog(
        title: title,
        description: description,
        options: choices,
      ),
    );

    if (choice == EventOutcome.loot) {
      final outcome = _rng.nextDouble();
      if (outcome < 0.3) {
        final items = [
          'meat_bait',
          'plant_bait',
          'universal_bait',
          'capture_net',
          'talisman_fragment',
        ];
        if (_rng.nextDouble() < 0.1) items.add('old_rod');
        final item = items[_rng.nextInt(items.length)];
        _userState.addLoot(item, 1);
        _showInteractionBubble('You found a $item!');
      } else if (outcome < 0.6) {
        _showInteractionBubble('Something jumped out at you!');
        await Future.delayed(const Duration(seconds: 1));

        final hour = TimeService().currentGameTime.hour;
        String timeOfDay = 'day';
        if (hour >= 18 && hour < 21) {
          timeOfDay = 'evening';
        } else if (hour >= 21 || hour < 6)
          timeOfDay = 'night';

        final encounter = getWeightedRandomOrganism(
          _currentBiomeName,
          widget.allOrganisms,
          accountLevel: _userState.currentUser?.accountLevel ?? 1,
          inventory: _userState.currentUser?.inventory ?? {},
          teamMoveNames:
              _userState.currentUser?.teamOrganisms
                  .expand((o) => o.selectedMoveNames)
                  .toList() ??
              <String>[],
          currentTimeOfDay: timeOfDay,
          encounterType: 'tallgrass',
        );
        if (encounter != null) {
          _onFight(encounter.organism, 'grass');
          return;
        }
      } else {
        _showInteractionBubble('It was nothing but dirt.');
      }
    }

    setState(() {
      _encounterActive = false;
    });
  }

  bool _handleTeleport(int row, int col) {
    if (_isTransitioning) return false;
    final transitions = _mapData.transitions ?? _mapData.config.transitions;
    if (transitions == null) return false;
    for (final t in transitions) {
      if (t.x == col && (_mapData.height - 1 - t.y) == row) {
        _executeTransition(t);
        return true;
      }
    }
    return false;
  }

  Future<void> _executeTransition(MapTransition t) async {
    if (_isTransitioning) return;
    _isTransitioning = true;
    try {
      // Determine target config
      late BiomeConfig targetConfig;
      targetConfig = BiomeDataManager.getBiome(t.targetMap);

      // Parse target map data with specific spawn coordinates from transition
      final targetMapData = MapStringParser.parse(
        targetConfig.layout ?? {'base': []},
        config: targetConfig,
        spawn: Point<int>(t.targetX, t.targetY),
        npcs: targetConfig.npcs,
        name: targetConfig.name,
        biomeId: targetConfig.biomeId,
        transitions: targetConfig.transitions,
      );

      setState(() {
        _isMapLoading = true;
        _loaderFadeOpacity = 1.0;
      });

      // Wait for fade out
      await Future.delayed(const Duration(milliseconds: 400));
      await _saveCurrentState();
      if (!mounted) return;

      // Preserve current direction for the next map
      final entryDirection = _playerDirection;
      final String oldBiomeId = _currentBiomeName;

      // Initialize new map data in-place
      setState(() {
        _initializeMapData(targetMapData, fromTeleport: true);

        // Override direction if transition specifies it, otherwise keep current
        _playerDirection = entryDirection;

        // Update music/audio if biome changed
        final newBiomeId = targetConfig.biomeId ?? targetConfig.id;
        if (newBiomeId != oldBiomeId || !AudioService.instance.isInitialized) {
          final fileName = newBiomeId.toLowerCase().replaceAll(' ', '_');
          AudioService.instance.playMusic('audio/${fileName}_theme.mp3');
        }

        // Snap camera
        _scrollToPlayer(insideSetState: true);
        _loaderFadeOpacity = 0.0;
      });

      // Wait for fade in
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _isMapLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Map Transition Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTransitioning = false;
        });
      } else {
        _isTransitioning = false;
      }
    }
  }

  Future<void> _handleWhiteOut() async {
    if (_isTransitioning) return;
    _isTransitioning = true;

    try {
      final userState = _userState;
      final user = userState.currentUser;

      // 1. Heal team
      await userState.healFullTeam();

      // 2. Determine target map and spawn
      String targetMapId = user?.lastMedicalCenterMapId ?? 'player_house';
      int targetCol = user?.lastMedicalCenterCol ?? 3; // Col corresponds to X
      int targetRow = user?.lastMedicalCenterRow ?? 6; // Row corresponds to Y

      // If we are defaulting to player_house, we should use its defined spawn if no coordinates are saved
      if (user?.lastMedicalCenterMapId == null) {
        // player_house spawn is x=3, y=6 according to maps.json
        targetCol = 3;
        targetRow = 6;
      }

      // 3. Load target map data
      final targetConfig = BiomeDataManager.getBiome(targetMapId);
      final targetMapData = MapStringParser.parse(
        targetConfig.layout ?? {'base': []},
        config: targetConfig,
        spawn: Point<int>(targetCol, targetRow),
        npcs: targetConfig.npcs,
        name: targetConfig.name,
        biomeId: targetConfig.biomeId,
        transitions: targetConfig.transitions,
      );

      // 4. Fade out
      setState(() {
        _isMapLoading = true;
        _loaderFadeOpacity = 1.0;
      });
      await Future.delayed(const Duration(milliseconds: 400));

      // 5. Initialize and Fade in
      if (!mounted) return;
      setState(() {
        _initializeMapData(targetMapData, fromTeleport: true);
        _playerDirection = 'down'; // Reset direction

        final newBiomeId = targetConfig.biomeId ?? targetConfig.id;
        final fileName = newBiomeId.toLowerCase().replaceAll(' ', '_');
        AudioService.instance.playMusic('audio/${fileName}_theme.mp3');

        _scrollToPlayer(insideSetState: true);
        _loaderFadeOpacity = 0.0;
      });

      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) {
        setState(() {
          _isMapLoading = false;
          _isMovingToTarget = false;
          _velX = 0;
          _velY = 0;
        });

        _showInteractionBubble('You whited out and were brought to safety.');
      }
    } catch (e) {
      debugPrint('White Out Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isTransitioning = false;
        });
      } else {
        _isTransitioning = false;
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
        final path = '${basePath}_${dir}_$i.png';
        var frameImg = await BiomeDataManager.loadImage(path);

        // Fallback: if frame 0 is missing, try without the _0 suffix
        if (frameImg == null && i == 0) {
          final fallbackPath = '${basePath}_$dir.png';
          frameImg = await BiomeDataManager.loadImage(fallbackPath);
        }

        if (frameImg != null) {
          frames.add(frameImg);

          // If we found a fallback (non-numbered) image, we treat it as a single-frame animation
          if (!path.contains('_$i.png')) break;
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
    _userState.removeListener(_onUserStateChange);
    _disposeTimers();
    _saveCurrentState(); // Save state on exit
    AudioService.instance.stopAll();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _loadSavedState() {
    final saved = _userState.getMapState(_mapData.config.id);
    if (saved != null) {
      _playerX = saved.playerX;
      _playerY = saved.playerY;
      _playerDirection = saved.playerDirection;
      _isSwimming = saved.isSwimming;
    }

    if (widget.initialDirection != null) {
      _playerDirection = widget.initialDirection!;
    }
  }

  Future<void> _saveCurrentState() async {
    final userState = _userState;
    // Collect defeated NPC IDs from this session
    final defeatedIds = <String>{};
    for (final npc in _gameNPCs) {
      if (npc.isDefeated) {
        defeatedIds.add(npc.data.id);
      }
    }
    final state = SavedMapState(
      playerX: _playerX,
      playerY: _playerY,
      playerDirection: _playerDirection,
      isSwimming: _isSwimming,
      savedSprites: [],
      defeatedNpcIds: defeatedIds,
    );
    await userState.saveMapState(_mapData.config.id, state);
    // Persist the current map as the last-visited zone
    await userState.updateCurrentMapId(_mapData.config.id);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      AudioService.instance.pauseAll();
      _saveCurrentState();
    } else if (state == AppLifecycleState.resumed) {
      final fileName = widget.biomeName.toLowerCase().replaceAll(' ', '_');
      AudioService.instance.playMusic('audio/${fileName}_theme.mp3');
    }
  }

  void _scrollToPlayer({bool insideSetState = false}) {
    if (!mounted || _viewSize == Size.zero) return;
    // Compute the ideal centered position and apply directly.
    // The _onTick camera system handles all subsequent tracking automatically.
    _cameraX = (_playerX + tileSize / 2) - (_viewSize.width / (2 * _zoomScale));
    _cameraY =
        (_playerY + tileSize / 2) - (_viewSize.height / (2 * _zoomScale));

    if (!insideSetState && mounted) setState(() {});
  }

  void _triggerEncounter(MapTile activeTile) {
    final user = _userState.currentUser;
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
      _currentBiomeName,
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
      biomeId: _currentBiomeName,
    );

    if (encounter != null) {
      AudioService.instance.playOrganismCry(encounter.organism.cry);
      setState(() => _encounterActive = true);
      // Immediately start the battle (no popup)
      _onFight(encounter.organism, activeTile.tileId);
    } else {
      setState(() => _encounterActive = false);
    }
  }

  void _startFishing(int targetR, int targetC) async {
    setState(() {
      _encounterActive = true;
      _velX = 0;
      _velY = 0;
      _isMovingToTarget = false;
      _walkFrame = 0;
    });

    final user = _userState.currentUser;
    if (user == null) {
      setState(() => _encounterActive = false);
      return;
    }

    final hasMeatBait = (user.inventory['meat_bait'] ?? 0) > 0;
    final hasPlantBait = (user.inventory['plant_bait'] ?? 0) > 0;
    final hasUniversalBait = (user.inventory['universal_bait'] ?? 0) > 0;

    if (!hasMeatBait && !hasPlantBait && !hasUniversalBait) {
      _showInteractionBubble(
        'You need bait to fish! (meat_bait, plant_bait, universal_bait)',
      );
      setState(() => _encounterActive = false);
      return;
    }

    String? selectedDiet;
    final selectedBait = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E3F2A),
        title: const Text(
          'Select Bait',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'PressStart2P',
            fontSize: 14,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasMeatBait)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[900],
                ),
                onPressed: () => Navigator.of(context).pop('carnivore'),
                child: const Text(
                  'Meat Bait (Carnivores)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            if (hasPlantBait)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[900],
                ),
                onPressed: () => Navigator.of(context).pop('herbivore'),
                child: const Text(
                  'Plant Bait (Herbivores)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            if (hasUniversalBait)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[900],
                ),
                onPressed: () => Navigator.of(context).pop('omnivore'),
                child: const Text(
                  'Universal Bait (Any)',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );

    if (selectedBait == null) {
      setState(() => _encounterActive = false);
      return;
    }

    selectedDiet = selectedBait == 'omnivore' ? null : selectedBait;

    final success = await showDialog<bool>(
      context: context,
      barrierColor: Colors.transparent, // Keeps game visible underneath
      builder: (context) => const FishingMinigameOverlay(),
    );

    if (success == true) {
      _showInteractionBubble('You hooked something!');
      await Future.delayed(const Duration(seconds: 1));

      final hour = TimeService().currentGameTime.hour;
      String timeOfDay = 'day';
      if (hour >= 18 && hour < 21) {
        timeOfDay = 'evening';
      } else if (hour >= 21 || hour < 6)
        timeOfDay = 'night';

      final encounter = getWeightedRandomOrganism(
        _currentBiomeName,
        widget.allOrganisms,
        accountLevel: _userState.currentUser?.accountLevel ?? 1,
        inventory: _userState.currentUser?.inventory ?? {},
        teamMoveNames:
            _userState.currentUser?.teamOrganisms
                .expand((o) => o.selectedMoveNames)
                .toList() ??
            <String>[],
        currentTimeOfDay: timeOfDay,
        encounterType: 'Aquatic',
        targetDiet: selectedDiet,
      );

      if (encounter != null) {
        final rng = Random();
        final wildLevel =
            _mapData.minLevel +
            rng.nextInt(_mapData.maxLevel - _mapData.minLevel + 1);
        final preSpawned = CapturedOrganism.spawn(
          encounter.organism,
          level: wildLevel,
          captureLocation: _currentMapName,
        );

        final caughtSize = encounter.organism.size * preSpawned.sizeScale;
        final caughtWeight = encounter.organism.weight * preSpawned.weightScale;

        final proceed = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E3F2A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFDAA520), width: 3),
            ),
            title: const Text(
              'Great Catch!',
              style: TextStyle(
                color: Color(0xFFDAA520),
                fontFamily: 'PressStart2P',
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'A wild ${encounter.organism.name} appeared!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      children: [
                        const Icon(Icons.straighten, color: Colors.blueAccent),
                        const SizedBox(height: 4),
                        Text(
                          '${caughtSize.toStringAsFixed(2)} m',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        const Icon(
                          Icons.fitness_center,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${caughtWeight.toStringAsFixed(2)} kg',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E8B57),
                    side: const BorderSide(color: Color(0xFFDAA520), width: 2),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    'BATTLE!',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'PressStart2P',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        if (proceed == true) {
          _onFight(encounter.organism, 'water', preSpawnedFighter: preSpawned);
          return;
        }
      } else {
        _showInteractionBubble('Nothing seems to be biting this bait here...');
      }
    } else {
      _showInteractionBubble('It got away...');
    }
    setState(() => _encounterActive = false);
  }

  /// Updates camera position based on current player position.
  /// Call this AFTER movement to ensure zero-lag centering.
  void _updateCamera() {
    if (_isPanning || _viewSize == Size.zero) return;

    final double idealX =
        (_playerX + tileSize / 2) - (_viewSize.width / (2 * _zoomScale));
    final double idealY =
        (_playerY + tileSize / 2) - (_viewSize.height / (2 * _zoomScale));

    if (_cameraSnapped) {
      // Pokémon-style: always exactly centered on player
      _cameraX = idealX;
      _cameraY = idealY;
    } else {
      // Gentle lerp recovery after a manual pan
      const double lerpSpeed = 0.15;
      _cameraX += (idealX - _cameraX) * lerpSpeed;
      _cameraY += (idealY - _cameraY) * lerpSpeed;

      final double dx = idealX - _cameraX;
      final double dy = idealY - _cameraY;
      if ((dx * dx + dy * dy) < 0.25) {
        _cameraX = idealX;
        _cameraY = idealY;
        _cameraSnapped = true;
      }
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

  Future<CapturedOrganism?> _getConsciousPlayerFighter() async {
    final user = _userState.currentUser;
    if (user == null) return null;

    final aliveTeamMembers = user.teamOrganisms
        .where((o) => o.currentHealth > 0)
        .toList();
    if (aliveTeamMembers.isEmpty && user.teamOrganisms.isNotEmpty) {
      _showInteractionBubble('Your team is exhausted!');
      setState(() => _encounterActive = false);
      await Future.delayed(const Duration(seconds: 2));
      await _userState.healFullTeam();
      _handleUnstuck();
      return null;
    }

    if (aliveTeamMembers.isNotEmpty) {
      return aliveTeamMembers.first;
    } else if (user.capturedOrganisms.isNotEmpty) {
      final aliveBoxMembers = user.capturedOrganisms
          .where((o) => o.currentHealth > 0)
          .toList();
      if (aliveBoxMembers.isEmpty) {
        _showInteractionBubble('All your animals are exhausted!');
        setState(() => _encounterActive = false);
        await Future.delayed(const Duration(seconds: 2));
        await _userState.healFullTeam();
        _handleUnstuck();
        return null;
      }
      return aliveBoxMembers.first;
    } else {
      return CapturedOrganism.spawn(
        Organism.humanOrganism.copyWith(name: user.username),
        level: user.accountLevel,
      );
    }
  }

  void _onFight(
    Organism wildOrganism,
    String encounterTileId, {
    CapturedOrganism? preSpawnedFighter,
  }) async {
    _userState.discoverOrganism(wildOrganism.name);
    final user = _userState.currentUser;
    if (user == null) return;

    final playerFighter = await _getConsciousPlayerFighter();
    if (playerFighter == null) return;

    final rng = Random();
    final wildLevel =
        _mapData.minLevel +
        rng.nextInt(_mapData.maxLevel - _mapData.minLevel + 1);

    final wildFighter =
        preSpawnedFighter ??
        CapturedOrganism.spawn(
          wildOrganism,
          level: wildLevel,
          captureLocation: _currentMapName,
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
    final BattleResult? result = await Navigator.of(context).push<BattleResult>(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          playerOrganism: playerFighter,
          opponentOrganism: wildFighter,
          biomeName: _currentBiomeName,
          playerTeam: user.teamOrganisms,
          timeOfDay: timeOfDay,
          mapScreenshot: mapScreenshot,
          encounterTileId: encounterTileId,
        ),
      ),
    );
    AudioService.instance.resumeAll();

    if (mounted) {
      if (result == BattleResult.loss) {
        await _handleWhiteOut();
      }

      setState(() {
        _encounterActive = false;
      });
    }
  }

  void _checkTileEvents(int row, int col) {
    final events = _mapData.events;
    if (events == null || events.isEmpty) return;

    for (final event in events) {
      final eventRow = _mapData.height - 1 - event.y;
      if (event.x == col && eventRow == row) {
        if (event.requiredFlag != null &&
            !_userState.hasFlag(event.requiredFlag!)) {
          continue;
        }
        if (event.oneTime) {
          final eventId = 'event_${_currentMapId}_${event.x}_${event.y}';
          if (_userState.hasFlag(event.setsFlag ?? eventId)) {
            continue;
          }
        }
        _handleMapEvent(event);
        return;
      }
    }
  }

  Future<void> _handleMapEvent(MapEvent event) async {
    final eventId = 'event_${_currentMapId}_${event.x}_${event.y}';
    final flagToSet = event.setsFlag ?? eventId;
    if (event.oneTime) {
      await _userState.setFlag(flagToSet);
    }

    switch (event.type) {
      case 'rival_battle':
        if (event.dialogue != null && event.dialogue!.isNotEmpty) {
          _showDialogue(event.dialogue!);
        }
        _startRivalEvent(event);
        break;
      case 'scripted_monologue':
        if (event.dialogue != null) {
          _showDialogue(event.dialogue!);
        }
        break;
    }
  }

  void _startRivalEvent(MapEvent event) async {
    final user = _userState.currentUser;
    if (user == null) return;

    // Use ArchetypeTeamBuilder for a dynamic rival team
    final archetypeResult = ArchetypeTeamBuilder.build(
      widget.allOrganisms,
      level: user.accountLevel + 2,
      teamSize: 3,
    );
    final rivalTeam = archetypeResult.team;

    if (rivalTeam.isEmpty) return;
    final opponent = rivalTeam.first;
    final mapScreenshot = await _captureMapScreenshot();

    AudioService.instance.pauseAll();
    if (!mounted) return;

    final playerFighter = await _getConsciousPlayerFighter();
    if (playerFighter == null) return;

    final trainerInfo = TrainerInfo(
      title: 'Rival',
      name: 'Gary',
      sprite: 'Ace_Trainer_Male_W.webp',
      gender: 'male',
      introDialogue: const [
        'Smell ya later! Let\'s see how strong you\'ve got!',
      ],
      midBattleDialogue: const ['Not bad, but you can\'t beat my team!'],
      defeatDialogue: const ['Unbelievable! You actually won...'],
    );

    final result = await Navigator.of(context).push<BattleResult>(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          playerOrganism: playerFighter,
          opponentOrganism: opponent,
          opponentTeam: rivalTeam,
          playerTeam: user.teamOrganisms,
          biomeName: _currentBiomeName,
          isTrainerBattle: true,
          battleTitle: 'VS Rival Gary',
          mapScreenshot: mapScreenshot,
          trainerInfo: trainerInfo,
        ),
      ),
    );
    AudioService.instance.resumeAll();

    if (result == BattleResult.win) {
      _showInteractionBubble('Gary: Smelling ya later!');
    } else if (result == BattleResult.loss) {
      await _userState.healFullTeam();
      _playerX = _mapData.spawnPoint.x * tileSize;
      _playerY = (_mapData.height - 1 - _mapData.spawnPoint.y) * tileSize;
      _scrollToPlayer();
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
    final weather = WeatherService().getCurrentWeather(_currentBiomeName);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        await _saveCurrentState();
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          centerTitle: true,
          title: Text(_currentMapName.toUpperCase()),
          backgroundColor: _biomeDarkColor,
          titleTextStyle: TextStyle(
            color: _biomeHighlightColor,
            fontFamily: 'PressStart2P',
            fontSize: 14,
          ),
          leading: Padding(
            padding: const EdgeInsets.only(left: 8.0, top: 2.0),
            child: GameClockWidget(highlightColor: _biomeHighlightColor),
          ),
          leadingWidth: 100,
          actions: [
            IconButton(
              icon: Icon(Icons.shopping_cart, color: AppColors.highlightColor),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ShopScreen(biome: _currentBiomeName),
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
              if (!_isIndoor)
                IgnorePointer(child: WeatherOverlay(weather: weather)),
              // Weather indicator chip
              if (!_isIndoor) _buildWeatherChip(weather),
              // Interaction Bubble Dismiss Overlay
              if (_bubbleText != null)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _dismissDialogue,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              // Interaction Bubble
              if (_bubbleText != null &&
                  (_interactionWorldPos != null || _interactionNPC != null))
                _buildInteractionBubble(),
              // Confirmation Dialog
              if (_confirmationTitle != null) _buildConfirmationDialog(),
              // Sleep Menu
              if (_showSleepMenu) _buildSleepDialog(),
              // Run Button
              _buildRunButton(),
              // Interact Button
              _buildInteractButton(),
              // D-Pad
              _buildDPad(),
              _buildZoomButtons(),
              // Animal Menu
              _buildAnimalMenuButton(),
              // Floating Coordinates
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _biomeHighlightColor.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentMapName.toUpperCase(),
                        style: TextStyle(
                          color: _biomeHighlightColor,
                          fontFamily: 'monospace',
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'COORD: ${(_playerX / tileSize).floor()}, ${_mapData.height - 1 - (_playerY / tileSize).floor()}',
                        style: TextStyle(
                          color: _biomeHighlightColor,
                          fontFamily: 'monospace',
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Loading / Sleeping Overlay
              if (_isMapLoading || _loaderFadeOpacity > 0 || _isSleeping)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: _isSleeping
                          ? _sleepFadeOpacity
                          : _loaderFadeOpacity,
                      duration: const Duration(milliseconds: 600),
                      child: Container(
                        color: Colors.black,
                        child: Center(
                          child: _isSleeping && _sleepFadeOpacity > 0.5
                              ? const Text(
                                  "Zzz...",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'PressStart2P',
                                    fontSize: 16,
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
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
            _cameraSnapped = false;
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
            setState(() {
              _isPanning = false;
            });
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
              isIndoor: _isIndoor,
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
              deployedCampfires: _deployedCampfires,
              fireflies: _fireflies,
              grassParticles: _grassParticles,
              gameNPCs: _gameNPCs,
              grassAnimTime: _grassAnimTime,
              tileShakeOffsets: _tileShakeOffsets,
            ),
          ),
        );
      },
    );
  }

  Widget _buildDPad() {
    const double padSize = 160.0;

    return Positioned(
      bottom: 24,
      left: 16,
      child: GestureDetector(
        onPanStart: (details) {
          setState(() {
            _cameraSnapped = true; // Snap camera back immediately when moving
          });
          _handleDPadGesture(details.localPosition, padSize);
        },
        onPanUpdate: (details) =>
            _handleDPadGesture(details.localPosition, padSize),
        onPanEnd: (_) {
          setState(() {
            _activeDirections.clear();
          });
        },
        child: CustomPaint(
          size: const Size(padSize, padSize),
          painter: _DPadPainter(
            activeDir: _activeDirections.isNotEmpty
                ? _activeDirections.last
                : '',
            highlightColor: _biomeHighlightColor,
            borderColor: _biomeHighlightColor,
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

  Widget _buildAnimalMenuButton() {
    final int campfireCount = _userState.currentUser?.inventory['campfire'] ?? 0;
    
    return Positioned(
      top: 200,
      right: 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (campfireCount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: _deployCampfire,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.orange.withValues(alpha: 0.8),
                    border: Border.all(color: Colors.deepOrange, width: 2),
                  ),
                  child: const Icon(Icons.local_fire_department, color: Colors.yellow, size: 24),
                ),
              ),
            ),
          GestureDetector(
            onTap: () => _showAnimalMenu(context),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.5),
                border: Border.all(color: _biomeHighlightColor, width: 1.5),
              ),
              child: Icon(Icons.pets, color: _biomeHighlightColor, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  void _deployCampfire() async {
    if (await _userState.consumeItem('campfire')) {
      setState(() {
        final pr = (_playerY / tileSize).floor();
        final pc = (_playerX / tileSize).floor();
        _deployedCampfires.add(Point(pc, pr));
        _showInteractionBubble('Deployed a Campfire! Enjoy the warmth.');
      });
    }
  }

  void _showAnimalMenu(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: _biomeHighlightColor.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _menuOption(
                icon: Icons.inventory_2_rounded,
                iconColor: Colors.amber,
                title: 'Animal Party',
                subtitle: 'Manage your active team',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const AnimalBoxScreen(teamOnly: true),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _menuOption(
                icon: Icons.auto_awesome,
                iconColor: Colors.blueAccent,
                title: 'Inventory',
                subtitle: 'Manage items & forging',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(builder: (_) => const CraftingScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              _menuOption(
                icon: Icons.pets,
                iconColor: Colors.purpleAccent,
                title: 'Animal Dex',
                subtitle: 'Browse the full species database',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  final user = _userState.currentUser;
                  if (user == null) return;
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => AnidexScreen(
                        currentUser: user,
                        authService: LocalAuthService(),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
              _menuOption(
                icon: Icons.save_rounded,
                iconColor: Colors.greenAccent,
                title: 'Save Game',
                subtitle: 'Record your progress immediately',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _saveCurrentState();
                  _showInteractionBubble('Game progress has been saved!');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _menuOption({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _biomeHighlightColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'PressStart2P',
                      fontSize: 10,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _handleInteract() {
    if (_bubbleText != null) {
      _dismissDialogue();
      return;
    }
    if (_encounterActive || _isMovingToTarget) return;

    // Determine target coordinate based on facing direction
    // USE CENTER of player for tile detection instead of top-left
    int currentR = ((_playerY + tileSize / 2) / tileSize).floor();
    int currentC = ((_playerX + tileSize / 2) / tileSize).floor();

    int targetR = currentR;
    int targetC = currentC;

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

    // DEBUG logging for signpost issue
    // Invert Y for logs to match maps.json (Bottom-Up)
    int displayR = mapHeight - 1 - currentR;
    int displayTargetR = mapHeight - 1 - targetR;
    debugPrint(
      'INTERACT: player at ($currentC, $displayR), target ($targetC, $displayTargetR)',
    );
    for (final n in _gameNPCs) {
      int displayNPCR = mapHeight - 1 - n.gridRow;
      debugPrint(
        '  NPC ${n.data.id} at (${n.gridCol}, $displayNPCR) type ${n.data.scriptType}',
      );
    }

    // 0. Check for NPC interaction
    OverworldNPC? targetNPC;
    for (final npc in _gameNPCs) {
      if (npc.gridRow == targetR && npc.gridCol == targetC) {
        targetNPC = npc;
        break;
      }
    }

    if (targetNPC != null) {
      // Speak!
      _showNPCDialogue(targetNPC);
      return;
    }

    // 0b. Check for NPC interaction behind a counter (distance 2)
    // First, check if the immediate target is a counter
    if (targetR >= 0 &&
        targetR < mapHeight &&
        targetC >= 0 &&
        targetC < mapWidth) {
      final overlayTilesAtTarget = _mapData.overlayGrid?[targetR][targetC];
      bool isCounter = false;
      if (overlayTilesAtTarget != null) {
        for (final ot in overlayTilesAtTarget) {
          if (ot.tileId.startsWith('med_counter_')) {
            isCounter = true;
            break;
          }
        }
      }

      if (isCounter) {
        // Check distance 2
        int targetR2 = targetR;
        int targetC2 = targetC;
        if (_playerDirection == 'up') targetR2 -= 1;
        if (_playerDirection == 'down') targetR2 += 1;
        if (_playerDirection == 'left') targetC2 -= 1;
        if (_playerDirection == 'right') targetC2 += 1;

        if (targetR2 >= 0 &&
            targetR2 < mapHeight &&
            targetC2 >= 0 &&
            targetC2 < mapWidth) {
          OverworldNPC? behindCounterNPC;
          for (final npc in _gameNPCs) {
            if (npc.gridRow == targetR2 && npc.gridCol == targetC2) {
              behindCounterNPC = npc;
              break;
            }
          }
          if (behindCounterNPC != null) {
            _showNPCDialogue(behindCounterNPC);
            return;
          }
        }
      }
    }

    // 1. Check for animal encounter
    OverworldSprite? targetSprite;
    for (final s in _overworldSprites) {
      if (s.row == targetR && s.col == targetC) {
        targetSprite = s;
        break;
      }
    }

    if (targetSprite != null) {
      AudioService.instance.playOrganismCry(targetSprite.organism.cry);
      setState(() {
        _encounterActive = true;
        _overworldSprites.remove(targetSprite);
      });
      final pr = (_playerY / tileSize).floor().clamp(0, _mapData.height - 1);
      final pc = (_playerX / tileSize).floor().clamp(0, _mapData.width - 1);
      final tileId = _mapData.grid[pr][pc].tileId;
      _onFight(targetSprite.organism, tileId);
      return;
    }

    // 2. Bounds check for tiles/signs
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
    String? tileName = baseDef?.name;

    if (overlayTiles != null) {
      for (final ot in overlayTiles) {
        final def = BiomeDataManager.allTiles[ot.tileId];
        if (def?.category == TileCategory.water) {
          isWater = true;
        }
        if (def?.category == TileCategory.ground ||
            def?.category == TileCategory.path) {
          isLand = true;
        }
        if (def?.category == TileCategory.floating) isFloating = true;
        if (def?.interactionText != null) textToShow = def!.interactionText;
        if (def?.name != null) tileName = def!.name;
      }
    }

    final bool canSwimHere = _canWalkAt(
      targetC * tileSize,
      targetR * tileSize,
      isSwimmingOverride: true,
    );
    final bool canWalkHere = _canWalkAt(
      targetC * tileSize,
      targetR * tileSize,
      isSwimmingOverride: false,
    );

    if (!_isSwimming && isWater && canSwimHere) {
      _showConfirmationDialog("Swim here?", () {
        setState(() {
          _isSwimming = true;
          _isRunning = false;
          _jumpTime = 0.3;
          _playerX = targetC * tileSize;
          _playerY = targetR * tileSize;
          _isMovingToTarget = false;
        });
      });
      return;
    } else if (_isSwimming && isLand && canWalkHere) {
      _showConfirmationDialog("Get out of water?", () {
        setState(() {
          _isSwimming = false;
          _jumpTime = 0.3;
          _playerX = targetC * tileSize;
          _playerY = targetR * tileSize;
          _isMovingToTarget = false;
        });
      });
      return;
    } else if (_isSwimming && isFloating && canWalkHere) {
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

    // 3. Enhanced environmental interactions
    // Fishing check
    if (isWater) {
      final isAquatic = [
        'ocean',
        'river',
        'lake',
        'swamp',
        'coastal',
        'beach',
        'water',
        'sea',
      ].any((b) => _currentBiomeName.toLowerCase().contains(b));

      if (!isAquatic) {
        _showInteractionBubble(
          'This water looks empty. Try fishing in an aquatic biome.',
        );
        return;
      }

      final user = _userState.currentUser;
      if (user != null && user.inventory.keys.any((k) => k.contains('rod'))) {
        _startFishing(targetR, targetC);
        return;
      } else {
        if (!_isSwimming && !canSwimHere) {
          if (_rng.nextDouble() < 0.5 &&
              user != null &&
              !(user.inventory.keys.any((k) => k.contains('rod')))) {
            _userState.addLoot('old_rod', 1);
            _showInteractionBubble(
              'You found an old_rod tangled in the weeds!',
            );
          } else {
            _showInteractionBubble(
              'The water looks deep... Maybe a fishing rod would be useful.',
            );
          }
          return;
        } else if (_isSwimming) {
          _showInteractionBubble('🎣 You could fish here if you had a rod!');
          return;
        }
      }
    }

    // ── Headbutt / Tree Interaction ──
    // Check if the target tile is a tree (solid overlay with "tree" in its id)
    bool isTree = false;
    String? treeTileId;
    if (overlayTiles != null) {
      for (final ot in overlayTiles) {
        final def = BiomeDataManager.allTiles[ot.tileId];
        if (def != null &&
            def.category == TileCategory.solid &&
            ot.tileId.toLowerCase().contains('tree')) {
          isTree = true;
          treeTileId = ot.tileId;
          break;
        }
      }
    }
    if (!isTree &&
        baseDef != null &&
        baseDef.category == TileCategory.solid &&
        baseTileInfo.tileId.toLowerCase().contains('tree')) {
      isTree = true;
      treeTileId = baseTileInfo.tileId;
    }

    if (isTree && treeTileId != null) {
      _tryHeadbutt(targetR, targetC, treeTileId);
      return;
    }

    // Tall grass rustle / Sickle cut
    bool isTallGrass = false;
    if (overlayTiles != null) {
      for (final ot in overlayTiles) {
        final def = BiomeDataManager.allTiles[ot.tileId];
        if (def != null && def.category == TileCategory.tallGrass) {
          isTallGrass = true;
          break;
        }
      }
    }
    if (!isTallGrass &&
        baseDef != null &&
        baseDef.category == TileCategory.tallGrass) {
      isTallGrass = true;
    }

    if (isTallGrass) {
      final hasSickle = (_userState.currentUser?.inventory['sickle'] ?? 0) > 0;
      final isSickleActive = _userState.eventFlags.isSickleActive;

      if (hasSickle && isSickleActive) {
        _tryCutGrass(targetR, targetC);
        return;
      }

      if (hasSickle && !isSickleActive) {
        _showInteractionBubble(
          'The Sickle is OFF. Turn it ON in the inventory to cut grass.',
        );
        return;
      }

      final messages = [
        '🌿 The grass rustles...',
        '🌱 Something might be hiding in here!',
        '🍃 You feel a gust of wind through the grass.',
      ];
      final msg = messages[Random().nextInt(messages.length)];
      _showInteractionBubble(msg);
      return;
    }

    // Rest spot
    if ((textToShow != null && textToShow.startsWith('REST:')) ||
        (tileName != null && tileName.contains('Bed Bottom'))) {
      setState(() => _showSleepMenu = true);
      return;
    }

    // ── PC / Animal Storage Interaction ──
    bool isPCTile = false;
    if (overlayTiles != null) {
      for (final ot in overlayTiles) {
        if (ot.tileId == 'pc_1') {
          isPCTile = true;
          break;
        }
      }
    }
    if (!isPCTile && baseTileInfo.tileId == 'pc_1') {
      isPCTile = true;
    }

    if (isPCTile && _playerDirection == 'up') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AnimalBoxScreen()),
      );
      return;
    }

    if (textToShow != null) {
      _showInteractionBubble(textToShow);
    }
  }

  /// Attempts to cut a tall grass tile with the sickle.
  void _tryCutGrass(int r, int c) {
    final userState = _userState;
    final String mapId = _currentMapId;

    // 1. Update persistent state
    userState.cutGrass(mapId, r, c);

    // 2. Visual effect: particles
    for (int i = 0; i < 5; i++) {
      _spawnGrassParticles(
        c * tileSize + tileSize / 2,
        r * tileSize + tileSize / 2,
      );
    }

    // 3. Update the map grid locally for immediate feedback
    if (_mapData.overlayGrid != null) {
      final alreadyCut = _mapData.overlayGrid![r][c].any(
        (t) => t.tileId == 'cutdown_grass',
      );
      if (!alreadyCut) {
        _mapData.overlayGrid![r][c].removeWhere((t) {
          final def = BiomeDataManager.allTiles[t.tileId];
          return def?.category == TileCategory.tallGrass;
        });
        _mapData.overlayGrid![r][c].add(
          MapTile(tileId: 'cutdown_grass', config: _mapData.config),
        );
      }
    }

    setState(() {});
    _showInteractionBubble('Swish! You cut the tall grass.');
  }

  /// Checks if any party animal has the "Headbutt" move.
  bool _checkHeadbuttMove() {
    final user = _userState.currentUser;
    if (user == null) return false;

    for (final org in user.teamOrganisms) {
      for (final moveName in org.selectedMoveNames) {
        final name = moveName.toLowerCase();
        if (name == 'headbutt' || name == 'zen headbutt') return true;
      }
    }
    return false;
  }

  /// Attempts to headbutt a tree at the given tile position.
  void _tryHeadbutt(int r, int c, String tileId) {
    if (_encounterActive || _isTransitioning) return;

    final String mapId = widget.biomeName;
    final String key = '$mapId:$r:$c';
    final userState = _userState;

    // 1. Check if any party animal has headbutt
    if (!_checkHeadbuttMove()) {
      _showInteractionBubble(
        'A sturdy tree. Maybe a headbutt could shake it...',
      );
      return;
    }

    // 2. Check cooldown
    if (userState.isTileOnCooldown(mapId, r, c)) {
      final lastTime =
          userState.currentUser?.eventFlags.tileCooldowns[key] ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final remainingMs = (5 * 60 * 1000) - (now - lastTime);
      final mins = (remainingMs / 60000).floor();
      final secs = ((remainingMs % 60000) / 1000).floor();
      _showInteractionBubble('Cooldown: ${mins}m ${secs}s remaining.');
      return;
    }

    // 3. Start the shake animation
    final shakeKey = '$r:$c';
    _tileShakeTimers[shakeKey] = 0.8; // 800ms shake
    _tileShakeOffsets[shakeKey] = 0;

    // 4. Set cooldown
    userState.updateTileCooldown(mapId, r, c);

    // 5. Determine drops based on tile definition
    final tileDef = BiomeDataManager.allTiles[tileId];
    if (tileDef == null) return;

    final rng = Random();
    if (tileDef.drop != null && tileDef.drop!.isNotEmpty) {
      final drops = tileDef.drop!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();

      if (drops.isNotEmpty && rng.nextDouble() < 0.30) {
        final dropId = drops[rng.nextInt(drops.length)];
        userState.addLoot(dropId, 1);

        String displayName =
            dropId[0].toUpperCase() + dropId.substring(1).replaceAll('_', ' ');
        _showInteractionBubble('Headbutt! A $displayName fell from the tree!');
        return;
      }
    }

    // 6. 20% chance for encounter if no drop
    if (rng.nextDouble() < 0.20) {
      _triggerHeadbuttEncounter(r, c, tileId);
    } else {
      _showInteractionBubble('Headbutt! ...nothing happened.');
    }
  }

  /// Triggers an encounter from a headbutted tree if any organism has this tile as spawn.
  void _triggerHeadbuttEncounter(int r, int c, String tileId) {
    final user = _userState.currentUser;
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

    // Find organisms that can spawn on this tile type
    final encounter = getWeightedRandomOrganism(
      _currentBiomeName,
      widget.allOrganisms,
      accountLevel: user.accountLevel,
      inventory: user.inventory,
      teamMoveNames: user.teamOrganisms
          .expand((o) => o.selectedMoveNames)
          .toList(),
      currentTimeOfDay: timeOfDay,
      encounterType: 'land',
      currentTileId: tileId,
      currentTileCategory: TileCategory.solid,
      biomeId: _currentBiomeName,
    );

    if (encounter != null) {
      _showInteractionBubble(
        'Headbutt! A wild ${encounter.organism.name} fell from the tree!',
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        AudioService.instance.playOrganismCry(encounter.organism.cry);
        setState(() => _encounterActive = true);
        _onFight(encounter.organism, tileId);
      });
    } else {
      _showInteractionBubble('Headbutt! ...nothing happened.');
    }
  }

  void _showNPCDialogue(OverworldNPC npc) {
    if (npc.data.scriptType == 'signpost') {
      _showDialogue(npc.data.dialogue);
      return;
    }

    // Make NPC face the player
    final pRow = (_playerY / tileSize).floor();
    final pCol = (_playerX / tileSize).floor();
    npc.faceToward(pRow, pCol);

    // If this is a defeated trainer, skip pre-battle dialogue and only show defeat text
    final isTrainerType =
        npc.data.scriptType == 'trainer' ||
        npc.data.scriptType == 'rival' ||
        npc.data.scriptType == 'major_trainer' ||
        npc.data.scriptType == 'evil_team' ||
        npc.data.scriptType == 'event_trainer';
    if (isTrainerType && npc.isDefeated) {
      _showInteractionBubble(
        '${npc.data.name}: ${npc.data.defeatText.isNotEmpty ? npc.data.defeatText : "..."}',
        speaker: npc,
      );
      return;
    }

    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    // Prepend display name to the first line if name exists
    final lines = List<String>.from(npc.data.dialogue);
    if (lines.isNotEmpty && displayName.isNotEmpty) {
      lines[0] = '$displayName${lines[0]}';
    }

    _showDialogue(
      lines,
      speaker: npc,
      onDismiss: () => _handleNPCInteraction(npc),
    );
  }

  void _handleNPCInteraction(OverworldNPC npc) {
    if (!mounted) return;
    if (npc.data.scriptType == 'trainer' ||
        npc.data.scriptType == 'rival' ||
        npc.data.scriptType == 'major_trainer' ||
        npc.data.scriptType == 'evil_team' ||
        npc.data.scriptType == 'event_trainer') {
      if (!npc.isDefeated) {
        _startTrainerBattle(npc);
      } else {
        _showInteractionBubble(
          '${npc.data.name}: ${npc.data.defeatText.isNotEmpty ? npc.data.defeatText : "..."}',
          speaker: npc,
        );
      }
    } else if (npc.data.scriptType == 'shopkeeper') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShopScreen(biome: _currentBiomeName),
        ),
      );
    } else if (npc.data.scriptType == 'medic') {
      final int playerCol = ((_playerX + tileSize / 2) / tileSize).floor();
      final int playerRow = ((_playerY + tileSize / 2) / tileSize).floor();
      // Convert to config-style coordinate (0 is bottom)
      final int spawnY = _mapData.height - 1 - playerRow;
      _userState.setLastMedicalCenter(_currentMapId, spawnY, playerCol);

      _userState.fullyHealTeam().then((_) {
        if (mounted) {
          _showInteractionBubble(
            'Your animals have been fully healed and revived!',
            speaker: npc,
          );
          AudioService.instance.playSound('audio/effects/heal.mp3');
        }
      });
    } else if (npc.data.scriptType == 'quest_giver') {
      _handleQuestGiverNPC(npc);
    } else if (npc.data.scriptType == 'story') {
      _handleStoryNPC(npc);
    } else if (npc.data.scriptType == 'blocker') {
      _handleBlockerNPC(npc);
    } else if (npc.data.scriptType == 'item_giver') {
      _handleItemGiverNPC(npc);
    } else if (npc.data.scriptType == 'fetch_quest') {
      _handleFetchQuestNPC(npc);
    } else if (npc.data.scriptType == 'professor') {
      _handleProfessorNPC(npc);
    } else if (npc.data.scriptType == 'request_board') {
      _handleRequestBoardNPC(npc);
    } else if (npc.data.scriptType == 'event_npc') {
      _handleEventNPC(npc);
    }
  }

  void _handleEventNPC(OverworldNPC npc) {
    final userState = _userState;

    // Show dialogue and then disappear
    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    final lines = List<String>.from(npc.data.dialogue);
    if (lines.isNotEmpty && displayName.isNotEmpty) {
      lines[0] = '$displayName${lines[0]}';
    }

    _showDialogue(
      lines,
      speaker: npc,
      onDismiss: () {
        // Set the event flag
        if (npc.data.setsFlag.isNotEmpty) {
          userState.setFlag(npc.data.setsFlag);
        }
        // Remove the NPC from the map
        _gameNPCs.remove(npc);
        setState(() {});
      },
    );
  }

  void _handleQuestGiverNPC(OverworldNPC npc) {
    final userState = _userState;
    final user = userState.currentUser;
    if (user == null) return;

    // Check if the quest is already completed in event flags
    if (npc.data.questId.isNotEmpty &&
        userState.eventFlags.isQuestCompleted(npc.data.questId)) {
      // Post-event dialogue
      final lines = npc.data.postEventDialogue.isNotEmpty
          ? List<String>.from(npc.data.postEventDialogue)
          : ['Thanks for your help!'];
      final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
      if (lines.isNotEmpty && displayName.isNotEmpty) {
        lines[0] = '$displayName${lines[0]}';
      }
      _showDialogue(lines);
      return;
    }

    // Check if the quest is already active
    final existingQuest = user.activeQuests
        .where((q) => q.id == npc.data.questId)
        .toList();
    if (existingQuest.isNotEmpty) {
      final q = existingQuest.first;
      if (q.isCompleted) {
        // Complete the quest!
        _showInteractionBubble('${npc.data.name}: Excellent work!');
        userState.markQuestCompleted(npc.data.questId);
        if (npc.data.setsFlag.isNotEmpty) {
          userState.setFlag(npc.data.setsFlag);
        }
      } else {
        _showInteractionBubble(
          '${npc.data.name}: ${q.description} (${q.currentCount}/${q.targetCount})',
        );
      }
      return;
    }

    // Offer the quest
    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    final lines = List<String>.from(npc.data.dialogue);
    if (lines.isNotEmpty && displayName.isNotEmpty) {
      lines[0] = '$displayName${lines[0]}';
    }

    _showDialogue(lines);
    // TODO: Add quest accept UI — for now auto-accept
    if (npc.data.questId.isNotEmpty) {
      final quest = Quest(
        id: npc.data.questId,
        description: npc.data.dialogue.isNotEmpty
            ? npc.data.dialogue.first
            : 'Complete the quest.',
        targetOrganismName: '', // Would be populated from quest data
        targetCount: 1,
        rewardMoney: 500,
        giverNpcId: npc.data.id,
        completionFlag: npc.data.setsFlag,
      );
      userState.acceptQuest(quest);
    }
  }

  void _handleStoryNPC(OverworldNPC npc) {
    final userState = _userState;

    // Check if story has been read (flag already set)
    if (npc.data.setsFlag.isNotEmpty && userState.hasFlag(npc.data.setsFlag)) {
      // Post-event dialogue
      final lines = npc.data.postEventDialogue.isNotEmpty
          ? List<String>.from(npc.data.postEventDialogue)
          : ['...'];
      final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
      if (lines.isNotEmpty && displayName.isNotEmpty) {
        lines[0] = '$displayName${lines[0]}';
      }
      _showDialogue(lines);
      return;
    }

    // Show story dialogue
    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    final lines = List<String>.from(npc.data.dialogue);
    if (lines.isNotEmpty && displayName.isNotEmpty) {
      lines[0] = '$displayName${lines[0]}';
    }

    _showDialogue(lines);

    // Set flag after reading
    if (npc.data.setsFlag.isNotEmpty) {
      userState.setFlag(npc.data.setsFlag);
    }
  }

  void _handleBlockerNPC(OverworldNPC npc) {
    final userState = _userState;

    // If requiredFlag is now satisfied, remove the NPC from the map
    if (npc.data.requiredFlag.isNotEmpty &&
        userState.hasFlag(npc.data.requiredFlag)) {
      _gameNPCs.remove(npc);
      _showInteractionBubble('The path is now clear!');
      setState(() {});
      return;
    }

    // Show blocking dialogue
    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    final lines = List<String>.from(npc.data.dialogue);
    if (lines.isNotEmpty && displayName.isNotEmpty) {
      lines[0] = '$displayName${lines[0]}';
    }

    _showDialogue(lines);
  }

  void _handleItemGiverNPC(OverworldNPC npc) {
    final userState = _userState;

    // Check if item already collected
    final itemKey = '${npc.data.id}_item';
    if (userState.eventFlags.isItemCollected(itemKey)) {
      final lines = npc.data.postEventDialogue.isNotEmpty
          ? List<String>.from(npc.data.postEventDialogue)
          : ['I have nothing more for you.'];
      final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
      if (lines.isNotEmpty && displayName.isNotEmpty) {
        lines[0] = '$displayName${lines[0]}';
      }
      _showDialogue(lines);
      return;
    }

    // Give the item
    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    final lines = List<String>.from(npc.data.dialogue);
    if (lines.isNotEmpty && displayName.isNotEmpty) {
      lines[0] = '$displayName${lines[0]}';
    }

    _showDialogue(lines);

    if (npc.data.itemRewardId.isNotEmpty) {
      userState.addLoot(npc.data.itemRewardId, npc.data.itemRewardCount);
      userState.markItemCollected(itemKey);
      if (npc.data.setsFlag.isNotEmpty) {
        userState.setFlag(npc.data.setsFlag);
      }
    }
  }

  void _handleFetchQuestNPC(OverworldNPC npc) {
    final userState = _userState;
    final user = userState.currentUser;
    if (user == null) return;

    // Check if already done
    if (npc.data.setsFlag.isNotEmpty && userState.hasFlag(npc.data.setsFlag)) {
      final lines = npc.data.postEventDialogue.isNotEmpty
          ? List<String>.from(npc.data.postEventDialogue)
          : ['Thanks for your help!'];
      final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
      if (lines.isNotEmpty && displayName.isNotEmpty) {
        lines[0] = '$displayName${lines[0]}';
      }
      _showDialogue(lines);
      return;
    }

    // Determine what is needed
    bool hasRequirements = false;
    if (npc.data.itemRequiredId.isNotEmpty) {
      final count = user.inventory[npc.data.itemRequiredId] ?? 0;
      hasRequirements = count >= npc.data.itemRequiredCount;
    } else if (npc.data.organismRequiredId.isNotEmpty) {
      hasRequirements = user.capturedOrganisms.any(
        (o) =>
            o.baseOrganism.name.toLowerCase() ==
            npc.data.organismRequiredId.toLowerCase(),
      );
    } else {
      hasRequirements = true;
    }

    if (hasRequirements) {
      _showInteractionBubble(
        '${npc.data.name}: You have what I need! Thank you!',
      );
      if (npc.data.itemRequiredId.isNotEmpty) {
        userState.addLoot(npc.data.itemRequiredId, -npc.data.itemRequiredCount);
      }

      if (npc.data.itemRewardId.isNotEmpty) {
        userState.addLoot(npc.data.itemRewardId, npc.data.itemRewardCount);
      }
      if (npc.data.setsFlag.isNotEmpty) {
        userState.setFlag(npc.data.setsFlag);
      }
    } else {
      final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
      final lines = List<String>.from(npc.data.dialogue);
      if (lines.isNotEmpty && displayName.isNotEmpty) {
        lines[0] = '$displayName${lines[0]}';
      }

      _showDialogue(lines);
    }
  }

  void _handleProfessorNPC(OverworldNPC npc) {
    final userState = _userState;
    final user = userState.currentUser;
    if (user == null) return;

    final dexCount = user.discoveredOrganisms.length;

    // Check milestone (using itemRequiredCount as milestone target)
    if (npc.data.itemRewardId.isNotEmpty && npc.data.itemRequiredCount > 0) {
      final itemKey = '${npc.data.id}_milestone';
      if (!userState.hasFlag(itemKey) &&
          dexCount >= npc.data.itemRequiredCount) {
        _showInteractionBubble(
          '${npc.data.name}: Excellent! You found ${npc.data.itemRequiredCount} species! Take this reward!',
        );
        userState.addLoot(npc.data.itemRewardId, npc.data.itemRewardCount);
        userState.setFlag(itemKey);
        return;
      }
    }

    _showInteractionBubble(
      '${npc.data.name}: You have discovered $dexCount species so far! Keep up the good work!',
    );
  }

  void _handleRequestBoardNPC(OverworldNPC npc) {
    // A request board acts similarly to a generic quest giver setup
    _handleQuestGiverNPC(npc);
  }

  // ── Trainer NPC Vision & Battle Flow ──
  OverworldNPC? _approachingNPC;

  void _checkNPCVision(int playerRow, int playerCol) {
    if (_encounterActive || _approachingNPC != null) return;

    for (final npc in _gameNPCs) {
      if (npc.canSeePlayer(playerRow, playerCol)) {
        // Freeze the player
        setState(() {
          _encounterActive = true;
          _velX = 0;
          _velY = 0;
          _isMovingToTarget = false;
          _walkFrame = 0;
          _activeDirections.clear();

          // Snap to tile center to avoid stopping between tiles
          _playerX = playerCol * tileSize;
          _playerY = playerRow * tileSize;
        });

        // NPC starts approaching
        npc.startApproach(playerRow, playerCol);
        _approachingNPC = npc;

        // Show "!" above NPC
        _showInteractionBubble(
          '!',
          speaker: npc,
          duration: const Duration(seconds: 1),
        );
        break;
      }
    }
  }

  void _startTrainerBattle(OverworldNPC npc) async {
    final userState = _userState;
    final user = userState.currentUser;
    if (user == null) return;

    // Show initial dialogue
    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    final lines = npc.data.dialogue.isNotEmpty
        ? List<String>.from(npc.data.dialogue)
        : ['Let\'s battle!'];

    if (lines.isNotEmpty && displayName.isNotEmpty) {
      lines[0] = '$displayName${lines[0]}';
    }

    _showDialogue(
      lines,
      speaker: npc,
      onDismiss: () async {
        if (!mounted) return;

        // Build opponent team from npc_teams.json
        final opponentTeam = NpcTeamLoader.buildTeam(
          npc.data.teamId,
          widget.allOrganisms,
        );
        for (final opponent in opponentTeam) {
          userState.discoverOrganism(opponent.baseOrganism.name);
        }
        if (opponentTeam.isEmpty) {
          debugPrint(
            'BiomeExplorationMap: Opponent team is empty for ${npc.data.teamId}. Cannot start battle.',
          );
          _showInteractionBubble(
            'I have no animals to fight with...',
            duration: const Duration(seconds: 2),
          );

          setState(() => _encounterActive = false);
          _approachingNPC = null;
          npc.hasTriggeredBattle = false;
          return;
        }

        // Get player's fighter
        final playerFighter = await _getConsciousPlayerFighter();
        if (playerFighter == null) {
          _approachingNPC = null;
          npc.hasTriggeredBattle = false;
          return;
        }

        final trainerName = NpcTeamLoader.getTrainerName(npc.data.teamId);
        final mapScreenshot = await _captureMapScreenshot();

        final hour = TimeService().currentGameTime.hour;
        String timeOfDay;
        if (hour >= 6 && hour < 18) {
          timeOfDay = 'day';
        } else if (hour >= 18 && hour < 21) {
          timeOfDay = 'evening';
        } else {
          timeOfDay = 'night';
        }

        AudioService.instance.pauseAll();
        if (!mounted) return;

        final trainerInfo =
            TrainerDataLoader.generateByName(trainerName) ??
            TrainerDataLoader.generateRandom(biome: _currentBiomeName);

        final BattleResult? result = await Navigator.of(context)
            .push<BattleResult>(
              MaterialPageRoute(
                builder: (context) => BattleScreen(
                  playerOrganism: playerFighter,
                  opponentOrganism: opponentTeam.first,
                  playerTeam: user.teamOrganisms,
                  opponentTeam: opponentTeam,
                  mapScreenshot: mapScreenshot,
                  isTrainerBattle: true,
                  battleTitle: 'VS ${trainerInfo.displayName}',
                  timeOfDay: timeOfDay,
                  biomeName: _currentBiomeName,
                  trainerInfo: trainerInfo,
                ),
              ),
            );

        if (mounted) {
          _handleBattleResult(result, npc);
        }
      },
    );
  }

  void _handleBattleResult(BattleResult? result, OverworldNPC npc) async {
    final userState = _userState;
    AudioService.instance.resumeAll();

    if (mounted) {
      bool won = result == BattleResult.win || result == BattleResult.capture;

      if (won) {
        // Mark as defeated permanently
        npc.isDefeated = true;
        npc.hasTriggeredBattle = true;

        // Persist to event flags
        await userState.markTrainerDefeated(npc.data.id);
        if (npc.data.setsFlag.isNotEmpty) {
          await userState.setFlag(npc.data.setsFlag);
        }

        // Show defeat text and then rewards
        if (npc.data.defeatText.isNotEmpty) {
          _showInteractionBubble(
            '${npc.data.name}: ${npc.data.defeatText}',
            speaker: npc,
            onDismiss: () {
              _showBattleRewards(npc);
              // Remove event trainers from the map after defeat
              if (npc.data.scriptType == 'event_trainer' ||
                  npc.data.disappearsOnDefeat) {
                _gameNPCs.remove(npc);
                setState(() {});
              }
            },
          );
        } else {
          _showBattleRewards(npc);
          // Remove event trainers from the map after defeat
          if (npc.data.scriptType == 'event_trainer' ||
              npc.data.disappearsOnDefeat) {
            _gameNPCs.remove(npc);
            setState(() {});
          }
        }
      } else if (result == BattleResult.loss) {
        await _handleWhiteOut();

        // Reset NPC back to initially defined location
        npc.resetPosition();

        // Allow re-challenge
        npc.hasTriggeredBattle = false;

        // Save the updated position
        _saveCurrentState();
      } else {
        // Fled or cancelled
        npc.hasTriggeredBattle = false;
      }

      _approachingNPC = null;
      setState(() {
        _encounterActive = false;
        // Always reset movement state when returning from battle
        _isMovingToTarget = false;
        _velX = 0;
        _velY = 0;
        _walkFrame = 0;
      });
    }
  }

  void _showBattleRewards(OverworldNPC npc) {
    if (!mounted) return;

    final userState = _userState;

    if (npc.data.rewardMoney > 0) {
      userState.addMoney(npc.data.rewardMoney);
      _showInteractionBubble(
        'Received ৳${npc.data.rewardMoney} for winning!',
        speaker: npc,
        onDismiss: () => _showItemReward(npc),
      );
    } else {
      _showItemReward(npc);
    }
  }

  void _showItemReward(OverworldNPC npc) {
    if (!mounted) return;

    if (npc.data.itemRewardId.isNotEmpty) {
      _userState.addLoot(npc.data.itemRewardId, npc.data.itemRewardCount);
      String displayName =
          npc.data.itemRewardId[0].toUpperCase() +
          npc.data.itemRewardId.substring(1).replaceAll('_', ' ');
      _showInteractionBubble(
        'Received $displayName x${npc.data.itemRewardCount}!',
        speaker: npc,
      );
    }
  }

  void _showDialogue(
    List<String> lines, {
    Offset? worldPos,
    OverworldNPC? speaker,
    VoidCallback? onDismiss,
    Duration? duration,
  }) {
    if (lines.isEmpty) return;

    // Attempt to determine the speaker prefix from the first line or the speaker object
    String? prefix;
    if (lines.first.contains(': ')) {
      prefix = '${lines.first.split(': ')[0]}: ';
    } else if (speaker != null && speaker.data.name.isNotEmpty) {
      prefix = '${speaker.data.name}: ';
    }

    // Flatten lines into a single list of pages, splitting any \n in individual lines
    final allPages = <String>[];
    for (final line in lines) {
      final splitPages = line.split('\n').where((s) => s.trim().isNotEmpty);
      for (final p in splitPages) {
        if (prefix != null && !p.startsWith(prefix)) {
          allPages.add('$prefix$p');
        } else {
          allPages.add(p);
        }
      }
    }

    if (allPages.isEmpty) return;

    setState(() {
      _dialogueQueue = allPages;
      _dialogueIndex = 0;
      _bubbleText = _dialogueQueue[0];
      _interactionWorldPos = worldPos ?? Offset(_playerX, _playerY - tileSize);
      _interactionNPC = speaker;
      _onBubbleDismiss = onDismiss;
    });

    _bubbleTimer?.cancel();
    final effectiveDuration = duration ?? const Duration(seconds: 8);
    _bubbleTimer = Timer(effectiveDuration, () {
      if (mounted) _dismissDialogue();
    });
  }

  void _showInteractionBubble(
    String text, {
    Offset? worldPos,
    OverworldNPC? speaker,
    VoidCallback? onDismiss,
    Duration? duration,
  }) {
    // Split by \n for multi-page support
    final pages = text.split('\n').where((s) => s.trim().isNotEmpty).toList();
    if (pages.isEmpty) return;

    // Attempt to determine the speaker prefix from the first line or the speaker object
    String? prefix;
    if (pages.first.contains(': ')) {
      prefix = '${pages.first.split(': ')[0]}: ';
    } else if (speaker != null && speaker.data.name.isNotEmpty) {
      prefix = '${speaker.data.name}: ';
    }

    final allPages = <String>[];
    for (final p in pages) {
      if (prefix != null && !p.startsWith(prefix)) {
        allPages.add('$prefix$p');
      } else {
        allPages.add(p);
      }
    }

    setState(() {
      _dialogueQueue = allPages;
      _dialogueIndex = 0;
      _bubbleText = _dialogueQueue[0];
      _interactionWorldPos = worldPos ?? Offset(_playerX, _playerY - tileSize);
      _interactionNPC = speaker;
      _onBubbleDismiss = onDismiss;
    });

    _bubbleTimer?.cancel();
    // Non-last pages don't auto-dismiss usually, or have longer timers.
    // For simplicity, we keep a timer but it resets on page advance.
    final effectiveDuration = duration ?? const Duration(seconds: 8);
    _bubbleTimer = Timer(effectiveDuration, () {
      if (mounted) _dismissDialogue();
    });
  }

  void _dismissDialogue() {
    if (!mounted) return;
    _bubbleTimer?.cancel();

    // Check if there are more pages in the queue
    if (_dialogueIndex < _dialogueQueue.length - 1) {
      setState(() {
        _dialogueIndex++;
        _bubbleText = _dialogueQueue[_dialogueIndex];
      });
      // Reset timer for the next page
      _bubbleTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) _dismissDialogue();
      });
      return;
    }

    final callback = _onBubbleDismiss;
    setState(() {
      _bubbleText = null;
      _dialogueQueue = [];
      _dialogueIndex = 0;
      _onBubbleDismiss = null;
    });
    callback?.call();
  }

  Widget _buildInteractionBubble() {
    if (_bubbleText == null ||
        (_interactionWorldPos == null && _interactionNPC == null) ||
        _viewSize == Size.zero) {
      return const SizedBox.shrink();
    }

    // Determine the current world position of the target
    final targetWorldPos = _interactionNPC != null
        ? Offset(_interactionNPC!.pixelX, _interactionNPC!.pixelY)
        : _interactionWorldPos!;

    // Map world coords back to screen coordinates
    double screenX =
        (targetWorldPos.dx - _cameraX) * _zoomScale +
        (tileSize * _zoomScale) / 2;
    double screenY = (targetWorldPos.dy - _cameraY) * _zoomScale;

    // The bubble should span the screen (with margins)
    const double horizontalMargin = 10.0;
    final double bubbleWidth = _viewSize.width - (horizontalMargin * 2);

    return Positioned(
      left: horizontalMargin,
      right: horizontalMargin,
      top: screenY - 75, // Height offset to sit above player/tile
      child: GestureDetector(
        onTap: _dismissDialogue,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22).withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Builder(
                      builder: (context) {
                        final text = _bubbleText!;
                        final splitIdx = text.indexOf(': ');
                        if (splitIdx != -1) {
                          final name = text.substring(0, splitIdx);
                          final msg = text.substring(splitIdx + 2);
                          return RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'PressStart2P',
                                fontSize: 10,
                                height: 1.6,
                              ),
                              children: [
                                TextSpan(
                                  text: '$name\n',
                                  style: const TextStyle(
                                    color: Color(0xFFFFD700), // Gold for name
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const TextSpan(text: '\n'), // Extra spacing
                                TextSpan(text: msg),
                              ],
                            ),
                          );
                        }
                        return Text(
                          text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'PressStart2P',
                            fontSize: 10,
                            height: 1.6,
                          ),
                        );
                      },
                    ),
                  ),
                  // "Click to continue" indicator
                  Positioned(
                    bottom: 2,
                    right: 4,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.3, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      builder: (context, value, child) {
                        return Opacity(opacity: value, child: child);
                      },
                      onEnd: () {},
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '▼',
                            style: TextStyle(
                              color: Colors.white70,
                              fontFamily: 'PressStart2P',
                              fontSize: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Dynamic Pointer Tail
            LayoutBuilder(
              builder: (context, constraints) {
                // Determine where the tail should be horizontally
                // screenX is absolute on the screen. The Column is at horizontalMargin.
                // So the tail's local offset within the Column is screenX - horizontalMargin.
                double tailLocalX = screenX - horizontalMargin;

                // Clamp it to be within the bubble's bounds
                tailLocalX = tailLocalX.clamp(20.0, bubbleWidth - 20.0);

                return Container(
                  width: double.infinity,
                  height: 14,
                  alignment: Alignment.topLeft,
                  child: Transform.translate(
                    offset: Offset(
                      tailLocalX - 7,
                      -2,
                    ), // -7 to center 14px tail
                    child: Transform.rotate(
                      angle: 3.14159 / 4,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF161B22,
                          ).withValues(alpha: 0.95),
                          border: const Border(
                            bottom: BorderSide(color: Colors.white, width: 2),
                            right: BorderSide(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
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

  Widget _buildSleepDialog() {
    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _biomeHighlightColor, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Rest for how long?",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'PressStart2P',
                fontSize: 10,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildDialogButton("1H", () => _rest(1)),
                _buildDialogButton("2H", () => _rest(2)),
                _buildDialogButton("4H", () => _rest(4)),
                _buildDialogButton("6H", () => _rest(6)),
                _buildDialogButton("12H", () => _rest(12)),
              ],
            ),
            const SizedBox(height: 16),
            _buildDialogButton("CANCEL", () {
              setState(() => _showSleepMenu = false);
            }),
          ],
        ),
      ),
    );
  }

  void _rest(int hours) async {
    setState(() {
      _showSleepMenu = false;
      _isSleeping = true;
      _sleepFadeOpacity = 1.0;
    });

    // Wait for the screen to fade to black
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    TimeService().advanceTime(hours);

    // Keep screen black for a moment while "Zzz..." shows
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    setState(() {
      _sleepFadeOpacity = 0.0;
    });

    // Wait for the screen to fade back in
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      _isSleeping = false;
    });

    _showInteractionBubble('Rested for $hours hours!');
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

    // Deadzone - much smaller for higher responsiveness
    if (dist < 0.5) {
      if (_activeDirections.isNotEmpty) {
        setState(() => _activeDirections.clear());
      }
      return;
    }

    // Convert angle to direction
    // Right: -PI/4 to PI/4
    // Down: PI/4 to 3PI/4
    // Left: 3PI/4 to -3PI/4 (wrap)
    // Up: -3PI/4 to -PI/4

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

  Widget _buildStaminaBar(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            opaque: false,
            pageBuilder: (_, animation, _) =>
                PhoneScreen(initialBiome: _currentBiomeName),
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
              borderRadius: BorderRadius.circular(12),
              color: _biomeDarkColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
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
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _biomeHighlightColor,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
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
              "${WeatherService().getForecast(_currentBiomeName).first.temperatureCelsius.toStringAsFixed(1)}°C",
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
      if (!habitats.contains(_currentBiomeName.toLowerCase())) continue;

      // Max of the same phenotype based on config or default 5
      final spawnData = BiomeDataManager.phenoSpawnData[org.pheno];
      final currentPhenoCount = _overworldSprites
          .where((s) => s.organism.pheno == org.pheno)
          .length;
      if (currentPhenoCount >= (spawnData?.maxSpawns ?? 5)) continue;

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

      validTiles.shuffle(rng);
      int? selectedRow;
      int? selectedCol;

      for (final pos in validTiles) {
        final r = pos[0];
        final c = pos[1];

        // Ensure tile is not occupied by another sprite or player
        bool occupied = false;
        if ((_playerY / tileSize).round() == r &&
            (_playerX / tileSize).round() == c) {
          occupied = true;
        } else {
          for (final s in _overworldSprites) {
            if (s.row == r && s.col == c) {
              occupied = true;
              break;
            }
          }
        }

        if (!occupied) {
          selectedRow = r;
          selectedCol = c;
          break;
        }
      }

      if (selectedRow == null || selectedCol == null) continue;

      final sprite = OverworldSprite(
        organism: org,
        row: selectedRow,
        col: selectedCol,
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
    final addedTiles = <String>{}; // track "r:c" to avoid duplicates
    final spawnSet = org.spawnTiles
        .split(',')
        .map((e) => e.trim().toLowerCase().replaceAll('_', ''))
        .toSet();
    final isAny = spawnSet.contains('any');

    for (int r = 0; r < _mapData.height; r++) {
      for (int c = 0; c < _mapData.width; c++) {
        final base = _mapData.grid[r][c];
        final overlay = _mapData.overlayGrid?[r][c];
        final isSolid =
            base.category == TileCategory.solid ||
            (overlay?.any((t) => t.category == TileCategory.solid) ?? false);

        if (isSolid) {
          // Check if this solid tile matches the spawn criteria
          bool solidMatch = false;
          if (!isAny) {
            if (spawnSet.contains(
                  base.tileId.toLowerCase().replaceAll('_', ''),
                ) ||
                spawnSet.contains(
                  base.category.name.toLowerCase().replaceAll('_', ''),
                )) {
              solidMatch = true;
            } else if (overlay != null) {
              for (final ot in overlay) {
                if (spawnSet.contains(
                      ot.tileId.toLowerCase().replaceAll('_', ''),
                    ) ||
                    spawnSet.contains(
                      ot.category.name.toLowerCase().replaceAll('_', ''),
                    )) {
                  solidMatch = true;
                  break;
                }
              }
            }
          }

          if (solidMatch) {
            // Add non-solid adjacent tiles instead
            for (final d in [
              [-1, 0],
              [1, 0],
              [0, -1],
              [0, 1],
            ]) {
              final nr = r + d[0];
              final nc = c + d[1];
              if (nr < 0 ||
                  nr >= _mapData.height ||
                  nc < 0 ||
                  nc >= _mapData.width) {
                continue;
              }
              final adjBase = _mapData.grid[nr][nc];
              final adjOverlay = _mapData.overlayGrid?[nr][nc];
              final adjSolid =
                  adjBase.category == TileCategory.solid ||
                  (adjOverlay?.any((t) => t.category == TileCategory.solid) ??
                      false);
              if (!adjSolid) {
                final key = '$nr:$nc';
                if (addedTiles.add(key)) {
                  tiles.add([nr, nc]);
                }
              }
            }
          }
          continue; // Don't add the solid tile itself
        }

        if (isAny) {
          final key = '$r:$c';
          if (addedTiles.add(key)) {
            tiles.add([r, c]);
          }
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
          final key = '$r:$c';
          if (addedTiles.add(key)) {
            tiles.add([r, c]);
          }
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
    final rng = Random();

    for (final sprite in _overworldSprites) {
      if (sprite.isAlerted) continue;

      // USE CENTER for distance/collision checks
      final int pr = ((_playerY + tileSize / 2) / tileSize).floor();
      final int pc = ((_playerX + tileSize / 2) / tileSize).floor();
      final int sr = (sprite.pixelY / tileSize).floor();
      final int sc = (sprite.pixelX / tileSize).floor();

      final int dr = pr - sr;
      final int dc = pc - sc;

      // 1. Cardinal adjacency check: Must be exactly 1 tile away vertically OR horizontally (not both/diagonal)
      bool isAdjacent =
          (dr.abs() == 1 && dc == 0) || (dc.abs() == 1 && dr == 0);

      // 2. Facing check: The animal must be facing the tile the player is on
      bool isFacing = false;
      if (isAdjacent) {
        if (dr == -1) isFacing = sprite.direction == 'up';
        if (dr == 1) isFacing = sprite.direction == 'down';
        if (dc == -1) isFacing = sprite.direction == 'left';
        if (dc == 1) isFacing = sprite.direction == 'right';
      }

      if (isAdjacent && isFacing) {
        if (!sprite.attackCalculated) {
          sprite.attackCalculated = true;
          sprite.attackDecision = rng.nextDouble() < 0.05;
        }

        if (sprite.attackDecision) {
          // Trigger encounter animation instead of immediate battle
          sprite.isAlerted = true;
          sprite.alertTimer = 0.8; // 800ms alert for two jumps
          sprite.isMoving = false;
          sprite.walkFrame = 0;
          break;
        }
      } else {
        // Reset if no longer colliding
        sprite.attackCalculated = false;
        sprite.attackDecision = false;
      }
    }
    _overworldSprites.removeWhere((s) => toRemove.contains(s));
  }
}

class _FireflyParticle {
  double x, y;
  double phase;
  double speed;
  double driftDir;

  _FireflyParticle({
    required this.x,
    required this.y,
    required this.phase,
    required this.speed,
    required this.driftDir,
  });
}

// ────────────────────────────────────────────────────────────────────
// Grass Particle definition
// ────────────────────────────────────────────────────────────────────

class _GrassParticle {
  double x, y;
  double vx, vy;
  double life; // 1.0 to 0.0
  double size;
  double angle;
  final Color color;

  _GrassParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.size,
    required this.angle,
    required this.color,
  });
}

extension _GrassParticleExtension on _BiomeExplorationMapState {
  void _spawnGrassParticles(double centerX, double centerY) {
    final rng = Random();
    for (int i = 0; i < 2; i++) {
      final double vx = (rng.nextDouble() - 0.5) * 40;
      final double vy = -(rng.nextDouble() * 30 + 10);
      _grassParticles.add(
        _GrassParticle(
          x: centerX + (rng.nextDouble() - 0.5) * 10,
          y: centerY - 4,
          vx: vx,
          vy: vy,
          life: 1.0,
          size: 2.0 + rng.nextDouble() * 3.0,
          angle: rng.nextDouble() * pi * 2,
          color: Color.lerp(
            const Color(0xFF4B6F44),
            const Color(0xFF8BC34A),
            rng.nextDouble(),
          )!,
        ),
      );
    }
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
  final List<Point<int>> deployedCampfires;
  final int currentHour;
  final double zoomScale;
  final List<_FireflyParticle> fireflies;
  final List<_GrassParticle> grassParticles;
  final List<OverworldNPC> gameNPCs;
  final double grassAnimTime;
  final bool isIndoor;
  final Map<String, double> tileShakeOffsets;

  _BiomeMapPainter({
    required this.currentHour,
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
    this.isSwimming = false,
    this.bobbingOffset = 0,
    this.jumpOffset = 0,
    this.isOnFloating = false,
    this.overworldSprites = const [],
    this.deployedCampfires = const [],
    this.zoomScale = 1.0,
    this.fireflies = const [],
    this.grassParticles = const [],
    required this.gameNPCs,
    this.grassAnimTime = 0,
    this.isIndoor = false,
    this.tileShakeOffsets = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(zoomScale);

    // Calculate visible range (viewport culling)
    final int startCol = (cameraX / tileSize).floor().clamp(0, mapData.width);
    final int endCol = ((cameraX + size.width / zoomScale) / tileSize)
        .ceil()
        .clamp(0, mapData.width);
    final int startRow = (cameraY / tileSize).floor().clamp(0, mapData.height);
    final int endRow = ((cameraY + size.height / zoomScale) / tileSize)
        .ceil()
        .clamp(0, mapData.height);

    // 1. Ground Layer (Base Terrain + Floating Tiles)
    for (int r = startRow; r < endRow; r++) {
      for (int c = startCol; c < endCol; c++) {
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

    // ── Draw Deployed Campfires ──
    for (final cf in deployedCampfires) {
      if (cf.x >= startCol && cf.x <= endCol && cf.y >= startRow && cf.y <= endRow) {
        final double dx = (cf.x * tileSize - cameraX);
        final double dy = (cf.y * tileSize - cameraY);
        
        // Draw fire glow
        final double glowOpacity = (sin(grassAnimTime * 5) * 0.2 + 0.5);
        canvas.drawCircle(
          Offset(dx + tileSize / 2, dy + tileSize / 2),
          tileSize * 1.5,
          Paint()
            ..color = Colors.orangeAccent.withValues(alpha: glowOpacity * 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.0),
        );
        
        // Draw logs
        final paintLogs = Paint()..color = Colors.brown[800]!;
        canvas.drawRect(Rect.fromLTWH(dx + tileSize*0.2, dy + tileSize*0.7, tileSize*0.6, tileSize*0.2), paintLogs);
        canvas.drawRect(Rect.fromLTWH(dx + tileSize*0.4, dy + tileSize*0.6, tileSize*0.2, tileSize*0.4), paintLogs);
        
        // Draw flames
        final paintFlame = Paint()..color = Colors.orange;
        canvas.drawCircle(Offset(dx + tileSize / 2, dy + tileSize*0.5 + (sin(grassAnimTime * 10) * 2)), tileSize*0.25, paintFlame);
        paintFlame.color = Colors.yellow;
        canvas.drawCircle(Offset(dx + tileSize / 2, dy + tileSize*0.4 + (cos(grassAnimTime * 15) * 2)), tileSize*0.15, paintFlame);
      }
    }

    // 2. Object & Player Sorting Layer
    for (int r = startRow; r < endRow; r++) {
      // Draw non-tallgrass, non-floating overlay objects
      if (mapData.overlayGrid != null) {
        for (int c = startCol; c < endCol; c++) {
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

      // Draw NPCs (sorted by row)
      for (final npc in gameNPCs) {
        final double ny = npc.worldY * tileSize + tileSize / 2;
        if (ny >= r * tileSize && ny < (r + 1) * tileSize) {
          _drawNPC(canvas, npc);
        }
      }

      // Draw Tallgrass & other "above-player" overlays
      if (mapData.overlayGrid != null) {
        for (int c = startCol; c < endCol; c++) {
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
    if (!isIndoor) {
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

        // Draw Fireflies
        _drawFireflies(canvas);
      }

      // Draw Grass Particles (on top of most things but below weather)
      _drawGrassParticles(canvas);
    }
  }

  void _drawGrassParticles(Canvas canvas) {
    for (final p in grassParticles) {
      final double dx = (p.x - cameraX) * zoomScale;
      final double dy = (p.y - cameraY) * zoomScale;

      final paint = Paint()..color = p.color.withValues(alpha: p.life);

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(p.angle);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: p.size * zoomScale,
          height: p.size * 2 * zoomScale,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawFireflies(Canvas canvas) {
    for (final f in fireflies) {
      final double dx = f.x - cameraX;
      final double dy = f.y - cameraY;

      // Flicker opacity based on phase
      final double opacity = (sin(f.phase) * 0.5 + 0.5) * 0.8;

      final paint = Paint()
        ..color = Colors.yellowAccent.withValues(alpha: opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

      canvas.drawCircle(Offset(dx, dy), 1.5, paint);

      // Core glow
      canvas.drawCircle(
        Offset(dx, dy),
        0.8,
        Paint()..color = Colors.white.withValues(alpha: opacity),
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
    // Round to avoid jitter + apply shake offset if present (only for trees)
    final shakeKey = '$r:$c';
    final double shakeOff = (tile.tileId.toLowerCase().contains('tree'))
        ? (tileShakeOffsets[shakeKey] ?? 0.0)
        : 0.0;
    final double finalX = (c * tileSize - cameraX) + shakeOff;
    final double finalY = (r * tileSize - cameraY);
    final rect = Rect.fromLTWH(finalX, finalY, tileSize, tileSize);

    if (tile.tileId == 'teleporter') {
      return; // HIDE the default debug teleporter tile in-game
    }

    if (tile.tileId == 'empty' || tile.tileId == '') {
      // Make 'null' / 'empty' tiles black in the map as requested.
      final paint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, paint);
      return;
    }

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

      canvas.save();
      if (tile.category == TileCategory.tallGrass) {
        // Find if any entity is on this tile
        bool entityHere = false;
        final px = (playerX / tileSize).floor();
        final py = (playerY / tileSize).floor();
        if (px == c && py == r) entityHere = true;
        if (!entityHere) {
          for (final s in overworldSprites) {
            if (s.col == c && s.row == r) {
              entityHere = true;
              break;
            }
          }
        }

        // Apply gentle sway
        final double swaySpeed = entityHere ? 4.0 : 2.0;
        final double swayIntensity = entityHere ? 0.08 : 0.03;
        final double sway =
            sin(grassAnimTime * swaySpeed + (c + r * 1.5)) * swayIntensity;

        canvas.translate(rect.center.dx, rect.bottom);
        canvas.rotate(sway);
        canvas.translate(-rect.center.dx, -rect.bottom);
      }

      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, assetW, assetH),
        Rect.fromLTWH(drawX, drawY, drawW, drawH),
        Paint(),
      );
      canvas.restore();
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

    // Apply alert jump offset for encounter animation
    final double x = px - drawW / 2;
    final double y =
        (py + sprite.hopOffset + sprite.tileOffset + sprite.alertJumpOffset) -
        drawH / 2;

    if (sprite.tileOffset > 0) {
      // Clip the sprite so `tileOffset` pixels are hidden below the waterline
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(x, y, drawW, drawH - sprite.tileOffset));
    }

    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, assetW, assetH),
      Rect.fromLTWH(x, y, drawW, drawH),
      Paint(),
    );

    if (sprite.tileOffset > 0) {
      canvas.restore();
    }

    // Draw behavior label (except wandering)
    if (sprite.ecoState != EcoState.wandering && zoomScale > 0.8) {
      final labelSpan = TextSpan(
        text: sprite.behaviorLabel,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'PressStart2P',
          fontSize: 6 * zoomScale,
          background: Paint()
            ..color = Colors.black.withValues(alpha: 0.5)
            ..strokeJoin = StrokeJoin.round
            ..style = PaintingStyle.fill,
        ),
      );
      final textPainter = TextPainter(
        text: labelSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(px - textPainter.width / 2, y - textPainter.height - 4),
      );
    }
  }

  void _drawNPC(Canvas canvas, OverworldNPC npc) {
    // Correct world to pixel coordinates using tileSize
    final double px = (npc.worldX * tileSize - cameraX) + tileSize / 2;
    final double py = (npc.worldY * tileSize - cameraY) + tileSize / 2;

    final assets = BiomeDataManager.npcAssets[npc.data.spriteKey];
    if (assets == null) return;

    final dirSprites = assets[npc.direction];
    if (dirSprites == null || dirSprites.isEmpty) return;

    final img = dirSprites[npc.walkFrame % dirSprites.length];

    final double assetW = img.width.toDouble();
    final double assetH = img.height.toDouble();

    // NPCs are typically 32x32 based on the requirement
    final double drawW = tileSize;
    final double drawH = tileSize;

    final double x = px - drawW / 2;
    final double y = py - drawH / 2;

    // Draw shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(px, py + tileSize * 0.45),
        width: tileSize * 0.7,
        height: tileSize * 0.3,
      ),
      shadowPaint,
    );

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

class _DPadPainter extends CustomPainter {
  final String activeDir;
  final Color highlightColor;
  final Color borderColor;

  _DPadPainter({
    required this.activeDir,
    required this.highlightColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Draw solid background
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Draw active quadrant highlight
    if (activeDir.isNotEmpty) {
      final highlightPaint = Paint()
        ..color = highlightColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;

      final path = Path();
      path.moveTo(center.dx, center.dy);

      double startAngle;
      if (activeDir == 'right') {
        startAngle = -pi / 4;
      } else if (activeDir == 'down') {
        startAngle = pi / 4;
      } else if (activeDir == 'left') {
        startAngle = 3 * pi / 4;
      } else {
        startAngle = -3 * pi / 4; // Up
      }

      path.arcTo(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        pi / 2,
        false,
      );
      path.close();
      canvas.drawPath(path, highlightPaint);
    }

    // 3. Draw diagonal dividers (X)
    final linePaint = Paint()
      ..color = borderColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final double off = radius * 0.7071; // cos(45)
    canvas.drawLine(
      center + Offset(-off, -off),
      center + Offset(off, off),
      linePaint,
    );
    canvas.drawLine(
      center + Offset(off, -off),
      center + Offset(-off, off),
      linePaint,
    );

    // 4. Draw outer border
    final borderPaint = Paint()
      ..color = borderColor.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, borderPaint);

    // 5. Draw Labels (U, D, L, R)
    _drawLabel(
      canvas,
      center + Offset(0, -radius * 0.65),
      'U',
      activeDir == 'up',
    );
    _drawLabel(
      canvas,
      center + Offset(0, radius * 0.65),
      'D',
      activeDir == 'down',
    );
    _drawLabel(
      canvas,
      center + Offset(-radius * 0.65, 0),
      'L',
      activeDir == 'left',
    );
    _drawLabel(
      canvas,
      center + Offset(radius * 0.65, 0),
      'R',
      activeDir == 'right',
    );
  }

  void _drawLabel(Canvas canvas, Offset pos, String text, bool isActive) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: isActive ? Colors.white : borderColor.withValues(alpha: 0.6),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontFamily: 'PressStart2P',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _DPadPainter oldDelegate) =>
      oldDelegate.activeDir != activeDir ||
      oldDelegate.highlightColor != highlightColor;
}
