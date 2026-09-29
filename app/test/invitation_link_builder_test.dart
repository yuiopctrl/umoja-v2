import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/membership_invitations/domain/invitation_link_builder.dart';

void main() {
  group('buildInvitationLinkResult (Prompt 09G-B1-E4 §H)', () {
    test('web: resolves against the browser origin (Uri.base)', () {
      final result = buildInvitationLinkResult('a' * 64, isWebOverride: true);

      expect(result.isConfigured, isTrue);
      expect(result.url, contains('/invite/${'a' * 64}'));
    });

    test(
      'native, no canonical public URL configured: fails safely, no URL',
      () {
        final result = buildInvitationLinkResult(
          'b' * 64,
          isWebOverride: false,
          configuredPublicWebUrlOverride: null,
        );

        expect(result.isConfigured, isFalse);
        expect(result.url, isNull);
      },
    );

    test('native, a valid canonical public URL configured: builds an '
        'absolute URL from it, never a relative path', () {
      final result = buildInvitationLinkResult(
        'c' * 64,
        isWebOverride: false,
        configuredPublicWebUrlOverride: 'https://umoja.example.org',
      );

      expect(result.isConfigured, isTrue);
      expect(result.url, 'https://umoja.example.org/invite/${'c' * 64}');
    });

    test('Copy and Share are both fed by this exact same function/result — '
        'calling it twice with the same input is deterministic', () {
      final first = buildInvitationLinkResult(
        'd' * 64,
        isWebOverride: false,
        configuredPublicWebUrlOverride: 'https://umoja.example.org',
      );
      final second = buildInvitationLinkResult(
        'd' * 64,
        isWebOverride: false,
        configuredPublicWebUrlOverride: 'https://umoja.example.org',
      );

      expect(first.url, second.url);
    });
  });
}
