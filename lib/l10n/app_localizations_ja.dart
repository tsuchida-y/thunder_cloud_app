// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => '入道雲サーチ';

  @override
  String get welcomeLead => 'あなたの場所から見える空に入道雲が現れたら、どの方角かをお知らせします。';

  @override
  String get welcomeLocationTitle => '位置情報（アプリの使用中）';

  @override
  String get welcomeLocationBody => '開いた場所の空を調べ、その場所の空を見張ります。';

  @override
  String get welcomeNotificationTitle => '通知';

  @override
  String get welcomeNotificationBody => '入道雲が見えたときに、1つの雲につき1回だけお知らせします。';

  @override
  String get welcomeContinue => '続ける';

  @override
  String get welcomeLaterNote => '移動先の空も見張る設定は、あとでご案内します。';

  @override
  String get cancel => 'やめる';

  @override
  String get none => 'なし';

  @override
  String get currentPlace => 'いまいる場所';

  @override
  String daysCount(int count) {
    return '$count日';
  }

  @override
  String kmValue(int km) {
    return '${km}km';
  }

  @override
  String rangePlusOption(int km) {
    return '${km}km（Plus）';
  }

  @override
  String get freeTrial7Days => '7日間無料';

  @override
  String get settingsTitle => '設定';

  @override
  String get settingsSectionNotification => '通知';

  @override
  String get settingsNotifyAppeared => '入道雲が見えたら知らせる';

  @override
  String get settingsSectionRange => 'どこまでの空を見守るか';

  @override
  String get settingsRangeNote =>
      '60kmより遠い雲は「見えるかもしれません」とお知らせします。山や建物で隠れることもあります。';

  @override
  String get settingsSectionOther => 'そのほか';

  @override
  String get settingsQuietHours => '通知しない時間';

  @override
  String get settingsQuietHoursNote => '空が暗いあいだ（夜）は自動で休みます';

  @override
  String get settingsRecord => '記録（見えた雲）';

  @override
  String get settingsPlaces => '見張る場所';

  @override
  String get settingsSectionAbout => 'このアプリについて';

  @override
  String get settingsHowToUse => '使い方';

  @override
  String get settingsDataSource => 'データの出典';

  @override
  String get settingsTerms => '利用規約';

  @override
  String get settingsPrivacy => 'プライバシーポリシー';

  @override
  String get settingsDeleteData => 'データを削除';

  @override
  String get settingsDeleting => '削除しています…';

  @override
  String get settingsDeleteDataNote => '見張る場所・設定・記録をサーバーから消します';

  @override
  String get settingsDeleteConfirmTitle => 'データを削除しますか';

  @override
  String get settingsDeleteConfirmBody =>
      '見張る場所、設定、通知の宛先、見えた雲の記録を、サーバーから削除します。元には戻せません。\n\nPlus の購入は消えません。削除したあとも、Plus はそのまま使えます。';

  @override
  String get settingsDeleteAction => '削除する';

  @override
  String get settingsDeletedTitle => '削除しました';

  @override
  String get settingsDeletedBody => 'もう一度はじめから使えます。';

  @override
  String get settingsDeleteFailed => '削除できませんでした。通信を確かめて、もう一度お試しください。';

  @override
  String get settingsPlusManage => 'プランの確認・解約';

  @override
  String get settingsPlusInUse => '利用中';

  @override
  String get settingsPlusBanner => 'Plus で、もっと遠くまで見張る';
}
