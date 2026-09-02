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

    /// Types [text] one character at a time through the formatter,
    /// exactly like a real text field does — each step's output feeds
    /// the next step's `oldValue`, so a cursor bug that only appears
    /// after several keystrokes (as opposed to pasting the whole string
    /// at once) is caught.
    TextEditingValue typeSequentially(String text) {
      var value = TextEditingValue.empty;
      for (final char in text.split('')) {
        final cursor = value.selection.end.clamp(0, value.text.length);
        final inserted = TextEditingValue(
          text:
              value.text.substring(0, cursor) +
              char +
              value.text.substring(cursor),
          selection: TextSelection.collapsed(offset: cursor + 1),
        );
        value = formatter.formatEditUpdate(value, inserted);
      }
      return value;
    }

    test(
      'typing "1000.5" digit-by-digit keeps the decimal point and digit '
      'after it in place — never reordered or hidden behind the separator',
      () {
        final result = typeSequentially('1000.5');
        expect(result.text, '1,000.5');
        expect(result.selection.baseOffset, result.text.length);
      },
    );

    test('typing "1000.50" digit-by-digit produces exactly that value', () {
      final result = typeSequentially('1000.50');
      expect(result.text, '1,000.50');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('typing "1234567.89" digit-by-digit groups thousands and keeps both '
        'decimal digits, cursor at the end', () {
      final result = typeSequentially('1234567.89');
      expect(result.text, '1,234,567.89');
      expect(result.selection.baseOffset, result.text.length);
    });

    test('the cursor lands immediately AFTER a freshly-typed decimal point '
        '(not before it) so the next digit is inserted into the decimal '
        'part rather than corrupting the integer part', () {
      // "1,000" fully typed, cursor at the end (offset 5); typing "."
      // there.
      final oldValue = TextEditingValue(
        text: '1,000',
        selection: const TextSelection.collapsed(offset: 5),
      );
      final newValue = TextEditingValue(
        text: '1,000.',
        selection: const TextSelection.collapsed(offset: 6),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '1,000.');
      expect(result.selection.baseOffset, 6);
    });

    test('backspace immediately after the decimal point removes the point, '
        'not a digit before it', () {
      // "1,000.5" with cursor right after "." (offset 6, before the "5"),
      // backspacing there removes the "." -> "1,0005" raw, cursor at 5.
      final oldValue = TextEditingValue(
        text: '1,000.5',
        selection: const TextSelection.collapsed(offset: 6),
      );
      final newValue = TextEditingValue(
        text: '1,0005',
        selection: const TextSelection.collapsed(offset: 5),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '10,005');
    });

    test('selecting the whole field and pasting a new value replaces it '
        'cleanly with the cursor at the end', () {
      final oldValue = TextEditingValue(
        text: '1,000.50',
        selection: const TextSelection(baseOffset: 0, extentOffset: 8),
      );
      final newValue = TextEditingValue(
        text: '1234567.89',
        selection: const TextSelection.collapsed(offset: 10),
      );
      final result = formatter.formatEditUpdate(oldValue, newValue);
      expect(result.text, '1,234,567.89');
      expect(result.selection.baseOffset, result.text.length);
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
