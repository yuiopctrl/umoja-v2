import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/providers/selected_group_provider.dart';
import '../domain/wallet_entry_page.dart';
import 'payment_repository_provider.dart';

/// Query key for [memberWalletEntriesProvider].
typedef WalletEntriesQuery = ({String membershipId, int limit});

/// The wallet ledger page, which already bundles the current balance
/// (see [WalletEntryPage.walletBalance]) — a screen never needs a
/// second round-trip just to show the balance. `.autoDispose` for the
/// same freshness reason as every other Prompt 07/08A list provider.
final memberWalletEntriesProvider = FutureProvider.autoDispose
    .family<WalletEntryPage, WalletEntriesQuery>((ref, query) async {
      final selectedGroup = ref.watch(selectedGroupProvider);
      if (selectedGroup is! SelectedGroupResolved) return WalletEntryPage.empty;

      final repository = ref.watch(paymentRepositoryProvider);
      return repository.listMemberWalletEntries(
        groupId: selectedGroup.membership.group.groupId,
        membershipId: query.membershipId,
        limit: query.limit,
      );
    });
