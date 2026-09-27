import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/usecases/analytics_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final september = AnalyticsPeriod.month(year: 2026, month: 9);

  late AppDatabase database;
  late BooksRepository books;
  late AccountsRepository accounts;
  late CategoriesRepository categories;
  late TransactionsRepository transactions;
  late AnalyticsUseCases useCases;

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
    books = DriftBooksRepository(database);
    accounts = DriftAccountsRepository(database);
    categories = DriftCategoriesRepository(database);
    transactions = DriftTransactionsRepository(database);
    useCases = AnalyticsUseCases(
      accounts: accounts,
      transactions: transactions,
    );
  });

  tearDown(() => database.close());

  test('срез по книге с операциями в двух валютах содержит два блока', () async {
    final book = await books.create(name: 'Бюджет');
    final rubles = await accounts.create(
      bookId: book.id,
      name: 'Рубли',
      currencyCode: 'RUB',
      initialBalanceMinor: 100000,
    );
    final dollars = await accounts.create(
      bookId: book.id,
      name: 'Доллары',
      currencyCode: 'USD',
      initialBalanceMinor: 0,
    );
    final food = await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: food.id,
      kind: TransactionKind.expense,
      amountMinor: 1500,
      occurredAt: DateTime(2026, 9, 10),
    );
    await transactions.create(
      bookId: book.id,
      accountId: dollars.id,
      categoryId: food.id,
      kind: TransactionKind.expense,
      amountMinor: 2000,
      occurredAt: DateTime(2026, 9, 11),
    );

    final slice = useCases.loadSlice(
      transactions: await useCases.loadBookTransactions(book.id),
      accounts: await useCases.loadBookAccounts(book.id),
      categories: await categories.listByBook(book.id, includeArchived: true),
      period: september,
      stream: TransactionKind.expense,
    );

    expect(slice.blocks.map((block) => block.currencyCode), ['RUB', 'USD']);
    expect(slice.blocks.map((block) => block.totalMinor), [1500, 2000]);
    // Начальный остаток счета в срез не входит.
    expect(
      slice.blocks.singleWhere((block) => block.currencyCode == 'RUB').totalMinor,
      1500,
    );
  });

  test('операции другой книги в срез не попадают', () async {
    final book = await books.create(name: 'Бюджет');
    final otherBook = await books.create(name: 'Другая книга');
    final otherRubles = await accounts.create(
      bookId: otherBook.id,
      name: 'Рубли',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final otherFood = await categories.create(
      bookId: otherBook.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await transactions.create(
      bookId: otherBook.id,
      accountId: otherRubles.id,
      categoryId: otherFood.id,
      kind: TransactionKind.expense,
      amountMinor: 9900,
      occurredAt: DateTime(2026, 9, 10),
    );

    final slice = useCases.loadSlice(
      transactions: await useCases.loadBookTransactions(book.id),
      accounts: await useCases.loadBookAccounts(book.id),
      categories: await categories.listByBook(book.id, includeArchived: true),
      period: september,
      stream: TransactionKind.expense,
    );

    expect(slice.isEmpty, isTrue);
  });

  test('счета читаются вместе с архивными', () async {
    final book = await books.create(name: 'Бюджет');
    final archived = await accounts.create(
      bookId: book.id,
      name: 'Архивный',
      currencyCode: 'USD',
      initialBalanceMinor: 0,
    );
    await accounts.archive(archived.id);

    expect(await accounts.listByBook(book.id), isEmpty);
    expect(
      (await useCases.loadBookAccounts(book.id)).map((item) => item.id),
      [archived.id],
    );
  });

  test('операции категории читаются за период в валюте блока', () async {
    final book = await books.create(name: 'Бюджет');
    final rubles = await accounts.create(
      bookId: book.id,
      name: 'Рубли',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final dollars = await accounts.create(
      bookId: book.id,
      name: 'Доллары',
      currencyCode: 'USD',
      initialBalanceMinor: 0,
    );
    final food = await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    final cafe = await categories.create(
      bookId: book.id,
      name: 'Кафе',
      kind: TransactionKind.expense,
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: food.id,
      kind: TransactionKind.expense,
      amountMinor: 1500,
      occurredAt: DateTime(2026, 9, 10),
    );
    await transactions.create(
      bookId: book.id,
      accountId: dollars.id,
      categoryId: food.id,
      kind: TransactionKind.expense,
      amountMinor: 2000,
      occurredAt: DateTime(2026, 9, 11),
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: cafe.id,
      kind: TransactionKind.expense,
      amountMinor: 900,
      occurredAt: DateTime(2026, 9, 11),
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: food.id,
      kind: TransactionKind.expense,
      amountMinor: 300,
      occurredAt: DateTime(2026, 8, 20),
    );

    final operations = await useCases.loadCategoryOperations(
      bookId: book.id,
      period: september,
      stream: TransactionKind.expense,
      categoryId: food.id,
      currencyCode: 'RUB',
    );

    expect(operations, hasLength(1));
    expect(operations.single.amountMinor, 1500);
  });

  test('доступные периоды содержат периоды с операциями и текущий месяц', () async {
    final book = await books.create(name: 'Бюджет');
    final rubles = await accounts.create(
      bookId: book.id,
      name: 'Рубли',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final food = await categories.create(
      bookId: book.id,
      name: 'Продукты',
      kind: TransactionKind.expense,
    );
    await transactions.create(
      bookId: book.id,
      accountId: rubles.id,
      categoryId: food.id,
      kind: TransactionKind.expense,
      amountMinor: 1500,
      occurredAt: DateTime(2026, 9, 10),
    );

    final available = useCases.loadAvailablePeriods(
      transactions: await useCases.loadBookTransactions(book.id),
      now: DateTime(2026, 9, 27),
    );

    expect(available, contains(september));
    expect(available, contains(AnalyticsPeriod.year(2026)));
    expect(available, contains(AnalyticsPeriod.month(year: 2026, month: 9)));
  });
}
