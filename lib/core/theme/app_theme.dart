import 'package:budget_tracker/core/theme/app_semantic_colors.dart';
import 'package:flutter/material.dart';

/// Единая тема приложения: Material 3 с бирюзовым акцентом
/// (`docs/adr/0001-budget-tracker-concept-and-ux.md`, решение 9.1).
///
/// Экраны получают цвета и шрифт из темы и не задают собственную палитру. Тёмная
/// тема не вводится: ADR-0001 не содержит такого решения.
abstract final class AppTheme {
  /// Семейство шрифта приложения: Open Sans встроен в сборку как asset, поэтому
  /// текст не зависит от сети и от шрифтов устройства.
  static const String fontFamily = 'OpenSans';

  /// Бирюзовый акцентный цвет интерфейса.
  static const Color seedColor = Colors.teal;

  static ThemeData get light => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
    useMaterial3: true,
    fontFamily: fontFamily,
    extensions: const <ThemeExtension<dynamic>>[AppSemanticColors.light],
  );
}