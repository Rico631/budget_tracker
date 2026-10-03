import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/ui/features/settings/views/category_form_page.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late FinanceBook book;
  late CategoriesRepository categories;

  setUp(() async {
    database = AppDatabase.forTesting();
    book = await DriftBooksRepository(database).create(name: 'Личная книга');
    categories = DriftCategoriesRepository(database);
  });

  tearDown(() => database.close());

  Future<void> openForm(
    WidgetTester tester, {
    FinanceCategory? category,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => CategoryFormPage.open(
                    context,
                    bookId: book.id,
                    category: category,
                  ),
                  child: const Text('open-form'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open-form'));
    await tester.pumpAndSettle();
  }

  testWidgets('создание сохраняет категорию с выбранным типом', (
    WidgetTester tester,
  ) async {
    await openForm(tester);

    await tester.enterText(find.byKey(categoryFormNameFieldKey), 'Продукты');
    await tester.tap(find.byKey(categoryFormKindIncomeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(categoryFormSaveButtonKey));
    await tester.pumpAndSettle();

    final stored = await categories.listByBook(book.id);

    expect(stored.single.name, 'Продукты');
    expect(stored.single.kind, TransactionKind.income);
    expect(find.byType(CategoryFormPage), findsNothing);
  });

  testWidgets('без выбранного типа категория не сохраняется', (
    WidgetTester tester,
  ) async {
    await openForm(tester);

    await tester.enterText(find.byKey(categoryFormNameFieldKey), 'Продукты');
    await tester.tap(find.byKey(categoryFormSaveButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('Выберите тип категории.'), findsOneWidget);
    expect(await categories.listByBook(book.id), isEmpty);
  });
  testWidgets('переименование обновляет наименование категории', (
    WidgetTester tester,
  ) async {
    final groceries = await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );

    await openForm(tester, category: groceries);

    // Тип существующей категории показывается только для чтения.
    expect(find.text('Расход'), findsOneWidget);
    expect(find.byKey(categoryFormKindExpenseKey), findsNothing);

    await tester.enterText(find.byKey(categoryFormNameFieldKey), 'Еда');
    await tester.tap(find.byKey(categoryFormSaveButtonKey));
    await tester.pumpAndSettle();

    expect((await categories.getById(groceries.id))!.name, 'Еда');
    expect(
      (await categories.getById(groceries.id))!.kind,
      TransactionKind.expense,
    );
  });

  testWidgets('дубликат наименования отклоняется с сообщением', (
    WidgetTester tester,
  ) async {
    await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );

    await openForm(tester);

    await tester.enterText(find.byKey(categoryFormNameFieldKey), '  продукты ');
    await tester.tap(find.byKey(categoryFormKindExpenseKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(categoryFormSaveButtonKey));
    await tester.pumpAndSettle();

    expect(
      find.text('Категория с таким наименованием уже есть в этом типе.'),
      findsOneWidget,
    );
    expect(await categories.listByBook(book.id), hasLength(1));
  });

  testWidgets('базовая категория отклоняет переименование и удаление', (
    WidgetTester tester,
  ) async {
    final fallback = await categories.create(
      bookId: book.id,
      name: 'Прочие расходы',
      kind: TransactionKind.expense,
      isFallback: true,
    );

    await openForm(tester, category: fallback);

    expect(find.byKey(categoryFormFallbackNoticeKey), findsOneWidget);
    expect(find.textContaining('Базовую категорию нельзя'), findsOneWidget);
    expect(find.byKey(categoryFormSaveButtonKey), findsNothing);
    expect(find.byKey(categoryFormDeleteButtonKey), findsNothing);

    final nameField = tester.widget<TextField>(
      find.byKey(categoryFormNameFieldKey),
    );

    expect(nameField.enabled, isFalse);
    expect((await categories.getById(fallback.id))!.name, 'Прочие расходы');
  });

  testWidgets('отказ в диалоге удаления не изменяет данные', (
    WidgetTester tester,
  ) async {
    final accounts = DriftAccountsRepository(database);
    final transactions = DriftTransactionsRepository(database);
    final groceries = await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await categories.create(
      bookId: book.id,
      name: 'Прочие расходы',
      kind: TransactionKind.expense,
      isFallback: true,
    );
    final account = await accounts.create(
      bookId: book.id,
      name: 'Рубли',
      currencyCode: 'RUB',
      initialBalanceMinor: 100000,
    );
    final transaction = await transactions.create(
      bookId: book.id,
      accountId: account.id,
      categoryId: groceries.id,
      kind: TransactionKind.expense,
      amountMinor: 1500,
      occurredAt: DateTime(2026, 9, 24),
    );

    await openForm(tester, category: groceries);
    await tester.tap(find.byKey(categoryFormDeleteButtonKey));
    await tester.pumpAndSettle();

    // Диалог прямо сообщает о переносе операций в базовую категорию.
    expect(find.text('Удалить категорию?'), findsOneWidget);
    expect(
      find.textContaining('операции перейдут в базовую категорию'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(categoryFormDeleteCancelButtonKey));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryFormPage), findsOneWidget);
    expect((await categories.getById(groceries.id))!.name, 'Продукты');
    expect(
      (await transactions.getById(transaction.id))!.categoryId,
      groceries.id,
    );
    expect((await transactions.getById(transaction.id))!.amountMinor, 1500);
  });
}
