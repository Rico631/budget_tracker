import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/account_selection_providers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/transactions_journal_rule.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/analytics_labels.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/analytics_status_views.dart';
import 'package:budget_tracker/ui/features/debts/view_models/debts_controller.dart';
import 'package:budget_tracker/ui/features/transactions/widgets/transaction_slidable.dart';
import 'package:budget_tracker/ui/features/analytics/view_models/analytics_controller.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/transactions_journal_provider.dart';
import 'package:budget_tracker/ui/core/utils/money_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Подэкран операций категории за выбранный период.
///
/// Подэкран открывается нажатием на категорию диаграммы и показывает операции
/// категории в валюте валютного блока: операции других категорий, периодов и валют
/// в него не попадают. Строки сгруппированы по дням от новых к старым, поэтому
/// состав подэкрана читается как журнал категории, а действия над операцией те же,
/// что в истории книги (ADR-0003, решение 3.2).
///
/// Подэкран работает с уже введенными операциями: действий добавления операции и
/// счета здесь нет, а изменение и удаление операции оставляют пользователя в
/// подэкране с сообщением о результате (ADR-0003, решение 3.5).
class CategoryOperationsPage extends ConsumerWidget {
  const CategoryOperationsPage({
    super.key,
    required this.bookId,
    required this.category,
    required this.currencyCode,
    required this.period,
    required this.stream,
    this.currencySymbol,
    this.accountFilter = AnalyticsAccountFilter.all,
  });

  final String bookId;

  /// Категория, по которой открыт подэкран.
  final FinanceCategory category;

  /// Валюта валютного блока, из которого открыта категория.
  final String currencyCode;

  /// Символ валютной единицы блока, если он есть в справочнике.
  final String? currencySymbol;

  /// Период среза: при возврате период, поток и фильтр раздела сохраняются.
  final AnalyticsPeriod period;

  final TransactionKind stream;

  /// Фильтр по счетам раздела; пустой набор — «Все счета».
  final AnalyticsAccountFilter accountFilter;

  /// Открывает подэкран операций категории.
  static Future<void> open(
    BuildContext context, {
    required String bookId,
    required FinanceCategory category,
    required String currencyCode,
    required AnalyticsPeriod period,
    required TransactionKind stream,
    String? currencySymbol,
    AnalyticsAccountFilter accountFilter = AnalyticsAccountFilter.all,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => CategoryOperationsPage(
          bookId: bookId,
          category: category,
          currencyCode: currencyCode,
          currencySymbol: currencySymbol,
          period: period,
          stream: stream,
          accountFilter: accountFilter,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final request = (
      bookId: bookId,
      categoryId: category.id,
      currencyCode: currencyCode,
      accountFilter: accountFilter,
      period: period,
      stream: stream,
    );

    return Scaffold(
      appBar: AppBar(title: Text(localizations.categoryOperationsTitle)),
      body: ref
          .watch(categoryOperationsProvider(request))
          .when(
            loading: () => const AnalyticsLoadingView(),
            error: (error, stackTrace) => AnalyticsErrorView(
              message: localizations.analyticsLoadErrorMessage,
              onRetry: () =>
                  ref.invalidate(categoryOperationsProvider(request)),
            ),
            data: (operations) => operations.isEmpty
                ? AnalyticsEmptyView(
                    message: localizations.categoryOperationsEmptyMessage(
                      analyticsPeriodLabel(localizations, period),
                    ),
                  )
                : _CategoryOperationsView(
                    bookId: bookId,
                    category: category,
                    currencyCode: currencyCode,
                    currencySymbol: currencySymbol,
                    period: period,
                    operations: operations,
                  ),
          ),
    );
  }
}

/// Содержимое подэкрана: итог категории и операции по дням.
class _CategoryOperationsView extends ConsumerWidget {
  const _CategoryOperationsView({
    required this.bookId,
    required this.category,
    required this.currencyCode,
    required this.currencySymbol,
    required this.period,
    required this.operations,
  });

  final String bookId;
  final FinanceCategory category;
  final String currencyCode;
  final String? currencySymbol;
  final AnalyticsPeriod period;
  final List<FinanceTransaction> operations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accounts =
        ref.watch(bookAccountsProvider(bookId)).value ??
        const <FinanceAccount>[];
    final currencies = ref.watch(currencyCatalogProvider).value ?? const {};
    final counterparties =
        ref.watch(bookCounterpartiesProvider(bookId)).value ?? const {};
    final accountsById = {for (final account in accounts) account.id: account};
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dayFormat = DateFormat.yMMMMEEEEd(localeTag);
    final journal = groupJournalByDay(operations);
    // Итог считается по показанным операциям, поэтому он равен сумме полосы
    // диаграммы, из которой открыт подэкран.
    final totalMinor = operations.fold<int>(
      0,
      (total, operation) => total + operation.amountMinor,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(category.name, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          analyticsPeriodLabel(localizations, period),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          '${localizations.categoryOperationsTotalLabel}: '
          '${formatMoneyMinor(context, totalMinor, currencyCode: currencyCode, currencySymbol: currencySymbol)}',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final group in journal.days) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
            child: Text(
              dayFormat.format(group.day),
              style: theme.textTheme.titleSmall,
            ),
          ),
          for (final operation in group.transactions)
            TransactionSlidable(
              bookId: bookId,
              transaction: operation,
              account: accountsById[operation.accountId],
              category: category,
              counterparty: counterparties[operation.counterpartyId],
              currencySymbol:
                  currencies[accountsById[operation.accountId]?.currencyCode]
                      ?.symbol,
            ),
        ],
      ],
    );
  }
}
