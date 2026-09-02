import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class WatchPlansIntroductionCard extends StatelessWidget {
  const WatchPlansIntroductionCard({
    super.key,
    required this.onCreate,
    required this.onLearnMore,
    required this.onDismiss,
  });

  final VoidCallback onCreate;
  final VoidCallback onLearnMore;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            FlixieColors.primary.withValues(alpha: .28),
            FlixieColors.success.withValues(alpha: .16),
          ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FlixieColors.primary.withValues(alpha: .5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.movie_filter_rounded,
                color: FlixieColors.success, size: 18),
            const SizedBox(width: 7),
            const Expanded(
                child: Text('WATCH TOGETHER',
                    style: TextStyle(
                        color: FlixieColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8))),
            IconButton(
              onPressed: onDismiss,
              tooltip: 'Dismiss',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close_rounded,
                  color: FlixieColors.medium, size: 20),
            ),
          ]),
          const Text('Can’t decide what to watch?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Add a few movies, invite friends and choose together.',
              style: TextStyle(color: FlixieColors.medium, fontSize: 13)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(
                onPressed: onCreate, child: const Text('Make a watch plan')),
            OutlinedButton(
                onPressed: onLearnMore, child: const Text('See how it works')),
          ]),
        ]),
      );
}
