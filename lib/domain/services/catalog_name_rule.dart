/// Правило сравнения наименований справочников (ADR-0004, решение 4.5).
///
/// Наименования категорий и банков сравниваются без учета регистра и краевых
/// пробелов. Правило применяется в Dart, а не в SQL: SQLite без ICU не приводит
/// кириллицу к нижнему регистру встроенной функцией `lower()`, поэтому условие
/// в SQL давало бы разные результаты для локалей `ru` и `en`.
String normalizeCatalogName(String name) => name.trim().toLowerCase();

/// Совпадают ли наименования справочных записей [first] и [second].
bool catalogNamesMatch(String first, String second) =>
    normalizeCatalogName(first) == normalizeCatalogName(second);
