import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/commands/finance_account_input.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/usecases/account_usecases.dart';
import 'package:budget_tracker/presentation/features/accounts/widgets/bank_picker_sheet.dart';
import 'package:budget_tracker/presentation/features/accounts/widgets/currency_picker_sheet.dart';
import 'package:budget_tracker/presentation/providers/accounts_controller.dart';
import 'package:budget_tracker/presentation/shared/utils/money_input_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ поля названия счета.
const Key accountFormNameFieldKey = Key('accountFormNameField');

/// Ключ поля выбора банка.
const Key accountFormBankFieldKey = Key('accountFormBankField');

/// Ключ поля выбора валюты.
const Key accountFormCurrencyFieldKey = Key('accountFormCurrencyField');

/// Ключ поля начального остатка.
const Key accountFormBalanceFieldKey = Key('accountFormBalanceField');

/// Код ошибки формы: введенную сумму не удалось разобрать.
const String _amountParsingError = 'amount cannot be parsed.';

/// Код ошибки формы: действие завершилось непредвиденной ошибкой.
const String _unexpectedError = 'unexpected.';

/// Форма создания и редактирования счета.
///
/// Название, валюта и начальный остаток обязательны, банк необязателен. Валюта
/// выбирается из справочника валют, доступного только для чтения. Начальный
/// остаток не создает операцию дохода: он является данными счета (ADR 2.2).
/// Для счета с операциями смена валюты запрещена, а удаление заменяется
/// предложением архивирования (ADR 4.4).
class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({super.key, this.account});

  /// Редактируемый счет; `null` — создание нового счета.
  final FinanceAccount? account;

  /// Открывает форму счета и возвращает `true`, если счет был изменен.
  static Future<bool?> open(BuildContext context, {FinanceAccount? account}) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AccountFormPage(account: account)),
    );
  }

  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _balanceController;
  String? _currencyCode;
  String? _bankId;
  List<String> _errors = const [];
  bool _isBusy = false;

  bool get _isEditing => widget.account != null;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _nameController = TextEditingController(text: account?.name ?? '');
    _balanceController = TextEditingController(
      text: account == null
          ? '0'
          : (account.initialBalanceMinor / 100).toStringAsFixed(2),
    );
    _currencyCode = account?.currencyCode;
    _bankId = account?.bankId;
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
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final banks = ref.watch(banksProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? localizations.accountFormEditTitle
              : localizations.accountFormCreateTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            key: accountFormNameFieldKey,
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: localizations.accountFormNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            key: accountFormBankFieldKey,
            onTap: banks == null ? null : () => _pickBank(banks),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: localizations.accountFormBankLabel,
                border: const OutlineInputBorder(),
              ),
              child: Text(_bankLabel(localizations, banks)),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            key: accountFormCurrencyFieldKey,
            onTap: _pickCurrency,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: localizations.accountFormCurrencyLabel,
                border: const OutlineInputBorder(),
              ),
              child: Text(_currencyCode ?? ''),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            key: accountFormBalanceFieldKey,
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            decoration: InputDecoration(
              labelText: localizations.accountFormInitialBalanceLabel,
              border: const OutlineInputBorder(),
            ),
          ),
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
            onPressed: _isBusy ? null : _save,
            child: Text(localizations.accountFormSaveAction),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isBusy ? null : _delete,
              child: Text(localizations.accountFormDeleteAction),
            ),
          ],
        ],
      ),
    );
  }

  /// Подпись поля банка: «Без банка», наименование выбранного банка или пустая
  /// строка, пока справочник банков не загружен либо ссылка на банк не найдена
  /// в активном списке.
  String _bankLabel(AppLocalizations localizations, List<FinanceBank>? banks) {
    final bankId = _bankId;
    if (bankId == null) {
      return localizations.accountFormBankNoneLabel;
    }
    for (final bank in banks ?? const <FinanceBank>[]) {
      if (bank.id == bankId) {
        return bank.name;
      }
    }
    return '';
  }

  Future<void> _pickBank(List<FinanceBank> banks) async {
    final selection = await BankPickerSheet.show(
      context,
      banks: banks,
      selectedId: _bankId,
    );
    if (!mounted || selection == null) {
      return;
    }
    setState(() {
      _bankId = selection.bank?.id;
    });
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
    });
  }

  Future<void> _save() async {
    final parsedAmount = parseMoneyInput(_balanceController.text);
    final bookId = widget.account?.bookId ?? await _activeBookId();

    final input = FinanceAccountInput.tryCreate(
      bookId: bookId,
      name: _nameController.text,
      currencyCode: _currencyCode ?? '',
      initialBalanceMinor: parsedAmount is MoneyInputValue
          ? parsedAmount.minorUnits
          : 0,
      bankId: _bankId,
    );

    final errors = <String>[
      if (input case Invalid(errors: final inputErrors)) ...inputErrors,
      if (parsedAmount is! MoneyInputValue) _amountParsingError,
    ];
    if (errors.isNotEmpty) {
      setState(() {
        _errors = errors;
      });
      return;
    }

    final validInput = switch (input) {
      Valid(value: final value) => value,
      Invalid() => null,
    };
    if (validInput == null || !mounted) {
      return;
    }

    setState(() {
      _errors = const [];
      _isBusy = true;
    });

    try {
      final result = await ref
          .read(accountsControllerProvider.notifier)
          .save(validInput, existing: widget.account);
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
        _errors = const [_unexpectedError];
        _isBusy = false;
      });
    }
  }

  Future<void> _delete() async {
    final account = widget.account;
    if (account == null) {
      return;
    }

    setState(() {
      _errors = const [];
      _isBusy = true;
    });

    try {
      final controller = ref.read(accountsControllerProvider.notifier);
      final outcome = await controller.remove(account.bookId, account.id);
      if (!mounted) {
        return;
      }
      if (outcome == AccountRemovalOutcome.archivingRequired) {
        final confirmed = await _confirmArchiving();
        if (!mounted) {
          return;
        }
        if (confirmed != true) {
          setState(() {
            _isBusy = false;
          });
          return;
        }
        await controller.archive(account.bookId, account.id);
        if (!mounted) {
          return;
        }
      }
      Navigator.of(context).pop(true);
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

  Future<bool?> _confirmArchiving() {
    final localizations = AppLocalizations.of(context);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.accountFormArchiveDialogTitle),
        content: Text(localizations.accountFormArchiveDialogMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.accountFormArchiveDialogCancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.accountFormArchiveAction),
          ),
        ],
      ),
    );
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
        accountNameRequiredError => localizations.accountFormNameRequiredError,
        accountCurrencyCodeInvalidError =>
          localizations.accountFormCurrencyInvalidError,
        accountCurrencyChangeRejectedError =>
          localizations.accountFormCurrencyLockedError,
        _amountParsingError => localizations.accountFormAmountInvalidError,
        _ => localizations.accountFormSaveErrorMessage,
      };
}