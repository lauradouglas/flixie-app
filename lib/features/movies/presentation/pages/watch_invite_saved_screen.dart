import 'package:flixie_app/features/pip/presentation/widgets/pip_companion.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/pending_watch_invite_store.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';

class WatchInviteSavedScreen extends StatelessWidget {
  const WatchInviteSavedScreen(
      {super.key,
      required this.requestId,
      this.movieTitle,
      this.rating,
      this.watchState});
  final String requestId;
  final String? movieTitle;
  final int? rating;
  final WatchRequestState? watchState;
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
                    const PipCompanion(celebrate: true),
                    const Align(
                        alignment: Alignment.centerLeft,
                        child: Icon(Icons.check_circle_outline, size: 48)),
                    const SizedBox(height: 24),
                    Text('One movie night. Your own take.',
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
                    if (watchState != null) ...[
                      Text('Your movie night',
                          style: Theme.of(context).textTheme.titleLarge),
                      for (final confirmation in watchState!
                          .request.watchConfirmations
                          .where((c) => c.watched))
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.movie_outlined),
                            title: Text(watchState!.request.viewingPeople
                                    .where((p) => p.id == confirmation.userId)
                                    .firstOrNull
                                    ?.displayName ??
                                'Film friend'),
                            subtitle: Text(confirmation.rating == null
                                ? 'Watch saved · no score'
                                : '${confirmation.rating}/10 · watch saved')),
                      const SizedBox(height: 16),
                    ],
                    const Text('Your date, rating and review stay your own.'),
                    const SizedBox(height: 28),
                    FilledButton(
                        onPressed: () =>
                            context.go('/watch-requests/$requestId'),
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
