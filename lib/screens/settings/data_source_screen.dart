import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
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
          PageHeader(title: AppLocalizations.of(context).settingsDataSource),
          const SizedBox(height: 14),
          SkyCard(
            solid: true,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppLocalizations.of(context).dataSourceCredit, style: AppTextStyles.item().copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context).dataSourceClouds,
                  style: body,
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context).dataSourceHeights,
                  style: body,
                ),
                const SizedBox(height: 10),
                Text(AppLocalizations.of(context).dataSourceFetch, style: body),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context).dataSourceDisclaimer,
                  style: body,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextLinkButton(
              label: AppLocalizations.of(context).dataSourceJmaTerms,
              color: AppColors.accent,
              onPressed: () => launchUrl(jmaTerms, mode: LaunchMode.externalApplication),
            ),
          ),
        ],
      ),
    );
  }
}
