import 'package:budget_tracker/ui/core/theme/app_semantic_colors.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/core/utils/money_formatter.dart';
import 'package:flutter/material.dart';

/// Строка диаграммы аналитики: наименование, сумма и полоса доли.
///
/// Общая форма полос месячного среза и годового тренда: полоса показывает долю
/// величины от наибольшей величины валютного блока, поэтому диаграмма читается без
/// процентов и легенд (`design.md`, решение 8). Сумма показывается в валюте блока,
/// а длинное наименование сжимается с многоточием и не обрезает сумму. Цвет полосы
/// — семантический цвет выбранного потока (ADR-0001, решение 9.1); поток при этом
/// выражен еще переключателем и подписью итога, поэтому смысл не зависит только от
/// цвета.
class AnalyticsBarRow extends StatelessWidget {
  const AnalyticsBarRow({
    super.key,
    required this.label,
    required this.amountMinor,
    required this.maxAmountMinor,
    required this.stream,
    required this.currencyCode,
    this.currencySymbol,
    this.onTap,
  });

  final String label;
  final int amountMinor;
  final int maxAmountMinor;
  final TransactionKind stream;
  final String currencyCode;
  final String? currencySymbol;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kindColor = AppSemanticColors.of(context).forKind(stream);
    final amount = formatMoneyMinor(
      context,
      amountMinor,
      currencyCode: currencyCode,
      currencySymbol: currencySymbol,
    );
    final factor = maxAmountMinor <= 0 ? 0.0 : amountMinor / maxAmountMinor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  amount,
                  maxLines: 1,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 8,
                color: theme.colorScheme.surfaceContainerHighest,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: factor,
                  child: ColoredBox(color: kindColor),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Горизонтальная диаграмма категорий месячного среза.
///
/// Категории приходят из правила домена уже упорядоченными по убыванию суммы, а
/// при равных суммах — по наименованию. Категории с нулевой суммой в диаграмму не
/// попадают: правило не возвращает нулевых полос.
class CategoryBarChart extends StatelessWidget {
  const CategoryBarChart({
    super.key,
    required this.block,
    required this.stream,
    this.onCategoryTap,
  });

  final AnalyticsCurrencyBlock block;
  final TransactionKind stream;

  /// Нажатие на категорию открывает операции этой категории за период.
  final ValueChanged<AnalyticsCategoryTotal>? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final maxAmountMinor = block.categories.fold<int>(
      0,
      (max, item) => item.amountMinor > max ? item.amountMinor : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final total in block.categories)
          AnalyticsBarRow(
            label: total.category.name,
            amountMinor: total.amountMinor,
            maxAmountMinor: maxAmountMinor,
            stream: stream,
            currencyCode: block.currencyCode,
            currencySymbol: block.currency?.symbol,
            onTap: onCategoryTap == null ? null : () => onCategoryTap!(total),
          ),
      ],
    );
  }
}
