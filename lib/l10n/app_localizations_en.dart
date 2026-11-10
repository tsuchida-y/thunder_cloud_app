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
}
