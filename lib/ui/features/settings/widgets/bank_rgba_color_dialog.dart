import 'package:budget_tracker/core/l10n/app_localizations.dart';
import 'package:budget_tracker/domain/services/bank_color_rule.dart';
import 'package:budget_tracker/ui/features/accounts/widgets/bank_avatar.dart';
import 'package:flutter/material.dart';

/// Ключ ползунка красного канала.
const Key bankRgbaRedSliderKey = Key('bankRgbaRedSlider');

/// Ключ ползунка зеленого канала.
const Key bankRgbaGreenSliderKey = Key('bankRgbaGreenSlider');

/// Ключ ползунка синего канала.
const Key bankRgbaBlueSliderKey = Key('bankRgbaBlueSlider');

/// Ключ ползунка непрозрачности.
const Key bankRgbaAlphaSliderKey = Key('bankRgbaAlphaSlider');

/// Ключ поля кода цвета.
const Key bankRgbaCodeFieldKey = Key('bankRgbaCodeField');

/// Ключ предпросмотра подобранного цвета.
const Key bankRgbaPreviewKey = Key('bankRgbaPreview');

/// Ключ блока ошибки кода цвета.
const Key bankRgbaErrorKey = Key('bankRgbaError');

/// Ключ действия подтверждения цвета.
const Key bankRgbaApplyButtonKey = Key('bankRgbaApplyButton');

/// Ключ действия отказа от подбора цвета.
const Key bankRgbaCancelButtonKey = Key('bankRgbaCancelButton');

/// Код ошибки диалога: введенный код цвета не разбирается.
const String _invalidCodeError = 'color code cannot be parsed.';

/// Показывает подбор произвольного цвета банка с прозрачностью.
///
/// Возвращает HEX-значение выбранного цвета (`#RRGGBB` или `#AARRGGBB`) либо
/// `null`, если пользователь отказался от подбора (ADR-0004, решение 4.10).
Future<String?> showBankRgbaColorDialog(
  BuildContext context, {
  String? initialHex,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => BankRgbaColorDialog(initialHex: initialHex),
  );
}

/// Диалог подбора произвольного цвета по каналам RGBA.
///
/// Цвет задается ползунками каналов, а поле кода позволяет ввести точное
/// значение. Цвет с полной непрозрачностью возвращается как `#RRGGBB`, поэтому
/// представление значения совпадает с предустановленными цветами набора.
class BankRgbaColorDialog extends StatefulWidget {
  const BankRgbaColorDialog({super.key, this.initialHex});

  /// Исходное значение: сохраненный цвет банка; `null` — цвет не задан.
  final String? initialHex;

  @override
  State<BankRgbaColorDialog> createState() => _BankRgbaColorDialogState();
}

class _BankRgbaColorDialogState extends State<BankRgbaColorDialog> {
  /// Цвет подбора по умолчанию, если у банка нет сохраненного цвета.
  static const Color _defaultColor = Color(0xFF1E88E5);

  late final TextEditingController _codeController;
  late double _red;
  late double _green;
  late double _blue;
  late double _alpha;
  List<String> _errors = const [];

  @override
  void initState() {
    super.initState();
    final color = bankColorFromHex(widget.initialHex) ?? _defaultColor;

    _red = (color.r * 255).roundToDouble();
    _green = (color.g * 255).roundToDouble();
    _blue = (color.b * 255).roundToDouble();
    _alpha = (color.a * 255).roundToDouble();
    _codeController = TextEditingController(text: _codeFor(_color));
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Color get _color => Color.fromARGB(
    _alpha.round(),
    _red.round(),
    _green.round(),
    _blue.round(),
  );

  /// Код цвета в каноническом виде: непрозрачный канал не показывается.
  String _codeFor(Color color) {
    final digits = [color.a, color.r, color.g, color.b]
        .map(
          (channel) =>
              (channel * 255).round().toRadixString(16).padLeft(2, '0'),
        )
        .join();

    return normalizeBankColorHex('#$digits')!;
  }

  void _updateChannel(VoidCallback update) {
    setState(() {
      update();
      _errors = const [];
    });
    _codeController.text = _codeFor(_color);
  }

  void _onCodeChanged(String value) {
    final color = bankColorFromHex(value);

    setState(() {
      _errors = const [];
      if (color != null) {
        _red = (color.r * 255).roundToDouble();
        _green = (color.g * 255).roundToDouble();
        _blue = (color.b * 255).roundToDouble();
        _alpha = (color.a * 255).roundToDouble();
      }
    });
  }

  void _apply() {
    final code = normalizeBankColorHex(_codeController.text);
    if (code == null) {
      setState(() {
        _errors = const [_invalidCodeError];
      });
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(localizations.bankColorCustomLabel),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                key: bankRgbaPreviewKey,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: _color,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ChannelSlider(
              fieldKey: bankRgbaRedSliderKey,
              label: localizations.bankColorChannelRedLabel,
              value: _red,
              onChanged: (value) => _updateChannel(() => _red = value),
            ),
            _ChannelSlider(
              fieldKey: bankRgbaGreenSliderKey,
              label: localizations.bankColorChannelGreenLabel,
              value: _green,
              onChanged: (value) => _updateChannel(() => _green = value),
            ),
            _ChannelSlider(
              fieldKey: bankRgbaBlueSliderKey,
              label: localizations.bankColorChannelBlueLabel,
              value: _blue,
              onChanged: (value) => _updateChannel(() => _blue = value),
            ),
            _ChannelSlider(
              fieldKey: bankRgbaAlphaSliderKey,
              label: localizations.bankColorChannelAlphaLabel,
              value: _alpha,
              onChanged: (value) => _updateChannel(() => _alpha = value),
            ),
            const SizedBox(height: 8),
            TextField(
              key: bankRgbaCodeFieldKey,
              controller: _codeController,
              onChanged: _onCodeChanged,
              decoration: InputDecoration(
                labelText: localizations.bankColorCodeLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_errors.isNotEmpty)
              Padding(
                key: bankRgbaErrorKey,
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  localizations.bankColorCodeInvalidError,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: bankRgbaCancelButtonKey,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(localizations.bankColorDialogCancelAction),
        ),
        FilledButton(
          key: bankRgbaApplyButtonKey,
          onPressed: _apply,
          child: Text(localizations.bankColorDialogApplyAction),
        ),
      ],
    );
  }
}

/// Ползунок одного канала цвета: подпись и текущее значение.
class _ChannelSlider extends StatelessWidget {
  const _ChannelSlider({
    required this.fieldKey,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final Key fieldKey;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${value.round()}', style: theme.textTheme.bodyMedium),
        Slider(
          key: fieldKey,
          min: 0,
          max: 255,
          divisions: 255,
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
