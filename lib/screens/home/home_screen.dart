import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/finder_target.dart';

import '../../navigation/app_routes.dart';
import '../../services/notification/cloud_notifications.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/time_text.dart';
import '../../widgets/common/app_buttons.dart';
import '../../widgets/common/sky_card.dart';
import '../../widgets/common/sky_page.dart';
import '../../widgets/common/source_note.dart';
import 'always_allow_sheet.dart';
import 'home_controller.dart';
import 'widgets/home_parts.dart';
import 'widgets/sky_illustrations.dart';
import 'widgets/sky_radar.dart';

/// ホーム（docs/design/Main.html, Empty.html, Night.html, Offline.html, NoPermission.html）
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeController _controller = HomeController();
  StreamSubscription<FinderTarget>? _openedSub;

  @override
  void initState() {
    super.initState();
    _controller.onAskAlways = _askAlways;
    _controller.start();
    // 通知から開いたときは、方角ガイドを直接開く
    _openedSub = CloudNotifications.opened.listen(_openFromNotification);
    final pending = CloudNotifications.takeLaunchTarget();
    if (pending != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openFromNotification(pending));
  }

  void _openFromNotification(FinderTarget target) {
    if (!mounted) return;
    AppRoutes.backToHome(context);
    AppRoutes.openFinder(context, target);
  }

  void _askAlways() {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return;
    AlwaysAllowSheet.show(context, placeName: _controller.state.placeName, onAllow: _controller.requestAlways);
  }

  @override
  void dispose() {
    _openedSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final now = DateTime.now();
        return switch (state.mode) {
          HomeMode.loading => _LoadingView(state: state),
          HomeMode.clouds => _CloudsView(state: state, now: now),
          HomeMode.empty => _EmptyView(state: state, now: now),
          HomeMode.night => _NightView(state: state, now: now),
          HomeMode.offline => _OfflineView(state: state, now: now, onRetry: _controller.retry),
          HomeMode.noPermission => _NoPermissionView(state: state, controller: _controller),
        };
      },
    );
  }
}

/// 「3分前に空を見ました ・ 出典：気象庁」
class _SkyFooter extends StatelessWidget {
  final HomeState state;
  final DateTime now;

  const _SkyFooter({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    final observedAt = state.observedAt;
    return SourceNote(prefix: observedAt == null ? null : '${TimeText.ago(observedAt, now)}に空を見ました');
  }
}

class _LoadingView extends StatelessWidget {
  final HomeState state;

  const _LoadingView({required this.state});

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      gradient: SkyGradient.calm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeHeader(label: HomeHeader.skyOf(state.placeName)),
          const Expanded(
            child: Center(
              child: SizedBox.square(
                dimension: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white, semanticsLabel: '空を確かめています'),
              ),
            ),
          ),
          const SourceNote(),
        ],
      ),
    );
  }
}

/// 入道雲が見えているとき（Main.html）
class _CloudsView extends StatelessWidget {
  final HomeState state;
  final DateTime now;

  const _CloudsView({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    final nearest = state.clouds.first;
    final body = nearest.maybeVisible
        ? '約${nearest.roundedKm}km先なので、見えるかもしれません。${nearest.fistsLabel}くらいの高さに立っています。'
        : '約${nearest.roundedKm}km先。${nearest.fistsLabel}くらいの高さに立っています。';
    return SkyPage(
      gradient: SkyGradient.day,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeHeader(label: HomeHeader.skyOf(state.placeName)),
          const SizedBox(height: 14),
          HomeHeadline(
            badge: StatusBadge(
              text: nearest.maybeVisible ? '見えるかもしれません' : 'いま、見えています',
              icon: Icons.flare_rounded,
              foreground: AppColors.accent,
              background: Colors.white,
            ),
            title: '${nearest.directionName}の空に、\n入道雲。',
            body: body,
            titleSize: 32,
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Center(child: SkyRadar(clouds: state.clouds, rangeKm: state.rangeKm)),
          ),
          const Spacer(),
          const SizedBox(height: 14),
          PrimaryButton(
            label: '雲の方角を調べる',
            icon: Icons.explore_outlined,
            onPressed: () => AppRoutes.openFinder(context, FinderTarget.fromView(nearest)),
          ),
          const SizedBox(height: 14),
          CloudListCard(clouds: state.clouds),
          const SizedBox(height: 14),
          _SkyFooter(state: state, now: now),
        ],
      ),
    );
  }
}

/// 入道雲がないとき（Empty.html）
class _EmptyView extends StatelessWidget {
  final HomeState state;
  final DateTime now;

  const _EmptyView({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      gradient: SkyGradient.calm,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeHeader(label: HomeHeader.skyOf(state.placeName)),
          const SizedBox(height: 16),
          HomeHeadline(
            badge: StatusBadge(
              text: '空を見守っています',
              foreground: AppColors.text,
              background: Colors.white.withValues(alpha: 0.85),
            ),
            title: 'いまは、\n静かな空です。',
            body: '入道雲が現れたら、すぐにお知らせします。',
          ),
          const SizedBox(height: 40),
          Center(child: SkyRadar(clouds: const [], rangeKm: state.rangeKm, size: 280, showAllDirections: false)),
          const Spacer(),
          const SizedBox(height: 16),
          _SkyFooter(state: state, now: now),
        ],
      ),
    );
  }
}

/// 夜（Night.html）
class _NightView extends StatelessWidget {
  final HomeState state;
  final DateTime now;

  const _NightView({required this.state, required this.now});

  @override
  Widget build(BuildContext context) {
    final sunrise = state.nextSunrise;
    final resume = sunrise == null ? '' : '${TimeText.morning(sunrise, now)}、';
    final today = state.todaysCloud;
    return SkyPage(
      gradient: SkyGradient.night,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeHeader(label: HomeHeader.skyOf(state.placeName), showRecord: false),
          const SizedBox(height: 16),
          HomeHeadline(
            badge: const StatusBadge(
              text: '見張りはお休み中',
              foreground: Color(0xFF14295A),
              background: Color(0xFFBFE3FF),
            ),
            title: 'いまは夜。\n空が暗くて見えません。',
            body: '$resume明るくなったら見張りを再開します。夜のあいだは通知しません。',
          ),
          const Expanded(
            child: Center(
              child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: NightIllustration()),
            ),
          ),
          if (today != null)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('きょう見えた入道雲',
                        style: AppTextStyles.body(color: Colors.white).copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      '${TimeText.clock(today.from)} から ${TimeText.clock(today.to)} まで、'
                      '${today.directionName}の空（約${today.distanceKm}km先）',
                      style: AppTextStyles.body(color: Colors.white).copyWith(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 通信できないとき（Offline.html）
class _OfflineView extends StatelessWidget {
  final HomeState state;
  final DateTime now;
  final VoidCallback onRetry;

  const _OfflineView({required this.state, required this.now, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final last = state.lastSky;
    return SkyPage(
      gradient: SkyGradient.offline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeHeader(label: HomeHeader.skyOf(state.placeName), showRecord: false, showSettings: false),
          const SizedBox(height: 16),
          const HomeHeadline(
            badge: StatusBadge(text: 'オフライン', foreground: Color(0xFF2F4766), background: Colors.white),
            title: '空の情報が\n受け取れません。',
            body: '電波の届く場所で、もう一度読み込んでください。',
          ),
          const Expanded(
            child: Center(
              child: Padding(padding: EdgeInsets.symmetric(vertical: 16), child: OfflineIllustration()),
            ),
          ),
          if (last != null) ...[
            SkyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('最後に見た空（${TimeText.clockWithDate(last.checkedAt, now)}）', style: AppTextStyles.note()),
                  const SizedBox(height: 4),
                  Text(
                    '${last.directionName}の空に入道雲（約${last.distanceKm}km先）',
                    style: AppTextStyles.item().copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text('いまも見えるかは分かりません。', style: AppTextStyles.note()),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          PrimaryButton(label: 'もう一度読み込む', onPressed: onRetry),
        ],
      ),
    );
  }
}

/// 場所が分からないとき（NoPermission.html）
class _NoPermissionView extends StatelessWidget {
  final HomeState state;
  final HomeController controller;

  const _NoPermissionView({required this.state, required this.controller});

  @override
  Widget build(BuildContext context) {
    return SkyPage(
      gradient: SkyGradient.day,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HomeHeader(label: '場所が分かりません', showPin: false, showRecord: false),
          const SizedBox(height: 16),
          const HomeHeadline(
            title: 'このままでは\n空を見張れません。',
            body: '下の2つをオンにすると、入道雲が現れたときにお知らせできます。',
          ),
          const Spacer(),
          const SizedBox(height: 16),
          if (state.locationOff) ...[
            _PermissionCard(
              icon: Icons.place_outlined,
              title: '位置情報がオフです',
              body: '設定アプリで「位置情報」を「使用中のみ」か「常に」にしてください。',
              button: PrimaryButton(label: '設定アプリを開く', compact: true, onPressed: controller.openLocationSettings),
            ),
            const SizedBox(height: 16),
          ],
          if (state.notificationsOff) ...[
            _PermissionCard(
              icon: Icons.notifications_none_rounded,
              title: '通知がオフです',
              body: 'アプリを開いたときだけ、雲の場所を確かめられます。',
              button: OutlinePillButton(label: '通知をオンにする', height: 44, onPressed: controller.enableNotifications),
            ),
            const SizedBox(height: 16),
          ],
          Center(
            child: TextLinkButton(
              label: '場所を手で登録する',
              color: AppColors.text,
              onPressed: () => AppRoutes.openPlaces(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget button;

  const _PermissionCard({required this.icon, required this.title, required this.body, required this.button});

  @override
  Widget build(BuildContext context) {
    return SkyCard(
      solid: true,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.accent),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTextStyles.item().copyWith(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 10),
          Text(body, style: AppTextStyles.note()),
          const SizedBox(height: 10),
          button,
        ],
      ),
    );
  }
}
