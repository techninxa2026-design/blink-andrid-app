import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A shower of small, vivid red Blink hearts:
/// 1. Pop outward from the exact double-tap position.
/// 2. Follow distinct curved paths into the Like button.
/// 3. Shrink and fade as they arrive, revealing the selected ❤️ reaction.
///
/// This is painted in one layer rather than building dozens of animated
/// widgets. It never intercepts taps, swipes or the action buttons.
class BlinkHeartFlight extends StatelessWidget {
  const BlinkHeartFlight({
    super.key,
    required this.progress,
    required this.origin,
    required this.destination,
  });

  final Animation<double> progress;
  final Offset origin;
  final Offset destination;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: CustomPaint(
      key: const ValueKey('blink-moment-heart-flight'),
      painter: _HeartFlightPainter(
        progress: progress,
        origin: origin,
        destination: destination,
      ),
      child: const SizedBox.expand(),
    ),
  );
}

class _HeartFlightPainter extends CustomPainter {
  _HeartFlightPainter({
    required this.progress,
    required this.origin,
    required this.destination,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Offset origin;
  final Offset destination;

  static const colors = [
    Color(0xFFF51D48),
    Color(0xFFFB3153),
    Color(0xFFE70034),
    Color(0xFFFF4966),
    Color(0xFFFF193E),
    Color(0xFFEA1744),
  ];

  double _easeOut(double value) {
    final t = value.clamp(0.0, 1.0).toDouble();
    return 1 - math.pow(1 - t, 3).toDouble();
  }

  double _easeInOut(double value) {
    final t = value.clamp(0.0, 1.0).toDouble();
    return t * t * (3 - 2 * t);
  }

  Offset _quadratic(Offset a, Offset control, Offset b, double t) {
    final reverse = 1.0 - t;
    return a * (reverse * reverse) +
      control * (2 * reverse * t) +
      b * (t * t);
  }

  Path _heart(double size) {
    // Normalized heart outline with an unmistakable pointed lower tip.
    final p = Path();
    p.moveTo(0, size * .33);
    p.cubicTo(-size * .54, -size * .27,
      -size * 1.04, size * .35, 0, size);
    p.cubicTo(size * 1.04, size * .35,
      size * .54, -size * .27, 0, size * .33);
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress.value.clamp(0.0, 1.0).toDouble();
    if (t <= 0 || t >= 1) return;

    final validTarget = destination.dx.isFinite && destination.dy.isFinite;
    final goal = validTarget
      ? destination
      : Offset(size.width - 48, size.height * .45);

    const hearts = 20;
    for (var i = 0; i < hearts; i++) {
      // Slight delay staggers the trail of hearts so they don't move as one.
      final delay = (i % 5) * .036;
      final local = ((t - delay) / (1 - delay))
        .clamp(0.0, 1.0).toDouble();
      if (local <= 0 || local >= 1) continue;

      final angle = (math.pi * 2 * i / hearts) + .17;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      final distance = 28.0 + (i % 5) * 12.5;
      final burstEnd = origin +
        Offset(dx * distance, dy * distance * .85);
      final burst = _easeOut((local / .26).clamp(0.0, 1.0).toDouble());
      final flight = _easeInOut(
        ((local - .23) / .74).clamp(0.0, 1.0).toDouble());

      final curvedControl = Offset(
        (burstEnd.dx + goal.dx) / 2 + dx * 80,
        math.min(burstEnd.dy, goal.dy) - 94 - (i % 4) * 17,
      );
      final landing = goal + Offset(
        (i % 3 - 1) * 5.0,
        (i % 4 - 2) * 4.0,
      );
      final start = Offset.lerp(origin, burstEnd, burst)!;
      final at = local < .23
        ? start
        : _quadratic(burstEnd, curvedControl, landing, flight);

      final baseSize = 9.0 + (i % 5) * 3.1;
      final scale = local < .23 ? .42 + burst * .7
        : (1 - flight * .65);
      final opacity = local < .12
        ? (local / .12).clamp(0.0, 1.0).toDouble()
        : (1 - math.pow(flight, 2.7).toDouble() * .98)
          .clamp(0.0, 1.0).toDouble();
      if (opacity <= .02) continue;

      final paint = Paint()
        ..color = colors[i % colors.length].withValues(alpha: opacity)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;

      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.rotate(dx * .18 + flight * .26);
      canvas.scale(scale, scale);
      canvas.drawShadow(_heart(baseSize), const Color(0x77000000), 4, false);
      canvas.drawPath(_heart(baseSize), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _HeartFlightPainter oldDelegate) =>
      oldDelegate.origin != origin ||
      oldDelegate.destination != destination ||
      oldDelegate.progress != progress;
}
