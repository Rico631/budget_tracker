# budget_tracker

Приложение учета личных финансов: счета с остатками, операции доходов и
расходов, переводы между счетами (в том числе в разных валютах), аналитика по
категориям и управление базами данных с экспортом и резервным копированием.

Документация:

- решения по продукту — [docs/adr/](docs/adr/), начиная с
  [ADR-0001](docs/adr/0001-budget-tracker-concept-and-ux.md);
- справочные данные — [docs/reference-data/](docs/reference-data/);
- целевая архитектура — [ADR-0007](docs/adr/0007-architecture-layers-and-directory-structure.md).

## Архитектура

Приложение разделено на три слоя и инфраструктурное ядро (детали — в
[ADR-0007](docs/adr/0007-architecture-layers-and-directory-structure.md)):

`	ext
lib/
├── main.dart          # точка входа
├── core/              # инфраструктура: di (composition root), l10n, licensing
├── data/              # локальная база (Drift), файлы, репозитории-реализации
├── domain/            # модели, интерфейсы репозиториев, сервисы, use cases
└── ui/
    ├── core/          # общие router, theme, utils, widgets
    └── features/      # accounts, transactions, analytics, settings, bootstrap
        ├── view_models/   # контроллеры состояния (Riverpod, MVVM-адаптация)
        ├── views/         # страницы
        └── widgets/       # виджеты фичи
`

Правила слоев:

- data зависит только от domain;
- ui зависит от domain и core;
- domain не зависит ни от data, ни от ui;
- граф зависимостей собирается в lib/core/di/.

Состояние и DI — Riverpod: вью читают провайдеры контроллеров
(view_models), контроллеры вызывают use cases, use cases — интерфейсы
репозиториев из domain/repositories.

## Разработка

`	ext
flutter pub get        # зависимости
flutter gen-l10n       # генерация локализации (l10n.yaml)
dart analyze           # статический анализ
flutter test           # unit- и виджет-тесты
`

Тесты зеркалят структуру lib/: unit-тесты — в 	est/unit/, виджет-тесты —
в 	est/widget/.