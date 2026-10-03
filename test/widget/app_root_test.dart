import 'dart:io';

import 'package:budget_tracker/core/di/app_lifecycle_providers.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/database/database_registry.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/first_run_bootstrap_repository.dart';
import 'package:budget_tracker/presentation/features/bootstrap/app_root.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

const String _importedFileName = 'import_20260101_000000.sqlite';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late DatabaseRegistry registry;

  File fileIn(String name) =>
      File('${directory.path}${Platform.pathSeparator}$name');

  /// Открывает базу по пути из `activeDatabasePathProvider` без фонового
  /// изолята `drift_flutter`, недоступного в тестовом окружении.
  List<Override> databaseOverrides() => [
    appDatabaseProvider.overrideWith((ref) {
      final path = ref.watch(activeDatabasePathProvider);
      final database = AppDatabase.forFile(path!);
      ref.onDispose(database.close);
      return database;
    }),
  ];

  /// Создает готовую к работе базу приложения с одним счетом [accountName].
  Future<void> seedDatabase(String fileName, String accountName) async {
    final database = AppDatabase.forFile(fileIn(fileName).path);
    await DriftFirstRunBootstrapRepository(
      database,
    ).run(languageCode: 'ru', defaultBookName: 'Личная книга');
    final book = (await DriftBooksRepository(database).list()).single;
    await DriftAccountsRepository(database).create(
      bookId: book.id,
      name: accountName,
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    await database.close();
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('budget_tracker_');
    registry = DatabaseRegistry(supportDirectory: () async => directory);
    await seedDatabase('budget_tracker.sqlite', 'Счет первой базы');
    await seedDatabase(_importedFileName, 'Счет второй базы');
    await registry.load();
    await registry.registerActive(
      fileName: _importedFileName,
      source: DatabaseSource.imported,
    );
    await registry.setActive(DatabaseRegistry.originalEntryId);
  });

  tearDown(() async {
    // Контейнер освобождает соединение с базой асинхронно, поэтому файл может
    // оставаться занятым еще мгновение после завершения теста.
    for (var attempt = 0; attempt < 40; attempt++) {
      try {
        await directory.delete(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
  });

  testWidgets('после мягкого перезапуска открывается выбранная база', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      AppRoot(
        registry: registry,
        locale: const Locale('ru'),
        overrides: databaseOverrides(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Счет первой базы'), findsOneWidget);
    expect(find.text('Счет второй базы'), findsNothing);

    // Файловые операции реестра выполняются вне тестового цикла кадров:
    // реальный ввод-вывод не завершается внутри `testWidgets`.
    await tester.runAsync(() async {
      final state = await registry.load();
      final imported = state.entries.firstWhere(
        (entry) => entry.fileName == _importedFileName,
      );
      await registry.setActive(imported.id);
    });

    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    container.read(appRestartProvider)();
    await tester.pumpAndSettle();

    expect(find.text('Счет второй базы'), findsOneWidget);
    expect(find.text('Счет первой базы'), findsNothing);
  });
}
