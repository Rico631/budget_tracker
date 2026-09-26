import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BooksRepository books;
  late AccountsRepository accounts;

  setUp(() {
    database = AppDatabase.forTesting();
    books = DriftBooksRepository(database);
    accounts = DriftAccountsRepository(database);
  });

  tearDown(() => database.close());

  test('isolates child records by book and supports archive', () async {
    final firstBook = await books.create(name: 'First');
    final secondBook = await books.create(name: 'Second');
    final firstAccount = await accounts.create(
      bookId: firstBook.id,
      name: 'First account',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );
    await accounts.create(
      bookId: secondBook.id,
      name: 'Second account',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );

    expect((await accounts.listByBook(firstBook.id)).map((item) => item.id), [
      firstAccount.id,
    ]);

    await accounts.archive(firstAccount.id);
    expect(await accounts.listByBook(firstBook.id), isEmpty);
    expect(
      (await accounts.listByBook(
        firstBook.id,
        includeArchived: true,
      )).single.id,
      firstAccount.id,
    );
  });

  test('detects transactions where the account is source or transfer target', () async {
    final transactions = DriftTransactionsRepository(database);
    final book = await books.create(name: 'History');
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
    final untouched = await accounts.create(
      bookId: book.id,
      name: 'Untouched',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );

    expect(await accounts.hasTransactions(source.id), isFalse);
    expect(await accounts.hasTransactions(target.id), isFalse);

    await transactions.create(
      bookId: book.id,
      accountId: source.id,
      toAccountId: target.id,
      kind: TransactionKind.transfer,
      amountMinor: 500,
      occurredAt: DateTime(2026, 9, 26),
    );

    expect(await accounts.hasTransactions(source.id), isTrue);
    expect(await accounts.hasTransactions(target.id), isTrue);
    expect(await accounts.hasTransactions(untouched.id), isFalse);
  });
}
