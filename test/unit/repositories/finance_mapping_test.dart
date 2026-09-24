import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/banks_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/categories_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BooksRepository books;
  late BanksRepository banks;
  late AccountsRepository accounts;
  late CategoriesRepository categories;
  late TransactionsRepository transactions;

  setUp(() {
    database = AppDatabase.forTesting();
    books = DriftBooksRepository(database);
    banks = DriftBanksRepository(database);
    accounts = DriftAccountsRepository(database);
    categories = DriftCategoriesRepository(database);
    transactions = DriftTransactionsRepository(database);
  });

  tearDown(() => database.close());

  test('round-trips nullable finance fields through repositories', () async {
    final book = await books.create(name: 'Personal');
    final bank = await banks.create(name: 'Cash');
    final account = await accounts.create(
      bookId: book.id,
      name: 'Wallet',
      currencyCode: 'RUB',
      initialBalanceMinor: 1000,
    );
    final category = await categories.create(
      bookId: book.id,
      name: 'Food',
      kind: TransactionKind.expense,
    );
    final transaction = await transactions.create(
      bookId: book.id,
      accountId: account.id,
      kind: TransactionKind.expense,
      amountMinor: 250,
      occurredAt: DateTime(2026, 9, 24),
      categoryId: category.id,
    );

    expect((await books.getById(book.id))!.id, book.id);
    expect((await banks.getById(bank.id))!.displayName, isNull);
    expect((await accounts.getById(account.id))!.bankId, isNull);
    expect((await categories.getById(category.id))!.parentId, isNull);
    expect((await transactions.getById(transaction.id))!.toAccountId, isNull);
    expect((await transactions.getById(transaction.id))!.note, isNull);
  });
}
