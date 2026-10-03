import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/account_balance_rule.dart';
import 'package:budget_tracker/domain/services/debt_balance_rule.dart';
import 'package:budget_tracker/domain/services/debt_counterparty_rule.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:budget_tracker/domain/services/transactions_journal_rule.dart';

class FinanceTransactionUseCases {
  FinanceTransactionUseCases({
    required this.accounts,
    required this.categories,
    required this.counterparties,
    required this.transactions,
    FinanceIdGenerator? idGenerator,
  }) : idGenerator = idGenerator ?? const FinanceIdGenerator();

  final AccountsRepository accounts;
  final CategoriesRepository categories;
  final CounterpartiesRepository counterparties;
  final TransactionsRepository transactions;
  final FinanceIdGenerator idGenerator;

  /// Создает операцию книги.
  ///
  /// Если задано [newCounterpartyName], контрагент создается вместе с операцией,
  /// в которой он указан: обе записи сохраняются одной транзакцией, поэтому
  /// отказ операции не оставляет записи контрагента (ADR-0009, решение 9.11).
  Future<ValidationResult<FinanceTransaction>> create(
    FinanceTransactionInput input, {
    required DateTime occurredAt,
    String? newCounterpartyName,
  }) async {
    final validation = await _validateInput(input);
    if (validation case Invalid(errors: final errors)) {
      return ValidationResult.invalid(errors);
    }

    final newCounterparty = await _prepareNewCounterparty(
      input: input,
      name: newCounterpartyName,
    );
    if (newCounterparty case Invalid(errors: final errors)) {
      return ValidationResult.invalid(errors);
    }

    final counterparty = switch (newCounterparty) {
      Valid(value: final value) => value,
      Invalid() => null,
    };
    if (counterparty == null) {
      final created = await transactions.create(
        bookId: input.bookId,
        accountId: input.accountId,
        kind: input.kind,
        amountMinor: input.amountMinor,
        occurredAt: occurredAt,
        toAccountId: input.toAccountId,
        categoryId: input.categoryId,
        counterpartyId: input.counterpartyId,
        toAmountMinor: input.toAmountMinor,
        note: input.note,
      );
      return ValidationResult.valid(created);
    }

    final now = DateTime.now();
    final created = FinanceTransaction(
      id: idGenerator.generateV7(),
      bookId: input.bookId,
      accountId: input.accountId,
      toAccountId: input.toAccountId,
      categoryId: input.categoryId,
      counterpartyId: counterparty.id,
      kind: input.kind,
      amountMinor: input.amountMinor,
      toAmountMinor: input.toAmountMinor,
      occurredAt: occurredAt,
      note: input.note,
      createdAt: now,
      updatedAt: now,
    );
    await counterparties.createWithTransaction(
      counterparty: counterparty,
      transaction: created,
    );
    return ValidationResult.valid(created);
  }

  /// Сохраняет сумму, счета, категорию, дату, заметку и привязку к контрагенту.
  ///
  /// Тип операции неизменяем: попытка сохранить операцию с другим типом
  /// отклоняется с [transactionKindChangeRejectedError] без записи в базу.
  /// Новый контрагент из формы операции создается вместе с сохраняемой операцией
  /// (ADR-0009, решение 9.11).
  Future<ValidationResult<FinanceTransaction>> update(
    FinanceTransaction existing,
    FinanceTransactionInput input, {
    required DateTime occurredAt,
    String? newCounterpartyName,
  }) async {
    if (input.kind != existing.kind) {
      return ValidationResult.invalid([transactionKindChangeRejectedError]);
    }

    final validation = await _validateInput(input);
    if (validation case Invalid(errors: final errors)) {
      return ValidationResult.invalid(errors);
    }

    final newCounterparty = await _prepareNewCounterparty(
      input: input,
      name: newCounterpartyName,
    );
    if (newCounterparty case Invalid(errors: final errors)) {
      return ValidationResult.invalid(errors);
    }

    final counterparty = switch (newCounterparty) {
      Valid(value: final value) => value,
      Invalid() => null,
    };
    final updated = FinanceTransaction(
      id: existing.id,
      bookId: input.bookId,
      accountId: input.accountId,
      toAccountId: input.toAccountId,
      categoryId: input.categoryId,
      counterpartyId: counterparty?.id ?? input.counterpartyId,
      kind: input.kind,
      amountMinor: input.amountMinor,
      toAmountMinor: input.toAmountMinor,
      occurredAt: occurredAt,
      note: input.note,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );

    if (counterparty == null) {
      await transactions.update(updated);
    } else {
      await counterparties.createWithTransaction(
        counterparty: counterparty,
        transaction: updated,
      );
    }
    return ValidationResult.valid(updated);
  }

  /// Безвозвратно удаляет операцию: ее влияние на остатки исчезает.
  Future<void> delete(String id) => transactions.delete(id);

  /// Журнал операций книги: операции читаются один раз и группируются по дням.
  Future<TransactionsJournal> loadJournal(String bookId) async {
    final bookTransactions = await transactions.listByBook(bookId);
    return groupJournalByDay(bookTransactions);
  }

  Future<int> calculateAccountBalance(String accountId) async {
    final account = await accounts.getById(accountId);
    if (account == null) return 0;

    final accountTransactions = await transactions.listByBook(account.bookId);
    return accountBalanceMinor(account, accountTransactions);
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

    if (input.counterpartyId case final counterpartyId?) {
      final counterparty = await counterparties.getById(counterpartyId);
      if (counterparty == null || counterparty.bookId != input.bookId) {
        return ValidationResult.invalid([
          transactionCounterpartyBookMismatchError,
        ]);
      }
      if (counterparty.currencyCode != sourceAccount.currencyCode) {
        return ValidationResult.invalid([
          transactionCounterpartyCurrencyMismatchError,
        ]);
      }
      // Роль займа подходит любому контрагенту, а роль возврата долга — только
      // контрагенту с остатком своего направления (ADR-0009, решение 9.15).
      final role = category?.debtRole;
      if (role != null &&
          !debtRoleAcceptsBalance(
            role,
            await _counterpartyBalanceMinor(counterpartyId),
          )) {
        return ValidationResult.invalid([
          transactionCounterpartyDebtRoleMismatchError,
        ]);
      }
    }

    if (input.kind == TransactionKind.transfer) {
      final targetAccount = await accounts.getById(input.toAccountId!);
      if (targetAccount == null || targetAccount.bookId != input.bookId) {
        return ValidationResult.invalid(['toAccountId must belong to bookId.']);
      }
      final isCrossCurrency =
          targetAccount.currencyCode != sourceAccount.currencyCode;
      if (isCrossCurrency && input.toAmountMinor == null) {
        return ValidationResult.invalid([transferToAmountRequiredError]);
      }
      if (!isCrossCurrency && input.toAmountMinor != null) {
        return ValidationResult.invalid([transferToAmountNotAllowedError]);
      }
    }

    return ValidationResult.valid(null);
  }

  /// Остаток долга контрагента по его привязанным операциям (ADR-0009, 9.2).
  Future<int> _counterpartyBalanceMinor(String counterpartyId) async =>
      debtBalanceMinor(
        counterpartyId,
        await counterparties.listTransactions(counterpartyId),
      );

  /// Готовит нового контрагента формы операции: `null`, если имя не задано.
  ///
  /// Валюта нового контрагента равна валюте счета операции, поэтому привязка
  /// всегда допустима, а наименование проверяется на уникальность в книге
  /// (ADR-0009, решения 9.9 и 9.11).
  Future<ValidationResult<FinanceCounterparty?>> _prepareNewCounterparty({
    required FinanceTransactionInput input,
    required String? name,
  }) async {
    if (name == null) {
      return ValidationResult.valid(null);
    }
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return ValidationResult.invalid([catalogNameRequiredError]);
    }
    if (await counterparties.findByName(
          bookId: input.bookId,
          name: trimmedName,
        ) !=
        null) {
      return ValidationResult.invalid([counterpartyNameDuplicateError]);
    }

    final sourceAccount = await accounts.getById(input.accountId);
    if (sourceAccount == null) {
      return ValidationResult.invalid(['accountId must belong to bookId.']);
    }

    final now = DateTime.now();
    return ValidationResult.valid(
      FinanceCounterparty(
        id: idGenerator.generateV7(),
        bookId: input.bookId,
        name: trimmedName,
        currencyCode: sourceAccount.currencyCode,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
