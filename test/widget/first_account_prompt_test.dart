import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/domain/repositories/bootstrap_repositories.dart';
import 'package:budget_tracker/main.dart';
import 'package:budget_tracker/ui/features/accounts/views/account_form_page.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Bootstrap, который падает: проверяет контролируемое состояние ошибки.
class _FailingBootstrapRepository implements FirstRunBootstrapRepository {
  @override
  Future<FirstRunBootstrapResult> run({
    required String languageCode,
    required String defaultBookName,
  }) async {
    throw StateError('bootstrap failed');
  }
}

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting();
  });

  tearDown(() => database.close());

  Future<void> pumpApp(
    WidgetTester tester, {
    FirstRunBootstrapRepository? bootstrap,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          if (bootstrap != null)
            firstRunBootstrapRepositoryProvider.overrideWithValue(bootstrap),
        ],
        child: const BudgetTrackerApp(locale: Locale('ru')),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('показывает предложение добавить первый счет при пустой книге', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('Добавьте первый счет'), findsOneWidget);
    expect(find.text('Добавить счет'), findsOneWidget);
    expect(find.text('Пропустить'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('переходит к списку счетов после создания первого счета', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Добавить счет'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(accountFormNameFieldKey), 'Основной');
    await tester.tap(find.text('Сохранить'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Основной'), findsOneWidget);
    expect(find.text('Добавьте первый счет'), findsNothing);
  });

  testWidgets('переходит к оболочке после пропуска предложения', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Пока нет счетов'), findsOneWidget);
    expect(find.text('Добавьте первый счет'), findsNothing);
  });

  testWidgets('не показывает предложение при существующих счетах', (
    WidgetTester tester,
  ) async {
    final book = await DriftBooksRepository(
      database,
    ).create(name: 'Личная книга');
    await DriftAccountsRepository(database).create(
      bookId: book.id,
      name: 'Основной',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );

    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Основной'), findsOneWidget);
    expect(find.text('Добавьте первый счет'), findsNothing);
  });

  testWidgets('ошибка инициализации не показывает предложение первого счета', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester, bootstrap: _FailingBootstrapRepository());

    expect(
      find.text(
        'Не удалось подготовить данные приложения. Перезапустите приложение.',
      ),
      findsOneWidget,
    );
    expect(find.text('Добавьте первый счет'), findsNothing);
    expect(find.text('Пропустить'), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('пропуск предложения не изменяет данные первого запуска', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);
    final books = await database.select(database.books).get();
    final categories = await database.select(database.categories).get();
    final settings = await database.select(database.appSettings).get();

    await tester.tap(find.text('Пропустить'));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      await database.select(database.books).get(),
      hasLength(books.length),
    );
    expect(
      await database.select(database.categories).get(),
      hasLength(categories.length),
    );
    expect(
      await database.select(database.appSettings).get(),
      hasLength(settings.length),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await pumpApp(tester);

    expect(
      await database.select(database.books).get(),
      hasLength(books.length),
    );
    expect(
      await database.select(database.categories).get(),
      hasLength(categories.length),
    );
  });
}
