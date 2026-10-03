import 'dart:io';

import 'package:budget_tracker/domain/models/database_registry_models.dart';

/// Реестр баз данных приложения.
///
/// Хранит известные базы и указатель активной вне самих баз (ADR-0006,
/// решение 6.7). Реализация слоя данных читает и записывает файл
/// `db_registry.json` в каталоге application support.
abstract interface class DatabaseRegistry {
  /// Каталог application support, в котором лежат файлы баз и реестр.
  Future<Directory> supportDirectory();

  /// Абсолютный путь файла базы с именем [fileName].
  Future<String> pathOf(String fileName);

  /// Читает реестр, создавая или восстанавливая его при необходимости.
  Future<DatabaseRegistryState> load();

  /// Делает базу [id] активной и сохраняет реестр.
  Future<DatabaseRegistryState> setActive(String id);

  /// Регистрирует базу [fileName] как активную и сохраняет реестр.
  Future<DatabaseRegistryState> registerActive({
    required String fileName,
    required DatabaseSource source,
  });

  /// Удаляет базу [id] вместе с ее файлом и сохраняет реестр.
  Future<DatabaseRegistryState> deleteDatabase(String id);
}
