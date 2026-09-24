import 'dart:io';

import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
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
}
