import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FinanceValidationException implements Exception {
  FinanceValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => errors.join(' ');
}

class FinanceTransactionController extends AsyncNotifier<FinanceTransaction?> {
  @override
  Future<FinanceTransaction?> build() async => null;

  Future<void> save(
    FinanceTransactionInput input, {
    required DateTime occurredAt,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(financeTransactionUseCasesProvider)
          .create(input, occurredAt: occurredAt);
      state = switch (result) {
        Valid(value: final value) => AsyncData(value),
        Invalid(errors: final errors) => AsyncError(
          FinanceValidationException(errors),
          StackTrace.current,
        ),
      };
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

final financeTransactionControllerProvider =
    AsyncNotifierProvider<FinanceTransactionController, FinanceTransaction?>(
      FinanceTransactionController.new,
    );
