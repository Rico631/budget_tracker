import 'dart:async';

import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/presentation/features/settings/category_form_page.dart';
import 'package:budget_tracker/presentation/features/settings/widgets/catalog_status_views.dart';
import 'package:budget_tracker/presentation/providers/catalog_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ действия добавления категории на подэкране категорий.
const Key categoriesAddActionKey = Key('categoriesAddAction');

/// Подэкран «Категории»: управление категориями книги.
///
/// Категории разделены по типам: категория дохода неприменима к расходу и
/// наоборот, а категорий перевода не существует, потому что перевод не имеет
/// категории (решение 3.3 ADR-0001). При открытии подэкрана домен идемпотентно
/// гарантирует наличие базовой категории каждого типа (ADR-0004, решение 4.3).
class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});

  /// Открывает подэкран категорий из раздела «Настройки».
  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const CategoriesPage()));
  }

  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  bool _fallbackRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_fallbackRequested) {
      return;
    }
    _fallbackRequested = true;
    unawaited(
      _ensureFallbackCategories(Localizations.localeOf(context).languageCode),
    );
  }

  Future<void> _ensureFallbackCategories(String languageCode) async {
    final book = await ref.read(activeBookProvider.future);
    if (book == null || !mounted) {
      return;
    }

    try {
      await ref
          .read(categoryControllerProvider.notifier)
          .ensureFallbackCategories(
            bookId: book.id,
            languageCode: languageCode,
          );
    } catch (_) {
      // Подэкран остается работоспособным: отсутствующая базовая категория
      // будет создана при следующем открытии, а список читается отдельно.
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final book = ref.watch(activeBookProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.categoriesPageTitle),
        actions: [
          if (book.value != null)
            IconButton(
              key: categoriesAddActionKey,
              onPressed: () =>
                  CategoryFormPage.open(context, bookId: book.value!.id),
              tooltip: localizations.categoriesAddCategoryTooltip,
              icon: const Icon(Icons.add),
            ),
        ],
      ),
      body: book.when(
        loading: () => const CatalogLoadingView(),
        error: (error, stackTrace) => CatalogErrorView(
          message: localizations.catalogLoadErrorMessage,
          onRetry: () => ref.invalidate(activeBookProvider),
        ),
        data: (value) => value == null
            ? CatalogEmptyView(message: localizations.categoriesEmptyMessage)
            : _CategoriesListView(bookId: value.id),
      ),
    );
  }
}

class _CategoriesListView extends ConsumerWidget {
  const _CategoriesListView({required this.bookId});

  final String bookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final source = bookCategoriesAllProvider(bookId);

    return ref.watch(source).when(
      loading: () => const CatalogLoadingView(),
      error: (error, stackTrace) => CatalogErrorView(
        message: localizations.catalogLoadErrorMessage,
        onRetry: () => ref.invalidate(source),
      ),
      data: (categories) {
        final income = [
          for (final category in categories)
            if (category.kind == TransactionKind.income) category,
        ];
        final expense = [
          for (final category in categories)
            if (category.kind == TransactionKind.expense) category,
        ];

        if (income.isEmpty && expense.isEmpty) {
          return CatalogEmptyView(
            message: localizations.categoriesEmptyMessage,
          );
        }

        return ListView(
          children: [
            _CategorySection(
              bookId: bookId,
              title: localizations.categoriesIncomeSectionLabel,
              categories: income,
            ),
            _CategorySection(
              bookId: bookId,
              title: localizations.categoriesExpenseSectionLabel,
              categories: expense,
            ),
          ],
        );
      },
    );
  }
}

/// Секция категорий одного типа.
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.bookId,
    required this.title,
    required this.categories,
  });

  final String bookId;
  final String title;
  final List<FinanceCategory> categories;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(title, style: theme.textTheme.titleMedium),
        ),
        for (final category in categories)
          ListTile(
            key: ValueKey(category.id),
            leading: Icon(
              category.isFallback
                  ? Icons.label_important_outline
                  : Icons.label_outline,
            ),
            title: Text(
              category.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => CategoryFormPage.open(
              context,
              bookId: bookId,
              category: category,
            ),
          ),
      ],
    );
  }
}
