// 入道雲サーチ ローディングの雲 (参考コード)
// 見本: docs/nyudogumo/loading/cloud_loading.html と同じ計算をしている。
// 色はアプリのテーマに移してから使うこと。

import 'dart:math' as math;

import 'package:flutter/material.dart';

class CloudLoading extends StatefulWidget {
  const CloudLoading({
    super.key,
    this.size = 64,
    required this.cloudColor,
    required this.shadeColor,
  });

  /// 雲を描く正方形の一辺。読み込み画面では 64。
  final double size;
  final Color cloudColor;
  final Color shadeColor;

  @override
  State<CloudLoading> createState() => _CloudLoadingState();
}

class _CloudLoadingState extends State<CloudLoading>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_reduceMotion) {
        _loop.repeat();
      }
    });
  }

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) {
      // 動きを減らす設定の人には、できあがった雲を止めて出す
      _intro.value = 1;
      _loop.stop();
      _loop.value = 0;
    } else if (_intro.status == AnimationStatus.dismissed) {
      _intro.forward();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _CloudPainter(
            intro: _intro,
            loop: _loop,
            cloudColor: widget.cloudColor,
            shadeColor: widget.shadeColor,
          ),
        ),
      ),
    );
  }
}

class _Puff {
  const _Puff(this.x, this.y, this.r, this.order);
  final double x, y, r;
  final int order;
}

class _Circle {
  const _Circle(this.x, this.y, this.r);
  final double x, y, r;
}

// 0〜1 の箱の中の位置と半径。order が小さいほど先に現れる
const _puffs = <_Puff>[
  _Puff(.14, .77, .11, 0),
  _Puff(.28, .74, .14, 0),
  _Puff(.44, .73, .15, 0),
  _Puff(.60, .73, .15, 0),
  _Puff(.75, .74, .14, 0),
  _Puff(.88, .78, .10, 0),
  _Puff(.27, .60, .12, 1),
  _Puff(.41, .55, .15, 1),
  _Puff(.58, .54, .16, 1),
  _Puff(.73, .61, .12, 1),
  _Puff(.37, .41, .13, 2),
  _Puff(.50, .38, .15, 2),
  _Puff(.65, .40, .13, 2),
  _Puff(.43, .25, .12, 3),
  _Puff(.58, .24, .12, 3),
];

const _baseY = .84; // 雲の底。ここから下は切りそろえる

class _CloudPainter extends CustomPainter {
  _CloudPainter({
    required this.intro,
    required this.loop,
    required this.cloudColor,
    required this.shadeColor,
  }) : super(repaint: Listenable.merge([intro, loop]));

  final Animation<double> intro;
  final Animation<double> loop;
  final Color cloudColor;
  final Color shadeColor;

  List<_Circle> _circlesAt(double introT, double loopT) {
    final out = <_Circle>[];
    for (final p in _puffs) {
      final delay = p.order / 3 * 0.6;
      final t = ((introT - delay) / 0.4).clamp(0.0, 1.0);
      final appear =
          introT >= 1 ? 1.0 : math.max(0.0, Curves.easeOutBack.transform(t));
      // くり返しでは、下の段から順に丸がぽこっとふくらんで戻る(最初の湧き上がりと同じ順番)
      final lt = (loopT - p.order * 0.12) / 0.4;
      final bump = lt > 0 && lt < 1 ? math.sin(math.pi * lt) : 0.0;
      final r = p.r * appear * (1 + (0.20 + 0.06 * p.order) * bump);
      final y = p.y - 0.05 * (p.order / 3) * bump;
      if (r > 0) out.add(_Circle(p.x, y, r));
    }
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final circles = _circlesAt(intro.value, loop.value);
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, s, s * _baseY));
    // まず全部の丸を影の色で描き、その上に少し小さくして左上へずらした丸を雲の色で重ねる
    final shade = Paint()..color = shadeColor;
    for (final c in circles) {
      canvas.drawCircle(Offset(c.x * s, c.y * s), c.r * s, shade);
    }
    final cloud = Paint()..color = cloudColor;
    for (final c in circles) {
      canvas.drawCircle(
        Offset((c.x - c.r * .08) * s, (c.y - c.r * .12) * s),
        c.r * .9 * s,
        cloud,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CloudPainter old) =>
      old.cloudColor != cloudColor || old.shadeColor != shadeColor;
}
