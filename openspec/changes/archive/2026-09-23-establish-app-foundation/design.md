# Design

## Context

Текущий проект содержит Flutter starter app с одним экраном и локальным `StatefulWidget`; отдельных data, domain и state слоев нет. См. `proposal.md` и `specs/app-foundation/spec.md` для мотивации и поведенческого контракта.

Целевой runtime для первой версии — Android. Серверная часть и синхронизация не предусматриваются. Архитектура должна оставить возможность добавлять предметные модели бюджета без связывания UI с SQLite или конкретным способом хранения состояния.

## Goals / Non-Goals

**Goals:**

- Добавить минимальные data, state и localization слои, которые можно расширять по мере появления функций бюджета.
- Открывать локальную SQLite-базу через `drift_flutter`, сохраняя возможность использовать in-memory database в тестах.
- Разместить зависимости приложения в Riverpod providers и подключить единый `ProviderScope`.
- Подключить generated Flutter localizations через ARB resources и центральную конфигурацию `MaterialApp`.
- Проверить foundation widget- и unit-тестами.

**Non-Goals:**

- Проектирование таблиц финансовых операций, категорий, счетов или бюджетов.
- Реализация repository/use case логики для доходов и расходов.
- Серверная синхронизация, авторизация и миграции существующей пользовательской базы.
- Создание нового пользовательского экрана или полноценный редизайн starter app.

## Decisions

### Зависимости и генерация

В `dependencies` добавляются `drift`, `drift_flutter`, `flutter_riverpod`, `flutter_localizations` из Flutter SDK и `intl`. В `dev_dependencies` добавляются `drift_dev` и `build_runner`.

`drift` нужен для type-safe SQLite API, `drift_flutter` — для Flutter-инициализации базы, `flutter_riverpod` — для state/dependency scope, а `flutter_localizations` и `intl` — для стандартной Flutter localization и форматирования. `drift_dev` и `build_runner` ограничиваются dev-зависимостями, поскольку нужны только для генерации.

Альтернатива — использовать ручной `sqflite`-слой или хранить состояние в виджетах. Эти варианты отклоняются: они не дают требуемой типобезопасной модели запросов либо не разделяют состояние приложения с UI.

### Data layer

Создается отдельный database-модуль с главным объектом базы данных и конструктором production по умолчанию через `driftDatabase`. Конструктор должен принимать executor или эквивалентную тестовую конфигурацию, чтобы unit-тесты могли использовать in-memory SQLite.

На этом этапе база не содержит предметных таблиц. Database-модуль является точкой расширения для будущих Drift tables и repository-слоя. UI не импортирует низкоуровневые SQLite API.

### State layer

Корень приложения оборачивается в `ProviderScope`. Database и будущие repositories предоставляются через top-level providers; UI получает состояние через Riverpod widgets/providers. Тесты создают отдельный scope или container и переопределяют зависимости без общего глобального состояния.

Это предпочтительнее `InheritedWidget` или ручной передачи зависимостей, поскольку выбранный стек уже требует `flutter_riverpod`, а provider overrides упрощают изоляцию database и state тестов.

### Localization layer

Включается Flutter code generation через `flutter: generate: true`, добавляется конфигурация `l10n.yaml` и два ARB-ресурса: русский `app_ru.arb` и английский `app_en.arb`. `MaterialApp` использует сгенерированные `localizationsDelegates` и `supportedLocales` вместе с глобальными Flutter delegates.

Стартовые локали — `ru` и `en`; fallback locale — `ru`. До появления предметных экранов localization resources могут содержать только минимальные строки приложения, но каждая строка должна присутствовать в обоих ARB-ресурсах.

### Слои и границы

```text
UI widgets
   |
Riverpod providers / notifiers
   |
Repositories или application services (добавляются следующими changes)
   |
Drift database module
   |
SQLite
```

`MaterialApp` остается composition root для UI-конфигурации, `ProviderScope` — composition root для state/dependencies, а database module — владельцем открытия и закрытия SQLite. Эти границы не требуют создавать пустые repositories до появления предметного поведения.

## Risks / Trade-offs

- **[Risk]** Генерация Drift или localization может быть не запущена в CI и оставить устаревшие generated files. **Mitigation:** добавить явные build_runner и Flutter localization команды в tasks и проверять `flutter analyze`/`flutter test` после генерации.
- **[Risk]** Изменение starter counter test может скрыть регрессию при замене шаблонного экрана. **Mitigation:** сохранить минимальный smoke test приложения и добавить отдельные тесты ProviderScope, database initialization и localization fallback.
- **[Risk]** Поддержка только Android может ограничить запуск тестов или будущий web/desktop target. **Mitigation:** использовать `drift_flutter` вместо Android-specific file code и не добавлять платформенные API за пределами текущей Android-first цели.
- **[Risk]** Точная версия `intl` может конфликтовать с версией, которую предоставляет текущий Flutter SDK. **Mitigation:** разрешать совместимую версию через `flutter pub get`, не фиксировать независимую несовместимую версию вручную.

## Migration Plan

1. Добавить зависимости и конфигурацию генерации.
2. Создать database module с production и test constructors без предметных таблиц.
3. Добавить Riverpod root scope и providers для foundation dependencies.
4. Подключить localization generation, ARB resources и `MaterialApp` delegates.
5. Обновить существующий smoke test и добавить focused tests.
6. Запустить code generation, `flutter analyze` и `flutter test`.

Изменение не требует миграции данных, поскольку существующей прикладной базы нет. Откат выполняется удалением добавленных foundation-модулей, конфигурации генерации и зависимостей с восстановлением текущего starter wiring.
