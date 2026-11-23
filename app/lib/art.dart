import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Small colourful illustrations (Uber-style: black-and-white UI, colourful pictures).
/// Each painter draws in a 100 x 100 design space scaled to its box.
enum Art { bus, seat, stopwatch, route, flame, clock, sunrise }

class ArtView extends StatelessWidget {
  const ArtView(this.art, {super.key, this.size = 44, this.aspect = 1});
  final Art art;
  final double size, aspect;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size * aspect, height: size, child: CustomPaint(painter: _ArtPainter(art)));
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art);
  final Art art;

  static Paint _f(Color c) => Paint()..color = c;
  static Paint _s(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static RRect _rr(double l, double t, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r));

  @override
  void paint(Canvas c, Size size) {
    c.scale(size.width / 100, size.height / 100);
    switch (art) {
      case Art.bus:
        _bus(c);
      case Art.seat:
        _seat(c);
      case Art.stopwatch:
        _stopwatch(c);
      case Art.route:
        _route(c);
      case Art.flame:
        _flame(c);
      case Art.clock:
        _clock(c);
      case Art.sunrise:
        _sunrise(c);
    }
  }

  void _bus(Canvas c) {
    c.drawOval(Rect.fromCenter(center: const Offset(50, 84), width: 88, height: 8), _f(const Color(0x22000000)));
    c.drawRRect(_rr(14, 24, 60, 7, 3), _f(const Color(0xFFB22A1F)));
    c.drawRRect(_rr(6, 28, 88, 48, 9), _f(const Color(0xFFD7392B)));
    for (var i = 0; i < 4; i++) {
      c.drawRRect(_rr(12 + i * 16.0, 36, 13, 15, 2.5), _f(const Color(0xFFCFEFFF)));
    }
    c.drawRRect(_rr(78, 36, 11, 22, 3), _f(const Color(0xFFCFEFFF)));
    c.drawRect(const Rect.fromLTWH(6, 58, 70, 4), _f(const Color(0xCCFFFFFF)));
    c.drawRRect(_rr(78, 30, 11, 4, 1.5), _f(const Color(0xFFFFC043)));
    c.drawRRect(_rr(89, 62, 4, 6, 1.5), _f(const Color(0xFFFFE08A)));
    for (final x in [26.0, 72.0]) {
      c.drawCircle(Offset(x, 76), 9, _f(const Color(0xFF222222)));
      c.drawCircle(Offset(x, 76), 3.8, _f(const Color(0xFFBDBDBD)));
    }
  }

  void _seat(Canvas c) {
    c.drawRRect(_rr(30, 12, 40, 46, 11), _f(const Color(0xFFF2994A)));
    c.drawRRect(_rr(36, 18, 28, 32, 7), _f(const Color(0xFFF7B26F)));
    c.drawRRect(_rr(22, 54, 56, 17, 8), _f(const Color(0xFFE07B2C)));
    c.drawRect(const Rect.fromLTWH(32, 70, 6, 15), _f(const Color(0xFF555555)));
    c.drawRect(const Rect.fromLTWH(62, 70, 6, 15), _f(const Color(0xFF555555)));
    c.drawRRect(_rr(26, 84, 48, 5, 2.5), _f(const Color(0xFF3A3A3A)));
    c.drawCircle(const Offset(76, 22), 13, _f(const Color(0xFF06C167)));
    c.drawPath(Path()..moveTo(69.5, 22)..lineTo(74, 26.5)..lineTo(82.5, 17), _s(Colors.white, 4));
  }

  void _stopwatch(Canvas c) {
    c.drawRRect(_rr(43, 12, 14, 9, 2.5), _f(const Color(0xFF222222)));
    c.drawCircle(const Offset(48, 56), 31, _f(Colors.white));
    c.drawCircle(const Offset(48, 56), 31, _s(const Color(0xFF222222), 6));
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      c.drawLine(Offset(48 + 22 * math.cos(a), 56 + 22 * math.sin(a)), Offset(48 + 25 * math.cos(a), 56 + 25 * math.sin(a)),
          _s(const Color(0xFFBDBDBD), 2));
    }
    c.drawLine(const Offset(48, 56), const Offset(60, 40), _s(const Color(0xFFE11900), 5));
    c.drawCircle(const Offset(48, 56), 4, _f(const Color(0xFF222222)));
    c.drawPath(
        Path()
          ..moveTo(82, 6)
          ..lineTo(70, 28)
          ..lineTo(78, 28)
          ..lineTo(71, 46)
          ..lineTo(90, 20)
          ..lineTo(81, 20)
          ..lineTo(88, 6)
          ..close(),
        _f(const Color(0xFFFFC043)));
  }

  void _route(Canvas c) {
    c.drawRRect(_rr(8, 12, 84, 76, 12), _f(const Color(0xFFBFEBCB)));
    final road = _s(Colors.white, 7);
    c.drawLine(const Offset(8, 44), const Offset(92, 44), road);
    c.drawLine(const Offset(42, 12), const Offset(42, 88), road);
    c.drawLine(const Offset(8, 74), const Offset(60, 74), road);
    final p = Path()
      ..moveTo(22, 74)
      ..lineTo(42, 74)
      ..lineTo(42, 44)
      ..lineTo(72, 44)
      ..lineTo(72, 36);
    c.drawPath(p, _s(const Color(0xFF222222), 4));
    c.drawCircle(const Offset(22, 74), 6, _f(const Color(0xFF222222)));
    c.drawCircle(const Offset(22, 74), 2.5, _f(Colors.white));
    final pin = Path()
      ..moveTo(72, 38)
      ..cubicTo(64, 28, 61, 22, 61, 18)
      ..arcToPoint(const Offset(83, 18), radius: const Radius.circular(11))
      ..cubicTo(83, 22, 80, 28, 72, 38)
      ..close();
    c.drawPath(pin, _f(const Color(0xFFE11900)));
    c.drawCircle(const Offset(72, 18), 4, _f(Colors.white));
  }

  void _flame(Canvas c) {
    final outer = Path()
      ..moveTo(50, 8)
      ..cubicTo(70, 30, 84, 48, 78, 68)
      ..cubicTo(74, 84, 60, 92, 50, 92)
      ..cubicTo(38, 92, 22, 84, 20, 66)
      ..cubicTo(18, 52, 28, 42, 35, 32)
      ..cubicTo(37, 44, 43, 50, 48, 50)
      ..cubicTo(43, 36, 43, 22, 50, 8)
      ..close();
    c.drawPath(outer, _f(const Color(0xFFFF5A1F)));
    final inner = Path()
      ..moveTo(51, 50)
      ..cubicTo(61, 60, 66, 70, 62, 80)
      ..cubicTo(60, 86, 55, 89, 50, 89)
      ..cubicTo(43, 89, 37, 84, 37, 76)
      ..cubicTo(37, 67, 44, 62, 51, 50)
      ..close();
    c.drawPath(inner, _f(const Color(0xFFFFC043)));
  }

  void _clock(Canvas c) {
    c.drawCircle(const Offset(46, 54), 34, _f(Colors.white));
    c.drawCircle(const Offset(46, 54), 34, _s(const Color(0xFF222222), 6));
    c.drawLine(const Offset(46, 54), const Offset(46, 32), _s(const Color(0xFF222222), 5));
    c.drawLine(const Offset(46, 54), const Offset(62, 62), _s(const Color(0xFF2B7BE4), 5));
    c.drawCircle(const Offset(46, 54), 4, _f(const Color(0xFF222222)));
    c.drawCircle(const Offset(80, 20), 15, _f(const Color(0xFF06C167)));
    c.drawLine(const Offset(80, 13), const Offset(80, 27), _s(Colors.white, 4));
    c.drawLine(const Offset(73, 20), const Offset(87, 20), _s(Colors.white, 4));
  }

  void _sunrise(Canvas c) {
    c.drawCircle(const Offset(70, 52), 24, _f(const Color(0xFFFF9F1C)));
    for (var i = 0; i < 7; i++) {
      final a = math.pi + i * math.pi / 6;
      c.drawLine(Offset(70 + 30 * math.cos(a), 52 + 30 * math.sin(a)), Offset(70 + 38 * math.cos(a), 52 + 38 * math.sin(a)),
          _s(const Color(0xFFFF9F1C), 3.5));
    }
    c.drawRect(const Rect.fromLTWH(0, 52, 100, 48), _f(const Color(0xFF9AD8A8)));
    c.drawPath(
        Path()
          ..moveTo(0, 62)
          ..quadraticBezierTo(30, 50, 60, 60)
          ..quadraticBezierTo(80, 66, 100, 58)
          ..lineTo(100, 100)
          ..lineTo(0, 100)
          ..close(),
        _f(const Color(0xFF6CC283)));
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) => old.art != art;
}

/// Shrinks a little while pressed, like Uber's tiles.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.95 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      );
}
