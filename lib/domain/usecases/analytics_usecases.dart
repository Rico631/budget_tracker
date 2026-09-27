import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/analytics_rule.dart';

/// Домен: данные книги для аналитики и формы среза.
///
/// Правила сумм живут в `lib/domain/services/analytics_rule.dart` и проверяются
/// без базы (`test/unit/services/analytics_rule_test.dart`), а чтение — в
/// репозиториях: use case связывает их и остается точкой, через которую раздел
/// «Аналитика» получает данные.
///
/// Операции книги читаются один раз на книгу, а формы среза принимают уже
/// прочитанные данные: смена периода, потока и фильтра счета пересчитывает срез в
/// памяти и не обращается к базе (`design.md`, решение 6). Счета читаются вместе с
/// архивными, потому что операции архивного счета входят в срез (ADR-0004,
/// решение 4.4), а валюта операции — это валюта ее счета (ADR-0001, решение 2.1).
class AnalyticsUseCases {
  AnalyticsUseCases({required this.accounts, required this.transactions});

  final AccountsRepository accounts;
  final TransactionsRepository transactions;

  /// Операции книги от новых к старым: одно чтение на книгу.
  Future<List<FinanceTransaction>> loadBookTransactions(String bookId) =>
      transactions.listByBook(bookId);

  /// Счета книги вместе с архивными: операции архивного счета входят в срез в
  /// валюте этого счета.
  Future<List<FinanceAccount>> loadBookAccounts(String bookId) =>
      accounts.listByBook(bookId, includeArchived: true);

  /// Срез за период по данным книги, прочитанным один раз.
  AnalyticsSlice loadSlice({
    required Iterable<FinanceTransaction> transactions,
    required List<FinanceAccount> accounts,
    required List<FinanceCategory> categories,
    required AnalyticsPeriod period,
    required TransactionKind stream,
    Map<String, FinanceCurrency> currencyCatalog = const {},
    AnalyticsAccountFilter accountFilter = AnalyticsAccountFilter.all,
  }) => buildAnalyticsSlice(
    transactions: transactions,
    accounts: accounts,
    categories: categories,
    period: period,
    stream: stream,
    currencyCatalog: currencyCatalog,
    accountFilter: accountFilter,
  );

  /// Помесячный тренд года по данным книги, прочитанным один раз.
  AnalyticsYearTrend loadYearTrend({
    required Iterable<FinanceTransaction> transactions,
    required List<FinanceAccount> accounts,
    required AnalyticsPeriod period,
    required TransactionKind stream,
    Map<String, FinanceCurrency> currencyCatalog = const {},
    AnalyticsAccountFilter accountFilter = AnalyticsAccountFilter.all,
  }) => buildAnalyticsYearTrend(
    transactions: transactions,
    accounts: accounts,
    period: period,
    stream: stream,
    currencyCatalog: currencyCatalog,
    accountFilter: accountFilter,
  );

  /// Доступные периоды среза: периоды с операциями книги плюс текущий месяц и год.
  List<AnalyticsPeriod> loadAvailablePeriods({
    required Iterable<FinanceTransaction> transactions,
    required DateTime now,
  }) => availableAnalyticsPeriods(transactions, now);

  /// Операции категории за период в валюте валютного блока: состав подэкрана.
  ///
  /// Подэкран — отдельный маршрут со своим набором параметров (категория, период,
  /// валюта блока), поэтому его состав читается заново, а не пересчитывается из
  /// данных раздела.
  Future<List<FinanceTransaction>> loadCategoryOperations({
    required String bookId,
    required AnalyticsPeriod period,
    required TransactionKind stream,
    required String categoryId,
    required String currencyCode,
    AnalyticsAccountFilter accountFilter = AnalyticsAccountFilter.all,
  }) async {
    final bookTransactions = await loadBookTransactions(bookId);
    final bookAccounts = await loadBookAccounts(bookId);
    return categoryOperations(
      transactions: bookTransactions,
      accounts: bookAccounts,
      period: period,
      stream: stream,
      categoryId: categoryId,
      currencyCode: currencyCode,
      accountFilter: accountFilter,
    );
  }
}
