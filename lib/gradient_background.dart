import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Smoothly animated gradient background that shifts colors and motion over time.
class GradientBackground extends StatefulWidget {
  final List<Color> colors;
  final double speed;         // Controls how fast the gradient moves.
  final double hueShiftSpeed; // Controls how fast hues change.
  final Widget? child;
  final List<double>? stops;

  const GradientBackground({
    super.key,
    this.colors = const [
      Color(0xFF2196F3),
      Color(0xFF9C27B0),
      Color(0xFFFF4081),
      Color(0xFF00BCD4),
    ],
    this.speed = 1,
    this.hueShiftSpeed = 0.02,
    this.stops,
    this.child,
  });

  @override
  State<GradientBackground> createState() =>
      _GradientBackgroundState();
}

class _GradientBackgroundState
    extends State<GradientBackground> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  double _t = 0.0;

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
    final animatedColors = _shiftColors(widget.colors, _t, widget.hueShiftSpeed);

    return CustomPaint(
      painter: _GradientPainter(
        time: _t,
        colors: animatedColors,
        stops: widget.stops
      ),
      size: size,
      child: widget.child,
    );
  }

  List<Color> _shiftColors(List<Color> baseColors, double t, double speed) {
    return baseColors.map((c) {
      final hsv = HSVColor.fromColor(c);
      final hueShift = (hsv.hue + sin(t * 360 * speed) * 20) % 360;
      return hsv.withHue(hueShift).toColor();
    }).toList();
  }
}

class _GradientPainter extends CustomPainter {
  final List<double>? stops;
  final double time;
  final List<Color> colors;

  _GradientPainter({required this.time, required this.colors, this.stops});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;

    // Create gentle drifting movement
    final offsetX = sin(time * 0.3) * size.width * 0.2;
    final offsetY = cos(time * 0.25) * size.height * 0.2;
    final rotation = time * 0.1; // slow rotation

    final center = Offset(size.width / 2 + offsetX, size.height / 2 + offsetY);

    // Interpolated colors for smooth blending
    final gradient = LinearGradient(
      colors: colors,
      transform: GradientRotation(rotation),
      stops: stops,
    );

    paint.shader = gradient.createShader(Rect.fromCircle(center: center, radius: size.longestSide));

    // Paint large gradient circle filling the screen
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientPainter oldDelegate) => true;
}
