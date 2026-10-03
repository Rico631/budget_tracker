import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/account_selection_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/features/analytics/views/category_operations_page.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/account_filter_chip.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/analytics_labels.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/analytics_status_views.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/currency_block_view.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/period_control.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/stream_switch.dart';
import 'package:budget_tracker/ui/features/analytics/view_models/analytics_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Раздел «Аналитика»: срез операций книги за выбранный период.
///
/// Раздел показывает один выбранный поток: доходы и расходы не смешиваются в одной
/// диаграмме и одном итоге (ADR-0001, решения 2.3, 2.5). Суммы группируются по
/// валютам счетов, а общего итога по разным валютам нет (ADR-0001, решение 2.1).
///
/// Раздел работает только на чтение и не показывает действий добавления операции
/// или счета: операции вводятся на «Счетах» и «Операциях» (ADR-0001, решение 2.4).
class AnalyticsPage extends ConsumerWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return ref
        .watch(activeBookProvider)
        .when(
          loading: () => const AnalyticsLoadingView(),
          error: (error, stackTrace) => AnalyticsErrorView(
            message: localizations.analyticsLoadErrorMessage,
            onRetry: () => ref.invalidate(activeBookProvider),
          ),
          data: (book) => book == null
              ? const AnalyticsEmptyBookView()
              : _AnalyticsSection(bookId: book.id),
        );
  }
}

/// Раздел книги: контролы среза и содержимое выбранного периода.
class _AnalyticsSection extends ConsumerWidget {
  const _AnalyticsSection({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return ref
        .watch(bookTransactionsProvider(bookId))
        .when(
          loading: () => const AnalyticsLoadingView(),
          error: (error, stackTrace) => AnalyticsErrorView(
            message: localizations.analyticsLoadErrorMessage,
            onRetry: () => ref.invalidate(bookTransactionsProvider(bookId)),
          ),
          data: (bookTransactions) => Column(
            children: [
              const SizedBox(height: 8),
              PeriodControl(bookId: bookId),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                // Поток и фильтр по счетам стоят в одной строке и разнесены по
                // краям: переключатель у левого края, фильтр у правого. Длинная
                // подпись фильтра сжимается многоточием и не переносит строку.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const StreamSwitch(),
                    const SizedBox(width: 8),
                    Flexible(child: AccountFilterChip(bookId: bookId)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _AnalyticsContent(
                  bookId: bookId,
                  // Пустая книга отличается от периода без операций: без операций
                  // в книге показывается приглашение ввести первую операцию.
                  hasBookTransactions: bookTransactions.isNotEmpty,
                ),
              ),
            ],
          ),
        );
  }
}

/// Содержимое среза: месячная диаграмма или помесячный тренд года.
class _AnalyticsContent extends ConsumerWidget {
  const _AnalyticsContent({
    required this.bookId,
    required this.hasBookTransactions,
  });

  final String bookId;
  final bool hasBookTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(analyticsSelectionProvider);

    return switch (selection.period.mode) {
      AnalyticsPeriodMode.month => _MonthlySliceView(
        bookId: bookId,
        accountFilter: selection.accountFilter,
        hasBookTransactions: hasBookTransactions,
      ),
      AnalyticsPeriodMode.year => _YearTrendView(
        bookId: bookId,
        hasBookTransactions: hasBookTransactions,
      ),
    };
  }
}

/// Месячный срез: валютные блоки с диаграммой категорий выбранного потока.
class _MonthlySliceView extends ConsumerWidget {
  const _MonthlySliceView({
    required this.bookId,
    required this.accountFilter,
    required this.hasBookTransactions,
  });

  final String bookId;
  final AnalyticsAccountFilter accountFilter;
  final bool hasBookTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return ref
        .watch(analyticsSliceProvider(bookId))
        .when(
          loading: () => const AnalyticsLoadingView(),
          error: (error, stackTrace) => AnalyticsErrorView(
            message: localizations.analyticsLoadErrorMessage,
            onRetry: () => ref.invalidate(analyticsSliceProvider(bookId)),
          ),
          data: (slice) => slice.hasData
              ? _AnalyticsBlocks(
                  children: [
                    for (final block in slice.blocks)
                      CurrencyBlockView(
                        block: block,
                        stream: slice.stream,
                        onCategoryTap: (total) => CategoryOperationsPage.open(
                          context,
                          bookId: bookId,
                          category: total.category,
                          currencyCode: block.currencyCode,
                          currencySymbol: block.currency?.symbol,
                          period: slice.period,
                          stream: slice.stream,
                          accountFilter: accountFilter,
                        ),
                      ),
                  ],
                )
              : _EmptySliceView(
                  bookId: bookId,
                  period: slice.period,
                  hasBookTransactions: hasBookTransactions,
                ),
        );
  }
}

/// Годовой обзор: валютные блоки с помесячным трендом выбранного потока.
class _YearTrendView extends ConsumerWidget {
  const _YearTrendView({
    required this.bookId,
    required this.hasBookTransactions,
  });

  final String bookId;
  final bool hasBookTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return ref
        .watch(analyticsYearTrendProvider(bookId))
        .when(
          loading: () => const AnalyticsLoadingView(),
          error: (error, stackTrace) => AnalyticsErrorView(
            message: localizations.analyticsLoadErrorMessage,
            onRetry: () => ref.invalidate(analyticsYearTrendProvider(bookId)),
          ),
          data: (trend) => trend.hasData
              ? _AnalyticsBlocks(
                  children: [
                    for (final block in trend.blocks)
                      CurrencyBlockView(block: block, stream: trend.stream),
                  ],
                )
              : _EmptySliceView(
                  bookId: bookId,
                  period: trend.period,
                  hasBookTransactions: hasBookTransactions,
                ),
        );
  }
}

/// Состояние отсутствия данных за период.
///
/// Состояние различает отсутствие операций в книге, отсутствие операций за
/// выбранный период и отсутствие операций по выбранным счетам: пустая диаграмма,
/// нулевые полосы и нулевой итог как готовый результат не показываются.
class _EmptySliceView extends ConsumerWidget {
  const _EmptySliceView({
    required this.bookId,
    required this.period,
    required this.hasBookTransactions,
  });

  final String bookId;
  final AnalyticsPeriod period;
  final bool hasBookTransactions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    if (!hasBookTransactions) {
      return const AnalyticsEmptyBookView();
    }

    final periodLabel = analyticsPeriodLabel(localizations, period);
    final accountFilter = ref.watch(
      analyticsSelectionProvider.select((selection) => selection.accountFilter),
    );
    final selected = filteredAccounts(
      ref.watch(bookAccountsProvider(bookId)).value ?? const <FinanceAccount>[],
      accountFilter,
    );

    // Состояние различает период без операций, один выбранный счет и набор счетов:
    // сообщение называет то, что сузило срез.
    final String message;
    if (accountFilter.isEmpty) {
      message = localizations.analyticsEmptyPeriodMessage(periodLabel);
    } else if (selected.length == 1) {
      message = localizations.analyticsEmptyAccountMessage(
        selected.single.name,
        periodLabel,
      );
    } else {
      message = localizations.analyticsEmptyAccountsMessage(periodLabel);
    }

    return AnalyticsEmptyView(message: message);
  }
}

/// Прокручиваемое содержимое раздела: список валютных блоков.
///
/// Содержимое строится целиком (`SingleChildScrollView` и `Column`), потому что
/// число валютных блоков и их полос ограничено данными книги: это позволяет
/// проверить состав диаграммы целиком, включая месяцы годового тренда, которые
/// выходят за пределы видимой области.
class _AnalyticsBlocks extends StatelessWidget {
  const _AnalyticsBlocks({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}
