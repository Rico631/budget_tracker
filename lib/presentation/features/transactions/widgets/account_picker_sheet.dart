import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/features/transactions/widgets/picker_sheet_view.dart';
import 'package:budget_tracker/presentation/providers/transactions_journal_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ поля поиска счета.
const Key accountPickerSearchFieldKey = Key('accountPickerSearchField');

/// Выбор счета операции из активных счетов книги.
///
/// Архивный счет в списке отсутствует: в архивный счет новую операцию не вводят,
/// хотя операции архивированного счета остаются в истории (ADR 4.4). Список
/// читается провайдером, поэтому шторка не делает собственных выборок.
class AccountPickerSheet extends ConsumerStatefulWidget {
  const AccountPickerSheet({super.key, required this.bookId, this.selectedId});

  final String bookId;

  /// Счет операции: выбранная позиция помечается отметкой.
  final String? selectedId;

  /// Показывает выбор счета и возвращает выбранный счет.
  static Future<FinanceAccount?> show(
    BuildContext context, {
    required String bookId,
    String? selectedId,
  }) {
    return showModalBottomSheet<FinanceAccount>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          AccountPickerSheet(bookId: bookId, selectedId: selectedId),
    );
  }

  @override
  ConsumerState<AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends ConsumerState<AccountPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final source = activeBookAccountsProvider(widget.bookId);

    return ref
        .watch(source)
        .when(
          loading: () => const PickerSheetLoadingView(),
          error: (error, stackTrace) => PickerSheetErrorView(
            message: localizations.accountPickerLoadErrorMessage,
            onRetry: () => ref.invalidate(source),
          ),
          data: (accounts) => PickerSheetLayout(
            title: localizations.accountPickerTitle,
            searchHint: localizations.accountPickerSearchHint,
            searchFieldKey: accountPickerSearchFieldKey,
            emptyMessage: localizations.accountPickerEmptyMessage,
            onQueryChanged: (query) => setState(() {
              _query = query;
            }),
            items: [
              for (final account in _matches(accounts))
                ListTile(
                  key: ValueKey(account.id),
                  leading: const Icon(Icons.account_balance_wallet_outlined),
                  title: Text(account.name),
                  subtitle: Text(account.currencyCode),
                  trailing: account.id == widget.selectedId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(account),
                ),
            ],
          ),
        );
  }

  List<FinanceAccount> _matches(List<FinanceAccount> accounts) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return accounts;
    }
    return [
      for (final account in accounts)
        if (account.name.toLowerCase().contains(query) ||
            account.currencyCode.toLowerCase().contains(query))
          account,
    ];
  }
}