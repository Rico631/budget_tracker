import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/theme/app_semantic_colors.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/transfer_rate_rule.dart';
import 'package:budget_tracker/ui/core/utils/money_formatter.dart';
import 'package:flutter/material.dart';

/// Локализованная подпись типа операции.
String transactionKindLabel(
  AppLocalizations localizations,
  TransactionKind kind,
) => switch (kind) {
  TransactionKind.income => localizations.transactionKindIncomeLabel,
  TransactionKind.expense => localizations.transactionKindExpenseLabel,
  TransactionKind.transfer => localizations.transactionKindTransferLabel,
};

/// Строка операции в истории книги.
///
/// Тип операции показывается текстом и цветом (ADR 9.1): цвет — дополнительный
/// признак, поэтому тип остается различимым и без цвета. Сумма показывается со
/// знаком в валюте счета операции: у перевода знака нет, потому что операция
/// перекладывает деньги между своими счетами, а не зарабатывает и не тратит их.
/// Для перевода между счетами разных валют дополнительно показываются сумма
/// зачисления и вычисленный фактический курс (ADR 2.3).
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.account,
    this.toAccount,
    this.category,
    this.counterparty,
    this.currencySymbol,
    this.toCurrencySymbol,
    this.onTap,
  });

  final FinanceTransaction transaction;

  /// Счет операции; у перевода — счет-источник.
  final FinanceAccount account;

  /// Счет-получатель перевода.
  final FinanceAccount? toAccount;

  /// Категория дохода или расхода; у перевода ее нет.
  final FinanceCategory? category;

  /// Контрагент долга у операции с привязкой; у перевода и операции без привязки
  /// его нет, и строка не показывает пустое значение (ADR-0009, решение 9.4).
  final FinanceCounterparty? counterparty;

  final String? currencySymbol;
  final String? toCurrencySymbol;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final kindColor = AppSemanticColors.of(context).forKind(transaction.kind);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: kindColor.withValues(alpha: 0.16),
        foregroundColor: kindColor,
        child: Icon(_iconFor(transaction.kind)),
      ),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        // Тип операции у левого края строки, сумма — у правого: остаток ширины
        // распределяется между элементами, поэтому строка занимает всю ширину
        // списка.
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              transactionKindLabel(localizations, transaction.kind),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(color: kindColor),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              _amountText(context),
              maxLines: 1,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        // Строки растягиваются по ширине строки списка, а не сжимаются по
        // длине текста.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _detailsText(context, localizations),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium,
          ),
          if (_crossCurrencyText(context) case final line?)
            Text(line, maxLines: 2, style: theme.textTheme.bodySmall),
          if (counterparty case final counterparty?)
            Text(
              '${localizations.transactionTileCounterpartyLabel}: '
              '${counterparty.name}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          if (transaction.note case final note? when note.isNotEmpty)
            Text(
              note,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  IconData _iconFor(TransactionKind kind) => switch (kind) {
    TransactionKind.income => Icons.south_west,
    TransactionKind.expense => Icons.north_east,
    TransactionKind.transfer => Icons.swap_horiz,
  };

  String _amountText(BuildContext context) {
    final amount = formatMoneyMinor(
      context,
      transaction.amountMinor,
      currencyCode: account.currencyCode,
      currencySymbol: currencySymbol,
    );
    return switch (transaction.kind) {
      TransactionKind.income => '+$amount',
      TransactionKind.expense => '-$amount',
      TransactionKind.transfer => amount,
    };
  }

  String _detailsText(BuildContext context, AppLocalizations localizations) {
    if (transaction.kind == TransactionKind.transfer) {
      final targetName = toAccount?.name ?? '';
      return '${account.name} → $targetName';
    }
    final categoryName = category?.name;
    return categoryName == null || categoryName.isEmpty
        ? account.name
        : '$categoryName · ${account.name}';
  }

  /// Сумма зачисления и фактический курс мультивалютного перевода.
  String? _crossCurrencyText(BuildContext context) {
    final targetAccount = toAccount;
    final rate = transferRate(transaction);
    if (targetAccount == null || rate == null) {
      return null;
    }
    final destinationAmount = formatMoneyMinor(
      context,
      transaction.toAmountMinor!,
      currencyCode: targetAccount.currencyCode,
      currencySymbol: toCurrencySymbol,
    );
    final formattedRate = formatTransferRate(
      context,
      rate,
      sourceCurrencyCode: account.currencyCode,
      targetCurrencyCode: targetAccount.currencyCode,
    );
    return '$destinationAmount · $formattedRate';
  }
}
