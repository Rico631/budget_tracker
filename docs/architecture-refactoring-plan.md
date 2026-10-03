# План рефакторинга архитектуры

Целевая архитектура — по скиллу **flutter-apply-architecture-best-practices**:
UI (MVVM: Views + ViewModels) / Domain (модели, use cases, сервисы) / Data
(репозитории, сервисы). Гибридная структура каталогов: UI группируется по
фичам, Data и Domain — по типу.

Проект уже близок к целевой структуре: есть `data/`, `domain/`, контроллеры
(Riverpod-адаптация ViewModel) и use cases. Рефакторинг — «доводка»: убрать
нарушения границ слоёв, переложить файлы в целевые папки, разбить крупные
файлы, выровнять тесты и документацию.

---

## 1. Результаты анализа

### 1.1. Что уже хорошо

- Слои выделены: [data/](../lib/data/), [domain/](../lib/domain/),
  [presentation/](../lib/presentation/) и инфраструктурный [core/](../lib/core/).
- Паттерн Repository соблюдён: интерфейсы в `domain/repositories/`, реализации
  в `data/repositories/`.
- Use cases выделены в `domain/usecases/`, бизнес-правила — в
  `domain/services/`.
- Контроллеры Riverpod (`AsyncNotifier`) играют роль ViewModels, вью —
  `ConsumerWidget`; DI — Riverpod в `core/di/`.
- Широкое покрытие тестами (unit + widget), зеркалящее слои.
- ADR-культура (`docs/adr/`) и генерация локализации.

### 1.2. Слабые места: структура

| № | Проблема | Где |
|---|---|---|
| S1 | `presentation/` вместо целевого `ui/`; контроллеры централизованы в `presentation/providers/` вместо per-feature `view_models/`; страницы лежат в корне фичи, а не в `views/` | [lib/presentation/](../lib/presentation/) |
| S2 | `core/` смешивает UI-концерны (router, theme) с инфраструктурой (di, l10n, licensing). По целевой структуре тема и роутер — `ui/core` | [lib/core/router/](../lib/core/router/), [lib/core/theme/](../lib/core/theme/) |
| S3 | Общие виджеты и утилиты вне `ui/core`: `presentation/shared/` | [lib/presentation/shared/](../lib/presentation/shared/) |
| S4 | «Божественный файл» моделей: 350 строк, 20 типов, финансы + аналитика + журнал в одном файле | [lib/domain/models/finance_models.dart](../lib/domain/models/finance_models.dart) |
| S5 | `domain/commands/` — неочевидное имя для DTO входа (семантичнее `inputs`) | [lib/domain/commands/](../lib/domain/commands/) |
| S6 | Тесты: `test/widget_test.dart` — легаси-имя на корне test (содержит тесты bootstrap-gate); тесты контроллеров соответствуют старой папке `providers` | [test/widget_test.dart](../test/widget_test.dart), [test/unit/providers/](../test/unit/providers/) |
| S7 | README — boilerplate, архитектура не документирована | [README.md](../README.md) |

### 1.3. Слабые места: код и зависимости

| № | Проблема | Где |
|---|---|---|
| C1 | **Domain → Data** (нарушение инверсии зависимостей): `DatabaseBackupUseCases` зависит от конкретного `DatabaseSnapshotService` (data), `DatabaseRestoreUseCases` — от конкретного `DatabaseRegistry` (data). Соседние зависимости (`FileDialog`, `DatabaseRestoreValidator`) уже вынесены в интерфейсы — эти два не доведены | [database_backup_usecases.dart](../lib/domain/usecases/database_backup_usecases.dart), [database_restore_usecases.dart](../lib/domain/usecases/database_restore_usecases.dart) |
| C2 | **Presentation → Data**: вью и контроллер импортируют конкретный `DatabaseRegistry` (data) | [app_root.dart](../lib/presentation/features/bootstrap/app_root.dart), [database_list_page.dart](../lib/presentation/features/settings/database_list_page.dart), [data_management_controller.dart](../lib/presentation/providers/data_management_controller.dart) |
| C3 | **Вью обходит ViewModel**: `data_management_page` вызывает `databaseBackupUseCasesProvider`/`databaseRestoreUseCasesProvider` напрямую, хотя `DataManagementController` существует (отвечает только за список баз); `account_form_page` напрямую зовёт `accountUseCasesProvider.defaultCurrencyCodeFor` | [data_management_page.dart](../lib/presentation/features/settings/data_management_page.dart), [account_form_page.dart](../lib/presentation/features/accounts/account_form_page.dart) |
| C4 | Вью импортируют целые файлы use cases только ради констант кодов ошибок (`catalogNameRequiredError`, `transactionKindChangeRejectedError`, …) | [bank_form_page.dart](../lib/presentation/features/settings/bank_form_page.dart), [category_form_page.dart](../lib/presentation/features/settings/category_form_page.dart), [transaction_form_page.dart](../lib/presentation/features/transactions/transaction_form_page.dart) |
| C5 | Связность контроллеров: `accounts_controller` импортирует `finance_transaction_controller` и `transactions_journal_provider` ради инвалидации чужих провайдеров; `bookAccountsProvider`/`activeBookAccountsProvider` (данные счетов) определены в файле журнала операций | [accounts_controller.dart](../lib/presentation/providers/accounts_controller.dart), [transactions_journal_provider.dart](../lib/presentation/providers/transactions_journal_provider.dart) |
| C6 | Толстые вью: 715 строк — локальный state формы + валидация + маппинг ошибок + расчёт курса в одном State | [transaction_form_page.dart](../lib/presentation/features/transactions/transaction_form_page.dart) |
| C7 | Крупные файлы: `catalog_controller.dart` (211, банки + категории), `analytics_rule.dart` (351), формы счета/банка/категории (345/354/382) | [lib/presentation/providers/](../lib/presentation/providers/), [analytics_rule.dart](../lib/domain/services/analytics_rule.dart) |

---

## 2. Целевая структура каталогов

```text
lib/
├── main.dart                       # composition root приложения
├── core/                           # инфраструктура уровня приложения (не UI)
│   ├── di/                         # composition root (Riverpod)
│   ├── l10n/                       # arb + сгенерированная локализация
│   └── licensing/
├── data/                           # без изменений структуры
│   ├── local/
│   │   ├── database/
│   │   ├── files/
│   │   ├── mappers/
│   │   └── seed/
│   └── repositories/
├── domain/
│   ├── models/                     # + разбиение finance_models.dart
│   ├── inputs/                     # ← commands (переименование)
│   ├── repositories/               # интерфейсы (+ DatabaseRegistry, DatabaseSnapshotService)
│   ├── services/                   # бизнес-правила
│   ├── common/                     # validation_result, коды ошибок
│   └── usecases/
└── ui/                             # ← presentation
    ├── core/                       # общий UI
    │   ├── router/                 # ← core/router
    │   ├── theme/                  # ← core/theme
    │   ├── utils/                  # ← presentation/shared/utils
    │   └── widgets/                # ← presentation/shared/empty_states
    └── features/
        ├── accounts/
        │   ├── view_models/        # ← providers/accounts_controller.dart
        │   ├── views/              # accounts_page, account_form_page
        │   └── widgets/
        ├── analytics/
        │   ├── view_models/        # analytics_controller
        │   ├── views/
        │   └── widgets/
        ├── bootstrap/
        │   ├── view_models/
        │   └── views/
        ├── settings/
        │   ├── view_models/        # catalog_controller, data_management_controller
        │   ├── views/
        │   └── widgets/
        └── transactions/
            ├── view_models/        # finance_transaction_controller, transactions_journal_provider
            ├── views/
            └── widgets/
```

Допустимые направления зависимостей:

- `data` → `domain` (модели, интерфейсы репозиториев);
- `ui` → `domain` (через use cases/контроллеры), `ui` → `core`;
- `domain` → **не зависит ни от** `data`, **ни от** `ui`;
- `core/di` — composition root, единственное место, которое знает все слои.

---

## 3. План по этапам

Каждый этап завершается прогоном `flutter analyze` и `flutter test` и отдельным
коммитом.

### Этап 0. Базовый прогон

`flutter analyze` и `flutter test` — зафиксировать зелёное состояние до
изменений.

### Этап 1. Устранение нарушений границ слоёв (только код, без переименований)

1.1. Вынести DTO реестра в домен: `DatabaseSource`, `DatabaseEntry`,
`DatabaseRegistryState` → новый файл
`domain/models/database_registry_models.dart` (концепт домена, а не формата
хранения).

1.2. Ввести интерфейс в домене: новый
`domain/repositories/database_registry.dart` —
`abstract interface class DatabaseRegistry` (методы: `load`, `setActive`,
`deleteDatabase`, `registerActive`, `supportDirectory`, `pathOf`).
Реализация: `data/local/database/file_database_registry.dart` (текущий
`database_registry.dart`, JSON-формат остаётся внутри реализации).
Провайдер `databaseRegistryProvider` типизировать интерфейсом.

1.3. Ввести интерфейс в домене: новый
`domain/repositories/database_snapshot_service.dart` —
`abstract interface class DatabaseSnapshotService { Future<void> snapshotTo(String path); }`.
Реализация: `data/local/database/drift_database_snapshot_service.dart`
(текущий `database_snapshot_service.dart`, обёртка над `AppDatabase`).
Обновить `databaseBackupUseCasesProvider`.

1.4. Переключить `DatabaseBackupUseCases` и `DatabaseRestoreUseCases` на
интерфейсы из п. 1.2–1.3. После этого grep по
`package:budget_tracker/data/` в `domain/` должен быть пустым.

1.5. Убрать Presentation → Data: `app_root.dart`, `database_list_page.dart`,
`data_management_controller.dart` переключить на доменный интерфейс и DTO.
Создание реализации переносится в composition root (`main.dart` / `core/di`).

1.6. Вью перестают обходить ViewModel:
- в `DataManagementController` добавить методы `backup()` и `restore()`
  (состояние, ошибки) — `data_management_page.dart` работает только с
  контроллером;
- `account_form_page.dart` получает валюту по умолчанию через
  `AccountsController` (новый метод или провайдер).

1.7. Коды ошибок, читаемые вью, вынести в `domain/common/error_codes.dart`
(`catalogNameRequiredError`, `transactionKindChangeRejectedError`,
`transferToAmountRequiredError`, `transferToAmountNotAllowedError`,
`transactionToAmountNotAllowedError`, `transactionToAmountNotPositiveError`).
Формы банка/категории/операции импортируют константы из него, а не целые
файлы use cases.

**Проверка:** grep «слой импортирует не тот слой» (см. раздел 4) пуст;
analyze + все тесты зелёные.

### Этап 2. Переименование `presentation` → `ui` и разделение `core`

Переносы файлов:

| Откуда | Куда |
|---|---|
| `lib/presentation/**` | `lib/ui/**` (массово) |
| `lib/core/router/` | `lib/ui/core/router/` |
| `lib/core/theme/` | `lib/ui/core/theme/` |
| `lib/presentation/shared/utils/` | `lib/ui/core/utils/` |
| `lib/presentation/shared/empty_states/section_in_development_page.dart` | `lib/ui/core/widgets/section_in_development_page.dart` |

Правки импортов (механические, в lib/ и test/):
`package:budget_tracker/presentation/` → `package:budget_tracker/ui/`;
`core/router` → `ui/core/router`; `core/theme` → `ui/core/theme`;
`presentation/shared/utils` → `ui/core/utils`;
`presentation/shared/empty_states` → `ui/core/widgets`.

Остаются на месте: `core/di/`, `core/l10n/` (в т. ч. `l10n.yaml`),
`core/licensing/`.

**Проверка:** analyze + все тесты зелёные.

### Этап 3. Контроллеры в `view_models/`, страницы в `views/`

Переносы контроллеров (папка `ui/providers/` после этого удаляется):

| Откуда | Куда |
|---|---|
| `ui/providers/accounts_controller.dart` | `ui/features/accounts/view_models/accounts_controller.dart` |
| `ui/providers/finance_transaction_controller.dart` | `ui/features/transactions/view_models/` |
| `ui/providers/transactions_journal_provider.dart` | `ui/features/transactions/view_models/` |
| `ui/providers/analytics_controller.dart` | `ui/features/analytics/view_models/` |
| `ui/providers/catalog_controller.dart` | `ui/features/settings/view_models/` |
| `ui/providers/data_management_controller.dart` | `ui/features/settings/view_models/` |

Страницы переносятся в `views/` внутри своей фичи (виджеты остаются в
`widgets/`):

| Фича | Файлы → `views/` |
|---|---|
| accounts | `accounts_page.dart`, `account_form_page.dart` |
| analytics | `analytics_page.dart`, `category_operations_page.dart` |
| bootstrap | `app_bootstrap_gate.dart`, `app_root.dart`, `first_account_prompt_page.dart` |
| settings | `banks_page.dart`, `bank_form_page.dart`, `categories_page.dart`, `category_form_page.dart`, `database_list_page.dart`, `data_management_page.dart`, `journal_export_page.dart`, `settings_page.dart` |
| transactions | `transactions_page.dart`, `transaction_form_page.dart` |

Развязка C5: `bookAccountsProvider` и `activeBookAccountsProvider` перенести в
`ui/features/accounts/view_models/account_selection_providers.dart`
(данные счетов — вотчина фичи accounts; фичи-потребители — transactions,
settings — импортируют провайдеры из accounts, см. решение D5).

Тесты контроллеров: `test/unit/providers/*` → `test/unit/view_models/*`,
импорты обновить.

**Проверка:** analyze + все тесты зелёные.

### Этап 4. Разбиение крупных файлов

4.1. `domain/models/finance_models.dart` (350 строк, 20 типов) → отдельные
файлы:

| Файл | Типы |
|---|---|
| `domain/models/finance_book.dart` | `FinanceBook` |
| `domain/models/finance_bank.dart` | `FinanceBank` |
| `domain/models/finance_currency.dart` | `FinanceCurrency` |
| `domain/models/finance_account.dart` | `FinanceAccount`, `AccountBalance`, `AccountBalanceGroup`, `AccountsOverview` |
| `domain/models/finance_category.dart` | `FinanceCategory` |
| `domain/models/finance_transaction.dart` | `TransactionKind`, `FinanceTransaction` |
| `domain/models/transactions_journal.dart` | `JournalDayGroup`, `TransactionsJournal` |
| `domain/models/analytics_models.dart` | все `Analytics*` (9 типов) |

4.2. `ui/features/transactions/views/transaction_form_page.dart` (715 строк):
- маппинг кода ошибки → строка локализации вынести в хелпер
  `ui/features/transactions/view_models/transaction_form_error_messages.dart`
  (или `ui/core/utils/`);
- крупные фрагменты формы — в `widgets/` (селектор типа, блоки полей, список
  ошибок);
- опционально: `TransactionFormViewModel extends ChangeNotifier` для
  локального состояния формы (поля, валидация, busy), вью остаётся тонким.

4.3. Формы `account_form_page`, `bank_form_page`, `category_form_page` —
аналогичное облегчение (общие поля, сбор ошибок).

4.4. Опционально: `catalog_controller.dart` → `banks_controller.dart` +
`categories_controller.dart`; `analytics_rule.dart` — разбить по типам
агрегаций.

**Проверка:** analyze + все тесты зелёные.

### Этап 5. Выравнивание тестов

- `test/widget_test.dart` → `test/widget/bootstrap_gate_test.dart`.
- Проверить, что пути тестов зеркалят новые пути lib/; обновить импорты.
- (Опционально) `test/unit/utils/` → `test/unit/ui_core_utils/`.

**Проверка:** полный `flutter test`.

### Этап 6. Документация

- [README.md](../README.md): раздел «Архитектура» с деревом каталогов и
  правилами слоёв (направления зависимостей, где живёт что).
- `docs/adr/0007-architecture-layers-and-directory-structure.md`: фиксирует
  целевую структуру (`ui/`, per-feature `view_models/` + `views/`), Riverpod
  как DI/state-менеджмент, правило «domain не зависит от data/ui» и
  composition root в `core/di`.

---

## 4. Критерии готовности

- Grep пуст для: `package:budget_tracker/data/` внутри `lib/domain/`;
  `package:budget_tracker/data/` внутри `lib/ui/features/` и
  `lib/ui/core/` (кроме composition root `lib/core/di/`, `lib/main.dart`);
  `package:budget_tracker/ui/` внутри `lib/domain/`.
- `flutter analyze` — без ошибок и новых предупреждений.
- `flutter test` — все существующие и новые тесты зелёные.
- Каталог `lib/presentation/` отсутствует; `lib/ui/core/` содержит router,
  theme, utils, widgets.

---

## 5. Открытые решения (предложить пользователю)

| ID | Вопрос | Рекомендация |
|---|---|---|
| D1 | Переименовывать `presentation/` → `ui/` | Да — цель скилла |
| D2 | Страницы в подпапку `views/` внутри фичи | Да |
| D3 | `domain/commands/` → `domain/inputs/` | Да — семантичнее (DTO входа) |
| D4 | `domain/usecases/` → `domain/use_cases/` | Оставить `usecases` (меньше churn; скилл — ориентир) |
| D5 | Куда `bookAccountsProvider`/`activeBookAccountsProvider` | В фичу accounts (данные счетов) |
| D6 | Порядок работ | Поэтапно (0–6), коммит на этап |
