import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/features/transactions/transaction_form_page.dart';
import 'package:budget_tracker/presentation/features/transactions/widgets/transaction_tile.dart';
import 'package:budget_tracker/presentation/providers/finance_transaction_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// Строка операции с действиями «Редактировать» и «Удалить» по свайпу.
///
/// Действия не занимают места в самой строке, а нажатие по строке открывает форму
/// редактирования. Удаление безвозвратно и выполняется только после подтверждения:
/// операция не архивируется, потому что на нее не ссылается ни одна запись
/// (ADR-0003, решение 3.2).
///
/// Строку используют история операций и подэкран операций категории аналитики,
/// поэтому действия над операцией в обоих местах совпадают.
class TransactionSlidable extends ConsumerWidget {
  const TransactionSlidable({
    super.key,
    required this.bookId,
    required this.transaction,
    required this.account,
    this.toAccount,
    this.category,
    this.currencySymbol,
    this.toCurrencySymbol,
  });

  final String bookId;
  final FinanceTransaction transaction;

  /// Счет операции; отсутствует, если счет не найден. Операции без найденного
  /// счета не попадают в срез аналитики, а в истории показываются без остатка
  /// строки, потому что ссылочная целостность гарантируется внешним ключом.
  final FinanceAccount? account;

  /// Счет-получатель перевода.
  final FinanceAccount? toAccount;

  /// Категория дохода или расхода; у перевода ее нет.
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
