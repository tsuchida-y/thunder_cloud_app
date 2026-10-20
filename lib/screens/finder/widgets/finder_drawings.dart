import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/sky_geometry.dart';

/// 角度の差（-180〜180）。正なら右回り
double angleDiff(double from, double to) {
  final d = (to - from) % 360;
  return d > 180 ? d - 360 : (d < -180 ? d + 360 : d);
}

/// 雲の形（SVG の "M250 42 h40 a12 12 0 0 0 0-24 a17 17 0 0 0-32-4 a12 12 0 0 0-8 28z" を左下 (0,0) にしたもの）
Path _cloudPath(double scale) => Path()
  ..moveTo(0, 0)
  ..relativeLineTo(40 * scale, 0)
  ..relativeArcToPoint(Offset(0, -24 * scale), radius: Radius.circular(12 * scale), clockwise: false)
  ..relativeArcToPoint(Offset(-32 * scale, -4 * scale), radius: Radius.circular(17 * scale), clockwise: false)
  ..relativeArcToPoint(Offset(-8 * scale, 28 * scale), radius: Radius.circular(12 * scale), clockwise: false)
  ..close();

void _sparkle(Canvas canvas, Offset at, double size, Paint paint) {
  final s = size / 8;
  final path = Path()
    ..moveTo(at.dx, at.dy)
    ..relativeLineTo(2 * s, 6 * s)
    ..relativeLineTo(6 * s, 2 * s)
    ..relativeLineTo(-6 * s, 2 * s)
    ..relativeLineTo(-2 * s, 6 * s)
    ..relativeLineTo(-2 * s, -6 * s)
    ..relativeLineTo(-6 * s, -2 * s)
    ..relativeLineTo(6 * s, -2 * s)
    ..close();
  canvas.drawPath(path, paint);
}

TextPainter _text(String text, TextStyle style) =>
    TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();

/// 方位テープ（Finder.html の上の帯）。真ん中がいま向いている方角、雲の方角に雲の印
class HeadingTape extends StatelessWidget {
  final double headingDeg;
  final double targetDeg;

  const HeadingTape({super.key, required this.headingDeg, required this.targetDeg});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '方位テープ。いまは${SkyGeometry.directionName(headingDeg)}を向いていて、'
          '入道雲は${SkyGeometry.directionName(targetDeg)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: SizedBox(
            height: 58,
            width: double.infinity,
            child: CustomPaint(
              painter: _TapePainter(
                headingDeg: headingDeg,
                targetDeg: targetDeg,
                nameStyle: AppTextStyles.body(color: Colors.white).copyWith(fontSize: 13, fontWeight: FontWeight.w700, height: 1),
                numberStyle: AppTextStyles.number(fontSize: 11, color: Colors.white.withValues(alpha: 0.85)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TapePainter extends CustomPainter {
  final double headingDeg;
  final double targetDeg;
  final TextStyle nameStyle;
  final TextStyle numberStyle;

  _TapePainter({required this.headingDeg, required this.targetDeg, required this.nameStyle, required this.numberStyle});

  /// 1° あたりの幅（デザインでは 50° が 200px）
  static const double pxPerDeg = 4;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final cx = size.width / 2;
    final halfSpan = cx / pxPerDeg + 10;
    double xOf(double deg) => cx + angleDiff(headingDeg, deg) * pxPerDeg;
    final targetX = xOf(targetDeg);
    final targetVisible = angleDiff(headingDeg, targetDeg).abs() <= halfSpan;
    // 雲の印（見えない所にあるときは端に寄せる）
    final markX = targetX.clamp(14.0, size.width - 14);

    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final strongTick = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final start = ((headingDeg - halfSpan) / 5).floor() * 5;
    for (var d = start; d <= headingDeg + halfSpan; d += 5) {
      final deg = (d % 360 + 360) % 360;
      final x = xOf(deg.toDouble());
      final isName = deg % 45 == 0;
      if (isName) {
        canvas.drawLine(Offset(x, 18), Offset(x, 30), strongTick);
      } else if (deg % 10 == 0) {
        canvas.drawLine(Offset(x, 22), Offset(x, 30), tick);
      } else {
        continue;
      }
      // 雲の印と重なる文字は出さない
      if ((x - markX).abs() < 28) continue;
      final label = isName
          ? _text(SkyGeometry.directionName(deg.toDouble()), nameStyle)
          : (deg % 30 == 0 ? _text('$deg°', numberStyle) : null);
      label?.paint(canvas, Offset(x - label.width / 2, 48 - label.height + 2));
    }

    canvas.drawCircle(Offset(markX, 14), 13, Paint()..color = const Color(0xFFBFE3FF).withValues(alpha: 0.5));
    canvas.save();
    canvas.translate(markX - 7, 19);
    canvas.drawPath(_cloudPath(0.35), Paint()..color = Colors.white);
    canvas.restore();
    if (targetVisible) {
      final name = _text(SkyGeometry.directionName(targetDeg), nameStyle);
      name.paint(canvas, Offset(markX - name.width / 2, 48 - name.height + 2));
    }

    // いま向いている所の印
    final pointer = Path()
      ..moveTo(cx, 2)
      ..lineTo(cx - 6, 12)
      ..lineTo(cx + 6, 12)
      ..close();
    canvas.drawPath(pointer, Paint()..color = Colors.white);
    canvas.drawLine(
      Offset(cx, 12),
      Offset(cx, 34),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_TapePainter old) => old.headingDeg != headingDeg || old.targetDeg != targetDeg;
}

/// 「右へ 35°」の矢印（Finder.html、210×210）
class TurnDial extends StatelessWidget {
  /// 回る角度（-180〜180、正なら右）
  final double diffDeg;

  const TurnDial({super.key, required this.diffDeg});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: const Size.square(210), painter: _TurnDialPainter(diffDeg)),
    );
  }
}

class _TurnDialPainter extends CustomPainter {
  final double diffDeg;

  _TurnDialPainter(this.diffDeg);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 210);
    const c = Offset(105, 105);
    canvas.drawCircle(c, 98, Paint()..color = Colors.white.withValues(alpha: 0.14));
    canvas.drawCircle(
      c,
      98,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.6),
    );
    // 上（正面）から雲の方角までの弧
    final sweep = diffDeg * math.pi / 180;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: 98),
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = Colors.white,
    );

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(sweep);
    canvas.translate(-c.dx, -c.dy);
    final arrow = Path()
      ..moveTo(105, 30)
      ..lineTo(136, 84)
      ..lineTo(116, 78)
      ..lineTo(116, 160)
      ..quadraticBezierTo(116, 168, 105, 168)
      ..quadraticBezierTo(94, 168, 94, 160)
      ..lineTo(94, 78)
      ..lineTo(74, 84)
      ..close();
    canvas.drawPath(arrow, Paint()..color = Colors.white);
    canvas.restore();

    final white = Paint()..color = Colors.white;
    _sparkle(canvas, const Offset(176, 40), 16, white);
    canvas.drawCircle(const Offset(40, 58), 1.6, white);
    canvas.drawCircle(const Offset(170, 168), 1.4, white);
  }

  @override
  bool shouldRepaint(_TurnDialPainter old) => old.diffDeg != diffDeg;
}

/// 向きが合ったときの丸と雲（FinderAligned.html、210×210）
class AlignedDial extends StatelessWidget {
  const AlignedDial({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: const Size.square(210), painter: _AlignedDialPainter()),
    );
  }
}

class _AlignedDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 210);
    const c = Offset(105, 105);
    canvas.drawCircle(c, 98, Paint()..color = Colors.white.withValues(alpha: 0.22));
    canvas.drawCircle(
      c,
      98,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white,
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.5);
    const count = 61;
    for (var i = 0; i < count; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: 78), i * 2 * math.pi / count, 2 / 78, false, ring);
    }
    // "M66 128 h78 a20 20 0 0 0 0-40 a28 28 0 0 0-53-7 a19 19 0 0 0-25 47z"
    final cloud = Path()
      ..moveTo(66, 128)
      ..relativeLineTo(78, 0)
      ..relativeArcToPoint(const Offset(0, -40), radius: const Radius.circular(20), clockwise: false)
      ..relativeArcToPoint(const Offset(-53, -7), radius: const Radius.circular(28), clockwise: false)
      ..relativeArcToPoint(const Offset(-25, 47), radius: const Radius.circular(19), clockwise: false)
      ..close();
    final white = Paint()..color = Colors.white;
    canvas.drawPath(cloud, white);
    _sparkle(canvas, const Offset(176, 36), 16, white);
    _sparkle(canvas, const Offset(30, 150), 12, white);
  }

  @override
  bool shouldRepaint(_AlignedDialPainter oldDelegate) => false;
}

/// 見上げる高さの図（Finder.html のカードの中、316×104）
class ElevationDiagram extends StatelessWidget {
  final double elevationDeg;

  const ElevationDiagram({super.key, required this.elevationDeg});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '地平線から約${elevationDeg.round()}度上に入道雲が見える',
      child: AspectRatio(
        aspectRatio: 316 / 104,
        child: CustomPaint(
          painter: _ElevationPainter(
            elevationDeg: elevationDeg,
            labelStyle: AppTextStyles.caption().copyWith(fontSize: 11),
            numberStyle: AppTextStyles.number(fontSize: 12),
          ),
        ),
      ),
    );
  }
}

class _ElevationPainter extends CustomPainter {
  final double elevationDeg;
  final TextStyle labelStyle;
  final TextStyle numberStyle;

  _ElevationPainter({required this.elevationDeg, required this.labelStyle, required this.numberStyle});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 316);
    canvas.drawLine(
      const Offset(10, 88),
      const Offset(306, 88),
      Paint()
        ..color = AppColors.textSub.withValues(alpha: 0.5)
        ..strokeWidth = 1.5,
    );
    final horizon = _text('地平線', labelStyle);
    horizon.paint(canvas, Offset(306 - horizon.width, 92));

    const eye = Offset(22, 82);
    canvas.drawCircle(eye, 5, Paint()..color = AppColors.accent);

    // 見る線は、右の端（x=250）か上の端（y=17）までのどちらか近いほう
    final rad = elevationDeg.clamp(1, 89) * math.pi / 180;
    final run = math.min(228.0, 65 / math.tan(rad));
    final end = eye + Offset(run, -run * math.tan(rad));
    final line = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final total = (end - eye).distance;
    final dir = (end - eye) / total;
    for (double d = 0; d < total; d += 7) {
      canvas.drawLine(eye + dir * d, eye + dir * math.min(d + 2, total), line);
    }

    canvas.drawArc(
      Rect.fromCircle(center: eye, radius: 48),
      -rad,
      rad,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.text,
    );
    _text('${elevationDeg.round()}°', numberStyle).paint(canvas, const Offset(78, 64));

    final cloudCenter = Offset(math.min(end.dx + 20, 284), 30);
    canvas.drawRect(
      Rect.fromLTWH(cloudCenter.dx - 6, 43, 12, 45),
      Paint()..color = AppColors.accent.withValues(alpha: 0.18),
    );
    canvas.drawCircle(cloudCenter, 26, Paint()..color = const Color(0xFFBFE3FF).withValues(alpha: 0.35));
    canvas.save();
    canvas.translate(cloudCenter.dx - 20, 42);
    final cloud = _cloudPath(1);
    canvas.drawPath(cloud, Paint()..color = Colors.white);
    canvas.drawPath(
      cloud,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = AppColors.accent,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ElevationPainter old) => old.elevationDeg != elevationDeg;
}

/// スマホを8の字に動かす図（Calibrate.html、220×130）
class FigureEightDrawing extends StatelessWidget {
  const FigureEightDrawing({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'スマホを8の字に動かす図',
      child: CustomPaint(size: const Size(220, 130), painter: _FigureEightPainter()),
    );
  }
}

class _FigureEightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(110, 65)
      ..cubicTo(80, 20, 30, 20, 30, 65)
      ..cubicTo(30, 110, 80, 110, 110, 65)
      ..cubicTo(140, 20, 190, 20, 190, 65)
      ..cubicTo(190, 110, 140, 110, 110, 65)
      ..close();
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = AppColors.accent;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length)), dash);
      }
    }
    final phone = RRect.fromRectAndRadius(const Rect.fromLTWH(166, 34, 24, 40), const Radius.circular(5));
    canvas.drawRRect(phone, Paint()..color = Colors.white);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = AppColors.text;
    canvas.drawRRect(phone, stroke);
    canvas.drawLine(
      const Offset(176, 40),
      const Offset(180, 40),
      Paint()
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = AppColors.text,
    );
  }

  @override
  bool shouldRepaint(_FigureEightPainter oldDelegate) => false;
}
