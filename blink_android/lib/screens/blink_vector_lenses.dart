import 'dart:math' as math;
import 'package:flutter/material.dart';

/// High-resolution vector AR lenses anchored to ML Kit's detected face box.
/// Shapes, color treatments and behavior mirror Blink Web's original lenses,
/// while native capture supplies the tracking information.
class BlinkVectorLens extends CustomPainter {
  const BlinkVectorLens({required this.face, required this.lens});
  final Rect face;
  final String lens;

  Paint _paint(Color color, {double width = 0, bool glow = false}) =>
      Paint()
        ..isAntiAlias = true
        ..color = color
        ..style = width > 0 ? PaintingStyle.stroke : PaintingStyle.fill
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = glow ? const MaskFilter.blur(BlurStyle.normal, .045) : null;

  void _oval(Canvas c, double x, double y, double rx, double ry, Color color) {
    c.drawOval(Rect.fromCenter(
      center: Offset(x, y), width: rx * 2, height: ry * 2), _paint(color));
  }

  void _circle(Canvas c, double x, double y, double r, Color color,
      {bool glow = false}) {
    c.drawCircle(Offset(x, y), r, _paint(color, glow: glow));
  }

  void _poly(Canvas c, List<Offset> points, Color color,
      {Color? stroke, double width = .02}) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    path.close();
    c.drawPath(path, _paint(color));
    if (stroke != null) {
      c.drawPath(path, _paint(stroke, width: width));
    }
  }

  void _line(Canvas c, List<Offset> points, Color color, double width) {
    if (points.isEmpty) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    c.drawPath(path, _paint(color, width: width));
  }

  void _star(Canvas c, double x, double y, double r, Color color,
      {int points = 4}) {
    final vertices = <Offset>[];
    for (var i = 0; i < points * 2; i++) {
      final a = i * math.pi / points - math.pi / 2;
      final radius = i.isEven ? r : r * .26;
      vertices.add(Offset(x + math.cos(a) * radius,
        y + math.sin(a) * radius));
    }
    _poly(c, vertices, color);
  }

  void _heart(Canvas c, double x, double y, double scale, Color color) {
    c.save();
    c.translate(x, y);
    c.scale(scale);
    final path = Path()
      ..moveTo(0, .33)
      ..cubicTo(-.62, -.04, -.60, -.42, -.27, -.43)
      ..cubicTo(-.1, -.43, 0, -.24, 0, -.20)
      ..cubicTo(0, -.24, .1, -.43, .27, -.43)
      ..cubicTo(.60, -.42, .62, -.04, 0, .33)
      ..close();
    c.drawPath(path, _paint(color));
    c.restore();
  }

  void _cheeks(Canvas c) {
    _circle(c, -.29, .20, .13, const Color(0x30FF719D), glow: true);
    _circle(c, .29, .20, .13, const Color(0x30FF719D), glow: true);
    _oval(c, -.29, .20, .11, .045, const Color(0x77FF7C9F));
    _oval(c, .29, .20, .11, .045, const Color(0x77FF7C9F));
  }

  void _cat(Canvas c) {
    for (final side in [-1.0, 1.0]) {
      c.save();
      c.translate(side * .32, -.53);
      c.rotate(side * .14);
      _poly(c, [
        const Offset(-.17, .13), const Offset(-.13, -.28),
        const Offset(.07, -.18), const Offset(.21, .14),
      ], const Color(0xFF30212F),
        stroke: const Color(0xFFFAE9F6), width: .012);
      _poly(c, [
        const Offset(-.08, .05), const Offset(-.07, -.16),
        const Offset(.05, -.10), const Offset(.14, .06),
      ], const Color(0xFFEF98C3));
      c.restore();
    }
    _cheeks(c);
    _poly(c, [const Offset(-.07, .22),const Offset(.07,.22),
      const Offset(0,.31)],const Color(0xFFE7739A));
    _line(c,[const Offset(0,.31), const Offset(0,.38),
      const Offset(-.07,.41)], const Color(0xFF47313B),.018);
    _line(c,[const Offset(0,.38),const Offset(.07,.41)],
      const Color(0xFF47313B),.018);
    for(final side in [-1.0,1.0]) {
      for(var i=0;i<3;i++) {
        _line(c,[Offset(side*.11,.31+i*.044),
          Offset(side*.52,.24+i*.044)],const Color(0xFFF9E2E7),.015);
      }
    }
  }

  void _dog(Canvas c) {
    for(final side in [-1.0,1.0]) {
      c.save();
      c.translate(side*.43,-.50);
      c.rotate(side*.28);
      _oval(c,0,0,.18,.28,const Color(0xFF986446));
      _oval(c,0,.02,.11,.19,const Color(0xFFC78973));
      c.restore();
    }
    _circle(c,0,.29,.16,const Color(0x40FFE8D0),glow:true);
    _oval(c,0,.29,.13,.09,const Color(0xFF33272C));
    _oval(c,-.035,.26,.03,.015,const Color(0xE8FFFFFF));
    _line(c,[const Offset(0,.36),const Offset(0,.43),
      const Offset(-.08,.46)],const Color(0xFF573D3D),.014);
    _line(c,[const Offset(0,.43),const Offset(.08,.46)],
      const Color(0xFF573D3D),.014);
    _poly(c,[const Offset(-.07,.46), const Offset(.07,.46),
      const Offset(.05,.68),const Offset(0,.74),const Offset(-.05,.68)],
      const Color(0xFFED8AA7));
  }

  void _butterfly(Canvas c) {
    for(final side in [-1.0,1.0]) {
      c.save(); c.translate(side*.55,-.02); c.scale(side,1);
      _poly(c,[const Offset(0,0),const Offset(.22,-.50),
        const Offset(.55,-.38),const Offset(.52,-.05),
        const Offset(.22,.13)],const Color(0xAAE77FFF),
        stroke:const Color(0xFFEFC5FF));
      _poly(c,[const Offset(0,.02),const Offset(.30,.07),
        const Offset(.46,.42),const Offset(.19,.43)],
        const Color(0xA67DC3F6),stroke:const Color(0xFFE6F6FF));
      _circle(c,.31,-.23,.08,const Color(0xA8FFFFFF));
      _circle(c,.31,.24,.055,const Color(0xD6FFFFFF));
      c.restore();
    }
    _star(c,0,-.77,.10,const Color(0xFFF9EAA6));
  }

  void _love(Canvas c) {
    _cheeks(c);
    _circle(c,0,-.62,.28,const Color(0x33FF78AF),glow:true);
    _heart(c,-.36,-.52,.39,const Color(0xFFFF6197));
    _heart(c,.30,-.72,.26,const Color(0xFFFF82BD));
    _heart(c,.02,-.90,.30,const Color(0xFFFFB8D3));
    _star(c,-.52,.02,.08,const Color(0xFFFFF1B4));
    _star(c,.49,-.09,.09,const Color(0xFFFFF0CE));
  }

  void _crown(Canvas c) {
    _circle(c,0,-.62,.40,const Color(0x33FFDC8B),glow:true);
    _poly(c,[const Offset(-.50,-.47),const Offset(-.48,-.93),
      const Offset(-.22,-.73),const Offset(0,-1.12),
      const Offset(.22,-.73),const Offset(.48,-.93),
      const Offset(.50,-.47)],const Color(0xFFF4C253),
      stroke:const Color(0xFFFFF1B3));
    _poly(c,[const Offset(-.50,-.53),const Offset(.50,-.53),
      const Offset(.50,-.43),const Offset(-.50,-.43)],
      const Color(0xFFFFDE81),stroke:const Color(0xFFFFF3C7));
    for(final x in [-.32,0.0,.32]) {
      _oval(c,x,-.57,.045,.052,const Color(0xFFC74F73));
    }
    _star(c,-.61,-.39,.08,const Color(0xFFFFE3A3));
    _star(c,.61,-.39,.08,const Color(0xFFFFE3A3));
  }

  void _glasses(Canvas c) {
    _circle(c,0,-.02,.42,const Color(0x33FF77D4),glow:true);
    for(final side in [-1.0,1.0]) {
      _oval(c,side*.25,-.045,.235,.16,const Color(0xAE34183E));
      c.drawOval(Rect.fromCenter(center:Offset(side*.25,-.045),
        width:.47,height:.32),
        _paint(const Color(0xFFFF70D7),width:.044));
      _line(c,[Offset(side*.48,-.045),Offset(side*.65,-.09)],
        const Color(0xFFFF70D7),.04);
    }
    _line(c,[const Offset(-.03,-.05),const Offset(.03,-.05)],
      const Color(0xFFFF70D7),.043);
    _star(c,.42,-.22,.07,const Color(0xFFFFFFFF));
  }

  void _cyber(Canvas c) {
    for(final side in [-1.0,1.0]) {
      _poly(c,[Offset(side*.08,-.12),Offset(side*.35,-.20),
        Offset(side*.53,-.04),Offset(side*.40,.09),
        Offset(side*.13,.06)],const Color(0x5517E8FF),
        stroke:const Color(0xFF20EAFF),width:.035);
      _line(c,[Offset(side*.36,.18),Offset(side*.55,.29),
        Offset(side*.45,.40)],const Color(0xFF11E4F7),.025);
    }
    _line(c,[const Offset(-.06,-.06),const Offset(.06,-.06)],
      const Color(0xFF19E7FF),.034);
    _star(c,0,-.70,.09,const Color(0xFF38F1FC));
    _star(c,.53,.02,.07,const Color(0xFFD55AFF));
  }

  void _party(Canvas c) {
    _poly(c,[const Offset(-.27,-.45),const Offset(.06,-1.20),
      const Offset(.38,-.45)],const Color(0xFFEC5A9C),
      stroke:const Color(0xFFFFDF79));
    _line(c,[const Offset(-.15,-.69),const Offset(.23,-.69)],
      const Color(0xFFFFDA6A),.045);
    _circle(c,.06,-1.22,.10,const Color(0xFFFFEE98));
    for(final point in [
      const Offset(-.61,-.62),const Offset(.57,-.73),
      const Offset(-.52,.28),const Offset(.63,.38),
    ]) {
      _star(c,point.dx,point.dy,.09,const Color(0xFF8BDBFA));
    }
    _heart(c,-.56,-.03,.14,const Color(0xFFFF7EA7));
    _heart(c,.56,-.08,.16,const Color(0xFFFED367));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (face.width <= 0 || face.height <= 0 || lens == 'none') return;
    final box = Rect.fromLTRB(face.left*size.width,face.top*size.height,
      face.right*size.width,face.bottom*size.height);
    if (box.width < 8 || box.height < 8) return;
    canvas.save();
    canvas.translate(box.center.dx,box.center.dy);
    canvas.scale(box.width*.93);
    switch (lens) {
      case 'cat': _cat(canvas); break;
      case 'dog': _dog(canvas); break;
      case 'butterfly': _butterfly(canvas); break;
      case 'heart': _love(canvas); break;
      case 'crown': _crown(canvas); break;
      case 'glasses': _glasses(canvas); break;
      case 'cyber': _cyber(canvas); break;
      case 'blush': _cheeks(canvas); break;
      case 'party': _party(canvas); break;
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BlinkVectorLens oldDelegate) =>
      face != oldDelegate.face || lens != oldDelegate.lens;
}
