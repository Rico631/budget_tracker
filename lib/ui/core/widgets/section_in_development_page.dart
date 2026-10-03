import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

/// Единое состояние раздела, содержимое которого ещё не реализовано.
///
/// Экран показывает явное сообщение о том, что раздел в разработке, и не
/// выводит пустые списки, нулевые итоги или действия добавления вместо
/// готового результата.
class SectionInDevelopmentPage extends StatelessWidget {
  const SectionInDevelopmentPage({super.key});

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
              Icons.construction_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              localizations.sectionInDevelopmentTitle,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              localizations.sectionInDevelopmentMessage,
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
