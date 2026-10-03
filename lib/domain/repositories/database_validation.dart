/// Таблицы приложения и версия схемы, начиная с которой таблица существует.
///
/// Карта описывает, что именно делает файл базой данных приложения: файл
/// принимается, только если содержит все таблицы своей версии (ADR-0006,
/// решение 6.6). Версия 1 не содержала прикладных таблиц — они создаются
/// миграцией до версии 2, поэтому для нее список требований пуст.
const Map<String, int> applicationTables = {
  'books': 2,
  'banks': 2,
  'accounts': 2,
  'categories': 2,
  'transactions': 2,
  'currencies': 3,
  'app_settings': 3,
};

/// Таблицы, которые обязана содержать база версии [schemaVersion].
List<String> requiredTablesFor(int schemaVersion) => [
  for (final entry in applicationTables.entries)
    if (entry.value <= schemaVersion) entry.key,
];

/// Причина отказа от восстановления из выбранного файла.
enum RestoreFailureReason {
  /// Файл не является базой данных приложения.
  notAnApplicationDatabase,

  /// Версия схемы выше поддерживаемой приложением: миграция «вниз» невозможна.
  unsupportedSchemaVersion,

  /// Выбранный файл не удалось прочитать или сохранить копию.
  fileUnreadable,
}

/// Результат проверки файла-кандидата на восстановление.
sealed class RestoreValidation {
  const RestoreValidation();
}

/// Файл пригоден для восстановления.
final class RestoreAccepted extends RestoreValidation {
  const RestoreAccepted();
}

/// Файл отклонен с причиной [reason].
final class RestoreRejected extends RestoreValidation {
  const RestoreRejected(this.reason);

  final RestoreFailureReason reason;
}

/// Проверка файла-кандидата перед восстановлением.
///
/// Текущая база при восстановлении не трогается: проверяется копия выбранного
/// файла, и только успешная проверка делает ее активной (ADR-0006, решение 6.6).
abstract interface class DatabaseRestoreValidator {
  /// Проверяет, что файл [path] — совместимая база данных приложения.
  ///
  /// Проверка не изменяет файл: соединение открывается без применения миграций.
  Future<RestoreValidation> validate(String path);
}
