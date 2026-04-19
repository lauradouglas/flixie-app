import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/movie_wrapped_provider.dart';
import '../repositories/movie_features_repository.dart';
import '../theme/app_theme.dart';
import 'home/section_header.dart';
import 'wrapped/wrapped_widgets.dart';

class WrappedScreen extends StatelessWidget {
  const WrappedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().dbUser;
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('Sign in to view wrapped')));
    }
    final currentYear = DateTime.now().year;
    final joinYear = user.createdAt != null
        ? (DateTime.tryParse(user.createdAt!)?.year ?? currentYear)
        : currentYear;
    return ChangeNotifierProvider(
      create: (_) => MovieWrappedProvider(
        repository: const MovieFeaturesRepository(),
        userId: user.id,
      )..loadYear(currentYear),
      child: _WrappedView(initialYear: currentYear, joinYear: joinYear),
    );
  }
}

class _WrappedView extends StatefulWidget {
  const _WrappedView({required this.initialYear, required this.joinYear});
  final int initialYear;
  final int joinYear;

  @override
  State<_WrappedView> createState() => _WrappedViewState();
}

class _WrappedViewState extends State<_WrappedView> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieWrappedProvider>();
    final wrapped = provider.wrapped;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Year in Review'),
        actions: [
          DropdownButton<int>(
            value: _year,
            underline: const SizedBox(),
            dropdownColor: FlixieColors.tabBarBackgroundFocused,
            items: List.generate(
              DateTime.now().year - widget.joinYear + 1,
              (i) => DateTime.now().year - i,
            )
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              setState(() => _year = value);
              context.read<MovieWrappedProvider>().loadYear(value);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : wrapped == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      provider.error ?? 'No wrapped data for $_year.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: FlixieColors.medium),
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: [
                    if (wrapped.wrappedCard != null) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: WrappedSummaryCard(card: wrapped.wrappedCard!),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: WrappedHeadlineCard(
                        title: 'Movies Watched',
                        value: '${wrapped.totalMoviesWatched}',
                        icon: Icons.movie_outlined,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: WrappedHeadlineCard(
                              title: 'Total Watches',
                              value: '${wrapped.rewatchCount}',
                              icon: Icons.replay,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: WrappedHeadlineCard(
                              title: 'Hours',
                              value:
                                  wrapped.totalHoursWatched.toStringAsFixed(1),
                              icon: Icons.schedule_outlined,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const HomeSectionHeader(title: 'Monthly Activity'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child:
                          WrappedMonthGrid(months: wrapped.monthlyWatchCounts),
                    ),
                    if (wrapped.topGenres.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const HomeSectionHeader(title: 'Top Genres'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: WrappedGenreChips(genres: wrapped.topGenres),
                      ),
                    ],
                    if (wrapped.topDirectors.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const HomeSectionHeader(title: 'Top Directors'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: WrappedDirectorList(
                            directors: wrapped.topDirectors),
                      ),
                    ],
                    if (wrapped.highestRatedMovies.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const HomeSectionHeader(title: 'Highest Rated'),
                      const SizedBox(height: 8),
                      ...wrapped.highestRatedMovies.map(
                        (m) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: WrappedRatedMovieRow(movie: m),
                        ),
                      ),
                    ],
                    if (wrapped.topMovies.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const HomeSectionHeader(title: 'Most Rewatched'),
                      const SizedBox(height: 8),
                      ...wrapped.topMovies.map(
                        (m) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: WrappedRewatchMovieRow(movie: m),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}
