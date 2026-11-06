import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thunder_cloud_app/screens/plus/plus_screen.dart';
import 'package:thunder_cloud_app/services/plus/plus_service.dart';

/// Plus の画面の「Plus を使っています」の4つの状態（月額・無料体験中・解約済み・買い切り）の表示
///
/// 実機の解約は、サンドボックスの管理画面からしかできず、期限が来るまで確かめられないので、表示の文言と、
/// 管理ボタンが出るかを、ここで確かめる。
void main() {
  final renewAt = DateTime(2026, 11, 6, 11, 55);

  Future<void> show(WidgetTester tester, PlusStatus? status) => tester.pumpWidget(
        MaterialApp(home: Scaffold(body: SingleChildScrollView(child: PlusActiveCard(status: status)))),
      );

  PlusStatus status({bool lifetime = false, bool willRenew = true, bool inTrial = false, DateTime? expiresAt}) => PlusStatus(
        lifetime: lifetime,
        expiresAt: lifetime ? null : (expiresAt ?? renewAt),
        willRenew: willRenew,
        inTrial: inTrial,
        managementUrl: null,
      );

  testWidgets('月額（自動更新）: 更新される日と、管理ボタンが出る', (tester) async {
    await show(tester, status());
    expect(find.text('Plus を使っています。ありがとうございます。'), findsOneWidget);
    expect(find.text('月額（自動更新）\n2026年11月6日に更新されます'), findsOneWidget);
    expect(find.text('サブスクリプションを管理'), findsOneWidget);
    expect(find.text('月額の更新や解約は、ストアの設定から行えます。'), findsOneWidget);
  });

  testWidgets('7日間の無料体験中: 無料体験中と、更新される日が出る', (tester) async {
    await show(tester, status(inTrial: true));
    expect(find.text('7日間の無料体験中\n2026年11月6日に更新されます'), findsOneWidget);
    expect(find.text('サブスクリプションを管理'), findsOneWidget);
  });

  testWidgets('月額（解約済み）: 使える最後の日が出て、料金がかからないと書く。管理ボタンは残る', (tester) async {
    await show(tester, status(willRenew: false));
    expect(find.text('月額（解約済み）\n2026年11月6日まで使えます。それ以降は料金がかかりません'), findsOneWidget);
    expect(find.text('サブスクリプションを管理'), findsOneWidget);
    // 更新されるとは書かない
    expect(find.textContaining('更新されます'), findsNothing);
  });

  testWidgets('買い切り: 期限なし、追加の料金なし。管理ボタンは出ない', (tester) async {
    await show(tester, status(lifetime: true));
    expect(find.text('買い切り（ずっと使えます。追加の料金はかかりません）'), findsOneWidget);
    expect(find.text('サブスクリプションを管理'), findsNothing);
    expect(find.textContaining('更新'), findsNothing);
  });

  testWidgets('契約の情報がまだ取れていないとき: 「使っています」だけ出し、管理ボタンは出す', (tester) async {
    await show(tester, null);
    expect(find.text('Plus を使っています。ありがとうございます。'), findsOneWidget);
    expect(find.text('サブスクリプションを管理'), findsOneWidget);
  });
}
