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

  /// No description provided for @dirN.
  ///
  /// In ja, this message translates to:
  /// **'北'**
  String get dirN;

  /// No description provided for @dirNE.
  ///
  /// In ja, this message translates to:
  /// **'北東'**
  String get dirNE;

  /// No description provided for @dirE.
  ///
  /// In ja, this message translates to:
  /// **'東'**
  String get dirE;

  /// No description provided for @dirSE.
  ///
  /// In ja, this message translates to:
  /// **'南東'**
  String get dirSE;

  /// No description provided for @dirS.
  ///
  /// In ja, this message translates to:
  /// **'南'**
  String get dirS;

  /// No description provided for @dirSW.
  ///
  /// In ja, this message translates to:
  /// **'南西'**
  String get dirSW;

  /// No description provided for @dirW.
  ///
  /// In ja, this message translates to:
  /// **'西'**
  String get dirW;

  /// No description provided for @dirNW.
  ///
  /// In ja, this message translates to:
  /// **'北西'**
  String get dirNW;

  /// No description provided for @fistsWhole.
  ///
  /// In ja, this message translates to:
  /// **'こぶし{n}つ'**
  String fistsWhole(int n);

  /// No description provided for @fistsHalfMore.
  ///
  /// In ja, this message translates to:
  /// **'{n, plural, =0{こぶし半分} other{こぶし{n}つ半}}'**
  String fistsHalfMore(int n);

  /// No description provided for @agoMinutes.
  ///
  /// In ja, this message translates to:
  /// **'{n}分前'**
  String agoMinutes(int n);

  /// No description provided for @agoHours.
  ///
  /// In ja, this message translates to:
  /// **'{n}時間前'**
  String agoHours(int n);

  /// No description provided for @agoDays.
  ///
  /// In ja, this message translates to:
  /// **'{n}日前'**
  String agoDays(int n);

  /// No description provided for @morningSameDay.
  ///
  /// In ja, this message translates to:
  /// **'朝 {time} ごろ'**
  String morningSameDay(String time);

  /// No description provided for @morningNextDay.
  ///
  /// In ja, this message translates to:
  /// **'あすの朝 {time} ごろ'**
  String morningNextDay(String time);

  /// No description provided for @skySunny.
  ///
  /// In ja, this message translates to:
  /// **'日が差しています'**
  String get skySunny;

  /// No description provided for @skySometimesSunny.
  ///
  /// In ja, this message translates to:
  /// **'ときどき日が差しています'**
  String get skySometimesSunny;

  /// No description provided for @skyNoSun.
  ///
  /// In ja, this message translates to:
  /// **'日が差していません'**
  String get skyNoSun;

  /// No description provided for @skyTemp.
  ///
  /// In ja, this message translates to:
  /// **'気温{c}℃'**
  String skyTemp(int c);

  /// No description provided for @skyVisibilityMax.
  ///
  /// In ja, this message translates to:
  /// **'見通し{km}km以上'**
  String skyVisibilityMax(int km);

  /// No description provided for @skyVisibility.
  ///
  /// In ja, this message translates to:
  /// **'見通し約{km}km'**
  String skyVisibility(int km);

  /// No description provided for @badgePlace.
  ///
  /// In ja, this message translates to:
  /// **'{place} ・ '**
  String badgePlace(String place);

  /// No description provided for @skyObservedAgo.
  ///
  /// In ja, this message translates to:
  /// **'{ago}に空を見ました'**
  String skyObservedAgo(String ago);

  /// No description provided for @homeCloudBodyMaybe.
  ///
  /// In ja, this message translates to:
  /// **'約{km}km先なので、見えるかもしれません。{fists}くらいの高さに立っています。'**
  String homeCloudBodyMaybe(int km, String fists);

  /// No description provided for @homeCloudBody.
  ///
  /// In ja, this message translates to:
  /// **'約{km}km先。{fists}くらいの高さに立っています。'**
  String homeCloudBody(int km, String fists);

  /// No description provided for @homeBadgeMaybe.
  ///
  /// In ja, this message translates to:
  /// **'見えるかもしれません'**
  String get homeBadgeMaybe;

  /// No description provided for @homeBadgeVisible.
  ///
  /// In ja, this message translates to:
  /// **'いま、見えています'**
  String get homeBadgeVisible;

  /// No description provided for @homeCloudTitle.
  ///
  /// In ja, this message translates to:
  /// **'{direction}の空に、\n入道雲。'**
  String homeCloudTitle(String direction);

  /// No description provided for @homeFindDirection.
  ///
  /// In ja, this message translates to:
  /// **'雲の方角を調べる'**
  String get homeFindDirection;

  /// No description provided for @homeBadgeWatching.
  ///
  /// In ja, this message translates to:
  /// **'空を見守っています'**
  String get homeBadgeWatching;

  /// No description provided for @homeCalmTitle.
  ///
  /// In ja, this message translates to:
  /// **'いまは、\n静かな空です。'**
  String get homeCalmTitle;

  /// No description provided for @homeCalmBody.
  ///
  /// In ja, this message translates to:
  /// **'入道雲が現れたら、すぐにお知らせします。'**
  String get homeCalmBody;

  /// No description provided for @homeBadgeResting.
  ///
  /// In ja, this message translates to:
  /// **'見張りはお休み中'**
  String get homeBadgeResting;

  /// No description provided for @homeNightTitle.
  ///
  /// In ja, this message translates to:
  /// **'いまは夜。\n空が暗くて見えません。'**
  String get homeNightTitle;

  /// No description provided for @homeNightBody.
  ///
  /// In ja, this message translates to:
  /// **'明るくなったら見張りを再開します。夜のあいだは通知しません。'**
  String get homeNightBody;

  /// No description provided for @homeNightBodyResume.
  ///
  /// In ja, this message translates to:
  /// **'{when}、明るくなったら見張りを再開します。夜のあいだは通知しません。'**
  String homeNightBodyResume(String when);

  /// No description provided for @homeTodayCloud.
  ///
  /// In ja, this message translates to:
  /// **'きょう見えた入道雲'**
  String get homeTodayCloud;

  /// No description provided for @homeTodayCloudDetail.
  ///
  /// In ja, this message translates to:
  /// **'{from} から {to} まで、{direction}の空（約{km}km先）'**
  String homeTodayCloudDetail(String from, String to, String direction, int km);

  /// No description provided for @homeOffline.
  ///
  /// In ja, this message translates to:
  /// **'オフライン'**
  String get homeOffline;

  /// No description provided for @homeOfflineTitle.
  ///
  /// In ja, this message translates to:
  /// **'空の情報が\n受け取れません。'**
  String get homeOfflineTitle;

  /// No description provided for @homeOfflineBody.
  ///
  /// In ja, this message translates to:
  /// **'電波の届く場所で、もう一度読み込んでください。'**
  String get homeOfflineBody;

  /// No description provided for @homeLastSky.
  ///
  /// In ja, this message translates to:
  /// **'最後に見た空（{time}）'**
  String homeLastSky(String time);

  /// No description provided for @homeLastCloud.
  ///
  /// In ja, this message translates to:
  /// **'{direction}の空に入道雲（約{km}km先）'**
  String homeLastCloud(String direction, int km);

  /// No description provided for @homeLastUnknown.
  ///
  /// In ja, this message translates to:
  /// **'いまも見えるかは分かりません。'**
  String get homeLastUnknown;

  /// No description provided for @homeReload.
  ///
  /// In ja, this message translates to:
  /// **'もう一度読み込む'**
  String get homeReload;

  /// No description provided for @homeNoPlace.
  ///
  /// In ja, this message translates to:
  /// **'場所が分かりません'**
  String get homeNoPlace;

  /// No description provided for @homeNoPermissionTitle.
  ///
  /// In ja, this message translates to:
  /// **'このままでは\n空を見張れません。'**
  String get homeNoPermissionTitle;

  /// No description provided for @homeNoPermissionBody.
  ///
  /// In ja, this message translates to:
  /// **'下の2つをオンにすると、入道雲が現れたときにお知らせできます。'**
  String get homeNoPermissionBody;

  /// No description provided for @homeLocationOffTitle.
  ///
  /// In ja, this message translates to:
  /// **'位置情報がオフです'**
  String get homeLocationOffTitle;

  /// No description provided for @homeLocationOffBody.
  ///
  /// In ja, this message translates to:
  /// **'設定アプリで「位置情報」を「使用中のみ」か「常に」にしてください。'**
  String get homeLocationOffBody;

  /// No description provided for @homeOpenSettings.
  ///
  /// In ja, this message translates to:
  /// **'設定アプリを開く'**
  String get homeOpenSettings;

  /// No description provided for @homeNotificationOffTitle.
  ///
  /// In ja, this message translates to:
  /// **'通知がオフです'**
  String get homeNotificationOffTitle;

  /// No description provided for @homeNotificationOffBody.
  ///
  /// In ja, this message translates to:
  /// **'アプリを開いたときだけ、雲の場所を確かめられます。'**
  String get homeNotificationOffBody;

  /// No description provided for @homeEnableNotifications.
  ///
  /// In ja, this message translates to:
  /// **'通知をオンにする'**
  String get homeEnableNotifications;

  /// No description provided for @homeAddPlaceManually.
  ///
  /// In ja, this message translates to:
  /// **'場所を手で登録する'**
  String get homeAddPlaceManually;

  /// No description provided for @homeSkyOf.
  ///
  /// In ja, this message translates to:
  /// **'{place}の空'**
  String homeSkyOf(String place);

  /// No description provided for @recordLabel.
  ///
  /// In ja, this message translates to:
  /// **'記録'**
  String get recordLabel;

  /// No description provided for @homeChipWithCloud.
  ///
  /// In ja, this message translates to:
  /// **'{place}、入道雲あり'**
  String homeChipWithCloud(String place);

  /// No description provided for @homeAddPlace.
  ///
  /// In ja, this message translates to:
  /// **'場所を追加'**
  String get homeAddPlace;

  /// No description provided for @homeAddPlacePlus.
  ///
  /// In ja, this message translates to:
  /// **'場所を追加。Plus の機能です'**
  String get homeAddPlacePlus;

  /// No description provided for @homeCurrentLocation.
  ///
  /// In ja, this message translates to:
  /// **'現在地'**
  String get homeCurrentLocation;

  /// No description provided for @homeOtherSpotLine.
  ///
  /// In ja, this message translates to:
  /// **'{name} ・ {direction} ・ {km}km'**
  String homeOtherSpotLine(String name, String direction, int km);

  /// No description provided for @homeMaybeShort.
  ///
  /// In ja, this message translates to:
  /// **'見えるかも'**
  String get homeMaybeShort;

  /// No description provided for @homeVisibleShort.
  ///
  /// In ja, this message translates to:
  /// **'見えています'**
  String get homeVisibleShort;

  /// No description provided for @homeNearestPlace.
  ///
  /// In ja, this message translates to:
  /// **'（{place}）'**
  String homeNearestPlace(String place);

  /// No description provided for @homeNowSky.
  ///
  /// In ja, this message translates to:
  /// **'いまの空'**
  String get homeNowSky;

  /// No description provided for @homeAmedas.
  ///
  /// In ja, this message translates to:
  /// **'近くのアメダス {time}'**
  String homeAmedas(String time);

  /// No description provided for @homeNearestCloud.
  ///
  /// In ja, this message translates to:
  /// **'いちばん近い入道雲'**
  String get homeNearestCloud;

  /// No description provided for @homeNoneNationwide.
  ///
  /// In ja, this message translates to:
  /// **'全国で見つかっていません'**
  String get homeNoneNationwide;

  /// No description provided for @homeNearestLine.
  ///
  /// In ja, this message translates to:
  /// **'{direction} {km}km{place}'**
  String homeNearestLine(String direction, int km, String place);

  /// No description provided for @homeNationwideNote.
  ///
  /// In ja, this message translates to:
  /// **'全国で{count}か所 ・ 押すと一覧'**
  String homeNationwideNote(int count);

  /// No description provided for @homeRecordLink.
  ///
  /// In ja, this message translates to:
  /// **'見えた入道雲の記録'**
  String get homeRecordLink;

  /// No description provided for @homeCloudLine.
  ///
  /// In ja, this message translates to:
  /// **'{direction} ・ {km}km'**
  String homeCloudLine(String direction, int km);

  /// No description provided for @homeSinceMaybe.
  ///
  /// In ja, this message translates to:
  /// **'{since}から ・ 見えるかも'**
  String homeSinceMaybe(String since);

  /// No description provided for @homeSinceVisible.
  ///
  /// In ja, this message translates to:
  /// **'{since}から見えています'**
  String homeSinceVisible(String since);

  /// No description provided for @close.
  ///
  /// In ja, this message translates to:
  /// **'閉じる'**
  String get close;

  /// No description provided for @plusPurchaseFailed.
  ///
  /// In ja, this message translates to:
  /// **'購入できませんでした。時間をおいて、もう一度お試しください。'**
  String get plusPurchaseFailed;

  /// No description provided for @plusRestoreNone.
  ///
  /// In ja, this message translates to:
  /// **'復元できる Plus の購入が見つかりませんでした。'**
  String get plusRestoreNone;

  /// No description provided for @plusRestoreFailed.
  ///
  /// In ja, this message translates to:
  /// **'復元できませんでした。時間をおいて、もう一度お試しください。'**
  String get plusRestoreFailed;

  /// No description provided for @plusFallbackMonthly.
  ///
  /// In ja, this message translates to:
  /// **'200円'**
  String get plusFallbackMonthly;

  /// No description provided for @plusFallbackLifetime.
  ///
  /// In ja, this message translates to:
  /// **'1,200円'**
  String get plusFallbackLifetime;

  /// No description provided for @plusBuy.
  ///
  /// In ja, this message translates to:
  /// **'Plus を買う'**
  String get plusBuy;

  /// No description provided for @plusBuyLifetimeNote.
  ///
  /// In ja, this message translates to:
  /// **'{price}（1回だけのお支払い）'**
  String plusBuyLifetimeNote(String price);

  /// No description provided for @plusTryFree.
  ///
  /// In ja, this message translates to:
  /// **'7日間 無料で試す'**
  String get plusTryFree;

  /// No description provided for @plusTryFreeNote.
  ///
  /// In ja, this message translates to:
  /// **'そのあと月額{price}（自動更新）'**
  String plusTryFreeNote(String price);

  /// No description provided for @plusStart.
  ///
  /// In ja, this message translates to:
  /// **'Plus をはじめる'**
  String get plusStart;

  /// No description provided for @plusStartNote.
  ///
  /// In ja, this message translates to:
  /// **'月額{price}（自動更新）'**
  String plusStartNote(String price);

  /// No description provided for @plusHeadline.
  ///
  /// In ja, this message translates to:
  /// **'もっと遠くまで、\nいくつもの空を。'**
  String get plusHeadline;

  /// No description provided for @plusPlanMonthly.
  ///
  /// In ja, this message translates to:
  /// **'月額 {price}'**
  String plusPlanMonthly(String price);

  /// No description provided for @plusPlanMonthlyNote.
  ///
  /// In ja, this message translates to:
  /// **'いつでも解約できます'**
  String get plusPlanMonthlyNote;

  /// No description provided for @plusPlanLifetime.
  ///
  /// In ja, this message translates to:
  /// **'買い切り {price}'**
  String plusPlanLifetime(String price);

  /// No description provided for @plusPlanLifetimeNote.
  ///
  /// In ja, this message translates to:
  /// **'1回払いでずっと使える'**
  String get plusPlanLifetimeNote;

  /// No description provided for @plusNotReady.
  ///
  /// In ja, this message translates to:
  /// **'いまは購入の準備中です。'**
  String get plusNotReady;

  /// No description provided for @plusTermsLifetime.
  ///
  /// In ja, this message translates to:
  /// **'買い切りは1回のお支払いで、自動更新はありません。\nあとから追加の料金はかかりません。'**
  String get plusTermsLifetime;

  /// No description provided for @plusTermsTrial.
  ///
  /// In ja, this message translates to:
  /// **'終了24時間前までの解約なら、料金はかかりません。\n更新はストアの設定からいつでも止められます。'**
  String get plusTermsTrial;

  /// No description provided for @plusTermsMonthly.
  ///
  /// In ja, this message translates to:
  /// **'期間が終わる24時間前までに解約しないと、自動で更新されます。\n更新はストアの設定からいつでも止められます。'**
  String get plusTermsMonthly;

  /// No description provided for @plusRestore.
  ///
  /// In ja, this message translates to:
  /// **'購入を復元'**
  String get plusRestore;

  /// No description provided for @plusPrivacy.
  ///
  /// In ja, this message translates to:
  /// **'プライバシー'**
  String get plusPrivacy;

  /// No description provided for @plusFeaturePlaces.
  ///
  /// In ja, this message translates to:
  /// **'いまいる場所＋3か所'**
  String get plusFeaturePlaces;

  /// No description provided for @plusFeaturePlacesNote.
  ///
  /// In ja, this message translates to:
  /// **'家や学校、職場の空も見張って、ホームで切り替え'**
  String get plusFeaturePlacesNote;

  /// No description provided for @plusFeatureRange.
  ///
  /// In ja, this message translates to:
  /// **'90km先まで見張る'**
  String get plusFeatureRange;

  /// No description provided for @plusFeatureRangeNote.
  ///
  /// In ja, this message translates to:
  /// **'無料は30kmまで'**
  String get plusFeatureRangeNote;

  /// No description provided for @plusFeatureWidget.
  ///
  /// In ja, this message translates to:
  /// **'ホーム画面のウィジェット'**
  String get plusFeatureWidget;

  /// No description provided for @plusFeatureWidgetNote.
  ///
  /// In ja, this message translates to:
  /// **'アプリを開かずに方角と距離が分かる'**
  String get plusFeatureWidgetNote;

  /// No description provided for @plusActiveLifetime.
  ///
  /// In ja, this message translates to:
  /// **'買い切り（ずっと使えます。追加の料金はかかりません）'**
  String get plusActiveLifetime;

  /// No description provided for @plusActiveCancelledTitle.
  ///
  /// In ja, this message translates to:
  /// **'月額（解約済み）'**
  String get plusActiveCancelledTitle;

  /// No description provided for @plusActiveCancelledUntil.
  ///
  /// In ja, this message translates to:
  /// **'{day}まで使えます。それ以降は料金がかかりません'**
  String plusActiveCancelledUntil(String day);

  /// No description provided for @plusActiveTrial.
  ///
  /// In ja, this message translates to:
  /// **'7日間の無料体験中'**
  String get plusActiveTrial;

  /// No description provided for @plusActiveMonthly.
  ///
  /// In ja, this message translates to:
  /// **'月額（自動更新）'**
  String get plusActiveMonthly;

  /// No description provided for @plusRenewsOn.
  ///
  /// In ja, this message translates to:
  /// **'{day}に更新されます'**
  String plusRenewsOn(String day);

  /// No description provided for @plusActiveThanks.
  ///
  /// In ja, this message translates to:
  /// **'Plus を使っています。ありがとうございます。'**
  String get plusActiveThanks;

  /// No description provided for @plusActiveManageNote.
  ///
  /// In ja, this message translates to:
  /// **'月額の更新や解約は、ストアの設定から行えます。'**
  String get plusActiveManageNote;

  /// No description provided for @plusManageSubscription.
  ///
  /// In ja, this message translates to:
  /// **'サブスクリプションを管理'**
  String get plusManageSubscription;

  /// No description provided for @dateFull.
  ///
  /// In ja, this message translates to:
  /// **'{year}年{month}月{day}日'**
  String dateFull(String year, String month, String day);

  /// No description provided for @placesDeleteTitle.
  ///
  /// In ja, this message translates to:
  /// **'「{label}」を消しますか？'**
  String placesDeleteTitle(String label);

  /// No description provided for @placesDeleteAction.
  ///
  /// In ja, this message translates to:
  /// **'消す'**
  String get placesDeleteAction;

  /// No description provided for @placesNameTitle.
  ///
  /// In ja, this message translates to:
  /// **'場所の名前'**
  String get placesNameTitle;

  /// No description provided for @placesNameHint.
  ///
  /// In ja, this message translates to:
  /// **'例：家、おばあちゃんの家、塾'**
  String get placesNameHint;

  /// No description provided for @placesRegister.
  ///
  /// In ja, this message translates to:
  /// **'登録する'**
  String get placesRegister;

  /// No description provided for @placesIntro.
  ///
  /// In ja, this message translates to:
  /// **'いまいる場所に加えて、よく行く場所を3か所まで見張れます。ホームの上のチップで切り替えて見られます。'**
  String get placesIntro;

  /// No description provided for @placesSearchTitle.
  ///
  /// In ja, this message translates to:
  /// **'場所をさがす'**
  String get placesSearchTitle;

  /// No description provided for @placesSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'市町村名や住所'**
  String get placesSearchHint;

  /// No description provided for @placesFreeNoteBefore.
  ///
  /// In ja, this message translates to:
  /// **'無料プランは「いまいる場所」と、登録した1か所です。\n3か所の登録は '**
  String get placesFreeNoteBefore;

  /// No description provided for @placesFreeNoteAfter.
  ///
  /// In ja, this message translates to:
  /// **' の機能です。'**
  String get placesFreeNoteAfter;

  /// No description provided for @placesNotWatching.
  ///
  /// In ja, this message translates to:
  /// **'見張っていません'**
  String get placesNotWatching;

  /// No description provided for @placesQuietSky.
  ///
  /// In ja, this message translates to:
  /// **'静かな空'**
  String get placesQuietSky;

  /// No description provided for @placesRename.
  ///
  /// In ja, this message translates to:
  /// **'変更'**
  String get placesRename;

  /// No description provided for @placesDeleteLabel.
  ///
  /// In ja, this message translates to:
  /// **'{label} を消す'**
  String placesDeleteLabel(String label);

  /// No description provided for @placesAddButton.
  ///
  /// In ja, this message translates to:
  /// **'＋ 場所を追加（あと{remaining}か所）'**
  String placesAddButton(int remaining);

  /// No description provided for @addPlaceIntro.
  ///
  /// In ja, this message translates to:
  /// **'追加した場所は、ホームの上から切り替えて見られます。雲が出たら通知も届きます。'**
  String get addPlaceIntro;

  /// No description provided for @addPlaceSearchHint.
  ///
  /// In ja, this message translates to:
  /// **'例：盛岡市、滝沢市役所、盛岡駅'**
  String get addPlaceSearchHint;

  /// No description provided for @addPlaceSearchTooltip.
  ///
  /// In ja, this message translates to:
  /// **'さがす'**
  String get addPlaceSearchTooltip;

  /// No description provided for @addPlaceSearchHelp.
  ///
  /// In ja, this message translates to:
  /// **'市・町・村の名前、住所、駅や学校の名前でさがせます。入れたら「→」かキーボードの「検索」を押してください。'**
  String get addPlaceSearchHelp;

  /// No description provided for @addPlaceNotFound.
  ///
  /// In ja, this message translates to:
  /// **'見つかりませんでした。別の書き方でさがしてください。'**
  String get addPlaceNotFound;

  /// No description provided for @addPlaceLabelTitle.
  ///
  /// In ja, this message translates to:
  /// **'呼び名'**
  String get addPlaceLabelTitle;

  /// No description provided for @addPlaceLabelHint.
  ///
  /// In ja, this message translates to:
  /// **'場所を選ぶと地名が入ります'**
  String get addPlaceLabelHint;

  /// No description provided for @addPlaceButton.
  ///
  /// In ja, this message translates to:
  /// **'この場所を追加（あと{remaining}か所）'**
  String addPlaceButton(int remaining);
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
