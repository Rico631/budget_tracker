import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/features/analytics/view_models/analytics_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ переключателя потоков аналитики.
const Key analyticsStreamSwitchKey = Key('analyticsStreamSwitch');

/// Переключатель потока среза: на экране всегда один выбранный поток.
///
/// Доходы и расходы анализируются отдельно и не смешиваются в одной диаграмме или
/// одном итоге (ADR-0001, решения 2.3, 2.5), поэтому второй поток показывается
/// только переключением.
///
/// Переключатель делит строку с фильтром по счетам: он стоит у левого края, а
/// фильтр — у правого. Иконки показывают направление потока, а выбранный поток
/// дополнительно выражен подсветкой сегмента и подписью итога блока, поэтому смысл
/// не зависит только от цвета (ADR-0001, решение 9.1).
class StreamSwitch extends ConsumerWidget {
  const StreamSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final stream = ref.watch(
      analyticsSelectionProvider.select((selection) => selection.stream),
    );

    return SegmentedButton<TransactionKind>(
      key: analyticsStreamSwitchKey,
      style: SegmentedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      // Отметка выбора не показывается: выбранный сегмент виден по подсветке, а
      // место в строке нужно фильтру по счетам.
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: TransactionKind.income,
          label: Text(localizations.analyticsStreamIncomeLabel),
          icon: const Icon(Icons.south_west, size: 18),
        ),
        ButtonSegment(
          value: TransactionKind.expense,
          label: Text(localizations.analyticsStreamExpenseLabel),
          icon: const Icon(Icons.north_east, size: 18),
        ),
      ],
      selected: {stream},
      onSelectionChanged: (values) => ref
          .read(analyticsSelectionProvider.notifier)
          .selectStream(values.single),
    );
  }
}
