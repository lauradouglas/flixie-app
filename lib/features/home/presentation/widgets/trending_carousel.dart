import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'home_hero_card.dart';

/// Original Home artwork cards, without the friend activity footer.
class TrendingCarousel extends StatefulWidget {
  const TrendingCarousel(
      {super.key,
      required this.movies,
      required this.onDetails,
      required this.onSave,
      required this.onTrailer,
      this.savedIds = const {},
      this.pendingIds = const {}});
  final List<MovieShort> movies;
  final Set<int> savedIds, pendingIds;
  final ValueChanged<MovieShort> onDetails, onSave, onTrailer;
  @override
  State<TrendingCarousel> createState() => _TrendingCarouselState();
}

class _TrendingCarouselState extends State<TrendingCarousel> {
  final _pages = PageController(viewportFraction: .84);
  int _selected = 0;
  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies.take(8).toList(growable: false);
    if (movies.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return Column(children: [
      SizedBox(
          height: 280 + 225 + 280 * (scale - 1).clamp(0.0, double.infinity),
          child: PageView.builder(
              controller: _pages,
              padEnds: false,
              onPageChanged: (index) => setState(() => _selected = index),
              itemCount: movies.length,
              itemBuilder: (context, index) {
                final movie = movies[index];
                return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: HomeHeroCard(
                        movie: movie,
                        posterHeight: 280,
                        inWatchlist: widget.savedIds.contains(movie.id),
                        isUpdating: widget.pendingIds.contains(movie.id),
                        showFriendActivity: false,
                        interactions: const [],
                        friendActivityLoading: false,
                        friendActivityFailed: false,
                        onOpen: () => widget.onDetails(movie),
                        onDetails: () => widget.onDetails(movie),
                        onWatchlist: () => widget.onSave(movie),
                        onTrailer: () => widget.onTrailer(movie),
                        onFriendsRetry: () {}));
              })),
      if (movies.length > 1) ...[
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var index = 0; index < movies.length; index++)
            Semantics(
                label: 'Page ${index + 1} of ${movies.length}',
                selected: index == _selected,
                child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: index == _selected ? 20 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                        color: index == _selected
                            ? FlixieColors.primary
                            : Colors.white.withValues(alpha: .3),
                        borderRadius: BorderRadius.circular(3)))),
        ]),
      ],
    ]);
  }
}
