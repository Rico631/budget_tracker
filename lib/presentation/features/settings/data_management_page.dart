import 'package:budget_tracker/core/di/app_lifecycle_providers.dart';
import 'package:budget_tracker/core/di/data_management_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/repositories/database_validation.dart';
import 'package:budget_tracker/domain/usecases/database_restore_usecases.dart';
import 'package:budget_tracker/presentation/features/settings/database_list_page.dart';
import 'package:budget_tracker/presentation/features/settings/journal_export_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ пункта выгрузки журнала.
const Key dataManagementJournalExportItemKey = Key(
  'dataManagementJournalExportItem',
);

/// Ключ пункта создания резервной копии.
const Key dataManagementBackupItemKey = Key('dataManagementBackupItem');

/// Ключ пункта восстановления из копии.
const Key dataManagementRestoreItemKey = Key('dataManagementRestoreItem');

/// Ключ пункта списка баз данных.
const Key dataManagementDatabaseListItemKey = Key(
  'dataManagementDatabaseListItem',
);

/// Подэкран «Экспорт и базы данных».
///
/// Хаб раздела настроек: выгрузка журнала, создание резервной копии,
/// восстановление из копии и список баз. Действий добавления оболочки подэкран
/// не показывает: операции раздела выполняются его пунктами (ADR-0006,
/// решение 6.11).
class DataManagementPage extends ConsumerStatefulWidget {
  const DataManagementPage({super.key});

  /// Открывает подэкран из раздела «Настройки».
  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const DataManagementPage()));
  }

  @override
  ConsumerState<DataManagementPage> createState() => _DataManagementPageState();
}

class _DataManagementPageState extends ConsumerState<DataManagementPage> {
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.settingsDataManagementItemLabel),
      ),
      body: Column(
        children: [
          if (_isBusy) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              children: [
                ListTile(
                  key: dataManagementJournalExportItemKey,
                  leading: const Icon(Icons.description_outlined),
                  title: Text(
                    localizations.dataManagementJournalExportItemLabel,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isBusy ? null : () => JournalExportPage.open(context),
                ),
                ListTile(
                  key: dataManagementBackupItemKey,
                  leading: const Icon(Icons.save_outlined),
                  title: Text(localizations.dataManagementBackupItemLabel),
                  onTap: _isBusy ? null : _createBackup,
                ),
                ListTile(
                  key: dataManagementRestoreItemKey,
                  leading: const Icon(Icons.settings_backup_restore),
                  title: Text(localizations.dataManagementRestoreItemLabel),
                  onTap: _isBusy ? null : _restore,
                ),
                ListTile(
                  key: dataManagementDatabaseListItemKey,
                  leading: const Icon(Icons.storage_outlined),
                  title: Text(
                    localizations.dataManagementDatabaseListItemLabel,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _isBusy ? null : () => DatabaseListPage.open(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Создает резервную копию данных.
  ///
  /// Отмена диалога сохранения не считается ошибкой: файл не создается, данные
  /// приложения не изменяются, поэтому сообщение не показывается.
  Future<void> _createBackup() async {
    final localizations = AppLocalizations.of(context);
    setState(() => _isBusy = true);
    try {
      final saved = await ref
          .read(databaseBackupUseCasesProvider)
          .exportBackup();
      if (!mounted) {
        return;
      }
      if (saved) {
        _showMessage(localizations.dataManagementBackupSuccessMessage);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(localizations.dataManagementBackupFailureMessage);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  /// Восстанавливает базу из выбранной пользователем копии.
  ///
  /// После успеха приложение перезапускается и открывает восстановленную базу;
  /// при отказе активная база не меняется, а пользователь видит причину.
  Future<void> _restore() async {
    final localizations = AppLocalizations.of(context);
    final restart = ref.read(appRestartProvider);

    setState(() => _isBusy = true);

    final RestoreResult result;
    try {
      result = await ref.read(databaseRestoreUseCasesProvider).restore();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isBusy = false);
      _showMessage(localizations.dataManagementRestoreFileUnreadableMessage);
      return;
    }

    if (!mounted) {
      return;
    }

    switch (result) {
      case RestoreCancelled():
        setState(() => _isBusy = false);
      case RestoreFailed(:final reason):
        setState(() => _isBusy = false);
        _showMessage(_restoreFailureMessage(reason, localizations));
      case RestoreSucceeded():
        // Индикатор снимается до перезапуска: корень пересоздает дерево, и
        // состояние этого экрана больше не используется.
        setState(() => _isBusy = false);
        restart();
    }
  }

  String _restoreFailureMessage(
    RestoreFailureReason reason,
    AppLocalizations localizations,
  ) => switch (reason) {
    RestoreFailureReason.notAnApplicationDatabase =>
      localizations.dataManagementRestoreNotApplicationDatabaseMessage,
    RestoreFailureReason.unsupportedSchemaVersion =>
      localizations.dataManagementRestoreUnsupportedVersionMessage,
    RestoreFailureReason.fileUnreadable =>
      localizations.dataManagementRestoreFileUnreadableMessage,
  };

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
