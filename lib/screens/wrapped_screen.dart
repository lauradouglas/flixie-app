import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/movie_wrapped_provider.dart';
import '../repositories/movie_features_repository.dart';
import '../theme/app_theme.dart';

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
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Sign in to view wrapped')));
    }
    final currentYear = DateTime.now().year;
    return ChangeNotifierProvider(
      create: (_) => MovieWrappedProvider(
        repository: const MovieFeaturesRepository(),
        userId: userId,
      )..loadYear(currentYear),
      child: _WrappedView(initialYear: currentYear),
    );
  }
}

class _WrappedView extends StatefulWidget {
  const _WrappedView({required this.initialYear});
  final int initialYear;

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
            items: List.generate(6, (i) => DateTime.now().year - i)
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
                  padding: const EdgeInsets.all(16),
                  children: [
                    _HeadlineCard(
                      title: 'Movies Watched',
                      value: '${wrapped.totalMoviesWatched}',
                      icon: Icons.movie_outlined,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _HeadlineCard(
                            title: 'Rewatches',
                            value: '${wrapped.rewatchCount}',
                            icon: Icons.replay,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _HeadlineCard(
                            title: 'Hours',
                            value: wrapped.totalHoursWatched.toStringAsFixed(1),
                            icon: Icons.schedule_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _SectionTitle('Monthly Activity'),
                    const SizedBox(height: 10),
                    ...wrapped.monthlyWatchCounts.map(
                      (m) => ListTile(
                        dense: true,
                        title: Text(_monthNames[((m.month - 1).clamp(0, 11) as int)]),
                        trailing: Text('${m.count}'),
                      ),
                    ),
                    if (wrapped.topGenres.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SectionTitle('Top Genres'),
                      ...wrapped.topGenres
                          .map((g) => ListTile(dense: true, title: Text(g.name), trailing: Text('${g.count}'))),
                    ],
                    if (wrapped.topDirectors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SectionTitle('Top Directors'),
                      ...wrapped.topDirectors
                          .map((d) => ListTile(dense: true, title: Text(d.name), trailing: Text('${d.count}'))),
                    ],
                    if (wrapped.topMovies.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      const _SectionTitle('Top Movies'),
                      ...wrapped.topMovies.map((m) {
                        final poster = m.posterPath;
                        final url = poster != null ? 'https://image.tmdb.org/t/p/w185$poster' : null;
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                              width: 40,
                              height: 56,
                              child: url == null
                                  ? Container(
                                      color: FlixieColors.tabBarBackgroundFocused,
                                      child: const Icon(Icons.movie_outlined, size: 18),
                                    )
                                  : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                            ),
                          ),
                          title: Text(m.title),
                          trailing: Text('${m.watchCount}x'),
                        );
                      }),
                    ],
                  ],
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                Text(title, style: const TextStyle(color: FlixieColors.medium)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}
