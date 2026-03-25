import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:animal_warfare/models/move.dart';
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
              cx - 210; // Approximate attacker center in relative coordinates
          double startY = cy + 150;
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
// Swords Dance Effect (Circling Swords)
// ----------------------------------------------------------------
class BuffEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;
  final String imagePath;

  const BuffEffect({
    super.key,
    required this.imagePath,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    const numSwords = 2;
    final p = progress.clamp(0.0, 1.0);

    // Fade in (0-20%), hold, then fade out (80-100%)
    final opacity = p < 0.2 ? p / 0.2 : (p > 0.8 ? (1.0 - p) / 0.2 : 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(numSwords, (index) {
          // Circular motion: 2 full rotations (4 * PI) over the duration
          final angle = (p * math.pi * 4) + (index * math.pi);

          // Radius stays consistent or pulses slightly
          final radius = 65.0 + math.sin(p * math.pi * 4) * 5.0;

          final dx = math.cos(angle) * radius;
          final dy = math.sin(angle) * radius;

          // Rotation: adjust by 45 degrees so sword points inward/forward
          final swordRotation = angle + (math.pi / 4);

          return Positioned(
            left: (size / 2) + dx - 25,
            top: (size / 2) + dy - 25,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: swordRotation,
                child: Image.asset(
                  imagePath, // Ensure this asset exists
                  width: 50,
                  height: 50,
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
// Protect Effect (Hexagonal Shield)
// ----------------------------------------------------------------
class ProtectEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const ProtectEffect({
    super.key,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    final p = progress.clamp(0.0, 1.0);

    // Fade in (0-15%), hold, then fade out (85-100%)
    final opacity = p < 0.15 ? p / 0.15 : (p > 0.85 ? (1.0 - p) / 0.15 : 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: CustomPaint(painter: _ProtectPainter(progress: p)),
      ),
    );
  }
}

class _ProtectPainter extends CustomPainter {
  final double progress;
  _ProtectPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 2.0;

    // Pulse effect for color/glow
    final pulse = 0.8 + math.sin(progress * math.pi * 10) * 0.2;
    final shieldColor = const Color(0xFF40E0D0); // Turquoise/Teal

    const hexRadius = 18.0;
    final hexWidth = hexRadius * math.sqrt(3);
    final hexHeight = hexRadius * 2;

    // Draw a small cluster of hexagons
    for (int q = -2; q <= 2; q++) {
      for (int r = -2; r <= 2; r++) {
        // Hexagonal axial to pixel coordinates
        if (q.abs() + r.abs() + (-q - r).abs() > 6) continue;

        final dx = hexWidth * (q + r / 2);
        final dy = hexHeight * 0.75 * r;

        final hexCenter = center + Offset(dx, dy);

        // Individual hex pulse based on progress and distance
        final dist = Offset(dx, dy).distance / 60;
        final localPulse = (math.sin(progress * 15 - dist * 5) + 1) / 2;

        paint.color = shieldColor.withValues(
          alpha: 0.2 + 0.4 * localPulse * pulse,
        );
        _drawHexagon(canvas, hexCenter, hexRadius * 0.9, paint);

        // Hex border
        paint.style = PaintingStyle.stroke;
        paint.color = shieldColor.withValues(alpha: 0.6 * pulse);
        _drawHexagon(canvas, hexCenter, hexRadius * 0.9, paint);
        paint.style = PaintingStyle.fill;
      }
    }

    // Outer glow ring
    canvas.drawCircle(
      center,
      80 * (0.95 + 0.05 * pulse),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..shader = RadialGradient(
          colors: [
            shieldColor.withValues(alpha: 0.6),
            shieldColor.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 90)),
    );
  }

  void _drawHexagon(Canvas canvas, Offset c, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i + (math.pi / 6);
      final x = c.dx + radius * math.cos(angle);
      final y = c.dy + radius * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ProtectPainter old) => true;
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
    double startX = cx - 210;
    double startY = cy + 150;
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
                  width: 40,
                  height: 40,
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
                child: Transform.scale(
                  scaleY: isPlayer ? 1.0 : -1.0,
                  child: Image.asset(
                    'assets/move_effects/bird.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
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
// Bite Effect for Snapping Jaws
// ----------------------------------------------------------------
class BiteEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const BiteEffect({super.key, required this.progress, required this.isPlayer});

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    final p = progress.clamp(0.0, 1.0);

    // Fade out at the end
    final opacity = p > 0.8 ? (1.0 - p) / 0.2 : 1.0;

    // Movement: snapping together
    // p: 0.0 (open) -> 0.4 (closed) -> 1.0 (fade/hold)
    final snap = math.sin((p * 2.5).clamp(0.0, 1.0) * math.pi / 2);

    final offset = 40.0 * (1.0 - snap);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Upper Jaw
          Positioned(
            top: 20 - offset,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Image.asset(
                'assets/move_effects/upper_jaw.png',
                width: 100,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Lower Jaw
          Positioned(
            bottom: 20 - offset,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Image.asset(
                'assets/move_effects/lower_jaw.png',
                width: 100,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// Melee Effect for Punch/Kick
// ----------------------------------------------------------------
class MeleeEffect extends StatelessWidget {
  final String imagePath;
  final double progress;
  final bool isPlayer;

  const MeleeEffect({
    super.key,
    required this.imagePath,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    final p = progress.clamp(0.0, 1.0);

    final cx = size / 2;
    final cy = size / 2;

    // Fast travel: from attacker to target
    double startX = cx - 180;
    double startY = cy + 180;
    double endX = cx;
    double endY = cy;

    if (!isPlayer) {
      startX = cx + 180;
      startY = cy - 180;
    }

    double currentX = startX + (endX - startX) * p;
    double currentY = startY + (endY - startY) * p;

    // Scale and opacity
    final scale = p < 0.2 ? p / 0.2 : (p > 0.8 ? (1.0 - p) / 0.2 : 1.0);
    final opacity = scale;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: currentX - 40,
            top: currentY - 40,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Image.asset(
                  imagePath,
                  width: 80,
                  height: 80,
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
// Close Combat Effect (Rapid Strikes)
// ----------------------------------------------------------------
class SpamAttackEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;
  final String imagePath;

  const SpamAttackEffect({
    super.key,
    required this.progress,
    required this.isPlayer,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    const numStrikes = 8;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(numStrikes, (index) {
          // Staggered strikes
          final delay = index * 0.1;
          final p = (progress * 1.5 - delay).clamp(0.0, 1.0);

          if (p <= 0.0 || p >= 1.0) return const SizedBox.shrink();

          final rand = math.Random(index);
          final angle = rand.nextDouble() * math.pi * 2;
          final radius = 30.0 + rand.nextDouble() * 30.0;

          final dx = math.cos(angle) * radius;
          final dy = math.sin(angle) * radius;

          final isPunchRand = rand.nextBool();
          final particlePath = isPunchRand
              ? 'assets/move_effects/punch.png'
              : 'assets/move_effects/kick.png';

          // Use the passed-in imagePath if available, otherwise fallback to the random one
          final finalImagePath =
              imagePath.isNotEmpty && !imagePath.contains('ice.png')
              ? imagePath
              : particlePath;

          final opacity = (1.0 - p).clamp(0.0, 1.0);
          final scale = 0.5 + p * 1.0;

          return Positioned(
            left: (size / 2) + dx - 30,
            top: (size / 2) + dy - 30,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Image.asset(
                  finalImagePath,
                  width: 60,
                  height: 60,
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
// Drain Effect (Particles from Target to Attacker)
// ----------------------------------------------------------------
class DrainEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const DrainEffect({
    super.key,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    const numParticles = 12;
    final p = progress.clamp(0.0, 1.0);

    final cx = size / 2;
    final cy = size / 2;

    // Movement: from target to attacker
    double startX = cx;
    double startY = cy;
    double endX = cx - 210;
    double endY = cy + 150;

    if (!isPlayer) {
      endX = cx + 210;
      endY = cy - 150;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(numParticles, (index) {
          final appearanceThreshold = (index / numParticles) * 0.5;
          if (p < appearanceThreshold) return const SizedBox.shrink();

          final localP = ((p - appearanceThreshold) / 0.5).clamp(0.0, 1.0);

          final curX = startX + (endX - startX) * localP;
          final curY = startY + (endY - startY) * localP;

          final opacity = localP > 0.8 ? (1.0 - localP) / 0.2 : 1.0;
          final scale = 0.4 + math.sin(localP * math.pi) * 0.6;

          return Positioned(
            left: curX - 20,
            top: curY - 20,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Image.asset(
                  'assets/move_effects/aqua.png',
                  width: 40,
                  height: 40,
                  color: Colors.greenAccent.withValues(alpha: 0.8),
                  colorBlendMode: BlendMode.modulate,
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
// Surf Effect (Wave Overlay)
// ----------------------------------------------------------------
class SurfEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const SurfEffect({super.key, required this.progress, required this.isPlayer});

  @override
  Widget build(BuildContext context) {
    const size = 300.0;
    final p = progress.clamp(0.0, 1.0);

    final opacity = p < 0.2 ? p / 0.2 : (p > 0.8 ? (1.0 - p) / 0.2 : 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset((p - 0.5) * 500 * (isPlayer ? 1 : -1), 0),
            child: Opacity(
              opacity: opacity,
              child: Image.asset(
                'assets/move_effects/aqua.png',
                width: 300,
                height: 180,
                fit: BoxFit.fill,
                color: Colors.blue.withValues(alpha: 0.4),
                colorBlendMode: BlendMode.srcATop,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// Hurricane Effect (Tornado Travelling from Attacker to Target)
// ----------------------------------------------------------------
class HurricaneEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  static const _tornadoFrames = [
    'assets/move_effects/tornado_1.png',
    'assets/move_effects/tornado_2.png',
    'assets/move_effects/tornado_3.png',
  ];

  const HurricaneEffect({
    super.key,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    final p = progress.clamp(0.0, 1.0);

    // Pick the tornado frame based on progress (cycles through 3 frames multiple times)
    final frameIndex = ((p * 12).floor()) % _tornadoFrames.length;
    final framePath = _tornadoFrames[frameIndex];

    final cx = size / 2;
    final cy = size / 2;

    // Travel from attacker (bottom-left) to target (center)
    double startX = cx - 210;
    double startY = cy + 150;
    double endX = cx;
    double endY = cy;

    // Ease-in travel: accelerates as it approaches the target
    final travel = Curves.easeIn.transform(p);

    double currentX = startX + (endX - startX) * travel;
    double currentY = startY + (endY - startY) * travel;

    // Arc curve: tornado arcs upward for dramatic effect
    double arc = math.sin(travel * math.pi) * 50.0;
    currentY -= arc;

    // Mirror for opponent attacks
    if (!isPlayer) {
      currentX = cx + (cx - currentX);
      currentY = cy + (cy - currentY);
    }

    // Scale: grows from small to large as it approaches the target
    final scale = 0.5 + travel * 1.0;

    // Opacity: fade in at start, hold, fade out at end
    final opacity = p < 0.1
        ? p / 0.1
        : (p > 0.85 ? (1.0 - p) / 0.15 : 1.0);

    // Slight wobble rotation for organic feel
    final wobbleAngle = math.sin(p * math.pi * 8) * 0.15;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: currentX - 60,
            top: currentY - 60,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: wobbleAngle,
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    framePath,
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
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
// Thunder Effect (Lightning Bolt)
// ----------------------------------------------------------------
class ThunderEffect extends StatelessWidget {
  final double progress;

  const ThunderEffect({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    const size = 400.0;
    final p = progress.clamp(0.0, 1.0);
    final flash = (math.sin(p * math.pi * 20) + 1) / 2;
    final opacity = p < 0.1 ? p / 0.1 : (p > 0.9 ? (1.0 - p) / 0.1 : 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -200,
            child: Opacity(
              opacity: opacity * (0.6 + 0.4 * flash),
              child: Image.asset(
                'assets/move_effects/electric_ball.png',
                width: 120,
                height: 500,
                fit: BoxFit.fill,
                color: Colors.yellowAccent,
                colorBlendMode: BlendMode.modulate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// Elemental Melee Effect (Strike + Blobs)
// ----------------------------------------------------------------
class ElementalMeleeEffect extends StatelessWidget {
  final String strikeImage; // punch or kick
  final String blobImage; // flame or aqua
  final double progress;
  final bool isPlayer;

  const ElementalMeleeEffect({
    super.key,
    required this.strikeImage,
    required this.blobImage,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    final p = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Underlying elemental burst
          Opacity(
            opacity: (1.0 - p).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.5 + p * 2.5,
              child: Image.asset(
                blobImage,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // Strike icon popping in
          if (p < 0.6)
            Opacity(
              opacity: (p / 0.3).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.8 + p * 0.5,
                child: Image.asset(
                  strikeImage,
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// Rock Effect (Falling Rocks)
// ----------------------------------------------------------------
class RockEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const RockEffect({super.key, required this.progress, required this.isPlayer});

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    const numRocks = 5;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(numRocks, (index) {
          final rand = math.Random(index);
          // Staggered fall
          final delay = index * 0.15;
          final p = (progress * 1.5 - delay).clamp(0.0, 1.0);

          if (p <= 0.0 || p >= 1.0) return const SizedBox.shrink();

          // Randomized horizontal position
          final dx = (rand.nextDouble() * 100) - 50;
          // Falling from top (offscreen) to target center (80)
          final startY = -150.0;
          final endY = 80.0;
          final currentY = startY + (endY - startY) * p;

          final rotation = p * math.pi * 2;
          final opacity = p > 0.8 ? (1.0 - p) / 0.2 : 1.0;
          final scale = 0.6 + rand.nextDouble() * 0.6;

          return Positioned(
            left: (size / 2) + dx - 20,
            top: currentY - 20,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    'assets/move_effects/rock.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
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
// Ice Beam / Elemental Beam Effect
// ----------------------------------------------------------------
class BeamEffect extends StatelessWidget {
  final List<String> imagePaths;
  final double progress;
  final bool isPlayer;

  const BeamEffect({
    super.key,
    required this.imagePaths,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    final p = progress.clamp(0.0, 1.0);

    final cx = size / 2;
    final cy = size / 2;

    // Movement: straight beam from attacker to target
    double startX = cx - 210;
    double startY = cy + 150;
    double endX = cx;
    double endY = cy;

    if (!isPlayer) {
      startX = cx + 210;
      startY = cy - 150;
    }

    // A "stretched" beam look or a stream of particles
    const numParticles = 15;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(numParticles, (index) {
          final particleDelay = index * 0.05;
          final pLocal = (p * 1.5 - particleDelay).clamp(0.0, 1.0);

          if (pLocal <= 0.0 || pLocal >= 1.0) return const SizedBox.shrink();

          final currentX = startX + (endX - startX) * pLocal;
          final currentY = startY + (endY - startY) * pLocal;

          final opacity = pLocal > 0.8 ? (1.0 - pLocal) / 0.2 : 1.0;
          final scale = 0.5 + math.sin(pLocal * math.pi) * 1.0;

          return Positioned(
            left: currentX - 15,
            top: currentY - 15,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Image.asset(
                  imagePaths[index % imagePaths.length],
                  width: 30,
                  height: 30,
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
// Shard/Quick Projectile Effect
// ----------------------------------------------------------------
class ShardEffect extends StatelessWidget {
  final String imagePath;
  final double progress;
  final bool isPlayer;

  const ShardEffect({
    super.key,
    required this.imagePath,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    const numShards = 3;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(numShards, (index) {
          final rand = math.Random(index);
          final delay = index * 0.2;
          final p = (progress * 1.4 - delay).clamp(0.0, 1.0);

          if (p <= 0.0 || p >= 1.0) return const SizedBox.shrink();

          final cx = size / 2;
          final cy = size / 2;

          // From attacker to target
          double startX = cx - 180 + (rand.nextDouble() * 40 - 20);
          double startY = cy + 180 + (rand.nextDouble() * 40 - 20);
          double endX = cx + (rand.nextDouble() * 40 - 20);
          double endY = cy + (rand.nextDouble() * 40 - 20);

          if (!isPlayer) {
            final tempX = startX;
            final tempY = startY;
            startX = cx + (cx - tempX);
            startY = cy + (cy - tempY);
            final tempEndX = endX;
            final tempEndY = endY;
            endX = cx + (cx - tempEndX);
            endY = cy + (cy - tempEndY);
          }

          final currentX = startX + (endX - startX) * p;
          final currentY = startY + (endY - startY) * p;

          final rotation = math.atan2(endY - startY, endX - startX);
          final opacity = p > 0.8 ? (1.0 - p) / 0.2 : 1.0;

          return Positioned(
            left: currentX - 20,
            top: currentY - 20,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: rotation,
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
// Ice Column Effect (Sequential Ice Shards)
// ----------------------------------------------------------------
class IceColumnEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const IceColumnEffect({
    super.key,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    final p = progress.clamp(0.0, 1.0);
    const numParticles = 12;

    final cx = size / 2;
    final cy = size / 2;

    // Movement: straight line from attacker to target
    double startX = cx - 180;
    double startY = cy + 180;
    double endX = cx;
    double endY = cy;

    if (!isPlayer) {
      startX = cx + 180;
      startY = cy - 180;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(numParticles, (index) {
          // Sequential appearance
          final appearanceThreshold = (index / numParticles) * 0.6;
          if (p < appearanceThreshold) return const SizedBox.shrink();

          // How developed this specific particle's "life" is after it appears
          final localP = ((p - appearanceThreshold) / 0.4).clamp(0.0, 1.0);

          final ratio = index / (numParticles - 1);
          final currentX = startX + (endX - startX) * ratio;
          final currentY = startY + (endY - startY) * ratio;

          final opacity = localP > 0.8 ? (1.0 - localP) / 0.2 : 1.0;
          final scale = 0.4 + math.sin(localP * math.pi) * 0.8;

          return Positioned(
            left: currentX - 15,
            top: currentY - 15,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale,
                child: Image.asset(
                  'assets/move_effects/ice.png',
                  width: 30,
                  height: 30,
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
// MOVE ANIMATION SYSTEM (Refactored from battle_screen.dart)
// ----------------------------------------------------------------

/// Holds the data needed to render one move-attack animation overlay.
class MoveAnimData {
  final int id;
  final Move move;
  final bool isPlayerAttacking;

  const MoveAnimData({
    required this.id,
    required this.move,
    required this.isPlayerAttacking,
  });
}

/// Renders a move-specific visual effect overlaid on the battle screen.
class MoveAnimationOverlay extends StatefulWidget {
  final MoveAnimData data;
  final LayerLink playerLink;
  final LayerLink opponentLink;

  const MoveAnimationOverlay({
    super.key,
    required this.data,
    required this.playerLink,
    required this.opponentLink,
  });

  @override
  State<MoveAnimationOverlay> createState() => _MoveAnimationOverlayState();
}

class _MoveAnimationOverlayState extends State<MoveAnimationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..forward();
    _progress = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final move = widget.data.move;
    final isPlayer = widget.data.isPlayerAttacking;
    // The ATTACKER link is used as the origin, target receives the hit
    final attackerLink = isPlayer ? widget.playerLink : widget.opponentLink;
    final targetLink = isPlayer ? widget.opponentLink : widget.playerLink;
    final color = move.type.color;

    if (move.animationType == 'blob') {
      final isFire =
          move.type == ElementalType.blaze ||
          move.name.toLowerCase() == 'flamethrower' ||
          move.name.toLowerCase() == 'overheat';
      final isSludge =
          move.type == ElementalType.toxic ||
          move.name.toLowerCase() == 'sludge bomb' ||
          move.name.toLowerCase() == 'sludge wave';
      final isWaterPulse =
          move.name.toLowerCase().contains('water pulse') ||
          move.name.toLowerCase().contains('dark pulse') ||
          move.name.toLowerCase().contains('aqua pulse') ||
          move.name.toLowerCase() == 'pulse';
      final rand = math.Random(42);
      final options = [
        'assets/move_effects/leaf1.png',
        'assets/move_effects/leaf2.png',
        'assets/move_effects/leaf3.png',
      ];

      final imagePath = isFire
          ? 'assets/move_effects/flame.png'
          : isSludge
          ? 'assets/move_effects/sludge.png'
          : move.name.toLowerCase() == 'dark pulse'
          ? 'assets/move_effects/dark_pulse.png'
          : move.name.toLowerCase() == 'leaf storm'
          ? options[rand.nextInt(options.length)]
          : (isWaterPulse
                ? 'assets/move_effects/water_pulse.png'
                : 'assets/move_effects/aqua.png');

      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: BlobStreamEffect(
              imagePath: imagePath,
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'slash') {
      final imagePath =
          move.type == ElementalType.darkness ||
              move.name.toLowerCase() == 'night slash'
          ? 'assets/move_effects/night_slash.png'
          : move.name.toLowerCase() == 'shadow ball'
          ? 'assets/move_effects/shadow_ball.png'
          : move.name.toLowerCase() == 'energy ball'
          ? 'assets/move_effects/energy_ball.png'
          : move.name.toLowerCase() == 'moonblast'
          ? 'assets/move_effects/moonblast.png'
          : move.name.toLowerCase() == 'air slash'
          ? 'assets/move_effects/air_slash.png'
          : move.name.toLowerCase() == 'aura sphere'
          ? 'assets/move_effects/aura_sphere.png'
          : move.name.toLowerCase() == 'focus blast'
          ? 'assets/move_effects/focus_blast.png'
          : move.name.toLowerCase() == 'electro ball'
          ? 'assets/move_effects/electric_ball.png'
          : move.name.toLowerCase() == 'volt switch'
          ? 'assets/move_effects/electric_ball.png'
          : move.name.toLowerCase() == 'u-turn'
          ? 'assets/move_effects/greenball.png'
          : move.name.toLowerCase() == 'flip turn'
          ? 'assets/move_effects/blueball.png'
          : 'assets/move_effects/slash.png';

      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: SlashEffect(
              imagePath: imagePath,
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'brave_bird') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: BraveBirdEffect(
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'bite') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: BiteEffect(progress: _progress.value, isPlayer: isPlayer),
          );
        },
      );
    }
    if (move.animationType == 'buff') {
      final imagePath = move.name.toLowerCase() == 'swords dance'
          ? 'assets/move_effects/sword.png'
          : 'assets/move_effects/sword.png';
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: attackerLink, // Anchor to the user of the move
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: BuffEffect(
              progress: _progress.value,
              isPlayer: isPlayer,
              imagePath: imagePath,
            ),
          );
        },
      );
    }
    if (move.animationType == 'protect') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: attackerLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: ProtectEffect(progress: _progress.value, isPlayer: isPlayer),
          );
        },
      );
    }
    if (move.animationType == 'drain') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: DrainEffect(progress: _progress.value, isPlayer: isPlayer),
          );
        },
      );
    }
    if (move.animationType == 'surf') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: SurfEffect(progress: _progress.value, isPlayer: isPlayer),
          );
        },
      );
    }
    if (move.animationType == 'hurricane') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: HurricaneEffect(
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }
    if (move.animationType == 'thunder') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: ThunderEffect(progress: _progress.value),
          );
        },
      );
    }
    if (move.animationType == 'melee') {
      final isKick = move.name.toLowerCase().contains('kick');
      final imagePath = isKick
          ? 'assets/move_effects/kick.png'
          : 'assets/move_effects/punch.png';

      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: MeleeEffect(
              imagePath: imagePath,
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'spam_attack') {
      String imagePath;
      final rand = math.Random(42);
      if (move.name.toLowerCase() == 'close combat') {
        final options = [
          'assets/move_effects/kick.png',
          'assets/move_effects/punch.png',
        ];
        imagePath = options[rand.nextInt(options.length)];
      } else if (move.name.toLowerCase() == 'thrash') {
        final options = [
          'assets/move_effects/punch.png',
          'assets/move_effects/normal_impact.png',
        ];
        imagePath = options[rand.nextInt(options.length)];
      } else if (move.name.toLowerCase() == 'outrage') {
        final options = [
          'assets/move_effects/flame.png',
          'assets/move_effects/drake_impact.png',
        ];
        imagePath = options[rand.nextInt(options.length)];
      } else if (move.name.toLowerCase() == 'petal dance') {
        final options = [
          'assets/move_effects/flower.png',
          'assets/move_effects/grass_impact.png',
        ];
        imagePath = options[rand.nextInt(options.length)];
      } else if (move.name.toLowerCase() == 'acrobatics') {
        final options = [
          'assets/move_effects/flying_impact.png',
          'assets/move_effects/normal_impact.png',
        ];
        imagePath = options[rand.nextInt(options.length)];
      } else {
        imagePath = 'assets/move_effects/ice.png';
      }
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: SpamAttackEffect(
              progress: _progress.value,
              isPlayer: isPlayer,
              imagePath: imagePath,
            ),
          );
        },
      );
    }

    if (move.animationType == 'elemental_melee') {
      final isKick = move.name.toLowerCase().contains('kick');
      final strikeImage = isKick
          ? 'assets/move_effects/kick.png'
          : 'assets/move_effects/punch.png';

      final isAqua =
          move.type == ElementalType.aquatic ||
          move.name.toLowerCase().contains('aqua') ||
          move.name.toLowerCase().contains('water');
      final blobImage = isAqua
          ? 'assets/move_effects/aqua.png'
          : 'assets/move_effects/flame.png';

      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: ElementalMeleeEffect(
              strikeImage: strikeImage,
              blobImage: blobImage,
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'rock') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: RockEffect(progress: _progress.value, isPlayer: isPlayer),
          );
        },
      );
    }

    // if (move.animationType == 'beam_column') {
    //   return AnimatedBuilder(
    //     animation: _progress,
    //     builder: (context, _) {
    //       return CompositedTransformFollower(
    //         link: targetLink,
    //         showWhenUnlinked: false,
    //         followerAnchor: Alignment.center,
    //         targetAnchor: Alignment.center,
    //         child: IceColumnEffect(
    //           progress: _progress.value,
    //           isPlayer: isPlayer,
    //         ),
    //       );
    //     },
    //   );
    // }

    if (move.animationType == 'fire_fang') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: FangScatterEffect(
              isFire: true,
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'aqua_fang') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: FangScatterEffect(
              isAqua: true,
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }
    if (move.animationType == 'ice_fang') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: FangScatterEffect(
              isCryo: true,
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'single_attack') {
      // ice_shard_single
      final imagePath = move.name.toLowerCase() == 'water gun'
          ? 'assets/move_effects/aqua.png'
          : move.name.toLowerCase() == 'ember'
          ? 'assets/move_effects/flame.png'
          : move.name.toLowerCase() == 'sludge'
          ? 'assets/move_effects/sludge.png'
          : move.name.toLowerCase() == 'toxic'
          ? 'assets/move_effects/sludge.png'
          : 'assets/move_effects/ice.png';
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: SingleProjectileEffect(
              imagePath: imagePath,
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'water_spout') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: SpoutEffect(
              isWater: true,
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'eruption') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: SpoutEffect(
              isFireRock: true,
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'beam_column') {
      List<String> imagePaths;
      if (move.name.toLowerCase() == 'hyper beam') {
        imagePaths = [
          'assets/move_effects/redball.png',
          'assets/move_effects/yellowball.png',
          'assets/move_effects/smallyellowball.png',
          'assets/move_effects/smallredball.png',
        ];
      } else if (move.name.toLowerCase() == 'solar beam') {
        imagePaths = [
          'assets/move_effects/yellowball.png',
          'assets/move_effects/smallyellowball.png',
        ];
      } else {
        imagePaths = ['assets/move_effects/ice.png'];
      }
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: BeamEffect(
              imagePaths: imagePaths,
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'ice_shard') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: ShardEffect(
              imagePath: 'assets/move_effects/ice.png',
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    // Default procedural animation fallback
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        return Stack(
          children: [
            // Attacker flash (brief glow at origin)
            CompositedTransformFollower(
              link: attackerLink,
              showWhenUnlinked: false,
              followerAnchor: Alignment.center,
              targetAnchor: Alignment.center,
              child: Opacity(
                opacity: (1.0 - _progress.value * 2).clamp(0.0, 1.0),
                child: _buildAttackerGlow(color, move.type, move.category),
              ),
            ),
            // Target hit effect
            CompositedTransformFollower(
              link: targetLink,
              showWhenUnlinked: false,
              followerAnchor: Alignment.center,
              targetAnchor: Alignment.center,
              child: _buildTargetEffect(
                color,
                move.type,
                move.category,
                _progress.value,
                isPlayer,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAttackerGlow(Color color, ElementalType type, MoveCategory cat) {
    return SizedBox(
      width: 100,
      height: 100,
      child: CustomPaint(painter: _GlowPainter(color: color, intensity: 0.8)),
    );
  }

  Widget _buildTargetEffect(
    Color color,
    ElementalType type,
    MoveCategory cat,
    double progress,
    bool isPlayer,
  ) {
    final size = 160.0;
    // Flip horizontally if the target is the opponent (so projectiles face the right direction)
    final flipX = !isPlayer; // effects point toward the target

    switch (cat) {
      case MoveCategory.physical:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _PhysicalHitPainter(
              type: type,
              color: color,
              progress: progress,
              flip: flipX,
            ),
          ),
        );
      case MoveCategory.special:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _SpecialHitPainter(
              type: type,
              color: color,
              progress: progress,
              flip: flipX,
            ),
          ),
        );
      case MoveCategory.status:
        return SizedBox(
          width: size,
          height: size,
          child: CustomPaint(
            painter: _StatusEffectPainter(
              type: type,
              color: color,
              progress: progress,
            ),
          ),
        );
    }
  }
}

// ----------------------------------------------------------------
// Glow painter for attacker charge-up
// ----------------------------------------------------------------
class _GlowPainter extends CustomPainter {
  final Color color;
  final double intensity;
  _GlowPainter({required this.color, required this.intensity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: intensity),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: 50));
    canvas.drawCircle(center, 50, paint);
  }

  @override
  bool shouldRepaint(_GlowPainter old) => old.intensity != intensity;
}

// ----------------------------------------------------------------
// Shared Painters for Procedural Effects
// ----------------------------------------------------------------
class _PhysicalHitPainter extends CustomPainter {
  final ElementalType type;
  final Color color;
  final double progress; // 0.0 → 1.0
  final bool flip;

  _PhysicalHitPainter({
    required this.type,
    required this.color,
    required this.progress,
    required this.flip,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (flip) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final cx = size.width / 2;
    final cy = size.height / 2;
    final p = progress;
    final fade = (1.0 - p).clamp(0.0, 1.0);
    final paint = Paint()..style = PaintingStyle.fill;

    switch (type) {
      // Basic — plain X-slash slashes
      case ElementalType.basic:
        paint.color = color.withValues(alpha: fade);
        paint.strokeWidth = 6 * (1 - p * 0.5);
        paint.style = PaintingStyle.stroke;
        _drawSlash(canvas, cx, cy, 50 * p, paint);
        break;

      // Flying — feather-arc sweep
      case ElementalType.flying:
        paint.color = color.withValues(alpha: fade);
        final r = 55.0 * p;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          -math.pi / 4,
          math.pi * 1.2 * p,
          false,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6,
        );
        // Feather tip circles
        for (int i = 0; i < 4; i++) {
          final angle = -math.pi / 4 + (math.pi * 1.2 * p) * i / 3;
          final dx = cx + math.cos(angle) * r;
          final dy = cy + math.sin(angle) * r;
          canvas.drawCircle(
            Offset(dx, dy),
            5 * fade,
            Paint()..color = color.withValues(alpha: fade * 0.8),
          );
        }
        break;

      // Aquatic — wave slash
      case ElementalType.aquatic:
        final path = Path();
        path.moveTo(cx - 50 * p, cy);
        for (int i = 0; i <= 30; i++) {
          final t = i / 30;
          final x = cx - 50 * p + t * 100 * p;
          final y = cy + math.sin(t * math.pi * 2) * 15 * fade;
          path.lineTo(x, y);
        }
        canvas.drawPath(
          path,
          paint
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = color.withValues(alpha: fade),
        );
        break;

      // Earth — impact shockwave ring
      case ElementalType.earth:
        for (int i = 0; i < 3; i++) {
          final r = (30 + i * 12) * p;
          canvas.drawCircle(
            Offset(cx, cy),
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4.0 - i
              ..color = color.withValues(alpha: fade * (1.0 - i * 0.25)),
          );
        }
        // Ground crack lines
        paint.color = color.withValues(alpha: fade);
        paint.strokeWidth = 3;
        paint.style = PaintingStyle.stroke;
        for (int i = 0; i < 6; i++) {
          final angle = math.pi * 2 * i / 6 + p * 0.5;
          canvas.drawLine(
            Offset(cx, cy),
            Offset(
              cx + math.cos(angle) * 50 * p,
              cy + math.sin(angle) * 50 * p,
            ),
            paint,
          );
        }
        break;

      // Cryo — ice shard burst
      case ElementalType.cryo:
        for (int i = 0; i < 8; i++) {
          final angle = math.pi * 2 * i / 8;
          final len = 45 * p;
          final tip = Offset(
            cx + math.cos(angle) * len,
            cy + math.sin(angle) * len,
          );
          final base1 = Offset(
            cx + math.cos(angle + 0.35) * 8,
            cy + math.sin(angle + 0.35) * 8,
          );
          final base2 = Offset(
            cx + math.cos(angle - 0.35) * 8,
            cy + math.sin(angle - 0.35) * 8,
          );
          final path = Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(base1.dx, base1.dy)
            ..lineTo(base2.dx, base2.dy)
            ..close();
          canvas.drawPath(
            path,
            Paint()..color = color.withValues(alpha: fade * 0.9),
          );
        }
        break;

      // Toxic — splat blob
      case ElementalType.toxic:
        final r = 40.0 * p;
        paint.color = color.withValues(alpha: fade * 0.85);
        canvas.drawCircle(Offset(cx, cy), r, paint);
        // Droplets
        for (int i = 0; i < 5; i++) {
          final angle = math.pi * 2 * i / 5;
          final dr = r * 1.4;
          canvas.drawCircle(
            Offset(cx + math.cos(angle) * dr, cy + math.sin(angle) * dr),
            8 * p * fade,
            Paint()..color = color.withValues(alpha: fade * 0.6),
          );
        }
        break;

      // Rock — boulder chunks
      case ElementalType.rock:
        final rand = math.Random(42);
        for (int i = 0; i < 8; i++) {
          final angle = math.pi * 2 * i / 8 + rand.nextDouble();
          final dist = 15 + rand.nextDouble() * 35 * p;
          final bx = cx + math.cos(angle) * dist;
          final by = cy + math.sin(angle) * dist;
          final rect = Rect.fromCenter(
            center: Offset(bx, by),
            width: (8 + rand.nextDouble() * 8) * (1 - p * 0.3),
            height: (8 + rand.nextDouble() * 8) * (1 - p * 0.3),
          );
          canvas.drawRect(rect, Paint()..color = color.withValues(alpha: fade));
        }
        break;

      // Arthropod — claw marks (3 downward slashes)
      case ElementalType.arthropod:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        for (int i = -1; i <= 1; i++) {
          paint.color = color.withValues(alpha: fade);
          final ox = cx + i * 18.0;
          canvas.drawLine(
            Offset(ox - 10, cy - 35 * p),
            Offset(ox + 10, cy + 35 * p),
            paint,
          );
        }
        break;

      // Electric — lightning bolt
      case ElementalType.electric:
        final path = Path();
        path.moveTo(cx - 10, cy - 50 * p);
        path.lineTo(cx + 8, cy - 5 * p);
        path.lineTo(cx - 8, cy + 5 * p);
        path.lineTo(cx + 10, cy + 50 * p);
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7
            ..strokeJoin = StrokeJoin.round
            ..color = color.withValues(alpha: fade),
        );
        // Inner bright core
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = Colors.white.withValues(alpha: fade * 0.8),
        );
        break;

      // Darkness — void spiral
      case ElementalType.darkness:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
        for (int i = 0; i < 3; i++) {
          final r2 = (20 + i * 12) * p;
          paint.color = color.withValues(alpha: fade * (1 - i * 0.2));
          final sweepAngle = math.pi * 2 * p;
          canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: r2),
            -math.pi / 2 + i * math.pi / 3,
            sweepAngle,
            false,
            paint,
          );
        }
        // Dark shroud
        canvas.drawCircle(
          Offset(cx, cy),
          40 * p,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withValues(alpha: fade * 0.3),
        );
        break;

      // Martial — impact stars + ring
      case ElementalType.martial:
        // Ring
        canvas.drawCircle(
          Offset(cx, cy),
          55 * p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = color.withValues(alpha: fade),
        );
        // 5-pointed star
        _drawStar(
          canvas,
          Offset(cx, cy),
          40 * p,
          5,
          color.withValues(alpha: fade),
        );
        break;

      // Blaze — fire burst
      case ElementalType.blaze:
        final rand2 = math.Random(12);
        for (int i = 0; i < 10; i++) {
          final angle = math.pi * 2 * rand2.nextDouble();
          final len = (20 + rand2.nextDouble() * 40) * p;
          final path = Path();
          path.moveTo(cx, cy);
          path.lineTo(cx + math.cos(angle) * len, cy + math.sin(angle) * len);
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4 + rand2.nextDouble() * 4
              ..color = color.withValues(alpha: fade * 0.9),
          );
        }
        // Core glow
        canvas.drawCircle(
          Offset(cx, cy),
          18 * p,
          Paint()
            ..style = PaintingStyle.fill
            ..color = Colors.white.withValues(alpha: fade * 0.6),
        );
        break;

      // Grass — leaf fan
      case ElementalType.grass:
        for (int i = 0; i < 6; i++) {
          final angle = math.pi * 2 * i / 6;
          final len = 50 * p;
          final ctrl = Offset(
            cx + math.cos(angle + 0.4) * len * 0.6,
            cy + math.sin(angle + 0.4) * len * 0.6,
          );
          final end = Offset(
            cx + math.cos(angle) * len,
            cy + math.sin(angle) * len,
          );
          final path = Path()
            ..moveTo(cx, cy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy);
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..color = color.withValues(alpha: fade * 0.9),
          );
        }
        break;

      // Mystic — energy sigil rings
      case ElementalType.mystic:
        for (int i = 0; i < 4; i++) {
          final r3 = (10 + i * 12) * p;
          canvas.drawCircle(
            Offset(
              cx + math.cos(math.pi / 4 + i) * 10 * p,
              cy + math.sin(math.pi / 4 + i) * 10 * p,
            ),
            r3,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color.withValues(alpha: fade * (0.6 + i * 0.1)),
          );
        }
        break;

      // Spectral — ghostly wisp
      case ElementalType.spectral:
        for (int i = 0; i < 3; i++) {
          final ox = cx + (i - 1) * 20.0;
          final r4 = (25 + i * 8) * p;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(ox, cy),
              width: r4,
              height: r4 * 1.5,
            ),
            Paint()
              ..style = PaintingStyle.fill
              ..color = color.withValues(alpha: fade * (0.4 - i * 0.05)),
          );
        }
        break;

      // Drake — dragon claw + breath
      case ElementalType.drake:
        // Three wide claw marks
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;
        for (int i = -1; i <= 1; i++) {
          paint.color = color.withValues(alpha: fade);
          final ox = cx + i * 22.0;
          canvas.drawLine(
            Offset(ox - 15, cy - 40 * p),
            Offset(ox + 15, cy + 40 * p),
            paint,
          );
        }
        // Breath glow
        canvas.drawCircle(
          Offset(cx, cy),
          30 * p,
          Paint()
            ..style = PaintingStyle.fill
            ..color = color.withValues(alpha: fade * 0.4),
        );
        break;

      // Metal — gear/gear-spike burst
      case ElementalType.metal:
        _drawStar(
          canvas,
          Offset(cx, cy),
          50 * p,
          6,
          color.withValues(alpha: fade * 0.8),
        );
        canvas.drawCircle(
          Offset(cx, cy),
          15 * p,
          Paint()..color = Colors.white.withValues(alpha: fade * 0.9),
        );
        break;

      // Aura — pulsing concentric rings
      case ElementalType.aura:
        for (int i = 0; i < 4; i++) {
          final r5 = (15 + i * 14) * p;
          canvas.drawCircle(
            Offset(cx, cy),
            r5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color.withValues(alpha: fade * (0.9 - i * 0.15)),
          );
        }
        break;

      // Sound — expanding sound wave arcs
      case ElementalType.sound:
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4;
        for (int i = 0; i < 5; i++) {
          final r6 = (15 + i * 16) * p;
          paint.color = color.withValues(alpha: fade * (1 - i * 0.15));
          canvas.drawArc(
            Rect.fromCircle(center: Offset(cx, cy), radius: r6),
            -math.pi * 0.7,
            math.pi * 1.4,
            false,
            paint,
          );
        }
        break;

      // Holy — radiant cross + halo
      case ElementalType.holy:
        // Halo
        canvas.drawCircle(
          Offset(cx, cy),
          50 * p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..color = color.withValues(alpha: fade),
        );
        // Radiant cross
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Colors.white.withValues(alpha: fade);
        canvas.drawLine(
          Offset(cx, cy - 50 * p),
          Offset(cx, cy + 50 * p),
          paint,
        );
        canvas.drawLine(
          Offset(cx - 50 * p, cy),
          Offset(cx + 50 * p, cy),
          paint,
        );
        break;
    }
  }

  void _drawSlash(
    Canvas canvas,
    double cx,
    double cy,
    double len,
    Paint paint,
  ) {
    canvas.drawLine(
      Offset(cx - len, cy - len),
      Offset(cx + len, cy + len),
      paint,
    );
    canvas.drawLine(
      Offset(cx + len, cy - len),
      Offset(cx - len, cy + len),
      paint,
    );
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    double radius,
    int points,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = -math.pi / 2 + math.pi * i / points;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PhysicalHitPainter old) => old.progress != progress;
}

// ----------------------------------------------------------------
// Special Hit Painter — projectile shapes per type
// ----------------------------------------------------------------
class _SpecialHitPainter extends CustomPainter {
  final ElementalType type;
  final Color color;
  final double progress;
  final bool flip;

  _SpecialHitPainter({
    required this.type,
    required this.color,
    required this.progress,
    required this.flip,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (flip) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final cx = size.width / 2;
    final cy = size.height / 2;
    final p = progress;
    final fade = (1.0 - p).clamp(0.0, 1.0);
    final paint = Paint()..style = PaintingStyle.fill;

    // Phases: 0-0.5 = projectile travels, 0.5-1.0 = impact explosion
    final travelPhase = (p * 2).clamp(0.0, 1.0);
    final impactPhase = ((p - 0.5) * 2).clamp(0.0, 1.0);

    switch (type) {
      // Basic — orb projectile
      case ElementalType.basic:
        _drawOrb(canvas, cx, cy, travelPhase, impactPhase, color, fade);
        break;

      // Flying — wind dart
      case ElementalType.flying:
        _drawWindDart(canvas, cx, cy, travelPhase, impactPhase, color, fade);
        break;

      // Aquatic — water bubble
      case ElementalType.aquatic:
        final bx = cx - 60 + travelPhase * 60;
        final by = cy;
        final r = 18 * (1 - impactPhase * 0.7);
        canvas.drawCircle(
          Offset(bx, by),
          r,
          paint..color = color.withValues(alpha: fade * 0.85),
        );
        canvas.drawCircle(
          Offset(bx, by),
          r * 0.6,
          Paint()..color = Colors.white.withValues(alpha: fade * 0.4),
        );
        if (impactPhase > 0) {
          // Splash
          for (int i = 0; i < 6; i++) {
            final angle = math.pi * 2 * i / 6;
            final dist = impactPhase * 40;
            canvas.drawCircle(
              Offset(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist),
              5 * (1 - impactPhase),
              Paint()..color = color.withValues(alpha: fade * 0.7),
            );
          }
        }
        break;

      // Earth — boulder projectile
      case ElementalType.earth:
        final bx = cx - 60 + travelPhase * 60;
        final by = cy + travelPhase * 5;
        if (impactPhase == 0) {
          final rect = Rect.fromCenter(
            center: Offset(bx, by),
            width: 28,
            height: 24,
          );
          canvas.drawRect(rect, paint..color = color.withValues(alpha: fade));
        } else {
          // Fragment explosion
          final rand = math.Random(7);
          for (int i = 0; i < 8; i++) {
            final angle = math.pi * 2 * rand.nextDouble();
            final dist = impactPhase * 45 * rand.nextDouble();
            final frag = Rect.fromCenter(
              center: Offset(
                cx + math.cos(angle) * dist,
                cy + math.sin(angle) * dist,
              ),
              width: 8 * (1 - impactPhase),
              height: 8 * (1 - impactPhase),
            );
            canvas.drawRect(
              frag,
              Paint()..color = color.withValues(alpha: fade),
            );
          }
        }
        break;

      // Cryo — ice shard spear
      case ElementalType.cryo:
        final bx = cx - 60 + travelPhase * 55;
        final by = cy;
        final shardPath = Path()
          ..moveTo(bx + 24, by)
          ..lineTo(bx, by - 8)
          ..lineTo(bx - 8, by)
          ..lineTo(bx, by + 8)
          ..close();
        canvas.drawPath(
          shardPath,
          paint..color = color.withValues(alpha: fade * 0.9),
        );
        canvas.drawPath(
          shardPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = Colors.white.withValues(alpha: fade * 0.5),
        );
        if (impactPhase > 0) {
          for (int i = 0; i < 6; i++) {
            final angle = math.pi * 2 * i / 6;
            final len = impactPhase * 40;
            canvas.drawLine(
              Offset(cx, cy),
              Offset(cx + math.cos(angle) * len, cy + math.sin(angle) * len),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = color.withValues(alpha: fade * 0.8),
            );
          }
        }
        break;

      // Toxic — poison cloud
      case ElementalType.toxic:
        final bx = cx - 60 + travelPhase * 60;
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(bx + i * 8.0, cy - i * 5.0),
            (12 + i * 5) * (1 - p * 0.3),
            Paint()..color = color.withValues(alpha: fade * (0.7 - i * 0.15)),
          );
        }
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 50,
            Paint()..color = color.withValues(alpha: fade * 0.35),
          );
        }
        break;

      // Rock — stone lob (parabolic)
      case ElementalType.rock:
        final bx = cx - 60 + travelPhase * 60;
        final by = cy - math.sin(travelPhase * math.pi) * 30;
        canvas.drawCircle(
          Offset(bx, by),
          14,
          paint..color = color.withValues(alpha: fade),
        );
        if (impactPhase > 0) {
          // Dust cloud
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 40,
            Paint()..color = color.withValues(alpha: fade * 0.3),
          );
        }
        break;

      // Arthropod — stinger dart
      case ElementalType.arthropod:
        final bx = cx - 65 + travelPhase * 65;
        final path = Path()
          ..moveTo(bx + 20, cy)
          ..lineTo(bx, cy - 6)
          ..lineTo(bx - 5, cy)
          ..lineTo(bx, cy + 6)
          ..close();
        canvas.drawPath(path, paint..color = color.withValues(alpha: fade));
        break;

      // Electric — lightning bolt projectile
      case ElementalType.electric:
        final bx = cx - 60 + travelPhase * 55;
        final zap = Path()
          ..moveTo(bx, cy - 20)
          ..lineTo(bx + 12, cy - 2)
          ..lineTo(bx + 4, cy + 2)
          ..lineTo(bx + 16, cy + 20);
        canvas.drawPath(
          zap,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..color = color.withValues(alpha: fade),
        );
        canvas.drawPath(
          zap,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = Colors.white.withValues(alpha: fade * 0.9),
        );
        if (impactPhase > 0) {
          for (int i = 0; i < 8; i++) {
            final angle = math.pi * 2 * i / 8;
            final len = impactPhase * 40;
            canvas.drawLine(
              Offset(cx, cy),
              Offset(cx + math.cos(angle) * len, cy + math.sin(angle) * len),
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = color.withValues(alpha: fade * 0.9),
            );
          }
        }
        break;

      // Darkness — shadow orb
      case ElementalType.darkness:
        final bx = cx - 60 + travelPhase * 60;
        canvas.drawCircle(
          Offset(bx, cy),
          20,
          paint..color = color.withValues(alpha: fade * 0.9),
        );
        canvas.drawCircle(
          Offset(bx - 5, cy - 5),
          8,
          Paint()..color = Colors.deepPurple.withValues(alpha: fade * 0.5),
        );
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 55,
            Paint()..color = color.withValues(alpha: fade * 0.25),
          );
        }
        break;

      // Martial — ki blast
      case ElementalType.martial:
        _drawOrb(canvas, cx, cy, travelPhase, impactPhase, color, fade);
        break;

      // Blaze — fireball
      case ElementalType.blaze:
        final bx = cx - 70 + travelPhase * 65;
        canvas.drawCircle(
          Offset(bx, cy),
          20 - travelPhase * 4,
          paint..color = color.withValues(alpha: fade),
        );
        canvas.drawCircle(
          Offset(bx, cy),
          10 - travelPhase * 3,
          Paint()..color = Colors.yellow.withValues(alpha: fade * 0.8),
        );
        // Flame trail
        final trailCells = 4;
        for (int i = 1; i <= trailCells; i++) {
          final tx = bx - i * 12.0;
          canvas.drawCircle(
            Offset(tx, cy),
            (8 - i * 1.5) * (1 - travelPhase * 0.5),
            Paint()..color = color.withValues(alpha: fade * (0.6 - i * 0.1)),
          );
        }
        if (impactPhase > 0) {
          // Explosion
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 50,
            paint..color = color.withValues(alpha: fade * 0.5),
          );
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 30,
            Paint()..color = Colors.yellow.withValues(alpha: fade * 0.7),
          );
        }
        break;

      // Grass — razor leaf
      case ElementalType.grass:
        final bx = cx - 60 + travelPhase * 60;
        final leafPath = Path()
          ..moveTo(bx, cy - 14)
          ..quadraticBezierTo(bx + 20, cy, bx, cy + 14)
          ..quadraticBezierTo(bx - 20, cy, bx, cy - 14);
        canvas.drawPath(leafPath, paint..color = color.withValues(alpha: fade));
        canvas.drawLine(
          Offset(bx - 10, cy),
          Offset(bx + 10, cy),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = Colors.white.withValues(alpha: fade * 0.5),
        );
        break;

      // Mystic — arcane missile
      case ElementalType.mystic:
        final bx = cx - 65 + travelPhase * 65;
        // Spiral trail
        for (int i = 0; i < 5; i++) {
          final tx = bx - i * 14.0;
          final angle = i * 1.2;
          canvas.drawCircle(
            Offset(tx + math.cos(angle) * 8, cy + math.sin(angle) * 8),
            (10 - i * 1.5),
            Paint()..color = color.withValues(alpha: fade * (0.8 - i * 0.1)),
          );
        }
        if (impactPhase > 0) {
          for (int i = 0; i < 6; i++) {
            final angle = math.pi * 2 * i / 6;
            canvas.drawCircle(
              Offset(
                cx + math.cos(angle) * impactPhase * 45,
                cy + math.sin(angle) * impactPhase * 45,
              ),
              8 * (1 - impactPhase),
              Paint()..color = color.withValues(alpha: fade * 0.9),
            );
          }
        }
        break;

      // Spectral — spectral beam
      case ElementalType.spectral:
        final bx = cx - 70 + travelPhase * 65;
        for (int i = 0; i < 3; i++) {
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(bx - i * 8.0, cy + (i - 1) * 6.0),
              width: 20.0,
              height: 30.0,
            ),
            Paint()..color = color.withValues(alpha: fade * (0.7 - i * 0.15)),
          );
        }
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 50,
            Paint()..color = color.withValues(alpha: fade * 0.3),
          );
        }
        break;

      // Drake — dragon beam
      case ElementalType.drake:
        // Beam
        final beamRect = Rect.fromLTWH(
          cx - 65 * (1 - travelPhase),
          cy - 8,
          65 * travelPhase,
          16,
        );
        canvas.drawRect(
          beamRect,
          paint..color = color.withValues(alpha: fade * 0.85),
        );
        // Core
        canvas.drawRect(
          Rect.fromLTWH(beamRect.left, cy - 4, beamRect.width, 8),
          Paint()..color = Colors.white.withValues(alpha: fade * 0.5),
        );
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 55,
            paint..color = color.withValues(alpha: fade * 0.5),
          );
        }
        break;

      // Metal — spinning gear projectile
      case ElementalType.metal:
        final bx = cx - 60 + travelPhase * 60;
        canvas.save();
        canvas.translate(bx, cy);
        canvas.rotate(travelPhase * math.pi * 3);
        _drawStarOnCanvas(
          canvas,
          Offset.zero,
          18,
          6,
          color.withValues(alpha: fade * 0.8),
        );
        canvas.restore();
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 45,
            paint..color = color.withValues(alpha: fade * 0.4),
          );
        }
        break;

      // Aura — aura pulse orb
      case ElementalType.aura:
        final bx = cx - 65 + travelPhase * 65;
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(bx, cy),
            (18 - i * 4) *
                (0.8 + math.sin(travelPhase * math.pi * 4 + i) * 0.2),
            Paint()..color = color.withValues(alpha: fade * (0.9 - i * 0.2)),
          );
        }
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 50,
            paint..color = color.withValues(alpha: fade * 0.4),
          );
        }
        break;

      // Sound — sonic ring
      case ElementalType.sound:
        final bx = cx - 65 + travelPhase * 65;
        for (int i = 0; i < 4; i++) {
          canvas.drawCircle(
            Offset(bx, cy),
            (8 + i * 10).toDouble() * travelPhase,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color.withValues(alpha: fade * (0.9 - i * 0.15)),
          );
        }
        if (impactPhase > 0) {
          for (int i = 0; i < 5; i++) {
            final r = (10 + i * 15) * impactPhase;
            canvas.drawCircle(
              Offset(cx, cy),
              r,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 3
                ..color = color.withValues(alpha: fade * (0.8 - i * 0.12)),
            );
          }
        }
        break;

      // Holy — holy beam
      case ElementalType.holy:
        final beamW = travelPhase * 65;
        final beamRect = Rect.fromLTWH(cx - beamW, cy - 10, beamW, 20);
        canvas.drawRect(
          beamRect,
          paint..color = color.withValues(alpha: fade * 0.6),
        );
        canvas.drawRect(
          Rect.fromLTWH(cx - beamW, cy - 4, beamW, 8),
          Paint()..color = Colors.white.withValues(alpha: fade * 0.8),
        );
        if (impactPhase > 0) {
          canvas.drawCircle(
            Offset(cx, cy),
            impactPhase * 55,
            paint..color = color.withValues(alpha: fade * 0.5),
          );
          // Cross burst
          canvas.drawLine(
            Offset(cx - impactPhase * 50, cy),
            Offset(cx + impactPhase * 50, cy),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = Colors.white.withValues(alpha: fade * 0.8),
          );
          canvas.drawLine(
            Offset(cx, cy - impactPhase * 50),
            Offset(cx, cy + impactPhase * 50),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 4
              ..color = Colors.white.withValues(alpha: fade * 0.8),
          );
        }
        break;
    }
  }

  void _drawOrb(
    Canvas canvas,
    double cx,
    double cy,
    double travel,
    double impact,
    Color color,
    double fade,
  ) {
    final bx = cx - 60 + travel * 60;
    canvas.drawCircle(
      Offset(bx, cy),
      18 * (1 - impact * 0.6),
      Paint()..color = color.withValues(alpha: fade * 0.9),
    );
    canvas.drawCircle(
      Offset(bx, cy),
      10 * (1 - impact * 0.6),
      Paint()..color = Colors.white.withValues(alpha: fade * 0.5),
    );
    if (impact > 0) {
      canvas.drawCircle(
        Offset(cx, cy),
        impact * 50,
        Paint()..color = color.withValues(alpha: fade * 0.4),
      );
    }
  }

  void _drawWindDart(
    Canvas canvas,
    double cx,
    double cy,
    double travel,
    double impact,
    Color color,
    double fade,
  ) {
    final bx = cx - 65 + travel * 65;
    final path = Path()
      ..moveTo(bx + 24, cy)
      ..lineTo(bx, cy - 6)
      ..lineTo(bx - 16, cy)
      ..lineTo(bx, cy + 6)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = color.withValues(alpha: fade * 0.85),
    );
    if (impact > 0) {
      for (int i = 0; i < 6; i++) {
        final angle = math.pi * 2 * i / 6;
        canvas.drawLine(
          Offset(cx, cy),
          Offset(
            cx + math.cos(angle) * impact * 45,
            cy + math.sin(angle) * impact * 45,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = color.withValues(alpha: fade * 0.8),
        );
      }
    }
  }

  void _drawStarOnCanvas(
    Canvas canvas,
    Offset center,
    double radius,
    int points,
    Color color,
  ) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    for (int i = 0; i < points * 2; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = -math.pi / 2 + math.pi * i / points;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SpecialHitPainter old) => old.progress != progress;
}

// ----------------------------------------------------------------
// Status Effect Painter — aura/buff animations per type
// ----------------------------------------------------------------
class _StatusEffectPainter extends CustomPainter {
  final ElementalType type;
  final Color color;
  final double progress;

  _StatusEffectPainter({
    required this.type,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final p = progress;
    // Status animations: rise upward + fade
    final fadeOut = (1.0 - p).clamp(0.0, 1.0);
    final riseY = cy - p * 40;
    final paint = Paint();

    switch (type) {
      case ElementalType.toxic:
        // Dripping bubbles
        for (int i = 0; i < 5; i++) {
          final angle = math.pi * 2 * i / 5;
          final ox = cx + math.cos(angle) * 35;
          final oy = riseY + math.sin(angle) * 20;
          canvas.drawCircle(
            Offset(ox, oy),
            8 + i * 2.0,
            paint..color = color.withValues(alpha: fadeOut * 0.7),
          );
        }
        break;

      case ElementalType.blaze:
        // Rising embers
        final rand = math.Random(3);
        for (int i = 0; i < 8; i++) {
          final ox = cx + (rand.nextDouble() - 0.5) * 60;
          final oy = riseY - i * 8.0 + rand.nextDouble() * 10;
          canvas.drawCircle(
            Offset(ox, oy),
            3 + rand.nextDouble() * 4,
            paint..color = color.withValues(alpha: fadeOut * 0.8),
          );
        }
        break;

      case ElementalType.cryo:
        // Snowflake descend
        for (int i = 0; i < 6; i++) {
          final angle = math.pi * 2 * i / 6;
          final len = 30 + math.sin(p * math.pi) * 15;
          canvas.drawLine(
            Offset(cx, riseY),
            Offset(cx + math.cos(angle) * len, riseY + math.sin(angle) * len),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = color.withValues(alpha: fadeOut),
          );
          // Mini cross
          canvas.drawLine(
            Offset(
              cx + math.cos(angle) * len * 0.6,
              riseY + math.sin(angle) * len * 0.6,
            ),
            Offset(
              cx +
                  math.cos(angle) * len * 0.6 +
                  math.cos(angle + math.pi / 2) * 8,
              riseY +
                  math.sin(angle) * len * 0.6 +
                  math.sin(angle + math.pi / 2) * 8,
            ),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = color.withValues(alpha: fadeOut * 0.7),
          );
        }
        break;

      case ElementalType.electric:
        // Jolts
        for (int i = 0; i < 4; i++) {
          final ox = cx + (i - 1.5) * 20.0;
          final path = Path()
            ..moveTo(ox - 4, riseY - 25)
            ..lineTo(ox + 4, riseY)
            ..lineTo(ox - 4, riseY + 5)
            ..lineTo(ox + 4, riseY + 25);
          canvas.drawPath(
            path,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color.withValues(alpha: fadeOut),
          );
        }
        break;

      case ElementalType.darkness:
        // Dark swirling wisps
        for (int i = 0; i < 4; i++) {
          final angle = p * math.pi * 2 + i * math.pi / 2;
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(
                cx + math.cos(angle) * 25,
                riseY + math.sin(angle) * 15,
              ),
              width: 20,
              height: 30,
            ),
            paint..color = color.withValues(alpha: fadeOut * 0.5),
          );
        }
        break;

      case ElementalType.holy:
        // Rising sparks
        for (int i = 0; i < 6; i++) {
          final angle = math.pi * 2 * i / 6;
          final dist = 30 + math.sin(p * math.pi) * 20;
          canvas.drawCircle(
            Offset(
              cx + math.cos(angle) * dist,
              riseY + math.sin(angle) * dist * 0.4,
            ),
            5 * fadeOut,
            paint..color = color.withValues(alpha: fadeOut),
          );
        }
        break;

      case ElementalType.grass:
        // Leaves swirling up
        final rand2 = math.Random(9);
        for (int i = 0; i < 6; i++) {
          final angle = p * math.pi * 3 + i * math.pi / 3;
          final dist = 20 + rand2.nextDouble() * 25;
          final lx = cx + math.cos(angle) * dist;
          final ly = riseY + math.sin(angle) * dist * 0.5;
          final leafPath = Path()
            ..moveTo(lx, ly - 8)
            ..quadraticBezierTo(lx + 8, ly, lx, ly + 8)
            ..quadraticBezierTo(lx - 8, ly, lx, ly - 8);
          canvas.drawPath(
            leafPath,
            paint..color = color.withValues(alpha: fadeOut * 0.8),
          );
        }
        break;

      case ElementalType.spectral:
        // Ghostly orbs
        for (int i = 0; i < 3; i++) {
          final angle = p * math.pi * 2 + i * math.pi * 2 / 3;
          canvas.drawCircle(
            Offset(cx + math.cos(angle) * 30, riseY + math.sin(angle) * 20),
            12 * fadeOut,
            paint..color = color.withValues(alpha: fadeOut * 0.6),
          );
        }
        break;

      case ElementalType.aura:
        // Pulsing rings
        for (int i = 0; i < 3; i++) {
          final r = (20 + i * 15) * (0.7 + math.sin(p * math.pi * 2) * 0.3);
          canvas.drawCircle(
            Offset(cx, riseY + 10),
            r,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = color.withValues(alpha: fadeOut * (0.9 - i * 0.2)),
          );
        }
        break;

      case ElementalType.mystic:
        // Sigil spirals
        for (int i = 0; i < 12; i++) {
          final angle = math.pi * 2 * i / 12;
          final r = 35 * (0.5 + p * 0.5);
          canvas.drawCircle(
            Offset(
              cx + math.cos(angle + p * math.pi * 2) * r,
              riseY + math.sin(angle + p * math.pi * 2) * r * 0.5,
            ),
            4,
            paint..color = color.withValues(alpha: fadeOut * 0.8),
          );
        }
        break;

      default:
        // Generic: expanding rings
        for (int i = 0; i < 3; i++) {
          canvas.drawCircle(
            Offset(cx, riseY),
            (20 + i * 15) * p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.5
              ..color = color.withValues(alpha: fadeOut * (0.8 - i * 0.2)),
          );
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_StatusEffectPainter old) => old.progress != progress;
}

// ----------------------------------------------------------------
// Single Projectile Effect
// ----------------------------------------------------------------
class SingleProjectileEffect extends StatelessWidget {
  final String imagePath;
  final double progress;
  final bool isPlayer;

  const SingleProjectileEffect({
    super.key,
    required this.imagePath,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    final p = progress.clamp(0.0, 1.0);

    final cx = size / 2;
    final cy = size / 2;

    // From attacker to target
    double startX = cx - 210;
    double startY = cy + 150;
    double endX = cx;
    double endY = cy;

    if (!isPlayer) {
      startX = cx + 180;
      startY = cy - 180;
    }

    final currentX = startX + (endX - startX) * p;
    final currentY = startY + (endY - startY) * p;

    final rotation =
        math.atan2(endY - startY, endX - startX) + (p * math.pi * 4);
    final opacity = p > 0.9 ? (1.0 - p) / 0.1 : 1.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: currentX - 25,
            top: currentY - 25,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: rotation,
                child: Image.asset(
                  imagePath,
                  width: 50,
                  height: 50,
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
// Fang Scatter Effect (Bite + Elemental Burst)
// ----------------------------------------------------------------
class FangScatterEffect extends StatelessWidget {
  final bool isFire;
  final bool isAqua;
  final bool isCryo;
  final double progress;
  final bool isPlayer;

  const FangScatterEffect({
    super.key,
    this.isFire = false,
    this.isAqua = false,
    this.isCryo = false,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    final p = progress.clamp(0.0, 1.0);

    // 0.0-0.4: Bite
    // 0.4-1.0: Scatter
    final biteP = (p / 0.4).clamp(0.0, 1.0);
    final scatterP = ((p - 0.4) / 0.6).clamp(0.0, 1.0);

    const numExplosions = 10;
    final assetPath = isFire
        ? 'assets/move_effects/flame.png'
        : isCryo
        ? 'assets/move_effects/ice.png'
        : 'assets/move_effects/aqua.png';

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (biteP < 1.0) BiteEffect(progress: biteP, isPlayer: isPlayer),
          if (scatterP > 0)
            ...List.generate(numExplosions, (index) {
              final rand = math.Random(index);
              final angle = rand.nextDouble() * math.pi * 2;
              final speed = 40.0 + rand.nextDouble() * 60.0;

              final dx = math.cos(angle) * speed * scatterP;
              final dy = math.sin(angle) * speed * scatterP;

              final opacity = (1.0 - scatterP).clamp(0.0, 1.0);
              final scale = 0.5 + scatterP * 1.5;

              return Positioned(
                left: (size / 2) + dx - 20,
                top: (size / 2) + dy - 20,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Image.asset(
                      assetPath,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------
// Spout Effect (Rising from Attacker, Falling on Target)
// ----------------------------------------------------------------
class SpoutEffect extends StatelessWidget {
  final bool isWater;
  final bool isFireRock;
  final double progress;
  final bool isPlayer;

  const SpoutEffect({
    super.key,
    this.isWater = false,
    this.isFireRock = false,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 160.0;
    final p = progress.clamp(0.0, 1.0);

    // 0.0-0.5: Spout rising from attacker
    // 0.5-1.0: Falling on target
    final spoutP = (p / 0.5).clamp(0.0, 1.0);
    final fallingP = ((p - 0.5) / 0.5).clamp(0.0, 1.0);

    const numParticles = 8;
    final cx = size / 2;
    final cy = size / 2;

    // Attacker position relative to target
    double attackerX = cx - 250;
    double attackerY = cy + 150;
    if (!isPlayer) {
      attackerX = cx + 250;
      attackerY = cy - 150;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Rising Spout
          if (spoutP > 0 && spoutP < 1.0)
            ...List.generate(numParticles, (index) {
              final rand = math.Random(index);
              final individualP = (spoutP * 1.5 - (index * 0.1)).clamp(
                0.0,
                1.0,
              );
              if (individualP <= 0 || individualP >= 1.0) {
                return const SizedBox.shrink();
              }

              final dy = -150.0 * individualP;
              final dx = (rand.nextDouble() * 40 - 20) * individualP;

              final asset = isWater
                  ? 'assets/move_effects/aqua.png'
                  : (rand.nextBool()
                        ? 'assets/move_effects/rock.png'
                        : 'assets/move_effects/flame.png');

              return Positioned(
                left: attackerX + dx - 20,
                top: attackerY + dy - 20,
                child: Opacity(
                  opacity: (1.0 - individualP).clamp(0.0, 1.0),
                  child: Image.asset(
                    asset,
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            }),

          // Falling on Target
          if (fallingP > 0)
            ...List.generate(numParticles, (index) {
              final rand = math.Random(index + 50);
              final individualP = (fallingP * 1.5 - (index * 0.1)).clamp(
                0.0,
                1.0,
              );
              if (individualP <= 0 || individualP >= 1.0) {
                return const SizedBox.shrink();
              }

              final startY = -200.0;
              final endY = cy;
              final currentY = startY + (endY - startY) * individualP;
              final dx = (rand.nextDouble() * 100 - 50);

              final asset = isWater
                  ? 'assets/move_effects/aqua.png'
                  : (rand.nextBool()
                        ? 'assets/move_effects/rock.png'
                        : 'assets/move_effects/flame.png');

              return Positioned(
                left: cx + dx - 20,
                top: currentY - 20,
                child: Opacity(
                  opacity: individualP < 0.2
                      ? individualP / 0.2
                      : (individualP > 0.8 ? (1.0 - individualP) / 0.2 : 1.0),
                  child: Transform.rotate(
                    angle: individualP * math.pi,
                    child: Image.asset(
                      asset,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
