import 'widgets/guest_watch_together_teaser.dart';
import 'widgets/guest_provider_example.dart';
import 'widgets/guest_favourites_teaser.dart';
import 'widgets/guest_communities_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/badges_explainer.dart';
import 'package:flixie_app/features/curated_lists/presentation/widgets/curated_lists_home_section.dart';
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
import 'package:flixie_app/features/home/presentation/widgets/trending_carousel_skeleton.dart';
import 'package:flixie_app/features/home/presentation/widgets/in_cinemas_section.dart';
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
                  MediaQuery.sizeOf(context).width < 300
              ? 132
              : 64,
          title: LayoutBuilder(builder: (_, constraints) {
            final actions = Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton(
                      onPressed: () {
                        GuestAccess.clear();
                        context.push('/auth/login');
                      },
                      style: TextButton.styleFrom(
                          foregroundColor: context.colors.primaryText,
                          minimumSize: const Size(44, 44),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      child: const Text('Sign in')),
                  FilledButton(
                      onPressed: _signup,
                      style: FilledButton.styleFrom(
                          backgroundColor: FlixieColors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 36),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          textStyle: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      child: const Text('Join free')),
                ]);
            if (MediaQuery.textScalerOf(context).scale(16) > 22 ||
                constraints.maxWidth < 260) {
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
                        if (GuestWatchlistStore.instance.homeKeys.isNotEmpty)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.bookmarks_outlined),
                              title: Text(
                                  'Your watchlist · ${GuestWatchlistStore.instance.homeKeys.length} ${GuestWatchlistStore.instance.homeKeys.length == 1 ? 'pick' : 'picks'}'),
                              subtitle: const Text('Saved on this device'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/guest-watchlist')),
                        const SizedBox(height: 28),
                        Text('Trending now',
                            style: Theme.of(context).textTheme.titleLarge),
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
                                  savedIds:
                                      GuestWatchlistStore.instance.homeKeys,
                                  onDetails: _openTitle,
                                  onSave: _saveTitle,
                                  onTrailer: _openTrailer);
                            }),
                        const SizedBox(height: 28),
                        const GuestProviderExample(),
                        const CuratedListsHomeSection(
                            horizontalPadding: 0,
                            leadingSpacing: 28,
                            includeOuterSpacing: false),
                        const SizedBox(height: 28),
                        InCinemasSection(
                            key: _cinemasKey,
                            bottomSpacing: 0,
                            loadingPlaceholder: const CinemaListSkeleton(),
                            region: WidgetsBinding.instance.platformDispatcher
                                    .locale.countryCode ??
                                'GB',
                            onDetails: _openTitle,
                            onSave: _saveTitle,
                            onTrailer: _openTrailer,
                            mediaBuilder: (items) => GuestCinemaList(
                                movies: items,
                                savedIds: GuestWatchlistStore.instance.homeKeys,
                                onDetails: _openTitle,
                                onSave: _saveTitle,
                                onTrailer: _openTrailer)),
                        const SizedBox(height: 28),
                        const GuestDiaryTeaser(),
                        const SizedBox(height: 28),
                        const GuestFavouritesTeaser(),
                        const SizedBox(height: 28),
                        const GuestWatchTogetherTeaser(),
                        const SizedBox(height: 28),
                        FutureBuilder<Map<String, dynamic>>(
                            future: _community,
                            builder: (context, snapshot) =>
                                GuestCommunitiesSection(
                                    loading: snapshot.connectionState ==
                                        ConnectionState.waiting,
                                    failed: snapshot.hasError,
                                    onRetry: () => setState(() {
                                          _community = _loadCommunity();
                                        }),
                                    communities: (snapshot.data?['communities']
                                                as List? ??
                                            const [])
                                        .whereType<Map>()
                                        .where((group) =>
                                            group['id'] is int &&
                                            group['name'] is String)
                                        .map((group) => (
                                              id: group['id'] as int,
                                              name: group['name'] as String
                                            ))
                                        .toList(),
                                    onSelect: (community) => GuestAccess.require(
                                        context,
                                        title: 'Join ${community.name}',
                                        message:
                                            'Create an account to join the conversation and share your favourites.',
                                        path:
                                            '/genre-communities/${community.id}',
                                        intent: 'community'))),
                        const SizedBox(height: 28),
                        GuestHomeLinkCard(
                            icon: Icons.article_outlined,
                            title: 'Around Flixie',
                            subtitle:
                                'Explore public ratings, reviews and lists',
                            onTap: () => context.push('/around-flixie')),
                        const SizedBox(height: 28),
                        GuestSignupSection(
                            onSignup: _signup,
                            onSignin: () {
                              GuestAccess.clear();
                              context.push('/auth/login');
                            }),
                        const SizedBox(height: 28),
                        Text('A little more Flixie',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        GuestHomeLinkCard(
                            icon: Icons.sports_esports,
                            title: 'Take a break with Pip’s games',
                            subtitle: 'Play a quick game with Pip.',
                            onTap: () => context.push('/play')),
                        const SizedBox(height: 12),
                        GuestHomeLinkCard(
                            icon: Icons.workspace_premium_outlined,
                            title: 'About badges & milestones',
                            subtitle:
                                'See how to earn badges and reach milestones.',
                            onTap: _showBadges),
                        const SizedBox(height: 12),
                        const WhyFlixieButton(),
                        const SizedBox(height: 24),
                      ],
                    ))),
      );
  void _showBadges() => showFlixiePromptSheet<void>(
        context: context,
        maxHeightFraction: .9,
        builder: (_) => const BadgesExplainer(),
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

  Widget _searchButton() => Semantics(
      button: true,
      label: 'Search films, shows and people',
      child: Material(
          color: context.colors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                  color: context.colors.light.withValues(alpha: .18))),
          child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => context.go('/search?focus=1'),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: ExcludeSemantics(
                          child: Row(children: [
                        Icon(Icons.search,
                            size: 22, color: context.colors.light),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Text('Search films, shows and people',
                                style: TextStyle(
                                    fontSize: 14,
                                    height: 1.5,
                                    fontWeight: FontWeight.w400,
                                    color: context.colors.light))),
                        const SizedBox(width: 10),
                        Icon(Icons.arrow_forward_rounded,
                            size: 20, color: context.colors.primaryText),
                      ])))))));

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
