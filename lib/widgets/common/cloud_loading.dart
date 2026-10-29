import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// 読み込み中に出す「雲がもくもく湧く」絵（2026-10-29）
///
/// 見本は docs/loading/nyudogumo_loading/cloud_loading.html（同じ計算）。雲は15個の丸を重ねて描く。
/// - 最初の1.4秒で、下の段の丸から順に、少し大きくなってから落ち着くように現れる
/// - そのあとは2.4秒ごとに、同じ順番で下の段から丸がぽこっとふくらんでは戻る
/// - 端末の設定で動きを減らしている人には、できあがった雲を止めて出す
///
/// 色はテーマ（[LoadingColors]）から取る。絵は読み上げの対象から外す（文字は読み込み画面が出す）。
class CloudLoading extends StatefulWidget {
  /// 雲を描く正方形の一辺。読み込み画面では 64
  final double size;

  const CloudLoading({super.key, this.size = 64});

  @override
  State<CloudLoading> createState() => _CloudLoadingState();
}

class _CloudLoadingState extends State<CloudLoading> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _intro.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_reduceMotion) _loop.repeat();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      // 動きを減らす設定の人には、できあがった雲を止めて出す
      _intro.value = 1;
      _loop
        ..stop()
        ..value = 0;
    } else if (_intro.status == AnimationStatus.dismissed) {
      _intro.forward();
    } else if (_intro.isCompleted && !_loop.isAnimating) {
      // 動きを減らす設定をあとから外したとき
      _loop.repeat();
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
    final colors = LoadingColors.of(context);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _CloudPainter(intro: _intro, loop: _loop, cloudColor: colors.cloud, shadeColor: colors.shade),
        ),
      ),
    );
  }
}

class _Puff {
  final double x, y, r;

  /// 小さいほど先に現れる（下の段が0）
  final int order;

  const _Puff(this.x, this.y, this.r, this.order);
}

class _Circle {
  final double x, y, r;

  const _Circle(this.x, this.y, this.r);
}

// 0〜1 の箱の中の位置と半径（見本の HTML と同じ）
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

/// 雲の底。ここから下は切りそろえる
const double _baseY = .84;

/// 少し行き過ぎてから戻る動き。見本の HTML の強さ（1.6）に合わせる（Flutter の Curves.easeOutBack は 1.70158）
double _easeOutBack(double t) {
  const c = 1.6;
  return 1 + (c + 1) * math.pow(t - 1, 3) + c * math.pow(t - 1, 2);
}

class _CloudPainter extends CustomPainter {
  final Animation<double> intro;
  final Animation<double> loop;
  final Color cloudColor;
  final Color shadeColor;

  _CloudPainter({required this.intro, required this.loop, required this.cloudColor, required this.shadeColor})
      : super(repaint: Listenable.merge([intro, loop]));

  List<_Circle> _circlesAt(double introT, double loopT) {
    final out = <_Circle>[];
    for (final p in _puffs) {
      final delay = p.order / 3 * 0.6;
      final t = ((introT - delay) / 0.4).clamp(0.0, 1.0);
      final appear = introT >= 1 ? 1.0 : math.max(0.0, _easeOutBack(t));
      // くり返しでは、下の段から順に丸がぽこっとふくらんで戻る（最初の湧き上がりと同じ順番）
      final lt = (loopT - p.order * 0.12) / 0.4;
      final bump = lt > 0 && lt < 1 ? math.sin(math.pi * lt) : 0.0;
      final r = p.r * appear * (1 + (0.10 + 0.04 * p.order) * bump);
      final y = p.y - 0.02 * (p.order / 3) * bump;
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
    // まず全部の丸を影の色で描き、その上に少し小さくして左上へずらした丸を雲の色で重ねる。
    // 雲のふちと丸のすき間にだけ影が残り、もこもこした形が見える
    final shade = Paint()..color = shadeColor;
    for (final c in circles) {
      canvas.drawCircle(Offset(c.x * s, c.y * s), c.r * s, shade);
    }
    final cloud = Paint()..color = cloudColor;
    for (final c in circles) {
      canvas.drawCircle(Offset((c.x - c.r * .08) * s, (c.y - c.r * .12) * s), c.r * .9 * s, cloud);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CloudPainter old) => old.cloudColor != cloudColor || old.shadeColor != shadeColor;
}
