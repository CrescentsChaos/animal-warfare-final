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
  final List<String> imagePaths;

  const SpamAttackEffect({
    super.key,
    required this.progress,
    required this.isPlayer,
    required this.imagePaths,
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
          final p = (progress * 2.0 - delay).clamp(0.0, 1.0);

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

          // Use the passed-in imagePaths if available, otherwise fallback to the random one
          String finalImagePath = particlePath;
          if (imagePaths.isNotEmpty) {
            // Check if it's just a fallback like ice.png
            if (imagePaths.length == 1 &&
                imagePaths.first.contains('ice.png')) {
              finalImagePath = imagePaths.first;
            } else {
              // Properly randomize from the provided options
              finalImagePath = imagePaths[rand.nextInt(imagePaths.length)];
            }
          }

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
    const size = 500.0;
    final p = progress.clamp(0.0, 1.0);

    final waveOpacity = p < 0.2 ? p / 0.2 : (p > 0.8 ? (1.0 - p) / 0.2 : 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The Surf wave traversing the screen
          Transform.translate(
            offset: Offset((p - 0.5) * 600 * (isPlayer ? 1 : -1), 0),
            child: Opacity(
              opacity: waveOpacity,
              child: Transform.flip(
                flipX: !isPlayer,
                child: Image.asset(
                  'assets/move_effects/surf.png',
                  width: 450,
                  height: 250,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),

          // The impact splash expanding as the wave hits the target
          if (p > 0.5)
            Positioned(
              child: Opacity(
                opacity: (1.0 - ((p - 0.5) / 0.5)).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.5 + ((p - 0.5) * 1.5),
                  child: Image.asset(
                    'assets/move_effects/water_impact.png',
                    width: 120,
                    height: 120,
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
    final opacity = p < 0.1 ? p / 0.1 : (p > 0.85 ? (1.0 - p) / 0.15 : 1.0);

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
// Thunder Effect (Lightning Bolt & Clouds)
// ----------------------------------------------------------------
class ThunderEffect extends StatelessWidget {
  final double progress;
  final bool showClouds;

  const ThunderEffect({
    super.key,
    required this.progress,
    this.showClouds = true,
  });

  @override
  Widget build(BuildContext context) {
    const size = 400.0;
    final p = progress.clamp(0.0, 1.0);
    final flash = (math.sin(p * math.pi * 20) + 1) / 2;
    final opacity = p < 0.1 ? p / 0.1 : (p > 0.9 ? (1.0 - p) / 0.1 : 1.0);

    String lightningFrame = 'assets/move_effects/lightning_1.png';
    if (p > 0.3 && p < 0.6) {
      lightningFrame = 'assets/move_effects/lightning_2.png';
    } else if (p >= 0.6) {
      lightningFrame = 'assets/move_effects/lightning_3.png';
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          if (p > 0.1)
            Positioned(
              top: showClouds ? -120 : -200,
              child: Opacity(
                opacity: opacity * (0.6 + 0.4 * flash),
                child: Image.asset(
                  lightningFrame,
                  width: 100,
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          if (showClouds)
            Positioned(
              top: -240,
              child: Opacity(
                opacity: opacity,
                child: Image.asset(
                  'assets/move_effects/black_cloud.png',
                  width: 150,
                  height: 100,
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
          final p = (progress * 2.0 - delay).clamp(0.0, 1.0);

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
          final pLocal = (p * 2.0 - particleDelay).clamp(0.0, 1.0);

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
// Giga Impact Effect (Charge + Massive Explosion)
// ----------------------------------------------------------------
class GigaImpactEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const GigaImpactEffect({
    super.key,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 300.0;
    final p = progress.clamp(0.0, 1.0);

    final cx = size / 2;
    final cy = size / 2;

    // Phase 1: Charge (0.0 to 0.6)
    // Travel from attacker (bottom-left) to target (center)
    double startX = cx - 250;
    double startY = cy + 180;
    double endX = cx;
    double endY = cy;

    if (!isPlayer) {
      startX = cx + 250;
      startY = cy - 180;
    }

    final chargeP = (p / 0.6).clamp(0.0, 1.0);
    // Ease-in acceleration
    final travel = chargeP * chargeP;

    double currentX = startX + (endX - startX) * travel;
    double currentY = startY + (endY - startY) * travel;

    // Angle pointing from start to end
    double rotation = math.atan2(endY - startY, endX - startX);

    // Phase 2: Explosion (0.6 to 1.0)
    final explodeP = ((p - 0.6) / 0.4).clamp(0.0, 1.0);
    final explodeOpacity = explodeP < 0.2
        ? explodeP / 0.2
        : (1.0 - explodeP) / 0.8;
    final explodeScale = 0.5 + explodeP * 2.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Charging energy (Phase 1)
          if (p < 0.6)
            Positioned(
              left: currentX - 100, // centered for 200x200
              top: currentY - 100,
              child: Transform.rotate(
                angle: rotation,
                child: Image.asset(
                  'assets/move_effects/giga_impact.png',
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                ),
              ),
            ),

          // Explosion (Phase 2)
          if (p >= 0.6)
            Positioned(
              child: Opacity(
                opacity: explodeOpacity.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: explodeScale,
                  child: Image.asset(
                    'assets/move_effects/giga_impact_2.png',
                    width: 200,
                    height: 200,
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
// Leaf Storm Effect (Swirling Vortex of Leaves)
// ----------------------------------------------------------------
class LeafStormEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const LeafStormEffect({
    super.key,
    required this.progress,
    required this.isPlayer,
  });

  @override
  Widget build(BuildContext context) {
    const size = 300.0;
    final p = progress.clamp(0.0, 1.0);
    const numLeaves = 35;

    final leafAssets = [
      'assets/move_effects/leaf1.png',
      'assets/move_effects/leaf2.png',
      'assets/move_effects/leaf3.png',
    ];

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(numLeaves, (index) {
          final rand = math.Random(index + 77);
          // Staggered launch from attacker to target
          final launchDelay = index * 0.02;
          final localP = (p * 2.0 - launchDelay).clamp(0.0, 1.0);

          if (localP <= 0 || localP >= 1.0) return const SizedBox.shrink();

          final cx = size / 2;
          final cy = size / 2;

          // Main travel path
          double startX = cx - 210;
          double startY = cy + 150;
          double endX = cx;
          double endY = cy;

          if (!isPlayer) {
            startX = cx + 210;
            startY = cy - 150;
          }

          // Base position along the path
          double curX = startX + (endX - startX) * localP;
          double curY = startY + (endY - startY) * localP;

          // Swirl / Vortex effect
          final orbitX =
              math.sin(localP * math.pi * 5 + index) * (20 + localP * 60);
          final orbitY =
              math.cos(localP * math.pi * 5 + index) * (10 + localP * 30);

          curX += orbitX;
          curY += orbitY;

          // Visuals
          final asset = leafAssets[rand.nextInt(leafAssets.length)];
          final rotation = localP * math.pi * 8 + (index * 0.5);
          final opacity = p < 0.1
              ? p / 0.1
              : (p > 0.85 ? (1.0 - p) / 0.15 : 1.0);
          final scale = 0.5 + rand.nextDouble() * 0.7;

          return Positioned(
            left: curX - 15,
            top: curY - 15,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    asset,
                    width: 30,
                    height: 30,
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
// MOVE ANIMATION SYSTEM (Refactored from battle_screen.dart)
// ----------------------------------------------------------------

class MoveAnimData {
  final int id;
  final Move move;
  final bool isPlayerAttacking;

  MoveAnimData({
    required this.id,
    required this.move,
    required this.isPlayerAttacking,
  });
}

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
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..forward();
    _progress = _controller;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final move = widget.data.move;
    final isPlayer = widget.data.isPlayerAttacking;
    final attackerLink = isPlayer ? widget.playerLink : widget.opponentLink;
    final targetLink = isPlayer ? widget.opponentLink : widget.playerLink;

    final moveName = move.name.toLowerCase();

    if (moveName == 'earth power') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: _EarthPowerEffect(
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (moveName == 'earthquake') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: _EarthquakeEffect(
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (moveName == 'fissure') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: _FissureEffect(
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

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

      final imagePath = isFire
          ? 'assets/move_effects/flame.png'
          : isSludge
          ? 'assets/move_effects/sludge.png'
          : move.name.toLowerCase() == 'dark pulse'
          ? 'assets/move_effects/dark_pulse.png'
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

    if (move.animationType == 'leaf_storm') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: LeafStormEffect(
              progress: _progress.value,
              isPlayer: isPlayer,
            ),
          );
        },
      );
    }

    if (move.animationType == 'giga impact' ||
        move.name.toLowerCase() == 'giga impact') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: GigaImpactEffect(
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
    if (move.animationType == 'thunder' ||
        move.name.toLowerCase() == 'thunder') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: ThunderEffect(progress: _progress.value, showClouds: true),
          );
        },
      );
    }
    if (move.animationType == 'thunderbolt' ||
        move.name.toLowerCase() == 'thunderbolt') {
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: ThunderEffect(progress: _progress.value, showClouds: false),
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
      List<String> imageOptions = [];
      if (move.name.toLowerCase() == 'close combat') {
        imageOptions = [
          'assets/move_effects/kick.png',
          'assets/move_effects/punch.png',
        ];
      } else if (move.name.toLowerCase() == 'thrash') {
        imageOptions = [
          'assets/move_effects/punch.png',
          'assets/move_effects/normal_impact.png',
        ];
      } else if (move.name.toLowerCase() == 'outrage') {
        imageOptions = [
          'assets/move_effects/flame.png',
          'assets/move_effects/drake_impact.png',
        ];
      } else if (move.name.toLowerCase() == 'petal dance') {
        imageOptions = [
          'assets/move_effects/flower.png',
          'assets/move_effects/grass_impact.png',
        ];
      } else if (move.name.toLowerCase() == 'acrobatics') {
        imageOptions = [
          'assets/move_effects/flying_impact.png',
          'assets/move_effects/normal_impact.png',
        ];
      } else {
        imageOptions = ['assets/move_effects/ice.png'];
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
              imagePaths: imageOptions,
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

    // ----------------------------------------------------------------
    // DEFAULT TYPE-BASED IMAGE ANIMATIONS
    // To replace an image: just change the path string in the maps below.
    // ----------------------------------------------------------------

    // Physical move images per type (impact at target)
    const physicalImages = <ElementalType, String>{
      ElementalType.basic: 'assets/move_effects/normal_impact.png',
      ElementalType.flying: 'assets/move_effects/flying_impact.png',
      ElementalType.aquatic: 'assets/move_effects/water_impact.png',
      ElementalType.earth: 'assets/move_effects/rock_impact.png',
      ElementalType.cryo: 'assets/move_effects/ice.png',
      ElementalType.toxic: 'assets/move_effects/poison_impact.png',
      ElementalType.rock: 'assets/move_effects/rock_impact.png',
      ElementalType.arthropod: 'assets/move_effects/grass_impact.png',
      ElementalType.electric: 'assets/move_effects/electric_impact.png',
      ElementalType.darkness: 'assets/move_effects/dark_pulse.png',
      ElementalType.martial: 'assets/move_effects/normal_impact.png',
      ElementalType.blaze: 'assets/move_effects/flame.png',
      ElementalType.grass: 'assets/move_effects/grass_impact.png',
      ElementalType.mystic: 'assets/move_effects/moonblast.png',
      ElementalType.spectral: 'assets/move_effects/shadow_ball.png',
      ElementalType.drake: 'assets/move_effects/drake_impact.png',
      ElementalType.metal: 'assets/move_effects/normal_impact.png',
      ElementalType.aura: 'assets/move_effects/aura_sphere.png',
      ElementalType.sound: 'assets/move_effects/normal_impact.png',
      ElementalType.holy: 'assets/move_effects/moonblast.png',
    };

    // Special move images per type (projectile from attacker to target)
    const specialImages = <ElementalType, String>{
      ElementalType.basic: 'assets/move_effects/yellowball.png',
      ElementalType.flying: 'assets/move_effects/air_slash.png',
      ElementalType.aquatic: 'assets/move_effects/aqua.png',
      ElementalType.earth: 'assets/move_effects/rock.png',
      ElementalType.cryo: 'assets/move_effects/ice.png',
      ElementalType.toxic: 'assets/move_effects/sludge.png',
      ElementalType.rock: 'assets/move_effects/rock.png',
      ElementalType.arthropod: 'assets/move_effects/greenball.png',
      ElementalType.electric: 'assets/move_effects/electric_ball.png',
      ElementalType.darkness: 'assets/move_effects/dark_pulse.png',
      ElementalType.martial: 'assets/move_effects/focus_blast.png',
      ElementalType.blaze: 'assets/move_effects/flame.png',
      ElementalType.grass: 'assets/move_effects/energy_ball.png',
      ElementalType.mystic: 'assets/move_effects/moonblast.png',
      ElementalType.spectral: 'assets/move_effects/shadow_ball.png',
      ElementalType.drake: 'assets/move_effects/drake_impact.png',
      ElementalType.metal: 'assets/move_effects/yellowball.png',
      ElementalType.aura: 'assets/move_effects/aura_sphere.png',
      ElementalType.sound: 'assets/move_effects/blueball.png',
      ElementalType.holy: 'assets/move_effects/yellowball.png',
    };

    // Status move images per type (pulse at self)
    const statusImages = <ElementalType, String>{
      ElementalType.basic: 'assets/move_effects/normal_impact.png',
      ElementalType.flying: 'assets/move_effects/flying_impact.png',
      ElementalType.aquatic: 'assets/move_effects/water_impact.png',
      ElementalType.earth: 'assets/move_effects/rock_impact.png',
      ElementalType.cryo: 'assets/move_effects/ice.png',
      ElementalType.toxic: 'assets/move_effects/poison_impact.png',
      ElementalType.rock: 'assets/move_effects/rock_impact.png',
      ElementalType.arthropod: 'assets/move_effects/grass_impact.png',
      ElementalType.electric: 'assets/move_effects/electric_impact.png',
      ElementalType.darkness: 'assets/move_effects/dark_pulse.png',
      ElementalType.martial: 'assets/move_effects/normal_impact.png',
      ElementalType.blaze: 'assets/move_effects/flame.png',
      ElementalType.grass: 'assets/move_effects/grass_impact.png',
      ElementalType.mystic: 'assets/move_effects/moonblast.png',
      ElementalType.spectral: 'assets/move_effects/shadow_ball.png',
      ElementalType.drake: 'assets/move_effects/drake_impact.png',
      ElementalType.metal: 'assets/move_effects/normal_impact.png',
      ElementalType.aura: 'assets/move_effects/aura_sphere.png',
      ElementalType.sound: 'assets/move_effects/normal_impact.png',
      ElementalType.holy: 'assets/move_effects/moonblast.png',
    };

    final defaultFallbackImage = 'assets/move_effects/normal_impact.png';

    if (move.category == MoveCategory.physical) {
      final img = physicalImages[move.type] ?? defaultFallbackImage;
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: _DefaultPhysicalEffect(
              imagePath: img,
              progress: _progress.value,
              isPlayer: isPlayer,
              type: move.type,
            ),
          );
        },
      );
    }

    if (move.category == MoveCategory.special) {
      final img = specialImages[move.type] ?? defaultFallbackImage;
      return AnimatedBuilder(
        animation: _progress,
        builder: (context, _) {
          return CompositedTransformFollower(
            link: targetLink,
            showWhenUnlinked: false,
            followerAnchor: Alignment.center,
            targetAnchor: Alignment.center,
            child: _DefaultSpecialEffect(
              imagePath: img,
              progress: _progress.value,
              isPlayer: isPlayer,
              type: move.type,
            ),
          );
        },
      );
    }

    // Status moves pulse at the attacker
    final img = statusImages[move.type] ?? defaultFallbackImage;
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, _) {
        return CompositedTransformFollower(
          link: attackerLink,
          showWhenUnlinked: false,
          followerAnchor: Alignment.center,
          targetAnchor: Alignment.center,
          child: _DefaultStatusEffect(
            imagePath: img,
            progress: _progress.value,
            type: move.type,
          ),
        );
      },
    );
  }
}

// ----------------------------------------------------------------
// Default Physical Effect — type-specific impact at the target
// ----------------------------------------------------------------
class _DefaultPhysicalEffect extends StatelessWidget {
  final String imagePath;
  final double progress;
  final bool isPlayer;
  final ElementalType type;

  const _DefaultPhysicalEffect({
    required this.imagePath,
    required this.progress,
    required this.isPlayer,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    const size = 200.0;
    final p = progress.clamp(0.0, 1.0);
    switch (type) {
      case ElementalType.basic:
      case ElementalType.martial:
      case ElementalType.metal:
        return _slamImpact(size, p);
      case ElementalType.aquatic:
      case ElementalType.toxic:
      case ElementalType.cryo:
        return _scatterBurst(size, p);
      case ElementalType.darkness:
      case ElementalType.flying:
      case ElementalType.drake:
      case ElementalType.arthropod:
        return _slashMarks(size, p);
      case ElementalType.earth:
      case ElementalType.rock:
        return _groundEruption(size, p);
      case ElementalType.electric:
      case ElementalType.sound:
      case ElementalType.aura:
        return _multiStrike(size, p);
      case ElementalType.blaze:
      case ElementalType.grass:
      case ElementalType.mystic:
      case ElementalType.spectral:
      case ElementalType.holy:
        return _burstRing(size, p);
    }
  }

  // Elastic bounce slam with shockwave ring
  Widget _slamImpact(double size, double p) {
    final scale = Curves.elasticOut.transform((p / 0.3).clamp(0.0, 1.0));
    final opacity = p < 0.35
        ? 1.0
        : (1.0 - ((p - 0.35) / 0.65)).clamp(0.0, 1.0);
    final shakeX = p < 0.4
        ? math.sin(p * math.pi * 20) * 6 * (1.0 - p * 2.5)
        : 0.0;
    final shakeY = p < 0.4
        ? math.cos(p * math.pi * 16) * 4 * (1.0 - p * 2.5)
        : 0.0;
    final ringP = ((p - 0.15) / 0.5).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (ringP > 0)
            Opacity(
              opacity: ((1.0 - ringP) * 0.5).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.3 + ringP * 1.5,
                child: Container(
                  width: size * 0.7,
                  height: size * 0.7,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: type.color.withValues(alpha: 0.6),
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(shakeX, shakeY),
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Image.asset(
                  imagePath,
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Center flash + particles scatter radially outward
  Widget _scatterBurst(double size, double p) {
    final flashOp = p < 0.25
        ? 1.0
        : (1.0 - ((p - 0.25) / 0.25)).clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (p < 0.5)
            Opacity(
              opacity: flashOp,
              child: Transform.scale(
                scale: 0.5 + (p / 0.25).clamp(0.0, 1.0) * 0.5,
                child: Image.asset(
                  imagePath,
                  width: size * 0.5,
                  height: size * 0.5,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ...List.generate(8, (i) {
            final sp = ((p - 0.1) / 0.9).clamp(0.0, 1.0);
            if (sp <= 0) return const SizedBox.shrink();
            final angle = (i / 8) * math.pi * 2 + 0.3;
            final dist = sp * size * 0.5;
            return Positioned(
              left: size / 2 + math.cos(angle) * dist - 20,
              top: size / 2 + math.sin(angle) * dist - 20,
              child: Opacity(
                opacity: (1.0 - sp).clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: sp * math.pi * 2,
                  child: Transform.scale(
                    scale: 0.3 + sp * 0.3,
                    child: Image.asset(
                      imagePath,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // Sequential diagonal energy slash marks
  Widget _slashMarks(double size, double p) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(3, (i) {
          final sp = ((p - i * 0.2) / 0.4).clamp(0.0, 1.0);
          if (sp <= 0 || sp >= 1.0) return const SizedBox.shrink();
          final angle = -math.pi / 4 + (i - 1) * (math.pi / 5);
          final slideIn = Curves.easeOut.transform((sp * 2).clamp(0.0, 1.0));
          final fadeOut = sp > 0.5
              ? (1.0 - (sp - 0.5) * 2).clamp(0.0, 1.0)
              : 1.0;
          return Positioned(
            left:
                size / 2 +
                (1.0 - slideIn) * 40 * math.cos(angle) -
                50 +
                (i - 1) * 15,
            top:
                size / 2 +
                (1.0 - slideIn) * 40 * math.sin(angle) -
                50 +
                (i - 1) * 10,
            child: Opacity(
              opacity: fadeOut,
              child: Transform.rotate(
                angle: angle,
                child: Transform.scale(
                  scaleX: 0.5 + slideIn * 0.8,
                  child: Image.asset(
                    imagePath,
                    width: 100,
                    height: 100,
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

  // Particles erupt upward from below
  Widget _groundEruption(double size, double p) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(6, (i) {
          final sp = ((p - i * 0.1) / 0.6).clamp(0.0, 1.0);
          if (sp <= 0 || sp >= 1.0) return const SizedBox.shrink();
          final rand = math.Random(i);
          final dx = (rand.nextDouble() - 0.5) * size * 0.7;
          final dy = size * 0.4 - sp * size * 0.9;
          return Positioned(
            left: size / 2 + dx - 25,
            top: size / 2 + dy - 25,
            child: Opacity(
              opacity: (sp > 0.7 ? (1.0 - sp) / 0.3 : 1.0).clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: sp * math.pi * 3,
                child: Transform.scale(
                  scale: 0.4 + rand.nextDouble() * 0.5,
                  child: Image.asset(
                    imagePath,
                    width: 50,
                    height: 50,
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

  // Rapid staggered hits at random offsets
  Widget _multiStrike(double size, double p) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: List.generate(5, (i) {
          final sp = ((p - i * 0.15) / 0.25).clamp(0.0, 1.0);
          if (sp <= 0 || sp >= 1.0) return const SizedBox.shrink();
          final rand = math.Random(i * 7);
          final dx = (rand.nextDouble() - 0.5) * 60;
          final dy = (rand.nextDouble() - 0.5) * 60;
          final scale = Curves.easeOut.transform((sp / 0.3).clamp(0.0, 1.0));
          final opacity = sp > 0.5 ? (1.0 - sp) / 0.5 : 1.0;
          return Positioned(
            left: size / 2 + dx - 40,
            top: size / 2 + dy - 40,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: scale * 0.8,
                child: Image.asset(
                  imagePath,
                  width: 80,
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // Expanding ring of orbiting particles with center flash
  Widget _burstRing(double size, double p) {
    final ringR = p * size * 0.5;
    final fade =
        (p < 0.2 ? p / 0.2 : 1.0) * (p > 0.6 ? (1.0 - (p - 0.6) / 0.4) : 1.0);
    final flashOp = p < 0.3 ? (1.0 - p / 0.3) : 0.0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (flashOp > 0)
            Opacity(
              opacity: flashOp.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.5 + p * 2,
                child: Image.asset(
                  imagePath,
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ...List.generate(10, (i) {
            final angle = (i / 10) * math.pi * 2 + p * math.pi;
            return Positioned(
              left: size / 2 + math.cos(angle) * ringR - 20,
              top: size / 2 + math.sin(angle) * ringR - 20,
              child: Opacity(
                opacity: fade.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: angle + p * math.pi * 4,
                  child: Transform.scale(
                    scale: 0.3 + math.sin(p * math.pi) * 0.4,
                    child: Image.asset(
                      imagePath,
                      width: 40,
                      height: 40,
                      fit: BoxFit.contain,
                    ),
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
// Default Special Effect — type-specific projectile toward target
// ----------------------------------------------------------------
class _DefaultSpecialEffect extends StatelessWidget {
  final String imagePath;
  final double progress;
  final bool isPlayer;
  final ElementalType type;

  const _DefaultSpecialEffect({
    required this.imagePath,
    required this.progress,
    required this.isPlayer,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);

    // Attacker position relative to target center (0,0)
    final baseX = isPlayer ? -210.0 : 210.0;
    final baseY = isPlayer ? 150.0 : -150.0;

    // Current linear trajectory point
    final tX = baseX * (1.0 - p);
    final tY = baseY * (1.0 - p);
    final dir = isPlayer ? 1 : -1;

    switch (type) {
      case ElementalType.basic:
      case ElementalType.martial:
      case ElementalType.metal:
        return _straightShot(p, tX, tY, dir);
      case ElementalType.aquatic:
      case ElementalType.sound:
        return _wavePath(p, tX, tY, dir);
      case ElementalType.earth:
      case ElementalType.toxic:
      case ElementalType.rock:
        return _lobArc(p, tX, tY, dir);
      case ElementalType.cryo:
      case ElementalType.mystic:
      case ElementalType.holy:
        return _spiralPath(p, tX, tY, dir);
      case ElementalType.electric:
      case ElementalType.aura:
        return _zigzagBolt(p, tX, tY, dir);
      case ElementalType.arthropod:
      case ElementalType.grass:
        return _swarmShot(p, tX, tY, dir);
      case ElementalType.blaze:
      case ElementalType.drake:
        return _blazeTrail(p, tX, tY, dir);
      case ElementalType.darkness:
      case ElementalType.spectral:
      case ElementalType.flying:
        return _phaseShot(p, tX, tY, dir);
    }
  }

  Widget _proj(double x, double y, double opacity, double scale, double rot) {
    return Positioned(
      left: x - 60,
      top: y - 60,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: rot,
          child: Transform.scale(
            scale: scale,
            child: Image.asset(
              imagePath,
              width: 120,
              height: 120,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  double _fadeEnds(double p) =>
      (p < 0.1 ? p / 0.1 : (p > 0.8 ? (1.0 - p) / 0.2 : 1.0));

  // Fast linear with echo trail
  Widget _straightShot(double p, double tX, double tY, int dir) {
    final arcY = math.sin(p * math.pi * 4) * 15;
    final rot = p * math.pi * 6 * dir;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (p > 0.05)
          _proj(tX + dir * 40, tY + arcY + 5, _fadeEnds(p) * 0.3, 0.6, rot * 0.8),
        if (p > 0.1)
          _proj(tX + dir * 80, tY + arcY + 10, _fadeEnds(p) * 0.15, 0.4, rot * 0.6),
        _proj(tX, tY + arcY, _fadeEnds(p), 0.7 + math.sin(p * math.pi) * 0.3, rot),
        if (p < 0.2)
          Positioned(
            left: (isPlayer ? -210.0 : 210.0) - 75,
            top: (isPlayer ? 150.0 : -150.0) - 75,
            child: Opacity(
              opacity: (1.0 - p / 0.2).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.5 + (p / 0.2) * 2.5,
                child: Image.asset(
                  imagePath,
                  width: 150,
                  height: 150,
                  color: Colors.white.withValues(alpha: 0.8),
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Sinusoidal wavy trajectory
  Widget _wavePath(double p, double tX, double tY, int dir) {
    final waveY = math.sin(p * math.pi * 6) * 30;
    final rot = p * math.pi * 3 * dir;

    final baseX = isPlayer ? -210.0 : 210.0;
    final baseY = isPlayer ? 150.0 : -150.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (int i = 1; i <= 2; i++)
          _proj(
            (baseX * (1.0 - (p - i * 0.06).clamp(0.0, 1.0))),
            (baseY * (1.0 - (p - i * 0.06).clamp(0.0, 1.0))) + math.sin((p - i * 0.06).clamp(0.0, 1.0) * math.pi * 6) * 30,
            _fadeEnds(p) * (0.4 - i * 0.1),
            0.5,
            rot * 0.7,
          ),
        _proj(tX, tY + waveY, _fadeEnds(p), 0.8 + math.sin(p * math.pi) * 0.2, rot),
      ],
    );
  }

  // Parabolic arc (lobbing)
  Widget _lobArc(double p, double tX, double tY, int dir) {
    final arcY = -math.sin(p * math.pi) * 120; // Arc upward
    final rot = p * math.pi * 2 * dir;
    final scale = 0.5 + math.sin(p * math.pi) * 0.5;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Shadow on ground
        Positioned(
          left: tX - 30,
          top: tY + 30,
          child: Opacity(
            opacity: _fadeEnds(p) * 0.3,
            child: Transform.scale(
              scaleY: 0.3,
              scaleX: scale,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ),
        _proj(tX, tY + arcY, _fadeEnds(p), scale, rot),
      ],
    );
  }

  // Helical spiral path
  Widget _spiralPath(double p, double tX, double tY, int dir) {
    final spiralR = 25.0 * (1.0 - p * 0.5);
    final spiralY = math.sin(p * math.pi * 8) * spiralR;
    final spiralX2 = math.cos(p * math.pi * 8) * spiralR * 0.5;

    final baseX = isPlayer ? -210.0 : 210.0;
    final baseY = isPlayer ? 150.0 : -150.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Ghost trails
        for (int i = 1; i <= 3; i++)
          _proj(
            (baseX * (1.0 - (p - i * 0.04).clamp(0.0, 1.0))) +
                dir * i * 15 +
                math.cos((p - i * 0.04) * math.pi * 8) * spiralR * 0.5,
            (baseY * (1.0 - (p - i * 0.04).clamp(0.0, 1.0))) +
                math.sin((p - i * 0.04) * math.pi * 8) * spiralR,
            _fadeEnds(p) * (0.3 - i * 0.08),
            0.5 - i * 0.1,
            p * math.pi * 4,
          ),
        _proj(
          tX + spiralX2,
          tY + spiralY,
          _fadeEnds(p),
          0.7 + math.sin(p * math.pi) * 0.3,
          p * math.pi * 4 * dir,
        ),
      ],
    );
  }

  // Lightning zigzag path
  Widget _zigzagBolt(double p, double tX, double tY, int dir) {
    // Create 4 zigzag segments
    final segCount = 4;
    final segP = p * segCount;
    final currentSeg = segP.floor().clamp(0, segCount - 1);
    final segFrac = segP - currentSeg;

    final baseX = isPlayer ? -210.0 : 210.0;
    final baseY = isPlayer ? 150.0 : -150.0;

    // Zigzag positions
    final zigY = (currentSeg.isEven ? -1 : 1) * segFrac * 40;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Afterimage flashes at each zig point
        for (int i = 0; i < currentSeg; i++) ...[
          Positioned(
            left: (baseX * (1.0 - (i / segCount))) - 30,
            top: (baseY * (1.0 - (i / segCount))) + (i.isEven ? -40 : 40) - 30,
            child: Opacity(
              opacity: (0.4 * (1.0 - p)).clamp(0.0, 1.0),
              child: Image.asset(
                imagePath,
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                color: type.color.withValues(alpha: 0.5),
                colorBlendMode: BlendMode.modulate,
              ),
            ),
          ),
        ],
        _proj(tX, tY + zigY, _fadeEnds(p), 0.8, p * math.pi * 10 * dir),
      ],
    );
  }

  // Cloud of small swarming particles
  Widget _swarmShot(double p, double tX, double tY, int dir) {
    final baseX = isPlayer ? -210.0 : 210.0;
    final baseY = isPlayer ? 150.0 : -150.0;

    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(7, (i) {
        final rand = math.Random(i * 13);
        final lp = (p - (i * 0.03)).clamp(0.0, 1.0);
        if (lp <= 0) return const SizedBox.shrink();

        final curTX = baseX * (1.0 - lp);
        final curTY = baseY * (1.0 - lp);

        final offX = math.sin(lp * math.pi * 6 + i * 1.2) * 20;
        final offY = math.cos(lp * math.pi * 5 + i * 0.8) * 20;

        return _proj(
          curTX + offX,
          curTY + offY,
          _fadeEnds(lp) * (0.5 + rand.nextDouble() * 0.5),
          0.3 + rand.nextDouble() * 0.3,
          lp * math.pi * 4,
        );
      }),
    );
  }

  // Straight shot with growing smoke/fire trail
  Widget _blazeTrail(double p, double tX, double tY, int dir) {
    final baseX = isPlayer ? -210.0 : 210.0;
    final baseY = isPlayer ? 150.0 : -150.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Trail particles behind the main projectile
        ...List.generate(5, (i) {
          final trailP = (p - i * 0.04).clamp(0.0, 1.0);
          if (trailP <= 0) return const SizedBox.shrink();
          final curTX = baseX * (1.0 - trailP);
          final curTY = baseY * (1.0 - trailP);
          return Positioned(
            left: curTX - 30,
            top: curTY + math.sin(trailP * 30 + i) * 8 - 30,
            child: Opacity(
              opacity: (0.6 - i * 0.1).clamp(0.0, 1.0) * _fadeEnds(p),
              child: Transform.scale(
                scale: 0.3 + i * 0.08,
                child: Image.asset(
                  imagePath,
                  width: 60,
                  height: 60,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        }),
        _proj(
          tX,
          tY + math.sin(p * 20) * 3,
          _fadeEnds(p),
          0.9,
          p * math.pi * 2 * dir,
        ),
      ],
    );
  }

  // Blinks in and out (phasing teleport)
  Widget _phaseShot(double p, double tX, double tY, int dir) {
    // The projectile appears and disappears as it travels
    final phaseVisible = math.sin(p * math.pi * 8) > -0.2;
    final flickerOp = phaseVisible ? _fadeEnds(p) : 0.0;
    final scale = 0.6 + math.sin(p * math.pi * 3) * 0.3;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Afterglow at each phase-in point
        if (p > 0.15 && p < 0.85)
          Positioned(
            left: tX - 40 + dir * 20,
            top: tY - 40,
            child: Opacity(
              opacity: ((1.0 - flickerOp) * 0.3).clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 1.2,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: type.color.withValues(alpha: 0.15),
                  ),
                ),
              ),
            ),
          ),
        _proj(tX, tY, flickerOp, scale, p * math.pi * 4 * dir),
      ],
    );
  }
}

// ----------------------------------------------------------------
// Default Status Effect — type-specific pulsing aura at the caster
// ----------------------------------------------------------------
class _DefaultStatusEffect extends StatelessWidget {
  final String imagePath;
  final double progress;
  final ElementalType type;

  const _DefaultStatusEffect({
    required this.imagePath,
    required this.progress,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    switch (type) {
      case ElementalType.basic:
      case ElementalType.blaze:
      case ElementalType.spectral:
        return _risingSpiral(p);
      case ElementalType.aquatic:
      case ElementalType.sound:
      case ElementalType.aura:
        return _ripplePulse(p);
      case ElementalType.rock:
      case ElementalType.earth:
      case ElementalType.metal:
        return _orbitFragments(p);
      case ElementalType.grass:
      case ElementalType.cryo:
      case ElementalType.mystic:
      case ElementalType.holy:
        return _shimmerRain(p);
      case ElementalType.electric:
      case ElementalType.arthropod:
        return _sparkFlash(p);
      case ElementalType.toxic:
      case ElementalType.darkness:
        return _smokeRise(p);
      case ElementalType.martial:
      case ElementalType.drake:
      case ElementalType.flying:
        return _powerFocus(p);
    }
  }

  // Particles spiral upward with rotation
  Widget _risingSpiral(double p) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(6, (i) {
        final sp = (p * 1.2 - i * 0.1).clamp(0.0, 1.0);
        if (sp <= 0 || sp >= 1.0) return const SizedBox.shrink();
        final angle = (i / 6) * math.pi * 2 + sp * math.pi * 2;
        final radius = 20.0 + sp * 50.0;
        final x = math.cos(angle) * radius;
        final y = math.sin(angle) * radius * 0.5 - sp * 80.0;
        final opacity = math.sin(sp * math.pi).clamp(0.0, 1.0);
        final scale =
            (0.4 + math.sin(sp * math.pi) * 0.6) * (0.8 + (i % 3) * 0.2);
        return Positioned(
          left: x - 40,
          top: y - 40,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: sp * math.pi * 2 * (i.isEven ? 1 : -1),
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
        );
      }),
    );
  }

  // Expanding concentric ring waves
  Widget _ripplePulse(double p) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ...List.generate(3, (i) {
          final rp = (p * 1.5 - i * 0.25).clamp(0.0, 1.0);
          if (rp <= 0 || rp >= 1.0) return const SizedBox.shrink();
          final ringSize = 40.0 + rp * 120;
          final opacity = (1.0 - rp) * 0.6;
          return Positioned(
            left: -ringSize / 2,
            top: -ringSize / 2,
            child: Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Container(
                width: ringSize,
                height: ringSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: type.color.withValues(alpha: 0.7),
                    width: 2.5,
                  ),
                ),
              ),
            ),
          );
        }),
        // Center image pulsing
        Opacity(
          opacity: math.sin(p * math.pi).clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.5 + math.sin(p * math.pi) * 0.3,
            child: Image.asset(
              imagePath,
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }

  // Fragments orbit in a horizontal ring
  Widget _orbitFragments(double p) {
    final fade = (p < 0.15 ? p / 0.15 : (p > 0.85 ? (1.0 - p) / 0.15 : 1.0));
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(5, (i) {
        final angle = (i / 5) * math.pi * 2 + p * math.pi * 4;
        final radius = 50.0 + math.sin(p * math.pi * 2) * 10;
        final x = math.cos(angle) * radius;
        final y = math.sin(angle) * radius * 0.35; // Flattened for perspective
        final behind = math.sin(angle) < 0;
        final scale = behind ? 0.3 : 0.5;
        return Positioned(
          left: x - 25,
          top: y - 25,
          child: Opacity(
            opacity: (fade * (behind ? 0.5 : 1.0)).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Transform.rotate(
                angle: p * math.pi * 6,
                child: Image.asset(
                  imagePath,
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // Particles gently drift downward like rain/snow
  Widget _shimmerRain(double p) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(8, (i) {
        final rand = math.Random(i * 11);
        final delay = i * 0.08;
        final sp = (p * 1.5 - delay).clamp(0.0, 1.0);
        if (sp <= 0 || sp >= 1.0) return const SizedBox.shrink();
        final x = (rand.nextDouble() - 0.5) * 120;
        final startY = -60.0;
        final y = startY + sp * 140;
        final drift = math.sin(sp * math.pi * 3 + i) * 15;
        final opacity = math.sin(sp * math.pi).clamp(0.0, 1.0);
        final scale = 0.2 + rand.nextDouble() * 0.3;
        return Positioned(
          left: x + drift - 20,
          top: y - 20,
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: sp * math.pi * 2 * (i.isEven ? 1 : -1),
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
          ),
        );
      }),
    );
  }

  // Random sparks flashing at random positions
  Widget _sparkFlash(double p) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(8, (i) {
        final rand = math.Random(i * 31);
        // Each spark has a very short lifetime at a random moment
        final sparkCenter = rand.nextDouble() * 0.8 + 0.1;
        final sparkDist = (p - sparkCenter).abs();
        if (sparkDist > 0.08) return const SizedBox.shrink();
        final sparkP = 1.0 - sparkDist / 0.08;
        final x = (rand.nextDouble() - 0.5) * 100;
        final y = (rand.nextDouble() - 0.5) * 100;
        return Positioned(
          left: x - 25,
          top: y - 25,
          child: Opacity(
            opacity: sparkP.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.3 + sparkP * 0.4,
              child: Image.asset(
                imagePath,
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      }),
    );
  }

  // Wisps of colored smoke floating upward
  Widget _smokeRise(double p) {
    return Stack(
      clipBehavior: Clip.none,
      children: List.generate(5, (i) {
        final delay = i * 0.12;
        final sp = (p * 1.4 - delay).clamp(0.0, 1.0);
        if (sp <= 0 || sp >= 1.0) return const SizedBox.shrink();
        final rand = math.Random(i * 17);
        final x = (rand.nextDouble() - 0.5) * 60;
        final y = -sp * 100;
        final drift = math.sin(sp * math.pi * 2 + i) * 25;
        final opacity = math.sin(sp * math.pi) * 0.7;
        final scale = 0.3 + sp * 0.6;
        return Positioned(
          left: x + drift - 30,
          top: y - 30,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: scale,
              child: Image.asset(
                imagePath,
                width: 60,
                height: 60,
                fit: BoxFit.contain,
                color: type.color.withValues(alpha: 0.6),
                colorBlendMode: BlendMode.modulate,
              ),
            ),
          ),
        );
      }),
    );
  }

  // Converging energy lines toward center then burst outward
  Widget _powerFocus(double p) {
    final isConverging = p < 0.5;
    final phase = isConverging ? p / 0.5 : (p - 0.5) / 0.5;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ...List.generate(6, (i) {
          final angle = (i / 6) * math.pi * 2;
          double radius;
          if (isConverging) {
            radius = 80.0 * (1.0 - Curves.easeIn.transform(phase));
          } else {
            radius = Curves.easeOut.transform(phase) * 100.0;
          }
          final x = math.cos(angle) * radius;
          final y = math.sin(angle) * radius;
          final opacity = isConverging
              ? phase.clamp(0.0, 1.0)
              : (1.0 - phase).clamp(0.0, 1.0);
          final scale = isConverging ? 0.3 + phase * 0.3 : 0.6 - phase * 0.3;
          return Positioned(
            left: x - 30,
            top: y - 30,
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: angle + p * math.pi * 4,
                child: Transform.scale(
                  scale: scale,
                  child: Image.asset(
                    imagePath,
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          );
        }),
        // Center flash at convergence point
        if (p > 0.4 && p < 0.6)
          Opacity(
            opacity: (1.0 - ((p - 0.5).abs() / 0.1)).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.8,
              child: Image.asset(
                imagePath,
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
            ),
          ),
      ],
    );
  }
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

// ----------------------------------------------------------------
// Ground Move Effects (Earth Power, Earthquake, Fissure)
// ----------------------------------------------------------------

class _ShakeEffect extends StatelessWidget {
  final Widget child;
  final double progress;
  final double intensity;

  const _ShakeEffect({
    required this.child,
    required this.progress,
    this.intensity = 10.0,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0 || progress >= 1.0) {
      return child;
    }
    // Shake logic using sine waves
    final shakeX = math.sin(progress * 100) * intensity * (1 - progress);
    final shakeY = math.cos(progress * 80) * (intensity * 0.8) * (1 - progress);
    return Transform.translate(
      offset: Offset(shakeX, shakeY),
      child: child,
    );
  }
}

class _EarthPowerEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const _EarthPowerEffect({required this.progress, required this.isPlayer});

  @override
  Widget build(BuildContext context) {
    const size = 250.0;
    final p = progress.clamp(0.0, 1.0);

    // 0.0 - 0.3: power_1
    // 0.3 - 0.6: power_2
    // 0.6 - 1.0: power_3
    String asset = 'assets/move_effects/earth_power_1.png';
    double opacity = 1.0;
    double scale = 1.0;

    if (p < 0.3) {
      asset = 'assets/move_effects/earth_power_1.png';
      opacity = p / 0.3;
      scale = 0.8 + p * 0.2;
    } else if (p < 0.6) {
      asset = 'assets/move_effects/earth_power_2.png';
      opacity = 1.0;
      scale = 1.0 + (p - 0.3) * 0.5;
    } else {
      asset = 'assets/move_effects/earth_power_3.png';
      opacity = (1.0 - p) / 0.4;
      scale = 1.15 + (p - 0.6) * 0.25;
    }

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: scale,
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}

class _EarthquakeEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const _EarthquakeEffect({required this.progress, required this.isPlayer});

  @override
  Widget build(BuildContext context) {
    const size = 300.0;
    final p = progress.clamp(0.0, 1.0);

    // Fade in cracks, then heavy pulse
    final crackOpacity = p < 0.2 ? p / 0.2 : (p > 0.8 ? (1.0 - p) / 0.2 : 1.0);
    final crackScale = 0.9 + math.sin(p * math.pi * 4) * 0.1;

    return _ShakeEffect(
      progress: p,
      intensity: 15.0,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: crackOpacity.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: crackScale,
                child: Image.asset(
                  'assets/move_effects/earth_crack.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            // Floating debris
            ...List.generate(5, (index) {
              final rand = math.Random(index);
              final dp = (p * 1.5 - (index * 0.1)).clamp(0.0, 1.0);
              if (dp <= 0 || dp >= 1.0) return const SizedBox.shrink();

              final dx = (rand.nextDouble() - 0.5) * 150;
              final dy = -dp * 100 + rand.nextDouble() * 20;

              return Positioned(
                left: 150 + dx,
                top: 150 + dy,
                child: Opacity(
                  opacity: (1.0 - dp),
                  child: Transform.rotate(
                    angle: dp * math.pi,
                    child: Image.asset(
                      'assets/move_effects/rock.png',
                      width: 20 + rand.nextDouble() * 20,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _FissureEffect extends StatelessWidget {
  final double progress;
  final bool isPlayer;

  const _FissureEffect({required this.progress, required this.isPlayer});

  @override
  Widget build(BuildContext context) {
    const size = 350.0;
    final p = progress.clamp(0.0, 1.0);

    // Fissure opens up and swallows
    final fissureOpacity = p < 0.1 ? p / 0.1 : (p > 0.9 ? (1.0 - p) / 0.1 : 1.0);
    // Expand horizontally to "open"
    final openScaleX = p < 0.5 ? 0.2 + p * 1.6 : 1.0;
    final openScaleY = 1.0 + math.sin(p * math.pi * 8) * 0.05;

    return _ShakeEffect(
      progress: p,
      intensity: 25.0,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Opacity(
            opacity: fissureOpacity.clamp(0.0, 1.0),
            child: Transform(
              transform: Matrix4.identity()
                ..scale(openScaleX, openScaleY),
              alignment: Alignment.center,
              child: Image.asset(
                'assets/move_effects/fissure.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
