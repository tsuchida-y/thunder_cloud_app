import 'package:flutter/material.dart';

import '../../services/compass/compass_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/app_buttons.dart';
import 'widgets/finder_drawings.dart';

/// 方位の調整（docs/design/Calibrate.html）
///
/// 方位センサーの精度が低いときに、方角ガイドの上に下から出す。精度が上がったら自動で閉じる。
class CalibrateSheet extends StatelessWidget {
  final Stream<Heading> headings;

  const CalibrateSheet({super.key, required this.headings});

  /// これより誤差が大きいと調整をお願いする（°）
  static const double poorAccuracyDeg = 30;

  /// これまで誤差が小さくなったら閉じる（°）
  static const double goodAccuracyDeg = 20;

  static Future<void> show(BuildContext context, Stream<Heading> headings) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x730B1630), // rgba(11, 22, 48, 0.45)
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => CalibrateSheet(headings: headings),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
        child: StreamBuilder<Heading>(
          stream: headings,
          builder: (context, snap) {
            final accuracy = snap.data?.accuracyDeg;
            if (accuracy != null && accuracy <= goodAccuracyDeg) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) Navigator.of(context).maybePop();
              });
            }
            // 誤差 60° で 0、15° で いっぱい
            final progress = accuracy == null ? 0.1 : ((60 - accuracy) / 45).clamp(0.1, 1.0);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(color: AppColors.switchOff, borderRadius: BorderRadius.circular(3)),
                ),
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  child: Text('方位がずれています', style: AppTextStyles.headline(color: AppColors.text, fontSize: 24)),
                ),
                const SizedBox(height: 14),
                const FigureEightDrawing(),
                const SizedBox(height: 14),
                Text(
                  'スマホを大きく8の字に、3回ほど動かしてください。磁石や金属の近くから離れると直りやすくなります。',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body(),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.chip,
                    color: AppColors.accent,
                  ),
                ),
                const SizedBox(height: 14),
                Text('方位の精度: もう少し', style: AppTextStyles.note()),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinePillButton(label: 'このまま続ける', onPressed: () => Navigator.of(context).maybePop()),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
