import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:animal_warfare/models/elemental_type.dart';

// ----------------------------------------------------------------
// Blob Stream Effect for Specific Moves
// ----------------------------------------------------------------
class BlobStreamEffect extends StatelessWidget {
  final String imagePath;
  final double progress;
  final bool isPlayer;

  const BlobStreamEffect({
    super.key,
    required this.imagePath,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    final flipX = !isPlayer; // Flipped if opponent uses it

    // A stream of overlapping blob particles
    const numParticles = 25;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(numParticles, (index) {
          // Each particle starts a tiny bit later
          final delay = index * 0.025;
          final p = progress * 1.5 - delay;

          if (p <= 0.0 || p >= 1.0) {
            return const SizedBox.shrink();
          }

          final travel = p.clamp(0.0, 1.0);
          final cx = size / 2;
          final cy = size / 2;

          // Movement from attacker area (bottom-left) to target (top-right)
          // Refined: starts exactly from middle of attacker sprite (cx=80, cy=80)
          // Previous startX was cx - 100, startY was cy + 110
          double startX =
              cx - 180; // Approximate attacker center in relative coordinates
          double startY = cy + 180;
          double endX = cx;
          double endY = cy;

          double currentX = startX + (endX - startX) * travel;
          double currentY = startY + (endY - startY) * travel;

          // Arc curve: arcs upwards for player
          double arc = math.sin(travel * math.pi) * 40.0;
          currentY -= arc;

          // Add some random wobble for organic stream feel
          double wobble = math.sin(travel * math.pi * 4 + index) * 10.0;
          currentY += wobble;
          currentX += wobble * 0.5;

          double opacity = 1.0;
          double scale = 1.0;

          if (travel < 0.2) {
            opacity = travel / 0.2;
            scale = 0.3 + travel * 3.5;
          } else if (travel > 0.8) {
            opacity = (1.0 - travel) / 0.2;
            scale = 1.0 + (travel - 0.8) * 2.5; // Explodes slightly at the end
          } else {
            scale = 0.8 + (index % 4) * 0.1; // Random size variation
          }

          if (flipX) {
            // Target is player. Attacker is opponent (above and to the right)
            currentX = cx + (cx - currentX);
            currentY = cy + (cy - currentY);
          }

          return Positioned(
            left: currentX - 20, // 40x40 image center
            top: currentY - 20,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Image.asset(
                  imagePath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ----------------------------------------------------------------
// Slash Effect for Specific Moves
// ----------------------------------------------------------------
class SlashEffect extends StatelessWidget {
  final String imagePath;
  final double progress;
  final bool isPlayer;

  const SlashEffect({
    super.key,
    required this.imagePath,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;

    final travel = progress.clamp(0.0, 1.0);
    final fadePhase = ((progress - 0.7) * 3.3).clamp(
      0.0,
      1.0,
    ); // Fades out at the very end

    final cx = size / 2;
    final cy = size / 2;

    // Diagonal travel: from attacker (bottom left) to target (top right)
    double startX = cx - 180;
    double startY = cy + 180;
    double endX = cx;
    double endY = cy;

    double currentX = startX + (endX - startX) * travel;
    double currentY = startY + (endY - startY) * travel;

    double rotation = travel * math.pi * 2; // Spinning as it travels
    double opacity = 1.0 - fadePhase;

    if (!isPlayer) {
      currentX = cx + (cx - currentX);
      currentY = cy + (cy - currentY);
      rotation = -rotation;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: currentX - 50,
            top: currentY - 50,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: rotation,
                child: Image.asset(
                  imagePath,
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// Brave Bird Diagonal Zoom Effect
// ----------------------------------------------------------------
class BraveBirdEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const BraveBirdEffect({
    super.key,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;

    final travel = progress.clamp(0.0, 1.0);
    final fade = progress > 0.8 ? (1.0 - progress) / 0.2 : 1.0;

    final cx = size / 2;
    final cy = size / 2;

    // Diagonal zoom: from attacker (bottom left) to target (top right)
    double startX = cx - 180;
    double startY = cy + 180;
    double endX = cx + 20; // Goes slightly past the target
    double endY = cy - 20;

    double currentX = startX + (endX - startX) * travel;
    double currentY = startY + (endY - startY) * travel;

    // Angle to rotate the bird sprite so it's pointing at the target
    double rotation = math.atan2(endY - startY, endX - startX); // Base angle

    if (!isPlayer) {
      // Mirror trajectory
      currentX = cx + (cx - currentX);
      currentY = cy + (cy - currentY);
      rotation += math.pi; // Rotate 180 degrees
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: currentX - 50, // 100x100
            top: currentY - 50,
            child: Opacity(
              opacity: fade.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: rotation,
                child: Image.asset(
                  'assets/move_effects/bird.png',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
