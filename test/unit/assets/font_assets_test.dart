import 'dart:io';

import 'package:budget_tracker/core/licensing/app_licenses.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Шрифт Open Sans встроен в приложение: текст не зависит от сети и от шрифтов
/// устройства (ADR-0001, решение 1.5), а русский интерфейс требует кириллицы в
/// файлах шрифта. Тест фиксирует и наличие файлов, и покрытие кириллицы: подмена
/// файлов на латиницу-only сломала бы русский интерфейс незаметно для тестов
/// виджетов, которые используют тестовый шрифт.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const fontFiles = [
    'OpenSans-Regular.ttf',
    'OpenSans-Italic.ttf',
    'OpenSans-SemiBold.ttf',
    'OpenSans-Bold.ttf',
    'OpenSans-BoldItalic.ttf',
  ];

  test('файлы шрифта Open Sans лежат в assets/fonts и содержат кириллицу', () {
    for (final name in fontFiles) {
      final file = File('assets/fonts/$name');

      expect(file.existsSync(), isTrue, reason: 'Нет файла шрифта: $name');
      final bytes = file.readAsBytesSync();
      expect(bytes.length, greaterThan(10000), reason: 'Пустой файл: $name');
      expect(
        String.fromCharCodes(bytes).contains('cyrl'),
        isTrue,
        reason: 'В файле $name нет кириллических глифов',
      );
    }
  });

  test('текст лицензии шрифта лежит рядом с файлами шрифта', () {
    final license = File('assets/fonts/LICENSE-OpenSans.txt');

    expect(license.existsSync(), isTrue);
    expect(license.readAsStringSync(), contains('SIL OPEN FONT LICENSE'));
  });

  test('лицензия встроенного шрифта зарегистрирована в приложении', () async {
    registerAppLicenses();

    final entries = await LicenseRegistry.licenses
        .where((entry) => entry.packages.contains('Open Sans'))
        .toList();

    expect(entries, hasLength(1));
    expect(entries.single.paragraphs, isNotEmpty);
  });
}
