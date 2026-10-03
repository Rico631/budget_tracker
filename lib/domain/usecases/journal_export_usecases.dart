import 'dart:typed_data';

import 'package:budget_tracker/domain/repositories/file_dialogs.dart';
import 'package:budget_tracker/domain/repositories/finance_repositories.dart';
import 'package:budget_tracker/domain/services/csv_journal_exporter.dart';
import 'package:budget_tracker/domain/services/export_file_name_rule.dart';

/// Выгрузка журнала операций книги в CSV-файл.
///
/// Выгрузка односторонняя: импорта CSV в приложение нет (ADR-0006, решение 6.1).
/// Сценарий только читает данные: отказ диалога сохранения и ошибка записи не
/// изменяют данные приложения.
class JournalExportUseCases {
  JournalExportUseCases({
    required this.transactions,
    required this.files,
    this.exporter = const CsvJournalExporter(),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final TransactionsRepository transactions;
  final FileDialog files;
  final CsvJournalExporter exporter;
  final DateTime Function() _clock;

  /// Сохраняет журнал книги [bookId] с профилем [profile].
  ///
  /// Имя файла формируется по маске `bt_YYYYMMDDHHmmss.csv` в момент выгрузки.
  /// Возвращает `true`, если файл сохранен, и `false`, если пользователь отменил
  /// диалог сохранения. Ошибка записи пробрасывается вызывающему: UI показывает
  /// сообщение о неуспешной выгрузке.
  Future<bool> exportJournal({
    required String bookId,
    required CsvExportProfile profile,
  }) async {
    final rows = await transactions.listJournalForExport(bookId);
    final bytes = Uint8List.fromList(
      encodeCsvBytes(exporter.build(rows: rows, profile: profile)),
    );

    final saved = await files.saveBytes(
      fileName: exportFileName(timestamp: _clock(), extension: 'csv'),
      bytes: bytes,
      mimeType: 'text/csv',
    );
    return saved != null;
  }
}
