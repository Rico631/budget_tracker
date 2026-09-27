import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/providers/accounts_controller.dart';
import 'package:budget_tracker/presentation/providers/transactions_journal_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinanceValidationException implements Exception {
  FinanceValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => errors.join(' ');
}

/// Создание, изменение и удаление операций книги.
///
/// После успешной мутации журнал книги, обзор счетов и признак наличия активных
/// счетов инвалидируются, поэтому история и остатки пересчитываются без
/// перезапуска приложения (ADR 3.5). Возвращаемый `ValidationResult` позволяет
/// форме показать ошибки валидации, не заглядывая в состояние провайдера.
class FinanceTransactionController extends AsyncNotifier<FinanceTransaction?> {
  @override
  Future<FinanceTransaction?> build() async => null;

  /// Создает операцию при `existing == null` или сохраняет изменения операции.
  ///
  /// Тип существующей операции неизменяем: смену типа отклоняет домен, а форма
  /// показывает тип только для чтения.
  ///
  /// Имя метода повторяет образец `AccountsController.save(input, existing: ...)`:
  /// у `AsyncNotifier` из Riverpod уже есть собственный метод `update`, поэтому
  /// одноименный метод мутации объявить нельзя.
  Future<ValidationResult<FinanceTransaction>> save(
    FinanceTransactionInput input, {
    required DateTime occurredAt,
    FinanceTransaction? existing,
  }) async {
    state = const AsyncLoading();
    try {
      final useCases = ref.read(financeTransactionUseCasesProvider);
      final result = existing == null
          ? await useCases.create(input, occurredAt: occurredAt)
          : await useCases.update(existing, input, occurredAt: occurredAt);
      _applyResult(result, input.bookId);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Безвозвратно удаляет операцию книги.
  Future<void> delete(String bookId, String transactionId) async {
    state = const AsyncLoading();
    try {
      await ref.read(financeTransactionUseCasesProvider).delete(transactionId);
      state = const AsyncData(null);
      _invalidateBookData(bookId);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void _applyResult(
    ValidationResult<FinanceTransaction> result,
    String bookId,
  ) {
    switch (result) {
      case Valid(value: final value):
        state = AsyncData(value);
        _invalidateBookData(bookId);
      case Invalid(errors: final errors):
        state = AsyncError(
          FinanceValidationException(errors),
          StackTrace.current,
        );
    }
  }

  void _invalidateBookData(String bookId) {
    ref.invalidate(transactionsJournalProvider(bookId));
    ref.invalidate(accountsOverviewProvider(bookId));
    ref.invalidate(hasActiveAccountsProvider);
  }
}

final financeTransactionControllerProvider =
    AsyncNotifierProvider<FinanceTransactionController, FinanceTransaction?>(
      FinanceTransactionController.new,
    );
