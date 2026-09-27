import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/services/bank_color_rule.dart';
import 'package:budget_tracker/presentation/features/accounts/widgets/bank_avatar.dart';
import 'package:budget_tracker/presentation/features/settings/widgets/bank_rgba_color_dialog.dart';
import 'package:flutter/material.dart';

/// Предустановленные цвета банка: 16 HEX-цветов из справочника
/// `docs/reference-data/banks.md` (ADR-0004, решение 4.10).
///
/// Это единственное место, где перечислены цвета набора, поэтому расширение не
/// требует ни миграции данных, ни изменения формы банка.
const List<String> bankColorPalette = <String>[
  '#1F1F1F',
  '#6E6E6E',
  '#C8102E',
  '#EF3124',
  '#F58220',
  '#FFB400',
  '#FFDD2D',
  '#54B948',
  '#21A038',
  '#007A33',
  '#007A78',
  '#00A4E4',
  '#1E88E5',
  '#0072CE',
  '#003087',
  '#6B2DAF',
];

/// Ключ варианта «без цвета».
const Key bankColorNoneOptionKey = Key('bankColorNoneOption');

/// Ключ варианта набора с цветом [colorHex].
Key bankColorOptionKey(String colorHex) => Key('bankColorOption:$colorHex');

/// Ключ варианта подбора произвольного цвета.
const Key bankColorCustomOptionKey = Key('bankColorCustomOption');

/// Результат выбора цвета банка.
///
/// `colorHex == null` означает «без цвета». Отсутствие результата (`null` вместо
/// [BankColorSelection]) означает отказ от выбора, поэтому форма различает сброс
/// цвета и закрытие набора.
class BankColorSelection {
  const BankColorSelection(this.colorHex);

  final String? colorHex;
}

/// Набор цветов банка: открывается поверх формы банка.
///
/// Первый вариант — «без цвета», затем предустановленные цвета, последний —
/// кружок «+», который открывает подбор произвольного цвета (ADR-0004, 4.10).
class BankColorPickerSheet extends StatelessWidget {
  const BankColorPickerSheet({super.key, required this.selectedHex});

  /// Сохраненный цвет банка; `null` — «без цвета».
  final String? selectedHex;

  /// Показывает набор цветов банка и возвращает выбор пользователя.
  static Future<BankColorSelection?> show(
    BuildContext context, {
    String? selectedHex,
  }) {
    return showModalBottomSheet<BankColorSelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BankColorPickerSheet(selectedHex: selectedHex),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final normalizedSelected = normalizeBankColorHex(selectedHex);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.bankFormColorLabel,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _ColorOption(
                  optionKey: bankColorNoneOptionKey,
                  color: theme.colorScheme.surfaceContainerHighest,
                  icon: Icons.block,
                  isSelected: normalizedSelected == null,
                  semanticLabel: localizations.bankFormColorNoneLabel,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(const BankColorSelection(null)),
                ),
                for (final hex in bankColorPalette)
                  _ColorOption(
                    optionKey: bankColorOptionKey(hex),
                    color: bankColorFromHex(hex)!,
                    isSelected: normalizedSelected == hex,
                    semanticLabel: hex,
                    onTap: () =>
                        Navigator.of(context).pop(BankColorSelection(hex)),
                  ),
                _ColorOption(
                  optionKey: bankColorCustomOptionKey,
                  color: theme.colorScheme.surfaceContainerHighest,
                  icon: Icons.add,
                  isSelected:
                      normalizedSelected != null &&
                      !bankColorPalette.contains(normalizedSelected),
                  semanticLabel: localizations.bankColorCustomLabel,
                  onTap: () => _pickCustomColor(context, normalizedSelected),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Открывает подбор произвольного цвета поверх набора и возвращает выбор
  /// банка, если пользователь подтвердил цвет.
  Future<void> _pickCustomColor(
    BuildContext context,
    String? initialHex,
  ) async {
    final colorHex = await showBankRgbaColorDialog(
      context,
      initialHex: initialHex,
    );
    if (!context.mounted || colorHex == null) {
      return;
    }
    Navigator.of(context).pop(BankColorSelection(colorHex));
  }
}

/// Кружок набора: цвет, признак выбора и доступное описание варианта.
class _ColorOption extends StatelessWidget {
  const _ColorOption({
    required this.optionKey,
    required this.color,
    required this.isSelected,
    required this.semanticLabel,
    required this.onTap,
    this.icon,
  });

  final Key optionKey;
  final Color color;
  final bool isSelected;

  /// Описание варианта: HEX-цвет, подпись «без цвета» или «свой цвет».
  final String semanticLabel;

  final VoidCallback onTap;

  /// Значок варианта, пока он не выбран: у служебных вариантов — иконка, чтобы
  /// нейтральный цвет не путался с серым цветом набора.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground =
        ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black87;

    return Semantics(
      button: true,
      selected: isSelected,
      label: semanticLabel,
      child: Tooltip(
        message: semanticLabel,
        child: InkWell(
          key: optionKey,
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
                width: isSelected ? 3 : 1,
              ),
            ),
            child: switch ((isSelected, icon)) {
              (true, _) => Icon(Icons.check, size: 20, color: foreground),
              (false, final value?) => Icon(
                value,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              _ => null,
            },
          ),
        ),
      ),
    );
  }
}
