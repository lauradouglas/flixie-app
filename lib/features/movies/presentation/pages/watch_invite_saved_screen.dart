import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/pending_watch_invite_store.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';

class WatchInviteSavedScreen extends StatelessWidget {
  const WatchInviteSavedScreen(
      {super.key, required this.requestId, this.movieTitle, this.rating});
  final String requestId;
  final String? movieTitle;
  final int? rating;
  Future<void> _continue(BuildContext context) async {
    final completed =
        context.read<AuthProvider>().dbUser?.completedSetup == true;
    await PendingWatchInviteStore.clear();
    GuestAccess.clear();
    if (context.mounted) context.go(completed ? '/' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const FlixieWordmark(), automaticallyImplyLeading: false),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                  padding: const EdgeInsets.all(24),
                  shrinkWrap: true,
                  children: [
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(Icons.check_circle_outline, size: 48)),
                    const SizedBox(height: 24),
                    Text('That one’s in your diary.',
                        style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 16),
                    Text(movieTitle == null
                        ? 'Your shared watch is saved.'
                        : '$movieTitle is saved to your watch history.'),
                    if (rating != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text('$rating / 10',
                              style:
                                  Theme.of(context).textTheme.headlineLarge)),
                    const SizedBox(height: 16),
                    const Text('Your date, rating and review stay your own.'),
                    const SizedBox(height: 28),
                    FilledButton(
                        onPressed: () =>
                            context.go('/watch-requests/$requestId?log=true'),
                        child: const Text('View my watch')),
                    TextButton(
                        onPressed: () => _continue(context),
                        child: Text(context
                                    .watch<AuthProvider>()
                                    .dbUser
                                    ?.completedSetup ==
                                true
                            ? 'Explore Flixie'
                            : 'Finish setting up Flixie')),
                  ]))));
}
