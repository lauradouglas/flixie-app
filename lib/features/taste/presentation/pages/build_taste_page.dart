import 'dart:async';
import '../../../settings/presentation/widgets/watch_providers_sheet.dart';
import '../../../../app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/auth/auth_provider.dart';
import '../../../../core/widgets/flixie_wordmark.dart';
import '../../../authentication/presentation/widgets/signup_title_grid.dart';
import '../../../authentication/presentation/widgets/signup_title_context.dart';
import '../../../movies/presentation/widgets/title_rating_editor.dart';
import '../../data/taste_service.dart';
import '../../data/taste_setup_store.dart';
import '../controllers/taste_controller.dart';

class BuildTastePage extends StatefulWidget {
  const BuildTastePage(
      {super.key,
      this.service = const TasteService(),
      this.store = const TasteSetupStore()});
  final TasteService service;
  final TasteSetupStore store;
  @override
  State<BuildTastePage> createState() => _BuildTastePageState();
}

class _BuildTastePageState extends State<BuildTastePage> {
  TasteController? _controller;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  bool _exiting = false;
  TasteController get data => _controller!;
  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final id = auth.dbUser?.id;
    if (id != null) {
      _controller = TasteController(
          userId: id,
          service: widget.service,
          store: widget.store,
          isCurrent: () => mounted && auth.dbUser?.id == id,
          onSaved: () {
            if (auth.dbUser?.id != id) return;
            auth.markActivityChanged();
            unawaited(auth.refreshLibrary().catchError((Object _) => false));
          })
        ..addListener(_changed);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.maybeOf(context)?.clearSnackBars();
        data.load();
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _move(String step) async {
    _debounce?.cancel();
    FocusManager.instance.primaryFocus?.unfocus();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _search.clear();
    await data.move(step);
  }

  Future<void> _exit({bool explore = false}) async {
    if (_exiting || (_controller?.busy ?? false)) return;
    setState(() => _exiting = true);
    try {
      await _controller?.dismiss();
    } catch (_) {/* Do not trap people in optional setup. */}
    if (!mounted) return;
    if (!explore && context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    _controller?.dispose();
    super.dispose();
  }

  Widget _heading(String title, String body) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 10),
        Text(body),
        const SizedBox(height: 24),
      ]);
  Widget _picker({required bool rating}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(rating ? '2 of 2 · Optional' : '1 of 2 · Favourites · Optional'),
        const SizedBox(height: 16),
        _heading(
            rating
                ? 'Seen it? Give us your take.'
                : 'Which films are your favourites?',
            rating
                ? 'Choose a film you’ve watched. Rate honestly — low scores help shape your taste too.'
                : 'Tap a heart for an all-time favourite. One is a good start; add more whenever you like.'),
        TextField(
            controller: _search,
            onChanged: (query) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () {
                if (mounted && data.active) data.search(query);
              });
            },
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                labelText: rating
                    ? 'Find a film you’ve seen'
                    : 'Find a favourite film')),
        const SizedBox(height: 20),
        if (data.searching) const Center(child: CircularProgressIndicator()),
        if (data.searchError != null) ...[
          Text(data.searchError!),
          TextButton(
              onPressed: () => data.search(_search.text),
              child: const Text('Retry search'))
        ],
        if (!data.searching && data.searchError == null && data.titles.isEmpty)
          const Text('No films found. Try another title.'),
        SignupTitleGrid(
            titles: data.titles,
            saved: {for (final id in data.favourites) 'movie:$id'},
            pending: {
              if (data.pendingFavourite != null) data.pendingFavourite!
            },
            disabled: data.busy,
            favourites: !rating,
            selectForRating: rating,
            allowRemoval: !rating,
            onAdd: (title) {
              FocusManager.instance.primaryFocus?.unfocus();
              if (rating) {
                data.choose(title);
              } else {
                data.toggle(title);
              }
            }),
        const SizedBox(height: 20),
        if (!rating) ...[
          Text(
              '${data.favourites.length} favourite films · Saved as you choose'),
          const SizedBox(height: 8),
          const Text('Favourites appear on your profile.'),
          const SizedBox(height: 16),
        ],
      ]);
  @override
  Widget build(BuildContext context) {
    final viewer = context.watch<AuthProvider>().dbUser?.id;
    final active = _controller != null && viewer == data.userId;
    Widget body;
    if (!active) {
      body = Column(children: [
        const Text('Your session has changed.'),
        TextButton(
            onPressed: () => context.go('/'), child: const Text('Back to Home'))
      ]);
    } else if (data.loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (data.error != null && data.titles.isEmpty) {
      body = Column(children: [
        Text(data.error!),
        TextButton(onPressed: data.load, child: const Text('Try again'))
      ]);
    } else if (data.step == 'summary') {
      final hasTaste = data.favourites.isNotEmpty || data.ratings.isNotEmpty;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Icon(Icons.check_circle_outline,
            size: 48, color: context.colors.primaryTint),
        const SizedBox(height: 20),
        _heading(
            hasTaste ? 'A little more you.' : 'Good films are still waiting.',
            hasTaste
                ? 'Your film ratings and favourites give Flixie more to go on. Keep rating as you watch — your taste can change with you.'
                : 'Browse first. You can build your taste any time from your profile.'),
        if (hasTaste)
          Text(
              '${data.favourites.length} favourite films · ${data.ratings.length} ratings saved this visit'),
        for (final entry in data.ratings.values) ...[
          const SizedBox(height: 16),
          SignupTitleContext(
              title: '${entry.title.name} · ${entry.score}/10',
              isShow: false,
              poster: entry.title.poster),
        ],
        const SizedBox(height: 24),
        FilledButton(
            onPressed: _exiting ? null : () => _exit(explore: true),
            child: const Text('Explore For You')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            onPressed: _exiting ? null : () => _move('rating'),
            icon: const Icon(Icons.star_outline_rounded),
            label:
                const Text('Rate another film', textAlign: TextAlign.center)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            onPressed: _exiting ? null : () => _move('favourites'),
            icon: const Icon(Icons.favorite_border_rounded),
            label:
                const Text('Add more favourites', textAlign: TextAlign.center)),
        const SizedBox(height: 28),
        Text('Your streaming services',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
            'Optional: add the services you use so Flixie can highlight them when you’re choosing what to watch.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: _exiting ? null : () => showWatchProvidersSetup(context),
            icon: const Icon(Icons.live_tv_rounded),
            label: const Text('Add or edit watch providers')),
      ]);
    } else if (data.step == 'rating' && data.selected != null) {
      final title = data.selected!;
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SignupTitleContext(
            title: title.name, isShow: false, poster: title.poster),
        if (data.ratingLoading)
          const Center(child: CircularProgressIndicator())
        else if (data.ratingError != null) ...[
          Text(data.ratingError!),
          TextButton(
              onPressed: () => data.choose(title),
              child: const Text('Retry rating'))
        ] else
          TitleRatingEditor(
              key: ValueKey('${title.key}:${data.initialRating}'),
              title: 'How was ${title.name}?',
              subtitle: 'Rate honestly. The films you didn’t love help too.',
              initialRating: data.initialRating,
              initialRecommendation: data.initialRecommendation,
              onSave: data.rate),
        const SizedBox(height: 16),
        OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            onPressed: data.busy ? null : data.chooseAnother,
            icon: const Icon(Icons.search_rounded),
            label:
                const Text('Choose another film', textAlign: TextAlign.center)),
        TextButton(
            onPressed: data.busy ? null : () => _move('summary'),
            child: const Text('Skip for now')),
      ]);
    } else {
      body = _picker(rating: data.step == 'rating');
    }
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _exit();
        },
        child: Scaffold(
          appBar: AppBar(
              automaticallyImplyLeading: false,
              title: const FlixieWordmark(),
              actions: [
                IconButton(
                    tooltip: 'Close taste setup',
                    onPressed:
                        _exiting || (_controller?.busy ?? false) ? null : _exit,
                    icon: const Icon(Icons.close)),
              ]),
          bottomNavigationBar: active &&
                  !data.loading &&
                  MediaQuery.viewInsetsOf(context).bottom <= 0 &&
                  (data.step == 'favourites' ||
                      (data.step == 'rating' && data.selected == null))
              ? SafeArea(
                  child: Align(
                      heightFactor: 1,
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(24, 12, 24, 12),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    if (data.step == 'favourites')
                                      FilledButton(
                                          onPressed: data.busy
                                              ? null
                                              : () => _move('rating'),
                                          child: const Text(
                                              'Continue to ratings')),
                                    TextButton(
                                        onPressed: data.busy
                                            ? null
                                            : () => _move(
                                                data.step == 'favourites'
                                                    ? 'rating'
                                                    : 'summary'),
                                        child: const Text('Skip for now')),
                                  ])))))
              : null,
          body: SafeArea(
              child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: SingleChildScrollView(
                          controller: _scroll,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (active &&
                                    data.error != null &&
                                    data.titles.isNotEmpty) ...[
                                  Text(data.error!),
                                  const SizedBox(height: 12)
                                ],
                                body,
                              ]))))),
        ));
  }
}
