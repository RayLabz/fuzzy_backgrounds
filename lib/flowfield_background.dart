import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Flow-field / Perlin background: thousands of lightweight particles
/// advect through an animated 2D Perlin vector field for a silky, organic look.
///
/// No shaders. Fully Flutter Canvas; GPU does the rasterization.
/// Tune particleCount based on device perf (mobile: 1k–3k, desktop: 5k–10k).
class FlowFieldBackground extends StatefulWidget {
  const FlowFieldBackground({
    super.key,
    this.particleCount = 2000,
    this.noiseScale = 0.003,     // field spatial frequency (smaller => larger swirls)
    this.noiseSpeed = 0.15,      // how fast the field animates over time
    this.particleSpeed = 40.0,   // pixels/sec baseline
    this.turnResponsiveness = 4.0,// how quickly particles align to field
    this.lineWidth = 1.2,
    this.segmentSeconds = 1 / 50.0, // segment length (sec) per frame
    this.wrap = true,            // wrap around edges (continuous) or bounce
    this.backgroundColor = Colors.black,
    this.colorA = const Color(0xFF00FFC6),
    this.colorB = const Color(0xFF8A6BFF),
    this.opacity = 0.65,         // global paint alpha for strokes
    this.child,
    this.seed,
  });

  /// Particle count (mobile: 1k–3k, desktop: up to 10k+).
  final int particleCount;

  /// Spatial frequency of the noise field (world units -> normalized coords).
  final double noiseScale;

  /// Temporal speed of the noise field animation.
  final double noiseSpeed;

  /// Base particle speed in pixels/sec (before field modulation).
  final double particleSpeed;

  /// How quickly particles steer toward the field vector (0–8 good).
  final double turnResponsiveness;

  /// Stroke width of particle segments.
  final double lineWidth;

  /// Segment length in seconds (smaller => smoother, more CPU).
  final double segmentSeconds;

  /// If true, particles wrap seamlessly; otherwise they bounce.
  final bool wrap;

  /// Background fill color.
  final Color backgroundColor;

  /// Stroke color gradient (mapped by local field speed/curvature).
  final Color colorA;
  final Color colorB;

  /// Global stroke opacity (0–1).
  final double opacity;

  /// Optional overlay child.
  final Widget? child;

  /// Deterministic RNG seed.
  final int? seed;

  @override
  State<FlowFieldBackground> createState() => _FlowFieldBackgroundState();
}

class _Particle {
  Offset p;
  Offset v; // direction unit vector * speed scalar (we keep unit dir separately)
  _Particle(this.p, this.v);
}

class _FlowFieldBackgroundState extends State<FlowFieldBackground>
    with SingleTickerProviderStateMixin {
  final List<_Particle> _particles = [];
  late final _Perlin _perlin;
  late final Random _rng;

  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0.0;

  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    _rng = Random(widget.seed ?? 1337);
    _perlin = _Perlin(seed: _rng.nextInt(1 << 31));
    _ticker = createTicker(_tick)..start();
  }

  void _ensureInit(Size size) {
    if (_size == size && _particles.isNotEmpty) return;
    _size = size;
    _particles
      ..clear()
      ..addAll(List.generate(widget.particleCount, (_) {
        final p = Offset(
          _rng.nextDouble() * size.width,
          _rng.nextDouble() * size.height,
        );
        // Random initial heading
        final a = _rng.nextDouble() * pi * 2;
        final dir = Offset(cos(a), sin(a));
        return _Particle(p, dir * widget.particleSpeed);
      }));
  }

  void _tick(Duration elapsed) {
    if (_size == Size.zero || _particles.isEmpty) return;

    if (_last == Duration.zero) {
      _last = elapsed;
      return;
    }
    double dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;

    // Clamp pathological spikes (e.g., tab switch or frame hitch)
    if (dt <= 0 || dt.isNaN || dt > 0.25) return;

    // Advance "field time"
    _time += dt * widget.noiseSpeed;

    // Integrate particles with fixed sub-steps if needed for stability
    final seg = widget.segmentSeconds.clamp(1 / 120.0, 1 / 30.0);
    while (dt > 0) {
      final step = dt > seg ? seg : dt;
      _simulate(step);
      dt -= step;
    }

    setState(() {});
  }

  void _simulate(double dt) {
    final w = _size.width;
    final h = _size.height;

    // Field angle from perlin noise; convert to unit direction.
    Offset fieldDir(Offset p) {
      final nx = p.dx * widget.noiseScale;
      final ny = p.dy * widget.noiseScale;
      // Get 2D perlin value in [-1, 1]
      final n = _perlin.noise3(nx, ny, _time); // animated via z=time
      // Map to angle and derive a unit vector
      final angle = n * pi * 2.0;
      return Offset(cos(angle), sin(angle));
    }

    for (final part in _particles) {
      // Current direction (unit)
      Offset vDir;
      final vLen = part.v.distance;
      if (vLen > 1e-6) {
        vDir = part.v / vLen;
      } else {
        final a = _rng.nextDouble() * 2 * pi;
        vDir = Offset(cos(a), sin(a));
      }

      // Sample field direction
      final fDir = fieldDir(part.p);

      // Steer toward field with responsiveness factor
      final steering = Offset.lerp(vDir, fDir, (widget.turnResponsiveness * dt).clamp(0.0, 1.0))!;
      final newDir = steering / (steering.distance == 0 ? 1 : steering.distance);

      // Optionally modulate speed slightly by curl/curvature for visual variety
      final ahead = part.p + fDir * 6.0;
      final fAhead = fieldDir(ahead);
      final curvature = (fAhead - fDir).distance; // ~0..2
      final speedMod = 0.75 + curvature.clamp(0.0, 1.0) * 0.5;

      final speed = widget.particleSpeed * speedMod;
      part.v = newDir * speed;

      // Integrate
      part.p += part.v * dt;

      if (widget.wrap) {
        // Continuous wrap (no teleport look due to segment drawing)
        if (part.p.dx < 0) part.p = Offset(part.p.dx + w, part.p.dy);
        if (part.p.dx > w) part.p = Offset(part.p.dx - w, part.p.dy);
        if (part.p.dy < 0) part.p = Offset(part.p.dx, part.p.dy + h);
        if (part.p.dy > h) part.p = Offset(part.p.dx, part.p.dy - h);
      } else {
        // Bounce
        if (part.p.dx < 0 || part.p.dx > w) {
          part.v = Offset(-part.v.dx, part.v.dy);
          part.p = Offset(part.p.dx.clamp(0.0, w), part.p.dy);
        }
        if (part.p.dy < 0 || part.p.dy > h) {
          part.v = Offset(part.v.dx, -part.v.dy);
          part.p = Offset(part.p.dx, part.p.dy.clamp(0.0, h));
        }
      }
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth == double.infinity ? MediaQuery.of(context).size.width : constraints.maxWidth,
        constraints.maxHeight == double.infinity ? MediaQuery.of(context).size.height : constraints.maxHeight,
      );
      _ensureInit(size);

      return CustomPaint(
        painter: _FlowFieldPainter(
          particles: _particles,
          background: widget.backgroundColor,
          colorA: widget.colorA,
          colorB: widget.colorB,
          opacity: widget.opacity,
          lineWidth: widget.lineWidth,
        ),
        child: widget.child,
      );
    });
  }
}

class _FlowFieldPainter extends CustomPainter {
  final List<_Particle> particles;
  final Color background;
  final Color colorA;
  final Color colorB;
  final double opacity;
  final double lineWidth;

  _FlowFieldPainter({
    required this.particles,
    required this.background,
    required this.colorA,
    required this.colorB,
    required this.opacity,
    required this.lineWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Clear (we redraw trails fresh every frame; cheap with strokes)
    canvas.drawColor(background, BlendMode.srcOver);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = lineWidth
      ..blendMode = BlendMode.plus;

    // Draw short motion segments; color mapped by instantaneous speed.
    for (final p in particles) {
      final v = p.v;
      final vLen = v.distance; // px/sec
      final t = (vLen / 120.0).clamp(0.0, 1.0); // normalize for palette blend
      final color = Color.lerp(colorA, colorB, t)!.withOpacity(opacity);

      paint.color = color;

      // Segment length proportional to velocity; small cap for smoothness
      final seg = (v * (1 / 60.0)); // ~one frame motion
      final from = p.p - seg;
      final to = p.p;

      // Anti-teleport edge blending:
      // If wrapping happened between frames, just draw a point to avoid a long line
      if ((from - to).distance < 50) {
        canvas.drawLine(from, to, paint);
      } else {
        // fallback: small dot
        canvas.drawPoints(ui.PointMode.points, [to], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlowFieldPainter oldDelegate) => true;
}

/// Lightweight Perlin noise (3D): classic implementation.
/// z dimension is time to animate the field smoothly.
class _Perlin {
  late List<int> p;
  _Perlin({int seed = 0}) {
    final rng = Random(seed);
    final perm = List<int>.generate(256, (_) => rng.nextInt(256));
    p = List<int>.filled(512, 0);
    for (int i = 0; i < 512; i++) {
      p[i] = perm[i & 255];
    }
  }

  double fade(double t) => t * t * t * (t * (t * 6 - 15) + 10);
  double lerp(double t, double a, double b) => a + t * (b - a);
  double grad(int hash, double x, double y, double z) {
    final h = hash & 15;
    final u = h < 8 ? x : y;
    final v = h < 4 ? y : (h == 12 || h == 14 ? x : z);
    final s = ((h & 1) == 0) ? u : -u;
    final t = ((h & 2) == 0) ? v : -v;
    return s + t;
  }

  /// 3D Perlin noise in [-1, 1]
  double noise3(double x, double y, double z) {
    final xi = x.floor() & 255;
    final yi = y.floor() & 255;
    final zi = z.floor() & 255;

    final xf = x - x.floor();
    final yf = y - y.floor();
    final zf = z - z.floor();

    final u = fade(xf);
    final v = fade(yf);
    final w = fade(zf);

    final aaa = p[p[p[xi] + yi] + zi];
    final aba = p[p[p[xi] + (yi + 1)] + zi];
    final aab = p[p[p[xi] + yi] + (zi + 1)];
    final abb = p[p[p[xi] + (yi + 1)] + (zi + 1)];
    final baa = p[p[p[(xi + 1)] + yi] + zi];
    final bba = p[p[p[(xi + 1)] + (yi + 1)] + zi];
    final bab = p[p[p[(xi + 1)] + yi] + (zi + 1)];
    final bbb = p[p[p[(xi + 1)] + (yi + 1)] + (zi + 1)];

    final x1 = lerp(
      u,
      grad(aaa, xf, yf, zf),
      grad(baa, xf - 1, yf, zf),
    );
    final x2 = lerp(
      u,
      grad(aba, xf, yf - 1, zf),
      grad(bba, xf - 1, yf - 1, zf),
    );
    final y1 = lerp(v, x1, x2);

    final x3 = lerp(
      u,
      grad(aab, xf, yf, zf - 1),
      grad(bab, xf - 1, yf, zf - 1),
    );
    final x4 = lerp(
      u,
      grad(abb, xf, yf - 1, zf - 1),
      grad(bbb, xf - 1, yf - 1, zf - 1),
    );
    final y2 = lerp(v, x3, x4);

    // Map from approx [-1,1]
    return lerp(w, y1, y2).clamp(-1.0, 1.0);
  }
}
