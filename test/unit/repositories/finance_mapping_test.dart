import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/data/local/mappers/finance_row_mappers.dart';
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
    expect(
      (await transactions.getById(transaction.id))!.toAmountMinor,
      isNull,
    );
  });

  test('keeps the destination amount of a cross-currency transfer', () async {
    final book = await books.create(name: 'Cross currency');
    final source = await accounts.create(
      bookId: book.id,
      name: 'Dollars',
      currencyCode: 'USD',
      initialBalanceMinor: 0,
    );
    final target = await accounts.create(
      bookId: book.id,
      name: 'Rubles',
      currencyCode: 'RUB',
      initialBalanceMinor: 0,
    );

    final stored = await database
        .into(database.transactions)
        .insertReturning(
          transactionToCompanion(
            FinanceTransaction(
              id: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8b',
              bookId: book.id,
              accountId: source.id,
              toAccountId: target.id,
              kind: TransactionKind.transfer,
              amountMinor: 10000,
              toAmountMinor: 915000,
              occurredAt: DateTime(2026, 9, 24),
              createdAt: DateTime(2026, 9, 24),
              updatedAt: DateTime(2026, 9, 24),
            ),
          ),
        );

    final domain = stored.toDomain();

    expect(domain.kind, TransactionKind.transfer);
    expect(domain.amountMinor, 10000);
    expect(domain.toAmountMinor, 915000);
    expect(domain.bookId, book.id);
  });

  test('round-trips preset bank fields and currency catalog rows', () async {
    final presetBank = FinanceBank(
      id: '018f8d2e-3f2d-7e2a-9b3a-9e6c2c3b7d8b',
      name: 'СберБанк',
      colorHex: '#21A038',
      iconDomain: 'sberbank.ru',
      isPreset: true,
    );
    await database.into(database.banks).insert(bankToCompanion(presetBank));

    final storedBank = await banks.getById(presetBank.id);

    expect(storedBank!.colorHex, '#21A038');
    expect(storedBank.iconDomain, 'sberbank.ru');
    expect(storedBank.isPreset, isTrue);

    final customBank = await banks.create(name: 'Cash');

    expect((await banks.getById(customBank.id))!.colorHex, isNull);
    expect((await banks.getById(customBank.id))!.iconDomain, isNull);
    expect((await banks.getById(customBank.id))!.isPreset, isFalse);

    final currency = FinanceCurrency(
      code: 'RUB',
      numericCode: '643',
      symbol: '₽',
      nameRu: 'Российский рубль',
      nameEn: 'Russian Rouble',
    );
    await database
        .into(database.currencies)
        .insert(currencyToCompanion(currency));

    final storedCurrency = (await database.select(database.currencies).get())
        .single
        .toDomain();

    expect(storedCurrency.code, 'RUB');
    expect(storedCurrency.numericCode, '643');
    expect(storedCurrency.symbol, '₽');
    expect(storedCurrency.nameRu, 'Российский рубль');
    expect(storedCurrency.nameEn, 'Russian Rouble');

    final currencyWithoutSymbol = FinanceCurrency(
      code: 'XAU',
      numericCode: '959',
      nameRu: 'Золото (тройская унция)',
      nameEn: 'Gold',
    );
    await database
        .into(database.currencies)
        .insert(currencyToCompanion(currencyWithoutSymbol));

    final storedMetals = (await database.select(database.currencies).get())
        .where((row) => row.code == 'XAU')
        .single
        .toDomain();

    expect(storedMetals.symbol, isNull);
    expect(storedMetals.nameRu, 'Золото (тройская унция)');
  });
}
