import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:budget_tracker/core/di/app_lifecycle_providers.dart';
import 'package:budget_tracker/core/di/data_management_providers.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/router/app_shell.dart';
import 'package:budget_tracker/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/database/file_database_registry.dart';
import 'package:budget_tracker/domain/models/database_registry_models.dart';
import 'package:budget_tracker/data/local/database/drift_database_snapshot_service.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/database_validation.dart';
import 'package:budget_tracker/domain/repositories/file_dialogs.dart';
import 'package:budget_tracker/domain/usecases/database_backup_usecases.dart';
import 'package:budget_tracker/domain/usecases/database_restore_usecases.dart';
import 'package:budget_tracker/presentation/features/settings/data_management_page.dart';
import 'package:budget_tracker/presentation/features/settings/database_list_page.dart';
import 'package:budget_tracker/presentation/features/settings/journal_export_page.dart';
import 'package:budget_tracker/presentation/features/settings/settings_page.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

const String _importedFileName = 'import_20260101_000000.sqlite';

/// Диалог сохранения, запоминающий байты вместо записи файла.
class _RecordingFileDialog implements FileDialog {
  final List<Uint8List> saved = [];
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
    saved.add(bytes);
    return Uri.parse('content://export/$fileName');
  }

  @override
  Future<Uint8List?> pickBytes({String? dialogTitle}) async => null;
}

/// Валидатор, который принимает любой файл: заглушка для виджет-тестов.
class _AcceptingValidator implements DatabaseRestoreValidator {
  const _AcceptingValidator();

  @override
  Future<RestoreValidation> validate(String path) async =>
      const RestoreAccepted();
}

/// Заглушка создания резервной копии с заданным результатом.
class _StubBackupUseCases extends DatabaseBackupUseCases {
  _StubBackupUseCases(
    this.result, {
    required super.snapshot,
    required super.files,
  });

  final bool result;

  @override
  Future<bool> exportBackup() async => result;
}

/// Заглушка создания резервной копии, завершающаяся ошибкой.
class _FailingBackupUseCases extends DatabaseBackupUseCases {
  _FailingBackupUseCases({required super.snapshot, required super.files});

  @override
  Future<bool> exportBackup() async => throw const FileSystemException();
}

/// Заглушка восстановления с заданным результатом.
class _StubRestoreUseCases extends DatabaseRestoreUseCases {
  _StubRestoreUseCases(
    this.result, {
    required super.files,
    required super.registry,
  }) : super(
         validator: const _AcceptingValidator(),
         applyMigrations: (_) async => true,
       );

  final RestoreResult result;

  @override
  Future<RestoreResult> restore() async => result;
}

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late FileDatabaseRegistry registry;
  late AppDatabase database;
  late _RecordingFileDialog dialog;
  late int restartCount;

  File fileIn(String name) =>
      File('${directory.path}${Platform.pathSeparator}$name');

  Future<void> seedBook() async {
    final book = await DriftBooksRepository(database).create(name: 'Книга');
    final account = await DriftAccountsRepository(database).create(
      bookId: book.id,
      name: 'Карта',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final category = await DriftCategoriesRepository(
      database,
    ).create(bookId: book.id, name: 'Продукты', kind: TransactionKind.expense);
    await DriftTransactionsRepository(database).create(
      bookId: book.id,
      accountId: account.id,
      categoryId: category.id,
      kind: TransactionKind.expense,
      amountMinor: 12345,
      occurredAt: DateTime(2026, 5, 6, 7, 8, 9),
    );
  }

  /// Создает в каталоге приложения исходную базу и, при необходимости,
  /// восстановленную копию, и делает активной исходную.
  ///
  /// Файлы пишутся синхронно: помощник вызывается и из тел виджет-тестов, где
  /// реальный асинхронный ввод-вывод не завершается.
  Future<void> seedRegistry({required bool withImported}) async {
    fileIn('budget_tracker.sqlite').writeAsStringSync('исходная база');
    registry = FileDatabaseRegistry(supportDirectory: () async => directory);
    await registry.load();
    if (withImported) {
      fileIn(_importedFileName).writeAsStringSync('восстановленная база');
      await registry.registerActive(
        fileName: _importedFileName,
        source: DatabaseSource.imported,
      );
      await registry.setActive(FileDatabaseRegistry.originalEntryId);
    }
  }

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('budget_tracker_');
    database = AppDatabase.forTesting();
    dialog = _RecordingFileDialog();
    restartCount = 0;
    await seedBook();
    await seedRegistry(withImported: false);
  });

  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  void restart() => restartCount++;

  /// Возврат назад по нажатию кнопки в заголовке подэкрана.
  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  Future<void> pumpPage(
    WidgetTester tester,
    Widget home, {
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          databaseRegistryProvider.overrideWithValue(registry),
          fileDialogProvider.overrideWithValue(dialog),
          appRestartProvider.overrideWithValue(restart),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: home,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openDataManagement(WidgetTester tester) async {
    await pumpPage(tester, const AppShell());
    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(settingsDataManagementItemKey));
    await tester.pumpAndSettle();
  }

  testWidgets('пункт «Экспорт и базы данных» открывает подэкран раздела', (
    tester,
  ) async {
    await pumpPage(tester, const AppShell());

    await tester.tap(find.text('Настройки'));
    await tester.pumpAndSettle();

    expect(find.byKey(settingsDataManagementItemKey), findsOneWidget);
    expect(find.text('Экспорт и базы данных'), findsOneWidget);

    await tester.tap(find.byKey(settingsDataManagementItemKey));
    await tester.pumpAndSettle();

    expect(find.text('Выгрузка журнала'), findsOneWidget);
    expect(find.text('Резервная копия'), findsOneWidget);
    expect(find.text('Восстановление из копии'), findsOneWidget);
    expect(find.text('Базы данных'), findsOneWidget);

    await goBack(tester);

    expect(find.byKey(settingsDataManagementItemKey), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
  });

  testWidgets('подэкран открывает выгрузку журнала и список баз', (
    tester,
  ) async {
    await openDataManagement(tester);

    await tester.tap(find.byKey(dataManagementJournalExportItemKey));
    await tester.pumpAndSettle();

    expect(find.byType(JournalExportPage), findsOneWidget);
    expect(find.byKey(journalExportButtonKey), findsOneWidget);

    await goBack(tester);

    await tester.tap(find.byKey(dataManagementDatabaseListItemKey));
    await tester.pumpAndSettle();

    expect(find.byType(DatabaseListPage), findsOneWidget);
    expect(find.text('Текущая'), findsOneWidget);
  });

  testWidgets('ошибка создания резервной копии сообщается пользователю', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const DataManagementPage(),
      overrides: [
        databaseBackupUseCasesProvider.overrideWithValue(
          _FailingBackupUseCases(
            snapshot: DriftDatabaseSnapshotService(database),
            files: dialog,
          ),
        ),
      ],
    );

    await tester.tap(find.byKey(dataManagementBackupItemKey));
    await tester.pumpAndSettle();

    expect(find.text('Не удалось создать резервную копию.'), findsOneWidget);
  });

  testWidgets('успешная резервная копия подтверждается сообщением', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const DataManagementPage(),
      overrides: [
        databaseBackupUseCasesProvider.overrideWithValue(
          _StubBackupUseCases(
            true,
            snapshot: DriftDatabaseSnapshotService(database),
            files: dialog,
          ),
        ),
      ],
    );

    await tester.tap(find.byKey(dataManagementBackupItemKey));
    await tester.pumpAndSettle();

    expect(find.text('Резервная копия сохранена.'), findsOneWidget);
  });

  testWidgets('отказ восстановления показывает причину', (tester) async {
    await pumpPage(
      tester,
      const DataManagementPage(),
      overrides: [
        databaseRestoreUseCasesProvider.overrideWithValue(
          _StubRestoreUseCases(
            const RestoreFailed(RestoreFailureReason.unsupportedSchemaVersion),
            files: dialog,
            registry: registry,
          ),
        ),
      ],
    );

    await tester.tap(find.byKey(dataManagementRestoreItemKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Версия базы выше поддерживаемой приложением.'),
      findsOneWidget,
    );
    expect(restartCount, 0);
  });

  testWidgets('успешное восстановление перезапускает приложение', (
    tester,
  ) async {
    await pumpPage(
      tester,
      const DataManagementPage(),
      overrides: [
        databaseRestoreUseCasesProvider.overrideWithValue(
          _StubRestoreUseCases(
            const RestoreSucceeded(),
            files: dialog,
            registry: registry,
          ),
        ),
      ],
    );

    await tester.tap(find.byKey(dataManagementRestoreItemKey));
    await tester.pumpAndSettle();

    expect(restartCount, 1);
  });

  testWidgets('список баз отмечает текущую и запрещает ее удаление', (
    tester,
  ) async {
    await seedRegistry(withImported: true);

    await pumpPage(tester, const DatabaseListPage());

    final state = await registry.load();
    final original = state.entries.firstWhere(
      (entry) => entry.fileName == 'budget_tracker.sqlite',
    );
    final imported = state.entries.firstWhere(
      (entry) => entry.fileName == _importedFileName,
    );

    expect(find.text('Текущая'), findsOneWidget);
    expect(
      find.byKey(databaseListDeleteKey(original.id)),
      findsNothing,
      reason: 'активную базу удалить нельзя, пока есть другие базы',
    );
    expect(find.byKey(databaseListMakeActiveKey(original.id)), findsNothing);
    expect(find.byKey(databaseListMakeActiveKey(imported.id)), findsOneWidget);
    expect(find.byKey(databaseListDeleteKey(imported.id)), findsOneWidget);
  });

  testWidgets('список баз показывает дату и время создания', (tester) async {
    await seedRegistry(withImported: true);
    final createdAt = DateTime(2026, 10, 3, 15, 40, 5);
    final state = await registry.load();
    fileIn('db_registry.json').writeAsStringSync(
      jsonEncode({
        'version': FileDatabaseRegistry.formatVersion,
        'activeId': state.activeId,
        'entries': [
          for (final entry in state.entries)
            {
              'id': entry.id,
              'fileName': entry.fileName,
              'source': entry.source.name,
              'createdAt': createdAt.toIso8601String(),
            },
        ],
      }),
    );

    await pumpPage(tester, const DatabaseListPage());

    expect(
      find.text(formatDatabaseEntryLabel('ru', createdAt)),
      findsNWidgets(2),
      reason: 'время отличает базы, созданные в один день',
    );
  });

  testWidgets('переключение активной базы обновляет реестр и перезапускает', (
    tester,
  ) async {
    await seedRegistry(withImported: true);
    await pumpPage(tester, const DatabaseListPage());

    final imported = (await registry.load()).entries.firstWhere(
      (entry) => entry.fileName == _importedFileName,
    );

    await tester.tap(find.byKey(databaseListMakeActiveKey(imported.id)));
    await tester.pumpAndSettle();

    expect((await registry.load()).activeId, imported.id);
    expect(restartCount, 1);
  });

  testWidgets('удаление базы требует подтверждения', (tester) async {
    await seedRegistry(withImported: true);
    await pumpPage(tester, const DatabaseListPage());

    final imported = (await registry.load()).entries.firstWhere(
      (entry) => entry.fileName == _importedFileName,
    );

    await tester.tap(find.byKey(databaseListDeleteKey(imported.id)));
    await tester.pumpAndSettle();

    expect(find.text('Удалить базу?'), findsOneWidget);
    expect(find.textContaining('будет удалена безвозвратно'), findsOneWidget);

    await tester.tap(find.byKey(databaseListDeleteCancelKey));
    await tester.pumpAndSettle();

    expect(fileIn(_importedFileName).existsSync(), isTrue);
    expect(restartCount, 0);

    await tester.tap(find.byKey(databaseListDeleteKey(imported.id)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(databaseListDeleteConfirmKey));
    await tester.pumpAndSettle();

    expect(fileIn(_importedFileName).existsSync(), isFalse);
    expect((await registry.load()).entries, hasLength(1));
    expect(restartCount, 1);
  });

  testWidgets('удаление единственной базы создает новую базу', (tester) async {
    await pumpPage(tester, const DatabaseListPage());

    final original = (await registry.load()).entries.single;

    expect(find.byKey(databaseListDeleteKey(original.id)), findsOneWidget);

    await tester.tap(find.byKey(databaseListDeleteKey(original.id)));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('После удаления будет создана новая пустая база'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(databaseListDeleteConfirmKey));
    await tester.pumpAndSettle();

    final state = await registry.load();
    expect(state.entries, hasLength(1));
    expect(state.activeEntry.fileName, 'budget_tracker.sqlite');
    expect(state.activeEntry.source, DatabaseSource.original);
    expect(fileIn('budget_tracker.sqlite').existsSync(), isFalse);
    expect(restartCount, 1);
  });

  testWidgets('выгрузка журнала следует выбранному языку', (tester) async {
    await pumpPage(tester, const JournalExportPage());

    await tester.tap(find.byKey(journalExportButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Журнал выгружен.'), findsOneWidget);

    final russian = utf8.decode(dialog.saved.first.sublist(3));
    expect(
      russian,
      'Дата;Тип;Счет;Валюта;Категория;Заметка;Сумма;Счет получателя;'
      'Валюта получателя;Сумма зачисления\n'
      '2026-05-06 07:08:09;Расход;Карта;RUB;Продукты;;-123,45;;;\n',
    );

    await tester.tap(find.text('Английский'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(journalExportButtonKey));
    await tester.pumpAndSettle();

    final english = utf8.decode(dialog.saved.last.sublist(3));
    expect(
      english,
      'Date,Type,Account,Currency,Category,Note,Amount,To account,'
      'To currency,To amount\n'
      '2026-05-06 07:08:09,Expense,Карта,RUB,Продукты,,-123.45,,,\n',
    );
  });
}
