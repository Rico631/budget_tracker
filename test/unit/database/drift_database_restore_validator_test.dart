import 'dart:io';

import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/database/drift_database_snapshot_service.dart';
import 'package:budget_tracker/data/local/database/drift_database_restore_validator.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/domain/repositories/database_validation.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Directory directory;
  late AppDatabase current;
  late DriftDatabaseRestoreValidator validator;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('budget_tracker_');
    current = AppDatabase.forTesting();
    validator = DriftDatabaseRestoreValidator(current);
  });

  tearDown(() async {
    await current.close();
    await directory.delete(recursive: true);
  });

  File fileIn(String name) =>
      File('${directory.path}${Platform.pathSeparator}$name');

  Future<int> schemaVersionOf(String path) async {
    final database = AppDatabase.forTesting(
      NativeDatabase(File(path), enableMigrations: false),
    );
    addTearDown(database.close);
    final row = await database.customSelect('PRAGMA user_version').getSingle();
    return row.data['user_version']! as int;
  }

  test('принимает корректный снимок базы', () async {
    await DriftBooksRepository(current).create(name: 'Личная книга');
    final snapshot = fileIn('snapshot.sqlite');
    await DriftDatabaseSnapshotService(current).snapshotTo(snapshot.path);

    expect(await validator.validate(snapshot.path), isA<RestoreAccepted>());
  });

  test('отклоняет файл, который не является базой данных', () async {
    final broken = fileIn('broken.sqlite');
    await broken.writeAsString('это не база данных приложения');

    final result = await validator.validate(broken.path);

    expect(result, isA<RestoreRejected>());
    expect(
      (result as RestoreRejected).reason,
      RestoreFailureReason.notAnApplicationDatabase,
    );
  });

  test('отклоняет базу данных посторонней схемы', () async {
    final foreign = fileIn('foreign.sqlite');
    final database = AppDatabase.forTesting(
      NativeDatabase(File(foreign.path), enableMigrations: false),
    );
    await database.customStatement('CREATE TABLE notes (id TEXT NOT NULL)');
    await database.customStatement('PRAGMA user_version = 3');
    await database.close();

    final result = await validator.validate(foreign.path);

    expect(result, isA<RestoreRejected>());
    expect(
      (result as RestoreRejected).reason,
      RestoreFailureReason.notAnApplicationDatabase,
    );
    expect(await schemaVersionOf(foreign.path), 3);
  });

  test('отклоняет версию схемы выше поддерживаемой и не меняет файл', () async {
    final future = fileIn('future.sqlite');
    final database = AppDatabase.forTesting(NativeDatabase(File(future.path)));
    await DriftBooksRepository(database).create(name: 'Из будущего');
    await database.customStatement('PRAGMA user_version = 8');
    await database.close();

    final result = await validator.validate(future.path);

    expect(result, isA<RestoreRejected>());
    expect(
      (result as RestoreRejected).reason,
      RestoreFailureReason.unsupportedSchemaVersion,
    );
    expect(
      await schemaVersionOf(future.path),
      8,
      reason: 'проверка не применяет миграции к кандидату',
    );
  });

  test('принимает базу версии ниже текущей', () async {
    final older = fileIn('older.sqlite');
    final database = AppDatabase.forTesting(NativeDatabase(File(older.path)));
    await DriftBooksRepository(database).create(name: 'Старая книга');
    await database.customStatement('DROP TABLE currencies');
    await database.customStatement('DROP TABLE app_settings');
    await database.customStatement('PRAGMA user_version = 2');
    await database.close();

    expect(await validator.validate(older.path), isA<RestoreAccepted>());
  });

  test('принимает копию версии 5 без таблицы контрагентов', () async {
    final older = fileIn('version5.sqlite');
    final database = AppDatabase.forTesting(NativeDatabase(File(older.path)));
    await DriftBooksRepository(database).create(name: 'Книга версии 5');
    await database.customStatement('DROP TABLE counterparties');
    await database.customStatement('PRAGMA user_version = 5');
    await database.close();

    expect(await validator.validate(older.path), isA<RestoreAccepted>());
  });

  test('отклоняет копию версии 6 без таблицы контрагентов', () async {
    final broken = fileIn('version6.sqlite');
    final database = AppDatabase.forTesting(NativeDatabase(File(broken.path)));
    await DriftBooksRepository(database).create(name: 'Книга без контрагентов');
    await database.customStatement('DROP TABLE counterparties');
    await database.customStatement('PRAGMA user_version = 6');
    await database.close();

    final result = await validator.validate(broken.path);

    expect(result, isA<RestoreRejected>());
    expect(
      (result as RestoreRejected).reason,
      RestoreFailureReason.notAnApplicationDatabase,
    );
  });

  test('копия текущей версии содержит все таблицы карты приложения', () async {
    await DriftBooksRepository(current).create(name: 'Личная книга');
    final snapshot = fileIn('current.sqlite');
    await DriftDatabaseSnapshotService(current).snapshotTo(snapshot.path);

    final tables = await _tablesOf(snapshot.path);

    expect(tables, containsAll(requiredTablesFor(current.schemaVersion)));
    expect(tables, contains('counterparties'));
  });
}

Future<Set<String>> _tablesOf(String path) async {
  final database = AppDatabase.forTesting(
    NativeDatabase(File(path), enableMigrations: false),
  );
  addTearDown(database.close);
  final rows = await database
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return {for (final row in rows) row.data['name'] as String};
}
