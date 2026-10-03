import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/ui/features/transactions/widgets/picker_sheet_view.dart';
import 'package:budget_tracker/ui/features/transactions/view_models/transactions_journal_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ поля поиска категории.
const Key categoryPickerSearchFieldKey = Key('categoryPickerSearchField');

/// Выбор категории дохода или расхода из активных категорий книги.
///
/// Категории фильтруются по типу операции: категория дохода неприменима к
/// расходу и наоборот, а категории перевода в справочнике нет вовсе.
/// Архивированные категории в списке отсутствуют.
class CategoryPickerSheet extends ConsumerStatefulWidget {
  const CategoryPickerSheet({
    super.key,
    required this.bookId,
    required this.kind,
    this.selectedId,
  });

  final String bookId;
  final TransactionKind kind;

  /// Категория операции: выбранная позиция помечается отметкой.
  final String? selectedId;

  /// Показывает выбор категории и возвращает выбранную категорию.
  static Future<FinanceCategory?> show(
    BuildContext context, {
    required String bookId,
    required TransactionKind kind,
    String? selectedId,
  }) {
    return showModalBottomSheet<FinanceCategory>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategoryPickerSheet(
        bookId: bookId,
        kind: kind,
        selectedId: selectedId,
      ),
    );
  }

  @override
  ConsumerState<CategoryPickerSheet> createState() =>
      _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<CategoryPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final source = activeBookCategoriesProvider(widget.bookId);

    return ref
        .watch(source)
        .when(
          loading: () => const PickerSheetLoadingView(),
          error: (error, stackTrace) => PickerSheetErrorView(
            message: localizations.categoryPickerLoadErrorMessage,
            onRetry: () => ref.invalidate(source),
          ),
          data: (categories) => PickerSheetLayout(
            title: localizations.categoryPickerTitle,
            searchHint: localizations.categoryPickerSearchHint,
            searchFieldKey: categoryPickerSearchFieldKey,
            emptyMessage: localizations.categoryPickerEmptyMessage,
            onQueryChanged: (query) => setState(() {
              _query = query;
            }),
            items: [
              for (final category in _matches(categories))
                ListTile(
                  key: ValueKey(category.id),
                  leading: const Icon(Icons.label_outline),
                  title: Text(category.name),
                  trailing: category.id == widget.selectedId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.of(context).pop(category),
                ),
            ],
          ),
        );
  }

  List<FinanceCategory> _matches(List<FinanceCategory> categories) {
    final query = _query.trim().toLowerCase();
    return [
      for (final category in categories)
        if (category.kind == widget.kind &&
            (query.isEmpty || category.name.toLowerCase().contains(query)))
          category,
    ];
  }
}
