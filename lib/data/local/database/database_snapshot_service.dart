import 'dart:io';

import 'package:budget_tracker/data/local/database/app_database.dart';

/// Снимок базы данных для резервной копии.
///
/// Снимок создается командой `VACUUM INTO`: она дает согласованный однофайловый
/// снимок всех таблиц без хвоста WAL и не блокирует запись. Копирование основного
/// файла при включенном WAL могло бы захватить неполное состояние (ADR-0006,
/// решение 6.4). Создание копии не изменяет данные приложения.
class DatabaseSnapshotService {
  const DatabaseSnapshotService(this.database);

  final AppDatabase database;

  /// Создает снимок текущей базы в файле [targetPath].
  ///
  /// Существующий файл по этому пути заменяется: снимок всегда формируется
  /// заново, а не дописывается.
  Future<void> snapshotTo(String targetPath) async {
    final target = File(targetPath);
    if (target.existsSync()) {
      await target.delete();
    }
    await database.customStatement('VACUUM INTO ?', [targetPath]);
  }
}
