import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/models/movie_short.dart';

import '../../data/watchlist_data_service.dart';
import 'watchlist_poster_placeholder.dart';

class WatchlistMovieSearchSheet extends StatefulWidget {
  const WatchlistMovieSearchSheet(
      {super.key,
      required this.existingMovieIds,
      this.service = const WatchlistDataService()});

  final WatchlistDataService service;

  final Set<int> existingMovieIds;

  @override
  State<WatchlistMovieSearchSheet> createState() =>
      _WatchlistMovieSearchSheetState();
}

class _WatchlistMovieSearchSheetState extends State<WatchlistMovieSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<MovieShort> _results = [];
  bool _isSearching = false;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();
    setState(() => _query = query);
    if (query.length < 3) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = true);
    try {
      final movies = await widget.service.searchMovies(query);
      if (!mounted) return;
      setState(() {
        _results = movies;
        _isSearching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.55,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.colors.medium.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Add to Watchlist',
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: context.colors.light),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: context.colors.textPrimary),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search movies',
                    hintStyle: TextStyle(color: context.colors.medium),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: context.colors.medium),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: Icon(Icons.close_rounded,
                                color: context.colors.medium),
                            onPressed: () {
                              _controller.clear();
                              _onSearchChanged('');
                            },
                          ),
                    filled: true,
                    fillColor: context.colors.surfaceElevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: FlixieColors.primary),
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildResults(scrollController)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResults(ScrollController scrollController) {
    if (_query.length < 3) {
      return Center(
        child: Text(
          'Search for a movie to add',
          style: TextStyle(color: context.colors.medium),
        ),
      );
    }

    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: FlixieColors.primary),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No movies found for "$_query"',
          style: TextStyle(color: context.colors.medium),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final movie = _results[index];
        final isAdded = widget.existingMovieIds.contains(movie.id);
        return _WatchlistMovieSearchResultTile(
          movie: movie,
          isAdded: isAdded,
          onTap: isAdded ? null : () => Navigator.pop(context, movie),
        );
      },
    );
  }
}

class _WatchlistMovieSearchResultTile extends StatelessWidget {
  const _WatchlistMovieSearchResultTile({
    required this.movie,
    required this.isAdded,
    required this.onTap,
  });

  final MovieShort movie;
  final bool isAdded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final posterUrl = movie.poster == null
        ? null
        : 'https://image.tmdb.org/t/p/w185${movie.poster}';
    final year = _movieYear(movie.releaseDate);
    final vote = hideMovieRatings(context, movie.id) ? null : movie.voteAverage;

    return Material(
      color: context.colors.surfaceElevated,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: SizedBox(
                  width: 48,
                  height: 72,
                  child: posterUrl == null
                      ? const WatchlistPosterPlaceholder()
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const WatchlistPosterPlaceholder(),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.name,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        if (year != null)
                          Text(
                            year,
                            style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 12,
                            ),
                          ),
                        if (year != null && vote != null && vote > 0)
                          Text(
                            '  •  ',
                            style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 12,
                            ),
                          ),
                        if (vote != null && vote > 0) ...[
                          Icon(Icons.star_rounded,
                              color: context.colors.tertiary, size: 13),
                          const SizedBox(width: 2),
                          Text(
                            vote.toStringAsFixed(1),
                            style: TextStyle(
                              color: context.colors.tertiary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                isAdded
                    ? Icons.check_circle_rounded
                    : Icons.add_circle_outline_rounded,
                color: isAdded ? context.colors.success : FlixieColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _movieYear(String? releaseDate) {
    if (releaseDate == null || releaseDate.isEmpty) return null;
    final parsed = DateTime.tryParse(releaseDate);
    if (parsed != null) return parsed.year.toString();
    return releaseDate.length >= 4 ? releaseDate.substring(0, 4) : null;
  }
}
