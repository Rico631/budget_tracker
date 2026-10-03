import 'package:budget_tracker/data/local/database/app_database.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:drift/drift.dart';

extension BookRowMapper on Book {
  FinanceBook toDomain() => FinanceBook(
    id: id,
    name: name,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isArchived: isArchived,
  );
}

extension BankRowMapper on Bank {
  FinanceBank toDomain() => FinanceBank(
    id: id,
    name: name,
    displayName: displayName,
    displayDetails: displayDetails,
    colorHex: colorHex,
    iconDomain: iconDomain,
    isPreset: isPreset,
    isArchived: isArchived,
  );
}

extension CurrencyRowMapper on Currency {
  FinanceCurrency toDomain() => FinanceCurrency(
    code: code,
    numericCode: numericCode,
    symbol: symbol,
    nameRu: nameRu,
    nameEn: nameEn,
  );
}

extension AccountRowMapper on Account {
  FinanceAccount toDomain() => FinanceAccount(
    id: id,
    bookId: bookId,
    bankId: bankId,
    name: name,
    currencyCode: currencyCode,
    initialBalanceMinor: initialBalanceMinor,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isArchived: isArchived,
  );
}

extension CategoryRowMapper on Category {
  FinanceCategory toDomain() => FinanceCategory(
    id: id,
    bookId: bookId,
    name: name,
    kind: TransactionKind.values.byName(kind),
    parentId: parentId,
    createdAt: createdAt,
    updatedAt: updatedAt,
    isArchived: isArchived,
    isFallback: isFallback,
    debtRole: debtRole == null
        ? null
        : CategoryDebtRole.values.byName(debtRole!),
  );
}

extension TransactionRowMapper on Transaction {
  FinanceTransaction toDomain() => FinanceTransaction(
    id: id,
    bookId: bookId,
    accountId: accountId,
    toAccountId: toAccountId,
    categoryId: categoryId,
    counterpartyId: counterpartyId,
    kind: TransactionKind.values.byName(kind),
    amountMinor: amountMinor,
    toAmountMinor: toAmountMinor,
    occurredAt: occurredAt,
    note: note,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

BooksCompanion bookToCompanion(FinanceBook book) => BooksCompanion.insert(
  id: book.id,
  name: book.name,
  createdAt: Value(book.createdAt),
  updatedAt: Value(book.updatedAt),
  isArchived: Value(book.isArchived),
);

BanksCompanion bankToCompanion(FinanceBank bank) => BanksCompanion.insert(
  id: bank.id,
  name: bank.name,
  displayName: Value(bank.displayName),
  displayDetails: Value(bank.displayDetails),
  colorHex: Value(bank.colorHex),
  iconDomain: Value(bank.iconDomain),
  isPreset: Value(bank.isPreset),
  isArchived: Value(bank.isArchived),
);

CurrenciesCompanion currencyToCompanion(FinanceCurrency currency) =>
    CurrenciesCompanion.insert(
      code: currency.code,
      numericCode: currency.numericCode,
      symbol: Value(currency.symbol),
      nameRu: currency.nameRu,
      nameEn: currency.nameEn,
    );

AccountsCompanion accountToCompanion(FinanceAccount account) =>
    AccountsCompanion.insert(
      id: account.id,
      bookId: account.bookId,
      bankId: Value(account.bankId),
      name: account.name,
      currencyCode: account.currencyCode,
      initialBalanceMinor: account.initialBalanceMinor,
      createdAt: Value(account.createdAt),
      updatedAt: Value(account.updatedAt),
      isArchived: Value(account.isArchived),
    );

CategoriesCompanion categoryToCompanion(FinanceCategory category) =>
    CategoriesCompanion.insert(
      id: category.id,
      bookId: category.bookId,
      name: category.name,
      kind: category.kind.name,
      parentId: Value(category.parentId),
      createdAt: Value(category.createdAt),
      updatedAt: Value(category.updatedAt),
      isArchived: Value(category.isArchived),
      isFallback: Value(category.isFallback),
      debtRole: Value(category.debtRole?.name),
    );

extension CounterpartyRowMapper on Counterparty {
  FinanceCounterparty toDomain() => FinanceCounterparty(
    id: id,
    bookId: bookId,
    name: name,
    currencyCode: currencyCode,
    isClosed: isClosed,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

CounterpartiesCompanion counterpartyToCompanion(
  FinanceCounterparty counterparty,
) => CounterpartiesCompanion.insert(
  id: counterparty.id,
  bookId: counterparty.bookId,
  name: counterparty.name,
  currencyCode: counterparty.currencyCode,
  isClosed: Value(counterparty.isClosed),
  createdAt: Value(counterparty.createdAt),
  updatedAt: Value(counterparty.updatedAt),
);

TransactionsCompanion transactionToCompanion(FinanceTransaction transaction) =>
    TransactionsCompanion.insert(
      id: transaction.id,
      bookId: transaction.bookId,
      accountId: transaction.accountId,
      toAccountId: Value(transaction.toAccountId),
      categoryId: Value(transaction.categoryId),
      counterpartyId: Value(transaction.counterpartyId),
      kind: transaction.kind.name,
      amountMinor: transaction.amountMinor,
      toAmountMinor: Value(transaction.toAmountMinor),
      occurredAt: Value(transaction.occurredAt),
      note: Value(transaction.note),
      createdAt: Value(transaction.createdAt),
      updatedAt: Value(transaction.updatedAt),
    );
