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
    this.intensity = 2.8,
    this.waveAmplitude = 120.0,
    this.waveLength = 1.2,
    this.backgroundColor = Colors.transparent,
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
    this.backgroundBrightness,
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
  final Brightness? backgroundBrightness;

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
        backgroundBrightness: widget.backgroundBrightness, // NEW
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
  final Brightness? backgroundBrightness; // NEW
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
    this.backgroundBrightness, // NEW
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Fill background (if non-transparent)
    if (backgroundColor.opacity > 0) {
      canvas.drawColor(backgroundColor, BlendMode.srcOver);
    }

    // Decide luminance mode
    final isDark = _decideIsDark();

    // Optional nebula wash
    if (enableGradientSky) {
      final wash = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
          backgroundColor.withOpacity(1.0),
          backgroundColor.withOpacity(0.85),
          backgroundColor.withOpacity(0.6),
        ]
            : [
          backgroundColor.withOpacity(1.0),
          backgroundColor.withOpacity(0.95),
          backgroundColor.withOpacity(0.9),
        ],
        stops: const [0.0, 0.5, 1.0],
      );
      paint.shader = wash.createShader(Offset.zero & size);
      canvas.drawRect(Offset.zero & size, paint);
      paint.shader = null;
    }

    // Stars
    if (enableStars) {
      final starPaint = Paint()
        ..color = starColor
        ..blendMode = isDark ? BlendMode.plus : BlendMode.srcOver;
      for (final star in stars) {
        final parallaxY = size.height * (1 - skyDepth * 0.6);
        final dx = star.position.dx * size.width;
        final dy = star.position.dy * parallaxY;
        final twinkle =
            0.5 + 0.5 * sin(time * star.twinkleSpeed + star.twinklePhase);
        final alpha = (star.brightness * twinkle * starIntensity)
            .clamp(0.0, 1.0);
        starPaint.color = starColor.withOpacity(
          isDark ? alpha : alpha * 0.6, // tone stars down on light BGs
        );
        canvas.drawCircle(Offset(dx, dy), 0.8 + star.brightness * 1.5, starPaint);
      }
    }

    // Ribbons
    final path = Path();
    final auroraPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..blendMode = isDark ? BlendMode.plus : BlendMode.multiply; // ADAPTIVE

    for (int i = 0; i < ribbons.length; i++) {
      final ribbon = ribbons[i];
      final colorA = colors[(ribbon.colorIndex + i) % colors.length];
      final colorB = colors[(ribbon.colorIndex + i + 1) % colors.length];

      path.reset();
      final baseY = ribbon.baseY * size.height;
      final stepX = size.width / 40.0;
      final waveAmp = amplitude * ribbon.thickness;

      path.moveTo(0, baseY);
      for (double x = 0; x <= size.width + stepX; x += stepX) {
        final yOffset = sin(
          x / (size.width * wavelength) * 2 * pi +
              time * 2 * pi * ribbon.speedFactor +
              ribbon.phase,
        ) *
            waveAmp;
        path.lineTo(x, baseY + yOffset);
      }
      path
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();

      // ADAPT the gradient’s brightness/opacity for light backgrounds
      final double aTop = (isDark ? 0.28 : 0.35) * intensity;
      final double aMid = (isDark ? 0.16 : 0.28) * intensity;

      final hsvA = HSVColor.fromColor(colorA);
      final hsvB = HSVColor.fromColor(colorB);

      final Color adjA = (isDark
          ? hsvA
          : hsvA.withValue((hsvA.value * 0.75).clamp(0.0, 1.0)))
          .toColor()
          .withOpacity(aTop);
      final Color adjB = (isDark
          ? hsvB
          : hsvB.withValue((hsvB.value * 0.75).clamp(0.0, 1.0)))
          .toColor()
          .withOpacity(aMid);

      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          adjA,
          adjB,
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      );

      auroraPaint.shader = gradient.createShader(Offset.zero & size);
      canvas.drawPath(path, auroraPaint);
    }

    // BLUR pass – strong on dark, minimal on light to avoid washout
    final blurSigma = isDark ? blur : (blur * 0.25);
    final layerBlend = isDark ? BlendMode.screen : BlendMode.srcOver;

    if (blurSigma > 0.5) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()
          ..blendMode = layerBlend
          ..imageFilter = ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
      );
      canvas.restore();
    }
  }

  bool _decideIsDark() {
    if (backgroundBrightness != null) {
      return backgroundBrightness == Brightness.dark;
    }
    // Infer from backgroundColor if it has visible alpha; otherwise assume light.
    final hasBg = backgroundColor.opacity > 0.01;
    final luma = 0.2126 * (backgroundColor.red / 255.0) +
        0.7152 * (backgroundColor.green / 255.0) +
        0.0722 * (backgroundColor.blue / 255.0);
    return hasBg ? (luma < 0.45) : false; // transparent -> default to light
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => true;
}
