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
import 'package:animal_warfare/models/quest.dart';

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
  late Ticker _ticker;

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
  bool _cameraSnapped = true;

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
  final List<OverworldNPC> _gameNPCs = [];
  Timer? _phenoSpawnTimer;
  double _phenoTickAccumulator = 0;

  // ── Firefly Effect ──
  final List<_FireflyParticle> _fireflies = [];
  final List<Offset> _waterEdgeTiles = [];

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
          name: config.name,
          biomeId: config.biomeId,
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

    // Load saved state if available
    _loadSavedState();

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

    // Initialize NPCs from map data
    if (_mapData.npcs != null) {
      final userState = Provider.of<UserState>(context, listen: false);
      for (final npcData in _mapData.npcs!) {
        // Skip blocker NPCs whose requiredFlag is already satisfied
        if (npcData.scriptType == 'blocker' &&
            npcData.requiredFlag.isNotEmpty &&
            userState.hasFlag(npcData.requiredFlag)) {
          continue;
        }
        final npc = OverworldNPC(data: npcData);
        // Restore defeated state from persistent event flags
        if ((npcData.scriptType == 'trainer' ||
             npcData.scriptType == 'rival' ||
             npcData.scriptType == 'major_trainer' ||
             npcData.scriptType == 'evil_team') &&
            userState.isTrainerDefeated(npcData.id)) {
          npc.isDefeated = true;
          npc.hasTriggeredBattle = true;
        }
        _gameNPCs.add(npc);
      }
    }

    // Initialize firefly spawn points
    _initializeFireflyPoints();
  }

  void _initializeFireflyPoints() {
    if (widget.biomeName.toLowerCase() != 'swamp') return;

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

    // ── Overworld sprite AI ──
    _phenoTickAccumulator += dt;
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
        _overworldSprites.removeWhere((s) => s.isExpired);
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

    // ── Update Fireflies ──
    if (widget.biomeName.toLowerCase() == 'swamp') {
      final hour = TimeService().currentGameTime.hour;
      final bool isNight = hour >= 21 || hour < 6;
      if (isNight) {
        for (final f in _fireflies) {
          f.x += cos(f.driftDir) * f.speed;
          f.y += sin(f.driftDir) * f.speed;
          f.driftDir += (Random().nextDouble() - 0.5) * 0.1;
          f.phase += dt * 2;
        }
        if (mounted) setState(() {});
      }
    }

    // Player controls (only if not in an encounter)
    if (!_encounterActive) {
      if (_isMovingToTarget) {
        _moveTowardsTarget();
        // Camera update AFTER movement — this frame's position, zero lag
        _updateCamera();
        return;
      }

      // Advance animation if directions are held
      if (_activeDirections.isNotEmpty) {
        final double speed = _isRunning ? 8.0 : 4.0;
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
      if (targetR >= 0 && targetR < _mapData.height && targetC >= 0 && targetC < _mapData.width) {
        final tile = _mapData.grid[targetR][targetC];
        final overlays = _mapData.overlayGrid?[targetR][targetC];
        final bool isOneWay = tile.category == TileCategory.oneway || 
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
        _checkStepEncounter(
          ((_playerY + tileSize / 2) / tileSize).floor(),
          ((_playerX + tileSize / 2) / tileSize).floor(),
        );

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
      });
    }
  }

  // ── Collision ──
  bool _canWalkAt(double x, double y, {bool? isSwimmingOverride, bool ignoreEntities = false}) {
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
      final bool isSolid =
          baseTile.category == TileCategory.solid ||
          (overlayTile?.any((t) => t.category == TileCategory.solid) ?? false);
      final bool isFloating =
          baseTile.category == TileCategory.floating ||
          (overlayTile?.any((t) => t.category == TileCategory.floating) ??
              false);

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

    // Check both base and overlay for encounter tiles (like tallgrass)
    final baseTile = _mapData.grid[row][col];
    final overlayTiles = _mapData.overlayGrid?[row][col];

    MapTile? encounterTile;
    if (overlayTiles != null) {
      for (final t in overlayTiles) {
        if (t.hasEncounter || t.category == TileCategory.teleporter) {
          encounterTile = t;
          break; // Use the first encounter or teleporter tile found in overlays
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
          _isMovingToTarget = false;
          _activeDirections.clear();
          _playerX = col * tileSize;
          _playerY = row * tileSize;
          _walkFrame = 0;
          _walkAnimAccumulator = 0.0;
        });

        _triggerEncounter(activeTile);
      }
    } else if (activeTile.category == TileCategory.teleporter) {
      _handleTeleport(row, col);
    }
  }

  void _handleTeleport(int row, int col) {
    final transitions = _mapData.transitions ?? _mapData.config.transitions;
    if (transitions == null) return;
    for (final t in transitions) {
      if (t.x == col && t.y == row) {
        _executeTransition(t);
        return;
      }
    }
  }

  Future<void> _executeTransition(MapTransition t) async {
    // Determine target config
    late BiomeConfig targetConfig;

    try {
      targetConfig = BiomeDataManager.getBiome(t.targetMap);
    } catch (_) {
      // Fallback
      return; 
    }

    // Attempt to load map data to override spawn
    final targetMapData = MapStringParser.parse(
      targetConfig.layout ?? {'base': []},
      config: targetConfig,
      spawn: Point<int>(t.targetX, t.targetY),
      name: targetConfig.name,
      biomeId: targetConfig.biomeId,
    );

    // Stop movement and reset camera pan so next map is clean
    setState(() {
      _velX = 0;
      _velY = 0;
      _isMovingToTarget = false;
      _walkFrame = 0;
    });

    await _saveCurrentState();
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => BiomeExplorationMap(
          biomeName: targetConfig.name,
          allOrganisms: widget.allOrganisms,
          currentUser: widget.currentUser,
          authService: widget.authService,
          customMapData: targetMapData,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
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
    _saveCurrentState(); // Save state on exit
    AudioService.instance.stopAll();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _loadSavedState() {
    final userState = Provider.of<UserState>(context, listen: false);
    final saved = userState.getMapState(widget.biomeName.toLowerCase());
    if (saved != null) {
      _playerX = saved.playerX;
      _playerY = saved.playerY;
      _playerDirection = saved.playerDirection;
      _isSwimming = saved.isSwimming;
    }
  }

  Future<void> _saveCurrentState() async {
    final userState = Provider.of<UserState>(context, listen: false);
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
    await userState.saveMapState(widget.biomeName.toLowerCase(), state);
    // Persist the current map as the last-visited zone
    await userState.updateCurrentMapId(widget.biomeName.toLowerCase());
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
      biomeId: _mapData.biomeId,
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

  void _onFight(Organism wildOrganism, String encounterTileId) async {
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
        Organism.humanOrganism.copyWith(name: user.username),
        level: user.accountLevel,
      );
    }

    final wildFighter = CapturedOrganism.spawn(
      wildOrganism,
      accountLevel: user.accountLevel,
      captureLocation: widget.biomeName,
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
          biomeName: widget.biomeName,
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
        // Teleport to spawn on whiteout
        _playerX = _mapData.spawnPoint.x * tileSize;
        _playerY = _mapData.spawnPoint.y * tileSize;

        // Reset movement states
        _isMovingToTarget = false;
        _velX = 0;
        _velY = 0;

        // Update camera
        _scrollToPlayer();

        _showInteractionBubble('You were defeated and returned to spawn.',
            icon: '💀');
      }

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
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (didPop) {
          _saveCurrentState();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          centerTitle: true,
          title: Text((_mapData.name ?? widget.biomeName).toUpperCase()),
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
            // Animal Menu
            _buildAnimalMenuButton(),
            // Floating Coordinates
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                      (_mapData.name ?? widget.biomeName).toUpperCase(),
                      style: TextStyle(
                        color: _biomeHighlightColor,
                        fontFamily: 'monospace',
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'COORD: ${(_playerX / tileSize).floor()}, ${(_playerY / tileSize).floor()}',
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
              fireflies: _fireflies,
              gameNPCs: _gameNPCs,
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

  Widget _buildAnimalMenuButton() {
    return Positioned(
      top: 200,
      right: 16,
      child: GestureDetector(
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
    );
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
                title: 'Animal Box',
                subtitle: 'Manage your collection & team',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => const AnimalBoxScreen(),
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
                    MaterialPageRoute(
                      builder: (_) => const CraftingScreen(),
                    ),
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
                  final userState = Provider.of<UserState>(ctx, listen: false);
                  final user = userState.currentUser;
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
    // Water edge (not swimming, facing water)
    if (!_isSwimming && isWater && !canSwimHere) {
      _showInteractionBubble('💧 The water looks deep...', icon: '💧');
      return;
    }

    // Tall grass rustle
    bool isTallGrass =
        baseDef?.category == TileCategory.tallGrass ||
        (overlayTiles?.any((t) {
              final def = BiomeDataManager.allTiles[t.tileId];
              return def?.category == TileCategory.tallGrass;
            }) ??
            false);
    if (isTallGrass) {
      final messages = [
        '🌿 The grass rustles...',
        '🌱 Something might be hiding in here!',
        '🍃 You feel a gust of wind through the grass.',
      ];
      final msg = messages[Random().nextInt(messages.length)];
      _showInteractionBubble(msg);
      return;
    }

    // Fishing spot (swimming, press A facing water)
    if (_isSwimming && isWater) {
      _showInteractionBubble('🎣 You could fish here!');
      return;
    }

    // Rest spot
    if (textToShow != null && textToShow.startsWith('REST:')) {
      final restMsg = textToShow.substring(5);
      _showConfirmationDialog(
        restMsg.isNotEmpty ? restMsg : 'Rest here and recover?',
        () {
          _showInteractionBubble('💤 You feel refreshed!');
        },
      );
      return;
    }

    if (textToShow != null) {
      _showInteractionBubble(textToShow);
    }
  }

  void _showNPCDialogue(OverworldNPC npc) {
    // Face the player
    int currentR = ((_playerY + tileSize / 2) / tileSize).floor();
    int currentC = ((_playerX + tileSize / 2) / tileSize).floor();

    if (currentR < npc.gridRow) npc.direction = 'up';
    if (currentR > npc.gridRow) npc.direction = 'down';
    if (currentC < npc.gridCol) npc.direction = 'left';
    if (currentC > npc.gridCol) npc.direction = 'right';

    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    _showInteractionBubble('$displayName${npc.data.dialogue.join('\n')}', icon: '💬');

    // Script-based interactions
    if (npc.data.scriptType == 'trainer' ||
        npc.data.scriptType == 'rival' ||
        npc.data.scriptType == 'major_trainer' ||
        npc.data.scriptType == 'evil_team') {
      // Don't interact normally with trainers — they handle via vision
      if (!npc.isDefeated) {
        _startTrainerBattle(npc);
      } else {
        _showInteractionBubble('${npc.data.name}: ${npc.data.defeatText.isNotEmpty ? npc.data.defeatText : "..."}', icon: '💬');
      }
      return;
    } else if (npc.data.scriptType == 'shopkeeper') {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShopScreen(biome: widget.biomeName),
            ),
          );
        }
      });
    } else if (npc.data.scriptType == 'medic') {
      // Simple heal effect
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showInteractionBubble('✨ Your team has been fully healed!', icon: '💖');
          // In a real implementation we'd call user_state to heal organisms
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
    }
  }

  void _handleQuestGiverNPC(OverworldNPC npc) {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    // Check if the quest is already completed in event flags
    if (npc.data.questId.isNotEmpty &&
        userState.eventFlags.isQuestCompleted(npc.data.questId)) {
      // Post-event dialogue
      final postDialogue = npc.data.postEventDialogue.isNotEmpty
          ? npc.data.postEventDialogue.join('\n')
          : 'Thanks for your help!';
      _showInteractionBubble('${npc.data.name}: $postDialogue', icon: '💬');
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
        _showInteractionBubble('${npc.data.name}: Excellent work!', icon: '✅');
        userState.markQuestCompleted(npc.data.questId);
        if (npc.data.setsFlag.isNotEmpty) {
          userState.setFlag(npc.data.setsFlag);
        }
      } else {
        _showInteractionBubble(
            '${npc.data.name}: ${q.description} (${q.currentCount}/${q.targetCount})',
            icon: '📋');
      }
      return;
    }

    // Offer the quest
    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    _showInteractionBubble(
        '$displayName${npc.data.dialogue.join('\n')}', icon: '❗');
    // TODO: Add quest accept UI — for now auto-accept
    if (npc.data.questId.isNotEmpty) {
      final quest = Quest(
        id: npc.data.questId,
        description: npc.data.dialogue.isNotEmpty ? npc.data.dialogue.first : 'Complete the quest.',
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
    final userState = Provider.of<UserState>(context, listen: false);

    // Check if story has been read (flag already set)
    if (npc.data.setsFlag.isNotEmpty && userState.hasFlag(npc.data.setsFlag)) {
      // Post-event dialogue
      final postDialogue = npc.data.postEventDialogue.isNotEmpty
          ? npc.data.postEventDialogue.join('\n')
          : '...';
      _showInteractionBubble('${npc.data.name}: $postDialogue', icon: '💬');
      return;
    }

    // Show story dialogue
    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    _showInteractionBubble(
        '$displayName${npc.data.dialogue.join('\n')}', icon: '📖');

    // Set flag after reading
    if (npc.data.setsFlag.isNotEmpty) {
      userState.setFlag(npc.data.setsFlag);
    }
  }

  void _handleBlockerNPC(OverworldNPC npc) {
    final userState = Provider.of<UserState>(context, listen: false);

    // If requiredFlag is now satisfied, remove the NPC from the map
    if (npc.data.requiredFlag.isNotEmpty &&
        userState.hasFlag(npc.data.requiredFlag)) {
      _gameNPCs.remove(npc);
      _showInteractionBubble('The path is now clear!', icon: '✅');
      setState(() {});
      return;
    }

    // Show blocking dialogue
    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    _showInteractionBubble(
        '$displayName${npc.data.dialogue.join('\n')}', icon: '⛔');
  }

  void _handleItemGiverNPC(OverworldNPC npc) {
    final userState = Provider.of<UserState>(context, listen: false);

    // Check if item already collected
    final itemKey = '${npc.data.id}_item';
    if (userState.eventFlags.isItemCollected(itemKey)) {
      final postDialogue = npc.data.postEventDialogue.isNotEmpty
          ? npc.data.postEventDialogue.join('\n')
          : 'I have nothing more for you.';
      _showInteractionBubble('${npc.data.name}: $postDialogue', icon: '💬');
      return;
    }

    // Give the item
    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    _showInteractionBubble(
        '$displayName${npc.data.dialogue.join('\n')}', icon: '🎁');

    if (npc.data.itemRewardId.isNotEmpty) {
      userState.addLoot(npc.data.itemRewardId, npc.data.itemRewardCount);
      userState.markItemCollected(itemKey);
      if (npc.data.setsFlag.isNotEmpty) {
        userState.setFlag(npc.data.setsFlag);
      }
    }
  }

  void _handleFetchQuestNPC(OverworldNPC npc) {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    // Check if already done
    if (npc.data.setsFlag.isNotEmpty && userState.hasFlag(npc.data.setsFlag)) {
      final postDialogue = npc.data.postEventDialogue.isNotEmpty
          ? npc.data.postEventDialogue.join('\n')
          : 'Thanks for your help!';
      _showInteractionBubble('${npc.data.name}: $postDialogue', icon: '💬');
      return;
    }

    // Determine what is needed
    bool hasRequirements = false;
    if (npc.data.itemRequiredId.isNotEmpty) {
      final count = user.inventory[npc.data.itemRequiredId] ?? 0;
      hasRequirements = count >= npc.data.itemRequiredCount;
    } else if (npc.data.organismRequiredId.isNotEmpty) {
      hasRequirements = user.capturedOrganisms.any((o) =>
          o.baseOrganism.name.toLowerCase() ==
          npc.data.organismRequiredId.toLowerCase());
    } else {
      hasRequirements = true;
    }

    if (hasRequirements) {
      _showInteractionBubble('${npc.data.name}: You have what I need! Thank you!', icon: '✅');
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
      _showInteractionBubble('$displayName${npc.data.dialogue.join('\n')}', icon: '❗');
    }
  }

  void _handleProfessorNPC(OverworldNPC npc) {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    final dexCount = user.discoveredOrganisms.length;
    
    // Check milestone (using itemRequiredCount as milestone target)
    if (npc.data.itemRewardId.isNotEmpty && npc.data.itemRequiredCount > 0) {
      final itemKey = '${npc.data.id}_milestone';
      if (!userState.hasFlag(itemKey) && dexCount >= npc.data.itemRequiredCount) {
        _showInteractionBubble('${npc.data.name}: Excellent! You found ${npc.data.itemRequiredCount} species! Take this reward!', icon: '🎁');
        userState.addLoot(npc.data.itemRewardId, npc.data.itemRewardCount);
        userState.setFlag(itemKey);
        return;
      }
    }
    
    _showInteractionBubble('${npc.data.name}: You have discovered $dexCount species so far! Keep up the good work!', icon: '🔬');
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
        _showInteractionBubble('!', icon: '❗');
        break;
      }
    }
  }

  void _startTrainerBattle(OverworldNPC npc) async {
    final userState = Provider.of<UserState>(context, listen: false);
    final user = userState.currentUser;
    if (user == null) return;

    // Show initial dialogue
    final displayName = npc.data.name.isNotEmpty ? '${npc.data.name}: ' : '';
    final dialogueText = npc.data.dialogue.isNotEmpty ? npc.data.dialogue.join('\n') : 'Let\'s battle!';
    _showInteractionBubble('$displayName$dialogueText', icon: '💬');

    // Wait for player to read dialogue
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;

    // Build opponent team from npc_teams.json
    final opponentTeam = NpcTeamLoader.buildTeam(npc.data.teamId, widget.allOrganisms);
    if (opponentTeam.isEmpty) {
      print('BiomeExplorationMap: Opponent team is empty for ${npc.data.teamId}. Cannot start battle.');
      _showInteractionBubble('I have no animals to fight with...', icon: '💬');
      
      await Future.delayed(const Duration(milliseconds: 2000));
      if (!mounted) return;
      
      setState(() => _encounterActive = false);
      _approachingNPC = null;
      npc.hasTriggeredBattle = false;
      return;
    }

    // Get player's fighter
    CapturedOrganism playerFighter;
    if (user.teamOrganisms.isNotEmpty) {
      playerFighter = user.teamOrganisms.first;
    } else if (user.capturedOrganisms.isNotEmpty) {
      playerFighter = user.capturedOrganisms.first;
    } else {
      playerFighter = CapturedOrganism.spawn(
        Organism.humanOrganism.copyWith(name: user.username),
        level: user.accountLevel,
      );
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

    final BattleResult? result = await Navigator.of(context).push<BattleResult>(
      MaterialPageRoute(
        builder: (context) => BattleScreen(
          playerOrganism: playerFighter,
          opponentOrganism: opponentTeam.first,
          biomeName: widget.biomeName,
          playerTeam: user.teamOrganisms,
          opponentTeam: opponentTeam,
          battleTitle: 'VS $trainerName',
          isTrainerBattle: true,
          timeOfDay: timeOfDay,
          mapScreenshot: mapScreenshot,
        ),
      ),
    );
    AudioService.instance.resumeAll();

    if (mounted) {
      bool won = result == BattleResult.win || result == BattleResult.capture;

      if (won) {
        // Mark as defeated permanently
        npc.isDefeated = true;
        npc.hasTriggeredBattle = true;

        // Persist to event flags
        final userState = Provider.of<UserState>(context, listen: false);
        await userState.markTrainerDefeated(npc.data.id);
        if (npc.data.setsFlag.isNotEmpty) {
          await userState.setFlag(npc.data.setsFlag);
        }

        // Show defeat text
        if (npc.data.defeatText.isNotEmpty) {
          _showInteractionBubble('${npc.data.name}: ${npc.data.defeatText}',
              icon: '💬');
        }
      } else if (result == BattleResult.loss) {
        // Teleport to spawn
        _playerX = _mapData.spawnPoint.x * tileSize;
        _playerY = _mapData.spawnPoint.y * tileSize;

        // Update camera
        _scrollToPlayer();

        // Allow re-challenge
        npc.hasTriggeredBattle = false;

        _showInteractionBubble('You were defeated and returned to spawn.',
            icon: '💀');
        
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

  void _showInteractionBubble(String text, {String? icon}) {
    setState(() {
      _bubbleText = text;
      _interactionTilePos = Offset(_playerX, _playerY - tileSize);
    });
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _bubbleText = null);
    });
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
    if (dist < 2.0) {
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
            (overlay?.any((t) => t.category == TileCategory.solid) ?? false)) {
          continue;
        }

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

// ────────────────────────────────────────────────────────────────────
// Firefly Particle definition
// ────────────────────────────────────────────────────────────────────

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
  final List<_FireflyParticle> fireflies;
  final List<OverworldNPC> gameNPCs;

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
    this.zoomScale = 1.0,
    this.fireflies = const [],
    required this.gameNPCs,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(zoomScale);

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

      // Draw NPCs (sorted by row)
      for (final npc in gameNPCs) {
        final double ny = npc.worldY * tileSize + tileSize / 2;
        if (ny >= r * tileSize && ny < (r + 1) * tileSize) {
          _drawNPC(canvas, npc);
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

      // Draw Fireflies
      _drawFireflies(canvas);
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
    // Round to avoid jitter
    final double finalX = (c * tileSize - cameraX);
    final double finalY = (r * tileSize - cameraY);
    final rect = Rect.fromLTWH(finalX, finalY, tileSize, tileSize);

    if (tile.category == TileCategory.teleporter) return; // HIDE teleporters in-game

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
