import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// CPU-based fuzzy animated background with soft bouncing circles and smooth falloff.
class FuzzyCirclesBackground extends StatefulWidget {
  const FuzzyCirclesBackground({
    super.key,
    this.circleCount = 5,
    this.radiusRange = const RangeValues(50, 180),
    this.softness = 80,
    this.speed = 5,
    this.parallaxScale = 2.0,
    this.intensity = 1.7,
    this.colors = const [
      Colors.orange,
      Colors.cyanAccent,
      Colors.purpleAccent,
      Colors.blue
    ],
    this.backgroundColor = Colors.transparent,
    this.child,
    this.seed,
    this.driftStrength = 0.15,
    this.bounceDamping = 0.98,
    this.falloff = 1.6,
    this.spacingFactor = 1.2,
  });

  final int circleCount;
  final RangeValues radiusRange;
  final double softness;
  final double speed;
  final double parallaxScale;
  final double intensity;
  final List<Color> colors;
  final Color backgroundColor;
  final Widget? child;
  final int? seed;
  final double driftStrength;
  final double bounceDamping;
  final double falloff;

  /// Controls how far apart circles start (1.0 = just touching, 1.2–1.5 = spaced out)
  final double spacingFactor;

  @override
  State<FuzzyCirclesBackground> createState() => _FuzzyCirclesBackgroundState();
}

class _Circle {
  Offset position;
  Offset velocity;
  double radius;
  double depth;
  Color color;
  double angle;

  _Circle(this.position, this.velocity, this.radius, this.depth, this.color, this.angle);
}

class _FuzzyCirclesBackgroundState extends State<FuzzyCirclesBackground>
    with SingleTickerProviderStateMixin {
  List<_Circle> _circles = [];
  late final Random _rng;
  late final Ticker _ticker;
  Duration _lastTime = Duration.zero;
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _rng = Random(widget.seed ?? 42);
    _ticker = createTicker(_tick)..start();
  }

  void _initialize(Size size) {
    _screenSize = size;
    _circles.clear();

    final palette = widget.colors.isNotEmpty
        ? widget.colors
        : [Colors.pinkAccent, Colors.cyanAccent, Colors.purpleAccent];

    // Greedy spaced initialization
    int maxAttempts = 2000;
    for (int i = 0; i < widget.circleCount; i++) {
      final depth = pow(_rng.nextDouble(), 2.0).toDouble();
      final r = ui.lerpDouble(
        widget.radiusRange.start,
        widget.radiusRange.end,
        _rng.nextDouble(),
      )!;
      final angle = _rng.nextDouble() * 2 * pi;
      final velocity = Offset(cos(angle), sin(angle));
      final color = palette[_rng.nextInt(palette.length)];

      Offset? pos;
      int attempt = 0;

      while (attempt++ < maxAttempts) {
        final candidate = Offset(
          _rng.nextDouble() * size.width,
          _rng.nextDouble() * size.height,
        );

        bool farEnough = true;
        for (final c in _circles) {
          final minDist = (r + c.radius) * widget.spacingFactor;
          if ((candidate - c.position).distance < minDist) {
            farEnough = false;
            break;
          }
        }

        if (farEnough) {
          pos = candidate;
          break;
        }
      }

      // If couldn't find good spaced position, fallback to random
      pos ??= Offset(
        _rng.nextDouble() * size.width,
        _rng.nextDouble() * size.height,
      );

      _circles.add(_Circle(pos, velocity, r, depth, color, angle));
    }
  }

  void _tick(Duration elapsed) {
    if (_screenSize == Size.zero || _circles.isEmpty) return;

    final dt = (elapsed - _lastTime).inMilliseconds / 1000.0;
    _lastTime = elapsed;
    if (dt <= 0 || dt.isNaN) return;

    const double basePixelSpeed = 10.0;
    final width = _screenSize.width;
    final height = _screenSize.height;

    for (final c in _circles) {
      // Smooth directional drift
      c.angle += (_rng.nextDouble() - 0.5) * widget.driftStrength * dt;
      c.velocity = Offset(cos(c.angle), sin(c.angle));

      final speedPxPerSec =
          widget.speed * basePixelSpeed / (1.0 + c.depth * widget.parallaxScale);

      c.position += c.velocity * speedPxPerSec * dt;

      final double r = c.radius + widget.softness * 0.3;

      // Bounce horizontally
      if (c.position.dx - r < 0) {
        c.position = Offset(r, c.position.dy);
        c.velocity = Offset(-c.velocity.dx * widget.bounceDamping, c.velocity.dy);
        c.angle = atan2(c.velocity.dy, c.velocity.dx);
      } else if (c.position.dx + r > width) {
        c.position = Offset(width - r, c.position.dy);
        c.velocity = Offset(-c.velocity.dx * widget.bounceDamping, c.velocity.dy);
        c.angle = atan2(c.velocity.dy, c.velocity.dx);
      }

      // Bounce vertically
      if (c.position.dy - r < 0) {
        c.position = Offset(c.position.dx, r);
        c.velocity = Offset(c.velocity.dx, -c.velocity.dy * widget.bounceDamping);
        c.angle = atan2(c.velocity.dy, c.velocity.dx);
      } else if (c.position.dy + r > height) {
        c.position = Offset(c.position.dx, height - r);
        c.velocity = Offset(c.velocity.dx, -c.velocity.dy * widget.bounceDamping);
        c.angle = atan2(c.velocity.dy, c.velocity.dx);
      }
    }

    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (_circles.isEmpty || _screenSize != size) {
          _initialize(size);
        }

        return CustomPaint(
          painter: _CirclesPainter(
            circles: _circles,
            softness: widget.softness,
            intensity: widget.intensity,
            backgroundColor: widget.backgroundColor,
            falloff: widget.falloff,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _CirclesPainter extends CustomPainter {
  final List<_Circle> circles;
  final double softness;
  final double intensity;
  final Color backgroundColor;
  final double falloff;

  _CirclesPainter({
    required this.circles,
    required this.softness,
    required this.intensity,
    required this.backgroundColor,
    required this.falloff,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    canvas.drawColor(backgroundColor, BlendMode.srcOver);

    for (final c in circles) {
      final r = c.radius + softness;

      // Multi-stop radial gradient for smoother energy falloff
      final gradient = RadialGradient(
        colors: [
          c.color.withOpacity(0.15 * intensity),
          c.color.withOpacity(0.07 * intensity),
          c.color.withOpacity(0.0),
        ],
        stops: const [0.0, 0.6, 1.0],
      );

      paint.shader =
          gradient.createShader(Rect.fromCircle(center: c.position, radius: r));
      canvas.drawCircle(c.position, r, paint);
    }

    // Global blur for soft diffusion
    canvas.saveLayer(
      Offset.zero & size,
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: softness * 0.25 / 20.0,
          sigmaY: softness * 0.25 / 20.0,
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CirclesPainter oldDelegate) => true;
}
