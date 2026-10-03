/// Результат разбора введенной пользователем суммы.
sealed class MoneyInputResult {
  const MoneyInputResult();
}

/// Текст разобран в минорные единицы валюты.
class MoneyInputValue extends MoneyInputResult {
  const MoneyInputValue(this.minorUnits);

  final int minorUnits;
}

/// Текст не является корректной суммой: разбор завершился ошибкой.
class MoneyInputFailure extends MoneyInputResult {
  const MoneyInputFailure();
}

/// Разбор введенной суммы в минорные единицы.
///
/// Десятичным разделителем может быть запятая или точка, поэтому ввод
/// `1234,56` и `1 234.56` дает одно и то же значение. Пробелы и другие
/// разделители групп разрядов игнорируются, знак минус поддерживается.
/// Пустой или нечисловой ввод возвращает [MoneyInputFailure], а не 0, чтобы
/// ошибка ввода не превращалась в сохраненную сумму.
MoneyInputResult parseMoneyInput(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return const MoneyInputFailure();
  }

  final normalized = trimmed.replaceAll(_groupSeparators, '');
  final match = _amountPattern.firstMatch(normalized);
  if (match == null) {
    return const MoneyInputFailure();
  }

  try {
    final wholeUnits = int.parse(match.group(2)!);
    if (wholeUnits > _maxWholeUnits) {
      return const MoneyInputFailure();
    }

    final fractionText = match.group(3) ?? '';
    var fractionMinor = int.parse(
      fractionText.padRight(2, '0').substring(0, 2),
    );
    if (fractionText.length > 2 && int.parse(fractionText[2]) >= 5) {
      // Округление до сотых: 100 минорных единиц переносятся в целую часть.
      fractionMinor += 1;
    }

    final minorUnits = wholeUnits * 100 + fractionMinor;
    return MoneyInputValue(match.group(1) == '-' ? -minorUnits : minorUnits);
  } on FormatException {
    return const MoneyInputFailure();
  }
}

/// Разделители групп разрядов, которые игнорируются при разборе.
final RegExp _groupSeparators = RegExp('[\u0020\u00A0\u2009\u202F\u0027]');

final RegExp _amountPattern = RegExp(r'^(-?)(\d+)(?:[.,](\d+))?$');

/// Максимальное число целых единиц, при котором минорные единицы не
/// переполняют целое число.
const int _maxWholeUnits = 92233720368547758;
