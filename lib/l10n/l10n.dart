import 'dart:ui';

import 'app_localizations.dart';

/// context を持たない所（モデル、時刻の文、サービス）から、いまの言語の文言を引く入口。
///
/// アプリの根（MaterialApp の builder）が、画面で使っている言語に合わせて [update] する。
/// まだ更新されていないとき（起動の直後、ウィジェットなど）は、端末の言語を見る（日本語・英語以外は日本語）。
class L {
  L._();

  static AppLocalizations? _current;

  static AppLocalizations get t => _current ?? forLocale(PlatformDispatcher.instance.locale);

  static void update(AppLocalizations l10n) => _current = l10n;

  static AppLocalizations forLocale(Locale locale) {
    return AppLocalizations.supportedLocales.any((l) => l.languageCode == locale.languageCode)
        ? lookupAppLocalizations(Locale(locale.languageCode))
        : lookupAppLocalizations(const Locale('ja'));
  }

  /// 英語のときだけ英語の表記にしたい処理（場所の名前など）向け
  static bool get isEnglish => t.localeName == 'en';

  /// 場所の名前を調べるときの言語
  static String get placeLocaleIdentifier => isEnglish ? 'en_US' : 'ja_JP';
}
