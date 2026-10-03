import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/domain/commands/counterparty_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/core/utils/finance_validation_exception.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/accounts_controller.dart';
import 'package:budget_tracker/ui/features/analytics/view_models/analytics_controller.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/transactions_journal_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Обзор долгов книги: активные контрагенты по знаку остатка и архив.
final debtOverviewProvider = FutureProvider.family<DebtOverview, String>((
  ref,
  bookId,
) {
  return ref.watch(debtUseCasesProvider).loadOverview(bookId);
});

/// Операции выбранного контрагента в порядке от новых к старым.
final counterpartyOperationsProvider =
    FutureProvider.family<List<FinanceTransaction>, String>((
      ref,
      counterpartyId,
    ) {
      return ref.watch(debtUseCasesProvider).loadTransactions(counterpartyId);
    });

/// Контрагенты книги, допустимые для операции с долговой ролью [request].
///
/// Список используется полем контрагента формы операции. Он ограничен валютой
/// счета операции: привязка операции другой валюты недопустима (ADR-0009,
/// решение 9.9). Долговая роль категории ограничивает состав дополнительно:
/// возврат долга доступен только контрагенту с остатком своего направления,
/// поэтому возврат денег не привязывается к тому, с кем долга нет
/// (решение 9.15).
final operationCounterpartiesProvider =
    FutureProvider.family<
      List<FinanceCounterparty>,
      ({String bookId, String currencyCode, CategoryDebtRole role})
    >((ref, request) {
      return ref
          .watch(debtUseCasesProvider)
          .listCounterpartiesForOperation(
            bookId: request.bookId,
            currencyCode: request.currencyCode,
            role: request.role,
          );
    });

/// Контрагенты книги по идентификатору вместе с архивными.
///
/// Справочник нужен строке операции: она показывает наименование контрагента, а
/// не его ссылку (ADR-0009, решение 9.4).
final bookCounterpartiesProvider =
    FutureProvider.family<Map<String, FinanceCounterparty>, String>((
      ref,
      bookId,
    ) async {
      final debts = await ref
          .watch(counterpartiesRepositoryProvider)
          .listWithBalances(bookId);
      return {
        for (final debt in debts) debt.counterparty.id: debt.counterparty,
      };
    });

/// Создание, изменение, закрытие и удаление долгов книги.
///
/// После успешной мутации обзор долгов книги и активная книга инвалидируются,
/// поэтому список долгов, архив и итоги пересчитываются без перезапуска
/// приложения.
class DebtsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Создает контрагента вместе с первой операцией долга.
  Future<ValidationResult<FinanceCounterparty>> create(
    CounterpartyInput input,
  ) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(debtUseCasesProvider)
          .createWithFirstTransaction(input);
      switch (result) {
        case Valid(value: final counterparty):
          state = const AsyncData(null);
          _invalidateDebts(counterparty.bookId);
        case Invalid(errors: final errors):
          state = AsyncError(
            FinanceValidationException(errors),
            StackTrace.current,
          );
      }
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Сохраняет наименование и валюту контрагента.
  Future<ValidationResult<FinanceCounterparty>> save(
    FinanceCounterparty existing, {
    required String name,
    required String currencyCode,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(debtUseCasesProvider)
          .update(existing, name: name, currencyCode: currencyCode);
      switch (result) {
        case Valid(value: final counterparty):
          state = const AsyncData(null);
          _invalidateDebts(counterparty.bookId);
        case Invalid(errors: final errors):
          state = AsyncError(
            FinanceValidationException(errors),
            StackTrace.current,
          );
      }
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Закрывает долг вручную: контрагент уходит в архив с сохранением остатка.
  Future<void> close(FinanceCounterparty counterparty) =>
      _mutate(counterparty.bookId, () {
        return ref.read(debtUseCasesProvider).close(counterparty);
      });

  /// Возвращает контрагента в активные.
  Future<void> reopen(FinanceCounterparty counterparty) =>
      _mutate(counterparty.bookId, () {
        return ref.read(debtUseCasesProvider).reopen(counterparty);
      });

  /// Удаляет контрагента без привязанных операций.
  Future<ValidationResult<void>> remove(
    FinanceCounterparty counterparty,
  ) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(debtUseCasesProvider).delete(counterparty);
      switch (result) {
        case Valid():
          state = const AsyncData(null);
          _invalidateDebts(counterparty.bookId);
        case Invalid(errors: final errors):
          state = AsyncError(
            FinanceValidationException(errors),
            StackTrace.current,
          );
      }
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  Future<void> _mutate(String bookId, Future<void> Function() action) async {
    state = const AsyncLoading();
    try {
      await action();
      state = const AsyncData(null);
      _invalidateDebts(bookId);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Инвалидирует представления книги после мутации долга.
  ///
  /// Долговое движение — обычная операция дохода или расхода, которая меняет
  /// остаток счета (ADR-0009, решение 9.4), поэтому вместе с долгами обновляются
  /// представления, читающие операции книги: журнал, остатки счетов и аналитика.
  /// Список совпадает с инвалидацией после мутации операции из журнала
  /// (`finance_transaction_controller`).
  void _invalidateDebts(String bookId) {
    ref.invalidate(debtOverviewProvider(bookId));
    ref.invalidate(counterpartyOperationsProvider);
    ref.invalidate(operationCounterpartiesProvider);
    ref.invalidate(bookCounterpartiesProvider(bookId));
    ref.invalidate(activeBookProvider);
    ref.invalidate(transactionsJournalProvider(bookId));
    ref.invalidate(accountsOverviewProvider(bookId));
    ref.invalidate(bookTransactionsProvider(bookId));
    ref.invalidate(analyticsSliceProvider(bookId));
    ref.invalidate(analyticsYearTrendProvider(bookId));
    ref.invalidate(availableAnalyticsPeriodsProvider(bookId));
    ref.invalidate(categoryOperationsProvider);
  }
}

final debtsControllerProvider = AsyncNotifierProvider<DebtsController, void>(
  DebtsController.new,
);
