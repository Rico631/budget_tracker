import 'dart:io';
import 'dart:typed_data';

import 'package:budget_tracker/data/local/database/database_registry.dart';
import 'package:budget_tracker/domain/repositories/database_validation.dart';
import 'package:budget_tracker/domain/repositories/file_dialogs.dart';
import 'package:budget_tracker/domain/services/export_file_name_rule.dart';

/// Применяет недостающие миграции к базе по пути и подтверждает ее
/// работоспособность пробным чтением.
typedef DatabaseCandidateMigrator = Future<bool> Function(String path);

/// Результат восстановления из резервной копии.
sealed class RestoreResult {
  const RestoreResult();
}

/// Восстановление выполнено: копия сохранена как новая база и стала активной.
final class RestoreSucceeded extends RestoreResult {
  const RestoreSucceeded();
}

/// Пользователь отменил выбор файла копии.
final class RestoreCancelled extends RestoreResult {
  const RestoreCancelled();
}

/// Восстановление отменено: причина показывается пользователю.
final class RestoreFailed extends RestoreResult {
  const RestoreFailed(this.reason);

  final RestoreFailureReason reason;
}

/// Восстановление базы из резервной копии.
///
/// Текущая база не удаляется и не перезаписывается: выбранный файл копируется в
/// каталог application support отдельным файлом, проверяется и только после
/// успешной проверки становится активным. При любом отказе копия удаляется, а
/// активная база и реестр остаются прежними (ADR-0006, решение 6.6).
class DatabaseRestoreUseCases {
  DatabaseRestoreUseCases({
    required this.files,
    required this.validator,
    required this.registry,
    required this.applyMigrations,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FileDialog files;
  final DatabaseRestoreValidator validator;
  final DatabaseRegistry registry;
  final DatabaseCandidateMigrator applyMigrations;
  final DateTime Function() _clock;

  /// Восстанавливает базу из выбранной пользователем копии.
  ///
  /// Мягкий перезапуск выполняет вызывающий код: после [RestoreSucceeded]
  /// активной становится восстановленная база, и приложение должно открыть ее.
  Future<RestoreResult> restore() async {
    Uint8List? bytes;
    try {
      bytes = await files.pickBytes();
    } on Exception {
      return const RestoreFailed(RestoreFailureReason.fileUnreadable);
    }
    if (bytes == null) {
      return const RestoreCancelled();
    }

    Directory directory;
    try {
      directory = await registry.supportDirectory();
    } on Exception {
      return const RestoreFailed(RestoreFailureReason.fileUnreadable);
    }

    final fileName = importedDatabaseFileName(_clock());
    final copy = File('${directory.path}${Platform.pathSeparator}$fileName');
    var activated = false;

    try {
      await copy.writeAsBytes(bytes, flush: true);

      final validation = await validator.validate(copy.path);
      if (validation is RestoreRejected) {
        return RestoreFailed(validation.reason);
      }
      if (!await applyMigrations(copy.path)) {
        return const RestoreFailed(
          RestoreFailureReason.notAnApplicationDatabase,
        );
      }

      await registry.registerActive(
        fileName: fileName,
        source: DatabaseSource.imported,
      );
      activated = true;
      return const RestoreSucceeded();
    } on Exception {
      return const RestoreFailed(RestoreFailureReason.fileUnreadable);
    } finally {
      // Успешная копия остается в приложении как активная база; отклоненная
      // удаляется, чтобы неработоспособный файл не копился в списке баз.
      if (!activated && copy.existsSync()) {
        await copy.delete();
      }
    }
  }
}
