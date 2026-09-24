sealed class ValidationResult<T> {
  const ValidationResult();

  factory ValidationResult.valid(T value) = Valid<T>;

  factory ValidationResult.invalid(List<String> errors) = Invalid<T>;
}

class Valid<T> extends ValidationResult<T> {
  const Valid(this.value);

  final T value;
}

class Invalid<T> extends ValidationResult<T> {
  Invalid(List<String> errors) : errors = List.unmodifiable(errors);

  final List<String> errors;
}
