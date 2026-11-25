import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_cloud_app/services/analytics/analytics_route_observer.dart';
import 'package:thunder_cloud_app/services/analytics/analytics_service.dart';

/// 送ったものを覚えておくだけの送り先
class _RecordingBackend implements AnalyticsBackend {
  final List<String> log = [];
  bool fail = false;

  @override
  Future<void> logEvent(String name, Map<String, Object>? parameters) async {
    if (fail) throw Exception('送れない');
    log.add('event:$name ${parameters ?? {}}');
  }

  @override
  Future<void> logScreenView(String screenName) async {
    if (fail) throw Exception('送れない');
    log.add('screen:$screenName');
  }

  @override
  Future<void> setUserProperty(String name, String? value) async => log.add('user:$name=$value');

  @override
  Future<void> setCrashKey(String key, String value) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingBackend backend;

  setUp(() {
    backend = _RecordingBackend();
    AnalyticsService.attach(backend);
  });

  tearDown(() => AnalyticsService.attach(null));

  test('つなぐ前（テストや開発中）は何も送らず、落ちもしない', () async {
    AnalyticsService.attach(null);
    AnalyticsService.screen('home');
    AnalyticsService.cloudReport(seen: true, source: 'finder');
    await pumpEventQueue();
    expect(backend.log, isEmpty);
  });

  test('イベント名とパラメータは決まった値だけを送る', () async {
    AnalyticsService.permissionResult('location', granted: false);
    AnalyticsService.cloudReport(seen: true, source: 'notification_button');
    AnalyticsService.purchaseResult('monthly', 'cancelled');
    await pumpEventQueue();
    expect(backend.log, [
      'event:permission_result {kind: location, result: denied}',
      'event:cloud_report {answer: seen, source: notification_button}',
      'event:purchase_result {product: monthly, result: cancelled}',
    ]);
  });

  test('裏に回ったときに、最後の画面と直前の操作を送る', () async {
    AnalyticsService.screen('finder');
    AnalyticsService.finderAligned(4);
    AnalyticsService.appBackground();
    await pumpEventQueue();
    expect(backend.log.last, startsWith('event:app_background {last_screen: finder, last_action: finder_aligned, session_seconds: '));
  });

  test('送るのに失敗しても、例外を外に出さない', () async {
    backend.fail = true;
    AnalyticsService.screen('home');
    AnalyticsService.errorShown('network');
    await pumpEventQueue();
    expect(backend.log, isEmpty);
    expect(AnalyticsService.lastScreen, 'home');
    expect(AnalyticsService.lastAction, 'error_shown');
  });

  testWidgets('名前の付いた画面とシートの表示を送り、戻ったら戻った先の画面を送る', (tester) async {
    AnalyticsService.rootScreen = 'home';
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      navigatorObservers: [AnalyticsRouteObserver()],
      home: const SizedBox(),
    ));
    navigator.currentState!.push(MaterialPageRoute<void>(
      settings: const RouteSettings(name: 'settings'),
      builder: (_) => const SizedBox(),
    ));
    await tester.pumpAndSettle();
    // 名前のない確認の画面は数えない。閉じても送らない
    navigator.currentState!.push(DialogRoute<void>(context: navigator.currentContext!, builder: (_) => const SizedBox()));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(backend.log, ['screen:home', 'screen:settings', 'screen:home']);
  });
}
