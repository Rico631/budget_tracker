import 'dart:io';
import 'dart:typed_data';

import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/database/drift_database_snapshot_service.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/domain/repositories/file_dialogs.dart';
import 'package:budget_tracker/domain/usecases/database_backup_usecases.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Диалог сохранения, запоминающий байты вместо записи файла.
class _RecordingFileDialog implements FileDialog {
  final List<Uint8List> saved = [];
  String? savedFileName;
  String? savedMimeType;
  bool cancelSave = false;

  @override
  Future<Uri?> saveBytes({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
  }) async {
    if (cancelSave) {
      return null;
    }
    savedFileName = fileName;
    savedMimeType = mimeType;
    saved.add(bytes);
    return Uri.parse('content://backup/$fileName');
  }

  @override
  Future<Uint8List?> pickBytes({String? dialogTitle}) async => null;
}

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late AppDatabase database;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('budget_tracker_');
    database = AppDatabase.forTesting();
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  DatabaseBackupUseCases useCasesWith(_RecordingFileDialog dialog) =>
      DatabaseBackupUseCases(
        snapshot: DriftDatabaseSnapshotService(database),
        files: dialog,
        temporaryDirectory: () async => directory,
        clock: () => DateTime(2026, 10, 3, 15, 40, 5),
      );

  test('сохраняет копию всех данных и убирает временный файл', () async {
    await DriftBooksRepository(database).create(name: 'Личная книга');
    final dialog = _RecordingFileDialog();

    final saved = await useCasesWith(dialog).exportBackup();

    expect(saved, isTrue);
    expect(dialog.savedFileName, 'bt_20261003154005.sqlite');
    expect(dialog.savedMimeType, 'application/vnd.sqlite3');
    expect(
      directory.listSync(),
      isEmpty,
      reason: 'снимок не остается в приложении после передачи файла',
    );

    final copy = File('${directory.path}${Platform.pathSeparator}copy.sqlite');
    await copy.writeAsBytes(dialog.saved.single);
    final restored = AppDatabase.forTesting(NativeDatabase(copy));
    addTearDown(restored.close);

    expect(
      (await restored.select(restored.books).get()).single.name,
      'Личная книга',
    );
  });

  test(
    'отмена диалога сохранения не изменяет данные и не оставляет файлов',
    () async {
      await DriftBooksRepository(database).create(name: 'Личная книга');
      final dialog = _RecordingFileDialog()..cancelSave = true;

      final saved = await useCasesWith(dialog).exportBackup();

      expect(saved, isFalse);
      expect(dialog.saved, isEmpty);
      expect(directory.listSync(), isEmpty);
      expect(await database.select(database.books).get(), hasLength(1));
    },
  );
}
