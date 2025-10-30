import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Smooth, continuous procedural caustics background.
/// Simulates underwater light rays using additive sinusoidal interference.
class RaysBackground extends StatefulWidget {
  const RaysBackground({
    super.key,
    this.speed = 0.25,
    this.scale = 0.015,
    this.intensity = 2,
    this.blur = 24.0,
    this.color = const Color(0xFF58C1FF),
    this.backgroundColor = Colors.transparent,
    this.child,
  });

  final double speed;
  final double scale;
  final double intensity;
  final double blur;
  final Color color;
  final Color backgroundColor;
  final Widget? child;

  @override
  State<RaysBackground> createState() => _RaysBackgroundState();
}

class _RaysBackgroundState extends State<RaysBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;

  @override
  void initState() {
    super.initState();
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
      painter: _SmoothCausticsPainter(
        time: _time,
        scale: widget.scale,
        intensity: widget.intensity,
        blur: widget.blur,
        color: widget.color,
        backgroundColor: widget.backgroundColor,
      ),
      child: widget.child,
    );
  }
}

class _SmoothCausticsPainter extends CustomPainter {
  final double time;
  final double scale;
  final double intensity;
  final double blur;
  final Color color;
  final Color backgroundColor;

  _SmoothCausticsPainter({
    required this.time,
    required this.scale,
    required this.intensity,
    required this.blur,
    required this.color,
    required this.backgroundColor,
  });

  double _pattern(double x, double y, double t) {
    // Smooth multi-wave interference pattern
    final v = sin(x * 1.2 + t * 1.3) +
        sin(y * 1.5 - t * 0.9) +
        sin((x + y) * 1.1 + t * 1.2) +
        cos((x * 0.7 - y * 1.3) + t * 1.4);
    return (v * 0.25 + 0.5).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    canvas.drawColor(backgroundColor, BlendMode.srcOver);

    // Use an offscreen recorder to composite continuous field
    final recorder = ui.PictureRecorder();
    final offCanvas = Canvas(recorder);
    final path = Path();
    final step = 3.0;

    // Evaluate pattern in a dense grid to avoid "orbs"
    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final nx = x * scale;
        final ny = y * scale;
        final v1 = _pattern(nx, ny, time);
        final v2 = _pattern(nx + 2.1, ny - 1.7, -time * 0.8);
        final brightness = pow(v1 * v2, 1.6).clamp(0.0, 1.0);

        if (brightness > 0.05) {
          paint.color = color.withOpacity(brightness * 0.12 * intensity);
          offCanvas.drawRect(Rect.fromLTWH(x, y, step, step), paint);
        }
      }
    }

    final picture = recorder.endRecording();
    canvas.drawPicture(picture);

    // Final soft blur and smooth blend
    canvas.saveLayer(
      Offset.zero & size,
      Paint()
        ..blendMode = BlendMode.screen
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: blur,
          sigmaY: blur,
        ),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SmoothCausticsPainter oldDelegate) => true;
}
