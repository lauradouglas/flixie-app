import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../../data/setup_service.dart';
import '../../controllers/onboarding_controller.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

class OnboardingTasteStep extends StatelessWidget {
  const OnboardingTasteStep(
      {super.key,
      required this.controller,
      required this.search,
      required this.onImport});
  final OnboardingController controller;
  final TextEditingController search;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _tastes(context));
  List<Widget> _tastes(BuildContext context) => [
        TextField(
            controller: search,
            decoration: const InputDecoration(
                labelText: 'Search titles', prefixIcon: Icon(Icons.search)),
            onChanged: controller.changeQuery),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final shows in [false, true])
              FlixiePill.choice(
                label: Text(shows ? 'Shows' : 'Movies'),
                selected: controller.shows == shows,
                showCheckmark: false,
                onSelected: controller.busy
                    ? null
                    : (_) => controller.changeMode(shows),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (controller.searching)
          const ContentPlaceholder(
              label: 'Loading titles', style: ContentPlaceholderStyle.posters),
        if (controller.searchError != null)
          TextButton(
              onPressed: controller.findTitles,
              child: Text(controller.searchError!)),
        if (!controller.searching &&
            controller.browse.isEmpty &&
            controller.searchError == null)
          const Text('No matches. Try another title.'),
        if (!controller.searching) _posterGrid(context, controller.browse),
        const SizedBox(height: 12),
        Text(
            'These shape your picks on this device. They won’t become public favourites, ratings or watched titles.',
            style: Theme.of(context).textTheme.bodySmall),
        if (controller.allGenres.isNotEmpty)
          ExpansionTile(
              title: const Text('Genres you enjoy (optional)'),
              children: [
                Wrap(
                    spacing: 8,
                    children: controller.allGenres
                        .map((g) => FlixiePill.filter(
                            label: Text(g.name),
                            selected: controller.genres.contains(g.id),
                            onSelected: (v) => controller.selectGenre(g.id, v)))
                        .toList())
              ]),
        TextButton.icon(
            onPressed: controller.busy ? null : onImport,
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Already have a library? Import it')),
        const SizedBox(height: 16),
      ];
  Widget _posterGrid(BuildContext context, List<SetupTitle> titles) =>
      LayoutBuilder(builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        final columns = (constraints.maxWidth / (largeText ? 150 : 105))
            .floor()
            .clamp(2, 5);
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
            spacing: 12,
            runSpacing: 20,
            children: titles
                .map((t) => SizedBox(
                    width: width,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                              key: ValueKey('taste-${t.key}'),
                              onTap: !controller.busy
                                  ? () {
                                      if (!controller.toggleTaste(t)) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Three selected. Remove one to make room for another.')));
                                      }
                                    }
                                  : null,
                              child: Semantics(
                                  label: t.name,
                                  selected: controller.taste.containsKey(t.key),
                                  child: AspectRatio(
                                      aspectRatio: 2 / 3,
                                      child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                if (t.poster != null)
                                                  Image.network(
                                                      t
                                                              .poster!
                                                              .startsWith(
                                                                  'http')
                                                          ? t.poster!
                                                          : 'https://image.tmdb.org/t/p/w342${t.poster}',
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __,
                                                              ___) =>
                                                          const ColoredBox(
                                                              color: Color(
                                                                  0xffddd0ef),
                                                              child: Icon(Icons
                                                                  .movie_outlined)))
                                                else
                                                  const ColoredBox(
                                                      color: Color(0xffddd0ef),
                                                      child: Icon(Icons
                                                          .movie_outlined)),
                                                Positioned(
                                                  top: 6,
                                                  right: 6,
                                                  child: AnimatedContainer(
                                                    duration: MediaQuery
                                                            .disableAnimationsOf(
                                                                context)
                                                        ? Duration.zero
                                                        : const Duration(
                                                            milliseconds: 150),
                                                    padding:
                                                        const EdgeInsets.all(4),
                                                    decoration: BoxDecoration(
                                                      color: controller.taste
                                                              .containsKey(
                                                                  t.key)
                                                          ? FlixieColors.primary
                                                          : context.colors
                                                              .background,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                          color: controller
                                                                  .taste
                                                                  .containsKey(
                                                                      t.key)
                                                              ? FlixieColors
                                                                  .primary
                                                              : context.colors
                                                                  .tabBarBorder),
                                                    ),
                                                    child: Icon(
                                                        controller.taste
                                                                .containsKey(
                                                                    t.key)
                                                            ? Icons.check
                                                            : Icons.add,
                                                        color: controller.taste
                                                                .containsKey(
                                                                    t.key)
                                                            ? Colors.white
                                                            : null,
                                                        size: 18),
                                                  ),
                                                ),
                                                if (controller.taste
                                                    .containsKey(t.key))
                                                  IgnorePointer(
                                                      child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                          color: FlixieColors
                                                              .primary,
                                                          width: 3),
                                                    ),
                                                  )),
                                              ]))))),
                          const SizedBox(height: 8),
                          Text(t.name,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                        ])))
                .toList());
      });
}
