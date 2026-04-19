import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/movie_short.dart';
import '../../providers/auth_provider.dart';
import '../../services/search_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';

const _posterBase = 'https://image.tmdb.org/t/p/w185';

enum _OnboardingStep { favourites, watched, watchlist }

extension _OnboardingStepExt on _OnboardingStep {
  String get title {
    switch (this) {
      case _OnboardingStep.favourites:
        return 'Your Favourite Movies';
      case _OnboardingStep.watched:
        return 'Recently Watched';
      case _OnboardingStep.watchlist:
        return 'Your Watchlist';
    }
  }

  String get subtitle {
    switch (this) {
      case _OnboardingStep.favourites:
        return 'Add movies you love.';
      case _OnboardingStep.watched:
        return 'Movies you\'ve already seen.';
      case _OnboardingStep.watchlist:
        return 'Movies you want to watch next.';
    }
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  _OnboardingStep _currentStep = _OnboardingStep.favourites;

  // Selected movies per step, keyed by id
  final Map<_OnboardingStep, Map<int, MovieShort>> _selected = {
    _OnboardingStep.favourites: {},
    _OnboardingStep.watched: {},
    _OnboardingStep.watchlist: {},
  };

  // Search state
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _debounce;
  List<MovieShort> _results = [];
  bool _isSearching = false;

  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() => _query = value);
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(value.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isSearching = true);
    try {
      final results = await SearchService.search(query, type: 'movie');
      final movies = results.results
          .where((r) => !r.isPerson && r.movie != null)
          .map((r) => r.movie!)
          .toList();
      if (mounted) {
        setState(() {
          _results = movies;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _toggleMovie(MovieShort movie) {
    setState(() {
      final map = _selected[_currentStep]!;
      if (map.containsKey(movie.id)) {
        map.remove(movie.id);
      } else {
        map[movie.id] = movie;
      }
    });
  }

  bool _isSelected(int movieId) =>
      _selected[_currentStep]!.containsKey(movieId);

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _query = '';
      _results = [];
      _isSearching = false;
    });
  }

  Future<void> _saveCurrentStep() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;

    final movies = _selected[_currentStep]!.values.toList();
    if (movies.isEmpty) return;

    final futures = movies.map((m) async {
      try {
        switch (_currentStep) {
          case _OnboardingStep.favourites:
            await UserService.addToFavorites(userId, m.id);
          case _OnboardingStep.watched:
            await UserService.addToWatched(userId, m.id);
          case _OnboardingStep.watchlist:
            await UserService.addToWatchlist(userId, m.id);
        }
      } catch (_) {}
    });

    await Future.wait(futures);
  }

  Future<void> _advance({required bool skip}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      if (!skip) {
        await _saveCurrentStep();
      }

      final isLast = _currentStep == _OnboardingStep.watchlist;

      if (isLast) {
        await _finish();
      } else {
        _clearSearch();
        final nextIndex = _currentStep.index + 1;
        setState(() => _currentStep = _OnboardingStep.values[nextIndex]);
        _pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _finish() async {
    final auth = context.read<AuthProvider>();
    await auth.completeOnboarding();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D1B2A), Color(0xFF172B4D), Color(0xFF1A1040)],
          ),
        ),
        child: SafeArea(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _OnboardingStep.values.length,
            itemBuilder: (_, __) => _StepPage(
              step: _currentStep,
              searchController: _searchController,
              query: _query,
              results: _results,
              isSearching: _isSearching,
              isSaving: _isSaving,
              selected: _selected[_currentStep]!,
              onSearchChanged: _onSearchChanged,
              onToggleMovie: _toggleMovie,
              isMovieSelected: _isSelected,
              onSkip: () => _advance(skip: true),
              onContinue: () => _advance(skip: false),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({
    required this.step,
    required this.searchController,
    required this.query,
    required this.results,
    required this.isSearching,
    required this.isSaving,
    required this.selected,
    required this.onSearchChanged,
    required this.onToggleMovie,
    required this.isMovieSelected,
    required this.onSkip,
    required this.onContinue,
  });

  final _OnboardingStep step;
  final TextEditingController searchController;
  final String query;
  final List<MovieShort> results;
  final bool isSearching;
  final bool isSaving;
  final Map<int, MovieShort> selected;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<MovieShort> onToggleMovie;
  final bool Function(int) isMovieSelected;
  final VoidCallback onSkip;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step indicators
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: List.generate(
              _OnboardingStep.values.length,
              (i) => Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: i <= step.index
                        ? FlixieColors.primary
                        : FlixieColors.medium.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Title
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 4),
          child: Text(
            step.title,
            style: const TextStyle(
              color: FlixieColors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Text(
            step.subtitle,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 14,
            ),
          ),
        ),

        // Selected chips
        if (selected.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              scrollDirection: Axis.horizontal,
              itemCount: selected.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final movie = selected.values.elementAt(i);
                return InputChip(
                  label: Text(
                    movie.name,
                    style: const TextStyle(
                        color: FlixieColors.white, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  backgroundColor: FlixieColors.primary.withOpacity(0.25),
                  side: const BorderSide(color: FlixieColors.primary),
                  deleteIconColor: FlixieColors.light,
                  onDeleted: () => onToggleMovie(movie),
                );
              },
            ),
          ),

        if (selected.isNotEmpty) const SizedBox(height: 12),

        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(color: FlixieColors.white),
            decoration: InputDecoration(
              hintText: 'Search movies...',
              hintStyle: TextStyle(color: FlixieColors.light.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.search, color: FlixieColors.light),
              suffixIcon: query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: FlixieColors.light),
                      onPressed: () => onSearchChanged(''),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Results / loading
        Expanded(
          child: isSearching
              ? const Center(
                  child: CircularProgressIndicator(color: FlixieColors.primary))
              : query.isEmpty
                  ? _EmptySearchHint()
                  : results.isEmpty
                      ? const Center(
                          child: Text(
                            'No results found.',
                            style: TextStyle(color: FlixieColors.light),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: results.length,
                          itemBuilder: (_, i) => _MovieResultTile(
                            movie: results[i],
                            isSelected: isMovieSelected(results[i].id),
                            onTap: () => onToggleMovie(results[i]),
                          ),
                        ),
        ),

        // Buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving ? null : onSkip,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlixieColors.light,
                    side:
                        BorderSide(color: FlixieColors.light.withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Skip'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: isSaving ? null : onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: FlixieColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          step == _OnboardingStep.watchlist
                              ? 'Get Started'
                              : 'Continue',
                        ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MovieResultTile extends StatelessWidget {
  const _MovieResultTile({
    required this.movie,
    required this.isSelected,
    required this.onTap,
  });

  final MovieShort movie;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final year = movie.releaseDate != null && movie.releaseDate!.length >= 4
        ? movie.releaseDate!.substring(0, 4)
        : null;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: movie.poster != null
            ? CachedNetworkImage(
                imageUrl: '$_posterBase${movie.poster}',
                width: 40,
                height: 56,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _PosterPlaceholder(),
              )
            : _PosterPlaceholder(),
      ),
      title: Text(
        movie.name,
        style: const TextStyle(
            color: FlixieColors.white, fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: year != null
          ? Text(year,
              style: const TextStyle(color: FlixieColors.light, fontSize: 12))
          : null,
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: FlixieColors.primary)
          : Icon(Icons.add_circle_outline,
              color: FlixieColors.light.withOpacity(0.5)),
    );
  }
}

class _PosterPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 56,
      color: FlixieColors.medium.withOpacity(0.3),
      child: const Icon(Icons.movie, color: FlixieColors.medium, size: 20),
    );
  }
}

class _EmptySearchHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search,
              size: 48, color: FlixieColors.light.withOpacity(0.3)),
          const SizedBox(height: 12),
          Text(
            'Search to add movies',
            style: TextStyle(
                color: FlixieColors.light.withOpacity(0.5), fontSize: 14),
          ),
        ],
      ),
    );
  }
}
