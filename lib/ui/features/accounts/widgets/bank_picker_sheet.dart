import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:flutter/material.dart';

/// Результат выбора банка в форме счета.
///
/// `bank == null` означает счет без банка: пользователь может снять выбор.
class BankPickerSelection {
  const BankPickerSelection(this.bank);

  final FinanceBank? bank;
}

/// Выбор банка счета из справочника банков с поиском по наименованию.
///
/// Поиск выполняется по уже загруженному списку банков без обращения к сети и
/// без учета регистра, поэтому он работает и для кириллических наименований.
/// Список банков передается снаружи: форма счета уже получает его из
/// `banksProvider`, поэтому лист не делает повторных выборок.
class BankPickerSheet extends StatefulWidget {
  const BankPickerSheet({super.key, required this.banks, this.selectedId});

  final List<FinanceBank> banks;

  /// Банк счета: выбранная позиция помечается отметкой.
  final String? selectedId;

  /// Показывает выбор банка и возвращает выбор пользователя.
  static Future<BankPickerSelection?> show(
    BuildContext context, {
    required List<FinanceBank> banks,
    String? selectedId,
  }) {
    return showModalBottomSheet<BankPickerSelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BankPickerSheet(banks: banks, selectedId: selectedId),
    );
  }

  @override
  State<BankPickerSheet> createState() => _BankPickerSheetState();
}

class _BankPickerSheetState extends State<BankPickerSheet> {
  String _query = '';

  List<FinanceBank> get _matches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.banks;
    }
    return [
      for (final bank in widget.banks)
        if (bank.name.toLowerCase().contains(query) ||
            (bank.displayName?.toLowerCase().contains(query) ?? false))
          bank,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final matches = _matches;
    final isSearching = _query.trim().isNotEmpty;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  localizations.bankPickerTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: bankPickerSearchFieldKey,
                  onChanged: (query) {
                    setState(() {
                      _query = query;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: localizations.bankPickerSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    if (!isSearching)
                      ListTile(
                        key: bankPickerNoneOptionKey,
                        leading: const Icon(Icons.block),
                        title: Text(localizations.accountFormBankNoneLabel),
                        trailing: widget.selectedId == null
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(const BankPickerSelection(null)),
                      ),
                    for (final bank in matches)
                      ListTile(
                        key: ValueKey(bank.id),
                        leading: const Icon(Icons.account_balance),
                        title: Text(bank.name),
                        subtitle: bank.displayName == null
                            ? null
                            : Text(bank.displayName!),
                        trailing: bank.id == widget.selectedId
                            ? const Icon(Icons.check)
                            : null,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(BankPickerSelection(bank)),
                      ),
                    if (matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          localizations.bankPickerEmptyMessage,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ключ варианта «Без банка» в листе выбора банка.
const Key bankPickerNoneOptionKey = Key('bankPickerNoneOption');

/// Ключ поля поиска банка.
const Key bankPickerSearchFieldKey = Key('bankPickerSearchField');
