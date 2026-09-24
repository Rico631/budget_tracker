import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';

class FinanceTransactionUseCases {
  FinanceTransactionUseCases({
    required this.accounts,
    required this.categories,
    required this.transactions,
  });

  final AccountsRepository accounts;
  final CategoriesRepository categories;
  final TransactionsRepository transactions;

  Future<ValidationResult<FinanceTransaction>> create(
    FinanceTransactionInput input, {
    required DateTime occurredAt,
  }) async {
    final validation = await _validateInput(input);
    if (validation case Invalid(errors: final errors)) {
      return ValidationResult.invalid(errors);
    }

    final created = await transactions.create(
      bookId: input.bookId,
      accountId: input.accountId,
      kind: input.kind,
      amountMinor: input.amountMinor,
      occurredAt: occurredAt,
      toAccountId: input.toAccountId,
      categoryId: input.categoryId,
      note: input.note,
    );
    return ValidationResult.valid(created);
  }

  Future<ValidationResult<FinanceTransaction>> update(
    FinanceTransaction existing,
    FinanceTransactionInput input, {
    required DateTime occurredAt,
  }) async {
    final validation = await _validateInput(input);
    if (validation case Invalid(errors: final errors)) {
      return ValidationResult.invalid(errors);
    }

    final updated = FinanceTransaction(
      id: existing.id,
      bookId: input.bookId,
      accountId: input.accountId,
      toAccountId: input.toAccountId,
      categoryId: input.categoryId,
      kind: input.kind,
      amountMinor: input.amountMinor,
      occurredAt: occurredAt,
      note: input.note,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await transactions.update(updated);
    return ValidationResult.valid(updated);
  }

  Future<void> delete(String id) => transactions.delete(id);

  Future<int> calculateAccountBalance(String accountId) async {
    final account = await accounts.getById(accountId);
    if (account == null) return 0;

    final accountTransactions = await transactions.listByBook(account.bookId);
    var balance = account.initialBalanceMinor;
    for (final transaction in accountTransactions) {
      if (transaction.accountId == accountId) {
        balance += switch (transaction.kind) {
          TransactionKind.income => transaction.amountMinor,
          TransactionKind.expense ||
          TransactionKind.transfer => -transaction.amountMinor,
        };
      }
      if (transaction.kind == TransactionKind.transfer &&
          transaction.toAccountId == accountId) {
        balance += transaction.amountMinor;
      }
    }
    return balance;
  }

  Future<int> calculateBookBalance(String bookId) async {
    final bookAccounts = await accounts.listByBook(bookId);
    final bookTransactions = await transactions.listByBook(bookId);
    var balance = bookAccounts.fold<int>(
      0,
      (total, account) => total + account.initialBalanceMinor,
    );
    for (final transaction in bookTransactions) {
      balance += switch (transaction.kind) {
        TransactionKind.income => transaction.amountMinor,
        TransactionKind.expense => -transaction.amountMinor,
        TransactionKind.transfer => 0,
      };
    }
    return balance;
  }

  Future<ValidationResult<void>> _validateInput(
    FinanceTransactionInput input,
  ) async {
    final sourceAccount = await accounts.getById(input.accountId);
    if (sourceAccount == null || sourceAccount.bookId != input.bookId) {
      return ValidationResult.invalid(['accountId must belong to bookId.']);
    }

    final category = input.categoryId == null
        ? null
        : await categories.getById(input.categoryId!);
    if (input.categoryId != null &&
        (category == null || category.bookId != input.bookId)) {
      return ValidationResult.invalid(['categoryId must belong to bookId.']);
    }

    if (input.kind != TransactionKind.transfer &&
        category!.kind != input.kind) {
      return ValidationResult.invalid([
        'Category kind must match transaction kind.',
      ]);
    }

    if (input.kind == TransactionKind.transfer) {
      final targetAccount = await accounts.getById(input.toAccountId!);
      if (targetAccount == null || targetAccount.bookId != input.bookId) {
        return ValidationResult.invalid(['toAccountId must belong to bookId.']);
      }
      if (targetAccount.currencyCode != sourceAccount.currencyCode) {
        return ValidationResult.invalid([
          'Transfer accounts must use the same currency.',
        ]);
      }
    }

    return ValidationResult.valid(null);
  }
}
