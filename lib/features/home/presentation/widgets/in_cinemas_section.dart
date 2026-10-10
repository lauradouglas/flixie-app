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
      this.savedIds = const {},
      this.pendingIds = const {},
      this.loader});
  final String region;
  final ValueChanged<MovieShort> onDetails, onSave, onTrailer;
  final Set<int> savedIds, pendingIds;
  final Future<List<MovieShort>> Function(String region)? loader;

  @override
  State<InCinemasSection> createState() => InCinemasSectionState();
}

class InCinemasSectionState extends State<InCinemasSection> {
  List<MovieShort> _movies = const [];
  bool _loading = true, _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(InCinemasSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.region != widget.region) {
      _movies = const [];
      refresh();
    }
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

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('In cinemas', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('${widget.region == 'GB' ? 'UK' : widget.region} cinema releases',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 14),
        if (_loading && _movies.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                  child: CircularProgressIndicator(
                      semanticsLabel: 'Loading cinema releases'))),
        if (_failed)
          Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                const Text('Couldn’t load cinema releases.'),
                TextButton(onPressed: refresh, child: const Text('Retry')),
              ]),
        if (!_loading && !_failed && _movies.isEmpty)
          const Text('No cinema releases available for this region right now.'),
        if (_movies.isNotEmpty)
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
