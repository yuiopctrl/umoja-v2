import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:umoja/features/auth/providers/app_context_provider.dart';
import 'package:umoja/features/auth/providers/auth_controller_provider.dart';
import 'package:umoja/features/auth/providers/auth_repository_provider.dart';
import 'package:umoja/features/auth/providers/pending_invitation_token_provider.dart';
import 'package:umoja/features/membership_invitations/controllers/membership_invitation_acceptance_controller.dart';
import 'package:umoja/features/membership_invitations/providers/membership_invitation_repository_provider.dart';

import 'fakes/fake_auth_repository.dart';
import 'fakes/fake_membership_invitation_repository.dart';

/// Prompt 09G-B1-E4-FINAL §B/§C: a captured invitation token (or a
/// "just accepted" flag) must not survive an explicit sign-out into a
/// future, unrelated session — [AuthController.signOut] must clear
/// both, exactly like it already clears every other user-scoped
/// provider.
void main() {
  late FakeAuthRepository fakeAuth;
  late FakeMembershipInvitationRepository fakeInvitationRepo;
  late ProviderContainer container;

  setUp(() {
    fakeAuth = FakeAuthRepository();
    fakeInvitationRepo = FakeMembershipInvitationRepository();
    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(fakeAuth),
        membershipInvitationRepositoryProvider.overrideWithValue(
          fakeInvitationRepo,
        ),
        appContextProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
  });

  test('signOut clears a pending invitation token — it must not resurrect '
      'for a later, unrelated login', () async {
    container.read(pendingInvitationTokenProvider.notifier).set('t' * 64);
    expect(container.read(pendingInvitationTokenProvider), isNotNull);

    await container.read(authControllerProvider).signOut();

    expect(container.read(pendingInvitationTokenProvider), isNull);
    expect(fakeAuth.signOutCallCount, 1);
  });

  test('signOut clears a "just accepted" invitation flag — it must not '
      'release a later, unrelated session\'s invitation hold early', () async {
    final token = 'u' * 64;
    fakeInvitationRepo.nextAcceptanceResult =
        fakeMembershipInvitationAcceptance();
    await container
        .read(membershipInvitationAcceptanceControllerProvider.notifier)
        .accept(token: token);
    expect(
      container
          .read(membershipInvitationAcceptanceControllerProvider)
          .isAcceptedFor(token),
      isTrue,
    );

    await container.read(authControllerProvider).signOut();

    expect(
      container
          .read(membershipInvitationAcceptanceControllerProvider)
          .isAcceptedFor(token),
      isFalse,
    );
    expect(
      container
          .read(membershipInvitationAcceptanceControllerProvider)
          .acceptance,
      isNull,
    );
  });

  test('signOut with no pending token/acceptance in play is a harmless '
      'no-op for these two providers (ordinary login regression)', () async {
    expect(container.read(pendingInvitationTokenProvider), isNull);
    expect(
      container
          .read(membershipInvitationAcceptanceControllerProvider)
          .acceptedToken,
      isNull,
    );

    await container.read(authControllerProvider).signOut();

    expect(container.read(pendingInvitationTokenProvider), isNull);
    expect(
      container
          .read(membershipInvitationAcceptanceControllerProvider)
          .acceptedToken,
      isNull,
    );
  });
}
