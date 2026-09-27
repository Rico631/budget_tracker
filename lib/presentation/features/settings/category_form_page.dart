import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/common/validation_result.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/usecases/catalog_usecases.dart';
import 'package:budget_tracker/presentation/features/transactions/widgets/transaction_tile.dart';
import 'package:budget_tracker/presentation/providers/catalog_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ поля наименования категории.
const Key categoryFormNameFieldKey = Key('categoryFormNameField');

/// Ключ выбора типа категории «Доход».
const Key categoryFormKindIncomeKey = Key('categoryFormKindIncome');

/// Ключ выбора типа категории «Расход».
const Key categoryFormKindExpenseKey = Key('categoryFormKindExpense');

/// Ключ действия сохранения категории.
const Key categoryFormSaveButtonKey = Key('categoryFormSaveButton');

/// Ключ действия удаления категории.
const Key categoryFormDeleteButtonKey = Key('categoryFormDeleteButton');

/// Ключ подтверждения удаления категории в диалоге.
const Key categoryFormDeleteConfirmButtonKey = Key(
  'categoryFormDeleteConfirmButton',
);

/// Ключ отказа от удаления категории в диалоге.
const Key categoryFormDeleteCancelButtonKey = Key(
  'categoryFormDeleteCancelButton',
);

/// Ключ блока ошибок формы категории.
const Key categoryFormErrorsKey = Key('categoryFormErrors');

/// Ключ пояснения о базовой категории.
const Key categoryFormFallbackNoticeKey = Key('categoryFormFallbackNotice');

/// Код ошибки формы: тип категории не выбран.
const String _kindRequiredError = 'kind is required.';

/// Код ошибки формы: сохранение завершилось непредвиденной ошибкой.
const String _unexpectedError = 'unexpected.';

/// Код ошибки формы: удаление завершилось непредвиденной ошибкой.
const String _deleteFailedError = 'delete failed.';

/// Форма создания и переименования категории.
///
/// Создание требует наименование и явно выбранный тип; тип существующей
/// категории неизменяем и показывается только для чтения. Базовая категория
/// открывается только для чтения: она не переименовывается и не удаляется, а
/// удаление небазовой категории переносит ее операции в базовую категорию того
/// же типа после подтверждения (ADR-0004, решения 4.1-4.4).
class CategoryFormPage extends ConsumerStatefulWidget {
  const CategoryFormPage({super.key, required this.bookId, this.category});

  /// Книга категории: категории принадлежат книге.
  final String bookId;

  /// Редактируемая категория; `null` — создание новой категории.
  final FinanceCategory? category;

  /// Открывает форму категории и возвращает `true`, если данные изменились.
  static Future<bool?> open(
    BuildContext context, {
    required String bookId,
    FinanceCategory? category,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CategoryFormPage(bookId: bookId, category: category),
      ),
    );
  }

  @override
  ConsumerState<CategoryFormPage> createState() => _CategoryFormPageState();
}

class _CategoryFormPageState extends ConsumerState<CategoryFormPage> {
  late final TextEditingController _nameController;
  TransactionKind? _kind;
  List<String> _errors = const [];
  bool _isBusy = false;

  bool get _isEditing => widget.category != null;

  /// Базовая категория не переименовывается и не удаляется (ADR-0004, 4.2).
  bool get _isFallback => widget.category?.isFallback ?? false;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _kind = category?.kind;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final kind = _kind;
    final localErrors = <String>[
      if (name.isEmpty) catalogNameRequiredError,
      if (kind == null) _kindRequiredError,
    ];

    if (localErrors.isNotEmpty) {
      setState(() {
        _errors = localErrors;
      });
      return;
    }

    setState(() {
      _errors = const [];
      _isBusy = true;
    });

    try {
      final controller = ref.read(categoryControllerProvider.notifier);
      final result = _isEditing
          ? await controller.rename(widget.category!, name)
          : await controller.create(
              bookId: widget.bookId,
              name: name,
              kind: kind!,
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
    final category = widget.category;
    if (category == null) {
      return;
    }

    final confirmed = await _confirmDeletion();
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _errors = const [];
      _isBusy = true;
    });

    try {
      final result = await ref
          .read(categoryControllerProvider.notifier)
          .delete(category);
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

  /// Подтверждение удаления прямо сообщает о переносе операций в базовую
  /// категорию: отказ в диалоге не изменяет данные (ADR-0004, решение 4.1).
  Future<bool?> _confirmDeletion() {
    final localizations = AppLocalizations.of(context);

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.categoryFormDeleteDialogTitle),
        content: Text(localizations.categoryFormDeleteDialogMessage),
        actions: [
          TextButton(
            key: categoryFormDeleteCancelButtonKey,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.categoryFormDeleteDialogCancelAction),
          ),
          FilledButton(
            key: categoryFormDeleteConfirmButtonKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.categoryFormDeleteAction),
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
        catalogNameRequiredError => localizations.categoryFormNameRequiredError,
        categoryNameDuplicateError =>
          localizations.categoryFormNameDuplicateError,
        categoryFallbackRenameRejectedError =>
          localizations.categoryFormFallbackRenameRejectedError,
        categoryFallbackDeleteRejectedError =>
          localizations.categoryFormFallbackDeleteRejectedError,
        categoryFallbackMissingError =>
          localizations.categoryFormFallbackMissingError,
        categoryKindChangeRejectedError ||
        categoryKindNotAllowedError =>
          localizations.categoryFormKindNotAllowedError,
        _kindRequiredError => localizations.categoryFormKindRequiredError,
        _deleteFailedError => localizations.categoryFormDeleteErrorMessage,
        _ => localizations.categoryFormSaveErrorMessage,
      };

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final errors = _errorMessages(localizations);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing
              ? localizations.categoryFormEditTitle
              : localizations.categoryFormCreateTitle,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isFallback) ...[
            _FallbackNotice(
              key: categoryFormFallbackNoticeKey,
              message: localizations.categoryFormFallbackNotice,
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            key: categoryFormNameFieldKey,
            controller: _nameController,
            enabled: !_isFallback && !_isBusy,
            decoration: InputDecoration(
              labelText: localizations.categoryFormNameLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_isEditing)
            InputDecorator(
              decoration: InputDecoration(
                labelText: localizations.categoryFormKindLabel,
                border: const OutlineInputBorder(),
              ),
              child: Text(transactionKindLabel(localizations, _kind!)),
            )
          else
            _KindSelector(
              selected: _kind,
              enabled: !_isBusy,
              onSelected: (kind) => setState(() {
                _kind = kind;
                _errors = const [];
              }),
            ),
          const SizedBox(height: 12),
          if (errors.isNotEmpty) _ErrorSummary(messages: errors),
          if (!_isFallback) ...[
            FilledButton(
              key: categoryFormSaveButtonKey,
              onPressed: _isBusy ? null : _save,
              child: Text(localizations.categoryFormSaveAction),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              TextButton(
                key: categoryFormDeleteButtonKey,
                onPressed: _isBusy ? null : _delete,
                child: Text(localizations.categoryFormDeleteAction),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Выбор типа новой категории.
///
/// Тип выбирается явно при создании и не изменяется позже, поэтому выбор
/// предлагается только в режиме создания (ADR-0004, решение 4.4).
class _KindSelector extends StatelessWidget {
  const _KindSelector({
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final TransactionKind? selected;
  final bool enabled;
  final ValueChanged<TransactionKind> onSelected;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          localizations.categoryFormKindLabel,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final option in const [
              TransactionKind.income,
              TransactionKind.expense,
            ])
              ChoiceChip(
                key: _kindKey(option),
                label: Text(transactionKindLabel(localizations, option)),
                selected: option == selected,
                onSelected: enabled ? (_) => onSelected(option) : null,
              ),
          ],
        ),
      ],
    );
  }

  Key _kindKey(TransactionKind kind) => switch (kind) {
    TransactionKind.income => categoryFormKindIncomeKey,
    _ => categoryFormKindExpenseKey,
  };
}

/// Пояснение о базовой категории в режиме только для чтения.
class _FallbackNotice extends StatelessWidget {
  const _FallbackNotice({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.lock_outline, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message, style: theme.textTheme.bodyMedium),
        ),
      ],
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
      key: categoryFormErrorsKey,
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
