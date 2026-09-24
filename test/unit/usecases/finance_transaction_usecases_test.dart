import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
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
}

extension on ValidationResult<FinanceTransactionInput> {
  FinanceTransactionInput valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Expected valid input, got $errors'),
  };
}
