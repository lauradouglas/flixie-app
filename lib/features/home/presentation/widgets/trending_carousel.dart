import 'content_sized_carousel.dart';
import 'tablet_trending_gallery.dart';
import '../models/home_section.dart';
import 'package:flixie_app/models/friend_media_interaction.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'home_hero_card.dart';

/// Home artwork cards, with optional signed-in friend activity.
class TrendingCarousel extends StatefulWidget {
  const TrendingCarousel(
      {super.key,
      required this.movies,
      required this.onDetails,
      required this.onSave,
      required this.onTrailer,
      this.friendActivity,
      this.onPageChanged,
      this.onFriendsRetry,
      this.savedIds = const {},
      this.pendingIds = const {}});
  final HomeSection<List<FriendMediaInteraction>> Function(int)? friendActivity;
  final ValueChanged<int>? onPageChanged;
  final ValueChanged<MovieShort>? onFriendsRetry;
  final List<MovieShort> movies;
  final Set<int> savedIds, pendingIds;
  final ValueChanged<MovieShort> onDetails, onSave, onTrailer;
  @override
  State<TrendingCarousel> createState() => _TrendingCarouselState();
}

class _TrendingCarouselState extends State<TrendingCarousel> {
  final _pages = PageController(viewportFraction: .90);
  int _selected = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPageChanged?.call(0);
    });
  }

  @override
  void didUpdateWidget(covariant TrendingCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movies.firstOrNull?.homeKey !=
        widget.movies.firstOrNull?.homeKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onPageChanged?.call(_selected);
      });
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final movies = widget.movies.take(20).toList(growable: false);
    if (movies.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(builder: (context, constraints) {
      if (constraints.maxWidth >= 560 && scale <= 1.4) {
        return TabletTrendingGallery(
            movies: movies,
            friendActivity: widget.friendActivity,
            onPageChanged: widget.onPageChanged,
            onFriendsRetry: widget.onFriendsRetry,
            savedIds: widget.savedIds,
            pendingIds: widget.pendingIds,
            onDetails: widget.onDetails,
            onSave: widget.onSave,
            onTrailer: widget.onTrailer);
      }
      Widget card(int index, {bool contentSized = true}) {
        final movie = movies[index];
        return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: HomeHeroCard(
                movie: movie,
                contentSized: contentSized,
                posterHeight: 280,
                inWatchlist: widget.savedIds.contains(movie.homeKey),
                isUpdating: widget.pendingIds.contains(movie.homeKey),
                showFriendActivity: widget.friendActivity != null,
                interactions:
                    widget.friendActivity?.call(movie.homeKey).value.data ??
                        const [],
                friendActivityLoading:
                    widget.friendActivity?.call(movie.homeKey).value.loading ??
                        false,
                friendActivityFailed:
                    widget.friendActivity?.call(movie.homeKey).value.error !=
                        null,
                onOpen: () => widget.onDetails(movie),
                onDetails: () => widget.onDetails(movie),
                onWatchlist: () => widget.onSave(movie),
                onTrailer: () => widget.onTrailer(movie),
                onFriendsRetry: () => widget.onFriendsRetry?.call(movie)));
      }

      return Column(children: [
        ContentSizedCarousel(
            viewportFraction: .90,
            measurements: [
              for (var index = 0; index < movies.length; index++)
                if (widget.friendActivity?.call(movies[index].homeKey)
                    case final activity?)
                  ListenableBuilder(
                      listenable: activity,
                      builder: (_, __) => card(index, contentSized: true))
                else
                  card(index, contentSized: true),
            ],
            child: PageView.builder(
                controller: _pages,
                padEnds: false,
                onPageChanged: (index) {
                  setState(() => _selected = index);
                  widget.onPageChanged?.call(index);
                },
                itemCount: movies.length,
                itemBuilder: (context, index) {
                  final movie = movies[index];
                  final activity = widget.friendActivity?.call(movie.homeKey);
                  return activity == null
                      ? card(index)
                      : ListenableBuilder(
                          listenable: activity,
                          builder: (_, __) => card(index));
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
    });
  }
}
