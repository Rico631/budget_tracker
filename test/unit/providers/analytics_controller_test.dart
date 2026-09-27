import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/presentation/providers/analytics_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  late BooksRepository books;
  late AccountsRepository accounts;
  late CategoriesRepository categories;
  late DriftTransactionsRepository transactions;

  setUp(() {
    database = AppDatabase.forTesting();
    books = DriftBooksRepository(database);
    accounts = DriftAccountsRepository(database);
    categories = DriftCategoriesRepository(database);
    transactions = DriftTransactionsRepository(database);
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
  });

  tearDown(() async {
    container.dispose();
    await database.close();
  });

  AnalyticsSelectionController selection() =>
      container.read(analyticsSelectionProvider.notifier);

  AnalyticsSelection current() => container.read(analyticsSelectionProvider);

  group('Выбор параметров аналитики', () {
    test('начальное состояние — текущий месяц, расходы и все счета', () {
      final now = DateTime.now();

      expect(
        current().period,
        AnalyticsPeriod.month(year: now.year, month: now.month),
      );
      expect(current().stream, TransactionKind.expense);
      expect(current().accountFilter.isEmpty, isTrue);
    });

    test('переключение режима меняет период и сохраняет поток и фильтр', () {
      selection()
        ..selectStream(TransactionKind.income)
        ..selectAccounts(AnalyticsAccountFilter.of(['account']))
        ..selectPeriodMode(AnalyticsPeriodMode.year);

      expect(current().period.mode, AnalyticsPeriodMode.year);
      expect(current().period.year, DateTime.now().year);
      expect(current().stream, TransactionKind.income);
      expect(current().accountFilter.accountIds, {'account'});
    });

    test('режим «Месяц» выбирает самый новый доступный месяц года', () {
      selection()
        ..selectPeriod(AnalyticsPeriod.year(2026))
        ..selectPeriodMode(
          AnalyticsPeriodMode.month,
          available: [
            AnalyticsPeriod.month(year: 2026, month: 3),
            AnalyticsPeriod.month(year: 2026, month: 9),
            AnalyticsPeriod.month(year: 2025, month: 12),
          ],
        );

      expect(current().period, AnalyticsPeriod.month(year: 2026, month: 9));
    });

    test('режим года без операций оставляет текущий месяц', () {
      selection()
        ..selectPeriod(AnalyticsPeriod.year(2026))
        ..selectPeriodMode(AnalyticsPeriodMode.month);
      final now = DateTime.now();

      expect(
        current().period,
        AnalyticsPeriod.month(year: now.year, month: now.month),
      );
    });

    test('сброс фильтра по счетам не сбрасывает период и поток', () {
      final august = AnalyticsPeriod.month(year: 2026, month: 8);
      selection()
        ..selectPeriod(august)
        ..selectStream(TransactionKind.income)
        ..selectAccounts(AnalyticsAccountFilter.of(['account']))
        ..selectAccounts(AnalyticsAccountFilter.all);

      expect(current().period, august);
      expect(current().stream, TransactionKind.income);
      expect(current().accountFilter.isEmpty, isTrue);
    });

    test('набор счетов сравнивается по составу, а не по порядку', () {
      selection().selectAccounts(AnalyticsAccountFilter.of(['first', 'second']));
      final applied = current();
      // Тот же набор в другом порядке — то же значение фильтра: состояние не
      // меняется, а значит срез не пересчитывается повторно.
      selection().selectAccounts(AnalyticsAccountFilter.of(['second', 'first']));

      expect(identical(current(), applied), isTrue);
      expect(current().accountFilter.accountIds, {'first', 'second'});
      expect(current().accountFilter.contains('first'), isTrue);

      selection().selectAccounts(AnalyticsAccountFilter.of(['first']));

      expect(identical(current(), applied), isFalse);
      expect(current().accountFilter.accountIds, {'first'});
    });
  });

  group('Провайдеры среза читают книгу один раз', () {
    test(
      'смена периода, потока и фильтра счета не читает операции книги повторно',
      () async {
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
        await transactions.create(
          bookId: book.id,
          accountId: rubles.id,
          categoryId: food.id,
          kind: TransactionKind.expense,
          amountMinor: 500,
          occurredAt: DateTime(2026, 8, 10),
        );

        final countingTransactions = _CountingTransactionsRepository(
          transactions,
        );
        final countingAccounts = _CountingAccountsRepository(accounts);
        final countingCategories = _CountingCategoriesRepository(categories);
        container.dispose();
        container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            transactionsRepositoryProvider.overrideWithValue(
              countingTransactions,
            ),
            accountsRepositoryProvider.overrideWithValue(countingAccounts),
            categoriesRepositoryProvider.overrideWithValue(countingCategories),
          ],
        );
        selection().selectPeriod(AnalyticsPeriod.month(year: 2026, month: 9));

        final september = await container.read(
          analyticsSliceProvider(book.id).future,
        );
        expect(september.blocks.single.totalMinor, 1500);
        final transactionsReads = countingTransactions.listByBookCalls;
        final accountsReads = countingAccounts.listByBookCalls;

        // Переключение потока, смена фильтра счета и смена периода.
        selection().selectStream(TransactionKind.income);
        await container.read(analyticsSliceProvider(book.id).future);
        selection()
          ..selectAccounts(AnalyticsAccountFilter.of([rubles.id]))
          ..selectStream(TransactionKind.expense);
        await container.read(analyticsSliceProvider(book.id).future);
        selection().selectPeriod(AnalyticsPeriod.month(year: 2026, month: 8));
        final august = await container.read(
          analyticsSliceProvider(book.id).future,
        );

        expect(august.blocks.single.totalMinor, 500);
        // Смена выбора пересчитывает срез в памяти: книга не читается повторно.
        expect(countingTransactions.listByBookCalls, transactionsReads);
        expect(countingAccounts.listByBookCalls, accountsReads);
        expect(countingCategories.listByBookCalls, 1);
      },
    );
  });
}

/// Шпион: считает выборки операций книги.
class _CountingTransactionsRepository implements TransactionsRepository {
  _CountingTransactionsRepository(this._inner);

  final TransactionsRepository _inner;
  int listByBookCalls = 0;

  @override
  Future<List<FinanceTransaction>> listByBook(String bookId) {
    listByBookCalls++;
    return _inner.listByBook(bookId);
  }

  @override
  Future<FinanceTransaction> create({
    required String bookId,
    required String accountId,
    required TransactionKind kind,
    required int amountMinor,
    required DateTime occurredAt,
    String? toAccountId,
    String? categoryId,
    int? toAmountMinor,
    String? note,
  }) => _inner.create(
    bookId: bookId,
    accountId: accountId,
    kind: kind,
    amountMinor: amountMinor,
    occurredAt: occurredAt,
    toAccountId: toAccountId,
    categoryId: categoryId,
    toAmountMinor: toAmountMinor,
    note: note,
  );

  @override
  Future<FinanceTransaction?> getById(String id) => _inner.getById(id);

  @override
  Future<void> update(FinanceTransaction transaction) =>
      _inner.update(transaction);

  @override
  Future<void> delete(String id) => _inner.delete(id);
}

/// Шпион: считает выборки счетов книги.
class _CountingAccountsRepository implements AccountsRepository {
  _CountingAccountsRepository(this._inner);

  final AccountsRepository _inner;
  int listByBookCalls = 0;

  @override
  Future<List<FinanceAccount>> listByBook(
    String bookId, {
    bool includeArchived = false,
  }) {
    listByBookCalls++;
    return _inner.listByBook(bookId, includeArchived: includeArchived);
  }

  @override
  Future<FinanceAccount> create({
    required String bookId,
    required String name,
    required String currencyCode,
    required int initialBalanceMinor,
    String? bankId,
  }) => _inner.create(
    bookId: bookId,
    name: name,
    currencyCode: currencyCode,
    initialBalanceMinor: initialBalanceMinor,
    bankId: bankId,
  );

  @override
  Future<FinanceAccount?> getById(String id) => _inner.getById(id);

  @override
  Future<void> update(FinanceAccount account) => _inner.update(account);

  @override
  Future<void> archive(String id) => _inner.archive(id);

  @override
  Future<void> delete(String id) => _inner.delete(id);

  @override
  Future<bool> hasTransactions(String accountId) =>
      _inner.hasTransactions(accountId);
}

/// Шпион: считает выборки категорий книги.
class _CountingCategoriesRepository implements CategoriesRepository {
  _CountingCategoriesRepository(this._inner);

  final CategoriesRepository _inner;
  int listByBookCalls = 0;

  @override
  Future<List<FinanceCategory>> listByBook(
    String bookId, {
    bool includeArchived = false,
  }) {
    listByBookCalls++;
    return _inner.listByBook(bookId, includeArchived: includeArchived);
  }

  @override
  Future<FinanceCategory> create({
    required String bookId,
    required String name,
    required TransactionKind kind,
    String? parentId,
    bool isFallback = false,
  }) => _inner.create(
    bookId: bookId,
    name: name,
    kind: kind,
    parentId: parentId,
    isFallback: isFallback,
  );

  @override
  Future<FinanceCategory?> getById(String id) => _inner.getById(id);

  @override
  Future<FinanceCategory?> findFallback(String bookId, TransactionKind kind) =>
      _inner.findFallback(bookId, kind);

  @override
  Future<FinanceCategory?> findByName({
    required String bookId,
    required TransactionKind kind,
    required String name,
  }) => _inner.findByName(bookId: bookId, kind: kind, name: name);

  @override
  Future<void> update(FinanceCategory category) => _inner.update(category);

  @override
  Future<void> deleteWithReassignment(
    String categoryId,
    String fallbackCategoryId,
  ) => _inner.deleteWithReassignment(categoryId, fallbackCategoryId);

  @override
  Future<void> delete(String id) => _inner.delete(id);
}
