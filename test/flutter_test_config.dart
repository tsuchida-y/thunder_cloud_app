import 'dart:async';
import 'dart:ui';

import 'package:thunder_cloud_app/l10n/app_localizations.dart';
import 'package:thunder_cloud_app/l10n/l10n.dart';

/// テストは日本語で動かす（端末の言語に左右されないように）。英語を確かめるテストは、自分で L.update する。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  L.update(lookupAppLocalizations(const Locale('ja')));
  await testMain();
}
