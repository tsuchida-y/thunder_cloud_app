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

  @override
  String get close => '閉じる';

  @override
  String get plusPurchaseFailed => '購入できませんでした。時間をおいて、もう一度お試しください。';

  @override
  String get plusRestoreNone => '復元できる Plus の購入が見つかりませんでした。';

  @override
  String get plusRestoreFailed => '復元できませんでした。時間をおいて、もう一度お試しください。';

  @override
  String get plusFallbackMonthly => '200円';

  @override
  String get plusFallbackLifetime => '1,200円';

  @override
  String get plusBuy => 'Plus を買う';

  @override
  String plusBuyLifetimeNote(String price) {
    return '$price（1回だけのお支払い）';
  }

  @override
  String get plusTryFree => '7日間 無料で試す';

  @override
  String plusTryFreeNote(String price) {
    return 'そのあと月額$price（自動更新）';
  }

  @override
  String get plusStart => 'Plus をはじめる';

  @override
  String plusStartNote(String price) {
    return '月額$price（自動更新）';
  }

  @override
  String get plusHeadline => 'もっと遠くまで、\nいくつもの空を。';

  @override
  String plusPlanMonthly(String price) {
    return '月額 $price';
  }

  @override
  String get plusPlanMonthlyNote => 'いつでも解約できます';

  @override
  String plusPlanLifetime(String price) {
    return '買い切り $price';
  }

  @override
  String get plusPlanLifetimeNote => '1回払いでずっと使える';

  @override
  String get plusNotReady => 'いまは購入の準備中です。';

  @override
  String get plusTermsLifetime =>
      '買い切りは1回のお支払いで、自動更新はありません。\nあとから追加の料金はかかりません。';

  @override
  String get plusTermsTrial =>
      '終了24時間前までの解約なら、料金はかかりません。\n更新はストアの設定からいつでも止められます。';

  @override
  String get plusTermsMonthly =>
      '期間が終わる24時間前までに解約しないと、自動で更新されます。\n更新はストアの設定からいつでも止められます。';

  @override
  String get plusRestore => '購入を復元';

  @override
  String get plusPrivacy => 'プライバシー';

  @override
  String get plusFeaturePlaces => 'いまいる場所＋3か所';

  @override
  String get plusFeaturePlacesNote => '家や学校、職場の空も見張って、ホームで切り替え';

  @override
  String get plusFeatureRange => '90km先まで見張る';

  @override
  String get plusFeatureRangeNote => '無料は30kmまで';

  @override
  String get plusFeatureWidget => 'ホーム画面のウィジェット';

  @override
  String get plusFeatureWidgetNote => 'アプリを開かずに方角と距離が分かる';

  @override
  String get plusActiveLifetime => '買い切り（ずっと使えます。追加の料金はかかりません）';

  @override
  String get plusActiveCancelledTitle => '月額（解約済み）';

  @override
  String plusActiveCancelledUntil(String day) {
    return '$dayまで使えます。それ以降は料金がかかりません';
  }

  @override
  String get plusActiveTrial => '7日間の無料体験中';

  @override
  String get plusActiveMonthly => '月額（自動更新）';

  @override
  String plusRenewsOn(String day) {
    return '$dayに更新されます';
  }

  @override
  String get plusActiveThanks => 'Plus を使っています。ありがとうございます。';

  @override
  String get plusActiveManageNote => '月額の更新や解約は、ストアの設定から行えます。';

  @override
  String get plusManageSubscription => 'サブスクリプションを管理';

  @override
  String dateFull(String year, String month, String day) {
    return '$year年$month月$day日';
  }

  @override
  String placesDeleteTitle(String label) {
    return '「$label」を消しますか？';
  }

  @override
  String get placesDeleteAction => '消す';

  @override
  String get placesNameTitle => '場所の名前';

  @override
  String get placesNameHint => '例：家、おばあちゃんの家、塾';

  @override
  String get placesRegister => '登録する';

  @override
  String get placesIntro =>
      'いまいる場所に加えて、よく行く場所を3か所まで見張れます。ホームの上のチップで切り替えて見られます。';

  @override
  String get placesSearchTitle => '場所をさがす';

  @override
  String get placesSearchHint => '市町村名や住所';

  @override
  String get placesFreeNoteBefore => '無料プランは「いまいる場所」と、登録した1か所です。\n3か所の登録は ';

  @override
  String get placesFreeNoteAfter => ' の機能です。';

  @override
  String get placesNotWatching => '見張っていません';

  @override
  String get placesQuietSky => '静かな空';

  @override
  String get placesRename => '変更';

  @override
  String placesDeleteLabel(String label) {
    return '$label を消す';
  }

  @override
  String placesAddButton(int remaining) {
    return '＋ 場所を追加（あと$remainingか所）';
  }

  @override
  String get addPlaceIntro => '追加した場所は、ホームの上から切り替えて見られます。雲が出たら通知も届きます。';

  @override
  String get addPlaceSearchHint => '例：盛岡市、滝沢市役所、盛岡駅';

  @override
  String get addPlaceSearchTooltip => 'さがす';

  @override
  String get addPlaceSearchHelp =>
      '市・町・村の名前、住所、駅や学校の名前でさがせます。入れたら「→」かキーボードの「検索」を押してください。';

  @override
  String get addPlaceNotFound => '見つかりませんでした。別の書き方でさがしてください。';

  @override
  String get addPlaceLabelTitle => '呼び名';

  @override
  String get addPlaceLabelHint => '場所を選ぶと地名が入ります';

  @override
  String addPlaceButton(int remaining) {
    return 'この場所を追加（あと$remainingか所）';
  }

  @override
  String finderTitle(String direction) {
    return '$directionの入道雲へ';
  }

  @override
  String finderDirectionIs(String direction) {
    return '$directionの方角です';
  }

  @override
  String get finderNoSensor => 'この端末では方位センサーが使えません。';

  @override
  String get finderChecking => '方角を調べています…';

  @override
  String get turnBehind => '後ろを向いて';

  @override
  String get finderSubBehind => 'ゆっくり、体ごと後ろを向いて';

  @override
  String get turnRightPrefix => '右へ ';

  @override
  String get turnLeftPrefix => '左へ ';

  @override
  String get finderSubRight => 'ゆっくり、体ごと右を向いて';

  @override
  String get finderSubLeft => 'ゆっくり、体ごと左を向いて';

  @override
  String get finderLookUpTitle => '見上げる高さ';

  @override
  String finderLookUpHint(String fists) {
    return '腕を伸ばして、$fistsくらい上。';
  }

  @override
  String get alignedHere => 'この方向です';

  @override
  String finderAlignedHint(String fists) {
    return '正面の空、$fistsくらい上を\n見上げてみてください。';
  }

  @override
  String get reportQuestion => '入道雲は見えましたか？';

  @override
  String get reportThanks => '教えてくれて、ありがとうございます。';

  @override
  String get reportWhy => '教えてもらうと、お知らせの精度が上がります。';

  @override
  String get seen => '見えた';

  @override
  String get notSeen => '見えなかった';

  @override
  String get introSkip => 'スキップ';

  @override
  String get introStart => 'はじめる';

  @override
  String get introNext => '次へ';

  @override
  String get introNotifyTitle => '入道雲が出たら、\n通知でお知らせ。';

  @override
  String get introNotifyBody =>
      'あなたの場所から見える空に入道雲が現れたら、方角と距離を通知します。1つの雲につき1回、1日3回までです。夜は通知しません。';

  @override
  String get introNow => 'いま';

  @override
  String get introNotifyHeadline => '南東の空に、入道雲が現れました';

  @override
  String get introNotifyDetail => '約42km先。こぶし1つ半の高さを見上げてみて。';

  @override
  String get introFinderTitle => 'どっちを見るか、\n矢印で案内。';

  @override
  String get introFinderBody =>
      'ホームの「雲の方角を調べる」でスマホを向けると、「右へ35°」のように案内します。向きが合うと軽く振動します。見上げる高さは、腕を伸ばした「こぶしいくつ分」で伝えます。';

  @override
  String get introFinderSample => '見本です。スマホの向きを変えると、矢印が変わります。';

  @override
  String get introPlacesTitle => '家や学校の空も、\n見張れます。';

  @override
  String get introPlacesBody =>
      'いまいる場所のほかに、よく行く場所を1か所まで登録できます。ホーム上のチップで切り替えます。Plus なら3か所まで、見える範囲も90kmまで広がります。';

  @override
  String get introMockHome => '家';

  @override
  String introPageOf(int page, int count) {
    return '$pageページ目、全$countページ';
  }

  @override
  String get introBack => '前のページに戻る';

  @override
  String get dataSourceCredit => '出典：気象庁ホームページ（加工して作成）';

  @override
  String get dataSourceClouds =>
      '雲の場所は、気象庁ホームページの「高解像度降水ナウキャスト」と「雷ナウキャスト」をもとに、このアプリが強い雨や雷のある場所をまとめて作っています。';

  @override
  String get dataSourceHeights =>
      '雲の背の高さは気象庁ホームページの「ひまわり」の赤外画像から、空が一面の曇りかと遠くまで見通せるかは「アメダス」の観測から、このアプリが見積もっています。';

  @override
  String get dataSourceFetch => '気象庁のデータは、このアプリのサーバーが5分ごとにまとめて受け取っています。';

  @override
  String get dataSourceDisclaimer =>
      'アプリの表示は気象庁が発表したものではありません。入道雲が見えるかどうかは、山や建物、ほかの雲によって変わります。';

  @override
  String get dataSourceJmaTerms => '気象庁ホームページの利用規約';

  @override
  String recordYear(int year) {
    return '$year年';
  }

  @override
  String recordDays(int days) {
    return '入道雲を見た日 $days日';
  }

  @override
  String get recordLoadFailed => '記録を読み込めませんでした。電波の届く場所で、もう一度開いてください。';

  @override
  String get recordEmpty => 'まだ記録はありません。入道雲が見えたら、方角ガイドや通知で「見えた」を押すと、ここに残ります。';

  @override
  String get homeTodayCloudSeen => '見えた入道雲';

  @override
  String timeRange(String from, String to) {
    return '$from〜$to';
  }

  @override
  String aroundTime(String time) {
    return '$timeごろ';
  }

  @override
  String recordRowText(String direction, int km, String time) {
    return '$direction ・ ${km}km ・ $time';
  }

  @override
  String get quietSet => '通知しない時間を決める';

  @override
  String get quietStart => 'はじめ';

  @override
  String get quietEnd => 'おわり';

  @override
  String get quietDone => '決める';

  @override
  String nationwideTitle(int count) {
    return '全国で見えている入道雲（$countか所）';
  }

  @override
  String get nationwideOrder => '見張っている場所から近い順です。';

  @override
  String nationwideMore(int count) {
    return 'ほか$countか所';
  }

  @override
  String get nationwideNote => '場所は、雲の真ん中の位置のおおよその目安です。';

  @override
  String get nationwideSearching => '場所を調べています';

  @override
  String nationwideSince(String since) {
    return '$sinceから見えています';
  }

  @override
  String get whatsNew1 => '気象庁のデータをもとに、いま見えている入道雲の方角と距離をお知らせするようになりました。';

  @override
  String get whatsNew2 => 'ホームの「雲の方角を調べる」で、スマホを向けて入道雲のある方角を確かめられます。';

  @override
  String get whatsNew3 =>
      'みんなの写真を見るコミュニティと、写真を撮る機能は終わりました。これまでに投稿された写真は削除します。スマホの写真アプリに保存した写真は、そのまま残ります。';

  @override
  String get whatsNew4 => '遠くの雲（90kmまで）や、よく行く場所も見張れる「Plus」ができました。';

  @override
  String get whatsNewTitle => '入道雲サーチが\n新しくなりました。';

  @override
  String get understood => 'わかりました';

  @override
  String get alwaysTitle => '出かけた先の空も、\n見張りましょうか。';

  @override
  String alwaysBody(String place) {
    return 'いまは、最後にアプリを開いた場所$placeの空を見張っています。位置情報を「常に」にすると、移動しても、いまいる場所の空を見張れます。';
  }

  @override
  String get alwaysHint =>
      '次の画面で「常に許可」を選んでください。Androidでは設定アプリが開くので、「常に許可」を選んで戻ってください。';
}
