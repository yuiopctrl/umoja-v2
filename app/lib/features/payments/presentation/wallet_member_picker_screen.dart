import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/app_routes.dart';
import '../../../core/localization/app_localizations_x.dart';
import '../../../core/widgets/umoja_page.dart';
import 'widgets/member_search_picker.dart';

/// `/wallet`: select a member to view/allocate their wallet (Salio la
/// Mwanachama). A thin picker step, reusing [MemberSearchPicker].
class WalletMemberPickerScreen extends StatelessWidget {
  const WalletMemberPickerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return UmojaPage(
      title: l10n.memberWalletTitle,
      maxWidth: 700,
      body: MemberSearchPicker(
        hintText: l10n.memberPickerSearchHint,
        onSelected: (member) =>
            context.push(AppRoutes.walletDetailPath(member.membershipId)),
      ),
    );
  }
}
