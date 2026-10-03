import 'dart:convert';
import 'dart:io';

import 'package:budget_tracker/domain/models/database_registry_models.dart';
import 'package:budget_tracker/domain/repositories/database_registry.dart';
import 'package:budget_tracker/domain/services/finance_id_generator.dart';
import 'package:path_provider/path_provider.dart';

/// Реестр баз данных приложения: файл `db_registry.json` в каталоге application
/// support рядом с файлами баз (ADR-0006, решение 6.7).
///
/// Указатель активной базы хранится вне самих баз, потому что признак первого
/// запуска лежит в `AppSettings` внутри переключаемой базы: будь указатель там,
/// он менялся бы вместе с базой и не переживал переключение.
///
/// Реестр не обязан существовать до первого обращения: при отсутствии файла он
/// создается с единственной записью — текущей базой как активной. Тот же
/// результат восстанавливается при нечитаемом файле реестра: файлы баз при этом
/// не трогаются.
///
/// Файл реестра мал (единицы килобайт), а меняется только по явному действию
/// пользователя, поэтому его ввод-вывод выполняется синхронно: состояние
/// указателя активной базы не зависит от планировщика, а вызовы остаются
/// асинхронными по подписи, потому что каталог приложения запрашивается у
/// платформы асинхронно.
class FileDatabaseRegistry implements DatabaseRegistry {
  FileDatabaseRegistry({
    Future<Directory> Function()? supportDirectory,
    this.idGenerator = const FinanceIdGenerator(),
    this.registryFileName = 'db_registry.json',
    this.defaultDatabaseFileName = 'budget_tracker.sqlite',
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  /// Версия формата файла реестра.
  static const int formatVersion = 1;

  /// Идентификатор исходной базы.
  ///
  /// Идентификатор постоянный, а не сгенерированный: так состояние реестра на
  /// только что установленном приложении не меняется от запуска к запуску.
  static const String originalEntryId = 'original';

  final Future<Directory> Function() _supportDirectory;

  /// Генератор идентификаторов новых записей реестра.
  final FinanceIdGenerator idGenerator;

  /// Имя файла реестра в каталоге application support.
  final String registryFileName;

  /// Имя файла базы, который приложение открывает без явного пути.
  final String defaultDatabaseFileName;

  /// Каталог application support, в котором лежат файлы баз и реестр.
  @override
  Future<Directory> supportDirectory() => _supportDirectory();

  /// Абсолютный путь файла базы с именем [fileName].
  @override
  Future<String> pathOf(String fileName) async {
    final directory = await supportDirectory();
    return _pathIn(directory, fileName);
  }

  /// Читает реестр, создавая или восстанавливая его при необходимости.
  ///
  /// Отсутствующий файл активной базы отбрасывается: активной становится первая
  /// оставшаяся база, а реестр переписывается (ADR-0006, решение 6.8).
  @override
  Future<DatabaseRegistryState> load() async {
    final directory = await supportDirectory();
    final file = File(_pathIn(directory, registryFileName));
    final parsed = file.existsSync()
        ? _tryParse(file.readAsStringSync())
        : null;
    final state = _normalize(parsed ?? _defaultState(), directory);

    if (parsed == null || !_isSameState(parsed, state)) {
      _write(file, state);
    }

    return state;
  }

  /// Делает базу [id] активной и сохраняет реестр.
  @override
  Future<DatabaseRegistryState> setActive(String id) async {
    final state = await load();
    if (!state.entries.any((entry) => entry.id == id)) {
      throw ArgumentError.value(id, 'id', 'База не найдена в реестре');
    }

    final updated = DatabaseRegistryState(entries: state.entries, activeId: id);
    await _save(updated);
    return updated;
  }

  /// Регистрирует базу [fileName] как активную и сохраняет реестр.
  ///
  /// Используется конвейером восстановления: новая база становится активной
  /// только после успешной проверки (ADR-0006, решение 6.6).
  @override
  Future<DatabaseRegistryState> registerActive({
    required String fileName,
    required DatabaseSource source,
  }) async {
    final state = await load();
    final entry = DatabaseEntry(
      id: idGenerator.generateV7(),
      fileName: fileName,
      createdAt: DateTime.now(),
      source: source,
    );
    final updated = DatabaseRegistryState(
      entries: List.unmodifiable([...state.entries, entry]),
      activeId: entry.id,
    );
    await _save(updated);
    return updated;
  }

  /// Удаляет базу [id] вместе с ее файлом и сохраняет реестр.
  ///
  /// Активную базу удалить нельзя, пока в реестре есть другие базы. Удаление
  /// единственной базы разрешено: вместо нее регистрируется исходная база, а
  /// заводское состояние создает первый запуск (ADR-0006, решение 6.8).
  @override
  Future<DatabaseRegistryState> deleteDatabase(String id) async {
    final state = await load();
    if (!state.entries.any((entry) => entry.id == id)) {
      throw ArgumentError.value(id, 'id', 'База не найдена в реестре');
    }
    if (state.entries.length > 1 && state.activeId == id) {
      throw ArgumentError.value(id, 'id', 'Активную базу удалить нельзя');
    }

    final directory = await supportDirectory();
    final entry = state.entries.firstWhere((item) => item.id == id);
    final file = File(_pathIn(directory, entry.fileName));
    if (file.existsSync()) {
      file.deleteSync();
    }

    final updated = state.entries.length == 1
        ? _defaultState()
        : DatabaseRegistryState(
            entries: List.unmodifiable(
              state.entries.where((item) => item.id != id),
            ),
            activeId: state.activeId,
          );
    await _save(updated);
    return updated;
  }

  Future<void> _save(DatabaseRegistryState state) async {
    final directory = await supportDirectory();
    _write(File(_pathIn(directory, registryFileName)), state);
  }

  void _write(File file, DatabaseRegistryState state) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(_toJson(state)),
      flush: true,
    );
  }

  Map<String, Object?> _toJson(DatabaseRegistryState state) => {
    'version': formatVersion,
    'activeId': state.activeId,
    'entries': [
      for (final entry in state.entries)
        {
          'id': entry.id,
          'fileName': entry.fileName,
          'createdAt': entry.createdAt.toIso8601String(),
          'source': entry.source.name,
        },
    ],
  };

  /// Разбирает содержимое реестра, возвращая `null` для нечитаемого файла.
  DatabaseRegistryState? _tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?> ||
          decoded['version'] != formatVersion) {
        return null;
      }

      final activeId = decoded['activeId'];
      final rawEntries = decoded['entries'];
      if (activeId is! String || rawEntries is! List) {
        return null;
      }

      final entries = <DatabaseEntry>[];
      for (final item in rawEntries) {
        if (item is! Map<String, Object?>) {
          continue;
        }
        final id = item['id'];
        final fileName = item['fileName'];
        if (id is! String || fileName is! String || fileName.isEmpty) {
          continue;
        }
        final createdAt = item['createdAt'];
        entries.add(
          DatabaseEntry(
            id: id,
            fileName: fileName,
            createdAt: createdAt is String
                ? DateTime.tryParse(createdAt) ?? DateTime.now()
                : DateTime.now(),
            source: _sourceByName(item['source']),
          ),
        );
      }

      if (entries.isEmpty) {
        return null;
      }
      return DatabaseRegistryState(
        entries: List.unmodifiable(entries),
        activeId: activeId,
      );
    } on FormatException {
      return null;
    }
  }

  /// Приводит реестр к работоспособному виду.
  DatabaseRegistryState _normalize(
    DatabaseRegistryState state,
    Directory directory,
  ) {
    if (state.entries.isEmpty) {
      return _defaultState();
    }

    var entries = List<DatabaseEntry>.of(state.entries);
    var activeId = entries.any((entry) => entry.id == state.activeId)
        ? state.activeId
        : entries.first.id;

    if (!_fileExists(
      directory,
      entries.firstWhere((e) => e.id == activeId).fileName,
    )) {
      entries = entries.where((entry) => entry.id != activeId).toList();
      if (entries.isEmpty) {
        return _defaultState();
      }
      activeId = entries.first.id;
    }

    if (entries.length == state.entries.length && activeId == state.activeId) {
      return state;
    }
    return DatabaseRegistryState(
      entries: List.unmodifiable(entries),
      activeId: activeId,
    );
  }

  DatabaseRegistryState _defaultState() => DatabaseRegistryState(
    entries: List.unmodifiable([
      DatabaseEntry(
        id: originalEntryId,
        fileName: defaultDatabaseFileName,
        createdAt: DateTime.now(),
        source: DatabaseSource.original,
      ),
    ]),
    activeId: originalEntryId,
  );

  bool _fileExists(Directory directory, String fileName) =>
      File(_pathIn(directory, fileName)).existsSync();

  String _pathIn(Directory directory, String fileName) =>
      '${directory.path}${Platform.pathSeparator}$fileName';

  DatabaseSource _sourceByName(Object? name) =>
      DatabaseSource.values.firstWhere(
        (value) => value.name == name,
        orElse: () => DatabaseSource.imported,
      );

  bool _isSameState(DatabaseRegistryState first, DatabaseRegistryState second) {
    if (first.activeId != second.activeId ||
        first.entries.length != second.entries.length) {
      return false;
    }

    for (var index = 0; index < first.entries.length; index++) {
      final left = first.entries[index];
      final right = second.entries[index];
      if (left.id != right.id ||
          left.fileName != right.fileName ||
          left.source != right.source) {
        return false;
      }
    }

    return true;
  }
}
