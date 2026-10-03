/// Снимок базы данных для резервной копии.
///
/// Абстракция, за которой скрыт механизм создания однофайлового снимка
/// (ADR-0006, решение 6.4). Реализация слоя данных создает снимок командой
/// `VACUUM INTO` текущей базы.
abstract interface class DatabaseSnapshotService {
  /// Создает снимок текущей базы в файле [targetPath].
  Future<void> snapshotTo(String targetPath);
}
