import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_cloud_app/l10n/app_localizations.dart';
import 'package:thunder_cloud_app/screens/home/always_allow_sheet.dart';
import 'package:thunder_cloud_app/screens/welcome/welcome_screen.dart';

/// 許可のお願いの前に出す私たちの案内は、先送りできないようにする（App Store 審査 5.1.1(iv)、2026-11-06 に却下された）。
void main() {
  testWidgets('はじめての起動: 許可のお願いに進むボタンだけで、先送りするボタンはない', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ja'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: WelcomeScreen(),
    ));

    expect(find.text('続ける'), findsOneWidget);
    expect(find.text('許可してはじめる'), findsNothing); // 許可を決めさせるような言葉にしない（「続ける」「次へ」にする）
    expect(find.text('あとで設定する'), findsNothing);
    expect(find.textContaining('あとで'), findsOneWidget); // 「移動先の空も見張る設定は、あとでご案内します。」の案内文だけ
  });

  testWidgets('英語の端末: 同じ作りで、ボタンは「Continue」だけ', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: WelcomeScreen(),
    ));

    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Thunderhead Watch'), findsOneWidget);
    expect(find.text('続ける'), findsNothing);
  });

  testWidgets('「常に」のお願いの案内: 許可のお願いに進むボタンだけで、閉じて先送りできない', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => AlwaysAllowSheet.show(context, placeName: '滝沢市', onAllow: () async {}),
            child: const Text('開く'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    expect(find.text('続ける'), findsOneWidget);
    expect(find.text('「常に」にする'), findsNothing);
    expect(find.text('いまのままにする'), findsNothing);

    // 外側をタップしても、下へ引いても閉じない
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('続ける'), findsOneWidget);
    await tester.drag(find.text('続ける'), const Offset(0, 500));
    await tester.pumpAndSettle();
    expect(find.text('続ける'), findsOneWidget);
  });
}
