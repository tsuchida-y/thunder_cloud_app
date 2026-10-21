import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/finder_target.dart';
import '../../services/compass/compass_service.dart';
import '../../services/location/current_place.dart';
import '../../services/sky/report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/app_buttons.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/sky_card.dart';
import '../../widgets/common/sky_page.dart';
import '../../widgets/common/source_note.dart';
import 'calibrate_sheet.dart';
import 'widgets/finder_drawings.dart';

/// 方角ガイド（docs/design/Finder.html, FinderAligned.html）
///
/// - ずれが10°以内で「この方向です」に切り替え、軽く振動する（15°を超えたら戻す）
/// - 雲が真後ろ（150°以上ずれている）のときは「後ろを向いて」
/// - 方位センサーの精度が低いときは、方位の調整（Calibrate.html）を1回だけ出す
class FinderScreen extends StatefulWidget {
  final FinderTarget target;

  const FinderScreen({super.key, required this.target});

  @override
  State<FinderScreen> createState() => _FinderScreenState();
}

class _FinderScreenState extends State<FinderScreen> {
  static const double alignEnterDeg = 10;
  static const double alignLeaveDeg = 15;
  static const double behindDeg = 150;

  /// 方位センサーから何も届かないまま、この時間がたったら「使えない」とする
  static const Duration noSensorAfter = Duration(seconds: 3);

  final StreamController<Heading> _headings = StreamController<Heading>.broadcast();
  StreamSubscription<Heading>? _sub;
  Timer? _noSensorTimer;

  double? _heading;
  bool _noSensor = false;
  bool _aligned = false;
  bool _calibrateShown = false;
  bool _answered = false;

  FinderTarget get target => widget.target;

  @override
  void initState() {
    super.initState();
    _start();
    ReportService.answered(target.cloudId).then((value) {
      if (mounted) setState(() => _answered = value);
    });
  }

  Future<void> _start() async {
    _noSensorTimer = Timer(noSensorAfter, () {
      if (mounted && _heading == null) setState(() => _noSensor = true);
    });
    // Android は磁北が基準なので、いまいる場所の偏角で本当の北に直す（iPhone は 0）
    final declination = await CompassService.declination(await CurrentPlace.lastKnown());
    if (!mounted) return;
    _sub = CompassService.headings(declinationDeg: declination).listen(_onHeading);
  }

  void _onHeading(Heading h) {
    _headings.add(h);
    final previous = _heading;
    // 細かく揺れないよう、前の値に少しずつ寄せる
    final smoothed = previous == null ? h.trueDeg : (previous + angleDiff(previous, h.trueDeg) * 0.25 + 360) % 360;
    final diff = angleDiff(smoothed, target.bearingDeg).abs();
    final aligned = _aligned ? diff <= alignLeaveDeg : diff <= alignEnterDeg;
    if (aligned && !_aligned) HapticFeedback.mediumImpact();

    setState(() {
      _heading = smoothed;
      _noSensor = false;
      _aligned = aligned;
    });

    final accuracy = h.accuracyDeg;
    if (!_calibrateShown && accuracy != null && accuracy > CalibrateSheet.poorAccuracyDeg) {
      _calibrateShown = true;
      CalibrateSheet.show(context, _headings.stream);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _noSensorTimer?.cancel();
    _headings.close();
    super.dispose();
  }

  void _answer(bool seen) {
    ReportService.send(target, seen: seen);
    setState(() => _answered = true);
  }

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      gradient: SkyGradient.finder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: '${target.directionName}の入道雲へ'),
          const SizedBox(height: 16),
          ...(_aligned ? _alignedBody() : _guideBody()),
        ],
      ),
    );
  }

  List<Widget> _guideBody() {
    final heading = _heading;
    final diff = heading == null ? null : angleDiff(heading, target.bearingDeg);
    final behind = diff != null && diff.abs() >= behindDeg;
    final white = AppTextStyles.body(color: Colors.white);

    final Widget headline;
    final String sub;
    if (diff == null) {
      headline = Text('${target.directionName}の方角です', style: AppTextStyles.display());
      sub = _noSensor ? 'この端末では方位センサーが使えません。' : '方角を調べています…';
    } else if (behind) {
      headline = Text('後ろを向いて', style: AppTextStyles.display());
      sub = 'ゆっくり、体ごと後ろを向いて';
    } else {
      final right = diff > 0;
      headline = Text.rich(
        TextSpan(children: [
          TextSpan(text: right ? '右へ ' : '左へ '),
          TextSpan(text: '${diff.abs().round()}°', style: AppTextStyles.number(fontSize: 34, color: Colors.white)),
        ]),
        style: AppTextStyles.display(),
      );
      sub = 'ゆっくり、体ごと${right ? '右' : '左'}を向いて';
    }

    return [
      if (heading != null) HeadingTape(headingDeg: heading, targetDeg: target.bearingDeg),
      const SizedBox(height: 18),
      Center(
        child: Semantics(
          liveRegion: true,
          child: Column(
            children: [
              if (diff != null) TurnDial(diffDeg: diff),
              const SizedBox(height: 10),
              headline,
              const SizedBox(height: 4),
              Text(sub, style: white, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
      const SizedBox(height: 18),
      SkyCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('見上げる高さ', style: AppTextStyles.body().copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            ElevationDiagram(elevationDeg: target.elevationDeg),
            const SizedBox(height: 6),
            Text('腕を伸ばして、${target.fistsLabel}くらい上。', style: AppTextStyles.body(color: AppColors.textSub).copyWith(fontSize: 14, height: 1.6)),
          ],
        ),
      ),
      // デザインにはないが、気象庁のデータから出した方角なので、画面に出典を出す（CLAUDE.md）
      const Spacer(),
      const SizedBox(height: 18),
      const SourceNote(),
    ];
  }

  List<Widget> _alignedBody() {
    return [
      const SizedBox(height: 8),
      const Center(child: AlignedDial()),
      const SizedBox(height: 10),
      Semantics(
        liveRegion: true,
        child: Text('この方向です', textAlign: TextAlign.center, style: AppTextStyles.display()),
      ),
      const SizedBox(height: 6),
      Text(
        '正面の空、${target.fistsLabel}くらい上を\n見上げてみてください。',
        textAlign: TextAlign.center,
        style: AppTextStyles.body(color: Colors.white),
      ),
      const Spacer(),
      const SizedBox(height: 16),
      _ReportCard(answered: _answered, onAnswer: _answer),
      const SizedBox(height: 14),
      const SourceNote(),
    ];
  }
}

/// 「入道雲は見えましたか？」
class _ReportCard extends StatelessWidget {
  final bool answered;
  final ValueChanged<bool> onAnswer;

  const _ReportCard({required this.answered, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    return SkyCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('入道雲は見えましたか？', style: AppTextStyles.item().copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          if (answered)
            Text('教えてくれて、ありがとうございます。', style: AppTextStyles.note())
          else ...[
            Text('教えてもらうと、お知らせの精度が上がります。', style: AppTextStyles.note()),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: ChoiceButton(label: '見えた', onPressed: () => onAnswer(true))),
                const SizedBox(width: 8),
                Expanded(child: ChoiceButton(label: '見えなかった', onPressed: () => onAnswer(false))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
