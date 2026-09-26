import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Выбор валюты счета из справочника валют.
///
/// Справочник доступен только для чтения: валюту можно найти по коду, символу
/// или наименованию и выбрать, но добавить или изменить позицию справочника
/// нельзя. Наименование показывается на языке интерфейса.
class CurrencyPickerSheet extends ConsumerStatefulWidget {
  const CurrencyPickerSheet({super.key, this.selectedCode});

  /// Код валюты счета: выбранная позиция помечается отметкой.
  final String? selectedCode;

  /// Показывает выбор валюты и возвращает выбранную позицию справочника.
  static Future<FinanceCurrency?> show(
    BuildContext context, {
    String? selectedCode,
  }) {
    return showModalBottomSheet<FinanceCurrency>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CurrencyPickerSheet(selectedCode: selectedCode),
    );
  }

  @override
  ConsumerState<CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends ConsumerState<CurrencyPickerSheet> {
  late Future<List<FinanceCurrency>> _result;

  @override
  void initState() {
    super.initState();
    _result = _search('');
  }

  Future<List<FinanceCurrency>> _search(String query) =>
      ref.read(currenciesRepositoryProvider).search(query);

  void _onQueryChanged(String query) {
    setState(() {
      _result = _search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  localizations.currencyPickerTitle,
                  style: theme.textTheme.titleLarge,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  onChanged: _onQueryChanged,
                  decoration: InputDecoration(
                    hintText: localizations.currencyPickerSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<FinanceCurrency>>(
                  future: _result,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _SheetMessage(
                        message: localizations.currencyPickerLoadErrorMessage,
                      );
                    }
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final currencies = snapshot.data ?? const <FinanceCurrency>[];
                    if (currencies.isEmpty) {
                      return _SheetMessage(
                        message: localizations.currencyPickerEmptyMessage,
                      );
                    }
                    return ListView.builder(
                      itemCount: currencies.length,
                      itemBuilder: (context, index) => _CurrencyTile(
                        currency: currencies[index],
                        isSelected:
                            currencies[index].code == widget.selectedCode,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrencyTile extends StatelessWidget {
  const _CurrencyTile({required this.currency, required this.isSelected});

  final FinanceCurrency currency;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context);
    final name = locale.languageCode == 'en'
        ? currency.nameEn
        : currency.nameRu;

    return ListTile(
      leading: SizedBox(
        width: 48,
        child: Text(
          currency.symbol ?? currency.code,
          style: theme.textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
      ),
      title: Text(currency.code),
      subtitle: Text(name),
      trailing: isSelected ? const Icon(Icons.check) : null,
      onTap: () => Navigator.of(context).pop(currency),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}