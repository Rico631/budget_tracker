import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/domain/commands/finance_account_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/usecases/account_usecases.dart';
import 'package:budget_tracker/presentation/providers/finance_transaction_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Активные счета книги с текущими остатками и итогами по валютам.
final accountsOverviewProvider =
    FutureProvider.family<AccountsOverview, String>((ref, bookId) {
      return ref.watch(accountUseCasesProvider).loadOverview(bookId);
    });

/// Справочник банков: нужен для маркера банка в списке счетов и выбора банка
/// в форме счета.
final banksProvider = FutureProvider<List<FinanceBank>>(
  (ref) => ref.watch(banksRepositoryProvider).list(),
);

/// Есть ли в активной книге хотя бы один активный счет.
///
/// Провайдер определяет, показывать ли предложение добавить первый счет.
final hasActiveAccountsProvider = FutureProvider<bool>((ref) async {
  final book = await ref.watch(activeBookProvider.future);
  if (book == null) {
    return false;
  }
  final overview = await ref.watch(accountsOverviewProvider(book.id).future);
  return overview.hasActiveAccounts;
});

/// Признак пропуска предложения первого счета в текущей сессии.
///
/// Пропуск не пишется в базу и действует до перезапуска приложения, поэтому он
/// не считается ошибкой и не изменяет данные первого запуска.
class FirstAccountPromptDismissal extends Notifier<bool> {
  @override
  bool build() => false;

  /// Запоминает пропуск предложения в текущей сессии.
  void dismiss() => state = true;
}

final firstAccountPromptDismissedProvider =
    NotifierProvider<FirstAccountPromptDismissal, bool>(
      FirstAccountPromptDismissal.new,
    );

/// Создание, изменение, архивирование и удаление счетов.
///
/// После успешной мутации обзор книги инвалидируется, поэтому список счетов,
/// итоги по валютам и признак наличия активных счетов пересчитываются.
class AccountsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Создает счет при `existing == null` или сохраняет изменения счета.
  Future<ValidationResult<FinanceAccount>> save(
    FinanceAccountInput input, {
    FinanceAccount? existing,
  }) async {
    state = const AsyncLoading();
    try {
      final useCases = ref.read(accountUseCasesProvider);
      final result = existing == null
          ? await useCases.create(input)
          : await useCases.update(existing, input);
      switch (result) {
        case Valid(value: final account):
          state = const AsyncData(null);
          _invalidateOverview(account.bookId);
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

  /// Удаляет счет книги или сообщает, что требуется архивирование.
  Future<AccountRemovalOutcome> remove(String bookId, String accountId) async {
    state = const AsyncLoading();
    try {
      final outcome = await ref
          .read(accountUseCasesProvider)
          .deleteOrArchive(accountId);
      state = const AsyncData(null);
      if (outcome != AccountRemovalOutcome.archivingRequired) {
        _invalidateOverview(bookId);
      }
      return outcome;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Архивирует счет, сохраняя его операции в истории книги.
  Future<void> archive(String bookId, String accountId) async {
    state = const AsyncLoading();
    try {
      await ref.read(accountUseCasesProvider).archive(accountId);
      state = const AsyncData(null);
      _invalidateOverview(bookId);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void _invalidateOverview(String bookId) {
    ref.invalidate(accountsOverviewProvider(bookId));
    ref.invalidate(hasActiveAccountsProvider);
  }
}

final accountsControllerProvider =
    AsyncNotifierProvider<AccountsController, void>(AccountsController.new);