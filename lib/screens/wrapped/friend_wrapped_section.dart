import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/movie_wrapped.dart';
import '../../providers/movie_wrapped_provider.dart';
import '../../repositories/movie_features_repository.dart';
import '../../theme/app_theme.dart';
import '../home/section_header.dart';
import 'wrapped_widgets.dart';

class FriendWrappedSection extends StatefulWidget {
  const FriendWrappedSection({
    super.key,
    required this.userId,
    required this.joinYear,
    required this.username,
    this.scrollController,
  });
  final String userId;
  final int joinYear;
  final String username;
  final ScrollController? scrollController;

  @override
  State<FriendWrappedSection> createState() => _FriendWrappedSectionState();
}

class _FriendWrappedSectionState extends State<FriendWrappedSection> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = DateTime.now().year;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MovieWrappedProvider(
        repository: const MovieFeaturesRepository(),
        userId: widget.userId,
      )..loadYear(_year),
      child: _FriendWrappedBody(
        year: _year,
        joinYear: widget.joinYear,
        username: widget.username,
        scrollController: widget.scrollController,
        onYearChanged: (y) {
          setState(() => _year = y);
        },
      ),
    );
  }
}

class _FriendWrappedBody extends StatelessWidget {
  const _FriendWrappedBody({
    required this.year,
    required this.joinYear,
    required this.username,
    required this.scrollController,
    required this.onYearChanged,
  });
  final int year;
  final int joinYear;
  final String username;
  final ScrollController? scrollController;
  final ValueChanged<int> onYearChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<MovieWrappedProvider>();
    final wrapped = provider.wrapped;
    final currentYear = DateTime.now().year;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            '$username Yearly Wrapped',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.1,
            ),
          ),
        ),

        // Section header with year picker
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: FlixieColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'YEAR IN REVIEW',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              DropdownButton<int>(
                value: year,
                underline: const SizedBox(),
                dropdownColor: FlixieColors.tabBarBackgroundFocused,
                isDense: true,
                items: List.generate(
                  currentYear - joinYear + 1,
                  (i) => currentYear - i,
                )
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  onYearChanged(value);
                  context.read<MovieWrappedProvider>().loadYear(value);
                },
              ),
            ],
          ),
        ),

        if (provider.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (wrapped == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Text(
              provider.error ?? 'No wrapped data for $year.',
              style: const TextStyle(color: FlixieColors.medium),
            ),
          )
        else
          _WrappedContent(wrapped: wrapped),
      ],
    );
  }
}

class _WrappedContent extends StatelessWidget {
  const _WrappedContent({required this.wrapped});
  final MovieWrapped wrapped;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (wrapped.wrappedCard != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WrappedSummaryCard(card: wrapped.wrappedCard!),
          ),
          const SizedBox(height: 16),
        ],

        // Highest rated
        if (wrapped.highestRatedMovies.isNotEmpty) ...[
          const SizedBox(height: 8),
          const HomeSectionHeader(title: 'Highest Rated'),
          const SizedBox(height: 8),
          ...wrapped.highestRatedMovies.map(
            (m) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: WrappedRatedMovieRow(movie: m),
            ),
          ),
        ],

        if (wrapped.topGenres.isNotEmpty) ...[
          const SizedBox(height: 12),
          const HomeSectionHeader(title: 'Top Genres'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WrappedGenreChips(genres: wrapped.topGenres),
          ),
        ],

        if (wrapped.topDirectors.isNotEmpty) ...[
          const SizedBox(height: 12),
          const HomeSectionHeader(title: 'Top Directors'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: WrappedDirectorList(directors: wrapped.topDirectors),
          ),
        ],

        const SizedBox(height: 16),
      ],
    );
  }
}
