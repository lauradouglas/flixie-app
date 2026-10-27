import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'widgets/guest_diary_teaser.dart';
import '../../watchlist/data/guest_watchlist_store.dart';
import 'widgets/why_flixie_button.dart';
import 'widgets/guest_home_link_card.dart';
import 'package:flixie_app/features/movies/presentation/trailers/trailer_player_sheet.dart';
import 'widgets/guest_signup_section.dart';
import 'widgets/guest_cinema_list.dart';
import 'package:flixie_app/features/home/presentation/widgets/cinema_list.dart'
    show CinemaListSkeleton;
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
  @override
  void initState() {
    super.initState();
    GuestWatchlistStore.instance.addListener(_picksChanged);
    GuestWatchlistStore.instance
        .read()
        .then((_) => _picksChanged())
        .catchError((Object _) {});
  }

  void _picksChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    GuestWatchlistStore.instance.removeListener(_picksChanged);
    super.dispose();
  }

  final _cinemasKey = GlobalKey<InCinemasSectionState>();
  Future<Map<String, dynamic>> _loadCommunity() {
    final result = ApiClient.get('/guest/home')
        .then((data) => Map<String, dynamic>.from(data as Map));
    // The section may be below the viewport before its FutureBuilder mounts.
    result.ignore();
    return result;
  }

  Future<List<MovieShort>> _loadMovies() {
    final result = TrendingService.getTrendingMovies();
    result.ignore();
    return result;
  }

  late Future<List<MovieShort>> _movies = _loadMovies();
  late Future<Map<String, dynamic>> _community = _loadCommunity();

  Future<void> _refresh() async {
    setState(() {
      _movies = _loadMovies();
      _community = _loadCommunity();
    });
    await Future.wait([
      _movies.then<void>((_) {}, onError: (Object _) {}),
      _community.then<void>((_) {}, onError: (Object _) {}),
      if (_cinemasKey.currentState != null) _cinemasKey.currentState!.refresh(),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 22 ||
                  MediaQuery.sizeOf(context).width < 360
              ? 132
              : 64,
          title: LayoutBuilder(builder: (context, constraints) {
            final actions = Wrap(spacing: 8, children: [
              FilledButton(
                onPressed: _signup,
                style: FilledButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 48),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: const Text('Sign up'),
              ),
              TextButton(
                  onPressed: () {
                    GuestAccess.clear();
                    context.push('/auth/login');
                  },
                  child: const Text('Sign in')),
            ]);
            if (MediaQuery.textScalerOf(context).scale(16) > 22 ||
                constraints.maxWidth < 328) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FlixieWordmark(),
                    const SizedBox(height: 8),
                    actions
                  ]);
            }
            return Row(
                children: [const FlixieWordmark(), const Spacer(), actions]);
          }),
        ),
        body: RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
                builder: (context, box) => ListView(
                      padding: EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: box.maxWidth > 920
                              ? (box.maxWidth - 880) / 2
                              : 20),
                      children: [
                        const GuestHomeWelcome(),
                        _searchButton(),
                        const Padding(
                            padding: EdgeInsets.only(top: 8, bottom: 8),
                            child: Text(
                                'Search titles and people, or browse below.')),
                        if (GuestWatchlistStore.instance.homeKeys.isNotEmpty)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.bookmarks_outlined),
                              title: Text(
                                  'Your watchlist · ${GuestWatchlistStore.instance.homeKeys.length} ${GuestWatchlistStore.instance.homeKeys.length == 1 ? 'pick' : 'picks'}'),
                              subtitle: const Text('Saved on this device'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/guest-watchlist')),
                        const SizedBox(height: 20),
                        LayoutBuilder(builder: (context, section) {
                          final discovery = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Trending now',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const Text('Films'),
                                const SizedBox(height: 14),
                                FutureBuilder<List<MovieShort>>(
                                    future: _movies,
                                    builder: (context, snapshot) {
                                      if (snapshot.hasError) {
                                        return TextButton(
                                            onPressed: () => setState(() {
                                                  _movies = _loadMovies();
                                                }),
                                            child: const Text(
                                                'Couldn’t load trending titles. Retry'));
                                      }
                                      if (!snapshot.hasData) {
                                        return const TrendingCarouselSkeleton();
                                      }
                                      return GuestTrendingCarousel(
                                          movies: snapshot.data!,
                                          savedIds: GuestWatchlistStore
                                              .instance.homeKeys,
                                          onDetails: _openTitle,
                                          onSave: _saveTitle,
                                          onTrailer: _openTrailer);
                                    }),
                                const SizedBox(height: 24),
                                InCinemasSection(
                                    key: _cinemasKey,
                                    loadingPlaceholder:
                                        const CinemaListSkeleton(),
                                    region: WidgetsBinding
                                            .instance
                                            .platformDispatcher
                                            .locale
                                            .countryCode ??
                                        'GB',
                                    onDetails: _openTitle,
                                    onSave: _saveTitle,
                                    onTrailer: _openTrailer,
                                    mediaBuilder: (items) => GuestCinemaList(
                                        movies: items,
                                        savedIds: GuestWatchlistStore
                                            .instance.homeKeys,
                                        onDetails: _openTitle,
                                        onSave: _saveTitle,
                                        onTrailer: _openTrailer)),
                              ]);
                          final personal = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: 20),
                                const GuestDiaryTeaser(),
                                const SizedBox(height: 28),
                                Text('Find where to watch.',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 8),
                                const Text(
                                    'See streaming, rental and purchase options on a title’s page.'),
                                const SizedBox(height: 8),
                                const Text(
                                    'Flixie helps you find it. You watch on the provider’s service, not inside Flixie.'),
                                const SizedBox(height: 28),
                                GuestSignupSection(onSignup: () {
                                  _signup();
                                }, onSignin: () {
                                  GuestAccess.clear();
                                  context.push('/auth/login');
                                }),
                              ]);
                          if (section.maxWidth >= 760 &&
                              MediaQuery.textScalerOf(context).scale(16) <=
                                  24) {
                            return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: discovery),
                                  const SizedBox(width: 32),
                                  Expanded(child: personal)
                                ]);
                          }
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [discovery, personal]);
                        }),
                        const SizedBox(height: 28),
                        Text('Better together, whenever you’re ready.',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                            'Friends can share the film nights later. Your watchlist and diary start with you.'),
                        const SizedBox(height: 24),
                        Text('A little more Flixie',
                            style: Theme.of(context).textTheme.titleLarge),
                        GuestHomeLinkCard(
                            icon: Icons.article_outlined,
                            title: 'Around Flixie',
                            subtitle:
                                'Explore public ratings, reviews and lists',
                            actionLabel: 'Take a look',
                            onTap: () => context.push('/around-flixie')),
                        const SizedBox(height: 8),
                        GuestHomeLinkCard(
                            icon: Icons.sports_esports,
                            title: 'Take a break with Pip’s games',
                            onTap: () => context.push('/play')),
                        TextButton.icon(
                            onPressed: _showBadges,
                            icon: const Icon(Icons.workspace_premium_outlined),
                            label: const Text('About badges')),
                        const SizedBox(height: 24),
                        Text('Communities',
                            style: Theme.of(context).textTheme.titleLarge),
                        const Text('Join when you’re ready to take part.'),
                        FutureBuilder<Map<String, dynamic>>(
                            future: _community,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return TextButton(
                                    onPressed: () => setState(() {
                                          _community = _loadCommunity();
                                        }),
                                    child: const Text(
                                        'Couldn’t load communities. Retry'));
                              }
                              if (!snapshot.hasData) {
                                return const LinearProgressIndicator();
                              }
                              return Wrap(spacing: 8, runSpacing: 8, children: [
                                for (final group
                                    in snapshot.data!['communities'] as List)
                                  if (isVisibleGenre(group['name'] as String,
                                      id: group['id'] as int))
                                    FlixiePill.action(
                                        colorKey: group['name'] as String,
                                        avatar:
                                            GenreIcon(group['name'] as String),
                                        label: Text(group['name'] as String),
                                        onPressed: () => GuestAccess.require(
                                            context,
                                            title: 'Join ${group['name']}',
                                            message:
                                                'Create an account to join the conversation and share your favourites.',
                                            path:
                                                '/genre-communities/${group['id']}',
                                            intent: 'community')),
                              ]);
                            }),
                        const SizedBox(height: 24),
                      ],
                    ))),
      );
  void _showBadges() => showFlixiePromptSheet<void>(
        context: context,
        builder: (sheetContext) => FlixiePromptSheetContent(
          title: const Text('Your Flixie badges'),
          content: const Text(
              'Badges appear on your profile. You can explore films and build a watchlist without collecting badges or joining a community.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Keep browsing'))
          ],
        ),
      );

  void _signup() {
    if (GuestWatchlistStore.instance.homeKeys.isNotEmpty) {
      GuestAccess.clear();
      GuestAccess.action = 'guest-watchlist';
      GuestAccess.destination = '/guest-watchlist';
      GuestAccess.awaitingAccount = true;
    } else {
      GuestAccess.beginGeneralSignup('home');
    }
    context.push('/auth/signup');
  }

  Widget _searchButton() => OutlinedButton.icon(
      onPressed: () => context.go('/search?focus=1'),
      icon: const Icon(Icons.search),
      label: const Text('Find a film or show'));

  void _openTitle(MovieShort movie) =>
      context.push('/${movie.isShow ? 'shows' : 'movies'}/${movie.id}');

  void _saveTitle(MovieShort movie) => GuestAccess.require(context,
      title: 'Save ${movie.name} for later',
      message:
          'Create an account to keep your watchlist and come back when you’re ready.',
      path: '/${movie.isShow ? 'shows' : 'movies'}/${movie.id}',
      mediaTitle: movie.name,
      mediaPoster: movie.poster,
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
                                                          GuestAccess
                                                              .beginGeneralSignup(
                                                                  'profile');
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
                                                    const WhyFlixieButton(),
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
                                Text('Films are better\nwith your people.',
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
                                    'See what friends love, find where it’s streaming, and plan your next watch together.',
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
                                const SizedBox(height: 16),
                                const WhyFlixieButton(),
                                const SizedBox(height: 12),
                                TextButton(
                                    onPressed: () {
                                      GuestAccess.beginGeneralSignup('home');
                                      context.push('/auth/signup');
                                    },
                                    style: TextButton.styleFrom(
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
        SizedBox(height: 14),
        TrendingCarouselSkeleton(),
        SizedBox(height: 28),
        Text('In cinemas now'),
        SizedBox(height: 14),
        TrendingCarouselSkeleton(),
      ]);
}
