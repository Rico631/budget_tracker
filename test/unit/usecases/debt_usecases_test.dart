import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/counterparties_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/commands/counterparty_input.dart';
import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:budget_tracker/domain/usecases/debt_usecases.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

void main() {
  drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late BooksRepository books;
  late AccountsRepository accounts;
  late CategoriesRepository categories;
  late CounterpartiesRepository counterparties;
  late TransactionsRepository transactions;
  late DebtUseCases useCases;
  late FinanceBook book;
  late FinanceAccount rubleAccount;

  setUp(() async {
    database = AppDatabase.forTesting();
    books = DriftBooksRepository(database);
    accounts = DriftAccountsRepository(database);
    categories = DriftCategoriesRepository(database);
    counterparties = DriftCounterpartiesRepository(database);
    transactions = DriftTransactionsRepository(database);
    useCases = DebtUseCases(
      accounts: accounts,
      categories: categories,
      counterparties: counterparties,
    );
    book = await books.create(name: 'Личная книга');
    rubleAccount = await accounts.create(
      bookId: book.id,
      name: 'Кошелек',
      currencyCode: 'RUB',
      initialBalanceMinor: 10000,
    );
    await _seedDebtCategories(database, book.id);
  });

  tearDown(() => database.close());

  CounterpartyInput input({
    String name = 'Иван',
    String currencyCode = 'RUB',
    DebtDirection direction = DebtDirection.lent,
    String? accountId,
    int amountMinor = 1000,
  }) => CounterpartyInput.tryCreate(
    bookId: book.id,
    name: name,
    currencyCode: currencyCode,
    direction: direction,
    accountId: accountId ?? rubleAccount.id,
    amountMinor: amountMinor,
  ).valueOrFail();

  group('DebtUseCases', () {
    test(
      'creates a counterparty with the first operation as one action',
      () async {
        final result = await useCases.createWithFirstTransaction(input());

        final created = result.valueOrFail();

        expect(created.name, 'Иван');
        expect(created.currencyCode, 'RUB');
        expect(created.isClosed, isFalse);

        final overview = await useCases.loadOverview(book.id);

        expect(overview.receivable.single.balanceMinor, 1000);
        expect(overview.payable, isEmpty);

        // Первая операция — расход с расходной категорией займа, а не с
        // расходной «Возврат денег» того же типа (ADR-0009, решение 9.5).
        final operations = await counterparties.listTransactions(created.id);
        final operation = operations.single;
        final category = await categories.getById(operation.categoryId!);

        expect(operation.kind, TransactionKind.expense);
        expect(operation.amountMinor, 1000);
        expect(category!.name, 'Заём');
        expect(category.debtRole, CategoryDebtRole.loanOutflow);
      },
    );

    test('creates a borrowed debt with an income operation', () async {
      final created = (await useCases.createWithFirstTransaction(
        input(direction: DebtDirection.borrowed),
      )).valueOrFail();

      final overview = await useCases.loadOverview(book.id);

      expect(overview.payable.single.balanceMinor, -1000);
      expect(overview.receivable, isEmpty);

      final operation = (await counterparties.listTransactions(
        created.id,
      )).single;
      final category = await categories.getById(operation.categoryId!);

      expect(operation.kind, TransactionKind.income);
      // Направление «Я взял в долг» использует доходную категорию «Заём»: та же
      // операция с категорией «Возврат денег» означала бы возврат долга.
      expect(category!.name, 'Заём');
      expect(category.debtRole, CategoryDebtRole.loanInflow);
    });

    test('uses the renamed debt category by its role', () async {
      final otherBook = await books.create(
        name: 'Книга с переименованной ролью',
      );
      final otherAccount = await accounts.create(
        bookId: otherBook.id,
        name: 'Кошелек',
        currencyCode: 'RUB',
        initialBalanceMinor: 0,
      );
      final debtCategory = FinanceCategory(
        id: const FinanceIdGenerator().generateV7(),
        bookId: otherBook.id,
        name: 'Заём',
        kind: TransactionKind.expense,
        createdAt: DateTime(2026, 10, 3),
        updatedAt: DateTime(2026, 10, 3),
        debtRole: CategoryDebtRole.loanOutflow,
      );

      await database
          .into(database.categories)
          .insert(categoryToCompanion(debtCategory));

      final renamed = FinanceCategory(
        id: debtCategory.id,
        bookId: debtCategory.bookId,
        name: 'Одолжил',
        kind: debtCategory.kind,
        createdAt: debtCategory.createdAt,
        updatedAt: DateTime(2026, 10, 4),
        debtRole: debtCategory.debtRole,
      );

      await categories.update(renamed);

      final created = (await useCases.createWithFirstTransaction(
        CounterpartyInput.tryCreate(
          bookId: otherBook.id,
          name: 'Иван',
          currencyCode: 'RUB',
          direction: DebtDirection.lent,
          accountId: otherAccount.id,
          amountMinor: 700,
        ).valueOrFail(),
      )).valueOrFail();
      final operation = (await counterparties.listTransactions(
        created.id,
      )).single;

      // Роль сохранена при переименовании, поэтому категория по-прежнему
      // распознается как долговая (ADR-0009, решение 9.5).
      expect(operation.categoryId, debtCategory.id);
    });

    test('rejects a duplicate name ignoring case and edge spaces', () async {
      await useCases.createWithFirstTransaction(input(name: 'Иван'));

      final result = await useCases.createWithFirstTransaction(
        input(name: '  иван '),
      );

      expect(result.errorsOrFail(), [counterpartyNameDuplicateError]);
      expect(await counterparties.listWithBalances(book.id), hasLength(1));
    });

    test('rejects a book account of another currency', () async {
      final result = await useCases.createWithFirstTransaction(
        input(currencyCode: 'USD'),
      );

      expect(result.errorsOrFail(), [counterpartyAccountCurrencyMismatchError]);
      expect(await counterparties.listWithBalances(book.id), isEmpty);
      expect(await transactions.listByBook(book.id), isEmpty);
    });

    test(
      'leaves no partially created state when the account is foreign',
      () async {
        final otherBook = await books.create(name: 'Другая книга');
        final foreignAccount = await accounts.create(
          bookId: otherBook.id,
          name: 'Чужой счет',
          currencyCode: 'RUB',
          initialBalanceMinor: 0,
        );

        final result = await useCases.createWithFirstTransaction(
          input(accountId: foreignAccount.id),
        );

        expect(result.errorsOrFail(), [
          counterpartyAccountCurrencyMismatchError,
        ]);
        expect(await counterparties.listWithBalances(book.id), isEmpty);
        expect(
          await counterparties.listWithBalances(otherBook.id),
          isEmpty,
          reason: 'в чужой книге не остается операции с привязкой',
        );
      },
    );

    test('reports a book without a debt category of the needed kind', () async {
      final sparseBook = await books.create(name: 'Без категорий');
      final sparseAccount = await accounts.create(
        bookId: sparseBook.id,
        name: 'Кошелек',
        currencyCode: 'RUB',
        initialBalanceMinor: 0,
      );

      final result = await useCases.createWithFirstTransaction(
        CounterpartyInput.tryCreate(
          bookId: sparseBook.id,
          name: 'Иван',
          currencyCode: 'RUB',
          direction: DebtDirection.lent,
          accountId: sparseAccount.id,
          amountMinor: 500,
        ).valueOrFail(),
      );

      expect(result.errorsOrFail(), [counterpartyDebtCategoryMissingError]);
      expect(await counterparties.listWithBalances(sparseBook.id), isEmpty);
    });

    test('renames a counterparty keeping its operations and balance', () async {
      final created = (await useCases.createWithFirstTransaction(
        input(),
      )).valueOrFail();
      final operationsBefore = await counterparties.listTransactions(
        created.id,
      );

      final renamed = await useCases.update(
        created,
        name: 'Иван Петров',
        currencyCode: 'RUB',
      );

      expect(renamed.valueOrFail().name, 'Иван Петров');
      expect(
        (await counterparties.listTransactions(created.id)).single.id,
        operationsBefore.single.id,
      );
      expect(
        (await useCases.loadOverview(book.id)).receivable.single.balanceMinor,
        1000,
      );
    });

    test('rejects renaming to an existing name keeping the old one', () async {
      final first = (await useCases.createWithFirstTransaction(
        input(name: 'Иван'),
      )).valueOrFail();

      await useCases.createWithFirstTransaction(input(name: 'Пётр'));

      final result = await useCases.update(
        first,
        name: ' пётр ',
        currencyCode: 'RUB',
      );

      expect(result.errorsOrFail(), [counterpartyNameDuplicateError]);
      expect((await counterparties.getById(first.id))!.name, 'Иван');
    });

    test('changes the currency only while there are no operations', () async {
      final created = (await useCases.createWithFirstTransaction(
        input(),
      )).valueOrFail();

      expect(
        (await useCases.update(
          created,
          name: 'Иван',
          currencyCode: 'USD',
        )).errorsOrFail(),
        [counterpartyCurrencyChangeRejectedError],
      );
      expect((await counterparties.getById(created.id))!.currencyCode, 'RUB');

      final lastOperation = (await counterparties.listTransactions(
        created.id,
      )).single;

      await (database.delete(
        database.transactions,
      )..where((row) => row.id.equals(lastOperation.id))).go();

      final updated = await useCases.update(
        created,
        name: 'Иван',
        currencyCode: 'USD',
      );

      expect(updated.valueOrFail().currencyCode, 'USD');
    });

    test(
      'closes and reopens a debt keeping its balance in the archive',
      () async {
        final created = (await useCases.createWithFirstTransaction(
          input(),
        )).valueOrFail();

        await useCases.close(created);

        final closed = await useCases.loadOverview(book.id);

        expect(closed.hasNoActiveDebts, isTrue);
        expect(closed.archived.single.balanceMinor, 1000);

        await useCases.reopen((await counterparties.getById(created.id))!);

        expect(
          (await useCases.loadOverview(book.id)).receivable.single.balanceMinor,
          1000,
        );
      },
    );

    test('archives a counterparty automatically at a zero balance', () async {
      final created = (await useCases.createWithFirstTransaction(
        input(amountMinor: 1000),
      )).valueOrFail();
      final repaymentCategory = (await categories.listByBook(book.id))
          .firstWhere(
            (category) =>
                category.kind == TransactionKind.income &&
                category.debtRole == CategoryDebtRole.refundInflow,
          );

      await transactions.create(
        bookId: book.id,
        accountId: rubleAccount.id,
        kind: TransactionKind.income,
        amountMinor: 1000,
        categoryId: repaymentCategory.id,
        counterpartyId: created.id,
        occurredAt: DateTime(2026, 10, 5),
      );

      final overview = await useCases.loadOverview(book.id);

      expect(overview.hasNoActiveDebts, isTrue);
      expect(overview.archived.single.balanceMinor, 0);
    });

    test('deletes a counterparty without operations', () async {
      final created = (await useCases.createWithFirstTransaction(
        input(),
      )).valueOrFail();
      final operation = (await counterparties.listTransactions(
        created.id,
      )).single;

      await transactions.delete(operation.id);

      expect(await useCases.delete(created), isA<Valid<void>>());
      expect(await counterparties.getById(created.id), isNull);
    });

    test('rejects deleting a counterparty with history', () async {
      final created = (await useCases.createWithFirstTransaction(
        input(),
      )).valueOrFail();

      expect((await useCases.delete(created)).errorsOrFail(), [
        counterpartyDeleteRejectedError,
      ]);
      expect(await counterparties.getById(created.id), isNotNull);
      expect(await transactions.listByBook(book.id), hasLength(1));
    });

    test(
      'lists counterparts available for a role and the operation currency',
      () async {
        await useCases.createWithFirstTransaction(input(name: 'Рублевый'));
        final dollarAccount = await accounts.create(
          bookId: book.id,
          name: 'Доллары',
          currencyCode: 'USD',
          initialBalanceMinor: 0,
        );

        await useCases.createWithFirstTransaction(
          input(
            name: 'Долларовый',
            currencyCode: 'USD',
            accountId: dollarAccount.id,
          ),
        );

        final rubleActive = await useCases.listCounterpartiesForOperation(
          bookId: book.id,
          currencyCode: 'RUB',
          role: CategoryDebtRole.loanInflow,
        );
        final dollarActive = await useCases.listCounterpartiesForOperation(
          bookId: book.id,
          currencyCode: 'USD',
          role: CategoryDebtRole.loanInflow,
        );

        expect(rubleActive.map((item) => item.name), ['Рублевый']);
        expect(dollarActive.map((item) => item.name), ['Долларовый']);
      },
    );

    test('offers a refund only for a debt of its own direction', () async {
      final debtor = (await useCases.createWithFirstTransaction(
        input(name: 'Должен мне'),
      )).valueOrFail();
      final creditor = (await useCases.createWithFirstTransaction(
        input(name: 'Должен я', direction: DebtDirection.borrowed),
      )).valueOrFail();

      Future<List<String>> namesFor(CategoryDebtRole role) async {
        final available = await useCases.listCounterpartiesForOperation(
          bookId: book.id,
          currencyCode: 'RUB',
          role: role,
        );
        return [for (final counterparty in available) counterparty.name];
      }

      // Возврат долга уменьшает существующий долг, поэтому доступен только
      // контрагенту с остатком своего направления: возврат выданного займа —
      // должнику, возврат своего долга — кредитору (ADR-0009, решение 9.15).
      expect(await namesFor(CategoryDebtRole.refundInflow), ['Должен мне']);
      expect(await namesFor(CategoryDebtRole.refundOutflow), ['Должен я']);
      // Заем создает новый долг, поэтому остаток контрагента его не ограничивает.
      expect(
        await namesFor(CategoryDebtRole.loanOutflow),
        containsAll(<String>[debtor.name, creditor.name]),
      );
    });

    test('loads operations of a counterparty from newest to oldest', () async {
      final created = (await useCases.createWithFirstTransaction(
        input(),
      )).valueOrFail();
      final repaymentCategory = (await categories.listByBook(book.id))
          .firstWhere(
            (category) =>
                category.kind == TransactionKind.income &&
                category.debtRole == CategoryDebtRole.refundInflow,
          );

      await transactions.create(
        bookId: book.id,
        accountId: rubleAccount.id,
        kind: TransactionKind.income,
        amountMinor: 400,
        categoryId: repaymentCategory.id,
        counterpartyId: created.id,
        occurredAt: DateTime(2026, 10, 9),
      );

      final operations = await useCases.loadTransactions(created.id);

      expect(operations, hasLength(2));
      expect(operations.first.occurredAt, DateTime(2026, 10, 9));
      expect(operations.last.kind, TransactionKind.expense);
    });
  });
}

/// Наполняет книгу долговыми категориями так, как это делает миграция схемы.
Future<void> _seedDebtCategories(AppDatabase database, String bookId) async {
  const idGenerator = FinanceIdGenerator();
  for (final entry in const <(TransactionKind, String, CategoryDebtRole)>[
    (TransactionKind.expense, 'Заём', CategoryDebtRole.loanOutflow),
    (TransactionKind.expense, 'Возврат денег', CategoryDebtRole.refundOutflow),
    (TransactionKind.income, 'Заём', CategoryDebtRole.loanInflow),
    (TransactionKind.income, 'Возврат денег', CategoryDebtRole.refundInflow),
  ]) {
    final now = DateTime(2026, 10, 3);
    await database
        .into(database.categories)
        .insert(
          categoryToCompanion(
            FinanceCategory(
              id: idGenerator.generateV7(),
              bookId: bookId,
              name: entry.$2,
              kind: entry.$1,
              createdAt: now,
              updatedAt: now,
              debtRole: entry.$3,
            ),
          ),
        );
  }
}

extension<T> on ValidationResult<T> {
  T valueOrFail() => switch (this) {
    Valid(value: final value) => value,
    Invalid(errors: final errors) => fail('Ожидался результат: $errors'),
  };

  List<String> errorsOrFail() => switch (this) {
    Valid() => fail('Ожидался отказ валидации.'),
    Invalid(errors: final errors) => errors,
  };
}
