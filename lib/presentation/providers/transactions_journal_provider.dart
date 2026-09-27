import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Журнал операций книги.
///
/// Журнал — это чтение по книге, поэтому он живет рядом с контроллером мутаций
/// (`finance_transaction_controller.dart`), а не внутри него. Провайдер
/// инвалидируется после каждой успешной мутации операции.
final transactionsJournalProvider =
    FutureProvider.family<TransactionsJournal, String>((ref, bookId) {
      return ref.watch(financeTransactionUseCasesProvider).loadJournal(bookId);
    });

/// Счета книги вместе с архивными.
///
/// История показывает операции архивированного счета с названием этого счета
/// (ADR 4.4), поэтому справочник читается вместе с архивными записями.
final bookAccountsProvider =
    FutureProvider.family<List<FinanceAccount>, String>((ref, bookId) {
      return ref
          .watch(accountsRepositoryProvider)
          .listByBook(bookId, includeArchived: true);
    });

/// Категории книги вместе с архивными: нужны для подписи категории в истории.
final bookCategoriesProvider =
    FutureProvider.family<List<FinanceCategory>, String>((ref, bookId) {
      return ref
          .watch(categoriesRepositoryProvider)
          .listByBook(bookId, includeArchived: true);
    });

/// Активные счета книги: выбор счета операции и счета-получателя в форме.
///
/// В архивный счет новую операцию не вводят, поэтому архивные счета в выбор не
/// попадают.
final activeBookAccountsProvider =
    FutureProvider.family<List<FinanceAccount>, String>((ref, bookId) {
      return ref.watch(accountsRepositoryProvider).listByBook(bookId);
    });

/// Активные категории книги: выбор категории дохода или расхода в форме.
final activeBookCategoriesProvider =
    FutureProvider.family<List<FinanceCategory>, String>((ref, bookId) {
      return ref.watch(categoriesRepositoryProvider).listByBook(bookId);
    });

/// Справочник валют по коду: символы валютных единиц в суммах истории.
///
/// Справочник доступен только для чтения и используется там, где у счета нет
/// готовой позиции справочника (обзор счетов получает ее вместе с группой
/// валюты).
final currencyCatalogProvider =
    FutureProvider<Map<String, FinanceCurrency>>((ref) async {
      final catalog = await ref.watch(currenciesRepositoryProvider).list();
      return {for (final currency in catalog) currency.code: currency};
    });
