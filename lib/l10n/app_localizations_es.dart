// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get profileTitle => 'Perfil';

  @override
  String get restTimerTitle => 'Temporizador de Descanso Activo';

  @override
  String get restTimerDesc =>
      'Inicia un temporizador de descanso al completar una serie.';

  @override
  String get restTimerDuration => 'Duración del Descanso';

  @override
  String get backupData => 'Copia de Seguridad y Sincronización';

  @override
  String get backupDesc =>
      'Cree códigos de planes fuera de línea o restaure perfiles guardados de gymZish.';

  @override
  String get logoutButton => 'Cerrar Sesión';

  @override
  String get themeMode => 'Tema de la Aplicación';

  @override
  String get languageTitle => 'Idioma';

  @override
  String get languageDesc =>
      'Cambiar las localizaciones de traducción de la aplicación.';
}
