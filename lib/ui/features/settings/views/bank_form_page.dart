import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/ui/features/accounts/view_models/account_selection_providers.dart';
import 'package:budget_tracker/domain/common/error_codes.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/usecases/catalog_usecases.dart';
import 'package:budget_tracker/ui/features/accounts/widgets/bank_avatar.dart';
import 'package:budget_tracker/ui/features/settings/widgets/bank_color_picker.dart';
import 'package:budget_tracker/ui/features/settings/view_models/catalog_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ поля наименования банка.
const Key bankFormNameFieldKey = Key('bankFormNameField');

/// Ключ действия сохранения банка.
const Key bankFormSaveButtonKey = Key('bankFormSaveButton');

/// Ключ действия удаления банка.
const Key bankFormDeleteButtonKey = Key('bankFormDeleteButton');

/// Ключ подтверждения удаления банка в диалоге.
const Key bankFormDeleteConfirmButtonKey = Key('bankFormDeleteConfirmButton');

/// Ключ отказа от удаления банка в диалоге.
const Key bankFormDeleteCancelButtonKey = Key('bankFormDeleteCancelButton');

/// Ключ блока ошибок формы банка.
const Key bankFormErrorsKey = Key('bankFormErrors');

/// Ключ маркера цвета в строке формы банка: нажатие открывает набор цветов.
const Key bankFormColorMarkerKey = Key('bankFormColorMarker');

/// Код ошибки формы: сохранение завершилось непредвиденной ошибкой.
const String _unexpectedError = 'unexpected.';

/// Код ошибки формы: удаление завершилось непредвиденной ошибкой.
const String _deleteFailedError = 'delete failed.';

/// Форма создания и переименования банка.
///
/// Банк создается с одним полем наименования и сохраняется без признака
/// предустановки; переименование доступно и предустановленным записям. Удаление
/// подтверждается диалогом, который указывает число счетов с этим банком:
/// у них будет снят признак банка, а остатки и операции не изменятся
/// (ADR-0004, решения 4.7 и 4.8).
class BankFormPage extends ConsumerStatefulWidget {
  const BankFormPage({super.key, this.bookId, this.bank});

  /// Активная книга приложения: нужна только для подсчета затронутых счетов.
  final String? bookId;

  /// Редактируемый банк; `null` — создание нового банка.
  final FinanceBank? bank;

  /// Открывает форму банка и возвращает `true`, если данные изменились.
  static Future<bool?> open(
    BuildContext context, {
    String? bookId,
    FinanceBank? bank,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BankFormPage(bookId: bookId, bank: bank),
      ),
    );
  }

  @override
  ConsumerState<BankFormPage> createState() => _BankFormPageState();
}

class _BankFormPageState extends ConsumerState<BankFormPage> {
  late final TextEditingController _nameController;
  String? _colorHex;
  List<String> _errors = const [];
  bool _isBusy = false;

  bool get _isEditing => widget.bank != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.bank?.name ?? '');
    _colorHex = widget.bank?.colorHex;
  }

  /// Открывает набор цветов банка поверх формы.
  ///
  /// Отказ от выбора (`null` вместо результата) и выбор варианта «без цвета»
  /// различаются: сброс цвета выполняется только явным выбором (ADR-0004, 4.10).
  Future<void> _pickColor() async {
    final selection = await BankColorPickerSheet.show(
      context,
      selectedHex: _colorHex,
    );
    if (!mounted || selection == null) {
      return;
    }
    setState(() {
      _colorHex = selection.colorHex;
      _errors = const [];
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _errors = const [catalogNameRequiredError];
      });
      return;
    }

    setState(() {
      _errors = const [];
      _isBusy = true;
    });

    try {
      final controller = ref.read(bankControllerProvider.notifier);
      final result = _isEditing
          ? await controller.rename(
              bank: widget.bank!,
              name: name,
              colorHex: _colorHex,
              bookId: widget.bookId,
            )
          : await controller.create(
              name: name,
              colorHex: _colorHex,
              bookId: widget.bookId,
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
        _errors = const [_unexpectedError];
        _isBusy = false;
      });
    }
  }

  Future<void> _delete() async {
    final bank = widget.bank;
    if (bank == null) {
      return;
    }

    final affectedAccounts = await _affectedAccountsCount(bank.id);
    if (!mounted) {
      return;
    }

    final confirmed = await _confirmDeletion(affectedAccounts);
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _errors = const [];
      _isBusy = true;
    });

    try {
      final result = await ref
          .read(bankControllerProvider.notifier)
          .delete(bank: bank, bookId: widget.bookId);
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
        _errors = const [_deleteFailedError];
        _isBusy = false;
      });
    }
  }

  /// Число счетов книги, ссылающихся на банк.
  ///
  /// Читаются и архивные счета: удаление банка очищает ссылку у всех счетов,
  /// поэтому число затронутых счетов должно учитывать и их.
  Future<int> _affectedAccountsCount(String bankId) async {
    final bookId = widget.bookId;
    if (bookId == null) {
      return 0;
    }
    final accounts = await ref.read(bookAccountsProvider(bookId).future);
    return accounts.where((account) => account.bankId == bankId).length;
  }

  Future<bool?> _confirmDeletion(int affectedAccounts) {
    final localizations = AppLocalizations.of(context);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.bankFormDeleteDialogTitle),
        content: Text(
          affectedAccounts == 0
              ? localizations.bankFormDeleteDialogMessage
              : localizations.bankFormDeleteDialogWithAccountsMessage(
                  affectedAccounts,
                ),
        ),
        actions: [
          TextButton(
            key: bankFormDeleteCancelButtonKey,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.bankFormDeleteDialogCancelAction),
          ),
          FilledButton(
            key: bankFormDeleteConfirmButtonKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.bankFormDeleteAction),
          ),
        ],
      ),
    );
  }

  List<String> _errorMessages(AppLocalizations localizations) => [
    for (final error in _errors) _messageFor(error, localizations),
  ];

  String _messageFor(String error, AppLocalizations localizations) =>
      switch (error) {
        catalogNameRequiredError => localizations.bankFormNameRequiredError,
        bankNameDuplicateError => localizations.bankFormNameDuplicateError,
        bankColorInvalidError => localizations.bankFormColorInvalidError,
        _deleteFailedError => localizations.bankFormDeleteErrorMessage,
        _ => localizations.bankFormSaveErrorMessage,
      };

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final errors = _errorMessages(localizations);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? localizations.bankFormEditTitle
              : localizations.bankFormCreateTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ColorMarkerButton(
                colorHex: _colorHex,
                name: _nameController.text,
                enabled: !_isBusy,
                onTap: _pickColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: bankFormNameFieldKey,
                  controller: _nameController,
                  enabled: !_isBusy,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: localizations.bankFormNameLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (errors.isNotEmpty) _ErrorSummary(messages: errors),
          FilledButton(
            key: bankFormSaveButtonKey,
            onPressed: _isBusy ? null : _save,
            child: Text(localizations.bankFormSaveAction),
          ),
          if (_isEditing) ...[
            const SizedBox(height: 8),
            TextButton(
              key: bankFormDeleteButtonKey,
              onPressed: _isBusy ? null : _delete,
              child: Text(localizations.bankFormDeleteAction),
            ),
          ],
        ],
      ),
    );
  }
}

/// Маркер цвета в строке формы банка: показывает текущий цвет и открывает набор.
class _ColorMarkerButton extends StatelessWidget {
  const _ColorMarkerButton({
    required this.colorHex,
    required this.name,
    required this.enabled,
    required this.onTap,
  });

  /// Текущий цвет банка; `null` — «без цвета».
  final String? colorHex;

  /// Наименование из строки формы: буква маркера совпадает с маркером списка.
  final String name;

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: localizations.bankFormColorLabel,
      child: Tooltip(
        message: localizations.bankFormColorLabel,
        child: InkWell(
          key: bankFormColorMarkerKey,
          onTap: enabled ? onTap : null,
          customBorder: const CircleBorder(),
          child: BankAvatar(
            bank: FinanceBank(
              id: 'bank-marker',
              name: name,
              colorHex: colorHex,
            ),
            size: 56,
          ),
        ),
      ),
    );
  }
}

/// Блок ошибок формы: показываются все ошибки сразу.
class _ErrorSummary extends StatelessWidget {
  const _ErrorSummary({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      key: bankFormErrorsKey,
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
