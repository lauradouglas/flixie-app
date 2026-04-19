import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/movie_wrapped_provider.dart';
import '../models/movie_wrapped.dart';
import '../repositories/movie_features_repository.dart';
import '../theme/app_theme.dart';
import 'home/section_header.dart';

const _monthNames = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

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
                        child: _WrappedSummaryCard(card: wrapped.wrappedCard!),
                      ),
                      const SizedBox(height: 20),
                    ],
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _HeadlineCard(
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
                            child: _HeadlineCard(
                              title: 'Total Watches',
                              value: '${wrapped.rewatchCount}',
                              icon: Icons.replay,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _HeadlineCard(
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
                      child: _MonthGrid(months: wrapped.monthlyWatchCounts),
                    ),
                    if (wrapped.topGenres.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const HomeSectionHeader(title: 'Top Genres'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _GenreChips(genres: wrapped.topGenres),
                      ),
                    ],
                    if (wrapped.topDirectors.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const HomeSectionHeader(title: 'Top Directors'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _DirectorList(directors: wrapped.topDirectors),
                      ),
                    ],
                    if (wrapped.highestRatedMovies.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const HomeSectionHeader(title: 'Highest Rated'),
                      const SizedBox(height: 8),
                      ...wrapped.highestRatedMovies.map(
                        (m) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _RatedMovieRow(movie: m),
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
                          child: _RewatchMovieRow(movie: m),
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }
}

// ── Month grid ────────────────────────────────────────────────────────────────

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.months});
  final List<WrappedMonthlyCount> months;

  @override
  Widget build(BuildContext context) {
    // Build a map so we can look up any month 1-12
    final countByMonth = {for (final m in months) m.month: m.count};
    final maxCount = countByMonth.values.fold(0, (a, b) => a > b ? a : b);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
      ),
      itemCount: 12,
      itemBuilder: (_, i) {
        final month = i + 1;
        final count = countByMonth[month] ?? 0;
        final intensity = maxCount > 0 ? count / maxCount : 0.0;
        final bg = Color.lerp(
          FlixieColors.tabBarBackgroundFocused,
          FlixieColors.primary,
          intensity * 0.85,
        )!;
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _monthNames[i],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: intensity > 0.4 ? Colors.white : FlixieColors.light,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: intensity > 0.4 ? Colors.white : FlixieColors.medium,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Genre chips ───────────────────────────────────────────────────────────────

class _GenreChips extends StatelessWidget {
  const _GenreChips({required this.genres});
  final List<WrappedNamedCount> genres;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: genres.map((g) {
        return Chip(
          label: Text('${g.name}  ${g.count}'),
          labelStyle: const TextStyle(color: FlixieColors.white, fontSize: 13),
          backgroundColor: FlixieColors.primary.withOpacity(0.25),
          side: const BorderSide(color: FlixieColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        );
      }).toList(),
    );
  }
}

// ── Director list ─────────────────────────────────────────────────────────────

class _DirectorList extends StatelessWidget {
  const _DirectorList({required this.directors});
  final List<WrappedNamedCount> directors;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: directors.map((d) {
        final tappable = d.personId != null;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            d.name,
            style: TextStyle(
              color: tappable ? FlixieColors.primary : FlixieColors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${d.count} film${d.count == 1 ? '' : 's'}',
                  style: const TextStyle(color: FlixieColors.medium)),
              if (tappable) ...[
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right,
                    color: FlixieColors.medium, size: 18),
              ],
            ],
          ),
          onTap: tappable ? () => context.push('/people/${d.personId}') : null,
        );
      }).toList(),
    );
  }
}

// ── Wrapped summary card ──────────────────────────────────────────────────────

class _WrappedSummaryCard extends StatelessWidget {
  const _WrappedSummaryCard({required this.card});
  final WrappedCard card;

  @override
  Widget build(BuildContext context) {
    final posterPath = card.mostRewatchedMovie?.posterPath;
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w342$posterPath'
        : null;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1040), Color(0xFF2A1B5E), Color(0xFF0D1B2A)],
        ),
        border: Border.all(color: FlixieColors.primary.withOpacity(0.4)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Faint blurred poster background
            if (posterUrl != null)
              Positioned.fill(
                child: Opacity(
                  opacity: 0.08,
                  child: CachedNetworkImage(
                    imageUrl: posterUrl,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Year badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: FlixieColors.primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: FlixieColors.primary.withOpacity(0.6)),
                    ),
                    child: Text(
                      '${card.year} Wrapped',
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Total watches
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${card.totalWatchCount}',
                          style: const TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            height: 1,
                          ),
                        ),
                        const TextSpan(
                          text: ' watches',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: FlixieColors.light,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Top genre + top director row
                  Row(
                    children: [
                      if (card.topGenre != null)
                        Expanded(
                          child: _SummaryStatColumn(
                            label: 'Top Genre',
                            value: card.topGenre!.name,
                            icon: Icons.category_outlined,
                          ),
                        ),
                      if (card.topGenre != null && card.topDirector != null)
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white12,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      if (card.topDirector != null)
                        Expanded(
                          child: _SummaryStatColumn(
                            label: 'Top Director',
                            value: card.topDirector!.name,
                            icon: Icons.movie_creation_outlined,
                          ),
                        ),
                    ],
                  ),
                  // Most rewatched movie
                  if (card.mostRewatchedMovie != null) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white12),
                    const SizedBox(height: 12),
                    _SummaryMovieRow(
                      movie: card.mostRewatchedMovie!,
                      posterUrl: posterUrl,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStatColumn extends StatelessWidget {
  const _SummaryStatColumn({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 12, color: FlixieColors.medium),
            const SizedBox(width: 4),
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: FlixieColors.medium)),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _SummaryMovieRow extends StatelessWidget {
  const _SummaryMovieRow({required this.movie, required this.posterUrl});
  final WrappedTopMovie movie;
  final String? posterUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            width: 36,
            height: 52,
            child: posterUrl == null
                ? Container(
                    color: FlixieColors.tabBarBackgroundFocused,
                    child: const Icon(Icons.movie_outlined, size: 16),
                  )
                : CachedNetworkImage(imageUrl: posterUrl!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Most Rewatched',
                  style: TextStyle(fontSize: 11, color: FlixieColors.medium)),
              const SizedBox(height: 2),
              Text(
                movie.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: FlixieColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${movie.watchCount}x',
            style: const TextStyle(
              color: FlixieColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Movie rows ────────────────────────────────────────────────────────────────

class _RatedMovieRow extends StatelessWidget {
  const _RatedMovieRow({required this.movie});
  final WrappedRatedMovie movie;

  @override
  Widget build(BuildContext context) {
    final url = movie.posterPath != null
        ? 'https://image.tmdb.org/t/p/w185${movie.posterPath}'
        : null;
    return _MovieRowBase(
      movieId: movie.movieId,
      title: movie.title,
      posterUrl: url,
      badge: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 15),
          const SizedBox(width: 3),
          Text(
            '${movie.rating}/10',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _RewatchMovieRow extends StatelessWidget {
  const _RewatchMovieRow({required this.movie});
  final WrappedTopMovie movie;

  @override
  Widget build(BuildContext context) {
    final url = movie.posterPath != null
        ? 'https://image.tmdb.org/t/p/w185${movie.posterPath}'
        : null;
    return _MovieRowBase(
      movieId: movie.movieId,
      title: movie.title,
      posterUrl: url,
      badge: Text(
        '${movie.watchCount}x',
        style: const TextStyle(
          color: FlixieColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}

class _MovieRowBase extends StatelessWidget {
  const _MovieRowBase({
    required this.movieId,
    required this.title,
    required this.posterUrl,
    required this.badge,
  });
  final int movieId;
  final String title;
  final String? posterUrl;
  final Widget badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/movies/$movieId'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 64,
                child: posterUrl == null
                    ? Container(
                        color: const Color(0xFF1E1E2E),
                        child: const Icon(Icons.movie_outlined,
                            size: 20, color: FlixieColors.medium),
                      )
                    : CachedNetworkImage(
                        imageUrl: posterUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            Container(color: const Color(0xFF1E1E2E)),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            badge,
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: FlixieColors.medium, size: 18),
          ],
        ),
      ),
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({
    required this.title,
    required this.value,
    required this.icon,
  });
  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: FlixieColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20)),
                Text(title, style: const TextStyle(color: FlixieColors.medium)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
