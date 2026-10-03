import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/usecases/finance_transaction_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BooksRepository books;
  late AccountsRepository accounts;
  late CategoriesRepository categories;
  late TransactionsRepository transactions;
  late FinanceTransactionUseCases useCases;

  setUp(() {
    database = AppDatabase.forTesting();
    books = DriftBooksRepository(database);
    accounts = DriftAccountsRepository(database);
    categories = DriftCategoriesRepository(database);
    transactions = DriftTransactionsRepository(database);
    useCases = FinanceTransactionUseCases(
      accounts: accounts,
      categories: categories,
      transactions: transactions,
    );
  });

  tearDown(() => database.close());

  test(
    'creates income, expense, and transfer and calculates balances',
    () async {
      final book = await books.create(name: 'Budget');
      final source = await accounts.create(
        bookId: book.id,
        name: 'Main',
        currencyCode: 'RUB',
        initialBalanceMinor: 1000,
      );
      final target = await accounts.create(
        bookId: book.id,
        name: 'Savings',
        currencyCode: 'RUB',
        initialBalanceMinor: 200,
      );
      final incomeCategory = await categories.create(
        bookId: book.id,
        name: 'Salary',
        kind: TransactionKind.income,
      );
      final expenseCategory = await categories.create(
        bookId: book.id,
        name: 'Food',
        kind: TransactionKind.expense,
      );

      final income = await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: source.id,
          kind: TransactionKind.income,
          amountMinor: 500,
          categoryId: incomeCategory.id,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 9, 24),
      );
      final expense = await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: source.id,
          kind: TransactionKind.expense,
          amountMinor: 150,
          categoryId: expenseCategory.id,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 9, 24),
      );
      final transfer = await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: source.id,
          toAccountId: target.id,
          kind: TransactionKind.transfer,
          amountMinor: 300,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 9, 24),
      );

      expect(income, isA<Valid<FinanceTransaction>>());
      expect(expense, isA<Valid<FinanceTransaction>>());
      expect(transfer, isA<Valid<FinanceTransaction>>());
      expect(await useCases.calculateAccountBalance(source.id), 1050);
      expect(await useCases.calculateAccountBalance(target.id), 500);
      expect(await useCases.calculateBookBalance(book.id), 1550);
    },
  );

  test(
    'rejects incompatible, cross-book, non-positive, and same-account operations',
    () async {
      final firstBook = await books.create(name: 'First');
      final secondBook = await books.create(name: 'Second');
      final firstAccount = await accounts.create(
        bookId: firstBook.id,
        name: 'First',
        currencyCode: 'RUB',
        initialBalanceMinor: 0,
      );
      final secondAccount = await accounts.create(
        bookId: secondBook.id,
        name: 'Second',
        currencyCode: 'RUB',
        initialBalanceMinor: 0,
      );
      final expenseCategory = await categories.create(
        bookId: firstBook.id,
        name: 'Food',
        kind: TransactionKind.expense,
      );

      final wrongCategory = await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: firstBook.id,
          accountId: firstAccount.id,
          kind: TransactionKind.income,
          amountMinor: 100,
          categoryId: expenseCategory.id,
        ).valueOrFail(),
        occurredAt: DateTime.now(),
      );
      expect(wrongCategory, isA<Invalid<FinanceTransaction>>());

      final crossBook = await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: firstBook.id,
          accountId: firstAccount.id,
          toAccountId: secondAccount.id,
          kind: TransactionKind.transfer,
          amountMinor: 100,
        ).valueOrFail(),
        occurredAt: DateTime.now(),
      );
      expect(crossBook, isA<Invalid<FinanceTransaction>>());

      final invalidAmount = FinanceTransactionInput.tryCreate(
        bookId: firstBook.id,
        accountId: firstAccount.id,
        kind: TransactionKind.expense,
        amountMinor: 0,
        categoryId: expenseCategory.id,
      );
      expect(invalidAmount, isA<Invalid<FinanceTransactionInput>>());

      final sameAccount = FinanceTransactionInput.tryCreate(
        bookId: firstBook.id,
        accountId: firstAccount.id,
        toAccountId: firstAccount.id,
        kind: TransactionKind.transfer,
        amountMinor: 100,
      );
      expect(sameAccount, isA<Invalid<FinanceTransactionInput>>());
    },
  );

  test('rejects a destination amount on income and expense', () {
    final income = FinanceTransactionInput.tryCreate(
      bookId: 'book-1',
      accountId: 'account-1',
      kind: TransactionKind.income,
      amountMinor: 100,
      categoryId: 'category-1',
      toAmountMinor: 500,
    );

    switch (income) {
      case Valid():
        fail('Expected an income with a destination amount to be invalid');
      case Invalid(errors: final errors):
        expect(errors, contains(transactionToAmountNotAllowedError));
    }
  });

  test('rejects a non-positive destination amount of a transfer', () {
    final transfer = FinanceTransactionInput.tryCreate(
      bookId: 'book-1',
      accountId: 'account-1',
      toAccountId: 'account-2',
      kind: TransactionKind.transfer,
      amountMinor: 100,
      toAmountMinor: 0,
    );

    switch (transfer) {
      case Valid():
        fail(
          'Expected a transfer with a zero destination amount to be invalid',
        );
      case Invalid(errors: final errors):
        expect(errors, contains(transactionToAmountNotPositiveError));
    }
  });

  test('saves a cross-currency transfer and accounts it in balances', () async {
    final book = await books.create(name: 'Cross currency');
    final dollars = await accounts.create(
      bookId: book.id,
      name: 'Dollars',
      currencyCode: 'USD',
      initialBalanceMinor: 50000,
    );
    final rubles = await accounts.create(
      bookId: book.id,
      name: 'Rubles',
      currencyCode: 'RUB',
      initialBalanceMinor: 1000,
    );

    final stored = (await useCases.create(
      FinanceTransactionInput.tryCreate(
        bookId: book.id,
        accountId: dollars.id,
        toAccountId: rubles.id,
        kind: TransactionKind.transfer,
        amountMinor: 10000,
        toAmountMinor: 915000,
      ).valueOrFail(),
      occurredAt: DateTime(2026, 9, 24),
    )).valueOrFail();

    expect(stored.toAmountMinor, 915000);
    expect(await useCases.calculateAccountBalance(dollars.id), 40000);
    expect(await useCases.calculateAccountBalance(rubles.id), 916000);
  });

  test(
    'rejects a cross-currency transfer without a destination amount',
    () async {
      final book = await books.create(name: 'Cross currency');
      final dollars = await accounts.create(
        bookId: book.id,
        name: 'Dollars',
        currencyCode: 'USD',
        initialBalanceMinor: 50000,
      );
      final rubles = await accounts.create(
        bookId: book.id,
        name: 'Rubles',
        currencyCode: 'RUB',
        initialBalanceMinor: 1000,
      );

      final result = await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: dollars.id,
          toAccountId: rubles.id,
          kind: TransactionKind.transfer,
          amountMinor: 10000,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 9, 24),
      );

      switch (result) {
        case Valid():
          fail('Expected a cross-currency transfer without an amount to fail');
        case Invalid(errors: final errors):
          expect(errors, contains(transferToAmountRequiredError));
      }
      expect(await useCases.calculateAccountBalance(dollars.id), 50000);
      expect(await useCases.calculateAccountBalance(rubles.id), 1000);
    },
  );

  test('rejects a destination amount on a same-currency transfer', () async {
    final book = await books.create(name: 'Same currency');
    final source = await accounts.create(
      bookId: book.id,
      name: 'Main',
      currencyCode: 'RUB',
      initialBalanceMinor: 10000,
    );
    final target = await accounts.create(
      bookId: book.id,
      name: 'Savings',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );

    final result = await useCases.create(
      FinanceTransactionInput.tryCreate(
        bookId: book.id,
        accountId: source.id,
        toAccountId: target.id,
        kind: TransactionKind.transfer,
        amountMinor: 1000,
        toAmountMinor: 1000,
      ).valueOrFail(),
      occurredAt: DateTime(2026, 9, 24),
    );

    switch (result) {
      case Valid():
        fail('Expected a same-currency transfer with an amount to fail');
      case Invalid(errors: final errors):
        expect(errors, contains(transferToAmountNotAllowedError));
    }
    expect(await useCases.calculateAccountBalance(source.id), 10000);
    expect(await useCases.calculateAccountBalance(target.id), 0);
  });

  test(
    'updates fields of an operation keeping its identity and kind',
    () async {
      final book = await books.create(name: 'Update');
      final account = await accounts.create(
        bookId: book.id,
        name: 'Main',
        currencyCode: 'RUB',
        initialBalanceMinor: 1000,
      );
      final food = await categories.create(
        bookId: book.id,
        name: 'Food',
        kind: TransactionKind.expense,
      );
      final transport = await categories.create(
        bookId: book.id,
        name: 'Transport',
        kind: TransactionKind.expense,
      );
      final created = (await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: account.id,
          kind: TransactionKind.expense,
          amountMinor: 150,
          categoryId: food.id,
          note: 'before',
        ).valueOrFail(),
        occurredAt: DateTime(2026, 9, 24),
      )).valueOrFail();
      final storedBefore = (await transactions.getById(created.id))!;

      final updated = (await useCases.update(
        storedBefore,
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: account.id,
          kind: TransactionKind.expense,
          amountMinor: 250,
          categoryId: transport.id,
          note: 'after',
        ).valueOrFail(),
        occurredAt: DateTime(2026, 9, 20),
      )).valueOrFail();

      expect(updated.id, storedBefore.id);
      expect(updated.kind, TransactionKind.expense);
      expect(updated.amountMinor, 250);
      expect(updated.categoryId, transport.id);
      expect(updated.note, 'after');
      expect(updated.occurredAt, DateTime(2026, 9, 20));

      final stored = (await transactions.getById(storedBefore.id))!;
      expect(stored.amountMinor, 250);
      expect(stored.note, 'after');
      expect(stored.createdAt, storedBefore.createdAt);
      expect(await useCases.calculateAccountBalance(account.id), 750);
    },
  );

  test('rejects a kind change keeping stored data of the operation', () async {
    final book = await books.create(name: 'Kind change');
    final account = await accounts.create(
      bookId: book.id,
      name: 'Main',
      currencyCode: 'RUB',
      initialBalanceMinor: 1000,
    );
    final expenseCategory = await categories.create(
      bookId: book.id,
      name: 'Food',
      kind: TransactionKind.expense,
    );
    final incomeCategory = await categories.create(
      bookId: book.id,
      name: 'Salary',
      kind: TransactionKind.income,
    );
    final created = (await useCases.create(
      FinanceTransactionInput.tryCreate(
        bookId: book.id,
        accountId: account.id,
        kind: TransactionKind.expense,
        amountMinor: 150,
        categoryId: expenseCategory.id,
      ).valueOrFail(),
      occurredAt: DateTime(2026, 9, 24),
    )).valueOrFail();

    final result = await useCases.update(
      created,
      FinanceTransactionInput.tryCreate(
        bookId: book.id,
        accountId: account.id,
        kind: TransactionKind.income,
        amountMinor: 150,
        categoryId: incomeCategory.id,
      ).valueOrFail(),
      occurredAt: DateTime(2026, 9, 24),
    );

    switch (result) {
      case Valid():
        fail('Expected a kind change to be rejected');
      case Invalid(errors: final errors):
        expect(errors, [transactionKindChangeRejectedError]);
    }

    final stored = (await transactions.getById(created.id))!;
    expect(stored.kind, TransactionKind.expense);
    expect(stored.categoryId, expenseCategory.id);
    expect(await useCases.calculateAccountBalance(account.id), 850);
  });

  test(
    'deleting an operation removes it from the book and from balances',
    () async {
      final book = await books.create(name: 'Delete');
      final account = await accounts.create(
        bookId: book.id,
        name: 'Main',
        currencyCode: 'RUB',
        initialBalanceMinor: 1000,
      );
      final category = await categories.create(
        bookId: book.id,
        name: 'Food',
        kind: TransactionKind.expense,
      );
      final created = (await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: account.id,
          kind: TransactionKind.expense,
          amountMinor: 300,
          categoryId: category.id,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 9, 24),
      )).valueOrFail();

      expect(await useCases.calculateAccountBalance(account.id), 700);

      await useCases.delete(created.id);

      expect(await transactions.getById(created.id), isNull);
      expect(await transactions.listByBook(book.id), isEmpty);
      expect(await useCases.calculateAccountBalance(account.id), 1000);
    },
  );

  test(
    'deleting an operation keeps the book, accounts and categories',
    () async {
      final book = await books.create(name: 'Keep');
      final account = await accounts.create(
        bookId: book.id,
        name: 'Main',
        currencyCode: 'RUB',
        initialBalanceMinor: 1000,
      );
      final category = await categories.create(
        bookId: book.id,
        name: 'Food',
        kind: TransactionKind.expense,
      );
      final removed = (await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: account.id,
          kind: TransactionKind.expense,
          amountMinor: 300,
          categoryId: category.id,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 9, 24),
      )).valueOrFail();
      final kept = (await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: account.id,
          kind: TransactionKind.expense,
          amountMinor: 100,
          categoryId: category.id,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 9, 25),
      )).valueOrFail();

      await useCases.delete(removed.id);

      expect((await books.list()).single.id, book.id);
      expect((await accounts.listByBook(book.id)).single.id, account.id);
      expect((await categories.listByBook(book.id)).single.id, category.id);
      expect((await transactions.listByBook(book.id)).single.id, kept.id);
    },
  );

  test(
    'journal of a book groups operations from newest day to oldest',
    () async {
      final book = await books.create(name: 'Journal');
      final account = await accounts.create(
        bookId: book.id,
        name: 'Main',
        currencyCode: 'RUB',
        initialBalanceMinor: 0,
      );
      final category = await categories.create(
        bookId: book.id,
        name: 'Food',
        kind: TransactionKind.expense,
      );
      for (final occurredAt in [
        DateTime(2026, 9, 26, 9),
        DateTime(2026, 9, 26, 21),
        DateTime(2026, 9, 22),
      ]) {
        await useCases.create(
          FinanceTransactionInput.tryCreate(
            bookId: book.id,
            accountId: account.id,
            kind: TransactionKind.expense,
            amountMinor: 100,
            categoryId: category.id,
          ).valueOrFail(),
          occurredAt: occurredAt,
        );
      }

      final journal = await useCases.loadJournal(book.id);

      expect(journal.hasTransactions, isTrue);
      expect(journal.days.map((group) => group.day), [
        DateTime(2026, 9, 26),
        DateTime(2026, 9, 22),
      ]);
      expect(journal.days.first.transactions, hasLength(2));
    },
  );

  test('journal of an empty book has no days', () async {
    final book = await books.create(name: 'Empty journal');

    final journal = await useCases.loadJournal(book.id);

    expect(journal.days, isEmpty);
    expect(journal.isEmpty, isTrue);
    expect(journal.hasTransactions, isFalse);
  });
}

extension<T> on ValidationResult<T> {
  T valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Expected valid value, got $errors'),
  };
}
