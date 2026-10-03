import 'dart:io';

import 'package:budget_tracker/data/local/database/database_snapshot_service.dart';
import 'package:budget_tracker/domain/repositories/file_dialogs.dart';
import 'package:budget_tracker/domain/services/export_file_name_rule.dart';
import 'package:path_provider/path_provider.dart';

/// Создание резервной копии данных приложения одним файлом `.sqlite`.
///
/// Копия — полный снимок всех таблиц базы; создание копии не изменяет данные
/// приложения. Файл передается пользователю системным диалогом сохранения
/// (ADR-0006, решения 6.4 и 6.5).
class DatabaseBackupUseCases {
  DatabaseBackupUseCases({
    required this.snapshot,
    required this.files,
    Future<Directory> Function()? temporaryDirectory,
    DateTime Function()? clock,
  }) : _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
       _clock = clock ?? DateTime.now;

  final DatabaseSnapshotService snapshot;
  final FileDialog files;
  final Future<Directory> Function() _temporaryDirectory;
  final DateTime Function() _clock;

  /// Сохраняет резервную копию и возвращает `false`, если пользователь отменил
  /// диалог сохранения.
  ///
  /// Имя файла формируется по маске `bt_YYYYMMDDHHmmss.sqlite` в момент
  /// создания копии. Снимок формируется в каталоге временных файлов и удаляется
  /// после передачи байтов диалогу: в приложении остается только активная база.
  /// Ошибка снимка или записи пробрасывается вызывающему; данные приложения при
  /// этом не изменяются.
  Future<bool> exportBackup() async {
    final fileName = exportFileName(timestamp: _clock(), extension: 'sqlite');
    final directory = await _temporaryDirectory();
    final path = '${directory.path}${Platform.pathSeparator}$fileName';
    final file = File(path);
    try {
      await snapshot.snapshotTo(path);
      final saved = await files.saveBytes(
        fileName: fileName,
        bytes: await file.readAsBytes(),
        mimeType: 'application/vnd.sqlite3',
      );
      return saved != null;
    } finally {
      if (file.existsSync()) {
        await file.delete();
      }
    }
  }
}
