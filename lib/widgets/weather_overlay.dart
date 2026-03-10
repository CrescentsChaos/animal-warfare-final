import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/weather.dart';

class WeatherOverlay extends StatefulWidget {
  final Weather weather;

  const WeatherOverlay({super.key, required this.weather});

  @override
  State<WeatherOverlay> createState() => _WeatherOverlayState();
}

class _WeatherOverlayState extends State<WeatherOverlay>
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
    if (widget.weather == Weather.none || widget.weather == Weather.clear) {
      return const SizedBox.shrink();
    }

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            painter: _getPainter(widget.weather, _controller.value),
            size: Size.infinite,
          );
        },
      ),
    );
  }

  CustomPainter _getPainter(Weather weather, double progress) {
    switch (weather) {
      case Weather.rain:
      case Weather.heavyRain:
        return _RainPainter(
          progress: progress,
          isHeavy: weather == Weather.heavyRain,
        );
      case Weather.hail:
        return _HailPainter(progress: progress);
      case Weather.snowstorm:
        return _SnowPainter(progress: progress, isHeavy: false);
      case Weather.sandstorm:
        return _SandstormPainter(progress: progress);
      case Weather.sunny:
        return _SunnyPainter(progress: progress);
      case Weather.fog:
        return _FogPainter(progress: progress);
      case Weather.thunderstorm:
        return _ThunderstormPainter(progress: progress);
      case Weather.windstorm:
        return _WindPainter(progress: progress);
      case Weather.typhoon:
      case Weather.hurricane:
        return _HurricanePainter(
          progress: progress,
          isTyphoon: weather == Weather.typhoon,
        );
      case Weather.tornado:
        return _TornadoPainter(progress: progress);
      case Weather.tsunami:
        return _TsunamiPainter(progress: progress);
      case Weather.earthquake:
        return _EarthquakePainter(progress: progress);
      case Weather.volcanoEruption:
        return _VolcanoPainter(progress: progress);
      case Weather.blizzard:
        return _SnowPainter(progress: progress, isHeavy: true);
      default:
        return _EmptyPainter();
    }
  }
}

class _RainPainter extends CustomPainter {
  final double progress;
  final bool isHeavy;
  final List<Offset> drops;

  _RainPainter({required this.progress, required this.isHeavy})
    : drops = List.generate(
        isHeavy ? 150 : 80,
        (i) => Offset(
          math.Random(i).nextDouble(),
          math.Random(i + 100).nextDouble(),
        ),
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Background atmospheric tint
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.blueGrey.withValues(alpha: isHeavy ? 0.25 : 0.1),
    );

    final paint = Paint()
      ..color = Colors.blue.withValues(alpha: isHeavy ? 0.6 : 0.4)
      ..strokeWidth = isHeavy ? 2.5 : 1.5
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < drops.length; i++) {
      final drop = drops[i];
      final speedMult = 1.0 + (math.Random(i).nextDouble() * 0.5);
      final x = drop.dx * size.width;
      final y = ((drop.dy + progress * speedMult) % 1.0) * size.height;

      final dropLength = isHeavy ? 25.0 : 15.0;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - (dropLength * 0.2), y + dropLength),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RainPainter oldDelegate) => true;
}

class _SnowPainter extends CustomPainter {
  final double progress;
  final bool isHeavy;
  final Color color;
  final List<_Snowflake> flakes;

  _SnowPainter({
    required this.progress,
    required this.isHeavy,
    this.color = Colors.white,
  }) : flakes = List.generate(
         isHeavy ? 200 : 100,
         (i) => _Snowflake(
           radius: math.Random(i).nextDouble() * (isHeavy ? 4 : 3) + 1,
           x: math.Random(i + 1).nextDouble(),
           y: math.Random(i + 2).nextDouble(),
           speed: math.Random(i + 3).nextDouble() * (isHeavy ? 1.0 : 0.5) + 0.2,
           drift:
               (math.Random(i + 4).nextDouble() * 0.4 - 0.2) +
               (isHeavy ? -0.5 : 0.0),
         ),
       );

  @override
  void paint(Canvas canvas, Size size) {
    // Cold atmospheric tint
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(
          0xFFE0F7FA,
        ).withValues(alpha: isHeavy ? 0.3 : 0.15),
    );

    final paint = Paint();
    for (var flake in flakes) {
      final x =
          (flake.x * size.width + (flake.drift * progress * size.width)) %
          size.width;
      final y =
          (flake.y * size.height + (flake.speed * progress * size.height)) %
          size.height;

      paint.color = color.withValues(alpha: isHeavy ? 0.9 : 0.7);
      canvas.drawCircle(Offset(x, y), flake.radius, paint);

      // Add a small glow to heavy flakes
      if (isHeavy && flake.radius > 3) {
        canvas.drawCircle(
          Offset(x, y),
          flake.radius + 2,
          Paint()..color = color.withValues(alpha: 0.2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SnowPainter oldDelegate) => true;
}

class _Snowflake {
  final double radius;
  final double x;
  final double y;
  final double speed;
  final double drift;

  _Snowflake({
    required this.radius,
    required this.x,
    required this.y,
    required this.speed,
    required this.drift,
  });
}

class _SandstormPainter extends CustomPainter {
  final double progress;
  final List<_SandParticle> particles;

  _SandstormPainter({required this.progress})
    : particles = List.generate(
        250,
        (i) => _SandParticle(
          x: math.Random(i).nextDouble(),
          y: math.Random(i + 1).nextDouble(),
          size: math.Random(i + 2).nextDouble() * 2 + 1,
          speed: math.Random(i + 3).nextDouble() * 2.0 + 1.5,
          opacity: math.Random(i + 4).nextDouble() * 0.4 + 0.2,
        ),
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Hazy brown atmosphere
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = const Color(0xFFD2B48C).withValues(alpha: 0.3)
        ..blendMode = BlendMode.multiply,
    );

    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var p in particles) {
      final x =
          ((p.x * size.width - progress * p.speed * size.width) % size.width);
      final y =
          (p.y * size.height + math.sin(progress * 5 + p.x * 10) * 15) %
          size.height;

      paint.color = const Color(0xFF8B4513).withValues(alpha: p.opacity);
      paint.strokeWidth = p.size;

      // Draw as a short line to show wind direction
      final lineLength = p.size * 3;
      canvas.drawLine(Offset(x, y), Offset(x + lineLength, y - 2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SandstormPainter oldDelegate) => true;
}

class _SandParticle {
  final double x;
  final double y;
  final double size;
  final double speed;
  final double opacity;

  _SandParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

class _SunnyPainter extends CustomPainter {
  final double progress;

  _SunnyPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;

    // Intense solar glow in the corner
    final sunCenter = Offset(size.width * 0.85, size.height * 0.15);
    final sunPulse = math.sin(progress * math.pi * 2) * 0.1 + 0.9;

    final Paint sunPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.yellow.withValues(alpha: 0.4 * sunPulse),
          Colors.orange.withValues(alpha: 0.2 * sunPulse),
          Colors.transparent,
        ],
        center: const Alignment(0.7, -0.7),
        radius: 0.6 * sunPulse,
      ).createShader(rect);

    canvas.drawPaint(sunPaint);

    // Scorched atmospheric tint
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.orange.withValues(alpha: 0.1)
        ..blendMode = BlendMode.overlay,
    );

    // Intense heat waves
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15 * sunPulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    for (double i = 0; i < size.width; i += 40) {
      final wavePath = Path();
      wavePath.moveTo(i, size.height);
      for (double j = size.height; j > 0; j -= 30) {
        final xOffset = math.sin(progress * 15 + j * 0.05 + i * 0.02) * 12;
        wavePath.lineTo(i + xOffset, j);
      }
      canvas.drawPath(wavePath, wavePaint);
    }

    // Additional radial heat from center
    canvas.drawCircle(
      sunCenter,
      size.width * 0.1,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3 * sunPulse)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );
  }

  @override
  bool shouldRepaint(covariant _SunnyPainter oldDelegate) => true;
}

class _FogPainter extends CustomPainter {
  final double progress;

  _FogPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0.6),
          Colors.white.withValues(alpha: 0.4),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint);

    // Drifting cloud layers
    final blobPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);

    for (int layer = 0; layer < 3; layer++) {
      final layerSpeed = 0.1 + (layer * 0.05);
      final layerOpacity = 0.15 - (layer * 0.03);

      for (int i = 0; i < 4; i++) {
        final x =
            ((progress * layerSpeed + i * 0.25 + layer * 0.1) % 1.0) *
                (size.width + 400) -
            200;
        final y =
            (math.sin(i + progress * 0.5 + layer) * 0.15 +
                0.3 +
                (layer * 0.2)) *
            size.height;
        final radius = 150.0 + (layer * 50);

        blobPaint.color = Colors.white.withValues(alpha: layerOpacity);
        canvas.drawCircle(Offset(x, y), radius, blobPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FogPainter oldDelegate) => true;
}

class _ThunderstormPainter extends CustomPainter {
  final double progress;
  final List<Offset> drops;

  _ThunderstormPainter({required this.progress})
    : drops = List.generate(
        120,
        (i) => Offset(
          math.Random(i).nextDouble(),
          math.Random(i + 100).nextDouble(),
        ),
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Very dark background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: 0.4),
    );

    // Dynamic Lightning Strike
    final random = math.Random((progress * 15).floor());
    if (random.nextDouble() < 0.08) {
      final flashOpacity = random.nextDouble() * 0.5 + 0.2;
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0xFFE0E0FF).withValues(alpha: flashOpacity)
          ..blendMode = BlendMode.screen,
      );
    }

    final paint = Paint()
      ..color = Colors.blueGrey.withValues(alpha: 0.7)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < drops.length; i++) {
      final drop = drops[i];
      final speedMult = 2.0 + (math.Random(i).nextDouble() * 1.0);
      final x = drop.dx * size.width;
      final y = ((drop.dy + progress * speedMult) % 1.0) * size.height;

      final dropLength = 30.0;
      canvas.drawLine(
        Offset(x, y),
        Offset(x - (dropLength * 0.3), y + dropLength),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ThunderstormPainter oldDelegate) => true;
}

class _HailPainter extends CustomPainter {
  final double progress;

  _HailPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Background tint (cold gray)
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.blueGrey.withValues(alpha: 0.15),
    );

    final random = math.Random(42);
    const pelletCount = 60;

    final paint = Paint()..color = Colors.white;
    final glintPaint = Paint()..color = Colors.lightBlueAccent.withAlpha(180);

    for (int i = 0; i < pelletCount; i++) {
      final initialX = random.nextDouble() * size.width;
      final initialY = random.nextDouble() * size.height;
      final speed = 25.0 + random.nextDouble() * 30.0; // Faster bombardment
      final sizePellet = 4.0 + random.nextDouble() * 6.0; // Larger crystals

      double yPos = (initialY + progress * speed * 30) % size.height;
      double xPos =
          (initialX + progress * 8 * 30) % size.width; // Sharper drift

      // Draw diamond/crystalline shape
      final path = Path();
      path.moveTo(xPos, yPos - sizePellet); // Top
      path.lineTo(xPos + sizePellet / 1.5, yPos); // Right
      path.lineTo(xPos, yPos + sizePellet); // Bottom
      path.lineTo(xPos - sizePellet / 1.5, yPos); // Left
      path.close();

      canvas.drawPath(path, paint..color = Colors.white.withValues(alpha: 0.9));

      // Add a crystalline glint/shadow
      final glintPath = Path();
      glintPath.moveTo(xPos, yPos - sizePellet * 0.5);
      glintPath.lineTo(xPos + sizePellet * 0.3, yPos);
      glintPath.lineTo(xPos, yPos + sizePellet * 0.5);
      glintPath.lineTo(xPos - sizePellet * 0.3, yPos);
      glintPath.close();

      canvas.drawPath(glintPath, glintPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HailPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _WindPainter extends CustomPainter {
  final double progress;
  final List<_WindLine> lines;

  _WindPainter({required this.progress})
    : lines = List.generate(
        60,
        (i) => _WindLine(
          x: math.Random(i).nextDouble(),
          y: math.Random(i + 1).nextDouble(),
          length: math.Random(i + 2).nextDouble() * 80 + 40,
          speed: math.Random(i + 3).nextDouble() * 3.0 + 2.0,
          opacity: math.Random(i + 4).nextDouble() * 0.3 + 0.1,
        ),
      );

  @override
  void paint(Canvas canvas, Size size) {
    // Subtle atmospheric tint
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );

    final paint = Paint()..strokeCap = StrokeCap.round;

    for (var line in lines) {
      final x =
          ((line.x * size.width + progress * line.speed * size.width) %
              (size.width + 200)) -
          100;
      final y =
          (line.y * size.height + math.sin(progress * 8 + line.x * 5) * 25) %
          size.height;

      paint.color = Colors.white.withValues(alpha: line.opacity);
      paint.strokeWidth = 1.2;

      canvas.drawLine(
        Offset(x, y),
        Offset(x + line.length, y + (math.sin(progress * 5) * 5)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WindPainter oldDelegate) => true;
}

class _WindLine {
  final double x;
  final double y;
  final double length;
  final double speed;
  final double opacity;

  _WindLine({
    required this.x,
    required this.y,
    required this.length,
    required this.speed,
    required this.opacity,
  });
}

class _HurricanePainter extends CustomPainter {
  final double progress;
  final bool isTyphoon;
  final _RainPainter _rain;
  final _WindPainter _wind;
  final _ThunderstormPainter _storm;

  _HurricanePainter({required this.progress, required this.isTyphoon})
    : _rain = _RainPainter(progress: progress, isHeavy: true),
      _wind = _WindPainter(progress: progress),
      _storm = _ThunderstormPainter(progress: progress);

  @override
  void paint(Canvas canvas, Size size) {
    _rain.paint(canvas, size);
    _wind.paint(canvas, size);
    if (!isTyphoon) _storm.paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _HurricanePainter oldDelegate) => true;
}

class _TornadoPainter extends CustomPainter {
  final double progress;
  final List<_WindLine> lines;

  _TornadoPainter({required this.progress})
    : lines = List.generate(
        100,
        (i) => _WindLine(
          x: math.Random(i).nextDouble(),
          y: math.Random(i + 1).nextDouble(),
          length: math.Random(i + 2).nextDouble() * 120 + 60,
          speed: math.Random(i + 3).nextDouble() * 5.0 + 4.0,
          opacity: math.Random(i + 4).nextDouble() * 0.5 + 0.2,
        ),
      );

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.grey.withValues(alpha: 0.2),
    );

    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.0;

    for (var line in lines) {
      final x =
          ((line.x * size.width + progress * line.speed * size.width) %
              (size.width + 400)) -
          200;
      final y =
          (line.y * size.height + math.sin(progress * 15 + line.x * 10) * 50) %
          size.height;

      paint.color = Colors.white.withValues(alpha: line.opacity);
      canvas.drawLine(Offset(x, y), Offset(x + line.length, y - 5), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TornadoPainter oldDelegate) => true;
}

class _TsunamiPainter extends CustomPainter {
  final double progress;

  _TsunamiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.blue.withValues(alpha: 0.3);

    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + i * 0.33) % 1.0;
      final height = size.height * (0.2 + 0.1 * math.sin(progress * 5 + i));
      final path = Path();
      path.moveTo(0, size.height);
      path.lineTo(0, size.height - height);

      for (double x = 0; x <= size.width; x += 20) {
        final y =
            size.height -
            height +
            math.sin(x * 0.01 + progress * 10 + i) * 20 * waveProgress;
        path.lineTo(x, y);
      }

      path.lineTo(size.width, size.height);
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _TsunamiPainter oldDelegate) => true;
}

class _EarthquakePainter extends CustomPainter {
  final double progress;

  _EarthquakePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (math.Random((progress * 20).floor()).nextDouble() > 0.7) {
      final offsetX = (math.Random().nextDouble() - 0.5) * 20;
      final offsetY = (math.Random().nextDouble() - 0.5) * 20;
      canvas.translate(offsetX, offsetY);
    }

    final paint = Paint()
      ..color = Colors.brown.withValues(alpha: 0.1)
      ..strokeWidth = 2.0;

    final random = math.Random(42);
    for (int i = 0; i < 5; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 50, y + 20),
        paint..color = Colors.black.withValues(alpha: 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EarthquakePainter oldDelegate) => true;
}

class _VolcanoPainter extends CustomPainter {
  final double progress;

  _VolcanoPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    // Ash fall (darker snow)
    final ashPainter = _SnowPainter(
      progress: progress,
      isHeavy: true,
      color: Colors.grey[700]!,
    );
    ashPainter.paint(canvas, size);

    // Embers (red particles)
    final embers = List.generate(
      50,
      (i) => Offset(
        math.Random(i).nextDouble(),
        math.Random(i + 100).nextDouble(),
      ),
    );

    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.red.withValues(alpha: 0.1),
    );

    final emberPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    for (int i = 0; i < embers.length; i++) {
      final e = embers[i];
      final x = e.dx * size.width;
      final y = ((e.dy - progress * 0.5) % 1.0) * size.height;
      emberPaint.color = Colors.orangeAccent.withValues(
        alpha: 0.6 + 0.4 * math.sin(progress * 10 + i),
      );
      canvas.drawCircle(
        Offset(x, y),
        2 + math.Random(i).nextDouble() * 3,
        emberPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VolcanoPainter oldDelegate) => true;
}

class _EmptyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant _EmptyPainter oldDelegate) => false;
}
