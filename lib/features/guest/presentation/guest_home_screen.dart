import 'widgets/guest_home_link_card.dart';
import 'package:flixie_app/features/movies/presentation/trailers/trailer_player_sheet.dart';
import 'package:flixie_app/features/home/presentation/widgets/pip_loading_strip.dart';
import 'widgets/guest_signup_section.dart';
import 'widgets/guest_cinema_list.dart';
import 'widgets/guest_home_welcome.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_carousel_skeleton.dart';
import 'package:flixie_app/features/home/presentation/widgets/in_cinemas_section.dart';
import 'package:flixie_app/core/utils/genre_catalogue.dart';
import 'package:flixie_app/core/widgets/genre_icon.dart';
import 'widgets/guest_trending_carousel.dart';
import 'package:flixie_app/core/widgets/cinema_light_background.dart';
import 'package:flixie_app/core/widgets/cinema_wordmark.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/home/data/trending_service.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'guest_access.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});
  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  final _cinemasKey = GlobalKey<InCinemasSectionState>();
  late Future<(List<MovieShort>, Map<String, dynamic>)> _content = _load();
  Future<(List<MovieShort>, Map<String, dynamic>)> _load() async {
    final results = await Future.wait<dynamic>([
      TrendingService.getTrendingMedia(),
      ApiClient.get('/guest/home'),
    ]);
    return (results[0] as List<MovieShort>, results[1] as Map<String, dynamic>);
  }

  Future<void> _refresh() async {
    final content = _load();
    setState(() {
      _content = content;
    });
    try {
      await Future.wait([
        _content,
        if (_cinemasKey.currentState != null)
          _cinemasKey.currentState!.refresh()
      ]);
    } catch (_) {/* FutureBuilder presents retry. */}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(title: const FlixieWordmark(), actions: [
          IconButton(
              tooltip: 'Play with Pip',
              onPressed: () => context.push('/play'),
              icon: const Icon(Icons.sports_esports_outlined)),
          TextButton(
              onPressed: () {
                GuestAccess.clear();
                context.push('/auth/login');
              },
              child: const Text('Sign in')),
        ]),
        body: RefreshIndicator(
            onRefresh: _refresh,
            child: FutureBuilder(
                future: _content,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ListView(children: [
                      const Padding(
                          padding: EdgeInsets.all(20),
                          child: GuestHomeWelcome()),
                      Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _searchButton()),
                      const SizedBox(height: 24),
                      const Center(
                          child: Text('Couldn’t load Home. Please try again.')),
                      Center(
                          child: TextButton(
                              onPressed: _refresh, child: const Text('Retry')))
                    ]);
                  }
                  if (!snapshot.hasData) {
                    return const GuestHomeLoadingSkeleton();
                  }
                  final (movies, community) = snapshot.data!;
                  return LayoutBuilder(
                      builder: (context, box) => ListView(
                              padding: EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: box.maxWidth > 920
                                      ? (box.maxWidth - 880) / 2
                                      : 20),
                              children: [
                                const GuestHomeWelcome(),
                                _searchButton(),
                                const SizedBox(height: 24),
                                Text('Trending now',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 4),
                                const Text('Movies & shows'),
                                const SizedBox(height: 14),
                                GuestTrendingCarousel(
                                  movies: movies,
                                  onDetails: (movie) => context.push(
                                      '/${movie.isShow ? 'shows' : 'movies'}/${movie.id}'),
                                  onSave: (movie) => GuestAccess.require(
                                      context,
                                      title: 'Save ${movie.name} for later',
                                      message:
                                          'Create an account to keep your watchlist and come back when you’re ready.',
                                      path:
                                          '/${movie.isShow ? 'shows' : 'movies'}/${movie.id}',
                                      intent: 'watchlist'),
                                  onTrailer: (movie) => _openTrailer(movie),
                                ),
                                const SizedBox(height: 28),
                                InCinemasSection(
                                    key: _cinemasKey,
                                    region: WidgetsBinding
                                            .instance
                                            .platformDispatcher
                                            .locale
                                            .countryCode ??
                                        'GB',
                                    onDetails: (movie) => context.push(
                                        '/${movie.isShow ? 'shows' : 'movies'}/${movie.id}'),
                                    onSave: (movie) => GuestAccess.require(
                                        context,
                                        title: 'Save ${movie.name} for later',
                                        message:
                                            'Create an account to keep your watchlist and come back when you’re ready.',
                                        path:
                                            '/${movie.isShow ? 'shows' : 'movies'}/${movie.id}',
                                        intent: 'watchlist'),
                                    onTrailer: _openTrailer,
                                    mediaBuilder: (items) => GuestCinemaList(
                                        movies: items,
                                        onDetails: _openTitle,
                                        onSave: _saveTitle,
                                        onTrailer: _openTrailer)),
                                GuestSignupSection(
                                  onSignup: () {
                                    GuestAccess.clear();
                                    context.push('/auth/signup');
                                  },
                                  onSignin: () {
                                    GuestAccess.clear();
                                    context.push('/auth/login');
                                  },
                                ),
                                const SizedBox(height: 10),
                                GuestHomeLinkCard(
                                  icon: Icons.article_outlined,
                                  title: 'Around Flixie',
                                  subtitle:
                                      'Explore public ratings, reviews and lists',
                                  actionLabel: 'Take a look',
                                  onTap: () => context.push('/around-flixie'),
                                ),
                                const SizedBox(height: 8),
                                GuestHomeLinkCard(
                                  icon: Icons.sports_esports,
                                  title: 'Take a break with Pip’s games',
                                  onTap: () => context.push('/play'),
                                ),
                                const SizedBox(height: 28),
                                Text('Find your film people',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 8),
                                const Text(
                                    'Explore Flixie communities. Join when you’re ready to take part.'),
                                const SizedBox(height: 16),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  for (final group
                                      in community['communities'] as List)
                                    if (isVisibleGenre(group['name'] as String,
                                        id: group['id'] as int))
                                      FlixiePill.action(
                                          avatar: GenreIcon(
                                              group['name'] as String),
                                          label: Text(group['name'] as String),
                                          onPressed: () => GuestAccess.require(
                                              context,
                                              title: 'Join ${group['name']}',
                                              message:
                                                  'Create an account to explore conversations and share your favourites with this community.',
                                              path:
                                                  '/genre-communities/${group['id']}'))
                                ]),
                                const SizedBox(height: 24),
                                const SizedBox(height: 24),
                              ]));
                })),
      );
  Widget _searchButton() => OutlinedButton.icon(
      onPressed: () => context.go('/search?focus=1'),
      icon: const Icon(Icons.search),
      label: const Text('Search movies, shows and people'));

  void _openTitle(MovieShort movie) =>
      context.push('/${movie.isShow ? 'shows' : 'movies'}/${movie.id}');

  void _saveTitle(MovieShort movie) => GuestAccess.require(context,
      title: 'Save ${movie.name} for later',
      message:
          'Create an account to keep your watchlist and come back when you’re ready.',
      path: '/${movie.isShow ? 'shows' : 'movies'}/${movie.id}',
      intent: 'watchlist');

  Future<void> _openTrailer(MovieShort movie) async {
    final source = movie.trailer?.key;
    if (source == null || source.trim().isEmpty) return;
    await showTrailerPlayerSheet(context,
        source: source, title: '${movie.name} trailer');
  }
}

class GuestWelcomeScreen extends StatelessWidget {
  const GuestWelcomeScreen({super.key, this.you = false});
  final bool you;
  @override
  Widget build(BuildContext context) =>
      you ? _account(context) : _welcome(context);

  Widget _account(BuildContext context) => Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(children: [
        const Positioned.fill(child: CinemaLightBackground()),
        SafeArea(
            child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                            child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 460),
                                child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        28, 38, 28, 32),
                                    child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                            minHeight:
                                                (constraints.maxHeight - 70)
                                                    .clamp(0, double.infinity)),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: CinemaWordmark(
                                                          fontSize: 64))),
                                              const SizedBox(height: 80),
                                              Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .stretch,
                                                  children: [
                                                    Text('Create your account',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .headlineLarge
                                                            ?.copyWith(
                                                                fontSize: 35,
                                                                height: 1.1,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                letterSpacing:
                                                                    -.8)),
                                                    const SizedBox(height: 20),
                                                    Text(
                                                        'Save a watchlist, log what you’ve watched and find people who love the same films.',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyLarge
                                                            ?.copyWith(
                                                                height: 1.55)),
                                                    const SizedBox(height: 32),
                                                    FilledButton(
                                                        onPressed: () {
                                                          GuestAccess.clear();
                                                          context.push(
                                                              '/auth/signup');
                                                        },
                                                        style: FilledButton
                                                            .styleFrom(
                                                                minimumSize:
                                                                    const Size(
                                                                        0, 55)),
                                                        child: const Text(
                                                            'Create account')),
                                                    const SizedBox(height: 12),
                                                    TextButton(
                                                        onPressed: () {
                                                          GuestAccess.clear();
                                                          context.push(
                                                              '/auth/login');
                                                        },
                                                        style: TextButton.styleFrom(
                                                            minimumSize:
                                                                const Size(
                                                                    0, 48),
                                                            foregroundColor:
                                                                context.colors
                                                                    .primaryText),
                                                        child: const Text(
                                                            'Already a member? Sign in')),
                                                  ]),
                                            ]))))))))),
      ]));
  Widget _welcome(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        body: Stack(children: [
          const Positioned.fill(child: CinemaLightBackground()),
          SafeArea(
              child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                  child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 38, 28, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 62)
                            .clamp(0, double.infinity)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: CinemaWordmark(fontSize: 64))),
                          const SizedBox(height: 100),
                          Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Find your next\ngreat watch.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge
                                        ?.copyWith(
                                            fontSize: 35,
                                            height: 1.1,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -.8)),
                                const SizedBox(height: 20),
                                Text(
                                    'Explore films and shows. Save your favourites when you’re ready.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(height: 1.55)),
                                const SizedBox(height: 32),
                                FilledButton(
                                    onPressed: () {
                                      GuestAccess.clear();
                                      context.go('/');
                                    },
                                    style: FilledButton.styleFrom(
                                        minimumSize: const Size(0, 55)),
                                    child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Flexible(
                                              child: Text('Explore Flixie')),
                                          SizedBox(width: 12),
                                          Icon(Icons.arrow_forward_rounded,
                                              size: 19)
                                        ])),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                    onPressed: () {
                                      GuestAccess.clear();
                                      context.push('/auth/signup');
                                    },
                                    style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(0, 53)),
                                    child: const Text('Create account')),
                                const SizedBox(height: 12),
                                TextButton(
                                    onPressed: () {
                                      GuestAccess.clear();
                                      context.push('/auth/login');
                                    },
                                    child: const Text(
                                        'Already a member? Sign in')),
                              ]),
                        ]),
                  ),
                ),
              )),
            )),
          )),
        ]),
      );
}

class GuestHomeLoadingSkeleton extends StatelessWidget {
  const GuestHomeLoadingSkeleton({super.key});
  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: const [
        GuestHomeWelcome(),
        SizedBox(height: 24),
        Text('Trending now'),
        PipLoadingStrip(),
        SizedBox(height: 14),
        TrendingCarouselSkeleton(),
        SizedBox(height: 28),
        Text('In cinemas now'),
        SizedBox(height: 14),
        TrendingCarouselSkeleton(),
      ]);
}
