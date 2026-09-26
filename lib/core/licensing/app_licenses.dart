import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Путь к тексту лицензии встроенного шрифта приложения (SIL OFL 1.1).
const String openSansLicenseAsset = 'assets/fonts/LICENSE-OpenSans.txt';

/// Регистрирует лицензии встроенных ресурсов приложения.
///
/// Шрифт Open Sans поставляется вместе с приложением, поэтому его лицензия
/// должна быть видна в стандартном списке лицензий Flutter, как и лицензии
/// подключенных библиотек.
void registerAppLicenses() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString(openSansLicenseAsset);
    yield LicenseEntryWithLineBreaks(const ['Open Sans'], license);
  });
}