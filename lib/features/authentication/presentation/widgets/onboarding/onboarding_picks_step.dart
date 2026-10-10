import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../../data/setup_service.dart';
import '../../controllers/onboarding_controller.dart';

class OnboardingPicksStep extends StatelessWidget {
  const OnboardingPicksStep(
      {super.key,
      required this.controller,
      required this.onFinish,
      required this.onAdd});
  final OnboardingController controller;
  final ValueChanged<String> onFinish;
  final ValueChanged<SetupTitle> onAdd;

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _results(context));
  List<Widget> _results(BuildContext context) => [
        if (controller.referrer != null)
          Text(
              'You joined through @$controller.referrer. Find them when you’re ready.'),
        Text(controller.taste.isEmpty
            ? 'Popular picks to get you started'
            : 'Inspired by the titles you chose'),
        if (controller.searching)
          const Padding(
              padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        if (controller.picksError != null)
          TextButton(
              onPressed: controller.loadPicks,
              child: Text(controller.picksError!)),
        if (!controller.searching &&
            controller.picks.isEmpty &&
            controller.picksError == null)
          const Text(
              'No picks available yet. Explore Flixie or try choosing a few more titles.'),
        if (!controller.searching)
          for (final title in controller.rankedPicks) _pickRow(context, title),
        if (controller.added.isNotEmpty)
          Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                    'Yours to come back to. Find your saved picks in Watchlist.',
                    style: TextStyle(color: context.colors.secondary)),
              )),
      ];
  Widget _pickRow(BuildContext context, SetupTitle title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 108,
                child: title.poster == null
                    ? ColoredBox(
                        color: context.colors.surfaceElevated,
                        child: const Icon(Icons.movie_outlined))
                    : Image.network(
                        title.poster!.startsWith('http')
                            ? title.poster!
                            : 'https://image.tmdb.org/t/p/w185${title.poster}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                            color: context.colors.surfaceElevated,
                            child: const Icon(Icons.movie_outlined))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(title.isShow ? 'Show' : 'Movie',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                if (title.reason != null)
                  Text(title.reason!,
                      style: TextStyle(
                          color: context.colors.secondary, fontSize: 13)),
                Text(controller.availabilityLabel(title),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  TextButton(
                    style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 13),
                        minimumSize: const Size(44, 44)),
                    onPressed: controller.busy
                        ? null
                        : () => onFinish(
                            '/${title.isShow ? 'shows' : 'movies'}/${title.id}'),
                    child:
                        Text(title.isShow ? 'Show details' : 'Movie details'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 13),
                        minimumSize: const Size(44, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: controller.added.contains(title.key) ||
                            controller.adding.contains(title.key)
                        ? null
                        : () => onAdd(title),
                    icon: Icon(
                        controller.added.contains(title.key)
                            ? Icons.check
                            : Icons.add,
                        size: 18),
                    label: Text(controller.added.contains(title.key)
                        ? 'Saved'
                        : controller.adding.contains(title.key)
                            ? 'Adding…'
                            : 'Add to watchlist'),
                  ),
                ]),
              ],
            )),
          ],
        ),
      );
}
