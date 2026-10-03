import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/counterparties_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const idGenerator = FinanceIdGenerator();

  late AppDatabase database;
  late BooksRepository books;
  late AccountsRepository accounts;
  late CategoriesRepository categories;
  late CounterpartiesRepository counterparties;
  late FinanceBook book;
  late FinanceAccount rubleAccount;
  late FinanceCategory expenseCategory;

  setUp(() async {
    // Ограничения внешних ключей включены: отказ операции должен откатывать и
    // запись контрагента (ADR-0009, решение 9.11).
    database = AppDatabase.forTesting(
      NativeDatabase.memory(
        setup: (raw) => raw.execute('PRAGMA foreign_keys = ON'),
      ),
    );
    books = DriftBooksRepository(database);
    accounts = DriftAccountsRepository(database);
    categories = DriftCategoriesRepository(database);
    counterparties = DriftCounterpartiesRepository(database);
    book = await books.create(name: 'Личная книга');
    rubleAccount = await accounts.create(
      bookId: book.id,
      name: 'Кошелек',
      currencyCode: 'RUB',
      initialBalanceMinor: 10000,
    );
    expenseCategory = await categories.create(
      bookId: book.id,
      name: 'Заём',
      kind: TransactionKind.expense,
    );
  });

  tearDown(() => database.close());

  FinanceCounterparty newCounterparty(
    String name, {
    String currencyCode = 'RUB',
    bool isClosed = false,
  }) => FinanceCounterparty(
    id: idGenerator.generateV7(),
    bookId: book.id,
    name: name,
    currencyCode: currencyCode,
    isClosed: isClosed,
    createdAt: DateTime(2026, 10, 3),
    updatedAt: DateTime(2026, 10, 3),
  );

  FinanceTransaction newTransaction({
    required String counterpartyId,
    required String accountId,
    required TransactionKind kind,
    required int amountMinor,
    required DateTime occurredAt,
  }) => FinanceTransaction(
    id: idGenerator.generateV7(),
    bookId: book.id,
    accountId: accountId,
    categoryId: expenseCategory.id,
    counterpartyId: counterpartyId,
    kind: kind,
    amountMinor: amountMinor,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );

  group('Counterparties repository', () {
    test(
      'creates a counterparty together with its first transaction',
      () async {
        final counterparty = newCounterparty('Иван');

        await counterparties.createWithTransaction(
          counterparty: counterparty,
          transaction: newTransaction(
            counterpartyId: counterparty.id,
            accountId: rubleAccount.id,
            kind: TransactionKind.expense,
            amountMinor: 1000,
            occurredAt: DateTime(2026, 10, 3),
          ),
        );

        expect((await counterparties.getById(counterparty.id))!.name, 'Иван');

        final debts = await counterparties.listWithBalances(book.id);

        expect(debts, hasLength(1));
        expect(debts.single.balanceMinor, 1000);
      },
    );

    test('does not keep the counterparty when its transaction fails', () async {
      final counterparty = newCounterparty('Пётр');

      await expectLater(
        counterparties.createWithTransaction(
          counterparty: counterparty,
          transaction: newTransaction(
            counterpartyId: counterparty.id,
            accountId: 'нет такого счета',
            kind: TransactionKind.expense,
            amountMinor: 500,
            occurredAt: DateTime(2026, 10, 3),
          ),
        ),
        throwsA(isA<Exception>()),
      );

      expect(await counterparties.getById(counterparty.id), isNull);
      expect(await counterparties.listWithBalances(book.id), isEmpty);
      expect(
        await database.select(database.transactions).get(),
        isEmpty,
        reason:
            'операция с привязкой к несуществующему контрагенту не остается',
      );
    });

    test(
      'finds a counterparty by name ignoring case and edge spaces',
      () async {
        final counterparty = newCounterparty('Иван Петров');

        await counterparties.createWithTransaction(
          counterparty: counterparty,
          transaction: newTransaction(
            counterpartyId: counterparty.id,
            accountId: rubleAccount.id,
            kind: TransactionKind.expense,
            amountMinor: 100,
            occurredAt: DateTime(2026, 10, 3),
          ),
        );

        expect(
          (await counterparties.findByName(
            bookId: book.id,
            name: '  иван петров ',
          ))!.id,
          counterparty.id,
        );
        expect(
          await counterparties.findByName(bookId: book.id, name: 'Пётр'),
          isNull,
        );
      },
    );

    test('isolates counterparties of another book', () async {
      final otherBook = await books.create(name: 'Другая книга');
      final counterparty = FinanceCounterparty(
        id: idGenerator.generateV7(),
        bookId: otherBook.id,
        name: 'Пётр',
        currencyCode: 'RUB',
        createdAt: DateTime(2026, 10, 3),
        updatedAt: DateTime(2026, 10, 3),
      );

      await counterparties.createWithTransaction(
        counterparty: counterparty,
        transaction: FinanceTransaction(
          id: idGenerator.generateV7(),
          bookId: otherBook.id,
          accountId: rubleAccount.id,
          categoryId: expenseCategory.id,
          counterpartyId: counterparty.id,
          kind: TransactionKind.expense,
          amountMinor: 700,
          occurredAt: DateTime(2026, 10, 3),
          createdAt: DateTime(2026, 10, 3),
          updatedAt: DateTime(2026, 10, 3),
        ),
      );

      expect(await counterparties.listWithBalances(book.id), isEmpty);
      expect(
        await counterparties.findByName(bookId: book.id, name: 'Пётр'),
        isNull,
      );
    });

    test('lists balances of several counterparties and currencies', () async {
      final rubleDebtor = newCounterparty('Должен мне');
      final rubleCreditor = newCounterparty('Должен я');
      final dollarDebtor = newCounterparty('Долларовый', currencyCode: 'USD');

      Future<void> seed(
        FinanceCounterparty counterparty,
        List<(TransactionKind, int)> movements,
      ) async {
        await counterparties.createWithTransaction(
          counterparty: counterparty,
          transaction: newTransaction(
            counterpartyId: counterparty.id,
            accountId: rubleAccount.id,
            kind: movements.first.$1,
            amountMinor: movements.first.$2,
            occurredAt: DateTime(2026, 10, 1),
          ),
        );
        for (final movement in movements.skip(1)) {
          await database
              .into(database.transactions)
              .insert(
                transactionToCompanion(
                  newTransaction(
                    counterpartyId: counterparty.id,
                    accountId: rubleAccount.id,
                    kind: movement.$1,
                    amountMinor: movement.$2,
                    occurredAt: DateTime(2026, 10, 2),
                  ),
                ),
              );
        }
      }

      await seed(rubleDebtor, [
        (TransactionKind.expense, 1000),
        (TransactionKind.income, 400),
      ]);
      await seed(rubleCreditor, [(TransactionKind.income, 700)]);
      await seed(dollarDebtor, [(TransactionKind.expense, 250)]);

      final debts = await counterparties.listWithBalances(book.id);
      final byName = {
        for (final debt in debts) debt.counterparty.name: debt.balanceMinor,
      };

      expect(byName, {'Должен мне': 600, 'Должен я': -700, 'Долларовый': 250});
      // Суммы разных валют не складываются: каждая запись остается в своей валюте.
      expect(debts.map((debt) => debt.counterparty.currencyCode).toSet(), {
        'RUB',
        'USD',
      });
    });

    test('counts operations of archived accounts in the balance', () async {
      final counterparty = newCounterparty('Иван');

      await counterparties.createWithTransaction(
        counterparty: counterparty,
        transaction: newTransaction(
          counterpartyId: counterparty.id,
          accountId: rubleAccount.id,
          kind: TransactionKind.expense,
          amountMinor: 1200,
          occurredAt: DateTime(2026, 10, 3),
        ),
      );
      await accounts.archive(rubleAccount.id);

      final debts = await counterparties.listWithBalances(book.id);

      expect(debts.single.balanceMinor, 1200);
    });

    test('returns only active counterparties on request', () async {
      final active = newCounterparty('Активный');
      final closed = newCounterparty('Закрытый', isClosed: true);
      final zero = newCounterparty('Нулевой');

      await counterparties.createWithTransaction(
        counterparty: active,
        transaction: newTransaction(
          counterpartyId: active.id,
          accountId: rubleAccount.id,
          kind: TransactionKind.expense,
          amountMinor: 900,
          occurredAt: DateTime(2026, 10, 3),
        ),
      );
      await counterparties.createWithTransaction(
        counterparty: closed,
        transaction: newTransaction(
          counterpartyId: closed.id,
          accountId: rubleAccount.id,
          kind: TransactionKind.expense,
          amountMinor: 500,
          occurredAt: DateTime(2026, 10, 3),
        ),
      );
      await counterparties.createWithTransaction(
        counterparty: zero,
        transaction: newTransaction(
          counterpartyId: zero.id,
          accountId: rubleAccount.id,
          kind: TransactionKind.expense,
          amountMinor: 300,
          occurredAt: DateTime(2026, 10, 3),
        ),
      );
      final zeroTransaction = newTransaction(
        counterpartyId: zero.id,
        accountId: rubleAccount.id,
        kind: TransactionKind.income,
        amountMinor: 300,
        occurredAt: DateTime(2026, 10, 4),
      );

      await database
          .into(database.transactions)
          .insert(transactionToCompanion(zeroTransaction));

      final activeDebts = await counterparties.listWithBalances(
        book.id,
        onlyActive: true,
      );

      expect(activeDebts.map((debt) => debt.counterparty.name), ['Активный']);
      expect(await counterparties.listWithBalances(book.id), hasLength(3));
    });

    test('reports whether a counterparty has transactions', () async {
      final counterparty = newCounterparty('Иван');

      await counterparties.createWithTransaction(
        counterparty: counterparty,
        transaction: newTransaction(
          counterpartyId: counterparty.id,
          accountId: rubleAccount.id,
          kind: TransactionKind.expense,
          amountMinor: 100,
          occurredAt: DateTime(2026, 10, 3),
        ),
      );

      expect(await counterparties.hasTransactions(counterparty.id), isTrue);
      expect(await counterparties.hasTransactions('нет такого'), isFalse);
    });

    test(
      'lists transactions of one counterparty from newest to oldest',
      () async {
        final first = newCounterparty('Иван');
        final second = newCounterparty('Пётр');

        await counterparties.createWithTransaction(
          counterparty: first,
          transaction: newTransaction(
            counterpartyId: first.id,
            accountId: rubleAccount.id,
            kind: TransactionKind.expense,
            amountMinor: 100,
            occurredAt: DateTime(2026, 10, 1),
          ),
        );
        for (final occurredAt in [
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 3),
        ]) {
          await database
              .into(database.transactions)
              .insert(
                transactionToCompanion(
                  newTransaction(
                    counterpartyId: first.id,
                    accountId: rubleAccount.id,
                    kind: TransactionKind.income,
                    amountMinor: 50,
                    occurredAt: occurredAt,
                  ),
                ),
              );
        }
        await counterparties.createWithTransaction(
          counterparty: second,
          transaction: newTransaction(
            counterpartyId: second.id,
            accountId: rubleAccount.id,
            kind: TransactionKind.expense,
            amountMinor: 700,
            occurredAt: DateTime(2026, 10, 6),
          ),
        );

        final operations = await counterparties.listTransactions(first.id);

        expect(operations, hasLength(3));
        expect(operations.map((operation) => operation.occurredAt), [
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 3),
          DateTime(2026, 10, 1),
        ]);
        expect(
          operations.every((operation) => operation.counterpartyId == first.id),
          isTrue,
        );
      },
    );

    test('updates and deletes a counterparty', () async {
      final counterparty = newCounterparty('Иван');
      final firstTransaction = newTransaction(
        counterpartyId: counterparty.id,
        accountId: rubleAccount.id,
        kind: TransactionKind.expense,
        amountMinor: 100,
        occurredAt: DateTime(2026, 10, 3),
      );

      await counterparties.createWithTransaction(
        counterparty: counterparty,
        transaction: firstTransaction,
      );
      final renamed = FinanceCounterparty(
        id: counterparty.id,
        bookId: counterparty.bookId,
        name: 'Иван Петров',
        currencyCode: 'USD',
        isClosed: true,
        createdAt: counterparty.createdAt,
        updatedAt: DateTime(2026, 10, 4),
      );

      await counterparties.update(renamed);

      final stored = (await counterparties.getById(counterparty.id))!;

      expect(stored.name, 'Иван Петров');
      expect(stored.currencyCode, 'USD');
      expect(stored.isClosed, isTrue);

      // Пока привязана операция, контрагент не удаляется на уровне целостности
      // ссылок: приложение предлагает закрыть долг (ADR-0009, решение 9.10).
      await expectLater(
        counterparties.delete(counterparty.id),
        throwsA(isA<Exception>()),
      );

      await (database.delete(
        database.transactions,
      )..where((row) => row.id.equals(firstTransaction.id))).go();
      await counterparties.delete(counterparty.id);

      expect(await counterparties.getById(counterparty.id), isNull);
    });
  });
}
