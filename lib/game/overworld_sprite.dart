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

  // AI timing
  double _aiCooldown = 0;

  // Player position tracking (set externally before tick)
  double playerPixelX = 0;
  double playerPixelY = 0;

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
  }

  /// Whether this sprite has expired (older than 60 seconds).
  bool get isExpired => DateTime.now().difference(spawnTime).inSeconds >= 60;

  /// Parse the organism's move_tiles from config (or spawn_tiles fallback) into a set of identifiers.
  Set<String> get _validMovementTiles {
    final spawnData = BiomeDataManager.phenoSpawnData[organism.pheno];
    final tileSource = (spawnData != null && spawnData.moveTiles.isNotEmpty)
        ? spawnData.moveTiles
        : organism.spawnTiles;

    if (tileSource == 'any') return {};
    return tileSource
        .split(',')
        .map((e) => e.trim().toLowerCase().replaceAll('_', ''))
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

    final validTiles = _validMovementTiles;
    if (validTiles.isEmpty) return true; // 'any' — can go anywhere non-solid

    // Check tile IDs
    if (validTiles.contains(baseTile.tileId.toLowerCase().replaceAll('_', '')))
      return true;

    if (overlayTile != null) {
      for (final ot in overlayTile) {
        if (validTiles.contains(ot.tileId.toLowerCase().replaceAll('_', ''))) {
          return true;
        }
      }
    }

    // Check tile categories (e.g., "water", "tallgrass", "ground")
    final baseCategory = baseTile.category.name.toLowerCase().replaceAll(
      '_',
      '',
    );
    if (validTiles.contains(baseCategory)) return true;

    if (overlayTile != null) {
      for (final ot in overlayTile) {
        final oc = ot.category.name.toLowerCase().replaceAll('_', '');
        if (validTiles.contains(oc)) return true;
      }
    }

    return false;
  }

  /// AI tick — called from _onTick. Returns true if state changed.
  bool tick(double dt, BiomeMapData mapData, double tileSize) {
    bool changed = false;

    if (isMoving) {
      // Move towards target
      final double defaultSpeedMult =
          BiomeDataManager.phenoSpawnData[organism.pheno]?.defaultSpeed ?? 1.0;
      final double speed = _profile.speed * defaultSpeedMult;
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
          _pickAiMove(mapData, tileSize);
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

        // Walk animation
        walkAnimAccumulator += speed;
        if (walkAnimAccumulator >= tileSize / 2) {
          walkAnimAccumulator -= tileSize / 2;
          walkFrame = (walkFrame == 1) ? 2 : 1;
        }
      }
      changed = true;
    } else {
      // Waiting — count down AI cooldown
      _aiCooldown -= dt;
      if (_aiCooldown <= 0) {
        _burstRemaining = _profile.burstLength - 1;
        _pickAiMove(mapData, tileSize);
        changed = true;
      }
    }

    return changed;
  }

  /// Pick the next direction, influenced by nature's playerAffinity and
  /// erraticChance.
  void _pickAiMove(BiomeMapData mapData, double tileSize) {
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
      erratic = 0.0;
    }

    // All 4 cardinal directions
    final allDirs = [
      [-1, 0, 'up'],
      [1, 0, 'down'],
      [0, -1, 'left'],
      [0, 1, 'right'],
    ];

    // Filter to valid moves
    final validDirs = allDirs
        .where(
          (d) => _canMoveTo(row + (d[0] as int), col + (d[1] as int), mapData),
        )
        .toList();

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
      _applyMove(validDirs.first, tileSize);
      return;
    }

    // Score each direction based on distance to player
    final double pRow = playerPixelY / tileSize;
    final double pCol = playerPixelX / tileSize;

    List<dynamic>? best;
    double bestScore = double.negativeInfinity;

    for (final d in validDirs) {
      final nr = row + (d[0] as int);
      final nc = col + (d[1] as int);
      final double distToPlayer = sqrt(
        (nr - pRow) * (nr - pRow) + (nc - pCol) * (nc - pCol),
      );

      // If affinity > 0 we want to DECREASE dist → score = -dist
      // If affinity < 0 we want to INCREASE dist → score = +dist
      double score = -distToPlayer * affinity;

      // Add a bit of randomness so movement isn't perfectly robotic
      score += rng.nextDouble() * 0.5;

      if (score > bestScore) {
        bestScore = score;
        best = d;
      }
    }

    if (best != null) {
      _applyMove(best, tileSize);
    } else {
      validDirs.shuffle(rng);
      _applyMove(validDirs.first, tileSize);
    }
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

  /// Check if the player is occupying the same tile as this sprite.
  bool isCollidingWith(double playerX, double playerY, double tileSize) {
    final playerRow = (playerY / tileSize).round();
    final playerCol = (playerX / tileSize).round();
    return playerRow == row && playerCol == col;
  }
}
