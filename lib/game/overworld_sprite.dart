// lib/game/overworld_sprite.dart
//
// Represents a roaming animal NPC ("pheno") on the biome exploration map.

import 'dart:math';
import 'dart:ui' as ui;

import 'package:animal_warfare/game/biome_map_data.dart';
import 'package:animal_warfare/models/organism.dart';

class OverworldSprite {
  final Organism organism;
  final DateTime spawnTime;

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

  // Animation
  String direction = 'down';
  int walkFrame = 0;
  double walkAnimAccumulator = 0.0;

  // AI timing
  double _aiCooldown = 0;

  // Loaded directional sprites (up/down/left/right)
  Map<String, ui.Image> sprites = {};

  OverworldSprite({
    required this.organism,
    required this.row,
    required this.col,
    required double tileSize,
    DateTime? spawnTime,
  }) : spawnTime = spawnTime ?? DateTime.now(),
       pixelX = col * tileSize,
       pixelY = row * tileSize,
       targetRow = row,
       targetCol = col,
       targetPixelX = col * tileSize,
       targetPixelY = row * tileSize {
    // Random initial cooldown so sprites don't all move in sync
    _aiCooldown = 1.0 + Random().nextDouble() * 2.0;
  }

  /// Whether this sprite has expired (older than 60 seconds).
  bool get isExpired => DateTime.now().difference(spawnTime).inSeconds >= 60;

  /// Parse the organism's spawn_tiles into a set of tile identifiers.
  Set<String> get _validSpawnTiles {
    if (organism.spawnTiles == 'any') return {};
    return organism.spawnTiles
        .split(',')
        .map((e) => e.trim().toLowerCase())
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
        overlayTile?.category == TileCategory.solid) {
      return false;
    }

    final validTiles = _validSpawnTiles;
    if (validTiles.isEmpty) return true; // 'any' — can go anywhere non-solid

    // Check tile IDs
    if (validTiles.contains(baseTile.tileId.toLowerCase())) return true;
    if (overlayTile != null &&
        validTiles.contains(overlayTile.tileId.toLowerCase())) {
      return true;
    }

    // Check tile categories (e.g., "water", "tallgrass", "ground")
    final baseCategory = baseTile.category.name.toLowerCase();
    final overlayCategory = overlayTile?.category.name.toLowerCase();
    if (validTiles.contains(baseCategory)) return true;
    if (overlayCategory != null && validTiles.contains(overlayCategory)) {
      return true;
    }

    return false;
  }

  /// AI tick — called from _onTick. Returns true if state changed.
  bool tick(double dt, BiomeMapData mapData, double tileSize) {
    bool changed = false;

    if (isMoving) {
      // Move towards target
      const double speed = 1.0; // Slower than player
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
        _aiCooldown = 1.5 + Random().nextDouble() * 3.0; // Wait 1.5-4.5s
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
        _pickRandomMove(mapData, tileSize);
        changed = true;
      }
    }

    return changed;
  }

  void _pickRandomMove(BiomeMapData mapData, double tileSize) {
    final directions = [
      [-1, 0, 'up'],
      [1, 0, 'down'],
      [0, -1, 'left'],
      [0, 1, 'right'],
    ];
    directions.shuffle();

    for (final dir in directions) {
      final nr = row + (dir[0] as int);
      final nc = col + (dir[1] as int);
      if (_canMoveTo(nr, nc, mapData)) {
        targetRow = nr;
        targetCol = nc;
        targetPixelX = nc * tileSize;
        targetPixelY = nr * tileSize;
        direction = dir[2] as String;
        isMoving = true;
        walkFrame = 1;
        return;
      }
    }

    // No valid move — wait again
    _aiCooldown = 1.0 + Random().nextDouble() * 2.0;
  }

  /// Check if the player is occupying the same tile as this sprite.
  bool isCollidingWith(double playerX, double playerY, double tileSize) {
    final playerRow = (playerY / tileSize).round();
    final playerCol = (playerX / tileSize).round();
    return playerRow == row && playerCol == col;
  }
}
