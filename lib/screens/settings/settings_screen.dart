import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/sky_cloud.dart';
import '../../navigation/app_routes.dart';
import '../../services/member/member_service.dart';
import '../../services/sky/report_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/logger.dart';
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
  bool _deleting = false;

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

  Future<void> _confirmDeleteData() async {
    if (_deleting) return;
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsDeleteConfirmTitle),
        content: Text(l10n.settingsDeleteConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(l10n.settingsDeleteAction)),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _deleting = true);
    try {
      await MemberService.deleteMyData();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.settingsDeletedTitle),
          content: Text(l10n.settingsDeletedBody),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );
      if (mounted) await AppRoutes.restartAtHome(context);
    } catch (e, stackTrace) {
      AppLogger.error('データの削除に失敗', error: e, stackTrace: stackTrace, tag: 'SettingsScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.settingsDeleteFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  Future<void> _editQuietHours(QuietHours? current) async {
    final result = await QuietHoursSheet.show(context, current);
    if (!result.changed) return;
    await MemberService.updateSettings({'quietHours': result.value?.toMap()});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = MemberSettings.fromMember(_member);
    final isPlus = _isPlus;
    final rangeKm = SkyRules.rangeKm(isPlus: isPlus, settingKm: settings.rangeKm);
    final places = MemberService.placesOf(_member);

    return SkyPage(
      gradient: SkyGradient.light,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageHeader(title: l10n.settingsTitle),
          const SizedBox(height: 6),
          SettingsSectionLabel(l10n.settingsSectionNotification),
          const SizedBox(height: 14),
          SettingsCard(
            children: [
              SettingsRow.text(
                l10n.settingsNotifyAppeared,
                trailing: SkySwitch(
                  value: settings.notifyAppeared,
                  semanticLabel: l10n.settingsNotifyAppeared,
                  onChanged: (v) => MemberService.updateSettings({'notifyAppeared': v}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsSectionLabel(l10n.settingsSectionRange),
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
              l10n.settingsRangeNote,
              style: AppTextStyles.note(),
            ),
          ),
          const SizedBox(height: 14),
          SettingsSectionLabel(l10n.settingsSectionOther),
          const SizedBox(height: 14),
          SettingsCard(
            children: [
              SettingsRow.text(
                l10n.settingsQuietHours,
                subtitle: l10n.settingsQuietHoursNote,
                trailing: SettingsValue(settings.quietHours?.label ?? l10n.none),
                onTap: () => _editQuietHours(settings.quietHours),
              ),
              SettingsRow.text(
                l10n.settingsRecord,
                trailing: _seenDays == null ? null : SettingsValue(l10n.daysCount(_seenDays!)),
                onTap: () => AppRoutes.openRecord(context),
              ),
              SettingsRow.text(
                l10n.settingsPlaces,
                trailing: SettingsValue(places.isEmpty ? l10n.currentPlace : places.first.label),
                onTap: () => AppRoutes.openPlaces(context),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // デザインにない行。仕様書の「デザインしない画面」（利用規約、プライバシーポリシー、データの出典）への入り口
          SettingsSectionLabel(l10n.settingsSectionAbout),
          const SizedBox(height: 14),
          SettingsCard(
            children: [
              SettingsRow.text(l10n.settingsHowToUse, onTap: () => AppRoutes.openIntro(context)),
              SettingsRow.text(l10n.settingsDataSource, onTap: () => AppRoutes.openDataSource(context)),
              SettingsRow.text(
                l10n.settingsTerms,
                onTap: () => launchUrl(SettingsScreen.termsOfUse, mode: LaunchMode.externalApplication),
              ),
              SettingsRow.text(
                l10n.settingsPrivacy,
                onTap: () => launchUrl(SettingsScreen.privacyPolicy, mode: LaunchMode.externalApplication),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SettingsCard(
            children: [
              SettingsRow.text(
                l10n.settingsDeleteData,
                subtitle: _deleting ? l10n.settingsDeleting : l10n.settingsDeleteDataNote,
                onTap: _deleting ? null : _confirmDeleteData,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (isPlus)
            // Plus の人は、プランや期限の確認と解約の入口へ
            SettingsCard(
              children: [
                SettingsRow.text(
                  'Plus',
                  subtitle: l10n.settingsPlusManage,
                  trailing: SettingsValue(l10n.settingsPlusInUse),
                  onTap: () => AppRoutes.openPlus(context),
                ),
              ],
            )
          else
            _PlusBanner(onTap: () => AppRoutes.openPlus(context)),
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
    final l10n = AppLocalizations.of(context);
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
                    if (locked) ...[
                      const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.text),
                      const SizedBox(width: 6)
                    ],
                    Text(
                      label,
                      style: AppTextStyles.body(color: selected ? Colors.white : AppColors.text).copyWith(
                          fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w400, height: 1.2),
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
            option(SkyRules.freeRangeKm.round(), l10n.kmValue(30)),
            const SizedBox(width: 6),
            option(SkyRules.plusRangeKm.round(), isPlus ? l10n.kmValue(90) : l10n.rangePlusOption(90), locked: !isPlus),
          ],
        ),
      ),
    );
  }
}

/// 「Plus で、もっと遠くまで見張る」（予告通知をやめたので「もっと早く」は外した。2026-10-22）
class _PlusBanner extends StatelessWidget {
  final VoidCallback onTap;

  const _PlusBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
                child: Text(l10n.settingsPlusBanner, style: AppTextStyles.button(fontSize: 15)),
              ),
              Text(l10n.freeTrial7Days, style: AppTextStyles.body(color: Colors.white).copyWith(fontSize: 13, height: 1.2)),
            ],
          ),
        ),
      ),
    );
  }
}
