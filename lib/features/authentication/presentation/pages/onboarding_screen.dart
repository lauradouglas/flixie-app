import 'package:flixie_app/features/settings/presentation/widgets/around_flixie_sharing_setting.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'setup_profile_favourites.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/models/country.dart';
import 'package:flixie_app/models/genre.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/settings/data/episode_spoiler_preference.dart';
import 'package:flixie_app/features/settings/presentation/widgets/movie_rating_privacy_setting.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/features/library_import/data/library_import_controller.dart';
import 'package:flixie_app/features/library_import/presentation/library_import_screen.dart';
import '../../data/setup_service.dart';
import 'signup_screen.dart' show SignupCountryPickerSheet;

// Retained for callers using the standalone favourite selector.
String? validateFavouriteMovieCount(int count) => count < 1 || count > 5
    ? 'Please select between 1 and 5 favourite movies.'
    : null;
bool canAddOnboardingMovie(Map<int, MovieShort> selected, int movieId,
        {int maxCount = 5}) =>
    selected.containsKey(movieId) || selected.length < maxCount;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen(
      {super.key, this.service = const SetupService(), this.returnTo});
  final String? returnTo;
  final SetupService service;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  bool _favouritesAdded = false;
  List<SetupCommunitySuggestion> _communityChoices = [];
  final Set<int> _selectedCommunities = {};
  bool _loadingCommunities = false;
  String? _communityError;
  int _communityRevision = 0;
  int _picksRevision = 0;
  final Map<int, Map<String, dynamic>> _conversations = {};

  bool _busy = false, _loading = true, _shows = false, _searching = false;
  String? _error, _searchError, _picksError, _referrer;
  List<Country> _countries = [];
  Country? _country;
  List<WatchProvider> _providers = [];
  final Set<int> _selectedProviders = {}, _genres = {};
  List<Genre> _allGenres = [];
  final Map<String, SetupTitle> _taste = {};
  List<SetupTitle> _browse = [], _picks = [];
  final Map<String, List<WatchProvider>?> _offers = {};
  final Set<String> _added = {}, _adding = {};
  final _search = TextEditingController();
  final _providerSearch = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  int _searchRevision = 0;
  late String _userId;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _userId = context.read<AuthProvider>().dbUser!.id;
    context.read<AnalyticsController?>()?.onboardingStarted();
    _load();
    _findTitles();
    _loadGenres();
    widget.service.referrer(_userId).then((name) {
      if (mounted) setState(() => _referrer = name);
    }).catchError((Object _) {});
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _providerSearch.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final countries = await widget.service.countries();
      final providers = await widget.service.providers();
      final saved = await widget.service.savedProviders(_userId);
      final taste = await widget.service.loadTaste(_userId);
      if (!mounted) return;
      final user = context.read<AuthProvider>().dbUser!;
      setState(() {
        _countries = countries;
        _providers = providers;
        _country = countries.where((c) => c.id == user.countryId).firstOrNull;
        _selectedProviders.addAll(saved.map((p) => p.id));
        _taste.addEntries(taste.take(3).map((t) => MapEntry(t.key, t)));
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t load setup. Retry, or skip this step and choose your services later.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _move(int step) {
    ++_searchRevision;
    _debounce?.cancel();
    if (step != 2) ++_picksRevision;
    setState(() {
      _searching = false;
      _step = step;
      _error = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
    if (step == 5) _loadCommunities();
    if (step == 2) {
      EpisodeSpoilerPreference.instance.load().catchError((Object _) {});
      _loadPicks();
    }
    if (step == 0 && _browse.isEmpty) {
      _findTitles();
      _loadGenres();
    }
  }

  Future<void> _loadGenres() async {
    try {
      final values = await widget.service.genres();
      if (mounted) setState(() => _allGenres = values);
    } catch (_) {/* Genres are optional; title search remains available. */}
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t save this step. Your choices are still here. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<Country>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => SignupCountryPickerSheet(
            countries: _countries, selected: _country));
    if (mounted && selected != null) {
      setState(() {
        _country = selected;
        _providerSearch.clear();
        _selectedProviders
            .removeWhere((id) => !_visibleProviders.any((p) => p.id == id));
      });
    }
  }

  List<WatchProvider> get _visibleProviders =>
      setupProviders(_providers, query: _providerSearch.text);

  Future<void> _findTitles() async {
    final revision = ++_searchRevision;
    final shows = _shows, query = _search.text.trim();
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final values = query.isEmpty
          ? await widget.service.popular(shows)
          : await widget.service.search(query, shows);
      if (mounted && revision == _searchRevision) {
        setState(() => _browse = values);
      }
    } catch (_) {
      if (mounted && revision == _searchRevision) {
        setState(() {
          _browse = [];
          _searchError = 'Couldn’t load titles. Try again.';
        });
      }
    } finally {
      if (mounted && revision == _searchRevision) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _loadPicks() async {
    final revision = ++_picksRevision;
    setState(() {
      _searching = true;
      _picksError = null;
    });
    try {
      final picks = _favouritesAdded
          ? await widget.service.favouriteRecommendations(_userId)
          : await widget.service.recommendations(_taste.values.toList());
      if (!mounted || revision != _picksRevision) return;
      setState(() {
        _picks = picks;
        _offers.clear();
      });
      if (_country != null) {
        final region = _country!.abbreviation.toUpperCase() == 'UK'
            ? 'GB'
            : _country!.abbreviation.toUpperCase();
        // Six cards at most, in batches of three availability requests.
        for (var i = 0; i < picks.length; i += 3) {
          await Future.wait(picks.skip(i).take(3).map((title) async {
            try {
              final offers = await widget.service.availability(title, region);
              if (mounted && revision == _picksRevision) {
                setState(() => _offers[title.key] = offers);
              }
            } catch (_) {
              if (mounted && revision == _picksRevision) {
                setState(() => _offers[title.key] = null);
              }
            }
          }));
        }
      }
    } catch (_) {
      if (mounted && revision == _picksRevision) {
        setState(() => _picksError =
            'Couldn’t load your first picks. Retry or explore Flixie.');
      }
    } finally {
      if (mounted && revision == _picksRevision) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _finish(String destination) => _run(() async {
        final auth = context.read<AuthProvider>();
        final analytics = context.read<AnalyticsController?>();
        await auth.refreshDbUser();
        final qualified = await auth.completeOnboarding();
        RecommendationService.invalidateCache(userId: _userId);
        await analytics?.tasteProfileCompleted(
            signalCount: _taste.length + _genres.length);
        if (qualified) await analytics?.rewardUnlocked();
        if (mounted) {
          context.go(destination == '/' ? widget.returnTo ?? '/' : destination);
        }
      });
  Future<void> _import() async {
    final auth = context.read<AuthProvider>();
    final controller = LibraryImportController(
        userId: _userId, isCurrentUser: () => auth.dbUser?.id == _userId);
    await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
            builder: (_) => LibraryImportScreen(controller: controller)));
    controller.dispose();
  }

  Future<void> _add(SetupTitle title) async {
    setState(() => _adding.add(title.key));
    try {
      await widget.service.addToWatchlist(_userId, title);
      if (mounted) {
        setState(() => _added.add(title.key));
        context.read<AnalyticsController?>()?.watchlistAdded(
            contentType: title.isShow ? 'show' : 'movie',
            contentId: title.id,
            source: 'onboarding');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${title.name} added to your watchlist')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t add ${title.name}. Tap Add to watchlist to retry.');
      }
    } finally {
      if (mounted) setState(() => _adding.remove(title.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    const titles = [
      'What stays with you?',
      'Make it an easy yes.',
      'Your picks.',
      'Your favourites.',
      'Sharing & spoilers.',
      'Good films start conversations.'
    ];
    const subtitles = [
      'Pick up to three films or shows you love. We’ll start there.',
      'Choose where you watch. We’ll put available picks first.',
      'A few places to start. Save what catches your eye.',
      'Bring the films you love onto your profile. This is optional.',
      'Choose what you share and what you see. You can change these in Settings.',
      'Browse a conversation before deciding to join. This part is optional.'
    ];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
        backgroundColor: context.colors.background,
        bottomNavigationBar: _setupActions(),
        body: SafeArea(
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            if (_step > 0)
                              IconButton(
                                  tooltip: 'Back',
                                  onPressed:
                                      _busy ? null : () => _move(_step - 1),
                                  icon: const Icon(Icons.arrow_back)),
                            const Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: FlixieWordmark()),
                              ),
                            ),
                            Text('${_step + 1} of 6',
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
                          const SizedBox(height: 12),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.5, end: (_step + 1) / 6),
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Row(
                              children: List.generate(
                                  6,
                                  (index) => Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                              right: index == 5 ? 0 : 5),
                                          child: LinearProgressIndicator(
                                            key: ValueKey(
                                                'setup-progress-$index'),
                                            minHeight: 3,
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            value: (value * 6 - index)
                                                .clamp(0.0, 1.0),
                                          ),
                                        ),
                                      )),
                            ),
                          ),
                          if (widget.returnTo != null)
                            TextButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _finish(widget.returnTo!),
                              icon: const Icon(Icons.arrow_forward),
                              label:
                                  const Text('Go straight to your invitation'),
                            ),
                          if (_referrer != null)
                            TextButton(
                              onPressed: _busy
                                  ? null
                                  : () => _run(() async {
                                        final id = await widget.service
                                            .friendId(_referrer!);
                                        if (!mounted) return;
                                        setState(() => _busy = false);
                                        await _finish(id == null
                                            ? '/social?tab=people'
                                            : '/friends/$id');
                                      }),
                              child: Text('Find @$_referrer first'),
                            ),
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
                              alignment: Alignment.topLeft,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            ),
                            child: Column(
                              key: ValueKey('setup-heading-$_step'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(titles[_step],
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text(subtitles[_step]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (_error != null) ...[
                            Text(_error!,
                                style: TextStyle(color: context.colors.danger)),
                            const SizedBox(height: 12)
                          ],
                          if (_step == 0) ..._tastes(),
                          if (_step == 1) ..._watching(),
                          if (_step == 2) ..._results(),
                          if (_step == 3) ..._favourites(),
                          if (_step == 4) ..._sharingPreferences(),
                          if (_step == 5) ..._communities(),
                        ],
                      )),
                ))));
  }

  void _showPicks() {
    _move(2);
  }

  Widget _setupActions() {
    final label = switch (_step) {
      0 => 'Continue',
      1 => _country == null ? 'Choose country' : 'Show my first picks',
      2 => 'Continue to favourites',
      3 => 'Continue to sharing',
      4 => 'Find my kind of people',
      _ => _selectedCommunities.isEmpty
          ? 'Explore Flixie'
          : 'Join ${_selectedCommunities.length} & explore',
    };
    final secondary = switch (_step) {
      0 => 'Skip taste picks',
      1 => 'Skip services for now',
      2 => 'Skip picks',
      3 => 'Skip favourites',
      _ => 'I’ll explore on my own',
    };
    final VoidCallback? advance = _busy ||
            (_step == 1 && _loading) ||
            (_step == 5 &&
                _loadingCommunities &&
                _selectedCommunities.isNotEmpty)
        ? null
        : () {
            switch (_step) {
              case 0:
                _saveTaste();
              case 1:
                if (_country == null) {
                  if (_countries.isNotEmpty) _pickCountry();
                } else {
                  _run(() async {
                    await widget.service
                        .saveWatching(_userId, _country!, _selectedProviders);
                    if (mounted) _showPicks();
                  });
                }
              case 2:
              case 3:
              case 4:
                _move(_step + 1);
              default:
                _joinCommunities();
            }
          };
    return ColoredBox(
        key: const ValueKey('setup-footer-surface'),
        color: _step <= 2 ? context.colors.surface : context.colors.background,
        child: SafeArea(
          top: false,
          child: Align(
            heightFactor: 1,
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Container(
                decoration: _step <= 2
                    ? BoxDecoration(
                        color: context.colors.surface,
                        border: Border(
                            top:
                                BorderSide(color: context.colors.tabBarBorder)))
                    : null,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_step == 1) ...[
                      _providerSummary(),
                      const SizedBox(height: 10),
                    ],
                    if (_step == 0) ...[
                      _tasteSummary(),
                      const SizedBox(height: 10),
                    ],
                    if (_step == 2) ...[
                      _savedPicksSummary(),
                      const SizedBox(height: 10),
                    ],
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff8050e8),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: advance,
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(label),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () {
                              switch (_step) {
                                case 0:
                                  _saveTaste(skip: true);
                                case 1:
                                  _showPicks();
                                case 2:
                                case 3:
                                  _move(_step + 1);
                                default:
                                  _selectedCommunities.clear();
                                  _finish('/');
                              }
                            },
                      style: TextButton.styleFrom(
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          minimumSize: const Size(44, 44)),
                      child: Text(secondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  Widget _savedPicksSummary() => Semantics(
      liveRegion: true,
      child: Row(children: [
        if (MediaQuery.textScalerOf(context).scale(1) < 1.5)
          for (final title
              in _picks.where((t) => _added.contains(t.key)).take(3))
            Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _tastePoster(title)),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              _added.isEmpty
                  ? 'Something catch your eye?'
                  : '${_added.length} saved for later',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
          Text(
              _added.isEmpty
                  ? 'Save a pick, or keep exploring.'
                  : 'Waiting for you in Watchlist.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 12)),
        ])),
      ]));

  Widget _tastePoster(SetupTitle title) => ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
            width: 28,
            height: 42,
            child: title.poster?.isNotEmpty == true
                ? Image.network(
                    title.poster!.startsWith('http')
                        ? title.poster!
                        : 'https://image.tmdb.org/t/p/w92${title.poster}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.movie_outlined))
                : const Icon(Icons.movie_outlined)),
      );

  Widget _tasteSummary() => Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (MediaQuery.textScalerOf(context).scale(1) < 1.5)
            for (final title in _taste.values)
              Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _tastePoster(title)),
          Expanded(
              child: Semantics(
                  liveRegion: true,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_taste.length} of 3 selected',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(
                            _taste.isEmpty
                                ? 'Start with something you love.'
                                : 'A few is enough.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 12)),
                      ]))),
          if (_taste.isNotEmpty)
            TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() => _editingTaste = !_editingTaste),
                style: TextButton.styleFrom(
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    minimumSize: const Size(48, 48)),
                child: Text(_editingTaste ? 'Done' : 'Edit')),
        ]),
        if (_editingTaste && _taste.isNotEmpty)
          SizedBox(
              height: MediaQuery.sizeOf(context).height * .18,
              child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                      children: _taste.values
                          .map((title) => Row(children: [
                                _tastePoster(title),
                                const SizedBox(width: 10),
                                Expanded(child: Text(title.name)),
                                TextButton(
                                    key: ValueKey('remove-taste-${title.key}'),
                                    onPressed: _busy
                                        ? null
                                        : () => setState(() {
                                              _taste.remove(title.key);
                                              if (_taste.isEmpty) {
                                                _editingTaste = false;
                                              }
                                            }),
                                    child: Semantics(
                                        excludeSemantics: true,
                                        label:
                                            'Remove ${title.name} from picks',
                                        child: const Text('Remove'))),
                              ]))
                          .toList()))),
      ]);

  bool _editingTaste = false;

  Widget _providerSummary() {
    final chosen = _providers
        .where((p) => _selectedProviders.contains(p.id))
        .take(3)
        .toList();
    return Semantics(
        liveRegion: true,
        child: Row(children: [
          if (chosen.isEmpty) const Icon(Icons.tv_outlined, size: 28),
          for (final provider in chosen)
            Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: provider.logoPath.isEmpty
                      ? const Icon(Icons.tv_outlined, size: 28)
                      : Image.network(provider.logoUrl,
                          width: 28,
                          height: 28,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.tv_outlined, size: 28)),
                )),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    _selectedProviders.isEmpty
                        ? 'No services selected'
                        : '${_selectedProviders.length} service${_selectedProviders.length == 1 ? '' : 's'} selected',
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                    _selectedProviders.isEmpty
                        ? 'You can add these later'
                        : 'Your services · change them anytime',
                    style: Theme.of(context).textTheme.bodySmall),
              ])),
        ]));
  }

  List<Widget> _watching() => [
        if (_loading)
          const Center(child: CircularProgressIndicator())
        else ...[
          Row(children: [
            if (MediaQuery.textScalerOf(context).scale(1) < 1.5)
              const Text('Country'),
            const SizedBox(width: 12),
            Expanded(
                child: OutlinedButton(
              onPressed: _busy || _countries.isEmpty ? null : _pickCountry,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: Row(children: [
                Expanded(child: Text(_country?.name ?? 'Select country')),
                const Icon(Icons.keyboard_arrow_down, size: 20),
              ]),
            )),
          ]),
          if (_country == null) ...[
            const SizedBox(height: 8),
            const Text(
                'Watch options vary by country. Choose yours to add your services.'),
          ],
          if (_error != null)
            TextButton(onPressed: _load, child: const Text('Retry setup')),
          const SizedBox(height: 8),
          if (_country != null) ...[
            const SizedBox(height: 8),
            Text('Your services',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            TextField(
                controller: _providerSearch,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    labelText: 'Search streaming services',
                    prefixIcon: Icon(Icons.search))),
            const SizedBox(height: 12),
            for (final provider in _visibleProviders)
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Material(
                  animationDuration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 150),
                  color: _selectedProviders.contains(provider.id)
                      ? context.colors.surfaceElevated
                      : context.colors.background,
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: CheckboxListTile.adaptive(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    value: _selectedProviders.contains(provider.id),
                    secondary: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: provider.logoPath.isEmpty
                          ? const SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(Icons.tv_outlined))
                          : Image.network(provider.logoUrl,
                              width: 36,
                              height: 36,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                  width: 36,
                                  height: 36,
                                  child: Icon(Icons.tv_outlined))),
                    ),
                    title: Text(provider.providerName),
                    onChanged: _busy
                        ? null
                        : (selected) => setState(() {
                              if (selected == true) {
                                _selectedProviders.add(provider.id);
                              } else {
                                _selectedProviders.remove(provider.id);
                              }
                            }),
                  ),
                ),
              ),
            if (_visibleProviders.isEmpty)
              const Text(
                  'No matching services. You can continue without selecting one.'),
            TextButton(
                onPressed:
                    _busy ? null : () => setState(_selectedProviders.clear),
                child: const Text('I don’t use streaming services')),
          ],
        ],
      ];
  List<Widget> _tastes() => [
        TextField(
            controller: _search,
            decoration: const InputDecoration(
                labelText: 'Search titles', prefixIcon: Icon(Icons.search)),
            onChanged: (_) {
              ++_searchRevision;
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _findTitles);
            }),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final shows in [false, true])
              FlixiePill.choice(
                label: Text(shows ? 'Shows' : 'Movies'),
                selected: _shows == shows,
                showCheckmark: false,
                onSelected: _busy
                    ? null
                    : (_) {
                        if (_shows == shows) return;
                        setState(() => _shows = shows);
                        _findTitles();
                      },
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_searching)
          const ContentPlaceholder(
              label: 'Loading titles', style: ContentPlaceholderStyle.posters),
        if (_searchError != null)
          TextButton(onPressed: _findTitles, child: Text(_searchError!)),
        if (!_searching && _browse.isEmpty && _searchError == null)
          const Text('No matches. Try another title.'),
        if (!_searching) _posterGrid(_browse, picking: true),
        const SizedBox(height: 12),
        Text(
            'These shape your picks on this device. They won’t become public favourites, ratings or watched titles.',
            style: Theme.of(context).textTheme.bodySmall),
        if (_allGenres.isNotEmpty)
          ExpansionTile(
              title: const Text('Genres you enjoy (optional)'),
              children: [
                Wrap(
                    spacing: 8,
                    children: _allGenres
                        .map((g) => FlixiePill.filter(
                            label: Text(g.name),
                            selected: _genres.contains(g.id),
                            onSelected: (v) => setState(() {
                                  v ? _genres.add(g.id) : _genres.remove(g.id);
                                })))
                        .toList())
              ]),
        TextButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.file_upload_outlined),
            label: const Text('Already have a library? Import it')),
        const SizedBox(height: 16),
      ];
  Future<void> _saveTaste({bool skip = false}) => _run(() async {
        await widget.service.saveTaste(
            _userId, skip ? [] : _taste.values.toList(), skip ? {} : _genres);
        if (mounted) {
          if (skip) {
            _taste.clear();
            _genres.clear();
          }
          _move(1);
        }
      });
  Future<void> _loadCommunities() async {
    final revision = ++_communityRevision;
    setState(() {
      _loadingCommunities = true;
      _communityError = null;
    });
    try {
      final choices = await widget.service
          .communitySuggestions(_taste.values.toList(), Set.of(_genres));
      if (!mounted || revision != _communityRevision) return;
      setState(() {
        _communityChoices = choices;
        _selectedCommunities.removeWhere((id) =>
            !choices.any((c) => c.community.id == id && !c.community.joined));
      });
      await Future.wait(
          choices.where((c) => c.suggested).take(3).map((c) async {
        try {
          final thread = await widget.service.conversation(c.community.id);
          if (mounted && revision == _communityRevision && thread != null) {
            setState(() => _conversations[c.community.id] = thread);
          }
        } catch (_) {/* Optional preview failure never blocks browsing. */}
      }));
    } catch (_) {
      if (mounted && revision == _communityRevision) {
        setState(() => _communityError =
            'Couldn’t load communities. Retry or skip for now.');
      }
    } finally {
      if (mounted && revision == _communityRevision) {
        setState(() => _loadingCommunities = false);
      }
    }
  }

  Future<void> _joinCommunities() async {
    if (_busy || (_loadingCommunities && _selectedCommunities.isNotEmpty)) {
      return;
    }
    setState(() {
      _busy = true;
      _communityError = null;
    });
    try {
      for (final id in _selectedCommunities.toList()) {
        await widget.service.joinCommunity(id);
        if (!mounted) return;
        setState(() {
          _selectedCommunities.remove(id);
          _communityChoices = _communityChoices
              .map((c) => c.community.id == id ? c.joined() : c)
              .toList();
        });
      }
      if (mounted) {
        setState(() => _busy = false);
        await _finish('/social?tab=communities');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _communityError =
            'Some communities couldn’t be joined. Your successful joins are saved. Retry the remaining choices or skip.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _communityRow(SetupCommunitySuggestion suggestion) {
    final community = suggestion.community;
    final thread = _conversations[community.id];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: community.joined || _selectedCommunities.contains(community.id),
        onChanged: community.joined || _busy
            ? null
            : (value) => setState(() {
                  if (value == true) {
                    _selectedCommunities.add(community.id);
                  } else {
                    _selectedCommunities.remove(community.id);
                  }
                }),
        title: Text(community.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(community.joined
            ? 'Already joined'
            : suggestion.reason ??
                'Reviews and ratings from community members'),
      ),
      if (thread != null) ...[
        Text('Spoiler-free conversation',
            style: TextStyle(color: context.colors.secondary, fontSize: 12)),
        Text(thread['title'] as String,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        TextButton(
          onPressed: _busy
              ? null
              : () => _finish(
                  '/genre-communities/${community.id}/discussions/${Uri.encodeComponent(thread['id'].toString())}'),
          child: const Text('Read the conversation'),
        ),
      ],
      TextButton(
        onPressed:
            _busy ? null : () => _finish('/genre-communities/${community.id}'),
        child: Text('Browse ${community.name} before joining'),
      ),
      const Divider(),
    ]);
  }

  List<Widget> _communities() => [
        if (_loadingCommunities) const LinearProgressIndicator(),
        if (_communityError != null) ...[
          Semantics(
              liveRegion: true,
              child: Text(_communityError!,
                  style: TextStyle(color: context.colors.danger))),
          if (_selectedCommunities.isEmpty)
            TextButton(
                onPressed:
                    _loadingCommunities || _busy ? null : _loadCommunities,
                child: const Text('Retry communities')),
        ],
        if (!_loadingCommunities &&
            _communityChoices.isEmpty &&
            _communityError == null)
          const Text('You can discover and join communities later in Social.'),
        if (_communityChoices.any((c) => c.suggested)) ...[
          const SizedBox(height: 12),
          const Text('Suggested for you',
              style: TextStyle(fontWeight: FontWeight.w700)),
          ..._communityChoices.where((c) => c.suggested).map(_communityRow),
        ],
        if (_communityChoices.any((c) => !c.suggested))
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Browse communities'),
            children: _communityChoices
                .where((c) => !c.suggested)
                .map(_communityRow)
                .toList(),
          ),
        const SizedBox(height: 16),
        const Text(
            'Joining adds communities to Social. It doesn’t turn on public sharing. Any reviews you already share publicly can appear in communities you join.'),
      ];

  List<Widget> _preferences() => [
        ListenableBuilder(
            listenable: EpisodeSpoilerPreference.instance,
            builder: (context, _) => SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hide episode spoilers'),
                subtitle: const Text('Keep unwatched episode details hidden.'),
                value: EpisodeSpoilerPreference.instance.hide,
                onChanged: _busy
                    ? null
                    : (value) => _run(() =>
                        EpisodeSpoilerPreference.instance.setHidden(value)))),
        const MovieRatingPrivacySetting(
            showIcon: false, contentPadding: EdgeInsets.zero),
        const SizedBox(height: 16),
        Text('You can change both in Settings anytime.',
            style: Theme.of(context).textTheme.bodySmall),
      ];
  List<Widget> _results() => [
        if (_referrer != null)
          Text('You joined through @$_referrer. Find them when you’re ready.'),
        Text(_taste.isEmpty
            ? 'Popular picks to get you started'
            : 'Inspired by the titles you chose'),
        if (_searching)
          const Padding(
              padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        if (_picksError != null)
          TextButton(onPressed: _loadPicks, child: Text(_picksError!)),
        if (!_searching && _picks.isEmpty && _picksError == null)
          const Text(
              'No picks available yet. Explore Flixie or try choosing a few more titles.'),
        if (!_searching)
          for (final title in _rankedPicks) _pickRow(title),
        if (_added.isNotEmpty)
          Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                    'Yours to come back to. Find your saved picks in Watchlist.',
                    style: TextStyle(color: context.colors.secondary)),
              )),
      ];
  List<Widget> _favourites() => [
        const SizedBox(height: 24),
        if (_taste.isEmpty)
          TextButton(
              onPressed: _busy ? null : () => _finish('/profile'),
              child:
                  const Text('Make your profile more you · choose favourites')),
        if (_taste.isNotEmpty)
          SetupProfileFavourites(
            key: const ValueKey('signup-favourites'),
            enabled: !_busy,
            titles: _taste.values.toList(),
            save: (title) => widget.service.addProfileFavourite(_userId, title),
            onSaved: () {
              _favouritesAdded = true;
              context.read<AuthProvider>().markActivityChanged();
              RecommendationService.invalidateCache(userId: _userId);
            },
            onBusyChanged: (busy) {
              if (mounted) {
                setState(() => _busy = busy);
                if (!busy && _favouritesAdded) _loadPicks();
              }
            },
          ),
      ];
  List<Widget> _sharingPreferences() => [
        const SizedBox(height: 16),
        AroundFlixieSharingSetting(
          key: ValueKey('signup-sharing-$_userId'),
          enabled: !_busy,
          contentPadding: EdgeInsets.zero,
          load: widget.service.sharing,
          save: widget.service.setSharing,
          onBusyChanged: (busy) {
            if (mounted) setState(() => _busy = busy);
          },
        ),
        const SizedBox(height: 28),
        Text('Your viewing preferences',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ..._preferences(),
      ];
  Widget _posterGrid(List<SetupTitle> titles, {required bool picking}) =>
      LayoutBuilder(builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
        final columns = (constraints.maxWidth / (largeText ? 150 : 105))
            .floor()
            .clamp(2, 5);
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
            spacing: 12,
            runSpacing: 20,
            children: titles
                .map((t) => SizedBox(
                    width: width,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                              key: ValueKey('taste-${t.key}'),
                              onTap: picking && !_busy
                                  ? () => setState(() {
                                        if (_taste.containsKey(t.key)) {
                                          _taste.remove(t.key);
                                        } else if (_taste.length < 3) {
                                          _taste[t.key] = t;
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Three selected. Remove one to make room for another.')),
                                          );
                                        }
                                      })
                                  : null,
                              child: Semantics(
                                  label: t.name,
                                  selected:
                                      picking && _taste.containsKey(t.key),
                                  child: AspectRatio(
                                      aspectRatio: 2 / 3,
                                      child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                if (t.poster != null)
                                                  Image.network(
                                                      t
                                                              .poster!
                                                              .startsWith(
                                                                  'http')
                                                          ? t.poster!
                                                          : 'https://image.tmdb.org/t/p/w342${t.poster}',
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __,
                                                              ___) =>
                                                          const ColoredBox(
                                                              color: Color(
                                                                  0xffddd0ef),
                                                              child: Icon(Icons
                                                                  .movie_outlined)))
                                                else
                                                  const ColoredBox(
                                                      color: Color(0xffddd0ef),
                                                      child: Icon(Icons
                                                          .movie_outlined)),
                                                if (picking)
                                                  Positioned(
                                                    top: 6,
                                                    right: 6,
                                                    child: AnimatedContainer(
                                                      duration: MediaQuery
                                                              .disableAnimationsOf(
                                                                  context)
                                                          ? Duration.zero
                                                          : const Duration(
                                                              milliseconds:
                                                                  150),
                                                      padding:
                                                          const EdgeInsets.all(
                                                              4),
                                                      decoration: BoxDecoration(
                                                        color:
                                                            _taste.containsKey(
                                                                    t.key)
                                                                ? FlixieColors
                                                                    .primary
                                                                : context.colors
                                                                    .background,
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                            color: _taste
                                                                    .containsKey(
                                                                        t.key)
                                                                ? FlixieColors
                                                                    .primary
                                                                : context.colors
                                                                    .tabBarBorder),
                                                      ),
                                                      child: Icon(
                                                          _taste.containsKey(
                                                                  t.key)
                                                              ? Icons.check
                                                              : Icons.add,
                                                          color: _taste
                                                                  .containsKey(
                                                                      t.key)
                                                              ? Colors.white
                                                              : null,
                                                          size: 18),
                                                    ),
                                                  ),
                                                if (picking &&
                                                    _taste.containsKey(t.key))
                                                  IgnorePointer(
                                                      child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                          color: FlixieColors
                                                              .primary,
                                                          width: 3),
                                                    ),
                                                  )),
                                              ]))))),
                          const SizedBox(height: 8),
                          Text(t.name,
                              style: TextStyle(
                                  fontSize: picking ? 13 : 16,
                                  fontWeight: FontWeight.w600)),
                          if (!picking)
                            Text(t.isShow ? 'Show' : 'Movie',
                                style: Theme.of(context).textTheme.bodySmall),
                          if (!picking) ...[
                            const SizedBox(height: 6),
                            Text(_availabilityLabel(t),
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 8),
                            OutlinedButton(
                                onPressed: _added.contains(t.key) ||
                                        _adding.contains(t.key)
                                    ? null
                                    : () => _add(t),
                                child: Text(_added.contains(t.key)
                                    ? 'Saved'
                                    : _adding.contains(t.key)
                                        ? 'Adding…'
                                        : 'Add to watchlist')),
                          ],
                        ])))
                .toList());
      });
  List<SetupTitle> get _rankedPicks {
    bool included(SetupTitle t) => (_offers[t.key] ?? [])
        .any((p) => p.isIncludedOffer && _selectedProviders.contains(p.id));
    return [..._picks.where(included), ..._picks.where((t) => !included(t))]
        .take(3)
        .toList();
  }

  Widget _pickRow(SetupTitle title) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 72,
                height: 108,
                child: title.poster == null
                    ? ColoredBox(
                        color: context.colors.surfaceElevated,
                        child: const Icon(Icons.movie_outlined))
                    : Image.network(
                        title.poster!.startsWith('http')
                            ? title.poster!
                            : 'https://image.tmdb.org/t/p/w185${title.poster}',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                            color: context.colors.surfaceElevated,
                            child: const Icon(Icons.movie_outlined))),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(title.isShow ? 'Show' : 'Movie',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                if (title.reason != null)
                  Text(title.reason!,
                      style: TextStyle(
                          color: context.colors.secondary, fontSize: 13)),
                Text(_availabilityLabel(title),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  TextButton(
                    style: TextButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 13),
                        minimumSize: const Size(44, 44)),
                    onPressed: _busy
                        ? null
                        : () => _finish(
                            '/${title.isShow ? 'shows' : 'movies'}/${title.id}'),
                    child:
                        Text(title.isShow ? 'Show details' : 'Movie details'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        textStyle: const TextStyle(fontSize: 13),
                        minimumSize: const Size(44, 44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10))),
                    onPressed: _added.contains(title.key) ||
                            _adding.contains(title.key)
                        ? null
                        : () => _add(title),
                    icon: Icon(
                        _added.contains(title.key) ? Icons.check : Icons.add,
                        size: 18),
                    label: Text(_added.contains(title.key)
                        ? 'Saved'
                        : _adding.contains(title.key)
                            ? 'Adding…'
                            : 'Add to watchlist'),
                  ),
                ]),
              ],
            )),
          ],
        ),
      );

  String _availabilityLabel(SetupTitle title) {
    if (_country == null) {
      return 'Choose your country in Settings for watch options';
    }
    if (!_offers.containsKey(title.key)) return 'Checking watch options…';
    final offers = _offers[title.key];
    if (offers == null) return 'Watch options unavailable';
    final included = offers.where((p) => p.isIncludedOffer).toList();
    final mine =
        included.where((p) => _selectedProviders.contains(p.id)).toList();
    if (mine.isNotEmpty) {
      return 'On your services: ${mine.map((p) => p.providerName).join(', ')}';
    }
    if (included.isNotEmpty) {
      return 'Streaming: ${included.map((p) => p.providerName).join(', ')}';
    }
    if (offers.isNotEmpty) return 'Rent or buy options available';
    return 'No watch options listed in ${_country!.name}';
  }
}
