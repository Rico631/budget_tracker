import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/transactions_journal_rule.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/account_selection_providers.dart';
import 'package:budget_tracker/ui/features/debts/view_models/debts_controller.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/transactions_journal_provider.dart';
import 'package:budget_tracker/ui/features/transactions/widgets/transaction_slidable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Подэкран операций контрагента.
///
/// Список показывает привязанные операции от новых к старым с датой, суммой и
/// знаком, доступен из списка долгов и из архива, а действий добавления не
/// содержит: он показывает уже введенные операции и их изменение, как подэкран
/// операций категории в аналитике (ADR-0009, решение 9.12).
class CounterpartyOperationsPage extends ConsumerWidget {
  const CounterpartyOperationsPage({super.key, required this.counterparty});

  final FinanceCounterparty counterparty;

  /// Открывает операции контрагента и возвращает `true`, если данные изменились.
  static Future<bool?> open(
    BuildContext context, {
    required FinanceCounterparty counterparty,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CounterpartyOperationsPage(counterparty: counterparty),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${localizations.debtsOperationsTitle}: ${counterparty.name}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ref
          .watch(counterpartyOperationsProvider(counterparty.id))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  localizations.debtsOperationsLoadErrorMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (operations) => operations.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        localizations.debtsOperationsEmptyMessage,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _OperationsList(
                    bookId: counterparty.bookId,
                    operations: operations,
                  ),
          ),
    );
  }
}

class _OperationsList extends ConsumerWidget {
  const _OperationsList({required this.bookId, required this.operations});

  final String bookId;
  final List<FinanceTransaction> operations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts =
        ref.watch(bookAccountsProvider(bookId)).value ??
        const <FinanceAccount>[];
    final categories =
        ref.watch(bookCategoriesProvider(bookId)).value ??
        const <FinanceCategory>[];
    final currencies = ref.watch(currencyCatalogProvider).value ?? const {};
    final counterparties =
        ref.watch(bookCounterpartiesProvider(bookId)).value ?? const {};
    final accountsById = {for (final account in accounts) account.id: account};
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final theme = Theme.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dayFormat = DateFormat.yMMMMEEEEd(localeTag);
    final journal = groupJournalByDay(operations);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final group in journal.days) ...[
          // Дата показывается заголовком дня: строка операции дату не несет, а
          // платежи по долгу читаются по дням, как в истории книги
          // (ADR-0009, решение 9.12).
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
              toAccount: accountsById[operation.toAccountId],
              category: categoriesById[operation.categoryId],
              counterparty: counterparties[operation.counterpartyId],
              currencySymbol:
                  currencies[accountsById[operation.accountId]?.currencyCode]
                      ?.symbol,
              toCurrencySymbol:
                  currencies[accountsById[operation.toAccountId]?.currencyCode]
                      ?.symbol,
            ),
        ],
      ],
    );
  }
}
