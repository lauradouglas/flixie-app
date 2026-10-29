import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/models/watch_log_details.dart';
import 'package:flixie_app/features/profile/data/diary_entry_service.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import 'package:flixie_app/features/pip/presentation/widgets/my_pip_sheet.dart';
import '../../data/curated_lists_service.dart';
import '../../models/curated_list.dart';
import '../controllers/curated_list_controller.dart';
import '../widgets/curated_list_views.dart';
import '../widgets/curated_rules_sheet.dart';
import '../widgets/curated_list_intro.dart';
import '../widgets/christmas_reward_frame.dart';

class CuratedListPage extends StatefulWidget {
  const CuratedListPage(
      {super.key,
      required this.id,
      this.service = const CuratedListsService(),
      this.diary = const DiaryEntryService()});
  final String id;
  final CuratedListsService service;
  final DiaryEntryService diary;
  @override
  State<CuratedListPage> createState() => _CuratedListPageState();
}

class _CuratedListPageState extends State<CuratedListPage>
    with WidgetsBindingObserver {
  late final AuthProvider _auth;
  late final CuratedListController _c;
  String? _owner;
  bool _toWatch = false, _rewardSheetOpen = false, _logging = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _auth = context.read<AuthProvider>();
    _owner = _auth.dbUser?.id;
    _c = CuratedListController(
        id: widget.id,
        currentUserId: () => _auth.dbUser?.id,
        service: widget.service)
      ..addListener(_changed);
    _auth.addListener(_authChanged);
    unawaited(_c.load());
  }

  void _authChanged() {
    final owner = _auth.dbUser?.id;
    if (owner == _owner) return;
    _owner = owner;
    _c.resetOwner();
    unawaited(_c.load());
  }

  void _changed() {
    if (!_c.newCompletion || _rewardSheetOpen) return;
    _rewardSheetOpen = true;
    final owner = _owner;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (mounted && owner == _owner && _c.takeCompletion()) await _rewards();
      } finally {
        _rewardSheetOpen = false;
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_logging) unawaited(_c.load());
  }

  Future<bool> _signedIn() => GuestAccess.require(context,
      title: 'Join a watch challenge',
      message:
          'Sign in to track your progress and collect this list’s rewards.',
      path: '/flixie-lists/${widget.id}',
      intent: 'curated-list');
  Future<void> _join() async {
    if (!await _signedIn() || !mounted) return;
    await _c.join();
  }

  Future<void> _rules() => showFlixiePromptSheet<void>(
      context: context,
      maxHeightFraction: .9,
      backgroundColor: const Color(0xFF191B2D),
      builder: (_) => CuratedRulesSheet(list: _c.list!));
  Future<void> _rewards() async {
    final list = _c.list, owner = _owner;
    if (list == null || owner == null) return;
    final pips = context.read<PipCollectionController?>();
    await Future.wait([
      _auth.refreshUserData(),
      if (pips != null) pips.refreshAfterReward()
    ].map((future) => future.catchError((_) {})));
    if (!mounted || owner != _owner) return;
    ModalRoute<dynamic>? route;
    final choose = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (sheetContext) {
          route = ModalRoute.of(sheetContext);
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                    list.rewards.isEmpty
                        ? 'Goal complete'
                        : 'Your rewards are unlocked',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                    '${list.requiredCount} of ${list.requiredCount} films watched and rated.'),
                const SizedBox(height: 16),
                for (final reward in list.rewards)
                  Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(children: [
                        CuratedRewardArt(reward: reward, size: 56),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(reward.name,
                                  style:
                                      Theme.of(context).textTheme.titleSmall),
                              Text(
                                  reward.isPip
                                      ? 'Yours to keep'
                                      : 'Added to your avatar',
                                  style: Theme.of(context).textTheme.bodySmall)
                            ])),
                        const Icon(Icons.check_circle_outline)
                      ])),
                if (list.rewards.any((r) => r.isPip)) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('Choose Pip'))
                ],
                TextButton(
                    onPressed: () => Navigator.pop(sheetContext, false),
                    child: const Text('Done'))
              ]);
        });
    await route?.completed;
    if (owner == _owner && pips?.verified == true) {
      for (final reward in list.rewards.where((r) => r.isPip)) {
        if (pips!.collection.owns(reward.key)) {
          try {
            await pips.acknowledgeSeasonal(reward.key);
          } catch (_) {
            /* Ownership is saved; acknowledgement can retry later. */
          }
        }
      }
    }
    if (choose == true && mounted && owner == _owner) {
      await showMyPipSheet(context, initialPane: 'outfit');
    }
  }

  Future<void> _log(CuratedFilm film) async {
    if (_logging) return;
    if (!await GuestAccess.require(context,
            path: '/movies/${film.id}',
            intent: 'log',
            mediaTitle: film.title,
            mediaPoster: film.poster) ||
        !mounted) {
      return;
    }
    final owner = _auth.dbUser?.id;
    if (owner == null) return;
    _logging = true;
    var saved = false;
    var details = const WatchLogDetails();
    final draftId = const Uuid().v4();
    ModalRoute<dynamic>? logRoute;
    try {
      await showMovieWatchLogSheet<void>(
          context: context,
          movieId: film.id,
          movieTitle: film.title,
          releaseDate: film.releaseDate,
          builder: (sheetContext) {
            logRoute = ModalRoute.of(sheetContext);
            return RewatchLogSheet(
                requireRating: true,
                movieTitle: film.title,
                movieYear: film.year,
                onDetailsChanged: (value) => details = value,
                onSubmit: (
                    {required watchedAt,
                    required rating,
                    required recommended,
                    required notes}) async {
                  if (_auth.dbUser?.id != owner) {
                    throw StateError(
                        'Your account changed. Reopen the watch log.');
                  }
                  await widget.diary.log(
                      owner,
                      LogMovieWatchRequest(
                          draftId: draftId,
                          movieId: film.id,
                          watchedAt: watchedAt,
                          rating: rating,
                          recommended: recommended,
                          notes: notes,
                          watchedAtCinema: details.watchedAtCinema,
                          companionId: details.companion?.id,
                          companionIds:
                              details.companions.map((p) => p.id).toList(),
                          externalCompanionName:
                              details.externalCompanionName));
                  saved = true;
                  if (_auth.dbUser?.id == owner) _auth.markActivityChanged();
                });
          });
      await logRoute?.completed;
    } finally {
      _logging = false;
    }
    if (!saved || !mounted || _auth.dbUser?.id != owner) return;
    // A progress failure must never turn an already-saved diary entry into a failed watch.
    await _c.refreshProgress();
    unawaited(_auth.refreshLibrary());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final list = _c.list, progress = _c.progress;
        return Scaffold(
            backgroundColor: context.colors.background,
            appBar: _appBar(list?.title ?? 'Watch challenges'),
            body: list == null
                ? Center(
                    child: _c.loading
                        ? const CircularProgressIndicator()
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_c.error ?? 'This list is unavailable.'),
                            TextButton(
                                onPressed: _c.load, child: const Text('Retry'))
                          ]))
                : RefreshIndicator(
                    onRefresh: _c.load,
                    child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [
                          Center(
                              child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 760),
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        CuratedListIntro(list: list),
                                        if (progress != null) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                              progress.completedAt != null
                                                  ? 'Goal complete'
                                                  : progress.label,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600)),
                                          const SizedBox(height: 8),
                                          LinearProgressIndicator(
                                              value:
                                                  progress.completedAt != null
                                                      ? 1
                                                      : progress.fraction,
                                              minHeight: 5)
                                        ],
                                        if (_c.loading)
                                          const Padding(
                                              padding: EdgeInsets.only(top: 12),
                                              child: LinearProgressIndicator()),
                                        if (_c.error != null)
                                          Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 12),
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(_c.error!,
                                                        style: TextStyle(
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .error)),
                                                    TextButton(
                                                        onPressed: _c.busy
                                                            ? null
                                                            : _c.load,
                                                        child: const Text(
                                                            'Retry progress'))
                                                  ])),
                                        const SizedBox(height: 16),
                                        if (list.rewards.isNotEmpty)
                                          _rewardArea(list.rewards)
                                        else
                                          Align(
                                              alignment: Alignment.centerLeft,
                                              child: TextButton(
                                                  onPressed: _rules,
                                                  child: const Text(
                                                      'View rules'))),
                                        const SizedBox(height: 14),
                                        if (progress?.completedAt != null)
                                          OutlinedButton(
                                              onPressed: _rewards,
                                              child: const Text(
                                                  'View unlocked rewards'))
                                        else if (progress?.joined == true)
                                          const Text(
                                              'Joined · your watched and rated films count towards this goal.')
                                        else if (list.openAt(DateTime.now()))
                                          FilledButton(
                                              onPressed: _c.busy ? null : _join,
                                              child: Text(_c.busy
                                                  ? 'Joining…'
                                                  : 'Join challenge'))
                                        else if (list.startsAt == null ||
                                            !DateTime.now()
                                                .isBefore(list.startsAt!))
                                          const Text(
                                              'This challenge has ended.'),
                                        const SizedBox(height: 16),
                                        _tabs(list.filmCount),
                                        const SizedBox(height: 6),
                                        for (final film in list.films.where(
                                            (film) =>
                                                !_toWatch ||
                                                !(progress?.watchedIds
                                                        .contains(film.id) ??
                                                    false)))
                                          _film(
                                              film,
                                              progress?.watchedIds
                                                      .contains(film.id) ??
                                                  false),
                                        const SizedBox(height: 20),
                                        Text(
                                            list.watchRule == 'ANY_WATCH'
                                                ? 'Your diary history counts towards this goal.'
                                                : 'Rated diary watches during the challenge count towards your goal.',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall),
                                      ])))
                        ])));
      });
  AppBar _appBar(String title) {
    final style = Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: Theme.of(context).colorScheme.onSurface);
    final painter = TextPainter(
        text: TextSpan(text: title, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context))
      ..layout(
          maxWidth: (MediaQuery.sizeOf(context).width - 96)
              .clamp(1.0, double.infinity));
    final height = (painter.height + 24).clamp(kToolbarHeight, double.infinity);
    painter.dispose();
    return AppBar(
        title: Text(title, softWrap: true),
        titleTextStyle: style,
        centerTitle: false,
        toolbarHeight: height);
  }

  Widget _rewardArea(List<CuratedReward> rewards) {
    final festive = _c.list?.theme == CuratedListTheme.christmas;
    return ChristmasRewardFrame(
        enabled: festive,
        child: Container(
            padding: EdgeInsets.fromLTRB(
                14, festive ? 16 : 6, 14, festive ? 22 : 14),
            decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(14)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                  width: double.infinity,
                  child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 16,
                      children: [
                        Text('Your rewards',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.2,
                                    color: context.colors.primaryText)),
                        TextButton(
                            onPressed: _rules,
                            style: TextButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(44, 44)),
                            child: Text('View rules',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        height: 1.2,
                                        color: context.colors.primaryText))),
                      ])),
              const SizedBox(height: 4),
              LayoutBuilder(builder: (context, box) {
                final stacked = box.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.3;
                final width = stacked ? box.maxWidth : (box.maxWidth - 12) / 2;
                return Wrap(spacing: 12, runSpacing: 12, children: [
                  for (final reward in rewards)
                    SizedBox(
                        width: width,
                        child: Row(children: [
                          CuratedRewardArt(reward: reward, size: 64),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(reward.name,
                                  style:
                                      Theme.of(context).textTheme.bodySmall)),
                        ])),
                ]);
              }),
            ])));
  }

  Widget _tabs(int count) => DecoratedBox(
      decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(
                  color: context.colors.light.withValues(alpha: .2)))),
      child: Wrap(spacing: 28, children: [
        _tab('All ($count)', !_toWatch, () => setState(() => _toWatch = false)),
        _tab('Still to watch', _toWatch, () => setState(() => _toWatch = true)),
      ]));

  Widget _tab(String label, bool selected, VoidCallback onTap) => Semantics(
      selected: selected,
      button: true,
      child: InkWell(
          onTap: onTap,
          child: IntrinsicWidth(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    child: Text(label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 16,
                            height: 1.3,
                            fontWeight:
                                selected ? FontWeight.w800 : FontWeight.w500,
                            fontVariations: [
                              FontVariation('wght', selected ? 800 : 500)
                            ],
                            color: selected
                                ? context.colors.primaryText
                                : context.colors.light))),
                Container(
                    height: 3,
                    color: selected
                        ? context.colors.primaryText
                        : Colors.transparent),
              ]))));

  Future<void> _openFilm(CuratedFilm film) async {
    await context.push('/movies/${film.id}');
    if (mounted) await _c.load();
  }

  Widget _film(CuratedFilm film, bool watched) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(children: [
        LayoutBuilder(builder: (context, box) {
          final stacked = box.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.3;
          final action = watched
              ? SizedBox(
                  width: 90,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle,
                        size: 24, color: context.colors.primaryText),
                    const SizedBox(height: 4),
                    Text('Watched & rated',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall),
                  ]))
              : Semantics(
                  button: true,
                  enabled: !_c.busy,
                  label: 'Log and rate ${film.title}',
                  excludeSemantics: true,
                  child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _c.busy ? null : () => _log(film),
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: context.colors.primary),
                                      child: const Icon(Icons.add,
                                          size: 20, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text('Log & rate',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontSize: 12,
                                              height: 1.3,
                                              color: context.colors.light)),
                                ])),
                      )));
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Semantics(
                button: true,
                label: 'View ${film.title}',
                child: InkWell(
                    onTap: () => _openFilm(film),
                    borderRadius: BorderRadius.circular(4),
                    child:
                        CuratedPoster(film: film, width: 48, borderRadius: 4))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  InkWell(
                      onTap: () => _openFilm(film),
                      child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(film.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                      fontSize: 16,
                                      height: 1.25,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontWeight: FontWeight.w800,
                                      fontVariations: const [
                                    FontVariation('wght', 800)
                                  ])))),
                  Text(film.year,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          height: 1.3,
                          color: context.colors.light)),
                  if (stacked)
                    Padding(
                        padding: const EdgeInsets.only(top: 8), child: action)
                ])),
            if (!stacked) ...[const SizedBox(width: 8), action]
          ]);
        }),
        const SizedBox(height: 6),
        Padding(
            padding: const EdgeInsets.only(left: 60),
            child: Divider(
                height: 1, color: context.colors.light.withValues(alpha: .2)))
      ]));
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_authChanged);
    _c.removeListener(_changed);
    _c.dispose();
    super.dispose();
  }
}
