import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../authentication/data/setup_service.dart';
import '../../../guest/presentation/guest_access.dart';
import '../../data/guest_watchlist_store.dart';

/// Makes unmerged device picks discoverable after a restart or dismissed retry.
class GuestPicksRecoveryButton extends StatelessWidget {
  const GuestPicksRecoveryButton({super.key});
  @override
  Widget build(BuildContext context) => FutureBuilder<List<SetupTitle>>(
      future: GuestWatchlistStore.instance.read(),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        if (count == 0) return const SizedBox.shrink();
        return TextButton.icon(
            icon: const Icon(Icons.bookmarks_outlined),
            label: Text(
                'Keep $count ${count == 1 ? 'pick' : 'picks'} from this device'),
            onPressed: () {
              GuestAccess.clear();
              GuestAccess.action = 'guest-watchlist';
              GuestAccess.destination = '/guest-watchlist';
              GuestAccess.awaitingAccount = true;
              context.go('/signup-journey');
            });
      });
}
