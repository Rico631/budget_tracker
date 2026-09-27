import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/features/transactions/transaction_form_page.dart';
import 'package:budget_tracker/presentation/features/transactions/widgets/transaction_tile.dart';
import 'package:budget_tracker/presentation/providers/finance_transaction_controller.dart';
import 'package:budget_tracker/presentation/providers/transactions_journal_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

/// Нижний отступ списка под крупную кнопку добавления операции.
const double transactionsListBottomPadding = 96;

/// История операций книги: список от новых к старым с группировкой по дням.
///
/// История показывает все операции книги, включая операции архивированных
/// счетов (ADR 4.4), и не применяет фильтры и итоги: фильтрация по счету,
/// категории и периоду относится к аналитике (ADR 2.5).
class TransactionsPage extends ConsumerWidget {
  const TransactionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return ref
        .watch(activeBookProvider)
        .when(
          loading: () => const TransactionsLoadingView(),
          error: (error, stackTrace) => TransactionsErrorView(
            message: localizations.transactionsLoadErrorMessage,
            onRetry: () => ref.invalidate(activeBookProvider),
          ),
          data: (book) => book == null
              ? const TransactionsEmptyView()
              : _TransactionsJournal(bookId: book.id),
        );
  }
}

class _TransactionsJournal extends ConsumerWidget {
  const _TransactionsJournal({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final journal = ref.watch(transactionsJournalProvider(bookId));

    return journal.when(
      loading: () => const TransactionsLoadingView(),
      error: (error, stackTrace) => TransactionsErrorView(
        message: localizations.transactionsLoadErrorMessage,
        onRetry: () => ref.invalidate(transactionsJournalProvider(bookId)),
      ),
      data: (value) => value.hasTransactions
          ? _TransactionsListView(bookId: bookId, journal: value)
          : const TransactionsEmptyView(),
    );
  }
}

class _TransactionsListView extends ConsumerWidget {
  const _TransactionsListView({required this.bookId, required this.journal});

  final String bookId;
  final TransactionsJournal journal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(bookAccountsProvider(bookId)).value ?? const [];
    final categories =
        ref.watch(bookCategoriesProvider(bookId)).value ?? const [];
    final currencies = ref.watch(currencyCatalogProvider).value ?? const {};
    final accountsById = {for (final account in accounts) account.id: account};
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dayFormat = DateFormat.yMMMMEEEEd(localeTag);

    return ListView(
      // Строка истории занимает всю ширину списка (действия по свайпу
      // открываются на всю ширину), а внутренний отступ строки задает ListTile.
      // Нижний отступ оставляет место под крупную кнопку добавления операции.
      padding: const EdgeInsets.only(
        bottom: 16 + transactionsListBottomPadding,
      ),
      children: [
        for (final group in journal.days) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              dayFormat.format(group.day),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (final transaction in group.transactions)
            _TransactionSlidable(
              bookId: bookId,
              transaction: transaction,
              account: accountsById[transaction.accountId],
              toAccount: accountsById[transaction.toAccountId],
              category: categoriesById[transaction.categoryId],
              currencySymbol: _currencySymbol(
                currencies,
                accountsById[transaction.accountId],
              ),
              toCurrencySymbol: _currencySymbol(
                currencies,
                accountsById[transaction.toAccountId],
              ),
            ),
        ],
      ],
    );
  }
}

/// Символ валютной единицы счета; `null`, если счет неизвестен или символа нет.
String? _currencySymbol(
  Map<String, FinanceCurrency> currencies,
  FinanceAccount? account,
) => account == null ? null : currencies[account.currencyCode]?.symbol;

/// Строка истории с действиями «Редактировать» и «Удалить» по свайпу.
///
/// Действия не занимают места в самой строке, а нажатие по строке открывает
/// форму редактирования. Удаление безвозвратно и выполняется только после
/// подтверждения: операция не архивируется, потому что на нее не ссылается ни
/// одна запись (ADR 4.4 не применяется к операциям).
class _TransactionSlidable extends ConsumerWidget {
  const _TransactionSlidable({
    required this.bookId,
    required this.transaction,
    required this.account,
    required this.toAccount,
    required this.category,
    required this.currencySymbol,
    required this.toCurrencySymbol,
  });

  final String bookId;
  final FinanceTransaction transaction;
  final FinanceAccount? account;
  final FinanceAccount? toAccount;
  final FinanceCategory? category;
  final String? currencySymbol;
  final String? toCurrencySymbol;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sourceAccount = account;

    return Slidable(
      key: ValueKey(transaction.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) =>
                TransactionFormPage.open(context, transaction: transaction),
            icon: Icons.edit,
            label: localizations.transactionsEditAction,
            backgroundColor: theme.colorScheme.primary,
          ),
          SlidableAction(
            onPressed: (_) => _confirmDeletion(context, ref),
            icon: Icons.delete,
            label: localizations.transactionsDeleteAction,
            backgroundColor: theme.colorScheme.error,
          ),
        ],
      ),
      child: sourceAccount == null
          ? ListTile(
              title: Text(
                transactionKindLabel(localizations, transaction.kind),
              ),
              subtitle: Text(transaction.accountId),
            )
          : TransactionTile(
              transaction: transaction,
              account: sourceAccount,
              toAccount: toAccount,
              category: category,
              currencySymbol: currencySymbol,
              toCurrencySymbol: toCurrencySymbol,
              onTap: () =>
                  TransactionFormPage.open(context, transaction: transaction),
            ),
    );
  }

  Future<void> _confirmDeletion(BuildContext context, WidgetRef ref) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.transactionsDeleteDialogTitle),
        content: Text(localizations.transactionsDeleteDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.transactionsDeleteDialogCancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.transactionsDeleteAction),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      await ref
          .read(financeTransactionControllerProvider.notifier)
          .delete(bookId, transaction.id);
      if (!context.mounted) {
        return;
      }
      _showMessage(context, localizations.transactionsDeletedMessage);
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      _showMessage(context, localizations.transactionsDeleteErrorMessage);
    }
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class TransactionsLoadingView extends StatelessWidget {
  const TransactionsLoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Пустое состояние истории: приглашение добавить первую операцию.
class TransactionsEmptyView extends StatelessWidget {
  const TransactionsEmptyView({super.key});

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
            Icon(
              Icons.swap_horiz_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.transactionsEmptyTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              localizations.transactionsEmptyMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => TransactionFormPage.open(context),
              child: Text(localizations.transactionsEmptyAction),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ошибка загрузки истории с действием повторной загрузки.
///
/// Пустой список при ошибке не показывается: иначе ошибка локального хранилища
/// выглядела бы как готовая пустая история.
class TransactionsErrorView extends StatelessWidget {
  const TransactionsErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

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
              onPressed: onRetry,
              child: Text(localizations.transactionsRetryAction),
            ),
          ],
        ),
      ),
    );
  }
}

