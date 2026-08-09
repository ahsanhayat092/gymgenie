// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get profileTitle => 'Profil';

  @override
  String get restTimerTitle => 'Minuteur de Repos Actif';

  @override
  String get restTimerDesc =>
      'Déclenche un minuteur de repos lorsque vous terminez une série.';

  @override
  String get restTimerDuration => 'Durée du Minuteur de Repos';

  @override
  String get backupData => 'Sauvegarde & Synchronisation';

  @override
  String get backupDesc =>
      'Créez des codes de plan hors ligne ou restaurez des profils enregistrés depuis GymGenie.';

  @override
  String get logoutButton => 'Se Déconnecter';

  @override
  String get themeMode => 'Thème de l\'Application';

  @override
  String get languageTitle => 'Langue';

  @override
  String get languageDesc =>
      'Modifier les localisations de traduction de l\'application.';
}
