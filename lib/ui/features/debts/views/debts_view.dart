import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/core/utils/money_formatter.dart';
import 'package:budget_tracker/ui/features/debts/view_models/debts_controller.dart';
import 'package:budget_tracker/ui/features/debts/views/counterparty_form_page.dart';
import 'package:budget_tracker/ui/features/debts/views/counterparty_operations_page.dart';
import 'package:budget_tracker/ui/features/debts/views/debts_archive_page.dart';
import 'package:budget_tracker/ui/features/transactions/views/transactions_page.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/transactions_journal_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ действия открытия архива долгов.
const Key debtsArchiveActionKey = Key('debtsArchiveAction');

/// Ключ действия создания контрагента в пустом состоянии.
const Key debtsEmptyActionKey = Key('debtsEmptyAction');

/// Ключ действия повторной загрузки долгов.
const Key debtsRetryActionKey = Key('debtsRetryAction');

/// Часть «Долги» раздела «Счета»: активные контрагенты по знаку остатка.
///
/// Контрагенты разделены на «Мне должны» (положительный остаток) и «Я должен»
/// (отрицательный), а итоги показываются для каждой части и каждой валюты
/// отдельно: суммы разных валют не складываются и не конвертируются
/// (ADR-0009, решение 9.3).
class DebtsView extends ConsumerWidget {
  const DebtsView({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return ref
        .watch(debtOverviewProvider(bookId))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _DebtsErrorView(
            message: localizations.debtsLoadErrorMessage,
            onRetry: () => ref.invalidate(debtOverviewProvider(bookId)),
          ),
          data: (overview) => Column(
            children: [
              // Доступ к архиву есть на части «Долги» всегда: архив может
              // содержать закрытые долги и при отсутствии активных
              // (ADR-0009, решение 9.12).
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton.icon(
                    key: debtsArchiveActionKey,
                    onPressed: () =>
                        DebtsArchivePage.open(context, bookId: bookId),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(localizations.debtsArchiveAction),
                  ),
                ),
              ),
              Expanded(
                child: overview.hasNoActiveDebts
                    ? _DebtsEmptyView(bookId: bookId)
                    : _DebtsContentView(bookId: bookId, overview: overview),
              ),
            ],
          ),
        );
  }
}

class _DebtsContentView extends ConsumerWidget {
  const _DebtsContentView({required this.bookId, required this.overview});

  final String bookId;
  final DebtOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return ListView(
      // Нижний отступ с запасом под крупную кнопку добавления операции, чтобы
      // последняя строка не перекрывалась кнопкой.
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16 + transactionsListBottomPadding,
      ),
      children: [
        _DebtPartView(
          bookId: bookId,
          title: localizations.debtsReceivableTitle,
          debts: overview.receivable,
          totals: _totalsFor(overview, receivable: true),
          receivable: true,
        ),
        const SizedBox(height: 16),
        _DebtPartView(
          bookId: bookId,
          title: localizations.debtsPayableTitle,
          debts: overview.payable,
          totals: _totalsFor(overview, receivable: false),
          receivable: false,
        ),
      ],
    );
  }

  /// Итоги одной части: только валюты с ненулевой суммой этой части.
  ///
  /// Положительные и отрицательные остатки одной валюты не сворачиваются в одно
  /// число, поэтому каждая часть показывает собственную сумму (ADR-0009,
  /// решение 9.3).
  List<CurrencyDebtTotals> _totalsFor(
    DebtOverview overview, {
    required bool receivable,
  }) => [
    for (final total in overview.totalsByCurrency)
      if (receivable ? total.receivableMinor != 0 : total.payableMinor != 0)
        total,
  ];
}

class _DebtPartView extends ConsumerWidget {
  const _DebtPartView({
    required this.bookId,
    required this.title,
    required this.debts,
    required this.totals,
    required this.receivable,
  });

  final String bookId;
  final String title;
  final List<CounterpartyDebt> debts;
  final List<CurrencyDebtTotals> totals;

  /// Показывать ли положительные итоги валюты; иначе показываются отрицательные.
  final bool receivable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (debts.isEmpty && totals.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);
    final currencies = ref.watch(currencyCatalogProvider).value ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        for (final total in totals)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '${localizations.debtsTotalLabel} ${total.currencyCode}: '
              '${formatMoneyMinor(context, receivable ? total.receivableMinor : total.payableMinor, currencyCode: total.currencyCode, currencySymbol: currencies[total.currencyCode]?.symbol)}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        const SizedBox(height: 4),
        for (final debt in debts)
          _DebtTile(
            debt: debt,
            currencySymbol: currencies[debt.counterparty.currencyCode]?.symbol,
            onTap: () => CounterpartyOperationsPage.open(
              context,
              counterparty: debt.counterparty,
            ),
          ),
      ],
    );
  }
}

/// Действия меню строки долга: изменение данных контрагента и закрытие долга.
enum _DebtAction { edit, close }

class _DebtTile extends ConsumerWidget {
  const _DebtTile({
    required this.debt,
    required this.currencySymbol,
    required this.onTap,
  });

  final CounterpartyDebt debt;
  final String? currencySymbol;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final counterparty = debt.counterparty;
    // Остаток показывается со знаком: положительный означает «мне должны»,
    // отрицательный — «я должен» (ADR-0009, решение 9.3).
    final amount = formatMoneyMinor(
      context,
      debt.balanceMinor,
      currencyCode: counterparty.currencyCode,
      currencySymbol: currencySymbol,
    );
    final signed = debt.balanceMinor > 0 ? '+$amount' : amount;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(
        counterparty.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.titleMedium,
      ),
      subtitle: Text(
        counterparty.currencyCode,
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              signed,
              maxLines: 1,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          PopupMenuButton<_DebtAction>(
            key: Key('debtsTileMenu-${counterparty.id}'),
            tooltip: localizations.debtsActionsTooltip,
            onSelected: (action) => switch (action) {
              _DebtAction.edit => _edit(context),
              _DebtAction.close => _confirmClose(context, ref),
            },
            itemBuilder: (menuContext) => [
              PopupMenuItem(
                value: _DebtAction.edit,
                key: Key('debtsEditAction-${counterparty.id}'),
                child: Text(localizations.debtsEditAction),
              ),
              PopupMenuItem(
                value: _DebtAction.close,
                key: Key('debtsCloseAction-${counterparty.id}'),
                child: Text(localizations.debtsCloseAction),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Открывает форму контрагента: наименование и валюту можно изменить, а
  /// остаток долга остается привязанным к операциям (ADR-0009, решение 9.8).
  Future<void> _edit(BuildContext context) async {
    await CounterpartyFormPage.open(context, counterparty: debt.counterparty);
  }

  /// Закрывает долг вручную при любом остатке: контрагент уходит в архив
  /// с сохранением остатка (ADR-0009, решение 9.10).
  Future<void> _confirmClose(BuildContext context, WidgetRef ref) async {
    final localizations = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('debtsCloseDialog'),
        title: Text(localizations.debtsCloseDialogTitle),
        content: Text(localizations.debtsCloseDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.debtsDialogCancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.debtsCloseAction),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await ref.read(debtsControllerProvider.notifier).close(debt.counterparty);
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.debtsSavedMessage)),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(localizations.debtsMutationFailureMessage)),
      );
    }
  }
}

class _DebtsEmptyView extends ConsumerWidget {
  const _DebtsEmptyView({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.handshake_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.debtsEmptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              localizations.debtsEmptyMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: debtsEmptyActionKey,
              onPressed: () =>
                  CounterpartyFormPage.open(context, bookId: bookId),
              child: Text(localizations.debtsEmptyAction),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtsErrorView extends StatelessWidget {
  const _DebtsErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: debtsRetryActionKey,
              onPressed: onRetry,
              child: Text(localizations.debtsRetryAction),
            ),
          ],
        ),
      ),
    );
  }
}
