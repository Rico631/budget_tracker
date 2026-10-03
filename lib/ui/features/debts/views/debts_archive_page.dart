import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/core/utils/money_formatter.dart';
import 'package:budget_tracker/ui/features/debts/view_models/debts_controller.dart';
import 'package:budget_tracker/ui/features/debts/views/counterparty_operations_page.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/transactions_journal_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Архив закрытых долгов книги.
///
/// Контрагент попадает в архив при нулевом остатке или ручном закрытии, а его
/// остаток сохраняется и показывается здесь (ADR-0009, решение 9.10). Из архива
/// доступны возврат контрагента в активные, открытие его операций и
/// безвозвратное удаление контрагента без привязанных операций.
class DebtsArchivePage extends ConsumerWidget {
  const DebtsArchivePage({super.key, required this.bookId});

  final String bookId;

  /// Открывает архив долгов и возвращает `true`, если данные изменились.
  static Future<bool?> open(BuildContext context, {required String bookId}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DebtsArchivePage(bookId: bookId)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.debtsArchiveTitle)),
      body: ref
          .watch(debtOverviewProvider(bookId))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  localizations.debtsLoadErrorMessage,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (overview) => overview.archived.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        localizations.debtsArchiveEmptyMessage,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _ArchiveList(bookId: bookId, debts: overview.archived),
          ),
    );
  }
}

class _ArchiveList extends ConsumerWidget {
  const _ArchiveList({required this.bookId, required this.debts});

  final String bookId;
  final List<CounterpartyDebt> debts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currencies = ref.watch(currencyCatalogProvider).value ?? const {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final debt in debts)
          _ArchiveTile(
            debt: debt,
            currencySymbol: currencies[debt.counterparty.currencyCode]?.symbol,
            onOpenOperations: () => CounterpartyOperationsPage.open(
              context,
              counterparty: debt.counterparty,
            ),
            onReopen: () => _reopen(context, ref, debt.counterparty),
            onDelete: () => _delete(context, ref, debt.counterparty),
          ),
      ],
    );
  }

  Future<void> _reopen(
    BuildContext context,
    WidgetRef ref,
    FinanceCounterparty counterparty,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final failureMessage = AppLocalizations.of(
      context,
    ).debtsMutationFailureMessage;
    final message = AppLocalizations.of(context).debtsSavedMessage;

    try {
      await ref.read(debtsControllerProvider.notifier).reopen(counterparty);
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    FinanceCounterparty counterparty,
  ) async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final operations = await ref.read(
      counterpartyOperationsProvider(counterparty.id).future,
    );

    if (operations.isNotEmpty) {
      // Контрагент с историей не удаляется безвозвратно: приложение предлагает
      // закрыть долг (ADR-0009, решение 9.10).
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.debtsCloseOfferMessage)),
      );
      return;
    }
    if (!context.mounted) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('debtsDeleteDialog'),
        title: Text(localizations.debtsDeleteDialogTitle),
        content: Text(localizations.debtsDeleteDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.debtsDialogCancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.debtsDeleteDialogConfirmAction),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    await ref.read(debtsControllerProvider.notifier).remove(counterparty);
    messenger.showSnackBar(
      SnackBar(content: Text(localizations.debtsDeletedMessage)),
    );
  }
}

class _ArchiveTile extends StatelessWidget {
  const _ArchiveTile({
    required this.debt,
    required this.currencySymbol,
    required this.onOpenOperations,
    required this.onReopen,
    required this.onDelete,
  });

  final CounterpartyDebt debt;
  final String? currencySymbol;
  final VoidCallback onOpenOperations;
  final VoidCallback onReopen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final counterparty = debt.counterparty;
    final amount = formatMoneyMinor(
      context,
      debt.balanceMinor,
      currencyCode: counterparty.currencyCode,
      currencySymbol: currencySymbol,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onOpenOperations,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                counterparty.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                amount,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton(
                    key: Key('debtsReopenAction-${counterparty.id}'),
                    onPressed: onReopen,
                    child: Text(localizations.debtsReopenAction),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    key: Key('debtsDeleteAction-${counterparty.id}'),
                    onPressed: onDelete,
                    child: Text(localizations.debtsDeleteAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
