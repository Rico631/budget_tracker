import 'package:budget_tracker/core/di/data_management_providers.dart';
import 'package:budget_tracker/domain/models/database_registry_models.dart';
import 'package:budget_tracker/domain/usecases/database_restore_usecases.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Известные базы данных и указатель активной.
///
/// Реестр читается при открытии списка баз и не зависит от активной книги,
/// поэтому провайдер не семейный.
final databaseListProvider = FutureProvider<DatabaseRegistryState>(
  (ref) => ref.watch(databaseRegistryProvider).load(),
);

/// Управление базами и действиями раздела «Экспорт и базы данных».
///
/// Единственная точка входа вью в операции раздела: страницы работают с
/// контроллером и не обращаются к use cases напрямую.
class DataManagementController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Создает резервную копию данных и возвращает `false`, если пользователь
  /// отменил диалог сохранения.
  Future<bool> backup() async {
    state = const AsyncLoading();
    try {
      final saved = await ref
          .read(databaseBackupUseCasesProvider)
          .exportBackup();
      state = const AsyncData(null);
      return saved;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Восстанавливает базу из выбранной пользователем копии.
  ///
  /// Текущая база не меняется при отказе; мягкий перезапуск после успеха
  /// выполняет экран.
  Future<RestoreResult> restore() async {
    state = const AsyncLoading();
    try {
      final result = await ref.read(databaseRestoreUseCasesProvider).restore();
      state = const AsyncData(null);
      return result;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Делает базу [id] активной.
  ///
  /// После успешной мутации список перечитывается: переключение меняет отметку
  /// текущей базы, а удаление убирает запись из списка (ADR-0006, решение 6.8).
  /// Мягкий перезапуск выполняет экран: реестр уже указывает на новую активную
  /// базу, и приложение должно открыть ее.
  Future<void> makeActive(String id) async {
    state = const AsyncLoading();
    try {
      await ref.read(databaseRegistryProvider).setActive(id);
      ref.invalidate(databaseListProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }

  /// Удаляет базу [id] вместе с ее файлом.
  ///
  /// Удаление единственной базы разрешено: реестр регистрирует вместо нее
  /// исходную базу, а заводское состояние создает первый запуск.
  Future<void> delete(String id) async {
    state = const AsyncLoading();
    try {
      await ref.read(databaseRegistryProvider).deleteDatabase(id);
      ref.invalidate(databaseListProvider);
      state = const AsyncData(null);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}

final dataManagementControllerProvider =
    AsyncNotifierProvider<DataManagementController, void>(
      DataManagementController.new,
    );
