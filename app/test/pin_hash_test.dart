import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/security/data/pin_hash.dart';

void main() {
  group('hashPin', () {
    test('never returns the plaintext PIN itself', () {
      final hash = hashPin('1234', 'somesalt');
      expect(hash, isNot('1234'));
      expect(hash.contains('1234'), isFalse);
    });

    test('is deterministic for the same PIN and salt', () {
      expect(hashPin('1234', 'salt-a'), hashPin('1234', 'salt-a'));
    });

    test(
      'is salted: the same PIN with a different salt hashes differently',
      () {
        expect(hashPin('1234', 'salt-a'), isNot(hashPin('1234', 'salt-b')));
      },
    );

    test('different PINs with the same salt hash differently', () {
      expect(hashPin('1234', 'salt-a'), isNot(hashPin('4321', 'salt-a')));
    });
  });

  group('generateSalt', () {
    test('produces a non-empty, non-deterministic value', () {
      final a = generateSalt();
      final b = generateSalt();
      expect(a, isNotEmpty);
      expect(a, isNot(b));
    });
  });
}
