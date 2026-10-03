import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/repositories/accounts_repository.dart';
import 'package:budget_tracker/data/repositories/banks_repository.dart';
import 'package:budget_tracker/data/repositories/books_repository.dart';
import 'package:budget_tracker/data/repositories/transactions_repository.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late BooksRepository books;
  late BanksRepository banks;
  late AccountsRepository accounts;
  late TransactionsRepository transactions;

  setUp(() {
    database = AppDatabase.forTesting();
    books = DriftBooksRepository(database);
    banks = DriftBanksRepository(database);
    accounts = DriftAccountsRepository(database);
    transactions = DriftTransactionsRepository(database);
  });

  tearDown(() => database.close());

  test('detaches accounts from the bank and deletes it', () async {
    final book = await books.create(name: 'Личная книга');
    final bank = await banks.create(name: 'Сбербанк');
    final otherBank = await banks.create(name: 'Тинькофф');
    final linked = await accounts.create(
      bookId: book.id,
      name: 'Зарплатный',
      currencyCode: 'RUB',
      initialBalanceMinor: 250000,
      bankId: bank.id,
    );
    final untouched = await accounts.create(
      bookId: book.id,
      name: 'Наличные',
      currencyCode: 'RUB',
      initialBalanceMinor: 1000,
      bankId: otherBank.id,
    );
    await transactions.create(
      bookId: book.id,
      accountId: linked.id,
      kind: TransactionKind.expense,
      amountMinor: 1500,
      occurredAt: DateTime(2026, 9, 20),
    );

    await banks.deleteWithAccountDetach(bank.id);

    expect(await banks.getById(bank.id), isNull);

    // Счет остается валидным и читается как счет без банка.
    final storedLinked = (await accounts.getById(linked.id))!;

    expect(storedLinked.bankId, isNull);
    expect(storedLinked.name, 'Зарплатный');
    expect(storedLinked.currencyCode, 'RUB');
    expect(storedLinked.initialBalanceMinor, 250000);
    expect(
      (await accounts.listByBook(
        book.id,
      )).where((account) => account.id == linked.id).single.bankId,
      isNull,
    );
    expect((await accounts.getById(untouched.id))!.bankId, otherBank.id);

    final storedTransactions = await transactions.listByBook(book.id);

    expect(storedTransactions, hasLength(1));
    expect(storedTransactions.single.accountId, linked.id);
    expect(storedTransactions.single.amountMinor, 1500);
  });

  test('finds a bank by name without case or surrounding spaces', () async {
    await banks.create(name: 'СберБанк');

    expect((await banks.findByName('  сбербанк '))?.name, 'СберБанк');
    expect(await banks.findByName('Тинькофф'), isNull);
  });
}
