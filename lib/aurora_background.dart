import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Aurora background with optional sky depth (stars + parallax gradient sky).
class AuroraBackground extends StatefulWidget {
  const AuroraBackground({
    super.key,
    this.ribbonCount = 4,
    this.speed = 0.02,
    this.blur = 30.0,
    this.intensity = 0.8,
    this.waveAmplitude = 120.0,
    this.waveLength = 1.2,
    this.backgroundColor = Colors.black,
    this.colors = const [
      Color(0xFF00FFAA),
      Color(0xFF00AFFF),
      Color(0xFFA855F7),
      Color(0xFFFF80ED),
    ],
    this.skyDepth = 0.3,
    this.starCount = 120,
    this.starColor = Colors.white,
    this.starIntensity = 0.6,
    this.enableStars = false,
    this.enableGradientSky = false,
    this.child,
  });

  final int ribbonCount;
  final double speed;
  final double blur;
  final double intensity;
  final double waveAmplitude;
  final double waveLength;
  final Color backgroundColor;
  final List<Color> colors;

  /// Controls how deep the parallax effect appears.
  /// 0 = flat, 1 = very deep, subtle = 0.2–0.4 recommended.
  final double skyDepth;

  /// Optional stars (visible only if enableStars = true)
  final bool enableStars;
  final int starCount;
  final Color starColor;
  final double starIntensity;

  /// Optional gradient behind aurora (acts like a nebulous glow)
  final bool enableGradientSky;

  final Widget? child;

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0.0;
  late final Random _rng;
  late final List<_Ribbon> _ribbons;
  late final List<_Star> _stars;

  @override
  void initState() {
    super.initState();
    _rng = Random();
    _ribbons = List.generate(widget.ribbonCount, (_) => _Ribbon.random(_rng));
    _stars = List.generate(widget.starCount, (_) => _Star.random(_rng));
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration elapsed) {
    if (_last == Duration.zero) {
      _last = elapsed;
      return;
    }
    final dt = (elapsed - _last).inMilliseconds / 1000.0;
    _last = elapsed;
    _time += dt * widget.speed;
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _AuroraPainter(
        time: _time,
        ribbons: _ribbons,
        stars: _stars,
        blur: widget.blur,
        intensity: widget.intensity,
        amplitude: widget.waveAmplitude,
        wavelength: widget.waveLength,
        backgroundColor: widget.backgroundColor,
        colors: widget.colors,
        skyDepth: widget.skyDepth,
        enableStars: widget.enableStars,
        enableGradientSky: widget.enableGradientSky,
        starColor: widget.starColor,
        starIntensity: widget.starIntensity,
      ),
      child: widget.child,
    );
  }
}

class _Ribbon {
  final double baseY;
  final double phase;
  final double speedFactor;
  final double thickness;
  final int colorIndex;

  _Ribbon({
    required this.baseY,
    required this.phase,
    required this.speedFactor,
    required this.thickness,
    required this.colorIndex,
  });

  factory _Ribbon.random(Random rng) {
    return _Ribbon(
      baseY: rng.nextDouble(),
      phase: rng.nextDouble() * pi * 2,
      speedFactor: 0.6 + rng.nextDouble() * 0.8,
      thickness: 0.3 + rng.nextDouble() * 0.7,
      colorIndex: rng.nextInt(8),
    );
  }
}

class _Star {
  Offset position;
  double brightness;
  double twinkleSpeed;
  double twinklePhase;

  _Star({
    required this.position,
    required this.brightness,
    required this.twinkleSpeed,
    required this.twinklePhase,
  });

  factory _Star.random(Random rng) {
    return _Star(
      position: Offset(rng.nextDouble(), rng.nextDouble()),
      brightness: 0.3 + rng.nextDouble() * 0.7,
      twinkleSpeed: 0.5 + rng.nextDouble() * 1.2,
      twinklePhase: rng.nextDouble() * 2 * pi,
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double time;
  final List<_Ribbon> ribbons;
  final List<_Star> stars;
  final double blur;
  final double intensity;
  final double amplitude;
  final double wavelength;
  final double skyDepth;
  final bool enableStars;
  final bool enableGradientSky;
  final Color backgroundColor;
  final Color starColor;
  final double starIntensity;
  final List<Color> colors;

  _AuroraPainter({
    required this.time,
    required this.ribbons,
    required this.stars,
    required this.blur,
    required this.intensity,
    required this.amplitude,
    required this.wavelength,
    required this.backgroundColor,
    required this.colors,
    required this.skyDepth,
    required this.enableStars,
    required this.enableGradientSky,
    required this.starColor,
    required this.starIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Background color fill
    canvas.drawColor(backgroundColor, BlendMode.srcOver);

    // Optional gradient nebula sky
    if (enableGradientSky) {
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          backgroundColor,
          backgroundColor.withOpacity(0.9),
          backgroundColor.withOpacity(0.6),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      paint.shader = gradient.createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, paint);
    }

    // Optional stars
    if (enableStars) {
      final starPaint = Paint()
        ..color = starColor
        ..blendMode = BlendMode.plus;
      for (final star in stars) {
        final parallaxY = size.height * (1 - skyDepth * 0.6);
        final dx = star.position.dx * size.width;
        final dy = star.position.dy * parallaxY;
        final twinkle =
            0.5 + 0.5 * sin(time * star.twinkleSpeed + star.twinklePhase);
        starPaint.color =
            starColor.withOpacity(star.brightness * twinkle * starIntensity);
        canvas.drawCircle(Offset(dx, dy), 0.8 + star.brightness * 1.5, starPaint);
      }
    }

    // Draw aurora ribbons
    final path = Path();
    final auroraPaint = Paint()..blendMode = BlendMode.plus;

    for (int i = 0; i < ribbons.length; i++) {
      final ribbon = ribbons[i];
      final colorA = colors[(ribbon.colorIndex + i) % colors.length];
      final colorB = colors[(ribbon.colorIndex + i + 1) % colors.length];

      path.reset();
      final double baseY = ribbon.baseY * size.height;
      final double stepX = size.width / 40;
      final double waveAmp = amplitude * ribbon.thickness;

      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width + stepX; x += stepX) {
        final yOffset = sin(x / (size.width * wavelength) * 2 * pi +
            time * 2 * pi * ribbon.speedFactor +
            ribbon.phase) *
            waveAmp;
        path.lineTo(x, baseY + yOffset);
      }
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
      path.close();

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colorA.withOpacity(0.28 * intensity),
          colorB.withOpacity(0.16 * intensity),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      );

      auroraPaint.shader = gradient.createShader(Offset.zero & size);
      canvas.drawPath(path, auroraPaint);
    }

    // Blur to merge ribbons softly
    canvas.saveLayer(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.screen
        ..imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => true;
}
