import 'dart:io';

import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/domain/repositories/database_validation.dart';
import 'package:drift/native.dart';

/// Проверка файла-кандидата на восстановление через отдельное соединение с базой.
///
/// Соединение открывается по явному пути с отключенными миграциями: проверка
/// только читает версию схемы, состав таблиц и пробную строку, поэтому файл
/// кандидата не изменяется даже при отказе (ADR-0006, решение 6.6).
class DriftDatabaseRestoreValidator implements DatabaseRestoreValidator {
  const DriftDatabaseRestoreValidator(this.database);

  /// Текущая база приложения: источник поддерживаемой версии схемы.
  final AppDatabase database;

  @override
  Future<RestoreValidation> validate(String path) async {
    final candidate = AppDatabase.forTesting(
      NativeDatabase(File(path), enableMigrations: false),
    );
    try {
      final version = await _readSchemaVersion(candidate);
      if (version < 1) {
        return const RestoreRejected(
          RestoreFailureReason.notAnApplicationDatabase,
        );
      }
      if (version > database.schemaVersion) {
        return const RestoreRejected(
          RestoreFailureReason.unsupportedSchemaVersion,
        );
      }

      final tables = await _readTables(candidate);
      final missing = requiredTablesFor(
        version,
      ).where((table) => !tables.contains(table));
      if (missing.isNotEmpty) {
        return const RestoreRejected(
          RestoreFailureReason.notAnApplicationDatabase,
        );
      }

      if (version >= 2) {
        // Пробное чтение подтверждает работоспособность базы, а не только
        // наличие таблиц в каталоге схемы.
        await (candidate.select(candidate.books)..limit(1)).get();
      }

      return const RestoreAccepted();
    } on SqliteException {
      return const RestoreRejected(
        RestoreFailureReason.notAnApplicationDatabase,
      );
    } finally {
      await candidate.close();
    }
  }

  Future<int> _readSchemaVersion(AppDatabase candidate) async {
    final row = await candidate.customSelect('PRAGMA user_version').getSingle();
    final value = row.data['user_version'];
    return value is int ? value : 0;
  }

  Future<Set<String>> _readTables(AppDatabase candidate) async {
    final rows = await candidate
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
        .get();
    return {for (final row in rows) row.data['name'] as String};
  }
}
