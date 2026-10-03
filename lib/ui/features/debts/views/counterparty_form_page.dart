import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/commands/counterparty_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/core/utils/money_input_parser.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/account_selection_providers.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/accounts_controller.dart';
import 'package:budget_tracker/ui/features/accounts/widgets/currency_picker_sheet.dart';
import 'package:budget_tracker/ui/features/debts/view_models/debts_controller.dart';
import 'package:budget_tracker/ui/features/transactions/views/transactions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ поля наименования контрагента.
const Key counterpartyFormNameFieldKey = Key('counterpartyFormNameField');

/// Ключ поля валюты контрагента.
const Key counterpartyFormCurrencyFieldKey = Key(
  'counterpartyFormCurrencyField',
);

/// Ключ поля счета первой операции.
const Key counterpartyFormAccountFieldKey = Key('counterpartyFormAccountField');

/// Ключ поля суммы первой операции.
const Key counterpartyFormAmountFieldKey = Key('counterpartyFormAmountField');

/// Ключ переключателя направления долга.
const Key counterpartyFormDirectionKey = Key('counterpartyFormDirection');

/// Ключ действия сохранения контрагента.
const Key counterpartyFormSaveKey = Key('counterpartyFormSave');

/// Ключ действия закрытия долга.
const Key counterpartyFormCloseKey = Key('counterpartyFormClose');

/// Ключ действия возврата контрагента в активные.
const Key counterpartyFormReopenKey = Key('counterpartyFormReopen');

/// Ключ действия удаления контрагента.
const Key counterpartyFormDeleteKey = Key('counterpartyFormDelete');

/// Форма создания и редактирования контрагента.
///
/// Контрагент создается только вместе с первой операцией: форма требует
/// наименование, валюту, направление, счет и сумму, а сохранение выполняется
/// единой операцией (ADR-0009, решение 9.11). Валюта контрагента с операциями
/// не изменяется, а долг закрывается вручную при любом остатке (решения 9.9
/// и 9.10).
class CounterpartyFormPage extends ConsumerStatefulWidget {
  const CounterpartyFormPage({super.key, this.bookId, this.counterparty});

  /// Книга создаваемого контрагента; `null` при редактировании.
  final String? bookId;

  /// Редактируемый контрагент; `null` — создание нового.
  final FinanceCounterparty? counterparty;

  /// Открывает форму контрагента и возвращает `true`, если данные изменились.
  static Future<bool?> open(
    BuildContext context, {
    String? bookId,
    FinanceCounterparty? counterparty,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CounterpartyFormPage(bookId: bookId, counterparty: counterparty),
      ),
    );
  }

  @override
  ConsumerState<CounterpartyFormPage> createState() =>
      _CounterpartyFormPageState();
}

class _CounterpartyFormPageState extends ConsumerState<CounterpartyFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  String? _currencyCode;
  String? _accountId;
  DebtDirection _direction = DebtDirection.lent;
  List<String> _errors = const [];
  bool _isBusy = false;

  bool get _isEditing => widget.counterparty != null;

  @override
  void initState() {
    super.initState();
    final counterparty = widget.counterparty;

    _nameController = TextEditingController(text: counterparty?.name ?? '');
    _amountController = TextEditingController();
    _currencyCode = counterparty?.currencyCode;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currencyCode ??= ref
        .read(accountsControllerProvider.notifier)
        .defaultCurrencyCodeFor(Localizations.localeOf(context).languageCode);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final counterparty = widget.counterparty;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? localizations.counterpartyFormEditTitle
              : localizations.counterpartyFormCreateTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + transactionsListBottomPadding,
        ),
        children: [
          TextField(
            key: counterpartyFormNameFieldKey,
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: localizations.counterpartyFormNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            key: counterpartyFormCurrencyFieldKey,
            onTap: _isEditing ? null : _pickCurrency,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: localizations.counterpartyFormCurrencyLabel,
                border: const OutlineInputBorder(),
                helperText: _isEditing
                    ? localizations.counterpartyFormCurrencyLockedMessage
                    : null,
              ),
              child: Text(_currencyCode ?? ''),
            ),
          ),
          if (!_isEditing) ...[
            const SizedBox(height: 16),
            SegmentedButton<DebtDirection>(
              key: counterpartyFormDirectionKey,
              segments: [
                ButtonSegment(
                  value: DebtDirection.lent,
                  label: Text(localizations.counterpartyFormDirectionLentLabel),
                ),
                ButtonSegment(
                  value: DebtDirection.borrowed,
                  label: Text(
                    localizations.counterpartyFormDirectionBorrowedLabel,
                  ),
                ),
              ],
              selected: {_direction},
              onSelectionChanged: (selection) =>
                  setState(() => _direction = selection.first),
            ),
            const SizedBox(height: 16),
            _AccountField(
              bookId: widget.bookId!,
              currencyCode: _currencyCode,
              accountId: _accountId,
              onSelected: (accountId) => setState(() => _accountId = accountId),
              localizations: localizations,
            ),
            const SizedBox(height: 16),
            TextField(
              key: counterpartyFormAmountFieldKey,
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: localizations.counterpartyFormAmountLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          for (final message in _errorMessages(localizations)) ...[
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            key: counterpartyFormSaveKey,
            onPressed: _isBusy ? null : _save,
            child: Text(localizations.counterpartyFormSaveAction),
          ),
          if (counterparty != null) ...[
            const SizedBox(height: 8),
            if (counterparty.isClosed)
              TextButton(
                key: counterpartyFormReopenKey,
                onPressed: _isBusy ? null : () => _setClosed(isClosed: false),
                child: Text(localizations.debtsReopenAction),
              )
            else
              TextButton(
                key: counterpartyFormCloseKey,
                onPressed: _isBusy ? null : _closeDebt,
                child: Text(localizations.debtsCloseAction),
              ),
            const SizedBox(height: 8),
            TextButton(
              key: counterpartyFormDeleteKey,
              onPressed: _isBusy ? null : _delete,
              child: Text(localizations.debtsDeleteAction),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickCurrency() async {
    final selected = await CurrencyPickerSheet.show(
      context,
      selectedCode: _currencyCode,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _currencyCode = selected.code;
      _accountId = null;
    });
  }

  Future<void> _save() async {
    final counterparty = widget.counterparty;
    final controller = ref.read(debtsControllerProvider.notifier);
    final parsedAmount = parseMoneyInput(_amountController.text);
    final bookId = counterparty?.bookId ?? widget.bookId!;

    setState(() {
      _errors = const [];
      _isBusy = true;
    });

    try {
      final result = counterparty == null
          ? await _create(controller, bookId, parsedAmount)
          : await controller.save(
              counterparty,
              name: _nameController.text,
              currencyCode: _currencyCode ?? counterparty.currencyCode,
            );
      if (!mounted) {
        return;
      }
      switch (result) {
        case Valid():
          Navigator.of(context).pop(true);
        case Invalid(errors: final domainErrors):
          setState(() {
            _errors = domainErrors;
            _isBusy = false;
          });
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errors = const ['unexpected.'];
        _isBusy = false;
      });
    }
  }

  Future<ValidationResult<FinanceCounterparty>> _create(
    DebtsController controller,
    String bookId,
    MoneyInputResult parsedAmount,
  ) async {
    final input = CounterpartyInput.tryCreate(
      bookId: bookId,
      name: _nameController.text,
      currencyCode: _currencyCode ?? '',
      direction: _direction,
      accountId: _accountId ?? '',
      amountMinor: parsedAmount is MoneyInputValue
          ? parsedAmount.minorUnits
          : 0,
    );

    switch (input) {
      case Valid(value: final value):
        return controller.create(value);
      case Invalid(errors: final inputErrors):
        setState(() {
          _errors = inputErrors;
          _isBusy = false;
        });
        return ValidationResult.invalid(inputErrors);
    }
  }

  Future<void> _closeDebt() async {
    final confirmed = await _confirm(
      titleKey: 'close',
      title: AppLocalizations.of(context).debtsCloseDialogTitle,
      message: AppLocalizations.of(context).debtsCloseDialogMessage,
      confirmLabel: AppLocalizations.of(context).debtsCloseAction,
    );
    if (!mounted || !confirmed) {
      return;
    }
    await _setClosed(isClosed: true);
  }

  Future<void> _setClosed({required bool isClosed}) async {
    final counterparty = widget.counterparty!;
    final controller = ref.read(debtsControllerProvider.notifier);

    setState(() {
      _errors = const [];
      _isBusy = true;
    });
    try {
      if (isClosed) {
        await controller.close(counterparty);
      } else {
        await controller.reopen(counterparty);
      }
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errors = const ['unexpected.'];
        _isBusy = false;
      });
    }
  }

  Future<void> _delete() async {
    final counterparty = widget.counterparty!;
    final localizations = AppLocalizations.of(context);
    final confirmed = await _confirm(
      titleKey: 'delete',
      title: localizations.debtsDeleteDialogTitle,
      message: localizations.debtsDeleteDialogMessage,
      confirmLabel: localizations.debtsDeleteDialogConfirmAction,
    );
    if (!mounted || !confirmed) {
      return;
    }

    setState(() {
      _errors = const [];
      _isBusy = true;
    });
    final result = await ref
        .read(debtsControllerProvider.notifier)
        .remove(counterparty);
    if (!mounted) {
      return;
    }
    switch (result) {
      case Valid():
        Navigator.of(context).pop(true);
      case Invalid(errors: final domainErrors):
        setState(() {
          _errors = domainErrors;
          _isBusy = false;
        });
    }
  }

  Future<bool> _confirm({
    required String titleKey,
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final localizations = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: Key('counterpartyFormDialog-$titleKey'),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.debtsDialogCancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  List<String> _errorMessages(AppLocalizations localizations) => [
    for (final error in _errors)
      counterpartyFormErrorMessage(error, localizations),
  ];
}

/// Локализованное сообщение по коду ошибки формы контрагента.
String counterpartyFormErrorMessage(
  String error,
  AppLocalizations localizations,
) => switch (error) {
  'name is required.' => localizations.counterpartyFormNameRequiredError,
  'a counterparty with the same name already exists in the book.' =>
    localizations.counterpartyFormNameDuplicateError,
  'currencyCode must contain three letters.' =>
    localizations.counterpartyFormCurrencyCodeError,
  'accountId is required.' => localizations.counterpartyFormAccountError,
  'amountMinor must be positive.' => localizations.counterpartyFormAmountError,
  'the book has no account with the counterparty currency.' =>
    localizations.counterpartyFormAccountCurrencyError,
  'currency cannot be changed for a counterparty with transactions.' =>
    localizations.counterpartyFormCurrencyChangeError,
  'the book has no debt category of the requested kind.' =>
    localizations.counterpartyFormDebtCategoryError,
  'a counterparty with transactions cannot be deleted.' =>
    localizations.counterpartyFormDeleteError,
  _ => localizations.counterpartyFormSaveErrorMessage,
};

class _AccountField extends ConsumerWidget {
  const _AccountField({
    required this.bookId,
    required this.currencyCode,
    required this.accountId,
    required this.onSelected,
    required this.localizations,
  });

  final String bookId;
  final String? currencyCode;
  final String? accountId;
  final ValueChanged<String?> onSelected;
  final AppLocalizations localizations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(activeBookAccountsProvider(bookId)).value;
    // Счет первой операции обязан иметь валюту контрагента, поэтому выбор
    // ограничен счетами этой валюты (ADR-0009, решение 9.9).
    final matching = [
      for (final account in accounts ?? const <FinanceAccount>[])
        if (account.currencyCode == currencyCode) account,
    ];
    final selected = matching.where((account) => account.id == accountId);

    return InkWell(
      key: counterpartyFormAccountFieldKey,
      onTap: matching.isEmpty
          ? null
          : () => _pick(
              context,
              matching,
              selected.isEmpty ? null : selected.first,
            ),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: localizations.counterpartyFormAccountLabel,
          border: const OutlineInputBorder(),
          helperText: matching.isEmpty
              ? localizations.counterpartyFormNoAccountMessage
              : null,
        ),
        child: Text(
          selected.isEmpty
              ? ''
              : '${selected.first.name} · ${selected.first.currencyCode}',
        ),
      ),
    );
  }

  Future<void> _pick(
    BuildContext context,
    List<FinanceAccount> accounts,
    FinanceAccount? selected,
  ) async {
    final selection = await showModalBottomSheet<FinanceAccount>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final account in accounts)
              ListTile(
                title: Text(account.name),
                subtitle: Text(account.currencyCode),
                selected: account.id == selected?.id,
                onTap: () => Navigator.of(sheetContext).pop(account),
              ),
          ],
        ),
      ),
    );
    if (selection == null) {
      return;
    }
    onSelected(selection.id);
  }
}
