import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/features/analytics/widgets/category_bar_chart.dart';
import 'package:budget_tracker/presentation/features/analytics/widgets/year_trend_chart.dart';
import 'package:budget_tracker/presentation/shared/utils/money_formatter.dart';
import 'package:flutter/material.dart';

/// Валютный блок раздела: собственный итог и собственная диаграмма одной валюты.
///
/// Общего итога по разным валютам нет: суммы разных валют не складываются и не
/// конвертируются (ADR-0001, решение 2.1). Форму диаграммы задает режим периода:
/// заполненные месячные суммы дают помесячный тренд года, категорийные суммы —
/// диаграмму категорий месяца.
class CurrencyBlockView extends StatelessWidget {
  const CurrencyBlockView({
    super.key,
    required this.block,
    required this.stream,
    this.onCategoryTap,
  });

  final AnalyticsCurrencyBlock block;
  final TransactionKind stream;

  /// Нажатие на категорию диаграммы месяца открывает операции категории.
  final ValueChanged<AnalyticsCategoryTotal>? onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final total = formatMoneyMinor(
      context,
      block.totalMinor,
      currencyCode: block.currencyCode,
      currencySymbol: block.currency?.symbol,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(block.currencyCode, style: theme.textTheme.titleMedium),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${localizations.analyticsTotalLabel}: $total',
                  maxLines: 1,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (block.months.isNotEmpty)
            YearTrendChart(block: block, stream: stream)
          else
            CategoryBarChart(
              block: block,
              stream: stream,
              onCategoryTap: onCategoryTap,
            ),
        ],
      ),
    );
  }
}
