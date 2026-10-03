import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/theme/app_theme.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/usecases/finance_transaction_usecases.dart';
import 'package:budget_tracker/ui/features/transactions/views/transaction_form_page.dart';
import 'package:budget_tracker/ui/features/transactions/views/transactions_page.dart';
import 'package:budget_tracker/ui/features/transactions/widgets/transaction_tile.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late FinanceBook book;
  late AccountsRepository accounts;
  late CategoriesRepository categories;
  late TransactionsRepository transactions;

  setUp(() async {
    database = AppDatabase.forTesting();
    await database.batch((batch) {
      batch.insertAll(database.currencies, [
        currencyToCompanion(
          FinanceCurrency(
            code: 'RUB',
            numericCode: '643',
            symbol: '₽',
            nameRu: 'Российский рубль',
            nameEn: 'Russian Ruble',
          ),
        ),
        currencyToCompanion(
          FinanceCurrency(
            code: 'USD',
            numericCode: '840',
            symbol: r'$',
            nameRu: 'Доллар США',
            nameEn: 'US Dollar',
          ),
        ),
      ]);
    });
    book = await DriftBooksRepository(database).create(name: 'Личная книга');
    accounts = DriftAccountsRepository(database);
    categories = DriftCategoriesRepository(database);
    transactions = DriftTransactionsRepository(database);
  });

  tearDown(() => database.close());

  Future<FinanceAccount> createAccount({
    required String name,
    String currencyCode = 'RUB',
    int initialBalanceMinor = 0,
  }) => accounts.create(
    bookId: book.id,
    name: name,
    currencyCode: currencyCode,
    initialBalanceMinor: initialBalanceMinor,
  );

  Future<FinanceCategory> createCategory({
    required String name,
    required TransactionKind kind,
  }) => categories.create(bookId: book.id, name: name, kind: kind);

  Future<void> pumpPage(
    WidgetTester tester, {
    List<Override> overrides = const [],
  }) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          ...overrides,
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: const [Locale('ru'), Locale('en')],
          home: const Scaffold(body: TransactionsPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('пустая книга показывает приглашение добавить операцию', (
    WidgetTester tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('Операций пока нет'), findsOneWidget);
    expect(
      find.text(
        'Добавьте первую операцию, чтобы история книги начала заполняться.',
      ),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(FilledButton, 'Добавить операцию'),
      findsOneWidget,
    );
  });

  testWidgets('ошибка загрузки показывает сообщение и повторную загрузку', (
    WidgetTester tester,
  ) async {
    await createAccount(name: 'Рубли');

    await pumpPage(
      tester,
      overrides: [
        financeTransactionUseCasesProvider.overrideWithValue(
          _FailingJournalUseCases(
            accounts: accounts,
            categories: categories,
            transactions: transactions,
          ),
        ),
      ],
    );

    expect(
      find.text('Не удалось загрузить историю операций. Попробуйте еще раз.'),
      findsOneWidget,
    );
    expect(find.widgetWithText(FilledButton, 'Повторить'), findsOneWidget);
    expect(find.text('Операций пока нет'), findsNothing);
  });

  testWidgets('история сгруппирована по дням и упорядочена от новых к старым', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final cafe = await createCategory(
      name: 'Кафе',
      kind: TransactionKind.expense,
    );
    final salary = await createCategory(
      name: 'Зарплата',
      kind: TransactionKind.income,
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 15000,
      occurredAt: DateTime(2026, 9, 24, 12),
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: salary.id,
      kind: TransactionKind.income,
      amountMinor: 50000,
      occurredAt: DateTime(2026, 9, 26, 9),
    );

    await pumpPage(tester);

    expect(find.text('Расход'), findsOneWidget);
    expect(find.text('Доход'), findsOneWidget);
    expect(find.text('-150,00 ₽'), findsOneWidget);
    expect(find.text('+500,00 ₽'), findsOneWidget);
    expect(find.text('Кафе · Рубли'), findsOneWidget);

    final orderedAmounts = tester
        .widgetList<Text>(find.byType(Text))
        .map((text) => text.data)
        .where((value) => value == '-150,00 ₽' || value == '+500,00 ₽')
        .toList();
    expect(orderedAmounts, ['+500,00 ₽', '-150,00 ₽']);

    // Фильтров по счету, категории и периоду в истории нет: фильтрация
    // относится к аналитике (ADR 2.5).
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.filter_list), findsNothing);
  });

  testWidgets('строка операции растянута по ширине списка', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final cafe = await createCategory(
      name: 'Кафе',
      kind: TransactionKind.expense,
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 15000,
      occurredAt: DateTime(2026, 9, 24),
    );

    await pumpPage(tester);

    final viewportWidth =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final row = tester.getRect(find.byType(TransactionTile));
    final label = tester.getRect(find.text('Расход'));
    final amount = tester.getRect(find.text('-150,00 ₽'));

    // Строка занимает всю ширину списка.
    expect(row.left, 0);
    expect(row.right, viewportWidth);
    // Тип операции показан у левого края строки, сумма — у правого: между ними
    // нет пустого пространства, которое остается при выравнивании в начало
    // (раньше справа от суммы оставалось около 40% ширины строки).
    expect(label.left - row.left, lessThan(80));
    expect(row.right - amount.right, lessThan(row.width * 0.1));
  });

  testWidgets('показывает операции архивированного счета с названием счета', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final cafe = await createCategory(
      name: 'Кафе',
      kind: TransactionKind.expense,
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 15000,
      occurredAt: DateTime(2026, 9, 24),
    );
    await accounts.archive(rubles.id);

    await pumpPage(tester);

    expect(find.text('Расход'), findsOneWidget);
    expect(find.text('Кафе · Рубли'), findsOneWidget);
  });

  testWidgets('показывает перевод одной валюты без категории', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(
      name: 'Рубли',
      initialBalanceMinor: 100000,
    );
    final savings = await createAccount(name: 'Копилка');
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      toAccountId: savings.id,
      kind: TransactionKind.transfer,
      amountMinor: 30000,
      occurredAt: DateTime(2026, 9, 24),
    );

    await pumpPage(tester);

    expect(find.text('Перевод'), findsOneWidget);
    expect(find.text('Рубли → Копилка'), findsOneWidget);
    expect(find.text('300,00 ₽'), findsOneWidget);
    expect(find.textContaining('·'), findsNothing);
  });

  testWidgets(
    'показывает мультивалютный перевод с суммой зачисления и курсом',
    (WidgetTester tester) async {
      final dollars = await createAccount(
        name: 'Доллары',
        currencyCode: 'USD',
        initialBalanceMinor: 100000,
      );
      final rubles = await createAccount(name: 'Рубли');
      await transactions.create(
        bookId: book.id,
        accountId: dollars.id,
        toAccountId: rubles.id,
        kind: TransactionKind.transfer,
        amountMinor: 10000,
        toAmountMinor: 91500,
        occurredAt: DateTime(2026, 9, 24),
      );

      await pumpPage(tester);

      expect(find.text('Доллары → Рубли'), findsOneWidget);
      expect(find.text('100,00 \$'), findsOneWidget);
      expect(find.text('915,00 ₽ · 1 USD = 9,15 RUB'), findsOneWidget);
    },
  );

  testWidgets('операция без заметки не показывает пустую заметку', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final cafe = await createCategory(
      name: 'Кафе',
      kind: TransactionKind.expense,
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 15000,
      occurredAt: DateTime(2026, 9, 24),
      note: 'Обед с коллегами',
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 500,
      occurredAt: DateTime(2026, 9, 23),
    );

    await pumpPage(tester);

    expect(find.text('Обед с коллегами'), findsOneWidget);
    expect(find.text(''), findsNothing);
  });

  testWidgets('свайп показывает действия и отмена удаления не меняет данные', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final cafe = await createCategory(
      name: 'Кафе',
      kind: TransactionKind.expense,
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 15000,
      occurredAt: DateTime(2026, 9, 24),
    );

    await pumpPage(tester);
    await tester.drag(find.text('Расход'), const Offset(-400, 0));
    await tester.pumpAndSettle();

    expect(find.text('Редактировать'), findsOneWidget);
    expect(find.text('Удалить'), findsOneWidget);

    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Удалить операцию?'), findsOneWidget);
    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();

    expect(find.text('Расход'), findsOneWidget);
    expect((await transactions.listByBook(book.id)), hasLength(1));
  });

  testWidgets('подтверждение удаления убирает операцию из истории', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final cafe = await createCategory(
      name: 'Кафе',
      kind: TransactionKind.expense,
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 15000,
      occurredAt: DateTime(2026, 9, 24),
    );

    await pumpPage(tester);
    await tester.drag(find.text('Расход'), const Offset(-400, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Удалить'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('Расход'), findsNothing);
    expect(find.text('Операций пока нет'), findsOneWidget);
    expect(await transactions.listByBook(book.id), isEmpty);
  });

  testWidgets('нажатие по строке открывает форму редактирования', (
    WidgetTester tester,
  ) async {
    final rubles = await createAccount(name: 'Рубли');
    final cafe = await createCategory(
      name: 'Кафе',
      kind: TransactionKind.expense,
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 15000,
      occurredAt: DateTime(2026, 9, 24),
    );

    await pumpPage(tester);
    await tester.tap(find.text('Расход'));
    await tester.pumpAndSettle();

    expect(find.text('Операция'), findsOneWidget);
    expect(find.text('Тип операции'), findsOneWidget);
    expect(find.byKey(transactionFormSaveButtonKey), findsOneWidget);
  });
}

/// Domains use cases, у которых чтение истории всегда завершается ошибкой.
class _FailingJournalUseCases extends FinanceTransactionUseCases {
  _FailingJournalUseCases({
    required super.accounts,
    required super.categories,
    required super.transactions,
  });

  @override
  Future<TransactionsJournal> loadJournal(String bookId) =>
      Future.error(StateError('storage failed'));
}
