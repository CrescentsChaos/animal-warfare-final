// lib/game/overworld_sprite.dart
//
// Represents a roaming animal NPC ("pheno") on the biome exploration map.
// Movement behaviour is driven by the sprite's Nature.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:animal_warfare/game/biome_map_data.dart';
import 'package:animal_warfare/models/organism.dart';
import 'package:animal_warfare/models/nature.dart';

// ── Behaviour profile derived from Nature ──────────────────────────────────

class _AiProfile {
  /// Movement speed in pixels per AI tick (player is ~2.0).
  final double speed;

  /// Min/max idle cooldown between moves (seconds).
  final double cooldownMin;
  final double cooldownMax;

  /// How this sprite reacts to the player:
  ///   positive = attracted (moves toward player)
  ///   negative = repelled (moves away from player)
  ///   zero     = ignores player (random wander)
  final double playerAffinity;

  /// Chance [0‑1] per move decision to pick a completely random direction
  /// instead of following affinity.  High = erratic / unpredictable.
  final double erraticChance;

  /// How many tiles the sprite can move in a burst before pausing.
  /// 1 = one step at a time,  2‑3 = short dashes.
  final int burstLength;

  const _AiProfile({
    required this.speed,
    required this.cooldownMin,
    required this.cooldownMax,
    required this.playerAffinity,
    this.erraticChance = 0.0,
    this.burstLength = 1,
  });
}

_AiProfile _profileForNature(String natureName) {
  switch (natureName) {
    // ── Aggressive / approaches player ──
    case 'Adamant':
      return const _AiProfile(
        speed: 1.4,
        cooldownMin: 0.5,
        cooldownMax: 1.5,
        playerAffinity: 0.9,
        burstLength: 2,
      );
    case 'Naughty':
      return const _AiProfile(
        speed: 1.5,
        cooldownMin: 0.4,
        cooldownMax: 1.2,
        playerAffinity: 0.85,
        erraticChance: 0.2,
        burstLength: 2,
      );
    case 'Brave':
      return const _AiProfile(
        speed: 0.7,
        cooldownMin: 1.0,
        cooldownMax: 2.5,
        playerAffinity: 0.95,
        burstLength: 1,
      );
    case 'Lonely':
      return const _AiProfile(
        speed: 1.0,
        cooldownMin: 0.8,
        cooldownMax: 2.0,
        playerAffinity: 0.6,
        burstLength: 1,
      );
    case 'Rash':
      return const _AiProfile(
        speed: 1.8,
        cooldownMin: 0.3,
        cooldownMax: 0.8,
        playerAffinity: 0.7,
        erraticChance: 0.35,
        burstLength: 3,
      );

    // ── Timid / flees from player ──
    case 'Timid':
      return const _AiProfile(
        speed: 1.8,
        cooldownMin: 0.3,
        cooldownMax: 1.0,
        playerAffinity: -0.95,
        burstLength: 3,
      );
    case 'Bashful':
      return const _AiProfile(
        speed: 1.0,
        cooldownMin: 1.5,
        cooldownMax: 3.5,
        playerAffinity: -0.6,
        burstLength: 1,
      );
    case 'Gentle':
      return const _AiProfile(
        speed: 0.6,
        cooldownMin: 2.0,
        cooldownMax: 4.0,
        playerAffinity: -0.4,
        burstLength: 1,
      );
    case 'Mild':
      return const _AiProfile(
        speed: 0.8,
        cooldownMin: 1.5,
        cooldownMax: 3.0,
        playerAffinity: -0.5,
        burstLength: 1,
      );
    case 'Calm':
      return const _AiProfile(
        speed: 0.5,
        cooldownMin: 2.5,
        cooldownMax: 5.0,
        playerAffinity: -0.3,
        burstLength: 1,
      );
    case 'Careful':
      return const _AiProfile(
        speed: 0.7,
        cooldownMin: 2.0,
        cooldownMax: 4.0,
        playerAffinity: -0.7,
        burstLength: 1,
      );

    // ── Playful / fast / bouncy ──
    case 'Jolly':
      return const _AiProfile(
        speed: 1.6,
        cooldownMin: 0.3,
        cooldownMax: 1.0,
        playerAffinity: 0.0,
        erraticChance: 0.5,
        burstLength: 2,
      );
    case 'Hasty':
      return const _AiProfile(
        speed: 2.0,
        cooldownMin: 0.2,
        cooldownMax: 0.6,
        playerAffinity: 0.0,
        erraticChance: 0.4,
        burstLength: 3,
      );
    case 'Naive':
      return const _AiProfile(
        speed: 1.4,
        cooldownMin: 0.5,
        cooldownMax: 1.5,
        playerAffinity: 0.4,
        erraticChance: 0.6,
        burstLength: 2,
      );
    case 'Impish':
      return const _AiProfile(
        speed: 1.3,
        cooldownMin: 0.5,
        cooldownMax: 1.5,
        playerAffinity: 0.3,
        erraticChance: 0.7,
        burstLength: 2,
      );

    // ── Slow / stationary / lazy ──
    case 'Quiet':
      return const _AiProfile(
        speed: 0.3,
        cooldownMin: 4.0,
        cooldownMax: 8.0,
        playerAffinity: 0.0,
        burstLength: 1,
      );
    case 'Relaxed':
      return const _AiProfile(
        speed: 0.4,
        cooldownMin: 3.0,
        cooldownMax: 6.0,
        playerAffinity: 0.0,
        burstLength: 1,
      );
    case 'Lax':
      return const _AiProfile(
        speed: 0.5,
        cooldownMin: 2.5,
        cooldownMax: 5.0,
        playerAffinity: 0.0,
        burstLength: 1,
      );
    case 'Docile':
      return const _AiProfile(
        speed: 0.5,
        cooldownMin: 3.0,
        cooldownMax: 6.0,
        playerAffinity: 0.0,
        burstLength: 1,
      );
    case 'Modest':
      return const _AiProfile(
        speed: 0.6,
        cooldownMin: 2.5,
        cooldownMax: 4.5,
        playerAffinity: -0.2,
        burstLength: 1,
      );
    case 'Sassy':
      return const _AiProfile(
        speed: 0.8,
        cooldownMin: 1.5,
        cooldownMax: 3.5,
        playerAffinity: -0.5,
        erraticChance: 0.3,
        burstLength: 1,
      );

    // ── Steady / neutral ──
    case 'Bold':
      return const _AiProfile(
        speed: 0.9,
        cooldownMin: 1.0,
        cooldownMax: 2.5,
        playerAffinity: 0.2,
        burstLength: 1,
      );
    case 'Serious':
      return const _AiProfile(
        speed: 1.0,
        cooldownMin: 1.0,
        cooldownMax: 2.5,
        playerAffinity: 0.0,
        burstLength: 1,
      );
    case 'Quirky':
      return const _AiProfile(
        speed: 1.1,
        cooldownMin: 0.5,
        cooldownMax: 3.0,
        playerAffinity: 0.0,
        erraticChance: 0.8,
        burstLength: 2,
      );

    // Hardy (default / fallback)
    case 'Hardy':
    default:
      return const _AiProfile(
        speed: 1.0,
        cooldownMin: 1.5,
        cooldownMax: 3.5,
        playerAffinity: 0.0,
        burstLength: 1,
      );
  }
}

// ── OverworldSprite ─────────────────────────────────────────────────────────

class OverworldSprite {
  final Organism organism;
  final DateTime spawnTime;
  final Nature nature;
  late final _AiProfile _profile;

  // Grid position
  int row;
  int col;

  // Pixel position for smooth movement
  double pixelX;
  double pixelY;

  // Movement target
  int targetRow;
  int targetCol;
  double targetPixelX;
  double targetPixelY;
  bool isMoving = false;

  // Burst movement (multi-step moves)
  int _burstRemaining = 0;

  // Animation
  String direction = 'down';
  int walkFrame = 0;
  double walkAnimAccumulator = 0.0;
  double tileOffset =
      0.0; // Vertical offset based on tile type (lily pads, water)

  // AI timing
  double _aiCooldown = 0;
  double _cryCooldown = 0;
  bool shouldPlayCry = false;

  // Hopping (Frogs)
  bool isHopping = false;
  double hopProgress = 0.0;
  double get hopOffset => isHopping ? -sin(hopProgress * pi) * 12.0 : 0.0;

  // Player position tracking (set externally before tick)
  double playerPixelX = 0;
  double playerPixelY = 0;
  double playerTargetPixelX = 0;
  double playerTargetPixelY = 0;

  // AI State
  List<int>? _currentBurstDir; // Current direction for a burst move [dr, dc]
  bool attackCalculated =
      false; // Whether we've rolled for the 30% attack chance
  bool attackDecision = false; // Whether the roll resulted in an attack

  // Alert/Encounter animation
  bool isAlerted = false;
  double alertTimer = 0.0;
  double shakeOffset = 0.0;

  // Loaded directional sprites (up/down/left/right)
  Map<String, ui.Image> sprites = {};

  OverworldSprite({
    required this.organism,
    required this.row,
    required this.col,
    required double tileSize,
    DateTime? spawnTime,
    Nature? nature,
  }) : spawnTime = spawnTime ?? DateTime.now(),
       nature = nature ?? Nature.getRandom(),
       pixelX = col * tileSize,
       pixelY = row * tileSize,
       targetRow = row,
       targetCol = col,
       targetPixelX = col * tileSize,
       targetPixelY = row * tileSize {
    _profile = _profileForNature(this.nature.name);
    // Random initial cooldown so sprites don't all move in sync
    _aiCooldown =
        _profile.cooldownMin +
        Random().nextDouble() * (_profile.cooldownMax - _profile.cooldownMin);
    // Ambient cry cooldown (20-60 seconds)
    _cryCooldown = 20.0 + Random().nextDouble() * 40.0;
  }

  /// Whether this sprite has expired (older than 60 seconds).
  bool get isExpired => DateTime.now().difference(spawnTime).inSeconds >= 60;

  /// Parse the organism's move_tiles from config (or spawn_tiles fallback) into a set of identifiers.
  Set<String> get _validMovementTiles {
    final spawnData = BiomeDataManager.phenoSpawnData[organism.pheno];
    final moveTiles = (spawnData != null && spawnData.moveTiles.isNotEmpty)
        ? spawnData.moveTiles
        : organism.spawnTiles;

    // Merge both sources to ensure species can move wherever they can spawn (plus extras)
    final combined = '$moveTiles,${organism.spawnTiles}';
    if (combined.contains('any')) return {};

    return combined
        .split(',')
        .map((e) => e.trim().toLowerCase().replaceAll('_', ''))
        .where((e) => e.isNotEmpty && e != 'any')
        .toSet();
  }

  /// Check if a tile at (r, c) is valid for this sprite to walk on.
  bool _canMoveTo(int r, int c, BiomeMapData mapData) {
    if (r < 0 || r >= mapData.height || c < 0 || c >= mapData.width) {
      return false;
    }

    final baseTile = mapData.grid[r][c];
    final overlayTile = mapData.overlayGrid?[r][c];

    // Check if solid — never walk on solid tiles
    if (baseTile.category == TileCategory.solid ||
        (overlayTile?.any((t) => t.category == TileCategory.solid) ?? false)) {
      return false;
    }

    final validTilesSet = _validMovementTiles;
    if (validTilesSet.isEmpty) return true; // 'any'

    // Check tile IDs
    final normalizedId = baseTile.tileId.toLowerCase().replaceAll('_', '');
    if (validTilesSet.contains(normalizedId)) return true;

    if (overlayTile != null) {
      for (final ot in overlayTile) {
        if (validTilesSet.contains(
          ot.tileId.toLowerCase().replaceAll('_', ''),
        )) {
          return true;
        }
      }
    }

    // Check categories
    final baseCategory = baseTile.category.name.toLowerCase().replaceAll(
      '_',
      '',
    );
    if (validTilesSet.contains(baseCategory)) return true;

    if (overlayTile != null) {
      for (final ot in overlayTile) {
        final oc = ot.category.name.toLowerCase().replaceAll('_', '');
        if (validTilesSet.contains(oc)) return true;
      }
    }

    // NEW: Fallback category match. If the animal can move on ANY tile of this category,
    // allow it. This solves mismatches where move_tiles has 'pond_water' but map has 'water'.
    for (final vt in validTilesSet) {
      // Find a tile in the registry that matches this move_tile ID
      final tileDef = BiomeDataManager.allTiles.values.firstWhere(
        (t) => t.id.toLowerCase().replaceAll('_', '') == vt,
        orElse: () => BiomeDataManager.allTiles.values.first,
      );
      if (tileDef.id.toLowerCase().replaceAll('_', '') == vt) {
        if (tileDef.category == baseTile.category) return true;
        if (overlayTile != null &&
            overlayTile.any((ot) => ot.category == tileDef.category)) {
          return true;
        }
      }
    }

    return false;
  }

  /// AI tick — called from _onTick. Returns true if state changed.
  bool tick(
    double dt,
    BiomeMapData mapData,
    double tileSize, {
    List<OverworldSprite> otherSprites = const [],
    double? pTargetX,
    double? pTargetY,
  }) {
    if (pTargetX != null) playerTargetPixelX = pTargetX;
    if (pTargetY != null) playerTargetPixelY = pTargetY;

    if (isExpired) return false;

    bool changed = false;

    if (isMoving) {
      // Move towards target
      final double spawnSpeedMult =
          BiomeDataManager.phenoSpawnData[organism.pheno]?.defaultSpeed ?? 1.0;

      // Tile-based speed modifier (frogs and other semi-aquatic animals go faster in water)
      double tileSpeedMult = 1.0;
      final currentTile = mapData.grid[row][col];
      final currentOverlays = mapData.overlayGrid?[row][col];
      bool inWater =
          currentTile.category == TileCategory.water ||
          (currentOverlays?.any((t) => t.category == TileCategory.water) ??
              false);

      bool isSemiAquatic =
          organism.spawnTiles.contains('water') ||
          organism.habitat.toLowerCase().contains('water') ||
          organism.habitat.toLowerCase().contains('swamp') ||
          organism.pheno == 'frog' ||
          organism.pheno == 'Hfrog';

      if (inWater && isSemiAquatic) {
        tileSpeedMult = 1.5; // 50% speed boost in water
      }

      final double speed = _profile.speed * spawnSpeedMult * tileSpeedMult;
      final dx = targetPixelX - pixelX;
      final dy = targetPixelY - pixelY;
      final dist = sqrt(dx * dx + dy * dy);

      if (dist <= speed) {
        // Reached target
        pixelX = targetPixelX;
        pixelY = targetPixelY;
        row = targetRow;
        col = targetCol;
        isMoving = false;
        walkFrame = 0;
        walkAnimAccumulator = 0.0;

        // If burst has more steps, pick next move immediately
        if (_burstRemaining > 0) {
          _burstRemaining--;
          _pickAiMove(mapData, tileSize, otherSprites: otherSprites);
        } else {
          _aiCooldown =
              _profile.cooldownMin +
              Random().nextDouble() *
                  (_profile.cooldownMax - _profile.cooldownMin);
        }
      } else {
        // Move closer
        final vx = dx / dist;
        final vy = dy / dist;
        pixelX += vx * speed;
        pixelY += vy * speed;

        // Walk/Hop animation
        walkAnimAccumulator += speed;
        if (isHopping) {
          double currentMoved = sqrt(
            pow(pixelX - (col * tileSize), 2) +
                pow(pixelY - (row * tileSize), 2),
          );
          hopProgress = (currentMoved / tileSize).clamp(0.0, 1.0);
        } else {
          if (walkAnimAccumulator >= tileSize / 2) {
            walkAnimAccumulator -= tileSize / 2;
            walkFrame = (walkFrame == 1) ? 2 : 1;
          }
        }
      }
      changed = true;
    } else {
      // Waiting — count down AI cooldown
      isHopping = false; // Ensure hopping is reset when idling
      if (!isAlerted) {
        if (_aiCooldown > 0) {
          _aiCooldown -= dt;
        }
        if (_aiCooldown <= 0) {
          _burstRemaining = _profile.burstLength - 1;
          _pickAiMove(
            mapData,
            tileSize,
            otherSprites: otherSprites,
            pTargetX: playerTargetPixelX,
            pTargetY: playerTargetPixelY,
          );
          changed = true;
        }
      }
    }

    // --- Alert Animation Logic ---
    if (isAlerted) {
      if (alertTimer > 0) {
        alertTimer -= dt;
        // Shake effect
        shakeOffset = sin(alertTimer * 50.0) * 2.5;
        // Face the player while alerted
        final double dxP = playerPixelX - pixelX;
        final double dyP = playerPixelY - pixelY;
        if (dyP.abs() > dxP.abs()) {
          direction = dyP > 0 ? 'down' : 'up';
        } else {
          direction = dxP > 0 ? 'right' : 'left';
        }
        changed = true;
      }
    }

    // Ambient cry logic
    if (_cryCooldown > 0) {
      _cryCooldown -= dt;
      if (_cryCooldown <= 0) {
        shouldPlayCry = true;
        // Reset cooldown (20-60 seconds)
        _cryCooldown = 20.0 + Random().nextDouble() * 40.0;
      }
    }

    // Update tile-based elevation/submersion (always update so idle sprites submerge too)
    final tileAt = mapData.grid[row][col];
    final overlaysAt = mapData.overlayGrid?[row][col];
    bool isFloatingTile =
        tileAt.category == TileCategory.floating ||
        (overlaysAt?.any((t) => t.category == TileCategory.floating) ?? false);
    bool isWaterTile =
        tileAt.category == TileCategory.water ||
        (overlaysAt?.any((t) => t.category == TileCategory.water) ?? false);

    double nextOffset = 0.0;
    if (isFloatingTile) {
      nextOffset = -7.0; // Elevated on lily pads
    } else if (isWaterTile &&
        (organism.pheno == 'frog' || organism.pheno == 'Hfrog')) {
      nextOffset = 4.0; // Submerged
    }

    if (tileOffset != nextOffset) {
      tileOffset = nextOffset;
      changed = true;
    }

    return changed;
  }

  /// Pick the next direction, influenced by nature's playerAffinity and
  /// erraticChance.
  void _pickAiMove(
    BiomeMapData mapData,
    double tileSize, {
    List<OverworldSprite> otherSprites = const [],
    double? pTargetX,
    double? pTargetY,
  }) {
    final rng = Random();

    // Check vision range
    final double visionRangePixels =
        (BiomeDataManager.phenoSpawnData[organism.pheno]?.visionRange ?? 5.0) *
        tileSize;
    final double distToPlayerRaw = sqrt(
      pow(playerPixelX - pixelX, 2) + pow(playerPixelY - pixelY, 2),
    );

    double affinity = _profile.playerAffinity;
    double erratic = _profile.erraticChance;

    // If player is outside vision range, calm wander independently
    if (distToPlayerRaw > visionRangePixels) {
      affinity = 0.0;
    }

    // All 4 cardinal directions
    final allDirs = [
      [-1, 0, 'up'],
      [1, 0, 'down'],
      [0, -1, 'left'],
      [0, 1, 'right'],
    ];

    // Filter to valid moves (cannot walk on solid OR on other sprites)
    final validDirs = allDirs.where((d) {
      final nr = row + (d[0] as int);
      final nc = col + (d[1] as int);

      // 1. Basic terrain check
      if (!_canMoveTo(nr, nc, mapData)) return false;

      // 2. Sprite-to-sprite collision avoidance
      for (final other in otherSprites) {
        if (other == this) continue;
        // Check both current position AND target position of neighbors
        if ((other.row == nr && other.col == nc) ||
            (other.targetRow == nr && other.targetCol == nc)) {
          return false;
        }
      }

      // 3. Player avoidance (don't block player)
      final int pr = (playerPixelY / tileSize).floor();
      final int pc = (playerPixelX / tileSize).floor();
      if (nr == pr && nc == pc) return false;

      // Also avoid player's target position if moving
      if (pTargetX != null && pTargetY != null) {
        final int ptr = (pTargetY / tileSize).floor();
        final int ptc = (pTargetX / tileSize).floor();
        if (nr == ptr && nc == ptc) return false;
      }

      return true;
    }).toList();

    // If we're mid-burst, try to keep the same direction if valid
    if (_burstRemaining > 0 && _currentBurstDir != null) {
      final dr = _currentBurstDir![0];
      final dc = _currentBurstDir![1];
      final match = validDirs.where((d) => d[0] == dr && d[1] == dc);
      if (match.isNotEmpty) {
        _applyMove(match.first, tileSize);
        return;
      } else {
        // Path blocked! End burst prematurely
        _burstRemaining = 0;
        _currentBurstDir = null;
      }
    }

    if (validDirs.isEmpty) {
      _aiCooldown =
          _profile.cooldownMin +
          rng.nextDouble() * (_profile.cooldownMax - _profile.cooldownMin);
      _burstRemaining = 0;
      return;
    }

    // Decide whether this move is erratic (random) or affinity-guided
    if (rng.nextDouble() < erratic || affinity == 0.0) {
      // Pure random
      validDirs.shuffle(rng);
      final move = validDirs.first;
      _currentBurstDir = [move[0] as int, move[1] as int];
      _applyMove(move, tileSize);
      return;
    }

    List<dynamic> selected;

    // --- Special Frog Behavior ---
    if ((organism.pheno == 'frog' || organism.pheno == 'Hfrog') &&
        distToPlayerRaw < visionRangePixels) {
      // Flee towards water
      List<dynamic> waterDirs = [];
      for (final d in validDirs) {
        int nr = row + (d[0] as int);
        int nc = col + (d[1] as int);
        final base = mapData.grid[nr][nc];
        final overlays = mapData.overlayGrid?[nr][nc];
        bool isWatery =
            base.category == TileCategory.water ||
            base.category == TileCategory.floating ||
            (overlays?.any(
                  (t) =>
                      t.category == TileCategory.water ||
                      t.category == TileCategory.floating,
                ) ??
                false);
        if (isWatery) {
          waterDirs.add(d);
        }
      }

      if (waterDirs.isNotEmpty) {
        selected = waterDirs[rng.nextInt(waterDirs.length)];
      } else {
        // No direct water neighbor, pick direction that stays closest to player-to-water vector?
        // Simpler: Just flee from player normally, but if frog, always hop.
        selected = _weightedAffinityPick(
          validDirs,
          affinity,
          erratic,
          rng,
          tileSize,
        );
      }
      isHopping = true;
    } else {
      selected = _weightedAffinityPick(
        validDirs,
        affinity,
        erratic,
        rng,
        tileSize,
      );
      isHopping =
          (organism.pheno == 'frog' ||
          organism.pheno == 'Hfrog'); // Frogs always hop? Or only when moving?
    }

    _currentBurstDir = [selected[0] as int, selected[1] as int];
    _applyMove(selected, tileSize);
  }

  void _applyMove(List<dynamic> dir, double tileSize) {
    targetRow = row + (dir[0] as int);
    targetCol = col + (dir[1] as int);
    targetPixelX = targetCol * tileSize;
    targetPixelY = targetRow * tileSize;
    direction = dir[2] as String;
    isMoving = true;
    walkFrame = 1;
  }

  List<dynamic> _weightedAffinityPick(
    List<dynamic> validDirs,
    double affinity,
    double erratic,
    Random rng,
    double tileSize,
  ) {
    if (rng.nextDouble() < erratic) {
      return validDirs[rng.nextInt(validDirs.length)];
    }

    if (affinity == 0) return validDirs[rng.nextInt(validDirs.length)];

    // Rank directions by how they affect distance to player
    validDirs.sort((a, b) {
      final d1 = sqrt(
        pow(playerPixelX - (col + (a[0] as int)) * tileSize, 2) +
            pow(playerPixelY - (row + (a[1] as int)) * tileSize, 2),
      );
      final d2 = sqrt(
        pow(playerPixelX - (col + (b[0] as int)) * tileSize, 2) +
            pow(playerPixelY - (row + (b[1] as int)) * tileSize, 2),
      );
      return (affinity > 0) ? d1.compareTo(d2) : d2.compareTo(d1);
    });

    // 70% chance to pick best, otherwise random among valid
    return (rng.nextDouble() < 0.7)
        ? validDirs.first
        : validDirs[rng.nextInt(validDirs.length)];
  }

  /// Check if the player is occupying the same tile as this sprite.
  bool isCollidingWith(double playerX, double playerY, double tileSize) {
    final playerRow = (playerY / tileSize).round();
    final playerCol = (playerX / tileSize).round();
    return playerRow == row && playerCol == col;
  }
}
