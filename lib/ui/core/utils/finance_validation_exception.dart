/// Ошибка валидации домена, которую контроллеры кладут в свое состояние.
///
/// Контроллеры используют один тип, поэтому вью показывают ошибки полей единообразно
/// и не зависят от того, какой контроллер выполнил мутацию.
class FinanceValidationException implements Exception {
  FinanceValidationException(this.errors);

  final List<String> errors;

  @override
  String toString() => errors.join(' ');
}
