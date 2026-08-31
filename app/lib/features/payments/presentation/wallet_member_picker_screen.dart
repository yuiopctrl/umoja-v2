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
      // UAT-FIX-02: `MemberSearchPicker` uses `Expanded` internally, which
      // requires bounded height from its ancestor. `UmojaPage` defaults
      // `scrollable` to `true`, wrapping `body` in a `SingleChildScrollView`
      // (unbounded height) — that combination threw
      // "RenderFlex children have non-zero flex but incoming height
      // constraints are unbounded" during layout, so this screen never
      // even reached the point of calling any provider/RPC. The Record
      // Payment flow's own member-picker step already avoids this
      // correctly (`scrollable: _step != _RecordPaymentStep.pickMember`);
      // this screen is nothing but that picker step, so it needs the
      // same `scrollable: false`.
      scrollable: false,
      body: MemberSearchPicker(
        hintText: l10n.memberPickerSearchHint,
        onSelected: (member) =>
            context.push(AppRoutes.walletDetailPath(member.membershipId)),
      ),
    );
  }
}
