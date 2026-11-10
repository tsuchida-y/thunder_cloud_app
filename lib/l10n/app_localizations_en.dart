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
}
