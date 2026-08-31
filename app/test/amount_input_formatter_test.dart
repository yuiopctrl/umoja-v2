import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/core/utils/amount_input_formatter.dart';

TextEditingValue _typed(String text) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: text.length),
);

void main() {
  group('ThousandsInputFormatter', () {
    const formatter = ThousandsInputFormatter();

    test('groups a whole number into thousands as it is typed', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _typed('10000'),
      );
      expect(result.text, '10,000');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('groups a larger whole number correctly', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _typed('1234567'),
      );
      expect(result.text, '1,234,567');
    });

    test('keeps a decimal point and caps the decimal part at 2 digits', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _typed('10000.567'),
      );
      expect(result.text, '10,000.56');
    });

    test('strips non-digit characters other than a single decimal point', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _typed('10,000abc'),
      );
      expect(result.text, '10,000');
    });

    test('collapses multiple decimal points into one', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _typed('1.2.3'),
      );
      expect(result.text, '1.23');
    });

    test('strips a leading zero once a following digit is typed', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _typed('01000'),
      );
      expect(result.text, '1,000');
    });

    test('an empty field stays empty', () {
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        _typed(''),
      );
      expect(result.text, '');
    });

    test('inserting a digit in the middle keeps the cursor after that digit, '
        'not jumped to the end', () {
      // "10,000" with cursor after the first "1" (offset 1), inserting
      // "5" there types "1" + "5" + "0,000" -> raw "150000".
      final oldValue = TextEditingValue(
        text: '10,000',
        selection: const TextSelection.collapsed(offset: 1),
      );
      final newValue = TextEditingValue(
        text: '150,000',
        selection: const TextSelection.collapsed(offset: 2),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '150,000');
      // Two digits ("1", "5") precede the cursor -> offset 2 in the
      // re-formatted text (no separator between them).
      expect(result.selection.baseOffset, 2);
    });
  });

  group('parseAmountInput', () {
    test('strips grouping commas before parsing', () {
      expect(parseAmountInput('10,000'), 10000.0);
      expect(parseAmountInput('1,234,567.89'), 1234567.89);
    });

    test('parses a plain unformatted number unchanged', () {
      expect(parseAmountInput('5000'), 5000.0);
    });

    test('returns null for an empty or whitespace-only string', () {
      expect(parseAmountInput(''), isNull);
      expect(parseAmountInput('   '), isNull);
    });

    test('returns null for non-numeric input', () {
      expect(parseAmountInput('abc'), isNull);
    });
  });
}
