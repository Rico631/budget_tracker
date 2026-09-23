# Tasks

## 1. Зависимости и конфигурация генерации

- [x] 1.1 Добавить runtime-зависимости `drift`, `drift_flutter`, `flutter_riverpod`, `flutter_localizations` и `intl`, а также dev-зависимости `drift_dev` и `build_runner`; проверить успешное выполнение `flutter pub get`.
- [x] 1.2 Включить Flutter localization generation, создать `l10n.yaml`, `app_ru.arb` и `app_en.arb`, задать `ru` и `en` как supported locales и `ru` как fallback locale; проверить генерацию localization API командой `flutter gen-l10n`.

## 2. Data layer

- [x] 2.1 Создать database module с production-конструктором через `driftDatabase` и тестовым in-memory конструктором без предметных таблиц; проверить успешное открытие и закрытие базы unit-тестом.
- [x] 2.2 Подключить Drift code generation и убедиться, что generated database output создается без ошибок командой `dart run build_runner build --delete-conflicting-outputs`.

## 3. State и composition root

- [x] 3.1 Обернуть корень приложения в `ProviderScope` и определить providers для foundation-зависимостей; проверить запуск приложения и доступность provider из widget test.
- [x] 3.2 Добавить тестовую конфигурацию с provider overrides и проверить, что тестовая зависимость изолирована от production-зависимости и других тестов.

## 4. Localization и UI wiring

- [x] 4.1 Подключить сгенерированные `localizationsDelegates` и `supportedLocales` к `MaterialApp`, добавить одинаковый набор минимальных строк в `app_ru.arb` и `app_en.arb`, настроить fallback на `ru`; проверить выбор русского, английского и fallback языка widget test-ами.
- [x] 4.2 Удалить прямые пользовательские строки из измененного foundation wiring и сохранить существующий smoke test приложения в адаптированном виде; проверить корректный первый кадр без localization exceptions.

## 5. Итоговая проверка

- [x] 5.1 Запустить `dart run build_runner build --delete-conflicting-outputs`, `flutter gen-l10n`, `flutter analyze` и `flutter test`; все команды должны завершиться успешно.
- [x] 5.2 Проверить Android-запуск приложения на чистом локальном хранилище и повторный запуск с сохранением доступности базы; зафиксировать результат в тестах или отчете проверки.
