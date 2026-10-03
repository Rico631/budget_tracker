/// Общая маска файлов выгрузки: `bt_YYYYMMDDHHmmss`.
///
/// Метка времени делает имена уникальными и сортируемыми, а префикс `bt`
/// отличает файлы приложения от посторонних. Маска одна для обоих направлений
/// выгрузки — CSV-журнала и снимка базы, — поэтому собирается одним местом
/// (ADR-0006, решение 6.10).
String exportFileName({
  required DateTime timestamp,
  required String extension,
}) => 'bt_${_datePart(timestamp)}${_timePart(timestamp)}.$extension';

/// Имя файла импортированной копии: `import_YYYYMMDD_HHmmss.sqlite`.
///
/// Копия восстановления отличается от выгрузки префиксом: по имени файла видно,
/// что база появилась в приложении из выбранного пользователем файла, а не была
/// создана выгрузкой (ADR-0006, решения 6.7 и 6.8).
String importedDatabaseFileName(DateTime timestamp) =>
    'import_${_datePart(timestamp)}_${_timePart(timestamp)}.sqlite';

String _datePart(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}'
    '${value.month.toString().padLeft(2, '0')}'
    '${value.day.toString().padLeft(2, '0')}';

String _timePart(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}'
    '${value.minute.toString().padLeft(2, '0')}'
    '${value.second.toString().padLeft(2, '0')}';
