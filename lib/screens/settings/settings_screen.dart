import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/sky_cloud.dart';
import '../../navigation/app_routes.dart';
import '../../services/member/member_service.dart';
import '../../services/sky/report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/page_header.dart';
import '../../widgets/common/settings_parts.dart';
import '../../widgets/common/sky_page.dart';
import 'quiet_hours_sheet.dart';

/// 設定（docs/design/Settings.html）
///
/// 値は members/{uid}.settings に書く。サーバーは notifyAppeared, rangeKm, quietHours を見て通知を決める。
/// Plus かどうかは member_server/{uid}（サーバーだけが書く）を読む。
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  /// 今のプライバシーポリシー（README と同じ。中身はステップ10で書き直す）
  static final Uri privacyPolicy = Uri.parse('https://tsuchida-y.github.io/thunder_cloud_app/privacy_policy.html');

  /// 利用規約（docs/terms.html。GitHub Pages は main の docs/ を公開するので、main に入ってから開ける）
  static final Uri termsOfUse = Uri.parse('https://tsuchida-y.github.io/thunder_cloud_app/terms.html');

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _memberSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _serverSub;
  Map<String, dynamic>? _member;
  Map<String, dynamic>? _server;
  int? _seenDays;

  @override
  void initState() {
    super.initState();
    final uid = MemberService.uid;
    if (uid != null) {
      _memberSub = MemberService.watchMember(uid).listen((doc) => setState(() => _member = doc.data()));
      _serverSub = MemberService.watchServer(uid).listen((doc) => setState(() => _server = doc.data()));
    }
    ReportService.seenDaysThisYear().then((days) {
      if (mounted) setState(() => _seenDays = days);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _memberSub?.cancel();
    _serverSub?.cancel();
    super.dispose();
  }

  bool get _isPlus => MemberService.isPlusActive(_server, DateTime.now());

  Future<void> _editQuietHours(QuietHours? current) async {
    final result = await QuietHoursSheet.show(context, current);
    if (!result.changed) return;
    await MemberService.updateSettings({'quietHours': result.value?.toMap()});
  }

  @override
  Widget build(BuildContext context) {
    final settings = MemberSettings.fromMember(_member);
    final isPlus = _isPlus;
    final rangeKm = SkyRules.rangeKm(isPlus: isPlus, settingKm: settings.rangeKm);
    final places = MemberService.placesOf(_member);

    return SkyPage(
      gradient: SkyGradient.light,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHeader(title: '設定'),
          const SizedBox(height: 6),
          const SettingsSectionLabel('通知'),
          const SizedBox(height: 14),
          SettingsCard(
            children: [
              SettingsRow.text(
                '入道雲が見えたら知らせる',
                trailing: SkySwitch(
                  value: settings.notifyAppeared,
                  semanticLabel: '入道雲が見えたら知らせる',
                  onChanged: (v) => MemberService.updateSettings({'notifyAppeared': v}),
                ),
              ),
              SettingsRow(
                title: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [Text('出そうなときも先に知らせる', style: AppTextStyles.item()), const PlusBadge()],
                ),
                subtitle: '30分前くらいにお知らせします',
                trailing: SkySwitch(
                  value: isPlus && settings.notifyPreview,
                  semanticLabel: '出そうなときも先に知らせる',
                  // 無料プランでは Plus のご案内を開く
                  onChanged: (v) =>
                      isPlus ? MemberService.updateSettings({'notifyPreview': v}) : AppRoutes.openPlus(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SettingsSectionLabel('どこまでの空を見守るか'),
          const SizedBox(height: 14),
          _RangeSelector(
            rangeKm: rangeKm,
            isPlus: isPlus,
            onSelect: (km) => isPlus ? MemberService.updateSettings({'rangeKm': km}) : AppRoutes.openPlus(context),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              '60kmより遠い雲は「見えるかもしれません」とお知らせします。山や建物で隠れることもあります。',
              style: AppTextStyles.note(),
            ),
          ),
          const SizedBox(height: 14),
          const SettingsSectionLabel('そのほか'),
          const SizedBox(height: 14),
          SettingsCard(
            children: [
              SettingsRow.text(
                '通知しない時間',
                subtitle: '夜（日没〜日の出）は自動で休みます',
                trailing: SettingsValue(settings.quietHours?.label ?? 'なし'),
                onTap: () => _editQuietHours(settings.quietHours),
              ),
              SettingsRow.text(
                '記録（見えた雲）',
                trailing: _seenDays == null ? null : SettingsValue('$_seenDays日'),
                onTap: () => AppRoutes.openRecord(context),
              ),
              SettingsRow.text(
                '見張る場所',
                trailing: SettingsValue(places.isEmpty ? 'いまいる場所' : places.first.label),
                onTap: () => AppRoutes.openPlaces(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // デザインにない行。仕様書の「デザインしない画面」（利用規約、プライバシーポリシー、データの出典）への入り口
          const SettingsSectionLabel('このアプリについて'),
          const SizedBox(height: 14),
          SettingsCard(
            children: [
              SettingsRow.text('データの出典', onTap: () => AppRoutes.openDataSource(context)),
              SettingsRow.text(
                '利用規約',
                onTap: () => launchUrl(SettingsScreen.termsOfUse, mode: LaunchMode.externalApplication),
              ),
              SettingsRow.text(
                'プライバシーポリシー',
                onTap: () => launchUrl(SettingsScreen.privacyPolicy, mode: LaunchMode.externalApplication),
              ),
            ],
          ),
          if (!isPlus) ...[
            const SizedBox(height: 14),
            _PlusBanner(onTap: () => AppRoutes.openPlus(context)),
          ],
        ],
      ),
    );
  }
}

/// 30km / 90km（Plus）
class _RangeSelector extends StatelessWidget {
  final double rangeKm;
  final bool isPlus;
  final ValueChanged<int> onSelect;

  const _RangeSelector({required this.rangeKm, required this.isPlus, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    Widget option(int km, String label, {bool locked = false}) {
      final selected = rangeKm.round() == km;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          child: Material(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.small),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.small),
              onTap: () => onSelect(km),
              child: SizedBox(
                height: AppSizes.minTapTarget,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (locked) ...[const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.text), const SizedBox(width: 6)],
                    Text(
                      label,
                      style: AppTextStyles.body(color: selected ? Colors.white : AppColors.text)
                          .copyWith(fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, height: 1.2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardSolid,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const [BoxShadow(color: AppColors.cardShadow, blurRadius: 12, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            option(SkyRules.freeRangeKm.round(), '30km'),
            const SizedBox(width: 6),
            option(SkyRules.plusRangeKm.round(), isPlus ? '90km' : '90km（Plus）', locked: !isPlus),
          ],
        ),
      ),
    );
  }
}

/// 「Plus で、もっと遠く・もっと早く」
class _PlusBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _PlusBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text('Plus で、もっと遠く・もっと早く', style: AppTextStyles.button(fontSize: 15)),
              ),
              Text('7日間無料', style: AppTextStyles.body(color: Colors.white).copyWith(fontSize: 13, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}
