import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_cloud_app/widgets/common/cloud_loading.dart';
import 'package:thunder_cloud_app/widgets/common/loading_view.dart';

/// 読み込み画面を、動きを減らす設定のあり・なしで出す
Widget _app({required bool reduceMotion, Widget child = const LoadingView()}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('読み込み画面に一辺64の雲と「読み込み中」が出て、雲は動き続ける', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: false));
    expect(find.byType(CloudLoading), findsOneWidget);
    expect(tester.getSize(find.byType(CloudLoading)), const Size.square(64));
    expect(find.text('読み込み中'), findsOneWidget);

    // 湧き上がり（1.4秒）のあとも、くり返し（2.4秒ごと）が続く
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isTrue);

    // 画面を外したら止まる（データが届いたらすぐ次の画面に切り替えられる）
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('動きを減らす設定では、できあがった雲を止めて出す', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: true));
    expect(find.byType(CloudLoading), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('読み上げは「読み込んでいます」だけ', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_app(reduceMotion: true));
    expect(find.bySemanticsLabel(LoadingView.semanticLabel), findsOneWidget);
    expect(find.bySemanticsLabel('読み込み中'), findsNothing);
    semantics.dispose();
  });
}
