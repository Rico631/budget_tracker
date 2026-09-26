import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/currencies_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/commands/finance_account_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/usecases/account_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BooksRepository books;
  late AccountsRepository accounts;
  late TransactionsRepository transactions;
  late AccountUseCases useCases;

  setUp(() async {
    database = AppDatabase.forTesting();
    books = DriftBooksRepository(database);
    accounts = DriftAccountsRepository(database);
    transactions = DriftTransactionsRepository(database);
    useCases = AccountUseCases(
      accounts: accounts,
      transactions: transactions,
      currencies: DriftCurrenciesRepository(database),
    );
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
  });

  tearDown(() => database.close());

  Future<FinanceAccount> addAccount(
    String bookId, {
    String name = 'Счет',
    String currencyCode = 'RUB',
    int initialBalanceMinor = 0,
    String? bankId,
  }) => accounts.create(
    bookId: bookId,
    name: name,
    currencyCode: currencyCode,
    initialBalanceMinor: initialBalanceMinor,
    bankId: bankId,
  );

  test('группирует счета одной валюты и считает итог группы', () async {
    final book = await books.create(name: 'Бюджет');
    final main = await addAccount(
      book.id,
      name: 'Основной',
      initialBalanceMinor: 10000,
    );
    await addAccount(book.id, name: 'Наличные', initialBalanceMinor: 2500);
    await transactions.create(
      bookId: book.id,
      accountId: main.id,
      kind: TransactionKind.expense,
      amountMinor: 1500,
      occurredAt: DateTime(2026, 9, 20),
    );

    final overview = await useCases.loadOverview(book.id);

    expect(overview.hasActiveAccounts, isTrue);
    expect(overview.groups, hasLength(1));
    final group = overview.groups.single;
    expect(group.currencyCode, 'RUB');
    expect(group.currency?.symbol, '₽');
    expect(group.accounts, hasLength(2));
    expect(group.totalMinor, 10000 - 1500 + 2500);
    expect(
      group.accounts.singleWhere((item) => item.account.id == main.id).balanceMinor,
      8500,
    );
  });

  test('счета разных валют образуют отдельные группы без общего итога', () async {
    final book = await books.create(name: 'Бюджет');
    await addAccount(
      book.id,
      name: 'Рубли',
      currencyCode: 'RUB',
      initialBalanceMinor: 1000,
    );
    await addAccount(
      book.id,
      name: 'Доллары',
      currencyCode: 'USD',
      initialBalanceMinor: 200,
    );

    final overview = await useCases.loadOverview(book.id);

    expect(overview.groups.map((group) => group.currencyCode), ['RUB', 'USD']);
    expect(overview.groups[0].totalMinor, 1000);
    expect(overview.groups[1].totalMinor, 200);
    expect(overview.groups[1].currency?.code, 'USD');
  });

  test('архивный счет не влияет на список и итог', () async {
    final book = await books.create(name: 'Бюджет');
    final active = await addAccount(
      book.id,
      name: 'Активный',
      initialBalanceMinor: 700,
    );
    final archived = await addAccount(
      book.id,
      name: 'Архивный',
      initialBalanceMinor: 5000,
    );
    await accounts.archive(archived.id);

    final overview = await useCases.loadOverview(book.id);

    expect(overview.groups, hasLength(1));
    expect(overview.groups.single.totalMinor, 700);
    expect(
      overview.groups.single.accounts.map((item) => item.account.id),
      [active.id],
    );
  });

  test('пустая книга возвращает обзор без активных счетов', () async {
    final book = await books.create(name: 'Бюджет');

    final overview = await useCases.loadOverview(book.id);

    expect(overview.groups, isEmpty);
    expect(overview.isEmpty, isTrue);
    expect(overview.hasActiveAccounts, isFalse);
  });

  test('читает счета и операции книги по одному разу', () async {
    final book = await books.create(name: 'Бюджет');
    await addAccount(book.id, name: 'Первый', initialBalanceMinor: 100);
    await addAccount(book.id, name: 'Второй', initialBalanceMinor: 200);
    await addAccount(book.id, name: 'Третий', initialBalanceMinor: 300);
    final countingAccounts = _CountingAccountsRepository(accounts);
    final countingTransactions = _CountingTransactionsRepository(transactions);
    final countingUseCases = AccountUseCases(
      accounts: countingAccounts,
      transactions: countingTransactions,
    );

    final overview = await countingUseCases.loadOverview(book.id);

    expect(overview.groups.single.accounts, hasLength(3));
    expect(countingAccounts.listByBookCalls, 1);
    expect(countingTransactions.listByBookCalls, 1);
  });

  test(
    'валидирует ввод счета: пустое название, код валюты не из трех букв '
    'и допустимый отрицательный остаток',
    () {
      final emptyName = FinanceAccountInput.tryCreate(
        bookId: 'book',
        name: '   ',
        currencyCode: 'RUB',
        initialBalanceMinor: 0,
      );
      expect(emptyName, isA<Invalid<FinanceAccountInput>>());
      expect(emptyName.errorsOrFail(), contains(accountNameRequiredError));

      final shortCurrencyCode = FinanceAccountInput.tryCreate(
        bookId: 'book',
        name: 'Счет',
        currencyCode: 'RU',
        initialBalanceMinor: 0,
      );
      expect(
        shortCurrencyCode.errorsOrFail(),
        contains(accountCurrencyCodeInvalidError),
      );

      final negativeBalance = FinanceAccountInput.tryCreate(
        bookId: 'book',
        name: '  Счет  ',
        currencyCode: 'rub',
        initialBalanceMinor: -500,
      );
      final input = negativeBalance.valueOrFail();
      expect(input.name, 'Счет');
      expect(input.currencyCode, 'RUB');
      expect(input.initialBalanceMinor, -500);
    },
  );

  test('создает счет и не создает его при незаполненном названии', () async {
    final book = await books.create(name: 'Бюджет');

    final invalidInput = FinanceAccountInput.tryCreate(
      bookId: book.id,
      name: '',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    expect(invalidInput, isA<Invalid<FinanceAccountInput>>());
    expect(await accounts.listByBook(book.id), isEmpty);

    final created = await useCases.create(
      FinanceAccountInput.tryCreate(
        bookId: book.id,
        name: 'Основной',
        currencyCode: 'RUB',
        initialBalanceMinor: 1200,
      ).valueOrFail(),
    );

    final account = created.valueOrFail();
    expect(account.name, 'Основной');
    expect(account.initialBalanceMinor, 1200);
    expect((await accounts.listByBook(book.id)).single.id, account.id);
  });

  test('изменяет название и начальный остаток счета', () async {
    final book = await books.create(name: 'Бюджет');
    final account = await addAccount(book.id, initialBalanceMinor: 1000);
    await transactions.create(
      bookId: book.id,
      accountId: account.id,
      kind: TransactionKind.income,
      amountMinor: 500,
      occurredAt: DateTime(2026, 9, 20),
    );

    final updated = await useCases.update(
      account,
      FinanceAccountInput.tryCreate(
        bookId: book.id,
        name: 'Переименованный',
        currencyCode: 'RUB',
        initialBalanceMinor: 2000,
      ).valueOrFail(),
    );

    expect(updated.valueOrFail().name, 'Переименованный');
    expect(
      (await useCases.loadOverview(book.id))
          .groups
          .single
          .accounts
          .single
          .balanceMinor,
      2500,
    );
    expect((await transactions.listByBook(book.id)).single.amountMinor, 500);
  });

  test('изменяет валюту счета без операций', () async {
    final book = await books.create(name: 'Бюджет');
    final account = await addAccount(book.id, initialBalanceMinor: 1000);

    final updated = await useCases.update(
      account,
      FinanceAccountInput.tryCreate(
        bookId: book.id,
        name: account.name,
        currencyCode: 'USD',
        initialBalanceMinor: 1000,
      ).valueOrFail(),
    );

    expect(updated.valueOrFail().currencyCode, 'USD');
    expect(
      (await useCases.loadOverview(book.id)).groups.single.currencyCode,
      'USD',
    );
  });

  test('не изменяет валюту счета с зарегистрированными операциями', () async {
    final book = await books.create(name: 'Бюджет');
    final account = await addAccount(book.id, initialBalanceMinor: 1000);
    await transactions.create(
      bookId: book.id,
      accountId: account.id,
      kind: TransactionKind.expense,
      amountMinor: 200,
      occurredAt: DateTime(2026, 9, 20),
    );

    final updated = await useCases.update(
      account,
      FinanceAccountInput.tryCreate(
        bookId: book.id,
        name: 'Переименованный',
        currencyCode: 'USD',
        initialBalanceMinor: 1000,
      ).valueOrFail(),
    );

    expect(updated, isA<Invalid<FinanceAccount>>());
    expect(updated.errorsOrFail(), contains(accountCurrencyChangeRejectedError));
    final stored = (await accounts.getById(account.id))!;
    expect(stored.currencyCode, 'RUB');
    expect(stored.name, account.name);
    expect(
      (await useCases.loadOverview(book.id)).groups.single.currencyCode,
      'RUB',
    );
  });

  test('отказывается удалять счет с операциями и архивирует его', () async {
    final book = await books.create(name: 'Бюджет');
    final account = await addAccount(book.id, initialBalanceMinor: 1000);
    final transaction = await transactions.create(
      bookId: book.id,
      accountId: account.id,
      kind: TransactionKind.expense,
      amountMinor: 200,
      occurredAt: DateTime(2026, 9, 20),
    );

    expect(
      await useCases.deleteOrArchive(account.id),
      AccountRemovalOutcome.archivingRequired,
    );
    expect(await accounts.getById(account.id), isNotNull);

    await useCases.archive(account.id);

    expect((await accounts.getById(account.id))!.isArchived, isTrue);
    expect(await accounts.listByBook(book.id), isEmpty);
    expect((await transactions.listByBook(book.id)).single.id, transaction.id);
  });

  test('удаляет счет без операций, не затрагивая другие счета', () async {
    final book = await books.create(name: 'Бюджет');
    final removable = await addAccount(book.id, name: 'Удаляемый');
    final remaining = await addAccount(book.id, name: 'Остающийся');

    expect(
      await useCases.deleteOrArchive(removable.id),
      AccountRemovalOutcome.deleted,
    );

    expect(await accounts.getById(removable.id), isNull);
    expect(
      (await accounts.listByBook(book.id)).map((item) => item.id),
      [remaining.id],
    );
  });

  test('выбирает валюту по умолчанию по локали интерфейса', () {
    expect(useCases.defaultCurrencyCodeFor('ru'), 'RUB');
    expect(useCases.defaultCurrencyCodeFor('RU'), 'RUB');
    expect(useCases.defaultCurrencyCodeFor('en'), 'USD');
    expect(useCases.defaultCurrencyCodeFor('de'), 'USD');
  });

  test('создает счет без банка наравне со счетом с банком', () async {
    final bankId = '00000000-0000-7000-8000-000000000001';
    final book = await books.create(name: 'Бюджет');
    await database
        .into(database.banks)
        .insert(
          bankToCompanion(
            FinanceBank(
              id: bankId,
              name: 'Банк',
              colorHex: '#1E88E5',
              isPreset: true,
            ),
          ),
        );

    final withBank = await useCases.create(
      FinanceAccountInput.tryCreate(
        bookId: book.id,
        name: 'С банком',
        currencyCode: 'RUB',
        initialBalanceMinor: 100,
        bankId: bankId,
      ).valueOrFail(),
    );
    final withoutBank = await useCases.create(
      FinanceAccountInput.tryCreate(
        bookId: book.id,
        name: 'Без банка',
        currencyCode: 'RUB',
        initialBalanceMinor: 100,
      ).valueOrFail(),
    );

    expect(withBank.valueOrFail().bankId, bankId);
    expect(withoutBank.valueOrFail().bankId, isNull);
    expect(
      (await useCases.loadOverview(book.id)).groups.single.accounts,
      hasLength(2),
    );
  });
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
    String? note,
  }) => _inner.create(
    bookId: bookId,
    accountId: accountId,
    kind: kind,
    amountMinor: amountMinor,
    occurredAt: occurredAt,
    toAccountId: toAccountId,
    categoryId: categoryId,
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

extension on ValidationResult<FinanceAccountInput> {
  FinanceAccountInput valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидался корректный ввод: $errors'),
  };

  List<String> errorsOrFail() => switch (this) {
    Valid() => fail('Ожидалась ошибка валидации ввода.'),
    Invalid(errors: final errors) => errors,
  };
}

extension on ValidationResult<FinanceAccount> {
  FinanceAccount valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидался счет, получено: $errors'),
  };

  List<String> errorsOrFail() => switch (this) {
    Valid() => fail('Ожидалась ошибка валидации счета.'),
    Invalid(errors: final errors) => errors,
  };
}