import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/providers/accounts_controller.dart';
import 'package:budget_tracker/presentation/providers/finance_transaction_controller.dart';
import 'package:budget_tracker/presentation/providers/transactions_journal_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Категории книги вместе с архивными записями.
///
/// Справочник категорий читается по книге и так же, как справочник подписей в
/// истории (`bookCategoriesProvider`): архивация выведена из модели
/// справочников (ADR-0004, решение 4.6), но ранее записанные данные остаются
/// видимыми и доступными для переименования и удаления.
final bookCategoriesAllProvider =
    FutureProvider.family<List<FinanceCategory>, String>((ref, bookId) {
      return ref
          .watch(categoriesRepositoryProvider)
          .listByBook(bookId, includeArchived: true);
    });

/// Создание, переименование и удаление категорий книги.
///
/// После успешной мутации справочник категорий и подписи категорий в истории
/// инвалидируются: переименование меняет подписи операций, а удаление переносит
/// их в базовую категорию (ADR-0004, решения 4.1 и 4.2). Возвращаемый
/// `ValidationResult` позволяет форме показать ошибку домена, не заглядывая в
/// состояние провайдера.
class CategoryController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Создает категорию с выбранным типом.
  Future<ValidationResult<FinanceCategory>> create({
    required String bookId,
    required String name,
    required TransactionKind kind,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(categoryUseCasesProvider)
          .create(bookId: bookId, name: name, kind: kind);
      _applyResult(result, bookId);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Переименовывает категорию, сохраняя ее тип.
  ///
  /// Имя метода не `update`: у `AsyncNotifier` из Riverpod уже есть собственный
  /// метод `update`, поэтому одноименный метод мутации объявить нельзя.
  Future<ValidationResult<FinanceCategory>> rename(
    FinanceCategory category,
    String name,
  ) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(categoryUseCasesProvider)
          .update(category, name: name, kind: category.kind);
      _applyResult(result, category.bookId);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Удаляет категорию, перенося ее операции в базовую категорию того же типа.
  Future<ValidationResult<void>> delete(FinanceCategory category) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(categoryUseCasesProvider)
          .delete(category);
      _applyResult(result, category.bookId);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Гарантирует наличие базовой категории каждого типа в книге.
  ///
  /// Метод идемпотентен и вызывается при открытии управления категориями
  /// (ADR-0004, решение 4.3).
  Future<List<FinanceCategory>> ensureFallbackCategories({
    required String bookId,
    required String languageCode,
  }) async {
    state = const AsyncLoading();
    try {
      final created = await ref
          .read(categoryUseCasesProvider)
          .ensureFallbackCategories(bookId: bookId, languageCode: languageCode);
      state = const AsyncData(null);
      if (created.isNotEmpty) {
        _invalidateCategories(bookId);
      }
      return created;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void _applyResult<T>(ValidationResult<T> result, String bookId) {
    switch (result) {
      case Valid():
        state = const AsyncData(null);
        _invalidateCategories(bookId);
      case Invalid(errors: final errors):
        state = AsyncError(
          FinanceValidationException(errors),
          StackTrace.current,
        );
    }
  }

  void _invalidateCategories(String bookId) {
    ref.invalidate(bookCategoriesAllProvider(bookId));
    ref.invalidate(bookCategoriesProvider(bookId));
    ref.invalidate(activeBookCategoriesProvider(bookId));
    ref.invalidate(transactionsJournalProvider(bookId));
  }
}

final categoryControllerProvider =
    AsyncNotifierProvider<CategoryController, void>(CategoryController.new);

/// Создание, переименование и удаление банков общего справочника.
///
/// После успешной мутации справочник банков и обзор счетов инвалидируются:
/// переименование меняет подпись банка в строках счетов, а удаление очищает у
/// счетов ссылку на банк, не изменяя остатки и операции (ADR-0004, решения 4.7
/// и 4.8).
class BankController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Создает пользовательский банк.
  Future<ValidationResult<FinanceBank>> create({
    required String name,
    String? colorHex,
    String? bookId,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(bankUseCasesProvider)
          .create(name: name, colorHex: colorHex);
      _applyResult(result, bookId);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Сохраняет наименование и цвет банка, включая предустановленный.
  ///
  /// Имя метода не `update`: у `AsyncNotifier` из Riverpod уже есть собственный
  /// метод `update`, поэтому одноименный метод мутации объявить нельзя.
  Future<ValidationResult<FinanceBank>> rename({
    required FinanceBank bank,
    required String name,
    required String? colorHex,
    String? bookId,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref
          .read(bankUseCasesProvider)
          .update(bank, name: name, colorHex: colorHex);
      _applyResult(result, bookId);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Удаляет банк, очищая ссылку на него у связанных счетов.
  Future<ValidationResult<void>> delete({
    required FinanceBank bank,
    String? bookId,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(bankUseCasesProvider).delete(bank);
      _applyResult(result, bookId);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  void _applyResult<T>(ValidationResult<T> result, String? bookId) {
    switch (result) {
      case Valid():
        state = const AsyncData(null);
        _invalidateBanks(bookId);
      case Invalid(errors: final errors):
        state = AsyncError(
          FinanceValidationException(errors),
          StackTrace.current,
        );
    }
  }

  void _invalidateBanks(String? bookId) {
    ref.invalidate(banksProvider);
    if (bookId != null) {
      ref.invalidate(accountsOverviewProvider(bookId));
    }
    ref.invalidate(hasActiveAccountsProvider);
  }
}

final bankControllerProvider =
    AsyncNotifierProvider<BankController, void>(BankController.new);
