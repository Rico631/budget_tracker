import 'package:budget_tracker/core/di/app_providers.dart';
import 'package:budget_tracker/core/di/data_management_providers.dart';
import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:budget_tracker/domain/services/csv_journal_exporter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Ключ селектора языка выгрузки.
const Key journalExportLanguageSelectorKey = Key(
  'journalExportLanguageSelector',
);

/// Ключ действия выгрузки журнала.
const Key journalExportButtonKey = Key('journalExportButton');

/// Профиль CSV-файла для языка выгрузки [language].
///
/// Заголовки колонок и метки типов операций берутся из локализации выбранного
/// языка выгрузки, а не из языка интерфейса: выбранный язык определяет и текст
/// файла, и разделители (ADR-0006, решение 6.3).
CsvExportProfile csvExportProfileForLanguage(CsvExportLanguage language) {
  final localizations = lookupAppLocalizations(Locale(language.name));

  return csvExportProfileFor(
    language: language,
    headers: (
      occurredAt: localizations.journalExportColumnOccurredAt,
      kind: localizations.journalExportColumnKind,
      account: localizations.journalExportColumnAccount,
      currency: localizations.journalExportColumnCurrency,
      category: localizations.journalExportColumnCategory,
      counterparty: localizations.journalExportColumnCounterparty,
      note: localizations.journalExportColumnNote,
      amount: localizations.journalExportColumnAmount,
      toAccount: localizations.journalExportColumnToAccount,
      toCurrency: localizations.journalExportColumnToCurrency,
      toAmount: localizations.journalExportColumnToAmount,
    ),
    kindLabels: {
      TransactionKind.income: localizations.transactionKindIncomeLabel,
      TransactionKind.expense: localizations.transactionKindExpenseLabel,
      TransactionKind.transfer: localizations.transactionKindTransferLabel,
    },
  );
}

/// Экран выгрузки журнала операций активной книги.
///
/// Язык выгрузки по умолчанию — язык приложения; его можно сменить перед
/// выгрузкой. Выгрузка односторонняя: импорта CSV в приложение нет
/// (ADR-0006, решение 6.1).
class JournalExportPage extends ConsumerStatefulWidget {
  const JournalExportPage({super.key});

  /// Открывает экран из подэкрана «Экспорт и базы данных».
  static Future<void> open(BuildContext context) {
    return Navigator.of(
      context,
    ).push<void>(MaterialPageRoute(builder: (_) => const JournalExportPage()));
  }

  @override
  ConsumerState<JournalExportPage> createState() => _JournalExportPageState();
}

class _JournalExportPageState extends ConsumerState<JournalExportPage> {
  /// Выбранный язык выгрузки; `null` означает язык приложения.
  CsvExportLanguage? _language;
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final book = ref.watch(activeBookProvider).value;
    final language = _selectedLanguage(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.dataManagementJournalExportItemLabel),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            localizations.journalExportLanguageLabel,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          SegmentedButton<CsvExportLanguage>(
            key: journalExportLanguageSelectorKey,
            segments: [
              ButtonSegment(
                value: CsvExportLanguage.ru,
                label: Text(localizations.journalExportLanguageRussianLabel),
              ),
              ButtonSegment(
                value: CsvExportLanguage.en,
                label: Text(localizations.journalExportLanguageEnglishLabel),
              ),
            ],
            selected: {language},
            onSelectionChanged: _isBusy
                ? null
                : (selection) => setState(() => _language = selection.first),
          ),
          const SizedBox(height: 24),
          if (book == null)
            Text(
              localizations.journalExportNoBookMessage,
              style: theme.textTheme.bodyMedium,
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: journalExportButtonKey,
            onPressed: _isBusy || book == null
                ? null
                : () => _export(bookId: book.id, language: language),
            child: Text(localizations.journalExportAction),
          ),
          if (_isBusy)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  CsvExportLanguage _selectedLanguage(BuildContext context) =>
      _language ??
      CsvExportLanguage.fromLanguageCode(
        Localizations.localeOf(context).languageCode,
      );

  Future<void> _export({
    required String bookId,
    required CsvExportLanguage language,
  }) async {
    final localizations = AppLocalizations.of(context);
    setState(() => _isBusy = true);
    try {
      final saved = await ref
          .read(journalExportUseCasesProvider)
          .exportJournal(
            bookId: bookId,
            profile: csvExportProfileForLanguage(language),
          );
      if (!mounted) {
        return;
      }
      if (saved) {
        _showMessage(localizations.journalExportSuccessMessage);
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(localizations.journalExportFailureMessage);
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
