// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Бюджетный трекер';

  @override
  String get welcomeMessage =>
      'Добро пожаловать в приложение для учета расходов';

  @override
  String get defaultBookName => 'Личная книга';

  @override
  String get bootstrapErrorMessage =>
      'Не удалось подготовить данные приложения. Перезапустите приложение.';
}
