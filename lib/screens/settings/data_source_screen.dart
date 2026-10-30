import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/app_buttons.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/sky_card.dart';
import '../../widgets/common/sky_page.dart';

/// データの出典（設定から開く文章ページ。仕様書の「デザインしない画面」）
///
/// ここでは長い出典表記「出典：気象庁ホームページ（加工して作成）」を使う（CLAUDE.md）。
class DataSourceScreen extends StatelessWidget {
  const DataSourceScreen({super.key});

  static final Uri jmaTerms = Uri.parse('https://www.jma.go.jp/jma/kishou/info/coment.html');

  @override
  Widget build(BuildContext context) {
    final body = AppTextStyles.body();
    return SkyPage(
      gradient: SkyGradient.light,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(title: 'データの出典'),
          const SizedBox(height: 14),
          SkyCard(
            solid: true,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('出典：気象庁ホームページ（加工して作成）', style: AppTextStyles.item().copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  '雲の場所は、気象庁ホームページの「高解像度降水ナウキャスト」と「雷ナウキャスト」をもとに、'
                  'このアプリが強い雨や雷のある場所をまとめて作っています。',
                  style: body,
                ),
                const SizedBox(height: 10),
                Text(
                  '雲の背の高さは気象庁ホームページの「ひまわり」の赤外画像から、空が一面の曇りかと遠くまで見通せるかは'
                  '「アメダス」の観測から、このアプリが見積もっています。',
                  style: body,
                ),
                const SizedBox(height: 10),
                Text('気象庁のデータは、このアプリのサーバーが5分ごとにまとめて受け取っています。', style: body),
                const SizedBox(height: 10),
                Text(
                  'アプリの表示は気象庁が発表したものではありません。入道雲が見えるかどうかは、山や建物、ほかの雲によって変わります。',
                  style: body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextLinkButton(
              label: '気象庁ホームページの利用規約',
              color: AppColors.accent,
              onPressed: () => launchUrl(jmaTerms, mode: LaunchMode.externalApplication),
            ),
          ),
        ],
      ),
    );
  }
}
