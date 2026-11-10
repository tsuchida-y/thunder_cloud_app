import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja')
  ];

  /// No description provided for @appName.
  ///
  /// In ja, this message translates to:
  /// **'入道雲サーチ'**
  String get appName;

  /// No description provided for @welcomeLead.
  ///
  /// In ja, this message translates to:
  /// **'あなたの場所から見える空に入道雲が現れたら、どの方角かをお知らせします。'**
  String get welcomeLead;

  /// No description provided for @welcomeLocationTitle.
  ///
  /// In ja, this message translates to:
  /// **'位置情報（アプリの使用中）'**
  String get welcomeLocationTitle;

  /// No description provided for @welcomeLocationBody.
  ///
  /// In ja, this message translates to:
  /// **'開いた場所の空を調べ、その場所の空を見張ります。'**
  String get welcomeLocationBody;

  /// No description provided for @welcomeNotificationTitle.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get welcomeNotificationTitle;

  /// No description provided for @welcomeNotificationBody.
  ///
  /// In ja, this message translates to:
  /// **'入道雲が見えたときに、1つの雲につき1回だけお知らせします。'**
  String get welcomeNotificationBody;

  /// No description provided for @welcomeContinue.
  ///
  /// In ja, this message translates to:
  /// **'続ける'**
  String get welcomeContinue;

  /// No description provided for @welcomeLaterNote.
  ///
  /// In ja, this message translates to:
  /// **'移動先の空も見張る設定は、あとでご案内します。'**
  String get welcomeLaterNote;

  /// No description provided for @cancel.
  ///
  /// In ja, this message translates to:
  /// **'やめる'**
  String get cancel;

  /// No description provided for @none.
  ///
  /// In ja, this message translates to:
  /// **'なし'**
  String get none;

  /// No description provided for @currentPlace.
  ///
  /// In ja, this message translates to:
  /// **'いまいる場所'**
  String get currentPlace;

  /// No description provided for @daysCount.
  ///
  /// In ja, this message translates to:
  /// **'{count}日'**
  String daysCount(int count);

  /// No description provided for @kmValue.
  ///
  /// In ja, this message translates to:
  /// **'{km}km'**
  String kmValue(int km);

  /// No description provided for @rangePlusOption.
  ///
  /// In ja, this message translates to:
  /// **'{km}km（Plus）'**
  String rangePlusOption(int km);

  /// No description provided for @freeTrial7Days.
  ///
  /// In ja, this message translates to:
  /// **'7日間無料'**
  String get freeTrial7Days;

  /// No description provided for @settingsTitle.
  ///
  /// In ja, this message translates to:
  /// **'設定'**
  String get settingsTitle;

  /// No description provided for @settingsSectionNotification.
  ///
  /// In ja, this message translates to:
  /// **'通知'**
  String get settingsSectionNotification;

  /// No description provided for @settingsNotifyAppeared.
  ///
  /// In ja, this message translates to:
  /// **'入道雲が見えたら知らせる'**
  String get settingsNotifyAppeared;

  /// No description provided for @settingsSectionRange.
  ///
  /// In ja, this message translates to:
  /// **'どこまでの空を見守るか'**
  String get settingsSectionRange;

  /// No description provided for @settingsRangeNote.
  ///
  /// In ja, this message translates to:
  /// **'60kmより遠い雲は「見えるかもしれません」とお知らせします。山や建物で隠れることもあります。'**
  String get settingsRangeNote;

  /// No description provided for @settingsSectionOther.
  ///
  /// In ja, this message translates to:
  /// **'そのほか'**
  String get settingsSectionOther;

  /// No description provided for @settingsQuietHours.
  ///
  /// In ja, this message translates to:
  /// **'通知しない時間'**
  String get settingsQuietHours;

  /// No description provided for @settingsQuietHoursNote.
  ///
  /// In ja, this message translates to:
  /// **'空が暗いあいだ（夜）は自動で休みます'**
  String get settingsQuietHoursNote;

  /// No description provided for @settingsRecord.
  ///
  /// In ja, this message translates to:
  /// **'記録（見えた雲）'**
  String get settingsRecord;

  /// No description provided for @settingsPlaces.
  ///
  /// In ja, this message translates to:
  /// **'見張る場所'**
  String get settingsPlaces;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In ja, this message translates to:
  /// **'このアプリについて'**
  String get settingsSectionAbout;

  /// No description provided for @settingsHowToUse.
  ///
  /// In ja, this message translates to:
  /// **'使い方'**
  String get settingsHowToUse;

  /// No description provided for @settingsDataSource.
  ///
  /// In ja, this message translates to:
  /// **'データの出典'**
  String get settingsDataSource;

  /// No description provided for @settingsTerms.
  ///
  /// In ja, this message translates to:
  /// **'利用規約'**
  String get settingsTerms;

  /// No description provided for @settingsPrivacy.
  ///
  /// In ja, this message translates to:
  /// **'プライバシーポリシー'**
  String get settingsPrivacy;

  /// No description provided for @settingsDeleteData.
  ///
  /// In ja, this message translates to:
  /// **'データを削除'**
  String get settingsDeleteData;

  /// No description provided for @settingsDeleting.
  ///
  /// In ja, this message translates to:
  /// **'削除しています…'**
  String get settingsDeleting;

  /// No description provided for @settingsDeleteDataNote.
  ///
  /// In ja, this message translates to:
  /// **'見張る場所・設定・記録をサーバーから消します'**
  String get settingsDeleteDataNote;

  /// No description provided for @settingsDeleteConfirmTitle.
  ///
  /// In ja, this message translates to:
  /// **'データを削除しますか'**
  String get settingsDeleteConfirmTitle;

  /// No description provided for @settingsDeleteConfirmBody.
  ///
  /// In ja, this message translates to:
  /// **'見張る場所、設定、通知の宛先、見えた雲の記録を、サーバーから削除します。元には戻せません。\n\nPlus の購入は消えません。削除したあとも、Plus はそのまま使えます。'**
  String get settingsDeleteConfirmBody;

  /// No description provided for @settingsDeleteAction.
  ///
  /// In ja, this message translates to:
  /// **'削除する'**
  String get settingsDeleteAction;

  /// No description provided for @settingsDeletedTitle.
  ///
  /// In ja, this message translates to:
  /// **'削除しました'**
  String get settingsDeletedTitle;

  /// No description provided for @settingsDeletedBody.
  ///
  /// In ja, this message translates to:
  /// **'もう一度はじめから使えます。'**
  String get settingsDeletedBody;

  /// No description provided for @settingsDeleteFailed.
  ///
  /// In ja, this message translates to:
  /// **'削除できませんでした。通信を確かめて、もう一度お試しください。'**
  String get settingsDeleteFailed;

  /// No description provided for @settingsPlusManage.
  ///
  /// In ja, this message translates to:
  /// **'プランの確認・解約'**
  String get settingsPlusManage;

  /// No description provided for @settingsPlusInUse.
  ///
  /// In ja, this message translates to:
  /// **'利用中'**
  String get settingsPlusInUse;

  /// No description provided for @settingsPlusBanner.
  ///
  /// In ja, this message translates to:
  /// **'Plus で、もっと遠くまで見張る'**
  String get settingsPlusBanner;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
