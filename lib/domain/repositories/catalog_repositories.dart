import 'package:budget_tracker/domain/models/finance_models.dart';

/// Справочник валют доступен только для чтения: операции добавления,
/// изменения и удаления валют интерфейсом не предоставляются.
abstract interface class CurrenciesRepository {
  Future<List<FinanceCurrency>> list();
  Future<List<FinanceCurrency>> search(String query);
  Future<FinanceCurrency?> getByCode(String code);
}
