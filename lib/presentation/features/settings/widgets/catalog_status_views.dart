import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Состояние загрузки справочника в подэкране раздела «Настройки».
class CatalogLoadingView extends StatelessWidget {
  const CatalogLoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Пустое состояние списка справочника.
///
/// Пустой список показывается только тогда, когда справочник действительно пуст:
/// при ошибке загрузки подэкран показывает ошибку с повтором, чтобы пустой
/// список не выглядел готовым результатом.
class CatalogEmptyView extends StatelessWidget {
  const CatalogEmptyView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}

/// Ошибка загрузки справочника с действием повторной загрузки.
class CatalogErrorView extends StatelessWidget {
  const CatalogErrorView({
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
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(localizations.catalogRetryAction),
            ),
          ],
        ),
      ),
    );
  }
}
