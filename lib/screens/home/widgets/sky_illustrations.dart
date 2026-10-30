import 'package:flutter/material.dart';

/// 夜の画面の月と星（Night.html の絵、260×220）
class NightIllustration extends StatelessWidget {
  const NightIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: const Size(260, 220), painter: _NightPainter()),
    );
  }
}

class _NightPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 260);
    final white = Paint()..color = Colors.white;

    final moon = Path()
      ..moveTo(170, 40)
      ..relativeArcToPoint(const Offset(40, 80), radius: const Radius.circular(50), largeArc: true, clockwise: false)
      ..relativeArcToPoint(const Offset(-40, -80), radius: const Radius.circular(40), clockwise: true)
      ..close();
    canvas.drawPath(moon, Paint()..color = const Color(0xFFFFF4D6));

    for (final (x, y, r) in const [(40.0, 30.0, 2.0), (80.0, 80.0, 1.5), (230.0, 40.0, 1.6), (30.0, 140.0, 1.4), (120.0, 20.0, 1.2)]) {
      canvas.drawCircle(Offset(x, y), r, white);
    }
    canvas.drawPath(_sparkle(60, 110), white);

    final cloud = Path()
      ..moveTo(10, 220)
      ..cubicTo(10, 196, 34, 186, 50, 192)
      ..cubicTo(54, 170, 84, 166, 94, 184)
      ..cubicTo(110, 172, 136, 182, 134, 204)
      ..cubicTo(150, 202, 164, 212, 164, 220)
      ..close();
    canvas.drawPath(cloud, Paint()..color = Colors.white.withValues(alpha: 0.12));
  }

  /// 4つの角の小さな光（"M60 110 l2 6 l6 2 l-6 2 l-2 6 l-2-6 l-6-2 l6-2z"）
  static Path _sparkle(double x, double y) => Path()
    ..moveTo(x, y)
    ..relativeLineTo(2, 6)
    ..relativeLineTo(6, 2)
    ..relativeLineTo(-6, 2)
    ..relativeLineTo(-2, 6)
    ..relativeLineTo(-2, -6)
    ..relativeLineTo(-6, -2)
    ..relativeLineTo(6, -2)
    ..close();

  @override
  bool shouldRepaint(_NightPainter oldDelegate) => false;
}

/// 通信できないときの、斜線の入った雲（Offline.html の絵、200×160）
class OfflineIllustration extends StatelessWidget {
  const OfflineIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(size: const Size(200, 160), painter: _OfflinePainter()),
    );
  }
}

class _OfflinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200);
    final cloud = Path()
      ..moveTo(30, 130)
      ..cubicTo(20, 110, 40, 96, 56, 102)
      ..cubicTo(56, 76, 92, 66, 104, 88)
      ..cubicTo(112, 62, 152, 62, 156, 94)
      ..cubicTo(176, 94, 186, 118, 172, 130)
      ..close();
    canvas.drawPath(cloud, Paint()..color = Colors.white.withValues(alpha: 0.85));

    const from = Offset(48, 56);
    const to = Offset(160, 150);
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = const Color(0xFF4E6E96)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_OfflinePainter oldDelegate) => false;
}
