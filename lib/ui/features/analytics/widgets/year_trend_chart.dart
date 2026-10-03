import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/analytics_labels.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/category_bar_chart.dart';
import 'package:flutter/material.dart';

/// Помесячный тренд года: двенадцать величин выбранного потока в календарном
/// порядке.
///
/// Месяц без операций показывается нулевой величиной: ось года непрерывна, и
/// нулевой месяц здесь является фактом, а не подменой отсутствия данных
/// (`design.md`, решение 5). Доходы и расходы в тренде не смешиваются: тренд
/// строится по одному выбранному потоку.
class YearTrendChart extends StatelessWidget {
  const YearTrendChart({super.key, required this.block, required this.stream});

  final AnalyticsCurrencyBlock block;
  final TransactionKind stream;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final maxAmountMinor = block.months.fold<int>(
      0,
      (max, item) => item.amountMinor > max ? item.amountMinor : max,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final total in block.months)
          AnalyticsBarRow(
            label: analyticsMonthName(localizations, total.month),
            amountMinor: total.amountMinor,
            maxAmountMinor: maxAmountMinor,
            stream: stream,
            currencyCode: block.currencyCode,
            currencySymbol: block.currency?.symbol,
          ),
      ],
    );
  }
}
