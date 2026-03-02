import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/terrain.dart';

class TailwindOverlay extends StatefulWidget {
  final bool isActive;
  const TailwindOverlay({super.key, required this.isActive});

  @override
  State<TailwindOverlay> createState() => _TailwindOverlayState();
}

class _TailwindOverlayState extends State<TailwindOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) return const SizedBox.shrink();

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _TailwindPainter(progress: _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _TailwindPainter extends CustomPainter {
  final double progress;
  final List<_WindLine> lines;

  _TailwindPainter({required this.progress})
    : lines = List.generate(
        25,
        (i) => _WindLine(
          x: math.Random(i).nextDouble(),
          y: math.Random(i + 1).nextDouble(),
          length: math.Random(i + 2).nextDouble() * 100 + 50,
          speed: math.Random(i + 3).nextDouble() * 2.5 + 1.5,
        ),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    for (var line in lines) {
      final x =
          ((line.x * size.width + progress * line.speed * size.width) %
              (size.width + 200)) -
          100;
      final y = line.y * size.height;

      canvas.drawLine(
        Offset(x, y),
        Offset(x + line.length, y + math.sin(progress * 5 + x * 0.01) * 10),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TailwindPainter oldDelegate) => true;
}

class _WindLine {
  final double x;
  final double y;
  final double length;
  final double speed;

  _WindLine({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
  });
}

class TerrainOverlay extends StatefulWidget {
  final Terrain terrain;

  const TerrainOverlay({super.key, required this.terrain});

  @override
  State<TerrainOverlay> createState() => _TerrainOverlayState();
}

class _TerrainOverlayState extends State<TerrainOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.terrain == Terrain.none) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _getPainter(widget.terrain, _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  CustomPainter _getPainter(Terrain terrain, double progress) {
    switch (terrain) {
      case Terrain.misty:
        return _MistyTerrainPainter(progress: progress);
      case Terrain.electric:
        return _ElectricTerrainPainter(progress: progress);
      case Terrain.grassy:
        return _GrassyTerrainPainter(progress: progress);
      case Terrain.psychic:
        return _PsychicTerrainPainter(progress: progress);
      default:
        return _EmptyPainter();
    }
  }
}

class _MistyTerrainPainter extends CustomPainter {
  final double progress;
  final List<Offset> points;

  _MistyTerrainPainter({required this.progress})
    : points = List.generate(
        30,
        (i) => Offset(
          math.Random(i).nextDouble(),
          math.Random(i + 50).nextDouble(),
        ),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    // Glowing mist on ground
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      paint,
    );

    // Rising sparkles
    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = p.dx * size.width;
      final y = ((p.dy - progress * 0.3) % 1.0) * size.height;
      final opacity = (1.0 - (y / size.height)).clamp(0.0, 1.0) * 0.4;

      canvas.drawCircle(
        Offset(x, y),
        2 + math.sin(progress * 10 + i) * 1,
        Paint()..color = Colors.white.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MistyTerrainPainter oldDelegate) => true;
}

class _ElectricTerrainPainter extends CustomPainter {
  final double progress;

  _ElectricTerrainPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random((progress * 20).floor());
    if (random.nextDouble() < 0.2) {
      final paint = Paint()
        ..color = Colors.yellowAccent.withValues(alpha: 0.3)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      final startX = random.nextDouble() * size.width;
      final startY =
          size.height * 0.7 + random.nextDouble() * size.height * 0.3;

      final path = Path();
      path.moveTo(startX, startY);
      for (int i = 0; i < 4; i++) {
        path.lineTo(
          startX + (random.nextDouble() - 0.5) * 40,
          startY + (random.nextDouble() - 0.5) * 40,
        );
      }
      canvas.drawPath(path, paint);
    }

    // Electric hum (ground glow)
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.8, size.width, size.height * 0.2),
      Paint()..color = Colors.yellow.withValues(alpha: 0.1),
    );
  }

  @override
  bool shouldRepaint(covariant _ElectricTerrainPainter oldDelegate) => true;
}

class _GrassyTerrainPainter extends CustomPainter {
  final double progress;

  _GrassyTerrainPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3),
      Paint()..color = Colors.green.withValues(alpha: 0.15),
    );

    // Rising leaves
    for (int i = 0; i < 20; i++) {
      final rand = math.Random(i);
      final x =
          (rand.nextDouble() * size.width + math.sin(progress * 2 + i) * 20) %
          size.width;
      final y = ((rand.nextDouble() - progress * 0.2) % 1.0) * size.height;

      if (y > size.height * 0.5) {
        final leafPaint = Paint()..color = Colors.greenAccent.withValues(alpha: 0.3);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: 8, height: 4),
          leafPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GrassyTerrainPainter oldDelegate) => true;
}

class _PsychicTerrainPainter extends CustomPainter {
  final double progress;

  _PsychicTerrainPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.indigo.withValues(alpha: 0.1),
    );

    final paint = Paint()
      ..color = Colors.deepPurple.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);

    for (int i = 0; i < 5; i++) {
      final x =
          (math.Random(i).nextDouble() * size.width +
              math.sin(progress * 3 + i) * 50) %
          size.width;
      final y =
          size.height * 0.2 +
          (math.Random(i + 10).nextDouble() * size.height * 0.6);
      canvas.drawCircle(Offset(x, y), 60, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PsychicTerrainPainter oldDelegate) => true;
}

class _EmptyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant _EmptyPainter oldDelegate) => false;
}
