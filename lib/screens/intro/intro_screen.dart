import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../services/compass/compass_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/common/app_buttons.dart';
import '../../widgets/common/sky_card.dart';
import '../../widgets/common/sky_page.dart';
import '../finder/widgets/finder_drawings.dart';
import '../welcome/welcome_screen.dart';

/// 使い方の紹介（docs/design/Intro.html）
///
/// はじめての起動で、許可のお願い（Welcome）の前に3枚だけ見せる。「スキップ」でいつでも飛ばせる。
/// 設定の「使い方」から開いたときは [fromSettings] が true で、終わったら前の画面に戻る。
class IntroScreen extends StatefulWidget {
  final bool fromSettings;

  /// 最初に開く枚数（0 から。開発中の確かめ用）
  final int initialPage;

  const IntroScreen({super.key, this.fromSettings = false, this.initialPage = 0});

  static const String _doneKey = 'intro_done';

  /// 見せ終わった（またはスキップした）か。許可のお願いを済ませた人（1.0.4 から上げた人を含む）には見せない
  static bool isDone(SharedPreferences prefs) => prefs.getBool(_doneKey) == true || WelcomeScreen.isDone(prefs);

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  static const int _pageCount = 3;

  late final PageController _pages = PageController(initialPage: widget.initialPage);
  late int _index = widget.initialPage;

  bool get _isLast => _index == _pageCount - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (widget.fromSettings) {
      Navigator.of(context).pop();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(IntroScreen._doneKey, true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const WelcomeScreen()));
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _pages.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _back() => _pages.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      gradient: SkyGradient.day,
      scrollable: false,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              children: [
                const Spacer(),
                if (!_isLast)
                  TextLinkButton(
                    label: widget.fromSettings ? AppLocalizations.of(context).close : AppLocalizations.of(context).introSkip,
                    color: Colors.white,
                    onPressed: _finish,
                  ),
              ],
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              onPageChanged: (i) => setState(() => _index = i),
              children: const [_NotifyPage(), _FinderPage(), _PlacesPage()],
            ),
          ),
          const SizedBox(height: 12),
          _Dots(count: _pageCount, index: _index),
          const SizedBox(height: 18),
          Row(
            children: [
              // 2枚目以降は、ひとつ前に戻れる（次への左の小さな丸いボタン）
              if (_index > 0) ...[
                _BackButton(onPressed: _back),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: PrimaryButton(
                  label: _isLast ? (widget.fromSettings ? AppLocalizations.of(context).close : AppLocalizations.of(context).introStart) : AppLocalizations.of(context).introNext,
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 1枚の中身（見出し、説明、絵）
class _Page extends StatelessWidget {
  final String title;
  final String body;
  final Widget picture;

  const _Page({required this.title, required this.body, required this.picture});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Semantics(header: true, child: Text(title, style: AppTextStyles.headline(fontSize: 30))),
              const SizedBox(height: 12),
              Text(body, style: AppTextStyles.body(color: Colors.white).copyWith(fontSize: 16)),
              // 絵は、説明の下の空きの真ん中に置く
              Expanded(
                  child: Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: picture))),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotifyPage extends StatelessWidget {
  const _NotifyPage();

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: AppLocalizations.of(context).introNotifyTitle,
      body: AppLocalizations.of(context).introNotifyBody,
      picture: SkyCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 8),
                Text(AppLocalizations.of(context).appName, style: AppTextStyles.caption()),
                const Spacer(),
                Text(AppLocalizations.of(context).introNow, style: AppTextStyles.caption()),
              ],
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context).introNotifyHeadline, style: AppTextStyles.item().copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(AppLocalizations.of(context).introNotifyDetail, style: AppTextStyles.note()),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _FakeButton(label: AppLocalizations.of(context).seen)),
                const SizedBox(width: 8),
                Expanded(child: _FakeButton(label: AppLocalizations.of(context).notSeen)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 通知の「見えた」「見えなかった」の見せかけ（押せない）
class _FakeButton extends StatelessWidget {
  final String label;

  const _FakeButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.chip, borderRadius: BorderRadius.circular(14)),
        child: Text(label, style: AppTextStyles.item().copyWith(fontSize: 14)),
      ),
    );
  }
}

/// 2枚目。スマホの向きを変えると、矢印が本物の方角ガイドと同じように変わる
///
/// 見本の雲は南東（真北から135°）にあることにする。方位センサーがない端末（シミュレータなど）では、
/// 「右へ 35°」のままの絵を出す。
class _FinderPage extends StatefulWidget {
  const _FinderPage();

  @override
  State<_FinderPage> createState() => _FinderPageState();
}

class _FinderPageState extends State<_FinderPage> {
  static const double _targetDeg = 135;
  static const double _alignedDeg = 10;
  static const double _behindDeg = 150;

  StreamSubscription<Heading>? _sub;
  double? _heading;

  @override
  void initState() {
    super.initState();
    _sub = CompassService.headings(allowMagneticFallback: true).listen((h) {
      if (!mounted) return;
      final previous = _heading;
      // 細かく揺れないよう、前の値に少しずつ寄せる（方角ガイドと同じ）
      final smoothed = previous == null ? h.trueDeg : (previous + angleDiff(previous, h.trueDeg) * 0.25 + 360) % 360;
      setState(() => _heading = smoothed);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heading = _heading;
    final diff = heading == null ? 35.0 : angleDiff(heading, _targetDeg);
    final aligned = heading != null && diff.abs() <= _alignedDeg;
    final behind = heading != null && diff.abs() >= _behindDeg;

    final Widget dial;
    final Widget headline;
    if (aligned) {
      dial = const AlignedDial();
      headline = Text(AppLocalizations.of(context).alignedHere, textAlign: TextAlign.center, style: AppTextStyles.display());
    } else if (behind) {
      dial = TurnDial(diffDeg: diff);
      headline = Text(AppLocalizations.of(context).turnBehind, textAlign: TextAlign.center, style: AppTextStyles.display());
    } else {
      dial = TurnDial(diffDeg: diff);
      headline = Text.rich(
        TextSpan(children: [
          TextSpan(text: diff > 0 ? AppLocalizations.of(context).turnRightPrefix : AppLocalizations.of(context).turnLeftPrefix),
          TextSpan(text: '${diff.abs().round()}°', style: AppTextStyles.number(fontSize: 34, color: Colors.white)),
        ]),
        textAlign: TextAlign.center,
        style: AppTextStyles.display(),
      );
    }

    return _Page(
      title: AppLocalizations.of(context).introFinderTitle,
      body: AppLocalizations.of(context).introFinderBody,
      picture: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: dial),
          const SizedBox(height: 8),
          headline,
          if (heading != null) ...[
            const SizedBox(height: 6),
            Text(AppLocalizations.of(context).introFinderSample,
                textAlign: TextAlign.center, style: AppTextStyles.note(color: Colors.white)),
          ],
        ],
      ),
    );
  }
}

class _PlacesPage extends StatelessWidget {
  const _PlacesPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Page(
      title: l10n.introPlacesTitle,
      body: l10n.introPlacesBody,
      picture: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ChipMock(label: l10n.homeCurrentLocation, icon: Icons.my_location_rounded, selected: true, cloud: true),
              _ChipMock(label: l10n.introMockHome, cloud: true),
              const _ChipMock(label: '＋ Plus', dashed: true),
            ],
          ),
          const SizedBox(height: 16),
          SkyCard(
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _RowMock(text: l10n.homeCloudLine(l10n.dirSE, 42), trailing: l10n.homeVisibleShort, divider: true),
                _RowMock(text: l10n.homeOtherSpotLine(l10n.introMockHome, l10n.dirN, 55), trailing: l10n.homeVisibleShort, cloud: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ホームの場所のチップの見せかけ（押せない）
class _ChipMock extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final bool cloud;
  final bool dashed;

  const _ChipMock({required this.label, this.icon, this.selected = false, this.cloud = false, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.accent : Colors.white;
    return ExcludeSemantics(
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.white.withValues(alpha: dashed ? 0.08 : 0.2),
          border: dashed ? Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5) : null,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 14, color: fg), const SizedBox(width: 6)],
            Text(label,
                style: AppTextStyles.body(color: fg).copyWith(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2)),
            if (cloud) ...[const SizedBox(width: 6), Icon(Icons.cloud_rounded, size: 14, color: fg)],
          ],
        ),
      ),
    );
  }
}

/// 雲の一覧の1行の見せかけ（押せない）
class _RowMock extends StatelessWidget {
  final String text;
  final String trailing;
  final bool cloud;
  final bool divider;

  const _RowMock({required this.text, required this.trailing, this.cloud = false, this.divider = false});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: divider ? const Border(bottom: BorderSide(color: AppColors.dividerOnCard)) : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              if (cloud)
                const Icon(Icons.cloud_rounded, size: 16, color: AppColors.accent)
              else
                const SizedBox.square(
                  dimension: 16,
                  child: DecoratedBox(decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle)),
                ),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: AppTextStyles.item())),
              Text(trailing,
                  style:
                      AppTextStyles.note(color: AppColors.accent).copyWith(fontWeight: FontWeight.w700, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;

  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: AppLocalizations.of(context).introPageOf(index + 1, count),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == index ? 22 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: i == index ? AppColors.primary : AppColors.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
        ],
      ),
    );
  }
}

/// ひとつ前に戻る丸いボタン（直径48、タップできる大きさは44以上）
class _BackButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _BackButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: AppLocalizations.of(context).introBack,
      excludeSemantics: true,
      child: Material(
        color: Colors.white.withValues(alpha: 0.9),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox.square(
            dimension: 48,
            child: Icon(Icons.arrow_back_rounded, size: 22, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}
