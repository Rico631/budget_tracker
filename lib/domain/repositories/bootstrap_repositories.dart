import 'package:budget_tracker/domain/models/finance_models.dart';

/// Состояние инициализации первого запуска.
enum FirstRunBootstrapStatus { created, alreadyInitialized }

/// Результат инициализации первого запуска.
class FirstRunBootstrapResult {
  const FirstRunBootstrapResult({required this.status, this.book});

  final FirstRunBootstrapStatus status;

  /// Книга по умолчанию: созданная при первом запуске или существующая.
  ///
  /// Значение отсутствует, если признак завершенного первого запуска
  /// установлен, но активной книги в хранилище нет.
  final FinanceBook? book;

  bool get isCreated => status == FirstRunBootstrapStatus.created;
}

/// Однократное наполнение книги по умолчанию и базовых справочников.
abstract interface class FirstRunBootstrapRepository {
  Future<FirstRunBootstrapResult> run({
    required String languageCode,
    required String defaultBookName,
  });
}
