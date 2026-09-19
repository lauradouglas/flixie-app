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
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            FlixieColors.primary.withValues(alpha: .28),
            context.colors.success.withValues(alpha: .16),
          ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FlixieColors.primary.withValues(alpha: .5)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.movie_filter_rounded,
                color: context.colors.success, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Make a Watch Plan',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  Text('Pick a movie with friends.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.colors.medium, fontSize: 12)),
                ],
              ),
            ),
            SizedBox(
              width: 28,
              height: 32,
              child: IconButton(
                onPressed: onDismiss,
                tooltip: 'Dismiss',
                padding: EdgeInsets.zero,
                icon: Icon(Icons.close_rounded,
                    color: context.colors.medium, size: 18),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            TextButton(
              onPressed: onLearnMore,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              child: const Text('How it works'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: onCreate,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text('Create plan'),
            ),
          ]),
        ]),
      );
}
