// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Thunderhead Watch';

  @override
  String get welcomeLead =>
      'When a thunderhead appears in the sky you can see from where you are, we\'ll tell you which direction to look.';

  @override
  String get welcomeLocationTitle => 'Location (while using the app)';

  @override
  String get welcomeLocationBody =>
      'Checks the sky where you open the app and keeps watch over that place.';

  @override
  String get welcomeNotificationTitle => 'Notifications';

  @override
  String get welcomeNotificationBody =>
      'When a thunderhead is visible, we\'ll let you know once per cloud.';

  @override
  String get welcomeContinue => 'Continue';

  @override
  String get welcomeLaterNote =>
      'We\'ll show you how to watch the sky where you travel later.';

  @override
  String get cancel => 'Cancel';

  @override
  String get none => 'None';

  @override
  String get currentPlace => 'Current location';

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String kmValue(int km) {
    return '$km km';
  }

  @override
  String rangePlusOption(int km) {
    return '$km km (Plus)';
  }

  @override
  String get freeTrial7Days => '7-day free trial';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionNotification => 'Notifications';

  @override
  String get settingsNotifyAppeared =>
      'Notify me when a thunderhead is visible';

  @override
  String get settingsSectionRange => 'How far to watch';

  @override
  String get settingsRangeNote =>
      'For clouds farther than 60 km, we say they \"may be visible\". Mountains and buildings can hide them.';

  @override
  String get settingsSectionOther => 'Other';

  @override
  String get settingsQuietHours => 'Quiet hours';

  @override
  String get settingsQuietHoursNote =>
      'Notifications pause automatically while the sky is dark (night)';

  @override
  String get settingsRecord => 'Log (clouds you saw)';

  @override
  String get settingsPlaces => 'Places to watch';

  @override
  String get settingsSectionAbout => 'About this app';

  @override
  String get settingsHowToUse => 'How to use';

  @override
  String get settingsDataSource => 'Data source';

  @override
  String get settingsTerms => 'Terms of Use';

  @override
  String get settingsPrivacy => 'Privacy Policy';

  @override
  String get settingsDeleteData => 'Delete my data';

  @override
  String get settingsDeleting => 'Deleting…';

  @override
  String get settingsDeleteDataNote =>
      'Removes your places, settings and log from the server';

  @override
  String get settingsDeleteConfirmTitle => 'Delete your data?';

  @override
  String get settingsDeleteConfirmBody =>
      'Your places, settings, notification address and log of clouds you saw will be deleted from the server. This cannot be undone.\n\nYour Plus purchase is not affected. You can keep using Plus after deleting.';

  @override
  String get settingsDeleteAction => 'Delete';

  @override
  String get settingsDeletedTitle => 'Deleted';

  @override
  String get settingsDeletedBody => 'You can start over from the beginning.';

  @override
  String get settingsDeleteFailed =>
      'Could not delete. Please check your connection and try again.';

  @override
  String get settingsPlusManage => 'View or cancel your plan';

  @override
  String get settingsPlusInUse => 'Active';

  @override
  String get settingsPlusBanner => 'Watch farther with Plus';

  @override
  String get dirN => 'North';

  @override
  String get dirNE => 'Northeast';

  @override
  String get dirE => 'East';

  @override
  String get dirSE => 'Southeast';

  @override
  String get dirS => 'South';

  @override
  String get dirSW => 'Southwest';

  @override
  String get dirW => 'West';

  @override
  String get dirNW => 'Northwest';

  @override
  String fistsWhole(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n fists',
      one: '1 fist',
      zero: 'half a fist',
    );
    return '$_temp0';
  }

  @override
  String fistsHalfMore(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n½ fists',
      zero: 'half a fist',
    );
    return '$_temp0';
  }

  @override
  String agoMinutes(int n) {
    return '$n min ago';
  }

  @override
  String agoHours(int n) {
    return '$n h ago';
  }

  @override
  String agoDays(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String morningSameDay(String time) {
    return 'around $time this morning';
  }

  @override
  String morningNextDay(String time) {
    return 'around $time tomorrow morning';
  }

  @override
  String get skySunny => 'Sunny';

  @override
  String get skySometimesSunny => 'Occasional sun';

  @override
  String get skyNoSun => 'No direct sun';

  @override
  String skyTemp(int c) {
    return '$c°C';
  }

  @override
  String skyVisibilityMax(int km) {
    return 'Visibility $km km or more';
  }

  @override
  String skyVisibility(int km) {
    return 'Visibility about $km km';
  }

  @override
  String badgePlace(String place) {
    return '$place · ';
  }

  @override
  String skyObservedAgo(String ago) {
    return 'Sky checked $ago';
  }

  @override
  String homeCloudBodyMaybe(int km, String fists) {
    return 'About $km km away, so it may be visible. It rises about $fists above the horizon.';
  }

  @override
  String homeCloudBody(int km, String fists) {
    return 'About $km km away. It rises about $fists above the horizon.';
  }

  @override
  String get homeBadgeMaybe => 'May be visible';

  @override
  String get homeBadgeVisible => 'Visible now';

  @override
  String homeCloudTitle(String direction) {
    return 'Thunderhead\nto the $direction.';
  }

  @override
  String get homeFindDirection => 'Find the cloud';

  @override
  String get homeBadgeWatching => 'Watching the sky';

  @override
  String get homeCalmTitle => 'The sky is\nquiet right now.';

  @override
  String get homeCalmBody =>
      'We\'ll tell you as soon as a thunderhead appears.';

  @override
  String get homeBadgeResting => 'Watch is resting';

  @override
  String get homeNightTitle => 'It\'s night.\nToo dark to see clouds.';

  @override
  String get homeNightBody =>
      'We\'ll start watching again when it gets light. No notifications at night.';

  @override
  String homeNightBodyResume(String when) {
    return 'We\'ll start watching again when it gets light, $when. No notifications at night.';
  }

  @override
  String get homeTodayCloud => 'Today\'s thunderhead';

  @override
  String homeTodayCloudDetail(
      String from, String to, String direction, int km) {
    return 'From $from to $to, to the $direction (about $km km away)';
  }

  @override
  String get homeOffline => 'Offline';

  @override
  String get homeOfflineTitle => 'Can\'t get\nsky information.';

  @override
  String get homeOfflineBody => 'Please reload where you have a connection.';

  @override
  String homeLastSky(String time) {
    return 'Last sky check ($time)';
  }

  @override
  String homeLastCloud(String direction, int km) {
    return 'Thunderhead to the $direction (about $km km away)';
  }

  @override
  String get homeLastUnknown => 'We can\'t tell if it\'s still visible.';

  @override
  String get homeReload => 'Reload';

  @override
  String get homeNoPlace => 'Location unknown';

  @override
  String get homeNoPermissionTitle => 'We can\'t watch\nthe sky yet.';

  @override
  String get homeNoPermissionBody =>
      'Turn on the two items below and we\'ll tell you when a thunderhead appears.';

  @override
  String get homeLocationOffTitle => 'Location is off';

  @override
  String get homeLocationOffBody =>
      'In the Settings app, set Location to \"While Using the App\" or \"Always\".';

  @override
  String get homeOpenSettings => 'Open Settings';

  @override
  String get homeNotificationOffTitle => 'Notifications are off';

  @override
  String get homeNotificationOffBody =>
      'You\'ll only see cloud positions when you open the app.';

  @override
  String get homeEnableNotifications => 'Turn on notifications';

  @override
  String get homeAddPlaceManually => 'Add a place manually';

  @override
  String homeSkyOf(String place) {
    return 'Sky over $place';
  }

  @override
  String get recordLabel => 'Log';

  @override
  String homeChipWithCloud(String place) {
    return '$place, thunderhead present';
  }

  @override
  String get homeAddPlace => 'Add a place';

  @override
  String get homeAddPlacePlus => 'Add a place. A Plus feature';

  @override
  String get homeCurrentLocation => 'Current location';

  @override
  String homeOtherSpotLine(String name, String direction, int km) {
    return '$name · $direction · $km km';
  }

  @override
  String get homeMaybeShort => 'May be visible';

  @override
  String get homeVisibleShort => 'Visible';

  @override
  String homeNearestPlace(String place) {
    return ' ($place)';
  }

  @override
  String get homeNowSky => 'Sky now';

  @override
  String homeAmedas(String time) {
    return 'Nearby AMeDAS station $time';
  }

  @override
  String get homeNearestCloud => 'Nearest thunderhead';

  @override
  String get homeNoneNationwide => 'None found in Japan';

  @override
  String homeNearestLine(String direction, int km, String place) {
    return '$direction $km km$place';
  }

  @override
  String homeNationwideNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count places',
      one: '1 place',
    );
    return '$_temp0 in Japan · tap for the list';
  }

  @override
  String get homeRecordLink => 'Log of thunderheads you saw';

  @override
  String homeCloudLine(String direction, int km) {
    return '$direction · $km km';
  }

  @override
  String homeSinceMaybe(String since) {
    return 'Since $since · may be visible';
  }

  @override
  String homeSinceVisible(String since) {
    return 'Visible since $since';
  }

  @override
  String get close => 'Close';

  @override
  String get plusPurchaseFailed =>
      'Could not complete the purchase. Please try again later.';

  @override
  String get plusRestoreNone => 'No Plus purchase was found to restore.';

  @override
  String get plusRestoreFailed => 'Could not restore. Please try again later.';

  @override
  String get plusFallbackMonthly => '¥200';

  @override
  String get plusFallbackLifetime => '¥1,200';

  @override
  String get plusBuy => 'Buy Plus';

  @override
  String plusBuyLifetimeNote(String price) {
    return '$price (one-time payment)';
  }

  @override
  String get plusTryFree => 'Try free for 7 days';

  @override
  String plusTryFreeNote(String price) {
    return 'Then $price/month (auto-renews)';
  }

  @override
  String get plusStart => 'Start Plus';

  @override
  String plusStartNote(String price) {
    return '$price/month (auto-renews)';
  }

  @override
  String get plusHeadline => 'Watch farther,\nand more skies.';

  @override
  String plusPlanMonthly(String price) {
    return 'Monthly $price';
  }

  @override
  String get plusPlanMonthlyNote => 'Cancel anytime';

  @override
  String plusPlanLifetime(String price) {
    return 'One-time $price';
  }

  @override
  String get plusPlanLifetimeNote => 'Pay once, use forever';

  @override
  String get plusNotReady => 'Purchases are not available right now.';

  @override
  String get plusTermsLifetime =>
      'A one-time payment. It does not auto-renew.\nThere are no additional charges later.';

  @override
  String get plusTermsTrial =>
      'Cancel at least 24 hours before the trial ends and you won\'t be charged.\nYou can stop renewal anytime in the store settings.';

  @override
  String get plusTermsMonthly =>
      'Renews automatically unless you cancel at least 24 hours before the period ends.\nYou can stop renewal anytime in the store settings.';

  @override
  String get plusRestore => 'Restore purchases';

  @override
  String get plusPrivacy => 'Privacy';

  @override
  String get plusFeaturePlaces => 'Current location + 3 more';

  @override
  String get plusFeaturePlacesNote =>
      'Watch the sky at home, school or work, and switch on the home screen';

  @override
  String get plusFeatureRange => 'Watch up to 90 km away';

  @override
  String get plusFeatureRangeNote => 'Free is up to 30 km';

  @override
  String get plusFeatureWidget => 'Home screen widget';

  @override
  String get plusFeatureWidgetNote =>
      'See direction and distance without opening the app';

  @override
  String get plusActiveLifetime =>
      'One-time purchase (yours to keep; no additional charges)';

  @override
  String get plusActiveCancelledTitle => 'Monthly (cancelled)';

  @override
  String plusActiveCancelledUntil(String day) {
    return 'You can use it until $day. You will not be charged after that.';
  }

  @override
  String get plusActiveTrial => 'In your 7-day free trial';

  @override
  String get plusActiveMonthly => 'Monthly (auto-renews)';

  @override
  String plusRenewsOn(String day) {
    return 'Renews on $day';
  }

  @override
  String get plusActiveThanks => 'You\'re using Plus. Thank you.';

  @override
  String get plusActiveManageNote =>
      'You can manage or cancel your monthly plan in the store settings.';

  @override
  String get plusManageSubscription => 'Manage subscription';

  @override
  String dateFull(String year, String month, String day) {
    String _temp0 = intl.Intl.selectLogic(
      month,
      {
        '1': 'Jan',
        '2': 'Feb',
        '3': 'Mar',
        '4': 'Apr',
        '5': 'May',
        '6': 'Jun',
        '7': 'Jul',
        '8': 'Aug',
        '9': 'Sep',
        '10': 'Oct',
        '11': 'Nov',
        '12': 'Dec',
        'other': '',
      },
    );
    return '$_temp0 $day, $year';
  }

  @override
  String placesDeleteTitle(String label) {
    return 'Delete \"$label\"?';
  }

  @override
  String get placesDeleteAction => 'Delete';

  @override
  String get placesNameTitle => 'Place name';

  @override
  String get placesNameHint => 'e.g. Home, Grandma\'s house, Cram school';

  @override
  String get placesRegister => 'Save';

  @override
  String get placesIntro =>
      'In addition to where you are now, you can watch up to 3 places you often go. Switch between them with the chips at the top of the home screen.';

  @override
  String get placesSearchTitle => 'Search for a place';

  @override
  String get placesSearchHint => 'City name or address';

  @override
  String get placesFreeNoteBefore =>
      'The free plan covers your current location and 1 saved place.\nSaving 3 places is a ';

  @override
  String get placesFreeNoteAfter => ' feature.';

  @override
  String get placesNotWatching => 'Not watching';

  @override
  String get placesQuietSky => 'Quiet sky';

  @override
  String get placesRename => 'Rename';

  @override
  String placesDeleteLabel(String label) {
    return 'Delete $label';
  }

  @override
  String placesAddButton(int remaining) {
    return '+ Add a place ($remaining more)';
  }

  @override
  String get addPlaceIntro =>
      'Places you add can be switched from the top of the home screen. You will also get notified when a cloud appears.';

  @override
  String get addPlaceSearchHint =>
      'e.g. Morioka, Takizawa City Hall, Morioka Station';

  @override
  String get addPlaceSearchTooltip => 'Search';

  @override
  String get addPlaceSearchHelp =>
      'Search by city or town name, address, or the name of a station or school. After typing, press the arrow or the keyboard\'s search key.';

  @override
  String get addPlaceNotFound => 'Not found. Please try a different spelling.';

  @override
  String get addPlaceLabelTitle => 'Nickname';

  @override
  String get addPlaceLabelHint =>
      'The place name is filled in when you pick a place';

  @override
  String addPlaceButton(int remaining) {
    return 'Add this place ($remaining more)';
  }
}
