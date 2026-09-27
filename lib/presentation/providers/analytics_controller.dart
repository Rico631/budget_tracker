import 'package:budget_tracker/core/di/finance_providers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/analytics_rule.dart';
import 'package:budget_tracker/presentation/providers/transactions_journal_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Выбор параметров раздела «Аналитика»: период, поток и фильтр счетов.
class AnalyticsSelection {
  const AnalyticsSelection({
    required this.period,
    required this.stream,
    this.accountFilter = AnalyticsAccountFilter.all,
  });

  final AnalyticsPeriod period;

  /// Выбранный поток: доходы или расходы; переводы не анализируются.
  final TransactionKind stream;

  /// Фильтр по счетам; пустой набор счетов — значение «Все счета».
  final AnalyticsAccountFilter accountFilter;
}

/// Состояние выбора раздела «Аналитика».
///
/// Начальное состояние — текущий месяц, поток «Расходы» и «Все счета»: раздел
/// открывается за текущий месяц, а вопрос «куда уходят деньги» первичен
/// (ADR-0001, решение 7.3).
///
/// Выбор живет, пока работает приложение, и не пишется в базу: период и фильтры
/// аналитики — состояние представления, а не данные книги. Поэтому возврат из
/// подэкрана и переход между вкладками сохраняют период, поток и фильтр.
class AnalyticsSelectionController extends Notifier<AnalyticsSelection> {
  @override
  AnalyticsSelection build() => AnalyticsSelection(
    period: currentAnalyticsPeriod(AnalyticsPeriodMode.month, DateTime.now()),
    stream: TransactionKind.expense,
  );

  /// Меняет режим периода, сохраняя год выбранного периода.
  ///
  /// В режиме «Месяц» выбирается самый новый доступный месяц этого года, поэтому
  /// после переключения срез содержит операции. Если доступных месяцев нет, режим
  /// остается на текущем месяце: он всегда доступен и всегда дает корректный срез.
  void selectPeriodMode(
    AnalyticsPeriodMode mode, {
    Iterable<AnalyticsPeriod> available = const [],
  }) {
    final current = state.period;
    if (current.mode == mode) {
      return;
    }
    if (mode == AnalyticsPeriodMode.year) {
      state = _next(period: AnalyticsPeriod.year(current.year));
      return;
    }

    AnalyticsPeriod? newestMonth;
    for (final period in available) {
      if (period.mode != AnalyticsPeriodMode.month ||
          period.year != current.year) {
        continue;
      }
      if (newestMonth == null || period.compareTo(newestMonth) > 0) {
        newestMonth = period;
      }
    }
    state = _next(
      period:
          newestMonth ??
          currentAnalyticsPeriod(AnalyticsPeriodMode.month, DateTime.now()),
    );
  }

  /// Выбирает период из списка доступных периодов.
  void selectPeriod(AnalyticsPeriod period) => state = _next(period: period);

  /// Переключает поток: доходы и расходы анализируются отдельно.
  void selectStream(TransactionKind stream) => state = _next(stream: stream);

  /// Устанавливает фильтр по счетам; пустой набор возвращает «Все счета».
  ///
  /// Фильтр не сбрасывает период и поток: смена фильтра сужает тот же срез. Набор
  /// счетов сравнивается по составу, поэтому повторное подтверждение того же выбора
  /// не меняет состояние и не пересчитывает срез.
  void selectAccounts(AnalyticsAccountFilter accountFilter) {
    if (accountFilter == state.accountFilter) {
      return;
    }
    state = AnalyticsSelection(
      period: state.period,
      stream: state.stream,
      accountFilter: accountFilter,
    );
  }

  AnalyticsSelection _next({AnalyticsPeriod? period, TransactionKind? stream}) =>
      AnalyticsSelection(
        period: period ?? state.period,
        stream: stream ?? state.stream,
        accountFilter: state.accountFilter,
      );
}

final analyticsSelectionProvider =
    NotifierProvider<AnalyticsSelectionController, AnalyticsSelection>(
      AnalyticsSelectionController.new,
    );

/// Операции книги от новых к старым: одно чтение на книгу.
///
/// Из этого чтения считаются все формы среза, поэтому смена периода, потока и
/// фильтра счетов пересчитывает срез в памяти и не обращается к базе
/// (`design.md`, решение 6).
final bookTransactionsProvider =
    FutureProvider.family<List<FinanceTransaction>, String>(
      (ref, bookId) =>
          ref.watch(analyticsUseCasesProvider).loadBookTransactions(bookId),
    );

/// Месячный срез: валютные блоки с категорийными суммами выбранного потока.
final analyticsSliceProvider = FutureProvider.family<AnalyticsSlice, String>((
  ref,
  bookId,
) async {
  final selection = ref.watch(analyticsSelectionProvider);
  final transactions = await ref.watch(bookTransactionsProvider(bookId).future);
  final accounts = await ref.watch(bookAccountsProvider(bookId).future);
  final categories = await ref.watch(bookCategoriesProvider(bookId).future);
  final currencies = await ref.watch(currencyCatalogProvider.future);

  return ref
      .read(analyticsUseCasesProvider)
      .loadSlice(
        transactions: transactions,
        accounts: accounts,
        categories: categories,
        period: selection.period,
        stream: selection.stream,
        currencyCatalog: currencies,
        accountFilter: selection.accountFilter,
      );
});

/// Помесячный тренд года выбранного потока: валютные блоки с месячными суммами.
final analyticsYearTrendProvider =
    FutureProvider.family<AnalyticsYearTrend, String>((ref, bookId) async {
      final selection = ref.watch(analyticsSelectionProvider);
      final transactions = await ref.watch(
        bookTransactionsProvider(bookId).future,
      );
      final accounts = await ref.watch(bookAccountsProvider(bookId).future);
      final currencies = await ref.watch(currencyCatalogProvider.future);

      return ref
          .read(analyticsUseCasesProvider)
          .loadYearTrend(
            transactions: transactions,
            accounts: accounts,
            period: AnalyticsPeriod.year(selection.period.year),
            stream: selection.stream,
            currencyCatalog: currencies,
            accountFilter: selection.accountFilter,
          );
    });

/// Доступные периоды среза: периоды с операциями книги плюс текущий месяц и год.
final availableAnalyticsPeriodsProvider =
    FutureProvider.family<List<AnalyticsPeriod>, String>((ref, bookId) async {
      final transactions = await ref.watch(
        bookTransactionsProvider(bookId).future,
      );
      return ref
          .read(analyticsUseCasesProvider)
          .loadAvailablePeriods(transactions: transactions, now: DateTime.now());
    });

/// Запрос состава подэкрана операций категории.
///
/// Ключ включает все параметры среза: одну категорию показывают за один период, в
/// одной валюте и с одним фильтром счетов, и срез заново читается только при
/// открытии подэкрана.
typedef CategoryOperationsRequest = ({
  String bookId,
  String categoryId,
  String currencyCode,
  AnalyticsAccountFilter accountFilter,
  AnalyticsPeriod period,
  TransactionKind stream,
});

/// Операции категории за период в валюте валютного блока: состав подэкрана.
final categoryOperationsProvider =
    FutureProvider.family<List<FinanceTransaction>, CategoryOperationsRequest>(
      (ref, request) => ref
          .watch(analyticsUseCasesProvider)
          .loadCategoryOperations(
            bookId: request.bookId,
            period: request.period,
            stream: request.stream,
            categoryId: request.categoryId,
            currencyCode: request.currencyCode,
            accountFilter: request.accountFilter,
          ),
    );
