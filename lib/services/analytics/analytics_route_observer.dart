import 'package:flutter/widgets.dart';

import 'analytics_service.dart';

/// 画面の行き来を見て、画面の表示（screen_view）を送る
///
/// 名前（RouteSettings.name）の付いた画面とシートだけを数える。名前は AppRoutes と各シートの show で付ける。
/// 最初の画面（MaterialApp の home。名前は '/'）は、起動のときに MyApp が [AnalyticsService.rootScreen] に名前を入れる。
/// 戻る操作で前の画面に戻ったときも、戻った先の画面の表示として送る（名前のない確認の画面を閉じたときは送らない）。
class AnalyticsRouteObserver extends NavigatorObserver {
  void _show(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null) return;
    AnalyticsService.screen(name == '/' ? AnalyticsService.rootScreen : name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _show(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != null) _show(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _show(newRoute);
}
