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

  double get pixelX => worldX * 32.0; // Assuming 32 is default, but better to pass it
  double get pixelY => worldY * 32.0;
  int get walkFrame => currentFrame;

  // AI
  double lastMoveTime = 0;
  final Random _random = Random();

  OverworldNPC({required this.data}) 
    : worldX = data.col.toDouble(), 
      worldY = data.row.toDouble(),
      gridRow = data.row,
      gridCol = data.col;

  void tick(double dt, double totalTime, List<List<bool>> walkability, {
    int? playerRow,
    int? playerCol,
    List<OverworldNPC>? otherNPCs,
  }) {
    if (isMoving) {
      _updateMovement(dt);
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
}
