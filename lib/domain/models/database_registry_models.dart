/// Модели реестра баз данных приложения.
///
/// Реестр — доменный концепт (ADR-0006): DTO описывают известные базы и
/// указатель активной, а формат хранения (`db_registry.json`) — деталь
/// реализации слоя данных.
library;

/// Источник базы данных в реестре.
enum DatabaseSource {
  /// Исходная база приложения (`budget_tracker.sqlite`).
  original,

  /// Копия, принятая при восстановлении из резервной копии.
  imported,

  /// Резервная копия, зарегистрированная в приложении.
  backup,
}

/// Запись реестра баз данных.
class DatabaseEntry {
  const DatabaseEntry({
    required this.id,
    required this.fileName,
    required this.createdAt,
    required this.source,
  });

  final String id;

  /// Имя файла базы относительно каталога application support.
  final String fileName;

  final DateTime createdAt;

  final DatabaseSource source;
}

/// Состояние реестра баз: известные базы и указатель активной базы.
class DatabaseRegistryState {
  const DatabaseRegistryState({required this.entries, required this.activeId});

  final List<DatabaseEntry> entries;

  final String activeId;

  /// Запись активной базы.
  DatabaseEntry get activeEntry =>
      entries.firstWhere((entry) => entry.id == activeId);
}
