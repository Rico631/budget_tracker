import 'package:budget_tracker/core/di/data_management_providers.dart';
import 'package:budget_tracker/data/local/database/database_registry.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Известные базы данных и указатель активной.
///
/// Реестр читается при открытии списка баз и не зависит от активной книги,
/// поэтому провайдер не семейный.
final databaseListProvider = FutureProvider<DatabaseRegistryState>(
  (ref) => ref.watch(databaseRegistryProvider).load(),
);

/// Переключение активной базы и удаление баз.
///
/// После успешной мутации список перечитывается: переключение меняет отметку
/// текущей базы, а удаление убирает запись из списка (ADR-0006, решение 6.8).
/// Мягкий перезапуск выполняет экран: реестр уже указывает на новую активную
/// базу, и приложение должно открыть ее.
class DatabaseListController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  /// Делает базу [id] активной.
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

final databaseListControllerProvider =
    AsyncNotifierProvider<DatabaseListController, void>(
      DatabaseListController.new,
    );
