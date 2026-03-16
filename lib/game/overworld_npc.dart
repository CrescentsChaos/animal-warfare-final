// lib/game/overworld_npc.dart

import 'dart:math';
import 'package:animal_warfare/models/npc_data.dart';

class OverworldNPC {
  final NPCData data;
  double worldX;
  double worldY;
  
  // Current tile position
  int gridRow;
  int gridCol;

  // Animation & Movement
  int currentFrame = 0;
  String direction = 'down';
  bool isMoving = false;
  double moveProgress = 0.0;
  int targetRow = -1;
  int targetCol = -1;

  double get pixelX => worldX * 32.0;
  double get pixelY => worldY * 32.0;
  int get walkFrame => currentFrame;

  // AI
  double lastMoveTime = 0;
  final Random _random = Random();

  // Trainer state
  bool isDefeated = false;
  bool isApproaching = false;
  bool hasTriggeredBattle = false; // prevents re-trigger during approach

  OverworldNPC({required this.data}) 
    : worldX = data.col.toDouble(), 
      worldY = data.row.toDouble(),
      gridRow = data.row,
      gridCol = data.col;

  bool get isTrainer => data.scriptType == 'trainer' && data.teamId.isNotEmpty;

  void tick(double dt, double totalTime, List<List<bool>> walkability, {
    int? playerRow,
    int? playerCol,
    List<OverworldNPC>? otherNPCs,
  }) {
    if (isMoving) {
      _updateMovement(dt);
    } else if (isApproaching && playerRow != null && playerCol != null) {
      // Continue approaching the player
      _stepTowardPlayer(playerRow, playerCol, walkability, otherNPCs: otherNPCs);
    } else {
      _handleAI(totalTime, walkability, playerRow: playerRow, playerCol: playerCol, otherNPCs: otherNPCs);
    }

    // Animation frame
    if (isMoving) {
      currentFrame = (totalTime * 8).floor() % 4; 
    } else {
      currentFrame = 0;
    }
  }

  void _updateMovement(double dt) {
    const speed = 2.0; // Tiles per second
    moveProgress += dt * speed;
    
    if (moveProgress >= 1.0) {
      worldX = targetCol.toDouble();
      worldY = targetRow.toDouble();
      gridRow = targetRow;
      gridCol = targetCol;
      isMoving = false;
      moveProgress = 0.0;
    } else {
      worldX = gridCol + (targetCol - gridCol) * moveProgress;
      worldY = gridRow + (targetRow - gridRow) * moveProgress;
    }
  }

  void _handleAI(double totalTime, List<List<bool>> walkability, {
    int? playerRow,
    int? playerCol,
    List<OverworldNPC>? otherNPCs,
  }) {
    if (data.movementType == 'still') {
      return;
    }

    // Don't wander if defeated trainer — just stand
    if (isDefeated && isTrainer) return;

    // Movement delay
    if (totalTime - lastMoveTime < 2.0 + _random.nextDouble() * 2.0) {
      return;
    }
    lastMoveTime = totalTime;

    if (data.movementType == 'random') {
      _tryRandomMove(walkability, playerRow: playerRow, playerCol: playerCol, otherNPCs: otherNPCs);
    }
  }

  void _tryRandomMove(List<List<bool>> walkability, {
    int? playerRow,
    int? playerCol,
    List<OverworldNPC>? otherNPCs,
  }) {
    final dirs = [[-1, 0], [1, 0], [0, -1], [0, 1]];
    final dir = dirs[_random.nextInt(4)];
    
    int nextR = gridRow + dir[0];
    int nextC = gridCol + dir[1];

    // Stay within range of original spawn
    if ((nextR - data.row).abs() > data.movementRange || 
        (nextC - data.col).abs() > data.movementRange) {
      return;
    }

    // Boundary check
    if (nextR < 0 || nextR >= walkability.length || 
        nextC < 0 || nextC >= walkability[0].length) {
      return;
    }

    // Tile walkability check
    if (!walkability[nextR][nextC]) {
      return;
    }

    // Player collision check
    if (playerRow == nextR && playerCol == nextC) {
      return;
    }

    // Other NPC collision check
    if (otherNPCs != null) {
      for (final other in otherNPCs) {
        if (other == this) continue;
        if (other.gridRow == nextR && other.gridCol == nextC) return;
        if (other.isMoving && other.targetRow == nextR && other.targetCol == nextC) return;
      }
    }

    targetRow = nextR;
    targetCol = nextC;
    isMoving = true;
    moveProgress = 0.0;

    if (dir[0] == -1) direction = 'up';
    if (dir[0] == 1) direction = 'down';
    if (dir[1] == -1) direction = 'left';
    if (dir[1] == 1) direction = 'right';
  }

  /// Check if the player is within the NPC's vision range (directional cone).
  bool canSeePlayer(int pRow, int pCol) {
    if (!isTrainer || isDefeated || isApproaching || hasTriggeredBattle) return false;
    if (data.visionRange <= 0) return false;

    // Check tiles in the NPC's facing direction
    int dr = 0, dc = 0;
    switch (direction) {
      case 'up':    dr = -1; dc = 0; break;
      case 'down':  dr = 1;  dc = 0; break;
      case 'left':  dr = 0;  dc = -1; break;
      case 'right': dr = 0;  dc = 1; break;
    }

    for (int i = 1; i <= data.visionRange; i++) {
      final checkR = gridRow + dr * i;
      final checkC = gridCol + dc * i;
      if (checkR == pRow && checkC == pCol) return true;
    }
    return false;
  }

  /// Begin approaching the player tile-by-tile.
  void startApproach(int pRow, int pCol) {
    isApproaching = true;
    _faceToward(pRow, pCol);
  }

  void _faceToward(int pRow, int pCol) {
    final dr = pRow - gridRow;
    final dc = pCol - gridCol;
    if (dr.abs() > dc.abs()) {
      direction = dr < 0 ? 'up' : 'down';
    } else {
      direction = dc < 0 ? 'left' : 'right';
    }
  }

  void _stepTowardPlayer(int pRow, int pCol, List<List<bool>> walkability, {
    List<OverworldNPC>? otherNPCs,
  }) {
    if (isMoving) return;

    // Check if adjacent to the player (within 1 tile)
    final dist = (gridRow - pRow).abs() + (gridCol - pCol).abs();
    if (dist <= 1) {
      // We've arrived — face the player and stop approaching
      _faceToward(pRow, pCol);
      isApproaching = false;
      return;
    }

    // Move one step closer
    int dr = (pRow - gridRow).sign;
    int dc = (pCol - gridCol).sign;

    // Try vertical first, then horizontal
    List<List<int>> attempts = [];
    if (dr != 0) attempts.add([dr, 0]);
    if (dc != 0) attempts.add([0, dc]);

    for (final dir in attempts) {
      final nextR = gridRow + dir[0];
      final nextC = gridCol + dir[1];

      if (nextR < 0 || nextR >= walkability.length ||
          nextC < 0 || nextC >= walkability[0].length) continue;
      if (!walkability[nextR][nextC]) continue;

      // Check NPC collision
      bool blocked = false;
      if (otherNPCs != null) {
        for (final other in otherNPCs) {
          if (other == this) continue;
          if (other.gridRow == nextR && other.gridCol == nextC) { blocked = true; break; }
        }
      }
      if (blocked) continue;

      // Don't step onto the player's tile
      if (nextR == pRow && nextC == pCol) {
        _faceToward(pRow, pCol);
        isApproaching = false;
        return;
      }

      targetRow = nextR;
      targetCol = nextC;
      isMoving = true;
      moveProgress = 0.0;

      if (dir[0] == -1) direction = 'up';
      if (dir[0] == 1) direction = 'down';
      if (dir[1] == -1) direction = 'left';
      if (dir[1] == 1) direction = 'right';
      return;
    }

    // Can't move — just stop approaching
    _faceToward(pRow, pCol);
    isApproaching = false;
  }
}
