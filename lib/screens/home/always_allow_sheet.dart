import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/app_buttons.dart';

/// 移動先も見張るお願い（docs/design/AlwaysAllow.html、許可の2段目）
///
/// 最初の入道雲の通知が届いたあとにアプリを開いたとき、1回だけホームの上に出す。
class AlwaysAllowSheet extends StatelessWidget {
  /// 「滝沢市」。分からなければ null
  final String? placeName;
  final Future<void> Function() onAllow;

  const AlwaysAllowSheet({super.key, required this.placeName, required this.onAllow});

  static Future<void> show(BuildContext context, {String? placeName, required Future<void> Function() onAllow}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      barrierColor: const Color(0x730B1630), // rgba(11, 22, 48, 0.45)
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => AlwaysAllowSheet(placeName: placeName, onAllow: onAllow),
    );
  }

  @override
  Widget build(BuildContext context) {
    final place = placeName == null ? '' : '（$placeName）';
    return SafeArea(
      top: false,
      child: Padding(
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
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(color: AppColors.chip, shape: BoxShape.circle),
                child: const Icon(Icons.near_me_outlined, size: 26, color: AppColors.accent),
              ),
            ),
            const SizedBox(height: 14),
            Semantics(
              header: true,
              child: Text(
                '出かけた先の空も、\n見張りましょうか。',
                style: AppTextStyles.headline(color: AppColors.text, fontSize: 22).copyWith(height: 1.5),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'いまは、最後にアプリを開いた場所$placeの空を見張っています。'
              '位置情報を「常に」にすると、移動しても、いまいる場所の空を見張れます。',
              style: AppTextStyles.body(),
            ),
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: BoxDecoration(color: const Color(0xFFF4F8FC), borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Text(
                  '次の画面で「常に許可」を選んでください。Androidでは設定アプリが開くので、「常に許可」を選んで戻ってください。',
                  style: AppTextStyles.note(),
                ),
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: '「常に」にする',
              onPressed: () async {
                Navigator.of(context).pop();
                await onAllow();
              },
            ),
            const SizedBox(height: 10),
            Center(
              child: TextLinkButton(label: 'いまのままにする', onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}
