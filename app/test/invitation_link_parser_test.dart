import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/membership_invitations/domain/invitation_link_parser.dart';

void main() {
  group('parseInvitationToken (Prompt 09G-B1-E4 §F)', () {
    test('accepts a full valid URL', () {
      expect(
        parseInvitationToken('https://umoja.example.org/invite/${'a' * 64}'),
        'a' * 64,
      );
    });

    test('accepts a valid /invite/token app-local path', () {
      expect(parseInvitationToken('/invite/${'b' * 64}'), 'b' * 64);
    });

    test('trims surrounding whitespace', () {
      expect(parseInvitationToken('  /invite/${'c' * 64}  \n'), 'c' * 64);
    });

    test('a query string never contributes to the extracted token', () {
      expect(
        parseInvitationToken(
          'https://umoja.example.org/invite/${'d' * 64}'
          '?x=/invite/${'e' * 64}',
        ),
        'd' * 64,
      );
    });

    test('rejects empty input', () {
      expect(
        () => parseInvitationToken(''),
        throwsA(isA<InvalidInvitationLinkException>()),
      );
    });

    test('rejects whitespace-only input', () {
      expect(
        () => parseInvitationToken('   '),
        throwsA(isA<InvalidInvitationLinkException>()),
      );
    });

    test('rejects /invite/ with no token', () {
      expect(
        () => parseInvitationToken('/invite/'),
        throwsA(isA<InvalidInvitationLinkException>()),
      );
    });

    test('rejects an unrelated path', () {
      expect(
        () => parseInvitationToken('/members/123'),
        throwsA(isA<InvalidInvitationLinkException>()),
      );
    });

    test('rejects extra path segments after the token', () {
      expect(
        () => parseInvitationToken('/invite/${'f' * 64}/extra'),
        throwsA(isA<InvalidInvitationLinkException>()),
      );
    });

    test('rejects a non-http(s) scheme', () {
      expect(
        () => parseInvitationToken('javascript:alert(1)//invite/${'g' * 64}'),
        throwsA(isA<InvalidInvitationLinkException>()),
      );
    });

    test('never accepts a membership_id/group_id/phone/member_number-shaped '
        'value in place of a token', () {
      expect(
        () => parseInvitationToken('membership_id=123'),
        throwsA(isA<InvalidInvitationLinkException>()),
      );
      expect(
        () => parseInvitationToken('0712345678'),
        throwsA(isA<InvalidInvitationLinkException>()),
      );
    });

    test('any host is accepted — only the path is ever used', () {
      // Safe by design: the token is the sole server-validated
      // authority (see invitation_link_parser.dart doc comment) — the
      // host of a pasted URL is never trusted or acted on.
      expect(
        parseInvitationToken(
          'https://totally-unrelated-host.example/invite/${'h' * 64}',
        ),
        'h' * 64,
      );
    });
  });
}
