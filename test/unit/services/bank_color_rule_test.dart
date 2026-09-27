import 'package:budget_tracker/domain/services/bank_color_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bank color rule', () {
    test('accepts HEX values with and without the hash', () {
      expect(isBankColorHexAcceptable('#1E88E5'), isTrue);
      expect(isBankColorHexAcceptable('1e88e5'), isTrue);
      expect(isBankColorHexAcceptable('  #1e88e5 '), isTrue);
      expect(isBankColorHexAcceptable('#00FF00FF'), isTrue);
    });

    test('treats an absent color as acceptable', () {
      expect(isBankColorHexAcceptable(null), isTrue);
      expect(isBankColorHexAcceptable(''), isTrue);
      expect(isBankColorHexAcceptable('   '), isTrue);
    });

    test('rejects values that are not HEX colors', () {
      expect(isBankColorHexAcceptable('синий'), isFalse);
      expect(isBankColorHexAcceptable('#12345'), isFalse);
      expect(isBankColorHexAcceptable('#GGGGGG'), isFalse);
      expect(isBankColorHexAcceptable('1e88e5ff0'), isFalse);
    });

    test('normalizes the saved value to upper case with the hash', () {
      expect(normalizeBankColorHex('#1e88e5'), '#1E88E5');
      expect(normalizeBankColorHex('1e88e5'), '#1E88E5');
    });

    test('canonicalizes an opaque alpha channel to six digits', () {
      expect(normalizeBankColorHex('#FF1E88E5'), '#1E88E5');
      expect(normalizeBankColorHex('ff00ff00'), '#00FF00');
    });

    test('keeps a transparent color as eight digits', () {
      expect(normalizeBankColorHex('#801E88E5'), '#801E88E5');
      expect(normalizeBankColorHex('001e88e5'), '#001E88E5');
    });

    test('returns no color for absent or invalid values', () {
      expect(normalizeBankColorHex(null), isNull);
      expect(normalizeBankColorHex('  '), isNull);
      // Некорректное значение отклоняется доменом раньше нормализации.
      expect(normalizeBankColorHex('синий'), isNull);
    });
  });
}
