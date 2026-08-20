import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/core/utils/tanzania_phone_number.dart';

void main() {
  group('TanzaniaPhoneNumber.parse', () {
    test('normalizes a local 0-prefixed number', () {
      expect(TanzaniaPhoneNumber.parse('0712345678').e164, '+255712345678');
    });

    test('normalizes a bare 9-digit subscriber number', () {
      expect(TanzaniaPhoneNumber.parse('712345678').e164, '+255712345678');
    });

    test('normalizes a 255-prefixed number without a plus', () {
      expect(TanzaniaPhoneNumber.parse('255712345678').e164, '+255712345678');
    });

    test('accepts an already-E.164 number unchanged', () {
      expect(TanzaniaPhoneNumber.parse('+255712345678').e164, '+255712345678');
    });

    test('strips spaces, hyphens, and parentheses', () {
      expect(
        TanzaniaPhoneNumber.parse('+255 712 345 678').e164,
        '+255712345678',
      );
      expect(TanzaniaPhoneNumber.parse('0712-345-678').e164, '+255712345678');
      expect(TanzaniaPhoneNumber.parse('(0712) 345 678').e164, '+255712345678');
    });

    test('accepts the 6-prefixed mobile range too', () {
      expect(TanzaniaPhoneNumber.parse('0612345678').e164, '+255612345678');
    });

    test('rejects an empty value', () {
      expect(
        () => TanzaniaPhoneNumber.parse(''),
        throwsA(isA<PhoneNumberException>()),
      );
      expect(
        () => TanzaniaPhoneNumber.parse('   '),
        throwsA(isA<PhoneNumberException>()),
      );
    });

    test('rejects letters', () {
      expect(
        () => TanzaniaPhoneNumber.parse('071234abcd'),
        throwsA(isA<PhoneNumberException>()),
      );
    });

    test('rejects obviously wrong lengths', () {
      expect(
        () => TanzaniaPhoneNumber.parse('071234'),
        throwsA(isA<PhoneNumberException>()),
      );
      expect(
        () => TanzaniaPhoneNumber.parse('07123456789'),
        throwsA(isA<PhoneNumberException>()),
      );
    });

    test('rejects an unsupported/malformed prefix', () {
      // Not a mobile range (6/7): looks like a landline-style number.
      expect(
        () => TanzaniaPhoneNumber.parse('0221234567'),
        throwsA(isA<PhoneNumberException>()),
      );
    });

    test('rejects a +country code that is not Tanzania', () {
      expect(
        () => TanzaniaPhoneNumber.parse('+254712345678'),
        throwsA(isA<PhoneNumberException>()),
      );
    });
  });

  group('TanzaniaPhoneNumber.tryParse', () {
    test('returns a value for valid input', () {
      expect(TanzaniaPhoneNumber.tryParse('0712345678'), isNotNull);
    });

    test('returns null for invalid input instead of throwing', () {
      expect(TanzaniaPhoneNumber.tryParse('not a phone'), isNull);
    });
  });

  group('display', () {
    test('groups the national number for display', () {
      expect(
        TanzaniaPhoneNumber.parse('0712345678').display,
        '+255 712 345 678',
      );
    });
  });

  group('equality', () {
    test('two numbers with the same E.164 value are equal', () {
      expect(
        TanzaniaPhoneNumber.parse('0712345678'),
        TanzaniaPhoneNumber.parse('+255712345678'),
      );
    });
  });
}
