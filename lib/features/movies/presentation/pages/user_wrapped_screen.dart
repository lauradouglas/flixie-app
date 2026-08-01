import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/movie_wrapped.dart';
import 'package:flixie_app/models/user.dart';

class UserWrappedScreen extends StatefulWidget {
  const UserWrappedScreen({super.key, this.userId, this.initialYear});

  final String? userId;
  final int? initialYear;

  @override
  State<UserWrappedScreen> createState() => _UserWrappedScreenState();
}

class _UserWrappedScreenState extends State<UserWrappedScreen> {
  late int _year;
  late Future<(User, MovieWrapped)> _future;

  @override
  void initState() {
    super.initState();
    _year = widget.initialYear ?? DateTime.now().year;
    _future = _load();
  }

  Future<(User, MovieWrapped)> _load() async {
    final current = context.read<AuthProvider>().dbUser;
    final id = widget.userId ?? current?.id;
    if (id == null) throw StateError('Sign in to view Wrapped');
    final user =
        current?.id == id ? current! : await UserService.getUserById(id);
    final wrapped = await UserService.getMovieWrapped(id, _year);
    return (user, wrapped);
  }

  void _changeYear(int year) {
    setState(() {
      _year = year;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlixieColors.navy,
      body: FutureBuilder<(User, MovieWrapped)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _WrappedError(
              message: snapshot.error?.toString() ?? 'Wrapped is unavailable.',
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final (user, wrapped) = snapshot.data!;
          final me = context.read<AuthProvider>().dbUser?.id == user.id;
          return _WrappedPage(
            user: user,
            wrapped: wrapped,
            isOwner: me,
            year: _year,
            onYearChanged: _changeYear,
          );
        },
      ),
    );
  }
}

class _WrappedPage extends StatelessWidget {
  const _WrappedPage({
    required this.user,
    required this.wrapped,
    required this.isOwner,
    required this.year,
    required this.onYearChanged,
  });

  final User user;
  final MovieWrapped wrapped;
  final bool isOwner;
  final int year;
  final ValueChanged<int> onYearChanged;

  List<_WrappedFilm> get films {
    final seen = <int>{};
    final result = <_WrappedFilm>[];
    for (final movie in wrapped.highestRatedMovies) {
      if (seen.add(movie.movieId)) {
        result.add(_WrappedFilm(movie.movieId, movie.title, movie.posterPath,
            rating: movie.rating));
      }
    }
    for (final movie in wrapped.topMovies) {
      if (seen.add(movie.movieId)) {
        result.add(_WrappedFilm(movie.movieId, movie.title, movie.posterPath));
      }
    }
    return result.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final featured = films;
    final subject = isOwner ? 'Your' : 'Their';
    final joinYear = DateTime.tryParse(user.createdAt ?? '')?.year ?? year;
    return Stack(
      children: [
        const Positioned.fill(child: _WrappedBackground()),
        SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _topBar(context, joinYear)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                sliver: SliverList.list(children: [
                  _identity(),
                  const SizedBox(height: 12),
                  _PosterFan(films: featured),
                  Transform.translate(
                    offset: const Offset(0, -8),
                    child: _headline(),
                  ),
                  const SizedBox(height: 14),
                  _highlights(),
                  if (featured.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionTitle(
                        '$subject year in ${_number(films.length)} films'),
                    const SizedBox(height: 10),
                    _FilmGrid(films: featured),
                  ],
                  if (wrapped.highestRatedMovies.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionTitle('$subject standout'),
                    const SizedBox(height: 10),
                    _Standout(movie: wrapped.highestRatedMovies.first),
                  ],
                  if (wrapped.topGenres.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const _SectionTitle('Taste snapshot'),
                    const SizedBox(height: 10),
                    _TastePills(genres: wrapped.topGenres.take(3).toList()),
                  ],
                  const SizedBox(height: 8),
                ]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _topBar(BuildContext context, int joinYear) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
        child: Row(children: [
          IconButton(
              icon: const Icon(Icons.close), onPressed: () => context.pop()),
          Expanded(
            child: Text(
              '${isOwner ? 'Your' : "${user.username}'s"} $year Wrapped',
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          PopupMenuButton<int>(
            initialValue: year,
            onSelected: onYearChanged,
            itemBuilder: (_) => [
              for (var value = DateTime.now().year; value >= joinYear; value--)
                PopupMenuItem(value: value, child: Text('$value')),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                  children: [Text('$year'), const Icon(Icons.arrow_drop_down)]),
            ),
          ),
          const SizedBox(width: 8),
        ]),
      );

  Widget _identity() =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        ProfileAvatarView(
          avatar: user.avatar,
          fallbackText: user.username.characters.first.toUpperCase(),
          fallbackColor: FlixieColors.primary,
          profileBadges: user.profileBadges,
          size: 44,
        ),
        const SizedBox(width: 9),
        Flexible(
          child: Text('@${user.username}',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: FlixieColors.primaryTint, fontSize: 16)),
        ),
      ]);

  Widget _headline() => Column(children: [
        Text('${wrapped.rewatchCount}',
            style: const TextStyle(
                fontSize: 74, height: .9, fontWeight: FontWeight.w900)),
        const Text('watches', style: TextStyle(fontSize: 34, letterSpacing: 4)),
        const SizedBox(height: 3),
        Text(
          '${wrapped.totalMoviesWatched} movies · ${wrapped.totalHoursWatched.toStringAsFixed(1)}h',
          style: const TextStyle(color: FlixieColors.light, fontSize: 17),
        ),
      ]);

  Widget _highlights() => Row(children: [
        Expanded(
            child: _Highlight(
                icon: Icons.explore_outlined,
                label: 'Top genre',
                value: wrapped.topGenres.firstOrNull?.name ?? 'Discovering')),
        const SizedBox(width: 10),
        Expanded(
            child: _Highlight(
                icon: Icons.movie_creation_outlined,
                label: 'Top director',
                value:
                    wrapped.topDirectors.firstOrNull?.name ?? 'Discovering')),
      ]);
}

class _WrappedBackground extends StatelessWidget {
  const _WrappedBackground();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.7),
            radius: 1.05,
            colors: [
              Color(0xFF3B1465),
              FlixieColors.background,
              FlixieColors.navy
            ],
          ),
        ),
      );
}

class _PosterFan extends StatelessWidget {
  const _PosterFan({required this.films});
  final List<_WrappedFilm> films;
  @override
  Widget build(BuildContext context) {
    if (films.isEmpty) {
      return const SizedBox(
          height: 150,
          child: Icon(Icons.movie_filter_outlined,
              size: 80, color: FlixieColors.primary));
    }
    return SizedBox(
      height: 245,
      child: LayoutBuilder(builder: (context, constraints) {
        final cardWidth = math.min(145.0, constraints.maxWidth * .35);
        return Stack(alignment: Alignment.center, children: [
          for (var i = 0; i < films.length; i++)
            Transform.translate(
              offset: Offset((i - (films.length - 1) / 2) * cardWidth * .65,
                  i.isEven ? 10 : 0),
              child: Transform.rotate(
                angle: (i - (films.length - 1) / 2) * .08,
                child: _Poster(
                    path: films[i].posterPath, width: cardWidth, height: 210),
              ),
            ),
        ]);
      }),
    );
  }
}

class _FilmGrid extends StatelessWidget {
  const _FilmGrid({required this.films});
  final List<_WrappedFilm> films;
  @override
  Widget build(BuildContext context) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: films.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.7,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10),
        itemBuilder: (context, i) {
          final film = films[i];
          return InkWell(
            onTap: () => context.push('/movies/${film.id}'),
            borderRadius: BorderRadius.circular(14),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(fit: StackFit.expand, children: [
                _Poster(
                    path: film.posterPath,
                    width: double.infinity,
                    height: double.infinity),
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.black87]))),
                Positioned(
                    left: 10,
                    right: 10,
                    bottom: 8,
                    child: Row(children: [
                      Expanded(
                          child: Text(film.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      if (film.rating != null)
                        Text('★ ${film.rating}/10',
                            style: const TextStyle(
                                color: FlixieColors.warning,
                                fontWeight: FontWeight.w700)),
                    ])),
              ]),
            ),
          );
        },
      );
}

class _Standout extends StatelessWidget {
  const _Standout({required this.movie});
  final WrappedRatedMovie movie;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.push('/movies/${movie.movieId}'),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 116,
          decoration: BoxDecoration(
              color: FlixieColors.surface.withValues(alpha: .82),
              border: Border.all(color: FlixieColors.tabBarBorder),
              borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(15)),
                child:
                    _Poster(path: movie.posterPath, width: 125, height: 116)),
            Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(movie.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 19, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 7),
                          Text('Highest rated  ★ ${movie.rating}/10',
                              style:
                                  const TextStyle(color: FlixieColors.warning)),
                        ]))),
            const Padding(
                padding: EdgeInsets.only(right: 14),
                child: Icon(Icons.diamond_outlined,
                    color: FlixieColors.warning, size: 34)),
          ]),
        ),
      );
}

class _TastePills extends StatelessWidget {
  const _TastePills({required this.genres});
  final List<WrappedNamedCount> genres;
  @override
  Widget build(BuildContext context) {
    const colors = [
      FlixieColors.warning,
      FlixieColors.secondary,
      FlixieColors.primary
    ];
    return Row(children: [
      for (var i = 0; i < genres.length; i++)
        Expanded(
            child: Padding(
                padding: EdgeInsets.only(right: i == genres.length - 1 ? 0 : 8),
                child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                        border: Border.all(color: colors[i]),
                        borderRadius: BorderRadius.circular(22)),
                    child: Text('${genres[i].name}  ${genres[i].count}',
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: colors[i])))))
    ]);
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Container(
        height: 68,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: .7),
            border: Border.all(color: FlixieColors.tabBarBorder),
            borderRadius: BorderRadius.circular(15)),
        child: Row(children: [
          Icon(icon, color: FlixieColors.warning),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: const TextStyle(
                        color: FlixieColors.medium, fontSize: 11)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700))
              ]))
        ]),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 4,
            height: 26,
            decoration: BoxDecoration(
                color: FlixieColors.primary,
                borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(
                fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: 1.2))
      ]);
}

class _Poster extends StatelessWidget {
  const _Poster(
      {required this.path, required this.width, required this.height});
  final String? path;
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) {
    final url = path?.isNotEmpty == true
        ? 'https://image.tmdb.org/t/p/w500$path'
        : null;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white12)),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? const Icon(Icons.movie_outlined, color: FlixieColors.medium)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined)),
    );
  }
}

class _WrappedError extends StatelessWidget {
  const _WrappedError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => SafeArea(
          child: Column(children: [
        Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
                onPressed: () => context.pop(), icon: const Icon(Icons.close))),
        Expanded(
            child: Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.auto_awesome,
                          size: 54, color: FlixieColors.primary),
                      const SizedBox(height: 14),
                      Text(message, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      OutlinedButton(
                          onPressed: onRetry, child: const Text('Try again'))
                    ]))))
      ]));
}

class _WrappedFilm {
  const _WrappedFilm(this.id, this.title, this.posterPath, {this.rating});
  final int id;
  final String title;
  final String? posterPath;
  final int? rating;
}

String _number(int value) =>
    const ['zero', 'one', 'two', 'three', 'four'][value.clamp(0, 4)];
