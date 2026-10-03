import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/analytics_rule.dart';
import 'package:budget_tracker/ui/features/analytics/widgets/analytics_labels.dart';
import 'package:budget_tracker/ui/features/analytics/view_models/analytics_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ контрола периода.
const Key analyticsPeriodControlKey = Key('analyticsPeriodControl');

/// Ключ подписи выбранного периода.
const Key analyticsPeriodLabelKey = Key('analyticsPeriodLabel');

/// Ключ переключателя режима периода.
const Key analyticsPeriodModeSwitchKey = Key('analyticsPeriodModeSwitch');

/// Ключ перехода к предыдущему периоду.
const Key analyticsPreviousPeriodButtonKey = Key(
  'analyticsPreviousPeriodButton',
);

/// Ключ перехода к следующему периоду.
const Key analyticsNextPeriodButtonKey = Key('analyticsNextPeriodButton');

/// Контрол периода среза: режим, подпись, переходы и список периодов.
///
/// Переходы ограничены доступными периодами: если соседнего доступного периода нет,
/// стрелка недоступна, поэтому уход в период без операций невозможен. Нажатие на
/// подпись открывает список периодов режима: он содержит периоды с операциями книги
/// и текущий месяц или год.
class PeriodControl extends ConsumerWidget {
  const PeriodControl({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final selection = ref.watch(analyticsSelectionProvider);
    final available =
        ref.watch(availableAnalyticsPeriodsProvider(bookId)).value ??
        const <AnalyticsPeriod>[];
    final periods = analyticsPeriodsOfMode(available, selection.period.mode);
    final previous = previousAvailablePeriod(periods, selection.period);
    final next = nextAvailablePeriod(periods, selection.period);
    final controller = ref.read(analyticsSelectionProvider.notifier);

    return Padding(
      key: analyticsPeriodControlKey,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<AnalyticsPeriodMode>(
            key: analyticsPeriodModeSwitchKey,
            segments: [
              ButtonSegment(
                value: AnalyticsPeriodMode.month,
                label: Text(localizations.analyticsPeriodModeMonthLabel),
              ),
              ButtonSegment(
                value: AnalyticsPeriodMode.year,
                label: Text(localizations.analyticsPeriodModeYearLabel),
              ),
            ],
            selected: {selection.period.mode},
            onSelectionChanged: (values) => controller.selectPeriodMode(
              values.single,
              available: available,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: analyticsPreviousPeriodButtonKey,
                onPressed: previous == null
                    ? null
                    : () => controller.selectPeriod(previous),
                tooltip: localizations.analyticsPreviousPeriodTooltip,
                icon: const Icon(Icons.chevron_left),
              ),
              TextButton(
                key: analyticsPeriodLabelKey,
                onPressed: () => _showPeriods(context, ref, periods),
                child: Text(
                  analyticsPeriodLabel(localizations, selection.period),
                ),
              ),
              IconButton(
                key: analyticsNextPeriodButtonKey,
                onPressed: next == null
                    ? null
                    : () => controller.selectPeriod(next),
                tooltip: localizations.analyticsNextPeriodTooltip,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showPeriods(
    BuildContext context,
    WidgetRef ref,
    List<AnalyticsPeriod> periods,
  ) async {
    final localizations = AppLocalizations.of(context);
    final selected = ref.read(analyticsSelectionProvider).period;
    final picked = await showModalBottomSheet<AnalyticsPeriod>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final period in periods)
                ListTile(
                  key: ValueKey(period),
                  title: Text(analyticsPeriodLabel(localizations, period)),
                  trailing: period == selected ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(sheetContext).pop(period),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null) {
      return;
    }
    ref.read(analyticsSelectionProvider.notifier).selectPeriod(picked);
  }
}
