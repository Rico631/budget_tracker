import 'package:budget_tracker/data/local/database/app_database.dart';

/// Применяет недостающие миграции к базе по пути [path] и подтверждает ее
/// работоспособность пробным чтением.
///
/// Кандидат на восстановление открывается отдельным экземпляром `AppDatabase`:
/// открытие само доигрывает миграции, если версия схемы ниже текущей, поэтому
/// восстановленная база работоспособна сразу после проверки (ADR-0006,
/// решение 6.6). Возвращает `false`, если база неработоспособна.
Future<bool> applyMigrationsAndProbe(String path) async {
  final database = AppDatabase.forFile(path);
  try {
    await (database.select(database.books)..limit(1)).get();
    return true;
  } on Exception {
    return false;
  } finally {
    await database.close();
  }
}
