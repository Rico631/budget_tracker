import 'package:budget_tracker/core/di/app_lifecycle_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/database_registry_models.dart';
import 'package:budget_tracker/presentation/features/settings/widgets/catalog_status_views.dart';
import 'package:budget_tracker/presentation/providers/data_management_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Ключ элемента списка баз.
Key databaseListEntryKey(String id) => Key('databaseListEntry_$id');

/// Ключ действия «Сделать активной» для базы [id].
Key databaseListMakeActiveKey(String id) => Key('databaseListMakeActive_$id');

/// Ключ действия «Удалить» для базы [id].
Key databaseListDeleteKey(String id) => Key('databaseListDelete_$id');

/// Ключ подтверждения удаления в диалоге.
const Key databaseListDeleteConfirmKey = Key('databaseListDeleteConfirm');

/// Ключ отмены удаления в диалоге.
const Key databaseListDeleteCancelKey = Key('databaseListDeleteCancel');

/// Подпись базы в списке: дата и время создания записи реестра.
///
/// Время показывается вместе с датой: базы, созданные в один день, иначе
/// неразличимы в списке.
String formatDatabaseEntryLabel(String localeTag, DateTime createdAt) =>
    DateFormat.yMMMMd(localeTag).add_Hm().format(createdAt);

/// Подэкран «Базы данных».
///
/// Показывает известные базы с отметкой текущей, позволяет сделать неактивную
/// базу активной и удалить базу. Активную базу удалить нельзя, пока в списке
/// есть другие базы; единственную базу удалить можно — вместо нее создается
/// новая база в заводском состоянии (ADR-0006, решение 6.8). После переключения
/// или удаления приложение перезапускается и открывает активную базу.
class DatabaseListPage extends ConsumerWidget {
  const DatabaseListPage({super.key});

  /// Открывает подэкран из подэкрана «Экспорт и базы данных».
  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const DatabaseListPage()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.dataManagementDatabaseListItemLabel),
      ),
      body: ref
          .watch(databaseListProvider)
          .when(
            loading: () => const CatalogLoadingView(),
            error: (error, stackTrace) => CatalogErrorView(
              message: localizations.databaseListLoadErrorMessage,
              onRetry: () => ref.invalidate(databaseListProvider),
            ),
            data: (state) => ListView(
              children: [
                for (final entry in state.entries)
                  _DatabaseTile(
                    entry: entry,
                    isActive: entry.id == state.activeId,
                    isOnlyEntry: state.entries.length == 1,
                  ),
              ],
            ),
          ),
    );
  }
}

class _DatabaseTile extends ConsumerWidget {
  const _DatabaseTile({
    required this.entry,
    required this.isActive,
    required this.isOnlyEntry,
  });

  final DatabaseEntry entry;
  final bool isActive;
  final bool isOnlyEntry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final canDelete = !isActive || isOnlyEntry;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        key: databaseListEntryKey(entry.id),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isActive
                        ? Icons.check_circle_outline
                        : Icons.storage_outlined,
                    color: isActive ? theme.colorScheme.primary : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatCreatedAt(context, entry.createdAt),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_sourceLabel(localizations, entry.source)} · '
                          '${entry.fileName}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Text(
                      localizations.databaseListCurrentBadge,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              if (!isActive || canDelete) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (!isActive)
                      TextButton(
                        key: databaseListMakeActiveKey(entry.id),
                        onPressed: () => _makeActive(context, ref),
                        child: Text(localizations.databaseListMakeActiveAction),
                      ),
                    if (canDelete)
                      TextButton(
                        key: databaseListDeleteKey(entry.id),
                        onPressed: () => _delete(context, ref),
                        child: Text(localizations.databaseListDeleteAction),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatCreatedAt(BuildContext context, DateTime createdAt) =>
      formatDatabaseEntryLabel(
        Localizations.localeOf(context).toLanguageTag(),
        createdAt,
      );

  String _sourceLabel(
    AppLocalizations localizations,
    DatabaseSource source,
  ) => switch (source) {
    DatabaseSource.original => localizations.databaseListSourceOriginalLabel,
    DatabaseSource.imported => localizations.databaseListSourceImportedLabel,
    DatabaseSource.backup => localizations.databaseListSourceBackupLabel,
  };

  /// Делает базу активной и перезапускает приложение.
  Future<void> _makeActive(BuildContext context, WidgetRef ref) async {
    final localizations = AppLocalizations.of(context);
    final restart = ref.read(appRestartProvider);

    try {
      await ref
          .read(dataManagementControllerProvider.notifier)
          .makeActive(entry.id);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      _showMessage(context, localizations.databaseListMakeActiveFailureMessage);
      return;
    }

    if (!context.mounted) {
      return;
    }
    restart();
  }

  /// Удаляет базу после подтверждения пользователем.
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final localizations = AppLocalizations.of(context);
    final restart = ref.read(appRestartProvider);

    final confirmed = await _confirmDeletion(context);
    if (!confirmed || !context.mounted) {
      return;
    }

    try {
      await ref.read(dataManagementControllerProvider.notifier).delete(entry.id);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      _showMessage(context, localizations.databaseListDeleteFailureMessage);
      return;
    }

    if (!context.mounted) {
      return;
    }
    restart();
  }

  /// Подтверждение удаления.
  ///
  /// Удаление единственной базы сообщает, что вместо нее будет создана новая
  /// база в заводском состоянии: отказ в диалоге ничего не меняет.
  Future<bool> _confirmDeletion(BuildContext context) async {
    final localizations = AppLocalizations.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizations.databaseListDeleteDialogTitle),
        content: Text(
          isOnlyEntry
              ? localizations.databaseListDeleteOnlyDialogMessage
              : localizations.databaseListDeleteDialogMessage(
                  _formatCreatedAt(context, entry.createdAt),
                ),
        ),
        actions: [
          TextButton(
            key: databaseListDeleteCancelKey,
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(localizations.databaseListDeleteDialogCancelAction),
          ),
          FilledButton(
            key: databaseListDeleteConfirmKey,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(localizations.databaseListDeleteAction),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
