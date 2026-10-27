import 'home_tablet_layout.dart';
import 'cinema_list.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'trending_carousel_skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'trending_carousel.dart';

/// Independent catalogue loading keeps cinema failures out of other Home sections.
class InCinemasSection extends StatefulWidget {
  const InCinemasSection(
      {super.key,
      required this.region,
      required this.onDetails,
      required this.onSave,
      required this.onTrailer,
      this.watchlistChanges,
      this.onChangeCountry,
      this.savedIds = const {},
      this.pendingIds = const {},
      this.loader,
      this.initialMovies = const [],
      this.loadingPlaceholder = const TrendingCarouselSkeleton(),
      this.mediaBuilder});
  final Future<void> Function()? onChangeCountry;
  final Listenable? watchlistChanges;
  final String region;
  final List<MovieShort> initialMovies;
  final Widget loadingPlaceholder;
  final ValueChanged<MovieShort> onDetails, onSave, onTrailer;
  final Set<int> savedIds, pendingIds;
  final Future<List<MovieShort>> Function(String region)? loader;
  final Widget Function(List<MovieShort>)? mediaBuilder;

  @override
  State<InCinemasSection> createState() => InCinemasSectionState();
}

class InCinemasSectionState extends State<InCinemasSection>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final _sheetRevision = ValueNotifier(0);
  List<MovieShort> _movies = const [];
  bool _loading = true, _failed = false;
  bool _changingCountry = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _movies = widget.initialMovies;
    refresh();
  }

  @override
  void didUpdateWidget(InCinemasSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sheetRevision.value++;
    });
    if (oldWidget.region != widget.region) {
      _movies = const [];
      refresh();
    }
  }

  @override
  void dispose() {
    _sheetRevision.dispose();
    super.dispose();
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final movies = await (widget.loader?.call(widget.region) ??
          MovieService().getNowPlayingMovies(region: widget.region));
      if (!mounted || generation != _generation) return;
      setState(() {
        _movies = movies;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _showAll() => showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.background,
      builder: (sheetContext) => SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .85,
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
                child: Row(children: [
                  const Expanded(
                      child: Text('In cinemas',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w800))),
                  IconButton(
                      tooltip: 'Close cinema releases',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close)),
                ])),
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: HomeTabletScope(
                        child: ListenableBuilder(
                            listenable: Listenable.merge([
                              _sheetRevision,
                              if (widget.watchlistChanges != null)
                                widget.watchlistChanges!
                            ]),
                            builder: (_, __) => CinemaList(
                                movies: _movies,
                                showAll: true,
                                savedIds: widget.savedIds,
                                pendingIds: widget.pendingIds,
                                onDetails: (movie) {
                                  Navigator.pop(sheetContext);
                                  widget.onDetails(movie);
                                },
                                onSave: widget.onSave,
                                onTrailer: (movie) {
                                  Navigator.pop(sheetContext);
                                  widget.onTrailer(movie);
                                }))))),
          ])));

  Future<void> _changeCountry() async {
    if (_changingCountry || widget.onChangeCountry == null) return;
    setState(() => _changingCountry = true);
    try {
      await widget.onChangeCountry!();
    } finally {
      if (mounted) setState(() => _changingCountry = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (HomeTabletLayout.active(context))
            Row(children: [
              const Expanded(
                  child: Text('In cinemas',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800))),
              if (widget.onChangeCountry != null) ...[
                TextButton.icon(
                    onPressed: _changingCountry ? null : _changeCountry,
                    icon: _changingCountry
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.location_on_outlined, size: 16),
                    style: TextButton.styleFrom(
                        foregroundColor: context.colors.light,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        textStyle: const TextStyle(fontSize: 12)),
                    label: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                          '${widget.region == 'GB' ? 'UK' : widget.region} theatres'),
                      const SizedBox(width: 4),
                      const Icon(Icons.expand_more, size: 16),
                    ])),
                const SizedBox(width: 8),
              ],
              TextButton(
                  onPressed: _movies.isEmpty ? null : _showAll,
                  child: const Text('See all'))
            ])
          else
            Text('In cinemas', style: Theme.of(context).textTheme.titleLarge),
          if (!HomeTabletLayout.active(context)) ...[
            const SizedBox(height: 8),
            Text(
                '${widget.region == 'GB' ? 'UK' : widget.region} cinema releases',
                style: Theme.of(context).textTheme.bodySmall),
          ],
          SizedBox(height: HomeTabletLayout.active(context) ? 8 : 14),
          if (_loading && _movies.isEmpty) widget.loadingPlaceholder,
          if (_failed)
            Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const Text('Couldn’t load cinema releases.'),
                  TextButton(onPressed: refresh, child: const Text('Retry')),
                ]),
          if (!_loading && !_failed && _movies.isEmpty)
            const Text(
                'No cinema releases available for this region right now.'),
          if (_movies.isNotEmpty)
            widget.mediaBuilder?.call(_movies) ??
                TrendingCarousel(
                    key: ValueKey(widget.region),
                    movies: _movies,
                    savedIds: widget.savedIds,
                    pendingIds: widget.pendingIds,
                    onDetails: widget.onDetails,
                    onSave: widget.onSave,
                    onTrailer: widget.onTrailer),
        ]));
  }
}
