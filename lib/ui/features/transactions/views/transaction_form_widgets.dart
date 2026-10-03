part of 'transaction_form_page.dart';

/// Локализованное сообщение ошибки формы операции по коду ошибки.
///
/// Коды ошибок формы (`_accountRequiredError` и другие) и коды ошибок домена
/// (`transactionKindChangeRejectedError` и другие) сопоставляются строкам
/// локализации в одном месте, чтобы форма не хранила список сообщений.
String _transactionFormErrorMessage(
  String error,
  AppLocalizations localizations,
) => switch (error) {
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
  _accountRequiredError => localizations.transactionFormAccountRequiredError,
  _toAccountRequiredError =>
    localizations.transactionFormToAccountRequiredError,
  _sameAccountError => localizations.transactionFormSameAccountError,
  _amountRequiredError => localizations.transactionFormAmountRequiredError,
  _amountParsingError => localizations.transactionFormAmountInvalidError,
  _toAmountRequiredError => localizations.transactionFormToAmountRequiredError,
  _toAmountParsingError => localizations.transactionFormToAmountInvalidError,
  _categoryRequiredError => localizations.transactionFormCategoryRequiredError,
  _ => localizations.transactionFormSaveErrorMessage,
};

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
