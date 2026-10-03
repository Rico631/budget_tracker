import 'dart:io';

import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/database/drift_database_snapshot_service.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  File fileIn(String name) =>
      File('${directory.path}${Platform.pathSeparator}$name');

  test('создает однофайловый снимок и не изменяет текущие данные', () async {
    final book = await DriftBooksRepository(
      database,
    ).create(name: 'Личная книга');
    await DriftAccountsRepository(database).create(
      bookId: book.id,
      name: 'Карта',
      currencyCode: 'RUB',
      initialBalanceMinor: 10000,
    );
    final target = fileIn('snapshot.sqlite');

    await DriftDatabaseSnapshotService(database).snapshotTo(target.path);

    expect(target.existsSync(), isTrue);
    expect(directory.listSync().map((entity) => entity.uri.pathSegments.last), [
      'snapshot.sqlite',
    ]);

    expect(await database.select(database.books).get(), hasLength(1));
    expect(await database.select(database.accounts).get(), hasLength(1));

    final snapshot = AppDatabase.forTesting(NativeDatabase(target));
    addTearDown(snapshot.close);

    expect(
      (await snapshot.select(snapshot.books).get()).single.name,
      'Личная книга',
    );
    expect(
      (await snapshot.select(snapshot.accounts).get()).single.name,
      'Карта',
    );
    expect(
      (await snapshot.customSelect('PRAGMA user_version').getSingle())
          .data['user_version'],
      database.schemaVersion,
    );
  });

  test('перезаписывает существующий файл снимка', () async {
    await DriftBooksRepository(database).create(name: 'Личная книга');
    final target = fileIn('snapshot.sqlite');
    await target.writeAsString('не база данных');

    await DriftDatabaseSnapshotService(database).snapshotTo(target.path);

    final snapshot = AppDatabase.forTesting(NativeDatabase(target));
    addTearDown(snapshot.close);

    expect(await snapshot.select(snapshot.books).get(), hasLength(1));
  });
}
