import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Общий каркас шторок выбора справочной записи: заголовок, поиск, список и
/// сообщение о пустом результате.
///
/// Каркас общий для выбора счета и выбора категории, потому что обе шторки
/// повторяют образец `bank_picker_sheet.dart` и отличаются только содержимым
/// строк списка.
class PickerSheetLayout extends StatelessWidget {
  const PickerSheetLayout({
    super.key,
    required this.title,
    required this.searchHint,
    required this.searchFieldKey,
    required this.emptyMessage,
    required this.onQueryChanged,
    required this.items,
  });

  final String title;
  final String searchHint;
  final Key searchFieldKey;
  final String emptyMessage;
  final ValueChanged<String> onQueryChanged;

  /// Строки списка в порядке показа.
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(title, style: theme.textTheme.titleLarge),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  key: searchFieldKey,
                  onChanged: onQueryChanged,
                  decoration: InputDecoration(
                    hintText: searchHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    ...items,
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Состояние загрузки справочника в шторке выбора.
class PickerSheetLoadingView extends StatelessWidget {
  const PickerSheetLoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Ошибка загрузки справочника в шторке выбора с действием повторной загрузки.
class PickerSheetErrorView extends StatelessWidget {
  const PickerSheetErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(localizations.transactionsRetryAction),
            ),
          ],
        ),
      ),
    );
  }
}