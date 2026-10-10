import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/models/watchlist_movie.dart';
import 'movie_collection.dart';

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.collectionId});
  final int collectionId;
  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late Future<MovieCollection> _future;
  @override
  void initState() {
    super.initState();
    _future = _loadCollection();
  }

  Future<MovieCollection> _loadCollection() {
    final future = MovieCollection.load(widget.collectionId);
    // A retry can fail before the next frame subscribes FutureBuilder.
    // Observe that error immediately while keeping it on the original future
    // for the page's retry state.
    future.then<void>((_) {}, onError: (Object error, StackTrace stack) {});
    return future;
  }

  Future<void> _refresh() async {
    final next = _loadCollection();
    setState(() => _future = next);
    await next;
  }

  Future<void> _openFilm(CollectionFilm film) async {
    await context.push(movieDetailPath(film.id, source: DetailSource.list));
    if (mounted) {
      try {
        await _refresh();
      } catch (_) {}
    }
  }

  Future<void> _watchRest(MovieCollection collection) async {
    if (!await GuestAccess.require(context,
        title: 'Track your collection progress',
        path: '/collections/${widget.collectionId}')) {
      return;
    }
    if (!mounted) return;
    await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => _WatchRestSheet(collection: collection));
    if (mounted) setState(() {});
  }

  Future<void> _plan(MovieCollection collection) async {
    if (!await GuestAccess.require(context,
        title: 'Plan a collection with friends',
        path: '/collections/${widget.collectionId}')) {
      return;
    }
    if (!mounted) return;
    final film = await showModalBottomSheet<CollectionFilm>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .7,
            child: Column(children: [
              const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Which film shall we watch?',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700))),
              Expanded(
                  child: ListView(children: [
                for (final film in collection.films)
                  _FilmRow(
                      film: film, onTap: () => Navigator.pop(context, film))
              ])),
            ])));
    if (!mounted || film == null) return;
    final auth = context.read<AuthProvider>();
    final user = auth.dbUser;
    if (user == null) return;
    await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => MovieWatchRequestSheet(
            movieId: film.id,
            movieTitle: film.title,
            moviePoster: film.posterPath,
            requesterId: user.id,
            friends: auth.cachedFriends?.friendships ?? [],
            onSuccess: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Watch plan sent')));
              }
            },
            onError: () {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content:
                        Text('Couldn’t send the plan. Please try again.')));
              }
            }));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: context.colors.background,
      body: FutureBuilder<MovieCollection>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return SafeArea(
                  child: Column(children: [
                const Align(
                    alignment: Alignment.centerLeft, child: BackButton()),
                Expanded(
                    child: Center(
                        child: snapshot.hasError
                            ? Column(mainAxisSize: MainAxisSize.min, children: [
                                const Text('Couldn’t load this collection.'),
                                TextButton(
                                    onPressed: () {
                                      _refresh().catchError((_) {});
                                    },
                                    child: const Text('Try again'))
                              ])
                            : const CircularProgressIndicator())),
              ]));
            }
            final data = snapshot.data!;
            final guest = context.watch<AuthProvider?>()?.dbUser == null;
            return RefreshIndicator(
                onRefresh: _refresh,
                child: CustomScrollView(slivers: [
                  SliverToBoxAdapter(
                      child: Stack(children: [
                    Positioned.fill(
                        child: data.backdropPath == null
                            ? const SizedBox.shrink()
                            : CachedNetworkImage(
                                imageUrl:
                                    'https://image.tmdb.org/t/p/w1280${data.backdropPath}',
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    const SizedBox.shrink())),
                    Positioned.fill(
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                          Colors.black.withValues(alpha: .45),
                          context.colors.background
                        ])))),
                    SafeArea(
                        bottom: false,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const BackButton(color: Colors.white),
                              SizedBox(
                                  height: data.backdropPath == null ? 24 : 120),
                              Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(20, 16, 20, 20),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(data.name,
                                            style: TextStyle(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w800,
                                                color: context.colors.white)),
                                        const SizedBox(height: 8),
                                        Text(
                                            '${data.released.length} released films${data.films.length > data.released.length ? ' · ${data.films.length - data.released.length} upcoming / undated' : ''}',
                                            style: TextStyle(
                                                color: context.colors.light)),
                                      ])),
                            ])),
                  ])),
                  SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                      sliver: SliverList.list(children: [
                        if (!guest) ...[
                          Text('Your progress',
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          Text(
                              '${data.watchedCount} of ${data.released.length} released films watched'),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                              value: data.released.isEmpty
                                  ? 0
                                  : data.watchedCount / data.released.length,
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8)),
                          const SizedBox(height: 20),
                          FilledButton.icon(
                              onPressed: data.toAdd.isEmpty
                                  ? null
                                  : () => _watchRest(data),
                              icon: Icon(Icons.bookmark,
                                  color: data.toAdd.isEmpty
                                      ? null
                                      : const Color(0xffffc52e)),
                              label: Text(data.remaining.isEmpty
                                  ? 'Collection watched'
                                  : data.toAdd.isEmpty
                                      ? 'Remaining films on your watchlist'
                                      : 'Watch this collection')),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                              onPressed:
                                  data.films.isEmpty ? null : () => _plan(data),
                              icon: const Icon(Icons.people_outline),
                              label: const Text('Plan with friends')),
                        ] else ...[
                          FilledButton.icon(
                              onPressed: () => GuestAccess.require(context,
                                  title: 'Track your collection progress',
                                  message:
                                      'Create an account to keep track of the films you’ve watched in this collection.',
                                  path: '/collections/${widget.collectionId}'),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Track progress')),
                        ],
                        if (data.overview.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Text(data.overview,
                              style: TextStyle(
                                  color: context.colors.light, height: 1.5))
                        ],
                        const SizedBox(height: 28),
                        Text('Films · Release order',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        if (data.films.isEmpty)
                          const Text('No films listed in this collection yet.'),
                        for (final film in data.films)
                          _FilmRow(
                              film: film,
                              showProgress: !guest,
                              onTap: () => _openFilm(film)),
                      ])),
                ]));
          }));
}

class _FilmRow extends StatelessWidget {
  const _FilmRow(
      {required this.film,
      this.onTap,
      this.trailing,
      this.showProgress = true});
  final bool showProgress;
  final CollectionFilm film;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
              onTap: onTap,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                            width: 48,
                            height: 72,
                            child: film.posterPath == null
                                ? const Icon(Icons.movie_outlined)
                                : CachedNetworkImage(
                                    imageUrl:
                                        'https://image.tmdb.org/t/p/w185${film.posterPath}',
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        const Icon(Icons.movie_outlined)))),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(film.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text(
                              film.releaseDate?.year.toString() ??
                                  'Release date TBA',
                              style: TextStyle(color: context.colors.light)),
                          const SizedBox(height: 6),
                          if (showProgress)
                            Wrap(spacing: 10, runSpacing: 4, children: [
                              if (film.watched)
                                _badge(Icons.check, 'Watched',
                                    context.colors.success)
                              else if (film.onWatchlist)
                                _badge(Icons.bookmark, 'Watchlist',
                                    context.colors.warning)
                              else
                                Text(film.released ? 'Not watched' : 'Upcoming',
                                    style:
                                        TextStyle(color: context.colors.light)),
                              if (film.rating != null)
                                _badge(Icons.star, '${film.rating}/10',
                                    context.colors.warning),
                            ]),
                        ])),
                    if (trailing != null)
                      trailing!
                    else if (onTap != null)
                      const Icon(Icons.chevron_right),
                  ])))));
  Widget _badge(IconData icon, String label, Color color) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 4),
        Flexible(child: Text(label))
      ]);
}

class _WatchRestSheet extends StatefulWidget {
  const _WatchRestSheet({required this.collection});
  final MovieCollection collection;
  @override
  State<_WatchRestSheet> createState() => _WatchRestSheetState();
}

class _WatchRestSheetState extends State<_WatchRestSheet> {
  late final Set<int> _selected =
      widget.collection.toAdd.map((f) => f.id).toSet();
  bool _saving = false;
  String? _error;
  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final user = auth.dbUser;
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final failed = <int>{};
    for (final film in widget.collection.toAdd
        .where((f) => _selected.contains(f.id))
        .toList()) {
      try {
        final entry = await UserService.addToWatchlist(user.id, film.id);
        film.onWatchlist = true;
        final current =
            List<WatchlistMovie>.from(auth.dbUser?.movieWatchlist ?? []);
        current.removeWhere((e) => e.movieId == film.id);
        current.add(WatchlistMovie.fromJson({
          ...entry.toJson(),
          'movie': {
            'id': film.id,
            'title': film.title,
            'posterPath': film.posterPath,
            'releaseDate': film.releaseDate?.toIso8601String(),
          }
        }));
        auth.updateUserList(movieWatchlist: current);
        auth.markActivityChanged();
      } catch (_) {
        failed.add(film.id);
      }
    }
    if (!mounted) return;
    if (failed.isEmpty) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = false;
      _selected
        ..clear()
        ..addAll(failed);
      _error =
          'Some films couldn’t be added. Your saved films are safe—try the remaining ones again.';
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_saving,
      child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .78,
          child: Padding(
              padding: const EdgeInsets.all(20),
              child: ListView(children: [
                Text('Watch the rest',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 10),
                const Text(
                    'Add the films you haven’t watched to your watchlist.'),
                const SizedBox(height: 16),
                for (final film in widget.collection.remaining)
                  _FilmRow(
                      film: film,
                      trailing: film.onWatchlist
                          ? const Icon(Icons.bookmark, color: Color(0xffffc52e))
                          : Checkbox(
                              value: _selected.contains(film.id),
                              onChanged: _saving
                                  ? null
                                  : (value) => setState(() {
                                        if (value == true) {
                                          _selected.add(film.id);
                                        } else {
                                          _selected.remove(film.id);
                                        }
                                      }))),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_error!,
                          style: TextStyle(color: context.colors.danger))),
                const Text('Your watched films stay marked as watched.'),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: _saving || _selected.isEmpty ? null : _save,
                    child: Text(_saving
                        ? 'Adding films…'
                        : 'Add ${_selected.length} ${_selected.length == 1 ? 'film' : 'films'} to watchlist')),
                TextButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel')),
              ]))));
}
