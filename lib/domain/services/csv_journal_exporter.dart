import 'dart:convert';

import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/models/journal_export_row.dart';

/// Заголовки колонок CSV-выгрузки в порядке колонок файла.
typedef CsvJournalHeaders = ({
  String occurredAt,
  String kind,
  String account,
  String currency,
  String category,
  String counterparty,
  String note,
  String amount,
  String toAccount,
  String toCurrency,
  String toAmount,
});

/// Профиль CSV-файла, зависящий от языка выгрузки (ADR-0006, решение 6.3).
///
/// Разделитель колонок и десятичный знак неразделимы: русский Excel ожидает
/// `;` и запятую, английский — `,` и точку. Заголовки колонок и метки типов
/// операций приходят из локализации выбранного языка, поэтому доменный сервис
/// не зависит от UI и локализации.
class CsvExportProfile {
  const CsvExportProfile({
    required this.columnSeparator,
    required this.decimalSeparator,
    required this.headers,
    required this.kindLabels,
  });

  final String columnSeparator;

  final String decimalSeparator;

  final CsvJournalHeaders headers;

  final Map<TransactionKind, String> kindLabels;
}

/// Язык выгрузки журнала.
///
/// Разделитель колонок и десятичный знак определяются языком и не выбираются по
/// отдельности: русский Excel ожидает `;` и запятую, английский — `,` и точку
/// (ADR-0006, решение 6.3).
enum CsvExportLanguage {
  ru(columnSeparator: ';', decimalSeparator: ','),
  en(columnSeparator: ',', decimalSeparator: '.');

  const CsvExportLanguage({
    required this.columnSeparator,
    required this.decimalSeparator,
  });

  final String columnSeparator;

  final String decimalSeparator;

  /// Язык выгрузки по коду языка приложения; неизвестный код дает `ru`, как и
  /// разрешение локали приложения.
  static CsvExportLanguage fromLanguageCode(String languageCode) =>
      values.firstWhere(
        (value) => value.name == languageCode,
        orElse: () => CsvExportLanguage.ru,
      );
}

/// Профиль CSV-выгрузки для языка [language]: разделители берутся из языка, а
/// заголовки колонок и метки типов операций — из локализации этого языка.
CsvExportProfile csvExportProfileFor({
  required CsvExportLanguage language,
  required CsvJournalHeaders headers,
  required Map<TransactionKind, String> kindLabels,
}) => CsvExportProfile(
  columnSeparator: language.columnSeparator,
  decimalSeparator: language.decimalSeparator,
  headers: headers,
  kindLabels: kindLabels,
);

/// Формирует содержимое CSV-файла с журналом операций.
///
/// Генератор намеренно не использует пакет `csv`: правило экранирования мало и
/// является частью контракта формата (ADR-0006, решение 6.3). Порядок строк
/// повторяет порядок входного списка, поэтому выгрузка не переупорядочивает
/// журнал относительно раздела «Операции».
class CsvJournalExporter {
  const CsvJournalExporter();

  /// Содержимое файла без BOM: строки разделяются `\n`, последняя строка тоже
  /// завершается переводом строки.
  String build({
    required Iterable<JournalExportRow> rows,
    required CsvExportProfile profile,
  }) {
    final buffer = StringBuffer()
      ..writeln(_line(_headerCells(profile), profile));
    for (final row in rows) {
      buffer.writeln(_line(_cells(row, profile), profile));
    }
    return buffer.toString();
  }

  List<String> _headerCells(CsvExportProfile profile) {
    final headers = profile.headers;
    return [
      headers.occurredAt,
      headers.kind,
      headers.account,
      headers.currency,
      headers.category,
      headers.counterparty,
      headers.note,
      headers.amount,
      headers.toAccount,
      headers.toCurrency,
      headers.toAmount,
    ];
  }

  List<String> _cells(JournalExportRow row, CsvExportProfile profile) {
    final isTransfer = row.kind == TransactionKind.transfer;
    final amount = switch (row.kind) {
      TransactionKind.income => row.amountMinor,
      TransactionKind.expense || TransactionKind.transfer => -row.amountMinor,
    };
    final toAmountMinor = row.toAmountMinor ?? row.amountMinor;

    return [
      _formatDate(row.occurredAt),
      profile.kindLabels[row.kind] ?? row.kind.name,
      row.accountName,
      row.currencyCode,
      isTransfer ? '' : row.categoryName ?? '',
      isTransfer ? '' : row.counterpartyName ?? '',
      row.note ?? '',
      _formatAmount(amount, profile),
      isTransfer ? row.toAccountName ?? '' : '',
      isTransfer ? row.toCurrencyCode ?? '' : '',
      isTransfer ? _formatAmount(toAmountMinor, profile) : '',
    ];
  }

  String _line(List<String> cells, CsvExportProfile profile) =>
      cells.map((cell) => _escape(cell, profile)).join(profile.columnSeparator);

  /// Заключает поле в кавычки, если оно содержит разделитель, кавычку или
  /// перевод строки; внутренние кавычки удваиваются.
  String _escape(String value, CsvExportProfile profile) {
    final needsQuotes =
        value.contains(profile.columnSeparator) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) {
      return value;
    }
    return '"${value.replaceAll('"', '""')}"';
  }

  /// ISO-дата `yyyy-MM-dd HH:mm:ss`.
  ///
  /// Компоненты берутся как есть: база хранит время операции в местном времени
  /// пользователя и возвращает его без сдвига.
  String _formatDate(DateTime value) {
    final date =
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    final time =
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  /// Сумма в десятичных единицах без разделителей групп разрядов.
  String _formatAmount(int amountMinor, CsvExportProfile profile) {
    final sign = amountMinor < 0 ? '-' : '';
    final absolute = amountMinor.abs();
    final major = absolute ~/ 100;
    final minor = (absolute % 100).toString().padLeft(2, '0');
    return '$sign$major${profile.decimalSeparator}$minor';
  }
}

/// Кодирует CSV-файл в `UTF-8` с BOM.
///
/// BOM делает файл открываемым в Excel двойным кликом с правильной кодировкой,
/// поэтому байты файла формируются одним местом (ADR-0006, решение 6.3).
List<int> encodeCsvBytes(String csv) => [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
