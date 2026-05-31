import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/genre.dart';
import '../../models/movie_short.dart';
import '../../providers/auth_provider.dart';
import '../../services/reference_data_service.dart';
import '../../services/search_service.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../auth/auth_ui.dart';

enum _OnboardingStep { preferences, success }

enum _MovieBucket { favourites, recentlyWatched }

const _popularGenres = [
  'Action',
  'Sci-Fi',
  'Drama',
  'Thriller',
  'Comedy',
  'Adventure',
  'Animation',
  'Fantasy',
  'Horror',
  'Crime',
];

String? validateFavouriteMovieCount(int count) {
  if (count < 3 || count > 5) {
    return 'Please select between 3 and 5 favourite movies.';
  }
  return null;
}

bool canAddOnboardingMovie(
  Map<int, MovieShort> selected,
  int movieId, {
  int maxCount = 5,
}) {
  return selected.containsKey(movieId) || selected.length < maxCount;
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  _OnboardingStep _step = _OnboardingStep.preferences;
  bool _saving = false;

  final Map<int, MovieShort> _favourites = {};
  final Map<int, MovieShort> _recentlyWatched = {};

  final TextEditingController _genreSearchController = TextEditingController();
  List<Genre> _genres = [];
  final Set<int> _selectedGenreIds = {};
  bool _loadingGenres = true;

  @override
  void initState() {
    super.initState();
    _loadGenres();
  }

  @override
  void dispose() {
    _genreSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await ReferenceDataService.getGenres();
      if (!mounted) return;
      setState(() {
        _genres = filterSupportedGenres(genres);
        _loadingGenres = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingGenres = false);
    }
  }

  Future<List<MovieShort>> _searchMovies(String query) async {
    final results = await SearchService.search(query, type: 'movie');
    return results.results
        .where((item) => !item.isPerson && item.movie != null)
        .map((item) => item.movie!)
        .toList(growable: false);
  }

  Future<void> _pickMovie(_MovieBucket bucket) async {
    final movie = await showModalBottomSheet<MovieShort>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF10355E),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: MovieSearchSheet(searchMovies: _searchMovies),
      ),
    );

    if (!mounted || movie == null) return;
    final selectedMap = bucket == _MovieBucket.favourites
        ? _favourites
        : _recentlyWatched;
    setState(() {
      if (!canAddOnboardingMovie(selectedMap, movie.id)) {
        return;
      }
      selectedMap[movie.id] = movie;
    });
  }

  Future<void> _savePreferences() async {
    final favouriteValidationError =
        validateFavouriteMovieCount(_favourites.length);
    if (favouriteValidationError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(favouriteValidationError),
          backgroundColor: FlixieColors.danger,
        ),
      );
      return;
    }
    if (_saving) return;

    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _saving = false);
      return;
    }

    try {
      await Future.wait(
        _favourites.keys.map((movieId) => UserService.addToFavorites(userId, movieId)),
      );
      if (_recentlyWatched.isNotEmpty) {
        await Future.wait(
          _recentlyWatched.keys
              .map((movieId) => UserService.addToWatched(userId, movieId)),
        );
      }
      if (_selectedGenreIds.isNotEmpty) {
        await UserService.addFavoriteGenres(userId, _selectedGenreIds.toList());
      }
      await auth.completeOnboarding();
      if (!mounted) return;
      setState(() => _step = _OnboardingStep.success);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to finish onboarding right now.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<Genre> get _filteredGenres {
    final query = _genreSearchController.text.trim().toLowerCase();
    final genres = _genres.where((genre) {
      if (query.isEmpty) return true;
      return genre.name.toLowerCase().contains(query);
    }).toList();
    genres.sort((a, b) {
      final aPopular = _popularGenres.contains(a.name);
      final bPopular = _popularGenres.contains(b.name);
      if (aPopular != bPopular) return aPopular ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return genres;
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      topLabel: _step == _OnboardingStep.preferences ? 'Step 2 of 3' : 'Step 3 of 3',
      title: Text(
        _step == _OnboardingStep.preferences
            ? 'Tell us what you love'
            : 'Welcome to Flixie! 🎉',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              color: FlixieColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
      ),
      subtitle: _step == _OnboardingStep.preferences
          ? 'Add favourites, recent watches, and optional genres.'
          : 'Your account has been created and your recommendations are ready.',
      onBack: null,
      cardPadding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
      cardChild: _step == _OnboardingStep.preferences
          ? _buildPreferencesStep()
          : _buildSuccessStep(),
    );
  }

  Widget _buildPreferencesStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingProgressIndicator(currentStep: 1, totalSteps: 3),
        const SizedBox(height: 18),
        _buildMovieSection(
          title: 'Favourite Movies ⭐',
          subtitle: 'Select 3–5 movies',
          selected: _favourites,
          maxCount: 5,
          onAdd: () => _pickMovie(_MovieBucket.favourites),
          onRemove: (movieId) => setState(() => _favourites.remove(movieId)),
        ),
        const SizedBox(height: 18),
        _buildMovieSection(
          title: 'Recently Watched 🎬',
          subtitle: 'Optional (up to 5)',
          selected: _recentlyWatched,
          maxCount: 5,
          onAdd: () => _pickMovie(_MovieBucket.recentlyWatched),
          onRemove: (movieId) => setState(() => _recentlyWatched.remove(movieId)),
        ),
        const SizedBox(height: 18),
        _buildGenreSection(),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Continue',
          isLoading: _saving,
          onPressed: _saving ? null : _savePreferences,
        ),
      ],
    );
  }

  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingProgressIndicator(currentStep: 2, totalSteps: 3),
        const SizedBox(height: 22),
        _buildSummaryTile(
          icon: Icons.star_rounded,
          label: '${_favourites.length} Favourite Movies',
          subtitle: 'We’ll recommend movies you’ll love.',
        ),
        const SizedBox(height: 12),
        _buildSummaryTile(
          icon: Icons.movie_creation_outlined,
          label: '${_recentlyWatched.length} Recently Watched',
          subtitle: 'Fresh picks based on what you’ve watched.',
        ),
        const SizedBox(height: 12),
        _buildSummaryTile(
          icon: Icons.favorite_rounded,
          label: '${_selectedGenreIds.length} Favourite Genres',
          subtitle: 'More of what you enjoy.',
        ),
        const SizedBox(height: 22),
        PrimaryButton(
          label: 'Enter Flixie',
          onPressed: () => context.go('/'),
        ),
      ],
    );
  }

  Widget _buildMovieSection({
    required String title,
    required String subtitle,
    required Map<int, MovieShort> selected,
    required int maxCount,
    required VoidCallback onAdd,
    required ValueChanged<int> onRemove,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: FlixieColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${selected.length}/$maxCount',
              style: const TextStyle(color: FlixieColors.light),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: FlixieColors.light),
        ),
        const SizedBox(height: 10),
        if (selected.isEmpty)
          SecondaryButton(
            label: 'Search movies',
            onPressed: onAdd,
          )
        else ...[
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (_, index) {
                final movie = selected.values.elementAt(index);
                return MovieSelectionCard(
                  movie: movie,
                  onRemove: () => onRemove(movie.id),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemCount: selected.length,
            ),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: selected.length >= maxCount ? 'Maximum selected' : 'Add movie',
            onPressed: selected.length >= maxCount ? null : onAdd,
          ),
        ],
      ],
    );
  }

  Widget _buildGenreSection() {
    final genres = _filteredGenres;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Favourite Genres',
                style: TextStyle(
                  color: FlixieColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${_selectedGenreIds.length} selected',
              style: const TextStyle(color: FlixieColors.light),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Optional',
          style: TextStyle(color: FlixieColors.light),
        ),
        const SizedBox(height: 10),
        AppTextField(
          controller: _genreSearchController,
          label: 'Search genres',
          prefixIcon: Icons.search,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 10),
        if (_loadingGenres)
          const Center(child: CircularProgressIndicator())
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: genres.map((genre) {
              final selected = _selectedGenreIds.contains(genre.id);
              return GenreChip(
                label: genre.name,
                selected: selected,
                onTap: () => setState(() {
                  if (selected) {
                    _selectedGenreIds.remove(genre.id);
                  } else {
                    _selectedGenreIds.add(genre.id);
                  }
                }),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSummaryTile({
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF10355E).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: FlixieColors.primaryTint),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: FlixieColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: FlixieColors.light, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
