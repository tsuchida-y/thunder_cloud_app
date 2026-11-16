import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n.dart';
import '../../services/member/member_service.dart';
import '../../services/plus/plus_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/logger.dart';
import '../../utils/time_text.dart';
import '../../widgets/common/app_buttons.dart';
import '../../widgets/common/sky_page.dart';
import '../settings/settings_screen.dart';

/// Plus のご案内（docs/design/Plus.html）
///
/// 月額（7日間無料）と買い切りの2つ（2026-10-27 に年額をやめて買い切りにした）。
/// ストアの審査のため、購入ボタンのすぐそばに「無料期間のあとの値段」と「自動更新」を出す（CLAUDE.md）。
/// 買い切りは自動更新がないので、そのことを出す。無料体験を使えない人には「無料で試す」を出さない。
/// 値段はストアの値段を使う。
class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key});

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  PlusPlans? _plans;
  bool _loading = true;
  bool _lifetime = false;
  bool _busy = false;
  bool _isPlus = false;
  PlusStatus? _status;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _serverSub;

  @override
  void initState() {
    super.initState();
    _loadStatus();
    // ストアで Plus なら、サーバーに届く前でも「Plus を使っています」にする
    _isPlus = PlusService.activeInStore.value;
    PlusService.activeInStore.addListener(_onStoreChanged);
    final uid = MemberService.uid;
    if (uid != null) {
      _serverSub = MemberService.watchServer(uid).listen((doc) {
        if (MemberService.isPlusActive(doc.data(), DateTime.now())) setState(() => _isPlus = true);
      });
    }
    PlusService.plans().then((plans) {
      if (mounted) {
        setState(() {
          _plans = plans;
          _loading = false;
        });
      }
    });
  }

  void _onStoreChanged() {
    if (mounted && PlusService.activeInStore.value) {
      setState(() => _isPlus = true);
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    final status = await PlusService.status();
    if (mounted) setState(() => _status = status);
  }

  @override
  void dispose() {
    PlusService.activeInStore.removeListener(_onStoreChanged);
    _serverSub?.cancel();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _purchase() async {
    final plans = _plans;
    if (plans == null) return;
    setState(() => _busy = true);
    try {
      final ok = await PlusService.purchase(_lifetime ? plans.lifetime : plans.monthly);
      if (ok && mounted) setState(() => _isPlus = true);
    } catch (e) {
      AppLogger.warning('購入に失敗: $e', tag: 'PlusScreen');
      if (mounted) _toast(L.t.plusPurchaseFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (!PlusService.available) return;
    setState(() => _busy = true);
    try {
      final ok = await PlusService.restore();
      if (!mounted) return;
      if (ok) {
        setState(() => _isPlus = true);
      } else {
        _toast(L.t.plusRestoreNone);
      }
    } catch (e) {
      if (mounted) _toast(L.t.plusRestoreFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final plans = _plans;
    final monthlyPrice = plans == null ? l10n.plusFallbackMonthly : _yen(plans.monthly.storeProduct);
    final lifetimePrice = plans == null ? l10n.plusFallbackLifetime : _yen(plans.lifetime.storeProduct);
    final trial = plans != null && !_lifetime && plans.monthlyTrial;
    final String buyTitle;
    final String buySubtitle;
    if (_lifetime) {
      buyTitle = l10n.plusBuy;
      buySubtitle = l10n.plusBuyLifetimeNote(lifetimePrice);
    } else if (trial) {
      buyTitle = l10n.plusTryFree;
      buySubtitle = l10n.plusTryFreeNote(monthlyPrice);
    } else {
      buyTitle = l10n.plusStart;
      buySubtitle = l10n.plusStartNote(monthlyPrice);
    }

    return SkyPage(
      gradient: SkyGradient.plus,
      padding: const EdgeInsets.fromLTRB(AppSizes.pageGutter, 0, AppSizes.pageGutter, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconTapButton(
              icon: Icons.close_rounded,
              semanticLabel: l10n.close,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Text('PLUS', style: AppTextStyles.number(fontSize: 14, color: Colors.white).copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              // 場所の見せ方_画面一覧.png（2026-10-22）
              l10n.plusHeadline,
              style: AppTextStyles.headline(fontSize: 28).copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          const _FeatureCard(),
          const SizedBox(height: 12),
          if (_isPlus)
            PlusActiveCard(status: _status)
          else ...[
            Row(
              children: [
                Expanded(
                  child: _PlanButton(
                    selected: !_lifetime,
                    badge: l10n.freeTrial7Days,
                    title: l10n.plusPlanMonthly(monthlyPrice),
                    subtitle: l10n.plusPlanMonthlyNote,
                    onTap: () => setState(() => _lifetime = false),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PlanButton(
                    selected: _lifetime,
                    title: l10n.plusPlanLifetime(lifetimePrice),
                    subtitle: l10n.plusPlanLifetimeNote,
                    onTap: () => setState(() => _lifetime = true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BuyButton(
              title: buyTitle,
              // 購入ボタンのすぐそばに、無料期間のあとの値段と自動更新（買い切りは1回だけのお支払い）を出す
              subtitle: buySubtitle,
              onPressed: _busy || _loading || plans == null ? null : _purchase,
            ),
            if (!_loading && plans == null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.plusNotReady,
                textAlign: TextAlign.center,
                style: AppTextStyles.note(),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Text(
            _lifetime
                ? l10n.plusTermsLifetime
                : trial
                    ? l10n.plusTermsTrial
                    : l10n.plusTermsMonthly,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption().copyWith(height: 1.6),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextLinkButton(label: l10n.plusRestore, color: AppColors.accent, onPressed: _busy ? null : _restore),
              Text('・', style: AppTextStyles.caption()),
              TextLinkButton(
                label: l10n.settingsTerms,
                color: AppColors.accent,
                onPressed: () => launchUrl(SettingsScreen.termsOfUse, mode: LaunchMode.externalApplication),
              ),
              Text('・', style: AppTextStyles.caption()),
              TextLinkButton(
                label: l10n.plusPrivacy,
                color: AppColors.accent,
                onPressed: () => launchUrl(SettingsScreen.privacyPolicy, mode: LaunchMode.externalApplication),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 「1,200円」。日本円でなければストアの書き方のまま
  static String _yen(StoreProduct product) {
    if (product.currencyCode != 'JPY' || L.isEnglish) return product.priceString;
    return '${_comma(product.price.round())}円';
  }

  static String _comma(int value) =>
      value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

/// Plus でできること
class _FeatureCard extends StatelessWidget {
  const _FeatureCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final features = [
      (Icons.place_outlined, l10n.plusFeaturePlaces, l10n.plusFeaturePlacesNote),
      (Icons.radar_rounded, l10n.plusFeatureRange, l10n.plusFeatureRangeNote),
      // 画像では「ウィジェットと写真の共有」だが、写真と共有は v2.0 で外した（2026-10-21 決定）ので、ウィジェットだけ
      (Icons.widgets_outlined, l10n.plusFeatureWidget, l10n.plusFeatureWidgetNote),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < features.length; i++)
              DecoratedBox(
                decoration: BoxDecoration(
                  border: i < features.length - 1
                      ? const Border(bottom: BorderSide(color: AppColors.dividerOnCard))
                      : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(features[i].$1, size: 20, color: AppColors.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(features[i].$2, style: AppTextStyles.item().copyWith(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(features[i].$3, style: AppTextStyles.note().copyWith(height: 1.4)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 月額・買い切りの選択
class _PlanButton extends StatelessWidget {
  final bool selected;
  final String? badge;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PlanButton({required this.selected, this.badge, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? AppColors.primary : AppColors.switchOff, width: selected ? 2 : 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 92),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (badge != null) ...[
                    DecoratedBox(
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(999)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: Text(badge!, style: AppTextStyles.caption(color: Colors.white).copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(title, style: AppTextStyles.item().copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 「7日間 無料で試す」（高さ60、2行）
class _BuyButton extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onPressed;

  const _BuyButton({required this.title, required this.subtitle, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: AppTextStyles.button()),
            Text(subtitle, style: AppTextStyles.caption(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

/// すでに Plus のとき。どのプランか、いつまでか、解約の入口を出す（二重に買わないように、購入ボタンは出さない）
///
/// テストで4つの状態（月額・無料体験中・解約済み・買い切り）の表示を確かめるため、公開している。
class PlusActiveCard extends StatelessWidget {
  final PlusStatus? status;

  const PlusActiveCard({super.key, required this.status});

  String _detail(PlusStatus status) {
    final l10n = L.t;
    if (status.lifetime) return l10n.plusActiveLifetime;
    final date = status.expiresAt;
    final day = date == null ? '' : TimeText.fullDate(date);
    if (!status.willRenew) return '${l10n.plusActiveCancelledTitle}\n${l10n.plusActiveCancelledUntil(day)}';
    final trial = status.inTrial ? l10n.plusActiveTrial : l10n.plusActiveMonthly;
    return '$trial\n${l10n.plusRenewsOn(day)}';
  }

  @override
  Widget build(BuildContext context) {
    final status = this.status;
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Column(
          children: [
            Text(AppLocalizations.of(context).plusActiveThanks, textAlign: TextAlign.center, style: AppTextStyles.body()),
            if (status != null) ...[
              const SizedBox(height: 8),
              Text(_detail(status), textAlign: TextAlign.center, style: AppTextStyles.note().copyWith(height: 1.6)),
            ],
            const SizedBox(height: 6),
            if (status?.lifetime ?? false)
              const SizedBox.shrink()
            else ...[
              Text(
                AppLocalizations.of(context).plusActiveManageNote,
                textAlign: TextAlign.center,
                style: AppTextStyles.note(),
              ),
              TextLinkButton(
                label: AppLocalizations.of(context).plusManageSubscription,
                color: AppColors.accent,
                onPressed: () => launchUrl(
                  status?.managementUrl ?? Uri.parse('https://apps.apple.com/account/subscriptions'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
