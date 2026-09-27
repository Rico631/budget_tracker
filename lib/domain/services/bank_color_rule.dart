/// Правило HEX-цвета банка (ADR-0004, решение 4.10).
///
/// Цвет банка — данные записи, которые задает пользователь. Значение хранится
/// как `#RRGGBB` в верхнем регистре, а отсутствие цвета (`null` или пустая
/// строка) допустимо: такой банк отображается нейтральным цветом темы, потому
/// что иконки банков по сети не загружаются (решение 5.1 ADR-0001).
///
/// Проверка выполняется в домене, а не только в интерфейсе: палитра формы
/// всегда передает корректное значение, но правило не должно зависеть от того,
/// какой экран вызвал мутацию.
library;

/// Принимаются `#RRGGBB` и `RRGGBB` в любом регистре; 8-значная запись
/// (`#AARRGGBB`) допустима так же, как в разборе цвета маркера банка.
final RegExp _hexColorPattern = RegExp(r'^#?([0-9A-F]{6}|[0-9A-F]{8})$');

/// Является ли значение [value] допустимым цветом банка.
///
/// Незаданный цвет допустим: `null` и пустая строка означают «без цвета».
bool isBankColorHexAcceptable(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty || _hexColorPattern.hasMatch(trimmed.toUpperCase());
}

/// Нормализованный цвет банка или `null`, если цвет не задан.
///
/// Значение приводится к виду `#RRGGBB`, а прозрачный цвет — к `#AARRGGBB`
/// в верхнем регистре. Значение с полностью непрозрачным каналом (`#FFRRGGBB`)
/// канонизируется до `#RRGGBB`, поэтому у одного цвета одно представление.
/// Некорректное значение не является цветом и не сохраняется: домен отклоняет
/// его раньше вызовом [isBankColorHexAcceptable].
String? normalizeBankColorHex(String? value) {
  final trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty) {
    return null;
  }
  final normalized = trimmed.toUpperCase();
  if (!_hexColorPattern.hasMatch(normalized)) {
    return null;
  }

  final withHash = normalized.startsWith('#') ? normalized : '#$normalized';
  final digits = withHash.substring(1);
  if (digits.length == 8) {
    return digits.startsWith('FF') ? '#${digits.substring(2)}' : withHash;
  }
  return withHash;
}
