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

  @override
  String get dirN => '北';

  @override
  String get dirNE => '北東';

  @override
  String get dirE => '東';

  @override
  String get dirSE => '南東';

  @override
  String get dirS => '南';

  @override
  String get dirSW => '南西';

  @override
  String get dirW => '西';

  @override
  String get dirNW => '北西';

  @override
  String fistsWhole(int n) {
    return 'こぶし$nつ';
  }

  @override
  String fistsHalfMore(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: 'こぶし$nつ半',
      zero: 'こぶし半分',
    );
    return '$_temp0';
  }

  @override
  String agoMinutes(int n) {
    return '$n分前';
  }

  @override
  String agoHours(int n) {
    return '$n時間前';
  }

  @override
  String agoDays(int n) {
    return '$n日前';
  }

  @override
  String morningSameDay(String time) {
    return '朝 $time ごろ';
  }

  @override
  String morningNextDay(String time) {
    return 'あすの朝 $time ごろ';
  }

  @override
  String get skySunny => '日が差しています';

  @override
  String get skySometimesSunny => 'ときどき日が差しています';

  @override
  String get skyNoSun => '日が差していません';

  @override
  String skyTemp(int c) {
    return '気温$c℃';
  }

  @override
  String skyVisibilityMax(int km) {
    return '見通し${km}km以上';
  }

  @override
  String skyVisibility(int km) {
    return '見通し約${km}km';
  }

  @override
  String badgePlace(String place) {
    return '$place ・ ';
  }

  @override
  String skyObservedAgo(String ago) {
    return '$agoに空を見ました';
  }

  @override
  String homeCloudBodyMaybe(int km, String fists) {
    return '約${km}km先なので、見えるかもしれません。$fistsくらいの高さに立っています。';
  }

  @override
  String homeCloudBody(int km, String fists) {
    return '約${km}km先。$fistsくらいの高さに立っています。';
  }

  @override
  String get homeBadgeMaybe => '見えるかもしれません';

  @override
  String get homeBadgeVisible => 'いま、見えています';

  @override
  String homeCloudTitle(String direction) {
    return '$directionの空に、\n入道雲。';
  }

  @override
  String get homeFindDirection => '雲の方角を調べる';

  @override
  String get homeBadgeWatching => '空を見守っています';

  @override
  String get homeCalmTitle => 'いまは、\n静かな空です。';

  @override
  String get homeCalmBody => '入道雲が現れたら、すぐにお知らせします。';

  @override
  String get homeBadgeResting => '見張りはお休み中';

  @override
  String get homeNightTitle => 'いまは夜。\n空が暗くて見えません。';

  @override
  String get homeNightBody => '明るくなったら見張りを再開します。夜のあいだは通知しません。';

  @override
  String homeNightBodyResume(String when) {
    return '$when、明るくなったら見張りを再開します。夜のあいだは通知しません。';
  }

  @override
  String get homeTodayCloud => 'きょう見えた入道雲';

  @override
  String homeTodayCloudDetail(
      String from, String to, String direction, int km) {
    return '$from から $to まで、$directionの空（約${km}km先）';
  }

  @override
  String get homeOffline => 'オフライン';

  @override
  String get homeOfflineTitle => '空の情報が\n受け取れません。';

  @override
  String get homeOfflineBody => '電波の届く場所で、もう一度読み込んでください。';

  @override
  String homeLastSky(String time) {
    return '最後に見た空（$time）';
  }

  @override
  String homeLastCloud(String direction, int km) {
    return '$directionの空に入道雲（約${km}km先）';
  }

  @override
  String get homeLastUnknown => 'いまも見えるかは分かりません。';

  @override
  String get homeReload => 'もう一度読み込む';

  @override
  String get homeNoPlace => '場所が分かりません';

  @override
  String get homeNoPermissionTitle => 'このままでは\n空を見張れません。';

  @override
  String get homeNoPermissionBody => '下の2つをオンにすると、入道雲が現れたときにお知らせできます。';

  @override
  String get homeLocationOffTitle => '位置情報がオフです';

  @override
  String get homeLocationOffBody => '設定アプリで「位置情報」を「使用中のみ」か「常に」にしてください。';

  @override
  String get homeOpenSettings => '設定アプリを開く';

  @override
  String get homeNotificationOffTitle => '通知がオフです';

  @override
  String get homeNotificationOffBody => 'アプリを開いたときだけ、雲の場所を確かめられます。';

  @override
  String get homeEnableNotifications => '通知をオンにする';

  @override
  String get homeAddPlaceManually => '場所を手で登録する';

  @override
  String homeSkyOf(String place) {
    return '$placeの空';
  }

  @override
  String get recordLabel => '記録';

  @override
  String homeChipWithCloud(String place) {
    return '$place、入道雲あり';
  }

  @override
  String get homeAddPlace => '場所を追加';

  @override
  String get homeAddPlacePlus => '場所を追加。Plus の機能です';

  @override
  String get homeCurrentLocation => '現在地';

  @override
  String homeOtherSpotLine(String name, String direction, int km) {
    return '$name ・ $direction ・ ${km}km';
  }

  @override
  String get homeMaybeShort => '見えるかも';

  @override
  String get homeVisibleShort => '見えています';

  @override
  String homeNearestPlace(String place) {
    return '（$place）';
  }

  @override
  String get homeNowSky => 'いまの空';

  @override
  String homeAmedas(String time) {
    return '近くのアメダス $time';
  }

  @override
  String get homeNearestCloud => 'いちばん近い入道雲';

  @override
  String get homeNoneNationwide => '全国で見つかっていません';

  @override
  String homeNearestLine(String direction, int km, String place) {
    return '$direction ${km}km$place';
  }

  @override
  String homeNationwideNote(int count) {
    return '全国で$countか所 ・ 押すと一覧';
  }

  @override
  String get homeRecordLink => '見えた入道雲の記録';

  @override
  String homeCloudLine(String direction, int km) {
    return '$direction ・ ${km}km';
  }

  @override
  String homeSinceMaybe(String since) {
    return '$sinceから ・ 見えるかも';
  }

  @override
  String homeSinceVisible(String since) {
    return '$sinceから見えています';
  }
}
