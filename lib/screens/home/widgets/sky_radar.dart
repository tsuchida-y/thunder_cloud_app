import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/sky_cloud.dart';
import '../../../theme/app_text_styles.dart';

/// いまいる場所を中心にした空のレーダー（Main.html, Empty.html）
///
/// 上が本当の北。外側の円が見える範囲（無料 30km、Plus は設定の範囲）。
/// いちばん近い雲は光の筋つきで大きく、ほかの雲は小さく描く。
/// 60km より遠い「見えるかもしれない」雲は点線の円で描く。
/// [sweep] が true なら、見張っていることが目で分かるよう、光の筋がゆっくり回る（2026-10-27）。
/// 端末の設定で動きを減らしている人には回さない。
class SkyRadar extends StatelessWidget {
  final List<CloudView> clouds;
  final double rangeKm;
  final double size;

  /// 東・南・西の文字も出すか（雲がないときは北だけ）
  final bool showAllDirections;

  /// 見張り中の光の筋を回すか
  final bool sweep;

  const SkyRadar({
    super.key,
    required this.clouds,
    required this.rangeKm,
    this.size = 260,
    this.showAllDirections = true,
    this.sweep = false,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: _semanticLabel(),
      image: true,
      child: Stack(
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RadarPainter(
              clouds: clouds,
              rangeKm: rangeKm,
              showAllDirections: showAllDirections,
              labelStyle: AppTextStyles.number(fontSize: showAllDirections ? 13 : 18, color: Colors.white),
            ),
          ),
          if (sweep && !MediaQuery.disableAnimationsOf(context)) _RadarSweep(size: size),
        ],
      ),
    );
  }

  String _semanticLabel() {
    if (clouds.isEmpty) return '空のレーダー。雲は見つかっていません';
    final parts = clouds.map((c) => '${c.directionName}${c.roundedKm}kmに入道雲').join('、');
    return '現在地を中心にした空のレーダー。$parts';
  }
}

/// 見張り中の光の筋（6秒で1周）
class _RadarSweep extends StatefulWidget {
  final double size;

  const _RadarSweep({required this.size});

  @override
  State<_RadarSweep> createState() => _RadarSweepState();
}

class _RadarSweepState extends State<_RadarSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(seconds: 6))
    ..repeat();

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.square(widget.size), painter: _SweepPainter(_turn)),
      ),
    );
  }
}

class _SweepPainter extends CustomPainter {
  final Animation<double> turn;

  _SweepPainter(this.turn) : super(repaint: turn);

  /// 光の筋の幅（扇の角度）
  static const double _width = math.pi / 3;

  @override
  void paint(Canvas canvas, Size size) {
    // レーダーの外側の円（デザインの 320 のうち半径 150）の内側だけを塗る
    final center = size.center(Offset.zero);
    final radius = size.width * 150 / 320;
    final end = turn.value * 2 * math.pi - math.pi / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      // 0〜幅の扇の色を作って、いまの角度まで回す（SweepGradient は 0〜2π の外の角度を扱えないため）
      ..shader = SweepGradient(
        endAngle: _width,
        colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.22)],
        transform: GradientRotation(end - _width),
      ).createShader(rect);
    canvas.drawArc(rect, end - _width, _width, true, paint);
  }

  @override
  bool shouldRepaint(_SweepPainter oldDelegate) => false;
}

class _RadarPainter extends CustomPainter {
  final List<CloudView> clouds;
  final double rangeKm;
  final bool showAllDirections;
  final TextStyle labelStyle;

  _RadarPainter({
    required this.clouds,
    required this.rangeKm,
    required this.showAllDirections,
    required this.labelStyle,
  });

  // デザインの SVG（320×320）の座標で描いて、大きさを合わせる
  static const double _box = 320;
  static const Offset _c = Offset(160, 160);
  static const double _outer = 150;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _box);

    final white = Paint()..color = Colors.white;
    canvas.drawCircle(_c, _outer, Paint()..color = const Color(0xFF14408F).withValues(alpha: 0.22));
    canvas.drawCircle(
      _c,
      _outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.7),
    );
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.45);
    _dashedCircle(canvas, _c, 100, ring, dash: 2, gap: 6);
    _dashedCircle(canvas, _c, 50, ring, dash: 2, gap: 6);

    _label(canvas, 'N', Offset(160, showAllDirections ? 27 : 29));
    if (showAllDirections) {
      _label(canvas, 'E', const Offset(292, 160));
      _label(canvas, 'S', const Offset(160, 294));
      _label(canvas, 'W', const Offset(28, 160));
    }

    // 飾りの星
    canvas.drawCircle(const Offset(74, 70), 1.6, white);
    canvas.drawCircle(const Offset(250, 96), 1.2, white);
    canvas.drawCircle(const Offset(96, 250), 1.4, white);

    // 遠い雲から描いて、近い雲を上に重ねる
    for (var i = clouds.length - 1; i >= 0; i--) {
      final view = clouds[i];
      final r = (view.distanceKm / rangeKm).clamp(0.0, 1.0) * (_outer - 22);
      final angle = view.bearingDeg * math.pi / 180;
      final p = _c + Offset(math.sin(angle) * r, -math.cos(angle) * r);
      if (view.maybeVisible) {
        _maybeCloud(canvas, p);
      } else if (i == 0) {
        _mainCloud(canvas, p);
      } else {
        _cloudShape(canvas, p, 0.7);
      }
    }

    // いまいる場所
    canvas.drawCircle(_c, 14, Paint()..color = Colors.white.withValues(alpha: 0.3));
    canvas.drawCircle(_c, 6.5, white);
    canvas.restore();
  }

  void _mainCloud(Canvas canvas, Offset p) {
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    _dashedLine(canvas, _c, p, line, dash: 2, gap: 5);
    canvas.drawCircle(p, 34, Paint()..color = const Color(0xFFBFE3FF).withValues(alpha: 0.35));

    final rays = Paint()
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    for (var k = 0; k < 8; k++) {
      final a = k * math.pi / 4;
      final dir = Offset(math.sin(a), -math.cos(a));
      final inner = k.isEven ? 28.0 : 28.3;
      final outer = k.isEven ? 38.0 : 38.2;
      canvas.drawLine(p + dir * inner, p + dir * outer, rays);
    }
    _cloudShape(canvas, p, 1);
  }

  void _maybeCloud(Canvas canvas, Offset p) {
    _dashedCircle(
      canvas,
      p,
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..color = Colors.white,
      dash: 3,
      gap: 3,
    );
    canvas.drawCircle(p, 3, Paint()..color = Colors.white);
  }

  /// デザインの雲の形（幅およそ 36、中心が p）
  void _cloudShape(Canvas canvas, Offset p, double scale) {
    canvas.save();
    canvas.translate(p.dx, p.dy);
    canvas.scale(scale);
    // SVG の "M195 218 h28 a7.5 7.5 0 0 0 0-15 a10.5 10.5 0 0 0-20-2.5 a7.2 7.2 0 0 0-8 17.5z" を中心 (209, 209) に合わせたもの
    final path = Path()
      ..moveTo(-14, 9)
      ..relativeLineTo(28, 0)
      ..relativeArcToPoint(const Offset(0, -15), radius: const Radius.circular(7.5), clockwise: false)
      ..relativeArcToPoint(const Offset(-20, -2.5), radius: const Radius.circular(10.5), clockwise: false)
      ..relativeArcToPoint(const Offset(-8, 17.5), radius: const Radius.circular(7.2), clockwise: false)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.restore();
  }

  void _label(Canvas canvas, String text, Offset center) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  static void _dashedCircle(Canvas canvas, Offset center, double radius, Paint paint,
      {required double dash, required double gap}) {
    final circumference = 2 * math.pi * radius;
    final count = (circumference / (dash + gap)).floor();
    final step = 2 * math.pi / count;
    final sweep = step * dash / (dash + gap);
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < count; i++) {
      canvas.drawArc(rect, i * step, sweep, false, paint);
    }
  }

  static void _dashedLine(Canvas canvas, Offset from, Offset to, Paint paint,
      {required double dash, required double gap}) {
    final total = (to - from).distance;
    if (total == 0) return;
    final dir = (to - from) / total;
    for (double d = 0; d < total; d += dash + gap) {
      canvas.drawLine(from + dir * d, from + dir * math.min(d + dash, total), paint);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter old) =>
      old.clouds != clouds || old.rangeKm != rangeKm || old.showAllDirections != showAllDirections;
}
