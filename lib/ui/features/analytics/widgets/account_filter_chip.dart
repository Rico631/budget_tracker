import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/account_selection_providers.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/features/analytics/view_models/analytics_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ фильтра по счетам.
const Key analyticsAccountFilterChipKey = Key('analyticsAccountFilterChip');

/// Ключ значения фильтра «Все счета» в списке выбора счетов.
const Key analyticsAccountFilterAllTileKey = Key(
  'analyticsAccountFilterAllTile',
);

/// Ключ подтверждения выбора счетов.
const Key analyticsAccountFilterApplyKey = Key('analyticsAccountFilterApply');

/// Счета книги, выбранные фильтром [filter], в порядке списка счетов.
///
/// Пустой фильтр означает «Все счета» и не выделяет отдельные счета: значение
/// фильтра по умолчанию не равно выбору всех счетов по отдельности.
List<FinanceAccount> filteredAccounts(
  List<FinanceAccount> accounts,
  AnalyticsAccountFilter filter,
) => filter.isEmpty
    ? const []
    : [
        for (final account in accounts)
          if (filter.contains(account.id)) account,
      ];

/// Фильтр по счетам: «Все счета» по умолчанию и выбор нескольких счетов.
///
/// Список содержит счета книги вместе с архивными, чтобы сужение сходилось с общим
/// срезом: операции архивного счета входят в аналитику (ADR-0001, решение 2.5), и
/// фильтр не должен предлагать меньше данных, чем показывает срез.
class AccountFilterChip extends ConsumerWidget {
  const AccountFilterChip({super.key, required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final filter = ref.watch(
      analyticsSelectionProvider.select((selection) => selection.accountFilter),
    );
    final accounts =
        ref.watch(bookAccountsProvider(bookId)).value ??
        const <FinanceAccount>[];

    return FilterChip(
      key: analyticsAccountFilterChipKey,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      showCheckmark: false,
      selected: filter.isNotEmpty,
      label: Text(
        _label(localizations, accounts, filter),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onSelected: (_) => _showAccounts(context, ref, accounts),
    );
  }

  /// Подпись фильтра: «Все счета», имя единственного счета или число выбранных.
  String _label(
    AppLocalizations localizations,
    List<FinanceAccount> accounts,
    AnalyticsAccountFilter filter,
  ) {
    if (filter.isEmpty) {
      return localizations.analyticsAccountFilterAllLabel;
    }
    final selected = filteredAccounts(accounts, filter);
    if (selected.length == 1) {
      return selected.single.name;
    }
    return localizations.analyticsAccountFilterMultipleLabel(
      filter.accountIds.length,
    );
  }

  Future<void> _showAccounts(
    BuildContext context,
    WidgetRef ref,
    List<FinanceAccount> accounts,
  ) async {
    final filter = ref.read(analyticsSelectionProvider).accountFilter;
    final picked = await showModalBottomSheet<AnalyticsAccountFilter>(
      context: context,
      builder: (_) => _AccountFilterSheet(accounts: accounts, selected: filter),
    );
    if (picked == null) {
      return;
    }
    ref.read(analyticsSelectionProvider.notifier).selectAccounts(picked);
  }
}

/// Список выбора счетов: «Все счета» и мультивыбор счетов книги.
///
/// Выбор копится в черновике и применяется подтверждением, поэтому промежуточные
/// нажатия не меняют срез, а итог выбора пользователь применяет одним действием.
class _AccountFilterSheet extends StatefulWidget {
  const _AccountFilterSheet({required this.accounts, required this.selected});

  final List<FinanceAccount> accounts;
  final AnalyticsAccountFilter selected;

  @override
  State<_AccountFilterSheet> createState() => _AccountFilterSheetState();
}

class _AccountFilterSheetState extends State<_AccountFilterSheet> {
  late final Set<String> _draft = {...widget.selected.accountIds};

  void _toggle(String accountId) {
    setState(() {
      if (!_draft.remove(accountId)) {
        _draft.add(accountId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                localizations.analyticsAccountFilterTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            CheckboxListTile(
              key: analyticsAccountFilterAllTileKey,
              value: _draft.isEmpty,
              title: Text(localizations.analyticsAccountFilterAllLabel),
              onChanged: (_) => setState(_draft.clear),
            ),
            for (final account in widget.accounts)
              CheckboxListTile(
                key: ValueKey(account.id),
                value: _draft.contains(account.id),
                title: Text(account.name),
                subtitle: Text(
                  account.isArchived
                      ? '${account.currencyCode} · '
                            '${localizations.analyticsAccountFilterArchivedLabel}'
                      : account.currencyCode,
                ),
                onChanged: (_) => _toggle(account.id),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton(
                key: analyticsAccountFilterApplyKey,
                onPressed: () => Navigator.of(
                  context,
                ).pop(AnalyticsAccountFilter.of(_draft)),
                child: Text(localizations.analyticsAccountFilterApplyAction),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
