import 'dart:io';
import 'dart:typed_data';

import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/database/database_candidate_migrator.dart';
import 'package:budget_tracker/data/local/database/file_database_registry.dart';
import 'package:budget_tracker/domain/models/database_registry_models.dart';
import 'package:budget_tracker/data/local/database/drift_database_restore_validator.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/domain/repositories/database_validation.dart';
import 'package:budget_tracker/domain/repositories/file_dialogs.dart';
import 'package:budget_tracker/domain/usecases/database_restore_usecases.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Диалог выбора файла, отдающий заранее заданные байты.
class _ScriptedFileDialog implements FileDialog {
  _ScriptedFileDialog(this.bytes);

  final Uint8List? bytes;

  @override
  Future<Uint8List?> pickBytes({String? dialogTitle}) async => bytes;

  @override
  Future<Uri?> saveBytes({
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
    String? dialogTitle,
  }) async => null;
}

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late Directory sources;
  late AppDatabase current;
  late FileDatabaseRegistry registry;

  File fileIn(String name) =>
      File('${directory.path}${Platform.pathSeparator}$name');

  /// Файл-источник вне каталога приложения: как выбранный пользователем файл.
  File sourceFile(String name) =>
      File('${sources.path}${Platform.pathSeparator}$name');

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('budget_tracker_');
    sources = await Directory(
      '${directory.path}${Platform.pathSeparator}sources',
    ).create();
    current = AppDatabase.forTesting();
    registry = FileDatabaseRegistry(supportDirectory: () async => directory);
    await fileIn('budget_tracker.sqlite').writeAsString('текущая база');
    await registry.load();
  });

  tearDown(() async {
    await current.close();
    await directory.delete(recursive: true);
  });

  List<String> databaseFileNames() => directory
      .listSync()
      .map((entity) => entity.uri.pathSegments.last)
      .where((name) => name.endsWith('.sqlite'))
      .toList();

  /// Создает файл корректной базы данных приложения с книгой [bookName].
  Future<Uint8List> applicationDatabaseBytes(String bookName) async {
    final file = sourceFile('candidate_$bookName.sqlite');
    final database = AppDatabase.forTesting(NativeDatabase(file));
    await DriftBooksRepository(database).create(name: bookName);
    await database.close();
    return file.readAsBytes();
  }

  DatabaseRestoreUseCases useCasesWith(FileDialog files) =>
      DatabaseRestoreUseCases(
        files: files,
        validator: DriftDatabaseRestoreValidator(current),
        registry: registry,
        applyMigrations: applyMigrationsAndProbe,
        clock: () => DateTime(2026, 10, 3, 15, 40, 5),
      );

  test('сохраняет копию новой базой и делает ее активной', () async {
    final bytes = await applicationDatabaseBytes('Восстановленная книга');

    final result = await useCasesWith(_ScriptedFileDialog(bytes)).restore();

    expect(result, isA<RestoreSucceeded>());

    final state = await registry.load();
    expect(state.activeEntry.fileName, 'import_20261003_154005.sqlite');
    expect(state.activeEntry.source, DatabaseSource.imported);
    expect(
      databaseFileNames(),
      containsAll(['budget_tracker.sqlite', state.activeEntry.fileName]),
    );

    final restored = AppDatabase.forTesting(
      NativeDatabase(File(await registry.pathOf(state.activeEntry.fileName))),
    );
    addTearDown(restored.close);

    expect(
      (await restored.select(restored.books).get()).single.name,
      'Восстановленная книга',
    );
  });

  test('отклоняет некорректный файл и не трогает активную базу', () async {
    final broken = sourceFile('broken.sqlite');
    await broken.writeAsString('это не база данных');
    final bytes = await broken.readAsBytes();

    final result = await useCasesWith(_ScriptedFileDialog(bytes)).restore();

    expect(
      (result as RestoreFailed).reason,
      RestoreFailureReason.notAnApplicationDatabase,
    );
    expect(databaseFileNames(), ['budget_tracker.sqlite']);
    expect(
      (await registry.load()).activeEntry.fileName,
      'budget_tracker.sqlite',
    );
  });

  test('отказывает при версии схемы выше поддерживаемой', () async {
    final future = sourceFile('future.sqlite');
    final database = AppDatabase.forTesting(NativeDatabase(future));
    await DriftBooksRepository(database).create(name: 'Из будущего');
    await database.customStatement('PRAGMA user_version = 6');
    await database.close();

    final result = await useCasesWith(
      _ScriptedFileDialog(await future.readAsBytes()),
    ).restore();

    expect(
      (result as RestoreFailed).reason,
      RestoreFailureReason.unsupportedSchemaVersion,
    );
    expect(databaseFileNames(), ['budget_tracker.sqlite']);
  });

  test('отмена выбора файла ничего не меняет', () async {
    final result = await useCasesWith(_ScriptedFileDialog(null)).restore();

    expect(result, isA<RestoreCancelled>());
    expect(databaseFileNames(), ['budget_tracker.sqlite']);
  });
}
