import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/account_selection_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/core/theme/app_semantic_colors.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/features/debts/view_models/debts_controller.dart';
import 'package:budget_tracker/ui/features/transactions/widgets/account_picker_sheet.dart';
import 'package:budget_tracker/ui/features/transactions/widgets/category_picker_sheet.dart';
import 'package:budget_tracker/ui/features/transactions/widgets/transaction_tile.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/finance_transaction_controller.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/transactions_journal_provider.dart';
import 'package:budget_tracker/ui/core/utils/money_formatter.dart';
import 'package:budget_tracker/ui/core/utils/money_input_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

part 'transaction_form_widgets.dart';

/// Ключ кнопки типа операции «Доход».
const Key transactionFormKindIncomeKey = Key('transactionFormKindIncome');

/// Ключ кнопки типа операции «Расход».
const Key transactionFormKindExpenseKey = Key('transactionFormKindExpense');

/// Ключ кнопки типа операции «Перевод».
const Key transactionFormKindTransferKey = Key('transactionFormKindTransfer');

/// Ключ поля выбора счета операции.
const Key transactionFormAccountFieldKey = Key('transactionFormAccountField');

/// Ключ поля выбора счета-получателя перевода.
const Key transactionFormToAccountFieldKey = Key(
  'transactionFormToAccountField',
);

/// Ключ поля выбора категории операции.
const Key transactionFormCategoryFieldKey = Key('transactionFormCategoryField');

/// Ключ поля суммы операции.
const Key transactionFormAmountFieldKey = Key('transactionFormAmountField');

/// Ключ поля суммы зачисления перевода.
const Key transactionFormToAmountFieldKey = Key('transactionFormToAmountField');

/// Ключ поля выбора контрагента операции.
const Key transactionFormCounterpartyFieldKey = Key(
  'transactionFormCounterpartyField',
);

/// Ключ действия создания контрагента из формы операции.
const Key transactionFormCounterpartyCreateKey = Key(
  'transactionFormCounterpartyCreate',
);

/// Ключ действия снятия привязки к контрагенту.
const Key transactionFormCounterpartyClearKey = Key(
  'transactionFormCounterpartyClear',
);

/// Ключ поля наименования нового контрагента.
const Key transactionFormCounterpartyNameFieldKey = Key(
  'transactionFormCounterpartyNameField',
);

/// Ключ поля даты операции.
const Key transactionFormDateFieldKey = Key('transactionFormDateField');

/// Ключ поля заметки операции.
const Key transactionFormNoteFieldKey = Key('transactionFormNoteField');

/// Ключ действия сохранения операции.
const Key transactionFormSaveButtonKey = Key('transactionFormSaveButton');

/// Ключ блока ошибок формы операции.
const Key transactionFormErrorsKey = Key('transactionFormErrors');

/// Код ошибки формы: сумма операции не заполнена.
const String _amountRequiredError = 'amount is required.';

/// Код ошибки формы: сумма зачисления не заполнена.
const String _toAmountRequiredError = 'toAmountMinor is required.';

/// Код ошибки формы: сумму операции не удалось разобрать.
const String _amountParsingError = 'amount cannot be parsed.';

/// Код ошибки формы: сумму зачисления не удалось разобрать.
const String _toAmountParsingError = 'toAmountMinor cannot be parsed.';

/// Код ошибки формы: счет операции не выбран.
const String _accountRequiredError = 'accountId is required.';

/// Код ошибки формы: счет-получатель перевода не выбран.
const String _toAccountRequiredError = 'toAccountId is required.';

/// Код ошибки формы: счета перевода совпадают.
const String _sameAccountError = 'transfer accounts must differ.';

/// Код ошибки формы: категория операции не выбрана.
const String _categoryRequiredError = 'categoryId is required.';

/// Код ошибки формы: действие завершилось непредвиденной ошибкой.
const String _unexpectedError = 'unexpected.';

/// Форма создания и редактирования операции.
///
/// Первым шагом выбирается тип операции, а набор остальных полей зависит от него
/// (ADR 3.2): у дохода и расхода это счет, сумма и категория, у перевода — счет,
/// отличный от него счет-получатель и сумма списания, а категория не задается
/// (ADR 3.3). Для перевода между счетами разных валют дополнительно вводится
/// фактическая сумма зачисления, а курс вычисляется приложением (ADR 2.3). Дата
/// операции по умолчанию текущая и может быть изменена на прошедшую (ADR 3.4).
class TransactionFormPage extends ConsumerStatefulWidget {
  const TransactionFormPage({super.key, this.transaction});

  /// Редактируемая операция; `null` — создание новой операции.
  final FinanceTransaction? transaction;

  /// Открывает форму операции и возвращает `true`, если операция была изменена.
  static Future<bool?> open(
    BuildContext context, {
    FinanceTransaction? transaction,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TransactionFormPage(transaction: transaction),
      ),
    );
  }

  @override
  ConsumerState<TransactionFormPage> createState() =>
      _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  late TransactionKind _kind;
  late final TextEditingController _amountController;
  late final TextEditingController _toAmountController;
  late final TextEditingController _noteController;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
  String? _counterpartyId;

  /// Наименование контрагента, создаваемого вместе с сохраняемой операцией.
  ///
  /// Запись контрагента появляется только при сохранении операции: закрытие
  /// формы без сохранения не оставляет контрагента (ADR-0009, решение 9.11).
  String? _newCounterpartyName;

  late DateTime _date;
  List<String> _errors = const [];
  bool _isBusy = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _kind = transaction?.kind ?? TransactionKind.expense;
    _amountController = TextEditingController(
      text: transaction == null
          ? ''
          : (transaction.amountMinor / 100).toStringAsFixed(2),
    );
    _toAmountController = TextEditingController(
      text: transaction?.toAmountMinor == null
          ? ''
          : (transaction!.toAmountMinor! / 100).toStringAsFixed(2),
    );
    _noteController = TextEditingController(text: transaction?.note ?? '');
    _accountId = transaction?.accountId;
    _toAccountId = transaction?.toAccountId;
    _categoryId = transaction?.categoryId;
    _counterpartyId = transaction?.counterpartyId;
    _date = transaction?.occurredAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _toAmountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final bookId = ref.watch(activeBookProvider).value?.id;
    final accounts = bookId == null
        ? const <FinanceAccount>[]
        : ref.watch(activeBookAccountsProvider(bookId)).value ??
              const <FinanceAccount>[];
    final categories = bookId == null
        ? const <FinanceCategory>[]
        : ref.watch(activeBookCategoriesProvider(bookId)).value ??
              const <FinanceCategory>[];
    final accountsById = {for (final account in accounts) account.id: account};
    final categoriesById = {
      for (final category in categories) category.id: category,
    };
    final sourceAccount = accountsById[_accountId];
    final targetAccount = accountsById[_toAccountId];
    final isTransfer = _kind == TransactionKind.transfer;
    final isCrossCurrency =
        isTransfer &&
        sourceAccount != null &&
        targetAccount != null &&
        sourceAccount.currencyCode != targetAccount.currencyCode;
    final counterpartyRole = _counterpartyRole(sourceAccount, categoriesById);
    final counterparties = bookId != null && counterpartyRole != null
        ? ref
                  .watch(
                    operationCounterpartiesProvider((
                      bookId: bookId,
                      currencyCode: sourceAccount!.currencyCode,
                      role: counterpartyRole,
                    )),
                  )
                  .value ??
              const <FinanceCounterparty>[]
        : const <FinanceCounterparty>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? localizations.transactionFormEditTitle
              : localizations.transactionFormCreateTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _KindStep(
            kind: _kind,
            isEditing: _isEditing,
            onSelected: _selectKind,
          ),
          const SizedBox(height: 16),
          if (_errors case final errors when errors.isNotEmpty)
            _ErrorSummary(messages: _errorMessages(localizations)),
          _PickerField(
            fieldKey: transactionFormAccountFieldKey,
            label: localizations.transactionFormAccountLabel,
            value: sourceAccount?.name,
            enabled: !_isBusy,
            onTap: () => _selectAccount(isTarget: false),
          ),
          if (isTransfer)
            _PickerField(
              fieldKey: transactionFormToAccountFieldKey,
              label: localizations.transactionFormToAccountLabel,
              value: targetAccount?.name,
              enabled: !_isBusy,
              onTap: () => _selectAccount(isTarget: true),
            ),
          _AmountField(
            fieldKey: transactionFormAmountFieldKey,
            controller: _amountController,
            label: localizations.transactionFormAmountLabel,
            enabled: !_isBusy,
            onChanged: (_) => setState(() {}),
          ),
          if (isCrossCurrency)
            _AmountField(
              fieldKey: transactionFormToAmountFieldKey,
              controller: _toAmountController,
              label: localizations.transactionFormToAmountLabel,
              enabled: !_isBusy,
              onChanged: (_) => setState(() {}),
            ),
          if (isCrossCurrency)
            if (_rateText(context, localizations, sourceAccount, targetAccount)
                case final line?)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(line, style: Theme.of(context).textTheme.bodySmall),
              ),
          if (!isTransfer)
            _PickerField(
              fieldKey: transactionFormCategoryFieldKey,
              label: localizations.transactionFormCategoryLabel,
              value: _selectedCategoryName(categories),
              enabled: !_isBusy,
              onTap: () => _selectCategory(bookId),
            ),
          if (counterparties.isNotEmpty)
            _CounterpartyField(
              value: _counterpartyLabel(counterparties),
              enabled: !_isBusy,
              onSelect: () => _selectCounterparty(counterparties),
              // Возврат долга уменьшает существующий долг, поэтому нового
              // контрагента для него не создают (ADR-0009, решение 9.15).
              onCreate: counterpartyRole != null && !counterpartyRole.isRefund
                  ? _createCounterparty
                  : null,
              onClear: _counterpartyId == null && _newCounterpartyName == null
                  ? null
                  : _clearCounterparty,
            ),
          _DateField(
            fieldKey: transactionFormDateFieldKey,
            label: localizations.transactionFormDateLabel,
            date: _date,
            enabled: !_isBusy,
            onTap: _selectDate,
          ),
          TextField(
            key: transactionFormNoteFieldKey,
            controller: _noteController,
            enabled: !_isBusy,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: localizations.transactionFormNoteLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: transactionFormSaveButtonKey,
            onPressed: _isBusy ? null : _save,
            child: Text(localizations.transactionFormSaveAction),
          ),
        ],
      ),
    );
  }

  /// Долговая роль выбранной категории, если поле контрагента применимо.
  ///
  /// Поле доступно доходу и расходу, категория которых имеет признак долговой
  /// роли (ADR-0009, решение 9.9).
  CategoryDebtRole? _counterpartyRole(
    FinanceAccount? sourceAccount,
    Map<String, FinanceCategory> categoriesById,
  ) {
    if (_kind == TransactionKind.transfer || sourceAccount == null) {
      return null;
    }
    return categoriesById[_categoryId]?.debtRole;
  }

  /// Подпись поля контрагента: выбранный контрагент, имя нового или «без
  /// контрагента».
  String? _counterpartyLabel(List<FinanceCounterparty> counterparties) {
    if (_newCounterpartyName case final name?) {
      return name;
    }
    final counterpartyId = _counterpartyId;
    if (counterpartyId == null) {
      return AppLocalizations.of(context).transactionFormCounterpartyNoneLabel;
    }
    for (final counterparty in counterparties) {
      if (counterparty.id == counterpartyId) {
        return counterparty.name;
      }
    }
    return AppLocalizations.of(context).transactionFormCounterpartyNoneLabel;
  }

  Future<void> _selectCounterparty(
    List<FinanceCounterparty> counterparties,
  ) async {
    final selected = await showModalBottomSheet<FinanceCounterparty>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final counterparty in counterparties)
              ListTile(
                title: Text(counterparty.name),
                subtitle: Text(counterparty.currencyCode),
                selected: counterparty.id == _counterpartyId,
                onTap: () => Navigator.of(sheetContext).pop(counterparty),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _counterpartyId = selected.id;
      _newCounterpartyName = null;
      _errors = const [];
    });
  }

  /// Спрашивает наименование нового контрагента и запоминает его.
  ///
  /// Запись создается только при сохранении операции, поэтому отказ от
  /// сохранения не оставляет контрагента (ADR-0009, решение 9.11).
  Future<void> _createCounterparty() async {
    final localizations = AppLocalizations.of(context);
    var name = _newCounterpartyName ?? '';
    final selectedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const Key('transactionFormCounterpartyDialog'),
        title: Text(localizations.transactionFormCounterpartyCreateTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(localizations.transactionFormCounterpartyCreateMessage),
            const SizedBox(height: 12),
            TextFormField(
              key: transactionFormCounterpartyNameFieldKey,
              initialValue: name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (value) => name = value,
              decoration: InputDecoration(
                labelText: localizations.transactionFormCounterpartyLabel,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              localizations.transactionFormCounterpartyCreateCancelAction,
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(name.trim()),
            child: Text(
              localizations.transactionFormCounterpartyCreateConfirmAction,
            ),
          ),
        ],
      ),
    );
    if (selectedName == null || !mounted) {
      return;
    }
    setState(() {
      if (selectedName.isEmpty) {
        _errors = const [catalogNameRequiredError];
        return;
      }
      _newCounterpartyName = selectedName;
      _counterpartyId = null;
      _errors = const [];
    });
  }

  void _clearCounterparty() {
    setState(() {
      _counterpartyId = null;
      _newCounterpartyName = null;
      _errors = const [];
    });
  }

  void _selectKind(TransactionKind kind) {
    if (_isEditing || kind == _kind) {
      return;
    }
    setState(() {
      _kind = kind;
      // Категория другого типа невалидна, а счет-получатель и сумма зачисления
      // относятся только к переводу, поэтому выбор сбрасывается. Привязка к
      // контрагенту снимается вместе с категорией: поле контрагента показывается
      // только для долговой категории (ADR-0009, решение 9.5).
      _categoryId = null;
      _toAccountId = null;
      _counterpartyId = null;
      _newCounterpartyName = null;
      _toAmountController.clear();
      _errors = const [];
    });
  }

  Future<void> _selectAccount({required bool isTarget}) async {
    final bookId = await _activeBookId();
    if (bookId.isEmpty || !mounted) {
      return;
    }
    final account = await AccountPickerSheet.show(
      context,
      bookId: bookId,
      selectedId: isTarget ? _toAccountId : _accountId,
    );
    if (account == null || !mounted) {
      return;
    }
    setState(() {
      final previousAccount = isTarget ? _toAccountId : _accountId;
      if (isTarget) {
        _toAccountId = account.id;
      } else {
        _accountId = account.id;
        // Смена счета на счет другой валюты снимает привязку к контрагенту:
        // валюта контрагента должна совпадать с валютой счета операции
        // (ADR-0009, решение 9.9).
        if (previousAccount != account.id) {
          _counterpartyId = null;
          _newCounterpartyName = null;
        }
      }
      _errors = const [];
    });
  }

  Future<void> _selectCategory(String? bookId) async {
    if (bookId == null || _kind == TransactionKind.transfer) {
      return;
    }
    final category = await CategoryPickerSheet.show(
      context,
      bookId: bookId,
      kind: _kind,
      selectedId: _categoryId,
    );
    if (category == null || !mounted) {
      return;
    }
    setState(() {
      if (category.id != _categoryId && category.debtRole == null) {
        // Категория без долговой роли не участвует в учете долгов, поэтому
        // привязка снимается (ADR-0009, решение 9.5).
        _counterpartyId = null;
        _newCounterpartyName = null;
      }
      _categoryId = category.id;
      _errors = const [];
    });
    await _dropCounterpartyUnfitForRole(bookId, category.debtRole);
  }

  /// Снимает привязку, если выбранная категория не допускает контрагента.
  ///
  /// Возврат долга допустим только у контрагента с остатком своего направления
  /// (ADR-0009, решение 9.15), поэтому смена категории на возврат привязку к
  /// контрагенту другого направления не сохраняет.
  Future<void> _dropCounterpartyUnfitForRole(
    String? bookId,
    CategoryDebtRole? role,
  ) async {
    final boundId = _counterpartyId;
    if (bookId == null || role == null || boundId == null) {
      return;
    }
    final account = _transactionAccount(bookId);
    if (account == null) {
      return;
    }
    final available = await ref.read(
      operationCounterpartiesProvider((
        bookId: bookId,
        currencyCode: account.currencyCode,
        role: role,
      )).future,
    );
    if (!mounted ||
        available.any((counterparty) => counterparty.id == boundId)) {
      return;
    }
    setState(() {
      _counterpartyId = null;
    });
  }

  /// Счет операции из активных счетов книги.
  FinanceAccount? _transactionAccount(String bookId) {
    final accounts =
        ref.read(activeBookAccountsProvider(bookId)).value ??
        const <FinanceAccount>[];
    for (final account in accounts) {
      if (account.id == _accountId) {
        return account;
      }
    }
    return null;
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initialDate = _date.isAfter(today) ? today : _date;
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(today.year - 10),
      lastDate: today,
    );
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _date = selected;
      _errors = const [];
    });
  }

  Future<void> _save() async {
    final bookId = await _activeBookId();
    if (bookId.isEmpty) {
      setState(() {
        _errors = const [_unexpectedError];
      });
      return;
    }

    final accounts = await ref.read(activeBookAccountsProvider(bookId).future);
    final accountsById = {for (final account in accounts) account.id: account};
    final sourceAccount = accountsById[_accountId];
    final targetAccount = accountsById[_toAccountId];
    final isTransfer = _kind == TransactionKind.transfer;
    final isCrossCurrency =
        isTransfer &&
        sourceAccount != null &&
        targetAccount != null &&
        sourceAccount.currencyCode != targetAccount.currencyCode;
    final amountMinor = _parseAmount(_amountController);
    final toAmountText = _toAmountController.text.trim();
    final toAmountMinor = isCrossCurrency
        ? _parseAmount(_toAmountController)
        : null;

    final errors = <String>[
      if (sourceAccount == null) _accountRequiredError,
      if (amountMinor == null)
        _amountController.text.trim().isEmpty
            ? _amountRequiredError
            : _amountParsingError,
      if (isTransfer && targetAccount == null) _toAccountRequiredError,
      if (isTransfer &&
          sourceAccount != null &&
          sourceAccount.id == _toAccountId)
        _sameAccountError,
      if (isCrossCurrency && toAmountText.isEmpty) _toAmountRequiredError,
      if (isCrossCurrency && toAmountText.isNotEmpty && toAmountMinor == null)
        _toAmountParsingError,
      if (!isTransfer && _categoryId == null) _categoryRequiredError,
    ];
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
      });
      return;
    }

    final input = FinanceTransactionInput.tryCreate(
      bookId: bookId,
      accountId: _accountId!,
      kind: _kind,
      amountMinor: amountMinor!,
      toAccountId: isTransfer ? _toAccountId : null,
      categoryId: isTransfer ? null : _categoryId,
      counterpartyId: isTransfer ? null : _counterpartyId,
      toAmountMinor: toAmountMinor,
      note: _noteController.text,
    );

    switch (input) {
      case Invalid(errors: final commandErrors):
        setState(() {
          _errors = commandErrors;
        });
      case Valid(value: final validInput):
        await _persist(validInput);
    }
  }

  Future<void> _persist(FinanceTransactionInput input) async {
    setState(() {
      _errors = const [];
      _isBusy = true;
    });

    try {
      final result = await ref
          .read(financeTransactionControllerProvider.notifier)
          .save(
            input,
            occurredAt: _occurredAt(),
            existing: widget.transaction,
            newCounterpartyName: _newCounterpartyName,
          );
      if (!mounted) {
        return;
      }
      switch (result) {
        case Valid():
          _showSuccessMessage();
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
        _errors = const [_unexpectedError];
        _isBusy = false;
      });
    }
  }

  /// Дата операции с текущим временем: время сохраняет порядок операций дня.
  DateTime _occurredAt() {
    final now = DateTime.now();
    return DateTime(
      _date.year,
      _date.month,
      _date.day,
      now.hour,
      now.minute,
      now.second,
    );
  }

  void _showSuccessMessage() {
    final localizations = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? localizations.transactionsUpdatedMessage
              : localizations.transactionsCreatedMessage,
        ),
      ),
    );
  }

  int? _parseAmount(TextEditingController controller) =>
      switch (parseMoneyInput(controller.text)) {
        MoneyInputValue(minorUnits: final value) => value,
        MoneyInputFailure() => null,
      };

  String? _selectedCategoryName(List<FinanceCategory> categories) {
    final categoryId = _categoryId;
    if (categoryId == null) {
      return null;
    }
    for (final category in categories) {
      if (category.id == categoryId) {
        return category.name;
      }
    }
    return null;
  }

  /// Фактический курс по введенным суммам; `null`, пока суммы не разобраны.
  String? _rateText(
    BuildContext context,
    AppLocalizations localizations,
    FinanceAccount? sourceAccount,
    FinanceAccount? targetAccount,
  ) {
    final amountMinor = _parseAmount(_amountController);
    final toAmountMinor = _parseAmount(_toAmountController);
    if (sourceAccount == null ||
        targetAccount == null ||
        amountMinor == null ||
        toAmountMinor == null ||
        amountMinor <= 0) {
      return null;
    }
    final rate = formatTransferRate(
      context,
      toAmountMinor / amountMinor,
      sourceCurrencyCode: sourceAccount.currencyCode,
      targetCurrencyCode: targetAccount.currencyCode,
    );
    return '${localizations.transactionFormRateLabel}: $rate';
  }

  Future<String> _activeBookId() async {
    final book = await ref.read(activeBookProvider.future);
    return book?.id ?? '';
  }

  List<String> _errorMessages(AppLocalizations localizations) => [
    for (final error in _errors)
      _transactionFormErrorMessage(error, localizations),
  ];
}
