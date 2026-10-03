import 'package:budget_tracker/domain/commands/counterparty_input.dart';
import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/catalog_name_rule.dart';
import 'package:budget_tracker/domain/services/debt_counterparty_rule.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';

/// Домен: учет долгов с контрагентами книги.
///
/// Остаток долга не хранится и вычисляется из привязанных операций, контрагент
/// создается только вместе с операцией, а записи с историей закрываются, а не
/// удаляются (ADR-0009, решения 9.2, 9.10 и 9.11).
class DebtUseCases {
  DebtUseCases({
    required this.accounts,
    required this.categories,
    required this.counterparties,
    FinanceIdGenerator? idGenerator,
  }) : idGenerator = idGenerator ?? const FinanceIdGenerator();

  final AccountsRepository accounts;
  final CategoriesRepository categories;
  final CounterpartiesRepository counterparties;
  final FinanceIdGenerator idGenerator;

  /// Обзор долгов книги: активные контрагенты по знаку остатка и архив.
  Future<DebtOverview> loadOverview(String bookId) async {
    final debts = await counterparties.listWithBalances(bookId);
    return DebtOverview.fromDebts(debts);
  }

  /// Активные контрагенты книги с валютой [currencyCode], допустимые для
  /// операции с долговой ролью [role].
  ///
  /// Список используется полем контрагента в форме операции: привязка доступна
  /// только операции счета той же валюты (ADR-0009, решение 9.9), а возврат
  /// долга дополнительно требует контрагента с подходящим знаком остатка
  /// (решение 9.15).
  Future<List<FinanceCounterparty>> listCounterpartiesForOperation({
    required String bookId,
    required String currencyCode,
    required CategoryDebtRole role,
  }) async {
    final debts = await counterparties.listWithBalances(
      bookId,
      onlyActive: true,
    );
    return [
      for (final debt in debts)
        if (debt.counterparty.currencyCode == currencyCode &&
            debtRoleAcceptsBalance(role, debt.balanceMinor))
          debt.counterparty,
    ];
  }

  /// Создает контрагента вместе с первой операцией долга.
  ///
  /// Направление задает тип первой операции, а ее категория — долговая
  /// категория займа этого типа: заем отличается от возврата долга собственной
  /// ролью, поэтому выбор не зависит от наименования категории
  /// (ADR-0009, решения 9.5, 9.7 и 9.11).
  Future<ValidationResult<FinanceCounterparty>> createWithFirstTransaction(
    CounterpartyInput input,
  ) async {
    final trimmedName = input.name.trim();
    if (await _isNameTaken(bookId: input.bookId, name: trimmedName)) {
      return ValidationResult.invalid([counterpartyNameDuplicateError]);
    }

    final account = await accounts.getById(input.accountId);
    if (account == null ||
        account.bookId != input.bookId ||
        account.currencyCode != input.currencyCode) {
      return ValidationResult.invalid([
        counterpartyAccountCurrencyMismatchError,
      ]);
    }

    final kind = input.firstTransactionKind;
    final category = await _debtCategory(input.bookId, kind);
    if (category == null) {
      return ValidationResult.invalid([counterpartyDebtCategoryMissingError]);
    }

    final now = DateTime.now();
    final counterparty = FinanceCounterparty(
      id: idGenerator.generateV7(),
      bookId: input.bookId,
      name: trimmedName,
      currencyCode: input.currencyCode,
      createdAt: now,
      updatedAt: now,
    );
    await counterparties.createWithTransaction(
      counterparty: counterparty,
      transaction: FinanceTransaction(
        id: idGenerator.generateV7(),
        bookId: input.bookId,
        accountId: account.id,
        categoryId: category.id,
        counterpartyId: counterparty.id,
        kind: kind,
        amountMinor: input.amountMinor,
        occurredAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    return ValidationResult.valid(counterparty);
  }

  /// Сохраняет наименование и валюту контрагента.
  ///
  /// Наименование остается уникальным в книге, а валюта изменяется только у
  /// контрагента без привязанных операций: привязка операции другой валюты
  /// недопустима (ADR-0009, решение 9.9).
  Future<ValidationResult<FinanceCounterparty>> update(
    FinanceCounterparty existing, {
    required String name,
    required String currencyCode,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      return ValidationResult.invalid([catalogNameRequiredError]);
    }
    final normalizedCurrency = currencyCode.trim().toUpperCase();
    if (!_currencyCodePattern.hasMatch(normalizedCurrency)) {
      return ValidationResult.invalid([counterpartyCurrencyCodeInvalidError]);
    }

    if (await _isNameTaken(
      bookId: existing.bookId,
      name: trimmedName,
      exceptId: existing.id,
    )) {
      return ValidationResult.invalid([counterpartyNameDuplicateError]);
    }

    if (normalizedCurrency != existing.currencyCode &&
        await counterparties.hasTransactions(existing.id)) {
      return ValidationResult.invalid([
        counterpartyCurrencyChangeRejectedError,
      ]);
    }

    final updated = FinanceCounterparty(
      id: existing.id,
      bookId: existing.bookId,
      name: trimmedName,
      currencyCode: normalizedCurrency,
      isClosed: existing.isClosed,
      createdAt: existing.createdAt,
      updatedAt: DateTime.now(),
    );
    await counterparties.update(updated);
    return ValidationResult.valid(updated);
  }

  /// Закрывает долг вручную: контрагент уходит в архив при любом остатке, а его
  /// остаток сохраняется и показывается в архиве (ADR-0009, решение 9.10).
  Future<void> close(FinanceCounterparty counterparty) =>
      _setClosed(counterparty, isClosed: true);

  /// Возвращает контрагента в активные вручную.
  ///
  /// При нулевом остатке контрагент снова уходит в архив при следующем
  /// пересчете, потому что активность определяется остатком (ADR-0009,
  /// решение 9.10).
  Future<void> reopen(FinanceCounterparty counterparty) =>
      _setClosed(counterparty, isClosed: false);

  /// Удаляет контрагента без привязанных операций.
  ///
  /// Контрагент с историей не удаляется безвозвратно: приложение предлагает
  /// закрыть долг, а операции и остатки счетов остаются без изменений
  /// (ADR-0009, решение 9.10).
  Future<ValidationResult<void>> delete(
    FinanceCounterparty counterparty,
  ) async {
    if (await counterparties.hasTransactions(counterparty.id)) {
      return ValidationResult.invalid([counterpartyDeleteRejectedError]);
    }
    await counterparties.delete(counterparty.id);
    return ValidationResult.valid(null);
  }

  /// Операции контрагента от новых к старым.
  Future<List<FinanceTransaction>> loadTransactions(String counterpartyId) =>
      counterparties.listTransactions(counterpartyId);

  Future<void> _setClosed(
    FinanceCounterparty counterparty, {
    required bool isClosed,
  }) {
    return counterparties.update(
      FinanceCounterparty(
        id: counterparty.id,
        bookId: counterparty.bookId,
        name: counterparty.name,
        currencyCode: counterparty.currencyCode,
        isClosed: isClosed,
        createdAt: counterparty.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<bool> _isNameTaken({
    required String bookId,
    required String name,
    String? exceptId,
  }) async {
    for (final counterparty in await counterparties.listWithBalances(bookId)) {
      if (counterparty.counterparty.id == exceptId) continue;
      if (catalogNamesMatch(counterparty.counterparty.name, name)) return true;
    }
    return false;
  }

  /// Долговая категория займа типа [kind].
  ///
  /// Роль различает и тип операции, и событие долга, поэтому заем ищется по
  /// собственной роли своего типа, а сравнение наименований не требуется
  /// (ADR-0009, решение 9.5).
  Future<FinanceCategory?> _debtCategory(
    String bookId,
    TransactionKind kind,
  ) async {
    final expectedRole = switch (kind) {
      TransactionKind.expense => CategoryDebtRole.loanOutflow,
      TransactionKind.income => CategoryDebtRole.loanInflow,
      TransactionKind.transfer => null,
    };
    if (expectedRole == null) return null;

    final bookCategories = await categories.listByBook(bookId);
    for (final category in bookCategories) {
      if (category.kind == kind && category.debtRole == expectedRole) {
        return category;
      }
    }
    return null;
  }

  static final RegExp _currencyCodePattern = RegExp(r'^[A-Z]{3}$');
}
