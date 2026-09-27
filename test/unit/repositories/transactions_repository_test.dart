import 'dart:io';

import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BooksRepository books;
  late AccountsRepository accounts;
  late TransactionsRepository transactions;

  setUp(() {
    database = AppDatabase.forTesting();
    books = DriftBooksRepository(database);
    accounts = DriftAccountsRepository(database);
    transactions = DriftTransactionsRepository(database);
  });

  tearDown(() => database.close());

  test('keeps transfer writes atomic and supports update/delete', () async {
    final book = await books.create(name: 'Transfers');
    final source = await accounts.create(
      bookId: book.id,
      name: 'Source',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final target = await accounts.create(
      bookId: book.id,
      name: 'Target',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final transfer = await transactions.create(
      bookId: book.id,
      accountId: source.id,
      toAccountId: target.id,
      kind: TransactionKind.transfer,
      amountMinor: 500,
      occurredAt: DateTime(2026, 9, 24),
    );

    expect((await transactions.listByBook(book.id)).single.id, transfer.id);
    final updated = FinanceTransaction(
      id: transfer.id,
      bookId: transfer.bookId,
      accountId: transfer.accountId,
      toAccountId: transfer.toAccountId,
      categoryId: transfer.categoryId,
      kind: transfer.kind,
      amountMinor: 750,
      occurredAt: transfer.occurredAt,
      note: transfer.note,
      createdAt: transfer.createdAt,
      updatedAt: DateTime.now(),
    );
    await transactions.update(updated);
    expect((await transactions.getById(transfer.id))!.amountMinor, 750);

    await transactions.delete(transfer.id);
    expect(await transactions.getById(transfer.id), isNull);
  });

  test(
    'restores transactions after reopening a file-backed database',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'budget_tracker_',
      );
      final file = File.fromUri(directory.uri.resolve('finance.sqlite'));
      final firstDatabase = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(() async {
        await firstDatabase.close();
        await directory.delete(recursive: true);
      });

      final firstBooks = DriftBooksRepository(firstDatabase);
      final firstAccounts = DriftAccountsRepository(firstDatabase);
      final firstCategories = DriftCategoriesRepository(firstDatabase);
      final firstTransactions = DriftTransactionsRepository(firstDatabase);
      final book = await firstBooks.create(name: 'Persistent');
      final account = await firstAccounts.create(
        bookId: book.id,
        name: 'Main',
        currencyCode: 'RUB',
        initialBalanceMinor: 0,
      );
      final category = await firstCategories.create(
        bookId: book.id,
        name: 'Food',
        kind: TransactionKind.expense,
      );
      await firstTransactions.create(
        bookId: book.id,
        accountId: account.id,
        categoryId: category.id,
        kind: TransactionKind.expense,
        amountMinor: 300,
        occurredAt: DateTime(2026, 9, 24),
      );
      await firstDatabase.close();

      final reopenedDatabase = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(reopenedDatabase.close);
      final reopenedTransactions = DriftTransactionsRepository(
        reopenedDatabase,
      );
      expect(
        (await reopenedTransactions.listByBook(book.id)).single.amountMinor,
        300,
      );
    },
  );

  test('creates a cross-currency transfer with both amounts', () async {
    final book = await books.create(name: 'Cross currency');
    final source = await accounts.create(
      bookId: book.id,
      name: 'Dollars',
      currencyCode: 'USD',
      initialBalanceMinor: 10000,
    );
    final target = await accounts.create(
      bookId: book.id,
      name: 'Rubles',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );

    final transfer = await transactions.create(
      bookId: book.id,
      accountId: source.id,
      toAccountId: target.id,
      kind: TransactionKind.transfer,
      amountMinor: 10000,
      toAmountMinor: 915000,
      occurredAt: DateTime(2026, 9, 24),
    );

    final stored = await transactions.getById(transfer.id);

    expect(stored!.amountMinor, 10000);
    expect(stored.toAmountMinor, 915000);
  });

  test('updates the destination amount and keeps identity of a transaction',
      () async {
    final book = await books.create(name: 'Update');
    final source = await accounts.create(
      bookId: book.id,
      name: 'Source',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final target = await accounts.create(
      bookId: book.id,
      name: 'Target',
      currencyCode: 'USD',
      initialBalanceMinor: 0,
    );
    final transfer = await transactions.create(
      bookId: book.id,
      accountId: source.id,
      toAccountId: target.id,
      kind: TransactionKind.transfer,
      amountMinor: 90000,
      toAmountMinor: 1000,
      occurredAt: DateTime(2026, 9, 24),
    );

    final storedBeforeUpdate = await transactions.getById(transfer.id);

    await transactions.update(
      FinanceTransaction(
        id: transfer.id,
        bookId: transfer.bookId,
        accountId: transfer.accountId,
        toAccountId: transfer.toAccountId,
        kind: transfer.kind,
        amountMinor: transfer.amountMinor,
        toAmountMinor: 1150,
        occurredAt: transfer.occurredAt,
        createdAt: transfer.createdAt,
        updatedAt: DateTime.now(),
      ),
    );

    final stored = await transactions.getById(transfer.id);

    expect((await transactions.listByBook(book.id)), hasLength(1));
    expect(stored!.id, transfer.id);
    expect(stored.createdAt, storedBeforeUpdate!.createdAt);
    expect(stored.toAmountMinor, 1150);
  });

  test('deletes only the requested transaction', () async {
    final book = await books.create(name: 'Delete');
    final account = await accounts.create(
      bookId: book.id,
      name: 'Main',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final kept = await transactions.create(
      bookId: book.id,
      accountId: account.id,
      kind: TransactionKind.income,
      amountMinor: 100,
      occurredAt: DateTime(2026, 9, 24),
    );
    final removed = await transactions.create(
      bookId: book.id,
      accountId: account.id,
      kind: TransactionKind.expense,
      amountMinor: 200,
      occurredAt: DateTime(2026, 9, 25),
    );

    await transactions.delete(removed.id);

    expect(await transactions.getById(removed.id), isNull);
    expect(await transactions.getById(kept.id), isNotNull);
    expect((await transactions.listByBook(book.id)).single.id, kept.id);
  });

  test('reads transactions of a book from newest to oldest', () async {
    final book = await books.create(name: 'Order');
    final account = await accounts.create(
      bookId: book.id,
      name: 'Main',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final older = await transactions.create(
      bookId: book.id,
      accountId: account.id,
      kind: TransactionKind.income,
      amountMinor: 100,
      occurredAt: DateTime(2026, 9, 23),
    );
    final newer = await transactions.create(
      bookId: book.id,
      accountId: account.id,
      kind: TransactionKind.expense,
      amountMinor: 200,
      occurredAt: DateTime(2026, 9, 25),
    );

    final ordered = await transactions.listByBook(book.id);

    expect(ordered.map((transaction) => transaction.id), [
      newer.id,
      older.id,
    ]);
  });

  test('reads same-day transactions from newest to oldest', () async {
    final book = await books.create(name: 'Same day');
    final account = await accounts.create(
      bookId: book.id,
      name: 'Main',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    final occurredAt = DateTime(2026, 9, 24);
    final orderedIds = <String>[];
    final orderedTransactions = DriftTransactionsRepository(
      database,
      idGenerator: _FixedIdGenerator([
        '00000000-0000-7000-8000-000000000001',
        '00000000-0000-7000-8000-000000000002',
      ]),
    );

    orderedIds.add(
      (await orderedTransactions.create(
        bookId: book.id,
        accountId: account.id,
        kind: TransactionKind.income,
        amountMinor: 100,
        occurredAt: occurredAt,
      ))
          .id,
    );
    orderedIds.add(
      (await orderedTransactions.create(
        bookId: book.id,
        accountId: account.id,
        kind: TransactionKind.expense,
        amountMinor: 200,
        occurredAt: occurredAt,
      ))
          .id,
    );

    final stored = await transactions.listByBook(book.id);

    expect(stored.map((transaction) => transaction.id), [
      orderedIds.last,
      orderedIds.first,
    ]);
  });
}

/// Генератор идентификаторов с заданной последовательностью значений.
///
/// Нужен, чтобы порядок операций с одинаковой датой не зависел от времени
/// создания записи в тесте.
class _FixedIdGenerator extends FinanceIdGenerator {
  _FixedIdGenerator(this._ids);

  final List<String> _ids;
  int _nextIndex = 0;

  @override
  String generateV7() => _ids[_nextIndex++];
}
