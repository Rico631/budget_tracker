import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
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
}
