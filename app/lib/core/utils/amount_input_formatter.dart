import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

final _wholeFormat = NumberFormat('#,##0');

/// Live-formats a currency amount as the user types — e.g. typing
/// `10000` renders as `10,000` immediately, matching [formatAmount]'s
/// display grouping everywhere a money amount is entered. Locked
/// design (see CLAUDE.md/UI conventions): every amount-entry field in
/// the app uses this same formatter rather than each screen inventing
/// its own.
///
/// Strips everything but digits and a single decimal point, caps the
/// decimal part at 2 digits (matching [formatAmount]'s `#,##0.##`), and
/// re-derives the cursor position by counting digits rather than
/// characters, so inserting/deleting a digit anywhere in the field
/// never jumps the cursor to the end.
class ThousandsInputFormatter extends TextInputFormatter {
  const ThousandsInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;

    // Anchor the cursor to a specific DIGIT-OR-DOT position (never just a
    // digit count) — counting digits alone cannot distinguish "cursor
    // right before the decimal point" from "cursor right after it" once
    // zero digits follow the dot, which used to snap a freshly-typed "."
    // back to BEFORE itself and corrupt every digit typed after it (the
    // original decimal-entry bug this replaces).
    final cursorIndex = newValue.selection.end.clamp(0, newValue.text.length);
    var contentBeforeCursor = 0;
    var seenDotBeforeCursor = false;
    for (var i = 0; i < cursorIndex; i++) {
      final char = newValue.text[i];
      if (char == '.' && !seenDotBeforeCursor) {
        contentBeforeCursor++;
        seenDotBeforeCursor = true;
      } else if (_digitPattern.hasMatch(char)) {
        contentBeforeCursor++;
      }
    }

    final raw = newValue.text.replaceAll(RegExp(r'[^\d.]'), '');
    final firstDot = raw.indexOf('.');
    final hasDot = firstDot != -1;
    var integerPart = hasDot ? raw.substring(0, firstDot) : raw;
    var decimalPart = hasDot
        ? raw.substring(firstDot + 1).replaceAll('.', '')
        : '';
    if (decimalPart.length > 2) decimalPart = decimalPart.substring(0, 2);
    integerPart = integerPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');

    final formattedInteger = integerPart.isEmpty
        ? ''
        : _wholeFormat.format(int.parse(integerPart));
    final formatted = hasDot
        ? '$formattedInteger.$decimalPart'
        : formattedInteger;

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: _offsetForContentCount(formatted, contentBeforeCursor),
      ),
    );
  }

  static final _digitPattern = RegExp(r'\d');

  static int _offsetForContentCount(String text, int contentCount) {
    if (contentCount <= 0) return 0;
    var seen = 0;
    for (var i = 0; i < text.length; i++) {
      if (text[i] == '.' || _digitPattern.hasMatch(text[i])) {
        seen++;
        if (seen == contentCount) return i + 1;
      }
    }
    return text.length;
  }
}

/// Parses a value out of a [ThousandsInputFormatter]-formatted field —
/// strips grouping commas before parsing. Every amount-entry field's
/// submit handler must use this instead of a raw `double.tryParse`, or
/// the thousands separators inserted while typing would break parsing.
double? parseAmountInput(String text) {
  final cleaned = text.replaceAll(',', '').trim();
  return cleaned.isEmpty ? null : double.tryParse(cleaned);
}
