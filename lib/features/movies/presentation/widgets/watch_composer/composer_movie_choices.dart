import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/movie_short.dart';

class MovieOptionsEmptyCard extends StatelessWidget {
  const MovieOptionsEmptyCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.tabBarBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(children: [
            Container(
              width: 92,
              height: 132,
              decoration: BoxDecoration(
                color: FlixieColors.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.add_rounded,
                  color: FlixieColors.primary, size: 36),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add films to vote on',
                      style: TextStyle(
                          color: context.colors.light,
                          fontSize: 19,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text('Everyone can add options.',
                      style: TextStyle(
                          color: context.colors.medium, fontSize: 13)),
                  const SizedBox(height: 14),
                  const Text('Browse cinema releases',
                      style: TextStyle(
                          color: FlixieColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ]),
        ),
      );
}

class SelectedPlanTitle extends StatelessWidget {
  const SelectedPlanTitle(
      {super.key,
      required this.choices,
      required this.selectedMovieId,
      required this.onSelect,
      required this.onRemove,
      required this.onAddOption});
  final List<MovieShort> choices;
  final int? selectedMovieId;
  final ValueChanged<MovieShort> onSelect;
  final ValueChanged<MovieShort> onRemove;
  final VoidCallback? onAddOption;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            border: Border.all(color: context.colors.tabBarBorder),
            borderRadius: BorderRadius.circular(18)),
        child: SizedBox(
          height: 128,
          child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: choices.length + (onAddOption == null ? 0 : 1),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                if (index == choices.length) {
                  return SizedBox(
                    width: 56,
                    child: Center(
                      child: Tooltip(
                        message: 'Add another movie option',
                        child: InkWell(
                          onTap: onAddOption,
                          customBorder: const CircleBorder(),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  FlixieColors.primary.withValues(alpha: .14),
                              border: Border.all(color: FlixieColors.primary),
                            ),
                            child: const Icon(Icons.add_rounded,
                                color: FlixieColors.primary),
                          ),
                        ),
                      ),
                    ),
                  );
                }
                final choice = choices[index];
                return SizedBox(
                    width: 76,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: InkWell(
                                  onTap: () => onSelect(choice),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(children: [
                                    Positioned.fill(
                                        child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: choice.poster == null
                                                ? ColoredBox(
                                                    color: context
                                                        .colors.surfaceElevated)
                                                : CachedNetworkImage(
                                                    imageUrl: choice.poster!
                                                            .startsWith('http')
                                                        ? choice.poster!
                                                        : 'https://image.tmdb.org/t/p/w185${choice.poster}',
                                                    fit: BoxFit.cover))),
                                    if (choice.id == selectedMovieId)
                                      Positioned(
                                          left: 4,
                                          bottom: 4,
                                          child: Icon(Icons.check_circle,
                                              color: context.colors.success,
                                              size: 18)),
                                    Positioned(
                                      right: 2,
                                      top: 2,
                                      child: Tooltip(
                                        message: 'Remove ${choice.name}',
                                        child: Material(
                                          color: Colors.black54,
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            onTap: () => onRemove(choice),
                                            customBorder: const CircleBorder(),
                                            child: const SizedBox(
                                              width: 28,
                                              height: 28,
                                              child: Icon(
                                                Icons.close_rounded,
                                                size: 17,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ]))),
                          const SizedBox(height: 4),
                          Text(choice.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: context.colors.light,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700)),
                        ]));
              }),
        ),
      );
}
