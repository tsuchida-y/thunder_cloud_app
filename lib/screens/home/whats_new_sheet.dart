import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/app_buttons.dart';

/// 今のアプリ（1.0.4）から v2.0 に上げた人へのお知らせ（実装の進め方 ステップ10）
///
/// コミュニティと写真の機能を外したことと、新しい使い方を1回だけ伝える。
/// v1 が端末に残した ID（unique_user_id）があれば、上げた人とみなす。
class WhatsNewSheet extends StatelessWidget {
  const WhatsNewSheet({super.key});

  static const String _legacyUserIdKey = 'unique_user_id';
  static const String _shownKey = 'whats_new_v2_shown';

  /// 出すべきなら true を返し、出したことを残す
  static Future<bool> takeTurn() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_legacyUserIdKey) == null || prefs.getBool(_shownKey) == true) return false;
    await prefs.setBool(_shownKey, true);
    return true;
  }

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x730B1630),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => const WhatsNewSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const points = [
      '気象庁のデータをもとに、いま見えている入道雲の方角と距離をお知らせするようになりました。',
      'ホームの「雲の方角を調べる」で、スマホを向けて入道雲のある方角を確かめられます。',
      'みんなの写真を見るコミュニティと、写真を撮る機能は終わりました。これまでに投稿された写真は削除します。スマホの写真アプリに保存した写真は、そのまま残ります。',
      '遠くの雲（90kmまで）や、よく行く場所も見張れる「Plus」ができました。',
    ];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: AppColors.switchOff, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(
                '入道雲サーチが\n新しくなりました。',
                style: AppTextStyles.headline(color: AppColors.text, fontSize: 22).copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            for (final point in points) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 9),
                    child: SizedBox.square(
                      dimension: 6,
                      child: DecoratedBox(decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(point, style: AppTextStyles.body())),
                ],
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 6),
            PrimaryButton(label: 'わかりました', onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}
