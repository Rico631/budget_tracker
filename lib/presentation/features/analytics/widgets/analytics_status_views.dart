import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Состояние загрузки раздела «Аналитика».
class AnalyticsLoadingView extends StatelessWidget {
  const AnalyticsLoadingView({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

/// Состояние «в книге нет ни одной операции».
///
/// Приглашение указывает раздел, в котором операция создается, и не содержит
/// действия добавления: раздел «Аналитика» работает только на чтение, а
/// `app-navigation` запрещает на нем действия добавления операции и счета.
class AnalyticsEmptyBookView extends StatelessWidget {
  const AnalyticsEmptyBookView({super.key});

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
            Icon(
              Icons.pie_chart_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.analyticsEmptyBookTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              localizations.analyticsEmptyBookMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Сообщение об отсутствии операций за период или по выбранному счету.
///
/// Состояние не показывает пустую диаграмму, нулевые полосы и нулевой итог:
/// отсутствие данных отличается от готового результата.
class AnalyticsEmptyView extends StatelessWidget {
  const AnalyticsEmptyView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

/// Ошибка чтения аналитики с действием повторной загрузки.
///
/// Пустой срез при ошибке не показывается: иначе ошибка локального хранилища
/// выглядела бы как готовый результат за период.
class AnalyticsErrorView extends StatelessWidget {
  const AnalyticsErrorView({
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
              child: Text(localizations.analyticsRetryAction),
            ),
          ],
        ),
      ),
    );
  }
}
