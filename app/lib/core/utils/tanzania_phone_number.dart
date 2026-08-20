/// Thrown when a phone number cannot be normalized. [message] is safe
/// to show directly to the user.
class PhoneNumberException implements Exception {
  const PhoneNumberException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A normalized Tanzanian mobile phone number.
///
/// Umoja's initial market is Tanzania, so this is a small,
/// purpose-built normalizer rather than a general international phone
/// library. It accepts the common local input shapes and normalizes
/// them to E.164 (`+255XXXXXXXXX`) for Supabase phone-OTP auth. Only
/// mobile numbers (subscriber number starting with 6 or 7) are
/// accepted — Tanzanian SMS-reachable numbers.
class TanzaniaPhoneNumber {
  const TanzaniaPhoneNumber._(this.e164);

  static const _countryCode = '255';
  static const _subscriberLength = 9;
  static final _digitsOnlyPattern = RegExp(r'^\d+$');
  static final _formattingCharsPattern = RegExp(r'[\s\-()]');

  /// The normalized number in E.164 form, e.g. `+255712345678`.
  final String e164;

  /// Parses and normalizes [raw] into a [TanzaniaPhoneNumber].
  ///
  /// Accepts (after stripping spaces/hyphens/parentheses):
  /// `0712345678`, `712345678`, `255712345678`, `+255712345678`.
  /// Throws [PhoneNumberException] with a user-presentable message for
  /// anything else (empty input, non-digit characters, wrong length,
  /// or a subscriber prefix that isn't a Tanzanian mobile range).
  factory TanzaniaPhoneNumber.parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw const PhoneNumberException('Enter a phone number.');
    }

    final stripped = trimmed.replaceAll(_formattingCharsPattern, '');
    final hasPlus = stripped.startsWith('+');
    final digits = hasPlus ? stripped.substring(1) : stripped;

    if (digits.isEmpty || !_digitsOnlyPattern.hasMatch(digits)) {
      throw const PhoneNumberException(
        'Enter a valid phone number using digits only.',
      );
    }

    final String subscriberNumber;
    if (hasPlus) {
      if (!digits.startsWith(_countryCode)) {
        throw const PhoneNumberException(
          'Enter a valid Tanzanian phone number (+255...).',
        );
      }
      subscriberNumber = digits.substring(_countryCode.length);
    } else if (digits.startsWith(_countryCode) &&
        digits.length == _countryCode.length + _subscriberLength) {
      subscriberNumber = digits.substring(_countryCode.length);
    } else if (digits.startsWith('0')) {
      subscriberNumber = digits.substring(1);
    } else {
      subscriberNumber = digits;
    }

    if (subscriberNumber.length != _subscriberLength) {
      throw const PhoneNumberException(
        'Phone number should have 9 digits after the country code, '
        'e.g. 0712345678.',
      );
    }

    if (!subscriberNumber.startsWith('6') &&
        !subscriberNumber.startsWith('7')) {
      throw const PhoneNumberException(
        'Enter a valid Tanzanian mobile number.',
      );
    }

    return TanzaniaPhoneNumber._('+$_countryCode$subscriberNumber');
  }

  /// Like [TanzaniaPhoneNumber.parse], but returns `null` instead of
  /// throwing — convenient for form validators.
  static TanzaniaPhoneNumber? tryParse(String raw) {
    try {
      return TanzaniaPhoneNumber.parse(raw);
    } on PhoneNumberException {
      return null;
    }
  }

  /// A lightly grouped display form, e.g. `+255 712 345 678`.
  String get display {
    final national = e164.substring(1 + _countryCode.length);
    return '+$_countryCode ${national.substring(0, 3)} '
        '${national.substring(3, 6)} ${national.substring(6)}';
  }

  @override
  String toString() => e164;

  @override
  bool operator ==(Object other) =>
      other is TanzaniaPhoneNumber && other.e164 == e164;

  @override
  int get hashCode => e164.hashCode;
}
