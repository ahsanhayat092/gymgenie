// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get profileTitle => 'Profile';

  @override
  String get restTimerTitle => 'Active Workout Rest Timer';

  @override
  String get restTimerDesc =>
      'Trigger a countdown rest timer when you check a set as completed.';

  @override
  String get restTimerDuration => 'Rest Timer Duration';

  @override
  String get backupData => 'Backup & Synchronization';

  @override
  String get backupDesc =>
      'Create offline plan codes or restore saved profiles from gymZish.';

  @override
  String get logoutButton => 'Sign Out';

  @override
  String get themeMode => 'App Theme';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageDesc => 'Change application translation localizations.';
}
