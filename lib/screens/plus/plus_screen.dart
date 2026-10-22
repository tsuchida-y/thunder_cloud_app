import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/member/member_service.dart';
import '../../services/plus/plus_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../utils/logger.dart';
import '../../widgets/common/app_buttons.dart';
import '../../widgets/common/sky_page.dart';
import '../settings/settings_screen.dart';

/// Plus のご案内（docs/design/Plus.html）
///
/// ストアの審査のため、購入ボタンのすぐそばに「無料期間のあとの値段」と「自動更新」を出す（CLAUDE.md）。
/// 無料体験を使えない人には「無料で試す」を出さない。値段はストアの値段を使う。
class PlusScreen extends StatefulWidget {
  const PlusScreen({super.key});

  @override
  State<PlusScreen> createState() => _PlusScreenState();
}

class _PlusScreenState extends State<PlusScreen> {
  PlusPlans? _plans;
  bool _loading = true;
  bool _annual = true;
  bool _busy = false;
  bool _isPlus = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _serverSub;

  @override
  void initState() {
    super.initState();
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

  @override
  void dispose() {
    _serverSub?.cancel();
    super.dispose();
  }

  void _toast(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _purchase() async {
    final plans = _plans;
    if (plans == null) return;
    setState(() => _busy = true);
    try {
      final ok = await PlusService.purchase(_annual ? plans.annual : plans.monthly);
      if (ok && mounted) setState(() => _isPlus = true);
    } catch (e) {
      AppLogger.warning('購入に失敗: $e', tag: 'PlusScreen');
      if (mounted) _toast('購入できませんでした。時間をおいて、もう一度お試しください。');
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
        _toast('復元できる Plus の購入が見つかりませんでした。');
      }
    } catch (e) {
      if (mounted) _toast('復元できませんでした。時間をおいて、もう一度お試しください。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final plans = _plans;
    final annualPrice = plans == null ? '1,200円' : _yen(plans.annual.storeProduct);
    final monthlyPrice = plans == null ? '200円' : _yen(plans.monthly.storeProduct);
    final perMonth = plans == null ? '100円' : _perMonth(plans.annual.storeProduct);
    final trial = plans != null && (_annual ? plans.annualTrial : plans.monthlyTrial);
    final selectedPrice = _annual ? '年額$annualPrice' : '月額$monthlyPrice';

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
              semanticLabel: '閉じる',
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          Text('PLUS', style: AppTextStyles.number(fontSize: 14, color: Colors.white).copyWith(letterSpacing: 1.4)),
          const SizedBox(height: 8),
          Semantics(
            header: true,
            child: Text(
              // 予告通知をやめたので「もっと早く」は外した（2026-10-22、docs/将来の検討.md）
              'もっと遠くの入道雲まで、\n見張る。',
              style: AppTextStyles.headline(fontSize: 28).copyWith(height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          const _FeatureCard(),
          const SizedBox(height: 12),
          if (_isPlus)
            _PlusActive()
          else ...[
            Row(
              children: [
                Expanded(
                  child: _PlanButton(
                    selected: _annual,
                    badge: 'おすすめ',
                    title: '年額 $annualPrice',
                    subtitle: '月あたり$perMonth',
                    onTap: () => setState(() => _annual = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _PlanButton(
                    selected: !_annual,
                    title: '月額 $monthlyPrice',
                    subtitle: 'いつでも解約できます',
                    onTap: () => setState(() => _annual = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _BuyButton(
              title: trial ? '7日間 無料で試す' : 'Plus をはじめる',
              // 購入ボタンのすぐそばに、無料期間のあとの値段と自動更新を出す
              subtitle: trial ? 'そのあと$selectedPrice（自動更新）' : '$selectedPrice（自動更新）',
              onPressed: _busy || _loading || plans == null ? null : _purchase,
            ),
            if (!_loading && plans == null) ...[
              const SizedBox(height: 8),
              Text(
                'いまは購入の準備中です。',
                textAlign: TextAlign.center,
                style: AppTextStyles.note(),
              ),
            ],
          ],
          const SizedBox(height: 12),
          Text(
            trial
                ? '終了24時間前までの解約なら、料金はかかりません。\n更新はストアの設定からいつでも止められます。'
                : '期間が終わる24時間前までに解約しないと、自動で更新されます。\n更新はストアの設定からいつでも止められます。',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption().copyWith(height: 1.6),
          ),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              TextLinkButton(label: '購入を復元', color: AppColors.accent, onPressed: _busy ? null : _restore),
              Text('・', style: AppTextStyles.caption()),
              TextLinkButton(
                label: '利用規約',
                color: AppColors.accent,
                onPressed: () => launchUrl(SettingsScreen.termsOfUse, mode: LaunchMode.externalApplication),
              ),
              Text('・', style: AppTextStyles.caption()),
              TextLinkButton(
                label: 'プライバシー',
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
    if (product.currencyCode != 'JPY') return product.priceString;
    return '${_comma(product.price.round())}円';
  }

  static String _perMonth(StoreProduct annual) {
    if (annual.currencyCode != 'JPY') return '${annual.currencyCode} ${(annual.price / 12).toStringAsFixed(2)}';
    return '${_comma((annual.price / 12).round())}円';
  }

  static String _comma(int value) =>
      value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

/// Plus でできること
class _FeatureCard extends StatelessWidget {
  const _FeatureCard();

  @override
  Widget build(BuildContext context) {
    const features = [
      (Icons.radar_rounded, '90km先まで見張る', '無料は30kmまで'),
      (Icons.place_outlined, 'いまいる場所＋3か所', '家や学校、職場の空も見張る'),
      (Icons.widgets_outlined, 'ホーム画面のウィジェット', 'アプリを開かずに方角と距離が分かる'),
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

/// 年額・月額の選択
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

/// すでに Plus のとき
class _PlusActive extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.card)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Text(
          'Plus を使っています。ありがとうございます。\n更新や解約は、ストアの設定から行えます。',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(),
        ),
      ),
    );
  }
}
