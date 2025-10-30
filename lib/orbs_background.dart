import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Visually rich glowing orbs with bloom, parallax and gentle motion.
/// No shaders required — GPU blur and color blending create the glow.
class BloomyOrbsBackground extends StatefulWidget {
  const BloomyOrbsBackground({
    super.key,
    this.orbCount = 2,
    this.radiusRange = const RangeValues(80, 200),
    this.softness = 100,
    this.speed = 1.0,
    this.parallaxScale = 2.0,
    this.intensity = 0.7,
    this.colors = const [
      Colors.pinkAccent,
      Colors.cyanAccent,
      Colors.deepPurpleAccent,
      Colors.orangeAccent,
    ],
    this.backgroundColor = Colors.transparent,
    this.seed,
    this.driftStrength = 0.2,
    this.bounceDamping = 0.96,
    this.chromaticAberration = 2.5,
    this.flickerAmplitude = 0.2,
    this.child,
  });

  final int orbCount;
  final RangeValues radiusRange;
  final double softness;
  final double speed;
  final double parallaxScale;
  final double intensity;
  final List<Color> colors;
  final Color backgroundColor;
  final int? seed;
  final double driftStrength;
  final double bounceDamping;
  final double chromaticAberration;
  final double flickerAmplitude;
  final Widget? child;

  @override
  State<BloomyOrbsBackground> createState() => _BloomyOrbsBackgroundState();
}

class _Orb {
  Offset position;
  Offset velocity;
  double radius;
  double depth;
  Color color;
  double angle;
  double flickerPhase;

  _Orb(this.position, this.velocity, this.radius, this.depth, this.color, this.angle, this.flickerPhase);
}

class _BloomyOrbsBackgroundState extends State<BloomyOrbsBackground>
    with SingleTickerProviderStateMixin {
  late final Random _rng;
  late final Ticker _ticker;
  List<_Orb> _orbs = [];
  Duration _lastTime = Duration.zero;
  Size _screenSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _rng = Random(widget.seed ?? 1337);
    _ticker = createTicker(_tick)..start();
  }

  void _initialize(Size size) {
    _screenSize = size;
    _orbs.clear();

    for (int i = 0; i < widget.orbCount; i++) {
      final depth = pow(_rng.nextDouble(), 2.0).toDouble();
      final r = ui.lerpDouble(
        widget.radiusRange.start,
        widget.radiusRange.end,
        _rng.nextDouble(),
      )!;
      final pos = Offset(
        _rng.nextDouble() * size.width,
        _rng.nextDouble() * size.height,
      );
      final angle = _rng.nextDouble() * 2 * pi;
      final velocity = Offset(cos(angle), sin(angle));
      final color = widget.colors[_rng.nextInt(widget.colors.length)];
      final flickerPhase = _rng.nextDouble() * 2 * pi;

      _orbs.add(_Orb(pos, velocity, r, depth, color, angle, flickerPhase));
    }
  }

  void _tick(Duration elapsed) {
    if (_screenSize == Size.zero || _orbs.isEmpty) return;

    if (_lastTime == Duration.zero) {
      _lastTime = elapsed;
      return;
    }

    final dt = (elapsed - _lastTime).inMilliseconds / 1000.0;
    _lastTime = elapsed;
    if (dt <= 0 || dt.isNaN || dt > 0.5) return;

    const double basePixelSpeed = 10.0;
    final width = _screenSize.width;
    final height = _screenSize.height;

    for (final o in _orbs) {
      // Smooth directional drift
      o.angle += (_rng.nextDouble() - 0.5) * widget.driftStrength * dt;
      o.velocity = Offset(cos(o.angle), sin(o.angle));

      final speedPxPerSec =
          widget.speed * basePixelSpeed / (1.0 + o.depth * widget.parallaxScale);
      o.position += o.velocity * speedPxPerSec * dt;

      // Flicker phase progression
      o.flickerPhase += dt;

      final double r = o.radius + widget.softness * 0.3;

      // Bounce off edges
      if (o.position.dx - r < 0) {
        o.position = Offset(r, o.position.dy);
        o.velocity = Offset(-o.velocity.dx * widget.bounceDamping, o.velocity.dy);
        o.angle = atan2(o.velocity.dy, o.velocity.dx);
      } else if (o.position.dx + r > width) {
        o.position = Offset(width - r, o.position.dy);
        o.velocity = Offset(-o.velocity.dx * widget.bounceDamping, o.velocity.dy);
        o.angle = atan2(o.velocity.dy, o.velocity.dx);
      }
      if (o.position.dy - r < 0) {
        o.position = Offset(o.position.dx, r);
        o.velocity = Offset(o.velocity.dx, -o.velocity.dy * widget.bounceDamping);
        o.angle = atan2(o.velocity.dy, o.velocity.dx);
      } else if (o.position.dy + r > height) {
        o.position = Offset(o.position.dx, height - r);
        o.velocity = Offset(o.velocity.dx, -o.velocity.dy * widget.bounceDamping);
        o.angle = atan2(o.velocity.dy, o.velocity.dx);
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
        if (_orbs.isEmpty || _screenSize != size) {
          _initialize(size);
        }

        return CustomPaint(
          painter: _BloomyOrbsPainter(
            orbs: _orbs,
            softness: widget.softness,
            intensity: widget.intensity,
            backgroundColor: widget.backgroundColor,
            chromaticAberration: widget.chromaticAberration,
            flickerAmplitude: widget.flickerAmplitude,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _BloomyOrbsPainter extends CustomPainter {
  final List<_Orb> orbs;
  final double softness;
  final double intensity;
  final Color backgroundColor;
  final double chromaticAberration;
  final double flickerAmplitude;

  _BloomyOrbsPainter({
    required this.orbs,
    required this.softness,
    required this.intensity,
    required this.backgroundColor,
    required this.chromaticAberration,
    required this.flickerAmplitude,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    canvas.drawColor(backgroundColor, BlendMode.srcOver);

    for (final o in orbs) {
      final flicker =
          1.0 + sin(o.flickerPhase * 2 * pi) * flickerAmplitude; // subtle shimmer
      final r = o.radius + softness;

      // Core bloom
      final gradientCore = RadialGradient(
        colors: [
          o.color.withOpacity(0.35 * intensity * flicker),
          o.color.withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      );
      paint.shader =
          gradientCore.createShader(Rect.fromCircle(center: o.position, radius: r));
      canvas.drawCircle(o.position, r, paint);

      // Outer halo (larger, softer)
      final haloColor = o.color.withOpacity(0.12 * intensity * flicker);
      paint.shader = RadialGradient(
        colors: [haloColor, haloColor.withOpacity(0.0)],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: o.position, radius: r * 1.6));
      canvas.drawCircle(o.position, r * 1.6, paint);

      // Chromatic aberration flare (RGB split)
      for (int i = 0; i < 3; i++) {
        final offsetAngle = i * 2 * pi / 3;
        final dx = cos(offsetAngle) * chromaticAberration;
        final dy = sin(offsetAngle) * chromaticAberration;
        final color = [
          o.color.red / 255,
          o.color.green / 255,
          o.color.blue / 255
        ];
        final flareColor = Color.fromRGBO(
          (color[0] * 255).toInt(),
          (color[1] * 255).toInt(),
          (color[2] * 255).toInt(),
          0.2 * intensity,
        );
        paint.shader = RadialGradient(
          colors: [flareColor, flareColor.withOpacity(0.0)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(
            center: o.position.translate(dx, dy), radius: r * 1.2));
        canvas.drawCircle(o.position.translate(dx, dy), r * 1.2, paint);
      }
    }

    // Global blur pass to merge blooms softly
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
  bool shouldRepaint(covariant _BloomyOrbsPainter oldDelegate) => true;
}
