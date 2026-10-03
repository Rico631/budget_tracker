/// Модели финансового домена.
///
/// Модели разнесены по отдельным файлам по агрегатам; этот модуль реэкспортирует
/// их для совместимости существующих импортов. Новый код должен импортировать
/// конкретные файлы моделей напрямую.
library;

export 'analytics_models.dart';
export 'finance_account.dart';
export 'finance_bank.dart';
export 'finance_book.dart';
export 'finance_category.dart';
export 'finance_currency.dart';
export 'finance_transaction.dart';
export 'transactions_journal.dart';
