import 'dart:convert';
import 'dart:io';

import 'package:budget_tracker/data/local/database/file_database_registry.dart';
import 'package:budget_tracker/domain/models/database_registry_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late FileDatabaseRegistry registry;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('budget_tracker_db_');
    registry = FileDatabaseRegistry(supportDirectory: () async => directory);
  });

  tearDown(() => directory.delete(recursive: true));

  File fileIn(String name) =>
      File('${directory.path}${Platform.pathSeparator}$name');

  String? persistedActiveId() {
    final file = fileIn('db_registry.json');
    if (!file.existsSync()) {
      return null;
    }
    return (jsonDecode(file.readAsStringSync())
            as Map<String, Object?>)['activeId']
        as String?;
  }

  test(
    'создает реестр с текущей базой как активной при отсутствии файла',
    () async {
      final state = await registry.load();

      expect(state.entries, hasLength(1));
      expect(state.activeEntry.fileName, 'budget_tracker.sqlite');
      expect(state.activeEntry.source, DatabaseSource.original);
      expect(state.activeId, FileDatabaseRegistry.originalEntryId);
      expect(fileIn('db_registry.json').existsSync(), isTrue);
    },
  );

  test('записывает и читает список баз вместе с указателем активной', () async {
    await registry.load();
    await fileIn('import_1.sqlite').writeAsString('snapshot');

    final registered = await registry.registerActive(
      fileName: 'import_1.sqlite',
      source: DatabaseSource.imported,
    );

    expect(registered.entries, hasLength(2));
    expect(registered.activeEntry.fileName, 'import_1.sqlite');
    expect(registered.activeEntry.source, DatabaseSource.imported);

    final reloaded = await FileDatabaseRegistry(
      supportDirectory: () async => directory,
    ).load();

    expect(reloaded.entries, hasLength(2));
    expect(reloaded.activeEntry.fileName, 'import_1.sqlite');
    expect(
      reloaded.entries.map((entry) => entry.fileName),
      contains('budget_tracker.sqlite'),
    );
  });

  test('переключает активную базу между существующими файлами', () async {
    await fileIn('budget_tracker.sqlite').writeAsString('original');
    await fileIn('import_2.sqlite').writeAsString('snapshot');
    await registry.load();
    await registry.registerActive(
      fileName: 'import_2.sqlite',
      source: DatabaseSource.imported,
    );

    final switched = await registry.setActive(FileDatabaseRegistry.originalEntryId);

    expect(switched.activeEntry.fileName, 'budget_tracker.sqlite');
    expect(persistedActiveId(), FileDatabaseRegistry.originalEntryId);
  });

  test('восстанавливает реестр при нечитаемом содержимом файла', () async {
    await fileIn('db_registry.json').writeAsString('{ это не json');

    final state = await registry.load();

    expect(state.entries, hasLength(1));
    expect(state.activeEntry.fileName, 'budget_tracker.sqlite');
    expect(
      jsonDecode(fileIn('db_registry.json').readAsStringSync()),
      isA<Map<String, Object?>>(),
    );
  });

  test('отбрасывает отсутствующий файл активной базы при чтении', () async {
    await fileIn('budget_tracker.sqlite').writeAsString('original');
    await fileIn('db_registry.json').writeAsString(
      jsonEncode({
        'version': FileDatabaseRegistry.formatVersion,
        'activeId': 'imported-entry',
        'entries': [
          {
            'id': FileDatabaseRegistry.originalEntryId,
            'fileName': 'budget_tracker.sqlite',
            'createdAt': DateTime(2026, 1, 1).toIso8601String(),
            'source': 'original',
          },
          {
            'id': 'imported-entry',
            'fileName': 'import_removed.sqlite',
            'createdAt': DateTime(2026, 1, 2).toIso8601String(),
            'source': 'imported',
          },
        ],
      }),
    );

    final state = await registry.load();

    expect(state.entries, hasLength(1));
    expect(state.activeId, FileDatabaseRegistry.originalEntryId);
    expect(state.activeEntry.fileName, 'budget_tracker.sqlite');
    expect(persistedActiveId(), FileDatabaseRegistry.originalEntryId);
  });

  test('удаляет неактивную базу вместе с файлом, сохраняя активную', () async {
    await fileIn('budget_tracker.sqlite').writeAsString('original');
    await fileIn('import_3.sqlite').writeAsString('snapshot');
    await registry.load();
    final registered = await registry.registerActive(
      fileName: 'import_3.sqlite',
      source: DatabaseSource.imported,
    );
    final originalId = registered.entries.first.id;

    final updated = await registry.deleteDatabase(originalId);

    expect(updated.entries, hasLength(1));
    expect(updated.activeEntry.fileName, 'import_3.sqlite');
    expect(fileIn('budget_tracker.sqlite').existsSync(), isFalse);
  });

  test(
    'удаление единственной базы регистрирует исходную базу заново',
    () async {
      await fileIn('budget_tracker.sqlite').writeAsString('original');
      final state = await registry.load();
      expect(state.entries, hasLength(1));

      final updated = await registry.deleteDatabase(state.activeId);

      expect(updated.entries, hasLength(1));
      expect(updated.activeEntry.fileName, 'budget_tracker.sqlite');
      expect(updated.activeEntry.source, DatabaseSource.original);
      expect(fileIn('budget_tracker.sqlite').existsSync(), isFalse);
    },
  );

  test('запрещает удаление активной базы, пока есть другие базы', () async {
    await fileIn('budget_tracker.sqlite').writeAsString('original');
    await fileIn('import_5.sqlite').writeAsString('snapshot');
    final registered = await registry.registerActive(
      fileName: 'import_5.sqlite',
      source: DatabaseSource.imported,
    );

    await expectLater(
      registry.deleteDatabase(registered.activeId),
      throwsArgumentError,
    );

    expect(fileIn('import_5.sqlite').existsSync(), isTrue);
  });
}
