import 'dart:math';
import 'dart:ui' as ui;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Material 3–inspired animated ribbon background.
///
/// Features:
/// - Multiple horizontal ribbons with sine-based flow
/// - Elevation: shadow + surface tint (M3-style)
/// - Translucency and optional backdrop blur
/// - Adaptive blending for light/dark backgrounds
/// - Animated gradients (hue drift)
/// - 3D parallax (drag/touch)
class RibbonBackground extends StatefulWidget {
  const RibbonBackground({
    super.key,
    this.backgroundColor = Colors.transparent,
    this.ribbonSpecs,
    this.ribbonCount = 3,
    this.baseAmplitude = 56.0,
    this.speed = 0.5,
    this.parallaxDepth = 0.22,
    this.colorShiftSpeed = 0.08,
    this.enableBackdropBlur = true,
    this.backdropBlurSigma = 8.0,
    this.child,
    this.primaryForTint, // if null: inferred from first ribbon color
  });

  /// Page background behind ribbons.
  final Color backgroundColor;

  /// Optional explicit ribbon specs; if null, defaults are generated from palette.
  final List<RibbonSpec>? ribbonSpecs;

  /// How many ribbons to auto-generate if [ribbonSpecs] is null.
  final int ribbonCount;

  /// Baseline vertical wave amplitude.
  final double baseAmplitude;

  /// Global time speed for animation.
  final double speed;

  /// Parallax amount (0..1).
  final double parallaxDepth;

  /// Speed of animated hue shift in gradients.
  final double colorShiftSpeed;

  /// Adds a real backdrop blur behind ribbons (Material translucency feel).
  final bool enableBackdropBlur;
  final double backdropBlurSigma;

  /// Source color for surface tint at elevation. If null, taken from first ribbon's gradient.
  final Color? primaryForTint;

  /// Optional foreground child.
  final Widget? child;

  @override
  State<RibbonBackground> createState() => _RibbonBackgroundState();
}

/// Per-ribbon configuration.
class RibbonSpec {
  RibbonSpec({
    required this.gradient,
    this.baseY = 0.2,         // normalized 0..1 of height
    this.thickness = 1.0,     // scales amplitude
    this.speedFactor = 1.0,   // local speed multiplier
    this.elevation = 6.0,     // dp (shadow + tint intensity)
    this.opacity = 0.75,      // translucency
  });

  final List<Color> gradient;
  final double baseY;
  final double thickness;
  final double speedFactor;
  final double elevation;
  final double opacity;
}

class _RibbonBackgroundState extends State<RibbonBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0.0;
  Offset _pointer = Offset.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      _t += widget.speed * 0.001;
      setState(() {});
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    final content = CustomPaint(
      painter: _M3RibbonPainter(
        t: _t,
        backgroundColor: widget.backgroundColor,
        specs: _specs(size),
        baseAmplitude: widget.baseAmplitude,
        parallaxDepth: widget.parallaxDepth,
        colorShiftSpeed: widget.colorShiftSpeed,
        pointerOffset: _pointer,
        primaryForTint: widget.primaryForTint,
      ),
      size: size,
      child: widget.child,
    );

    if (!widget.enableBackdropBlur) {
      return GestureDetector(
        onPanUpdate: (d) => setState(() => _pointer += d.delta * 0.1),
        onPanEnd: (_) => setState(() => _pointer = Offset.zero),
        child: content,
      );
    }

    // Backdrop blur to simulate translucent Material surfaces over content behind
    return GestureDetector(
      onPanUpdate: (d) => setState(() => _pointer += d.delta * 0.1),
      onPanEnd: (_) => setState(() => _pointer = Offset.zero),
      child: ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: widget.backdropBlurSigma,
            sigmaY: widget.backdropBlurSigma,
          ),
          child: content,
        ),
      ),
    );
  }

  List<RibbonSpec> _specs(Size size) {
    if (widget.ribbonSpecs != null && widget.ribbonSpecs!.isNotEmpty) {
      return widget.ribbonSpecs!;
    }
    // Auto-generate pleasing defaults: cool-to-warm sweep with varied elevation.
    final defaults = <List<Color>>[
      [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
      [const Color(0xFF6A1B9A), const Color(0xFFAB47BC)],
      [const Color(0xFF00897B), const Color(0xFF26A69A)],
      [const Color(0xFFEF6C00), const Color(0xFFFFA726)],
      [const Color(0xFF8E24AA), const Color(0xFFE040FB)],
    ];
    final count = widget.ribbonCount.clamp(1, defaults.length);
    return List.generate(count, (i) {
      final y = 0.18 + i * 0.14;
      final elev = [1.0, 3.0, 6.0, 8.0, 12.0][i % 5];
      return RibbonSpec(
        gradient: defaults[i % defaults.length],
        baseY: y,
        thickness: lerpDouble(0.8, 1.3, i / max(1, count - 1))!,
        speedFactor: 0.8 + i * 0.12,
        elevation: elev,
        opacity: 0.70 - i * 0.05, // deeper ribbons a bit more translucent
      );
    });
  }
}

class _M3RibbonPainter extends CustomPainter {
  final double t;
  final Color backgroundColor;
  final List<RibbonSpec> specs;
  final double baseAmplitude;
  final double parallaxDepth;
  final double colorShiftSpeed;
  final Offset pointerOffset;
  final Color? primaryForTint;

  _M3RibbonPainter({
    required this.t,
    required this.backgroundColor,
    required this.specs,
    required this.baseAmplitude,
    required this.parallaxDepth,
    required this.colorShiftSpeed,
    required this.pointerOffset,
    required this.primaryForTint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);

    final luminance = _luma(backgroundColor);
    final isDark = luminance < 0.45;

    // Blend: screen on dark, multiply on bright
    final blendMode = isDark ? BlendMode.screen : BlendMode.multiply;

    // Global color correction
    final brightnessScale = isDark ? 1.0 : 0.8;
    final opacityScale = isDark ? 1.0 : 1.25;

    canvas.saveLayer(
      Offset.zero & size,
      Paint()..blendMode = BlendMode.srcOver,
    );

    for (int i = 0; i < specs.length; i++) {
      _drawRibbon(
        canvas,
        size,
        specs[i],
        i,
        blendMode: blendMode,
        isDark: isDark,
        brightnessScale: brightnessScale,
        opacityScale: opacityScale,
      );
    }

    canvas.restore();
  }

  void _drawRibbon(
      Canvas canvas,
      Size size,
      RibbonSpec spec,
      int i, {
        required BlendMode blendMode,
        required bool isDark,
        required double brightnessScale,
        required double opacityScale,
      }) {
    final waveAmp = baseAmplitude * spec.thickness;
    final waveLen = size.width * (0.55 + i * 0.04);
    final baseY = size.height * spec.baseY;

    final pox = pointerOffset.dx * (i * parallaxDepth * 0.45);
    final poy = pointerOffset.dy * (i * parallaxDepth * 0.65);

    final path = Path()..moveTo(0, baseY + poy);
    const steps = 44;
    final dx = size.width / steps;
    for (int k = 0; k <= steps; k++) {
      final x = k * dx + pox;
      final phase = t * spec.speedFactor + i * 0.35;
      final y = baseY +
          sin((x / waveLen + phase) * 2 * pi) * waveAmp * 0.55 +
          cos((x / waveLen + phase * 1.35) * pi) * waveAmp * 0.22 +
          poy;
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    // Animate hue
    final animatedColors = spec.gradient.map((c) {
      final hsv = HSVColor.fromColor(c);
      final hueShift = (hsv.hue + sin(t * 360 * colorShiftSpeed + i * 50) * 18) % 360;
      var shifted = hsv.withHue(hueShift);
      if (!isDark) {
        // darken slightly for light backgrounds
        shifted = shifted.withValue(hsv.value * brightnessScale);
      }
      return shifted.toColor().withOpacity(spec.opacity * opacityScale);
    }).toList();

    // Fill paint
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true
      ..blendMode = blendMode
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: animatedColors,
      ).createShader(Offset.zero & size);

    // Shadow adaptation
    final shadowColor = isDark
        ? Colors.black.withOpacity(_elevationAmbientAlpha(spec.elevation))
        : Colors.black.withOpacity(0.05);

    final shadowBlur = isDark ? 20.0 : 6.0;

    final shadowPaint = Paint()
      ..color = shadowColor
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadowBlur);

    canvas.save();
    canvas.translate(0, 3.0 + i * 0.5);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Draw ribbon
    canvas.drawPath(path, fillPaint);
  }


  // --- Material 3 helpers ---

  // Very small algo approximations to M3 elevation visuals.
  double _surfaceTintOpacity(double elevation) {
    // Approximated from Material 3 overlay alpha ramp.
    if (elevation <= 0) return 0;
    if (elevation < 1) return 0.05;
    if (elevation < 3) return 0.08;
    if (elevation < 6) return 0.11;
    if (elevation < 8) return 0.12;
    if (elevation < 12) return 0.14;
    return 0.16;
  }

  Color _surfaceTintColorAtElevation(Color primary, double elevation) {
    // Slightly desaturate and lighten the primary with elevation.
    final hsv = HSVColor.fromColor(primary);
    final v = (hsv.value + (0.04 + elevation * 0.007)).clamp(0.0, 1.0);
    final s = (hsv.saturation * (1 - min(0.25, elevation * 0.03))).clamp(0.0, 1.0);
    return hsv.withSaturation(s).withValue(v).toColor();
  }

  double _elevationAmbientAlpha(double elevation) {
    // Broad, low alpha; increases slowly with elevation.
    return (0.04 + elevation * 0.008).clamp(0.04, 0.16);
  }

  double _elevationKeyAlpha(double elevation) {
    // Tighter, slightly stronger near lower elevations.
    return (0.03 + elevation * 0.004).clamp(0.03, 0.12);
  }

  double _luma(Color c) =>
      0.2126 * (c.red / 255.0) + 0.7152 * (c.green / 255.0) + 0.0722 * (c.blue / 255.0);

  @override
  bool shouldRepaint(covariant _M3RibbonPainter oldDelegate) => true;
}
