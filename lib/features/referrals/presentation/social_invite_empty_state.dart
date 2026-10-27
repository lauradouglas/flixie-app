import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SocialInviteEmptyState extends StatelessWidget {
  const SocialInviteEmptyState({super.key, this.activity = false});
  final bool activity;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(
              child: Image.asset('assets/icon/pip_cosmetics/cinema_club.png',
                  width: 88, height: 88, excludeFromSemantics: true)),
          const SizedBox(height: 16),
          Text(
              activity
                  ? 'No new friend activity yet.'
                  : 'Your film people belong here.',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
              'Invite someone to add their take on the films you watch together.'),
          const SizedBox(height: 12),
          const Text(
              'Both earn Film Friend when your referred friend finishes setup. Confirm your own logs of a shared film to unlock Cinema Club Pip and an app icon for both of you.'),
          const SizedBox(height: 16),
          FilledButton(
              onPressed: () => context.push('/invite-friend?from=social-empty'),
              child: const Text('Invite a friend')),
        ]),
      );
}
