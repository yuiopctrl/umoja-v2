import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/localization/failure_messages.dart';
import '../../../core/widgets/umoja_buttons.dart';
import '../../../shared/widgets/responsive_center.dart';
import '../../auth/presentation/sign_out_button.dart';
import '../controllers/membership_claim_controller.dart';

/// `/membership/link`: Group Code + Member Number only — no roster
/// search, no phone field, no membership/group id field anywhere.
/// Entering correct references never grants access by itself; the
/// server-side officer approval workflow (not built in D2) is what
/// actually links the membership. See
/// `rpc_request_membership_claim_by_reference` (Prompt 09G-B1-D1).
class MembershipLinkScreen extends ConsumerStatefulWidget {
  const MembershipLinkScreen({super.key});

  @override
  ConsumerState<MembershipLinkScreen> createState() =>
      _MembershipLinkScreenState();
}

class _MembershipLinkScreenState extends ConsumerState<MembershipLinkScreen> {
  final _groupCodeController = TextEditingController();
  final _memberNumberController = TextEditingController();

  @override
  void dispose() {
    _groupCodeController.dispose();
    _memberNumberController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final groupCode = _groupCodeController.text.trim().toUpperCase();
    final memberNumber = _memberNumberController.text.trim().toUpperCase();
    if (groupCode.isEmpty || memberNumber.isEmpty) return;

    final success = await ref
        .read(membershipClaimControllerProvider.notifier)
        .requestByReference(groupCode: groupCode, memberNumber: memberNumber);
    if (success && mounted) {
      context.push(AppRoutes.membershipClaims);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(membershipClaimControllerProvider);
    final l10n = context.l10n;
    final groupCode = _groupCodeController.text.trim();
    final memberNumber = _memberNumberController.text.trim();
    final canSubmit =
        !state.isSubmitting && groupCode.isNotEmpty && memberNumber.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: ResponsiveCenter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.membershipLinkTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l10n.membershipLinkExplanation),
              const SizedBox(height: 24),
              TextField(
                key: const Key('membershipGroupCodeField'),
                controller: _groupCodeController,
                autofocus: true,
                enabled: !state.isSubmitting,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                inputFormatters: [UpperCaseTextFormatter()],
                decoration: InputDecoration(
                  labelText: l10n.groupCodeLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('membershipMemberNumberField'),
                controller: _memberNumberController,
                enabled: !state.isSubmitting,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.done,
                inputFormatters: [UpperCaseTextFormatter()],
                decoration: InputDecoration(
                  labelText: l10n.memberNumberLabel,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              if (state.errorType != null) ...[
                const SizedBox(height: 12),
                Text(
                  membershipClaimFailureMessage(l10n, state.errorType!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              UmojaPrimaryButton(
                key: const Key('membershipRequestAccessAction'),
                expand: true,
                label: l10n.requestAccessAction,
                isLoading: state.isSubmitting,
                onPressed: canSubmit ? _submit : null,
              ),
              const SizedBox(height: 16),
              const SignOutButton(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Uppercases as the user types — group codes/member numbers are
/// consistently uppercase server-side reference formats (Prompt
/// 09G-B1-D2 §H), not a formatting preference.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
