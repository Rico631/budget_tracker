import 'package:budget_tracker/domain/models/finance_models.dart';
import 'package:flutter/material.dart';

/// Разбирает HEX-цвет вида `#RRGGBB` или `#AARRGGBB`.
///
/// Некорректное значение не является цветом и возвращает `null`: вызывающая
/// сторона подставляет нейтральный цвет темы. Функция общая для маркера банка и
/// палитры выбора цвета, чтобы правило разбора было в одном месте.
Color? bankColorFromHex(String? hex) {
  if (hex == null) {
    return null;
  }
  final value = hex.trim().replaceFirst('#', '').toUpperCase();
  if (value.length != 6 && value.length != 8) {
    return null;
  }
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) {
    return null;
  }
  return Color(value.length == 6 ? 0xFF000000 | parsed : parsed);
}

/// Маркер банка: круг с сохраненным HEX-цветом банка и буквенным обозначением
/// из наименования банка.
///
/// Иконки банков по сети не загружаются, поэтому приложение остается
/// offline-first, а `iconDomain` используется только как данные записи. Если
/// цвет не задан или задан некорректно, используется нейтральный цвет темы.
class BankAvatar extends StatelessWidget {
  const BankAvatar({super.key, required this.bank, this.size = 40});

  final FinanceBank bank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final backgroundColor =
        bankColorFromHex(bank.colorHex) ??
        theme.colorScheme.surfaceContainerHighest;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      child: Text(
        _letter,
        style: theme.textTheme.titleMedium?.copyWith(
          color: _foregroundColor(backgroundColor),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String get _letter {
    final name = bank.name.trim();
    return name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
  }

  Color _foregroundColor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}