import 'package:flutter/material.dart';

class MonthlyWatchSummary extends StatelessWidget {
  const MonthlyWatchSummary(
      {super.key,
      required this.movies,
      required this.episodes,
      required this.onDiscover,
      required this.onLog});
  final int movies, episodes;
  final VoidCallback onDiscover, onLog;
  @override
  Widget build(BuildContext context) {
    if (movies > 0 || episodes > 0) {
      return Text('$movies movie watches · $episodes episodes');
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Your next watch starts here.',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      const Text(
          'Find a film or series that catches your eye. Watched something already? Log it to start this month’s story.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 4, children: [
        FilledButton.icon(
            onPressed: onDiscover,
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Find something to watch')),
        TextButton(
            onPressed: onLog, child: const Text('Log something I’ve watched')),
      ]),
    ]);
  }
}
