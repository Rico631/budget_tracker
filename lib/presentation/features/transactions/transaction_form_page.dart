import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/core/theme/app_semantic_colors.dart';
import 'package:budget_tracker/domain/commands/finance_transaction_input.dart';
import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/features/transactions/widgets/account_picker_sheet.dart';
import 'package:budget_tracker/presentation/features/transactions/widgets/category_picker_sheet.dart';
import 'package:budget_tracker/presentation/features/transactions/widgets/transaction_tile.dart';
import 'package:budget_tracker/presentation/providers/finance_transaction_controller.dart';
import 'package:budget_tracker/presentation/providers/transactions_journal_provider.dart';
import 'package:budget_tracker/presentation/shared/utils/money_formatter.dart';
import 'package:budget_tracker/presentation/shared/utils/money_input_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
  ConsumerState<TransactionFormPage> createState() => _TransactionFormPageState();
}

class _TransactionFormPageState extends ConsumerState<TransactionFormPage> {
  late TransactionKind _kind;
  late final TextEditingController _amountController;
  late final TextEditingController _toAmountController;
  late final TextEditingController _noteController;
  String? _accountId;
  String? _toAccountId;
  String? _categoryId;
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
    final sourceAccount = accountsById[_accountId];
    final targetAccount = accountsById[_toAccountId];
    final isTransfer = _kind == TransactionKind.transfer;
    final isCrossCurrency =
        isTransfer &&
        sourceAccount != null &&
        targetAccount != null &&
        sourceAccount.currencyCode != targetAccount.currencyCode;

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
                child: Text(
                  line,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          if (!isTransfer)
            _PickerField(
              fieldKey: transactionFormCategoryFieldKey,
              label: localizations.transactionFormCategoryLabel,
              value: _selectedCategoryName(categories),
              enabled: !_isBusy,
              onTap: () => _selectCategory(bookId),
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

  void _selectKind(TransactionKind kind) {
    if (_isEditing || kind == _kind) {
      return;
    }
    setState(() {
      _kind = kind;
      // Категория другого типа невалидна, а счет-получатель и сумма зачисления
      // относятся только к переводу, поэтому выбор сбрасывается.
      _categoryId = null;
      _toAccountId = null;
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
      if (isTarget) {
        _toAccountId = account.id;
      } else {
        _accountId = account.id;
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
      _categoryId = category.id;
      _errors = const [];
    });
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
          .save(input, occurredAt: _occurredAt(), existing: widget.transaction);
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
    for (final error in _errors) _messageFor(error, localizations),
  ];

  String _messageFor(String error, AppLocalizations localizations) =>
      switch (error) {
        transferToAmountRequiredError =>
          localizations.transactionFormToAmountRequiredError,
        transferToAmountNotAllowedError =>
          localizations.transactionFormToAmountNotAllowedError,
        transactionToAmountNotAllowedError =>
          localizations.transactionFormToAmountNotAllowedError,
        transactionToAmountNotPositiveError =>
          localizations.transactionFormToAmountInvalidError,
        transactionKindChangeRejectedError =>
          localizations.transactionFormKindChangeRejectedError,
        _accountRequiredError =>
          localizations.transactionFormAccountRequiredError,
        _toAccountRequiredError =>
          localizations.transactionFormToAccountRequiredError,
        _sameAccountError => localizations.transactionFormSameAccountError,
        _amountRequiredError => localizations.transactionFormAmountRequiredError,
        _amountParsingError => localizations.transactionFormAmountInvalidError,
        _toAmountRequiredError =>
          localizations.transactionFormToAmountRequiredError,
        _toAmountParsingError =>
          localizations.transactionFormToAmountInvalidError,
        _categoryRequiredError =>
          localizations.transactionFormCategoryRequiredError,
        _ => localizations.transactionFormSaveErrorMessage,
      };
}

/// Шаг выбора типа операции: «Доход», «Расход» или «Перевод».
///
/// Тип показывается текстом и цветом (ADR 9.1) и выбирается первым шагом
/// (ADR 3.2). При редактировании тип не изменяется, поэтому вместо выбора
/// показывается неинтерактивная подпись: смена типа означала бы другую операцию
/// с другим набором обязательных полей.
class _KindStep extends StatelessWidget {
  const _KindStep({
    required this.kind,
    required this.isEditing,
    required this.onSelected,
  });

  final TransactionKind kind;
  final bool isEditing;
  final ValueChanged<TransactionKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.transactionFormKindLabel,
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        if (isEditing)
          Chip(
            avatar: Icon(_kindIcon(kind), color: _kindColor(context, kind)),
            label: Text(
              transactionKindLabel(localizations, kind),
              style: TextStyle(color: _kindColor(context, kind)),
            ),
          )
        else
          Wrap(
            spacing: 8,
            children: [
              for (final option in TransactionKind.values)
                ChoiceChip(
                  key: _kindKey(option),
                  avatar: Icon(
                    _kindIcon(option),
                    color: _kindColor(context, option),
                  ),
                  label: Text(
                    transactionKindLabel(localizations, option),
                    style: TextStyle(color: _kindColor(context, option)),
                  ),
                  selected: option == kind,
                  onSelected: (_) => onSelected(option),
                ),
            ],
          ),
      ],
    );
  }

  Color _kindColor(BuildContext context, TransactionKind value) =>
      AppSemanticColors.of(context).forKind(value);

  IconData _kindIcon(TransactionKind value) => switch (value) {
    TransactionKind.income => Icons.south_west,
    TransactionKind.expense => Icons.north_east,
    TransactionKind.transfer => Icons.swap_horiz,
  };

  Key _kindKey(TransactionKind value) => switch (value) {
    TransactionKind.income => transactionFormKindIncomeKey,
    TransactionKind.expense => transactionFormKindExpenseKey,
    TransactionKind.transfer => transactionFormKindTransferKey,
  };
}

/// Поле выбора счета или категории: открывает шторку выбора.
class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
  });

  final Key fieldKey;
  final String label;
  final String? value;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        key: fieldKey,
        onTap: enabled ? onTap : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.arrow_drop_down),
          ),
          child: Text(
            value ?? '',
            style: value == null
                ? theme.textTheme.bodyLarge?.copyWith(color: theme.hintColor)
                : theme.textTheme.bodyLarge,
          ),
        ),
      ),
    );
  }
}

/// Поле ввода суммы операции.
class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.fieldKey,
    required this.controller,
    required this.label,
    required this.enabled,
    required this.onChanged,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final String label;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        key: fieldKey,
        controller: controller,
        enabled: enabled,
        onChanged: onChanged,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

/// Поле даты операции: текущая дата по умолчанию, прошедшая — по выбору.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.fieldKey,
    required this.label,
    required this.date,
    required this.enabled,
    required this.onTap,
  });

  final Key fieldKey;
  final String label;
  final DateTime date;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).toLanguageTag();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        key: fieldKey,
        onTap: enabled ? onTap : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          child: Text(DateFormat.yMMMMd(localeTag).format(date)),
        ),
      ),
    );
  }
}

/// Блок ошибок валидации формы: показываются все ошибки сразу.
class _ErrorSummary extends StatelessWidget {
  const _ErrorSummary({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      key: transactionFormErrorsKey,
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final message in messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
