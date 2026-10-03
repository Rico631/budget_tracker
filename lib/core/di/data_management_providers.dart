import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/data/local/database/database_candidate_migrator.dart';
import 'package:budget_tracker/data/local/database/drift_database_restore_validator.dart';
import 'package:budget_tracker/data/local/database/drift_database_snapshot_service.dart';
import 'package:budget_tracker/data/local/database/file_database_registry.dart';
import 'package:budget_tracker/data/local/files/file_picker_file_dialog.dart';
import 'package:budget_tracker/domain/repositories/database_registry.dart';
import 'package:budget_tracker/domain/repositories/database_validation.dart';
import 'package:budget_tracker/domain/repositories/file_dialogs.dart';
import 'package:budget_tracker/domain/usecases/database_backup_usecases.dart';
import 'package:budget_tracker/domain/usecases/database_restore_usecases.dart';
import 'package:budget_tracker/domain/usecases/journal_export_usecases.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Системные диалоги выбора файла раздела «Экспорт и базы данных».
final fileDialogProvider = Provider<FileDialog>(
  (ref) => const FilePickerFileDialog(),
);

/// Реестр баз данных приложения.
final databaseRegistryProvider = Provider<DatabaseRegistry>(
  (ref) => FileDatabaseRegistry(),
);

/// Выгрузка журнала операций активной книги в CSV-файл.
final journalExportUseCasesProvider = Provider<JournalExportUseCases>(
  (ref) => JournalExportUseCases(
    transactions: ref.watch(transactionsRepositoryProvider),
    files: ref.watch(fileDialogProvider),
  ),
);

/// Создание резервной копии данных одним файлом `.sqlite`.
final databaseBackupUseCasesProvider = Provider<DatabaseBackupUseCases>(
  (ref) => DatabaseBackupUseCases(
    snapshot: DriftDatabaseSnapshotService(ref.watch(appDatabaseProvider)),
    files: ref.watch(fileDialogProvider),
  ),
);

/// Проверка файла-кандидата на восстановление.
final databaseRestoreValidatorProvider = Provider<DatabaseRestoreValidator>(
  (ref) => DriftDatabaseRestoreValidator(ref.watch(appDatabaseProvider)),
);

/// Восстановление базы из резервной копии.
final databaseRestoreUseCasesProvider = Provider<DatabaseRestoreUseCases>(
  (ref) => DatabaseRestoreUseCases(
    files: ref.watch(fileDialogProvider),
    validator: ref.watch(databaseRestoreValidatorProvider),
    registry: ref.watch(databaseRegistryProvider),
    applyMigrations: applyMigrationsAndProbe,
  ),
);
