import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_lists_controller.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

import 'package:flixie_app/features/movies/presentation/movie_list_selection.dart';
import 'add_movie_result_tile.dart';

class AddMovieToListSheet extends StatefulWidget {
  const AddMovieToListSheet({
    super.key,
    required this.listId,
    required this.listName,
  });

  final String listId;
  final String listName;

  @override
  State<AddMovieToListSheet> createState() => AddMovieToListSheetState();
}

class AddMovieToListSheetState extends State<AddMovieToListSheet> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  int _searchGeneration = 0;
  List<MovieShort> _results = const [];
  bool _searching = false;
  int? _addingMovieId;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    final generation = ++_searchGeneration;
    final query = value.trim();
    if (query.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query, generation);
    });
  }

  Future<void> _search(String query, int generation) async {
    try {
      final response = await SearchService.search(query);
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _results = response.results
            .map((item) => item.show == null
                ? item.movie
                : MovieShort(
                    id: item.show!.id,
                    name: item.show!.name,
                    poster: item.show!.posterPath,
                    releaseDate: item.show!.firstAirDate,
                    mediaType: 'tv'))
            .whereType<MovieShort>()
            .toList(growable: false);
        _searching = false;
      });
    } catch (e) {
      if (!mounted || generation != _searchGeneration) return;
      setState(() {
        _searching = false;
        _error = 'Unable to search titles right now.';
      });
    }
  }

  Future<void> _addMovie(MovieShort movie) async {
    if (_addingMovieId != null) return;
    final provider = context.read<MovieListsProvider>();
    final analytics = context.read<AnalyticsController>();
    setState(() {
      _addingMovieId = movie.id;
      _error = null;
    });
    final ok = movie.mediaType == 'tv'
        ? await provider.addShowToList(widget.listId, movie.id)
        : await provider.addMovieToList(widget.listId, movie.id);
    if (ok) await analytics.movieAddedToList();
    if (!mounted) return;
    setState(() => _addingMovieId = null);
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      // Keep the picker open so several titles can be added in one visit.
      messenger.showFlixieToast(FlixieToast(
          type: FlixieToastType.success, content: Text('Added ${movie.name}')));
    } else {
      setState(() {
        _error = provider.error ?? 'Unable to add title.';
      });
    }
  }

  bool _isAlreadyInList(MovieListsProvider provider, MovieShort movie) {
    final entries = provider.listMovies[widget.listId] ?? const [];
    return entries.any((entry) => movie.mediaType == 'tv'
        ? entry.showId == movie.id
        : entry.showId == 0 && entryMovieId(entry) == movie.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListsProvider>();
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
        child: SizedBox(
          height: sheetHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add to ${widget.listName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: context.colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                onChanged: _onQueryChanged,
                style: TextStyle(color: context.colors.white),
                decoration: InputDecoration(
                  hintText: 'Search movies or shows',
                  hintStyle: TextStyle(color: context.colors.medium),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: context.colors.medium,
                  ),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _controller.clear();
                            _onQueryChanged('');
                          },
                          icon: Icon(
                            Icons.close_rounded,
                            color: context.colors.medium,
                          ),
                        ),
                  filled: true,
                  fillColor: context.colors.tabBarBackgroundFocused,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: FlixieColors.primary),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    color: context.colors.danger,
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: _buildResults(provider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(MovieListsProvider provider) {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_controller.text.trim().length < 2) {
      return Center(
        child: Text(
          'Find movies or shows to start your collection.',
          style: TextStyle(color: context.colors.medium),
        ),
      );
    }
    if (_results.isEmpty) {
      return Center(
        child: Text(
          'No titles found.',
          style: TextStyle(color: context.colors.medium),
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final movie = _results[index];
        final alreadyAdded = _isAlreadyInList(provider, movie);
        final isAdding = _addingMovieId == movie.id;
        return AddMovieResultTile(
          movie: movie,
          alreadyAdded: alreadyAdded,
          isAdding: isAdding,
          onAdd: alreadyAdded || _addingMovieId != null
              ? null
              : () => _addMovie(movie),
        );
      },
    );
  }
}
