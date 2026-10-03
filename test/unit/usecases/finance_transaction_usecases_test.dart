import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/counterparties_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:budget_tracker/domain/usecases/finance_transaction_usecases.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BooksRepository books;
  late AccountsRepository accounts;
  late CategoriesRepository categories;
  late CounterpartiesRepository counterparties;
  late TransactionsRepository transactions;
  late FinanceTransactionUseCases useCases;

  setUp(() {
    database = AppDatabase.forTesting();
    books = DriftBooksRepository(database);
    accounts = DriftAccountsRepository(database);
    categories = DriftCategoriesRepository(database);
    counterparties = DriftCounterpartiesRepository(database);
    transactions = DriftTransactionsRepository(database);
    useCases = FinanceTransactionUseCases(
      accounts: accounts,
      categories: categories,
      counterparties: counterparties,
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

  group('Counterparty binding', () {
    late FinanceBook book;
    late FinanceAccount rubleAccount;
    late FinanceAccount dollarAccount;
    late FinanceCategory expenseCategory;
    late FinanceCounterparty rubleCounterparty;

    setUp(() async {
      book = await books.create(name: 'Debts');
      rubleAccount = await accounts.create(
        bookId: book.id,
        name: 'Рубли',
        currencyCode: 'RUB',
        initialBalanceMinor: 10000,
      );
      dollarAccount = await accounts.create(
        bookId: book.id,
        name: 'Доллары',
        currencyCode: 'USD',
        initialBalanceMinor: 10000,
      );
      expenseCategory = await categories.create(
        bookId: book.id,
        name: 'Заём',
        kind: TransactionKind.expense,
      );
      rubleCounterparty = FinanceCounterparty(
        id: const FinanceIdGenerator().generateV7(),
        bookId: book.id,
        name: 'Иван',
        currencyCode: 'RUB',
        createdAt: DateTime(2026, 10, 3),
        updatedAt: DateTime(2026, 10, 3),
      );
      await counterparties.createWithTransaction(
        counterparty: rubleCounterparty,
        transaction: FinanceTransaction(
          id: const FinanceIdGenerator().generateV7(),
          bookId: book.id,
          accountId: rubleAccount.id,
          categoryId: expenseCategory.id,
          counterpartyId: rubleCounterparty.id,
          kind: TransactionKind.expense,
          amountMinor: 1000,
          occurredAt: DateTime(2026, 10, 3),
          createdAt: DateTime(2026, 10, 3),
          updatedAt: DateTime(2026, 10, 3),
        ),
      );
    });

    test('keeps the binding when the account currency matches', () async {
      final created = await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: rubleAccount.id,
          kind: TransactionKind.expense,
          amountMinor: 250,
          categoryId: expenseCategory.id,
          counterpartyId: rubleCounterparty.id,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 10, 4),
      );

      expect(created.valueOrFail().counterpartyId, rubleCounterparty.id);
    });

    test('rejects the binding when the account currency differs', () async {
      final input = FinanceTransactionInput.tryCreate(
        bookId: book.id,
        accountId: dollarAccount.id,
        kind: TransactionKind.expense,
        amountMinor: 250,
        categoryId: expenseCategory.id,
        counterpartyId: rubleCounterparty.id,
      ).valueOrFail();

      expect(
        await useCases.create(input, occurredAt: DateTime(2026, 10, 4)),
        isA<Invalid<FinanceTransaction>>(),
      );
      expect(
        await transactions.listByBook(book.id),
        hasLength(1),
        reason: 'отклоненная операция не сохраняется',
      );
    });

    test('rejects a counterparty of another book', () async {
      final otherBook = await books.create(name: 'Другая книга');
      final otherCounterparty = FinanceCounterparty(
        id: const FinanceIdGenerator().generateV7(),
        bookId: otherBook.id,
        name: 'Пётр',
        currencyCode: 'RUB',
        createdAt: DateTime(2026, 10, 3),
        updatedAt: DateTime(2026, 10, 3),
      );

      await counterparties.createWithTransaction(
        counterparty: otherCounterparty,
        transaction: FinanceTransaction(
          id: const FinanceIdGenerator().generateV7(),
          bookId: otherBook.id,
          accountId: rubleAccount.id,
          categoryId: expenseCategory.id,
          kind: TransactionKind.expense,
          amountMinor: 100,
          occurredAt: DateTime(2026, 10, 3),
          createdAt: DateTime(2026, 10, 3),
          updatedAt: DateTime(2026, 10, 3),
        ),
      );

      final input = FinanceTransactionInput.tryCreate(
        bookId: book.id,
        accountId: rubleAccount.id,
        kind: TransactionKind.expense,
        amountMinor: 250,
        categoryId: expenseCategory.id,
        counterpartyId: otherCounterparty.id,
      ).valueOrFail();

      final result = await useCases.create(
        input,
        occurredAt: DateTime(2026, 10, 4),
      );

      expect((result as Invalid<FinanceTransaction>).errors, [
        transactionCounterpartyBookMismatchError,
      ]);
    });

    test('does not allow the counterparty on a transfer', () {
      final result = FinanceTransactionInput.tryCreate(
        bookId: book.id,
        accountId: rubleAccount.id,
        toAccountId: dollarAccount.id,
        kind: TransactionKind.transfer,
        amountMinor: 250,
        toAmountMinor: 3,
        counterpartyId: rubleCounterparty.id,
      );

      expect(
        (result as Invalid<FinanceTransactionInput>).errors,
        contains(transactionCounterpartyNotAllowedError),
      );
    });

    test(
      'clears the binding on update when the account changes currency',
      () async {
        final created = (await useCases.create(
          FinanceTransactionInput.tryCreate(
            bookId: book.id,
            accountId: rubleAccount.id,
            kind: TransactionKind.expense,
            amountMinor: 300,
            categoryId: expenseCategory.id,
            counterpartyId: rubleCounterparty.id,
          ).valueOrFail(),
          occurredAt: DateTime(2026, 10, 4),
        )).valueOrFail();

        final updated = await useCases.update(
          created,
          FinanceTransactionInput.tryCreate(
            bookId: book.id,
            accountId: dollarAccount.id,
            kind: TransactionKind.expense,
            amountMinor: 300,
            categoryId: expenseCategory.id,
          ).valueOrFail(),
          occurredAt: DateTime(2026, 10, 4),
        );

        expect(updated.valueOrFail().counterpartyId, isNull);
        expect(
          (await transactions.getById(created.id))!.counterpartyId,
          isNull,
        );
      },
    );

    /// Долговая категория [kind] с ролью [role] поверх стартового набора.
    Future<FinanceCategory> insertRoleCategory(
      TransactionKind kind,
      CategoryDebtRole role,
    ) async {
      final category = FinanceCategory(
        id: const FinanceIdGenerator().generateV7(),
        bookId: book.id,
        name: 'Долговая ${role.name}',
        kind: kind,
        createdAt: DateTime(2026, 10, 3),
        updatedAt: DateTime(2026, 10, 3),
        debtRole: role,
      );
      await database
          .into(database.categories)
          .insert(categoryToCompanion(category));
      return category;
    }

    test('accepts a refund of the issued loan from the debtor', () async {
      // Контрагент должен пользователю 1000, поэтому возврат выданного займа
      // привязывается к нему (ADR-0009, решение 9.15).
      final category = await insertRoleCategory(
        TransactionKind.income,
        CategoryDebtRole.refundInflow,
      );

      final created = await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: rubleAccount.id,
          kind: TransactionKind.income,
          amountMinor: 400,
          categoryId: category.id,
          counterpartyId: rubleCounterparty.id,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 10, 4),
      );

      expect(created.valueOrFail().counterpartyId, rubleCounterparty.id);
    });

    test('rejects repaying a debt to a counterparty that owes money', () async {
      // Контрагент должен пользователю, поэтому возврат своего долга ему
      // невозможен: остаток долга поменял бы направление (ADR-0009, 9.15).
      final category = await insertRoleCategory(
        TransactionKind.expense,
        CategoryDebtRole.refundOutflow,
      );

      final created = await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: rubleAccount.id,
          kind: TransactionKind.expense,
          amountMinor: 400,
          categoryId: category.id,
          counterpartyId: rubleCounterparty.id,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 10, 4),
      );

      expect((created as Invalid<FinanceTransaction>).errors, [
        transactionCounterpartyDebtRoleMismatchError,
      ]);
      expect(await transactions.listByBook(book.id), hasLength(1));
    });

    test('accepts any counterparty for a loan role', () async {
      // Заем создает новый долг, поэтому остаток контрагента его не ограничивает
      // (ADR-0009, решение 9.15).
      final category = await insertRoleCategory(
        TransactionKind.income,
        CategoryDebtRole.loanInflow,
      );

      final created = await useCases.create(
        FinanceTransactionInput.tryCreate(
          bookId: book.id,
          accountId: rubleAccount.id,
          kind: TransactionKind.income,
          amountMinor: 400,
          categoryId: category.id,
          counterpartyId: rubleCounterparty.id,
        ).valueOrFail(),
        occurredAt: DateTime(2026, 10, 4),
      );

      expect(created.valueOrFail().counterpartyId, rubleCounterparty.id);
    });
  });
}

extension<T> on ValidationResult<T> {
  T valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Expected valid value, got $errors'),
  };
}
