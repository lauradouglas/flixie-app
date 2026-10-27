import '../../../guest/data/guest_diary_store.dart';
import '../../../guest/models/guest_diary_draft.dart';
import '../../../guest/presentation/widgets/guest_diary_editor.dart';
import '../../../taste/data/taste_setup_store.dart';
import '../../../watchlist/data/guest_watchlist_store.dart';
import '../widgets/signup_title_context.dart';
import 'package:flixie_app/features/profile/presentation/widgets/change_avatar_sheet.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/onboarding/onboarding_services_step.dart';
import '../widgets/signup_title_grid.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/movies/models/watch_log_details.dart';
import 'package:flixie_app/features/movies/presentation/widgets/title_rating_editor.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/unreleased_movie_prompt.dart';
import 'package:flixie_app/features/movies/presentation/widgets/external_watch_invite_sheet.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/country.dart';
import '../../data/setup_service.dart';
import '../../data/signup_journey_service.dart';
import '../../models/signup_journey.dart';
import 'signup_screen.dart' show SignupCountryPickerSheet;

enum SignupJourneyStep {
  purpose,
  chooseLog,
  action,
  suggestions,
  providers,
  reviewSaved,
  watch,
  saved
}

/// An account's first task comes before skippable personalisation.
class SignupJourneyPage extends StatefulWidget {
  const SignupJourneyPage(
      {super.key,
      this.journey,
      this.service = const SignupJourneyService(),
      this.setup = const SetupService()});
  final SignupJourney? journey;
  final SignupJourneyService service;
  final SetupService setup;
  @override
  State<SignupJourneyPage> createState() => _SignupJourneyPageState();
}

class _SignupJourneyPageState extends State<SignupJourneyPage> {
  late SignupJourney? _journey = widget.journey ?? GuestAccess.journey;
  SignupJourney get journey => _journey!;
  SignupJourneyStep _step = SignupJourneyStep.action;
  String? _homeChoice;
  bool get _favourites =>
      const {'rate', 'favorite', 'profile'}.contains(journey.action) ||
      _homeChoice == 'favourites';
  SetupTitle? _title;
  List<SetupTitle> _suggestions = [];
  final _added = <String>{};
  final _savingTitles = <String>{};
  String? _error, _suggestionError;
  bool _editorBusy = false;
  bool _busy = false, _loading = true, _suggestionsLoading = false;
  MovieWatchEntry? _watch;
  Review? _review;
  WatchLogDetails _details = const WatchLogDetails();
  GuestDiaryDraft? _guestDraft;
  final _draftId = const Uuid().v4();
  OnboardingController? _watching;
  void _providerChanged() {
    if (mounted) setState(() {});
  }

  final _providerSearch = TextEditingController();
  final _titleSearch = TextEditingController();
  Timer? _searchDebounce;
  int _searchRevision = 0;
  bool _searchShows = false;
  Future<void> _findTitles() async {
    final revision = ++_searchRevision;
    final query = _titleSearch.text.trim();
    if (query.isEmpty) {
      await _loadSuggestions();
      return;
    }
    setState(() {
      _suggestionsLoading = true;
      _suggestionError = null;
    });
    try {
      final rows = await widget.setup.search(query, _searchShows);
      if (_active && revision == _searchRevision) {
        setState(() => _suggestions = rows);
      }
    } catch (_) {
      if (_active && revision == _searchRevision) {
        setState(() =>
            _suggestionError = 'Couldn’t search right now. Please try again.');
      }
    } finally {
      if (_active && revision == _searchRevision) {
        setState(() => _suggestionsLoading = false);
      }
    }
  }

  bool get _active =>
      mounted &&
      _journey != null &&
      context.read<AuthProvider>().dbUser?.id == journey.userId;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _watching?.removeListener(_providerChanged);
    _watching?.dispose();
    _searchDebounce?.cancel();
    _titleSearch.dispose();
    _providerSearch.dispose();
    super.dispose();
  }

  void _analytics(Future<void> Function(AnalyticsController) event) {
    final analytics = context.read<AnalyticsController?>();
    if (analytics != null) {
      unawaited(event(analytics).catchError((Object _) {}));
    }
  }

  void _changed() {
    unawaited(const TasteSetupStore()
        .enable(journey.userId)
        .catchError((Object _) {}));
    context.read<AuthProvider>().markActivityChanged();
  }

  Future<void> _start() async {
    if (!_active) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Your signup session has ended. Open your title to continue.';
        });
      }
      return;
    }
    _analytics((a) => a.onboardingStarted());
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (journey.action == 'guest-watchlist') {
        final saved = await GuestWatchlistStore.instance.merge(
            active: () => _active,
            save: (title) => widget.service.saveTitle(journey.userId, title));
        if (!_active) return;
        _changed();
        _added.addAll(saved.map((t) => t.key));
        for (final title in saved) {
          _analytics((a) => a.watchlistAdded(
              contentType: title.isShow ? 'show' : 'movie',
              contentId: title.id,
              source: 'guest_watchlist_signup'));
        }
        if (saved.isNotEmpty) _title = saved.last;
        _homeChoice = 'watchlist';
        setState(() => _step = SignupJourneyStep.suggestions);
        unawaited(_loadSuggestions());
        return;
      }
      if (journey.handoff) {
        await _finish(resumeAction: true);
        return;
      }
      if (journey.action == 'home') {
        setState(() {
          _loading = false;
          _step = SignupJourneyStep.purpose;
        });
        return;
      }
      if (journey.action == 'profile') {
        setState(() {
          _loading = false;
          _step = SignupJourneyStep.suggestions;
        });
        unawaited(_loadSuggestions());
        return;
      }
      if (journey.diaryDraftId != null) {
        _guestDraft = await GuestDiaryStore.instance
            .read(journey.diaryDraftId!, journey.userId);
        if (_guestDraft == null || _guestDraft!.owner != journey.userId) {
          throw StateError('This draft belongs to a different session');
        }
      }
      final title = await widget.service.title(journey);
      if (!mounted || !_active) return;
      setState(() => _title = title);
      if (journey.action == 'watchlist' || journey.action == 'favorite') {
        await widget.service.saveTitle(journey.userId, title,
            favourite: journey.action == 'favorite');
        if (!mounted || !_active) return;
        _changed();
        _added.add(title.key);
        if (journey.action == 'watchlist') {
          _analytics((a) => a.watchlistAdded(
              contentType: title.isShow ? 'show' : 'movie',
              contentId: title.id,
              source: 'onboarding'));
        }
        setState(() => _step = SignupJourneyStep.suggestions);
        unawaited(_loadSuggestions());
      } else if (journey.action == 'episode') {
        await widget.service.episode(journey);
        if (!mounted || !_active) return;
        _changed();
        _analytics((a) => a.watchLogged(
            contentType: 'show',
            contentId: journey.mediaId,
            source: 'onboarding'));
        setState(() => _step = SignupJourneyStep.saved);
      } else if (!journey.isShow && journey.action == 'log') {
        final movie = await widget.service.movieRelease(journey.mediaId);
        if (!mounted || !_active) return;
        final proceed = await confirmUnreleasedMovie(context,
            title: title.name,
            releaseDate: movie.releaseDate,
            status: movie.status);
        if (!mounted || !_active) return;
        if (!proceed) {
          setState(() => _error =
              'You can return to this film and log it when you’re ready.');
        }
      }
    } catch (_) {
      if (_active) {
        setState(() => _error = journey.action == 'guest-watchlist'
            ? 'Your account is ready. Some picks still need saving. They’re safe on this device - retry to finish.'
            : 'Couldn’t open your ${journey.action == 'watchlist' ? 'save' : 'title'}. Try again - your account is ready.');
      }
    } finally {
      if (_active) setState(() => _loading = false);
    }
  }

  Future<void> _loadSuggestions() async {
    final revision = ++_searchRevision;
    setState(() {
      _suggestionsLoading = true;
      _suggestionError = null;
    });
    try {
      final titles = _title == null
          ? await widget.service.initialSuggestions()
          : await widget.service.suggestions(_title!);
      if (_active && revision == _searchRevision) {
        setState(() => _suggestions =
            _favourites && _title != null ? [_title!, ...titles] : titles);
      }
    } catch (_) {
      if (_active && revision == _searchRevision) {
        setState(() => _suggestionError =
            'Couldn’t load more titles. Retry or keep going.');
      }
    } finally {
      if (_active && revision == _searchRevision) {
        setState(() => _suggestionsLoading = false);
      }
    }
  }

  Future<void> _add(SetupTitle title) async {
    if (!_active ||
        _added.contains(title.key) ||
        _savingTitles.contains(title.key)) {
      return;
    }
    setState(() {
      _savingTitles.add(title.key);
      _suggestionError = null;
    });
    try {
      await widget.service
          .saveTitle(journey.userId, title, favourite: _favourites);
      if (!mounted || !_active) return;
      _changed();
      setState(() => _added.add(title.key));
      if (!_favourites) {
        _analytics((a) => a.watchlistAdded(
            contentType: title.isShow ? 'show' : 'movie',
            contentId: title.id,
            source: 'onboarding'));
      }
    } catch (_) {
      if (_active) {
        setState(() => _suggestionError =
            'Couldn’t add ${title.name}. Tap it to try again. Your other choices are saved.');
      }
    } finally {
      if (_active) setState(() => _savingTitles.remove(title.key));
    }
  }

  Future<void> _rate(int rating, String? recommendation) async {
    if (!mounted || !_active) return;
    await widget.service.rate(journey, rating, recommendation);
    if (!mounted || !_active) return;
    _changed();
    _analytics((a) => a.ratingAdded(
        contentType: journey.isShow ? 'show' : 'movie',
        contentId: journey.mediaId,
        source: 'onboarding'));
    setState(() {
      _editorBusy = false;
      _step = SignupJourneyStep.suggestions;
    });
    unawaited(_loadSuggestions());
  }

  Future<void> _log(
      {required String? watchedAt,
      required double? rating,
      required bool? recommended,
      required String? notes}) async {
    if (!mounted || !_active) return;
    // A stable draft ID makes retrying a timed-out save safe.
    final saved = await widget.service.log(
        journey.userId,
        LogMovieWatchRequest(
            movieId: journey.mediaId,
            draftId: journey.diaryDraftId ?? _draftId,
            watchedAt: watchedAt,
            rating: rating,
            recommended: recommended,
            notes: notes,
            watchedAtCinema: _details.watchedAtCinema,
            companionIds: _details.companions.map((c) => c.id).toList(),
            externalCompanionName: _details.externalCompanionName));
    if (!mounted || !_active) return;
    _changed();
    _analytics((a) => a.watchLogged(
        contentType: 'movie',
        contentId: journey.mediaId,
        source: 'onboarding'));
    setState(() {
      _editorBusy = false;
      _watch = saved;
      _step = SignupJourneyStep.saved;
    });
  }

  Future<void> _openReviewDiary() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final movie = await widget.service.movieRelease(journey.mediaId);
      if (!mounted || !_active) return;
      if (!await confirmUnreleasedMovie(context,
          title: _title!.name,
          releaseDate: movie.releaseDate,
          status: movie.status)) {
        return;
      }
      if (mounted && _active) setState(() => _step = SignupJourneyStep.watch);
    } catch (_) {
      if (_active) {
        setState(() => _error =
            'Your review is posted. Couldn’t open the diary yet - please try again.');
      }
    } finally {
      if (_active) setState(() => _busy = false);
    }
  }

  void _reviewSaved(Review review) {
    _editorBusy = false;
    if (!mounted || !_active) return;
    final auth = context.read<AuthProvider>();
    auth.invalidateCachedReviews();
    _changed();
    setState(() {
      _review = review;
      _step = SignupJourneyStep.reviewSaved;
    });
  }

  Future<void> _loadProviders() async {
    setState(() {
      _step = SignupJourneyStep.providers;
      _error = null;
    });
    _watching ??= OnboardingController(
        service: widget.setup,
        userId: journey.userId,
        countryId: context.read<AuthProvider>().dbUser?.countryId,
        isCurrentUser: () => _active)
      ..addListener(_providerChanged);
    await _watching!.load(includeTaste: false);
  }

  Future<void> _chooseCountry() async {
    final owner = _watching!;
    final country = await showModalBottomSheet<Country>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => SignupCountryPickerSheet(
            countries: owner.countries, selected: owner.country));
    if (!mounted || !_active || country == null) return;
    _providerSearch.clear();
    owner.chooseCountry(country);
  }

  Future<void> _finish(
      {bool saveProviders = false,
      String? destination,
      bool resumeAction = false}) async {
    if (!_active || _busy || _editorBusy || _savingTitles.isNotEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    _watching?.setBusy(true);
    try {
      if (saveProviders) {
        await _watching!.persistWatching();
      }
      if (!mounted || !_active) return;
      final auth = context.read<AuthProvider>();
      final qualified = await auth.completeOnboarding();
      if (qualified && mounted) _analytics((a) => a.rewardUnlocked());
      if (!_active || auth.dbUser?.completedSetup != true) return;
      // Reload the library after mutations; profile refresh alone omits collections.
      await auth.refreshLibrary();
      if (!mounted || !_active) return;
      final target = destination ??
          (journey.action == 'watchlist' || _homeChoice == 'watchlist'
              ? '/watchlist'
              : journey.path);
      if (journey.diaryDraftId != null) {
        await GuestDiaryStore.instance.pause(journey.diaryDraftId!);
      }
      if (!mounted || !_active) return;
      GuestAccess.clear();
      if (resumeAction &&
          !const {'community', 'discussion'}.contains(journey.action)) {
        GuestAccess.destination = journey.path;
        GuestAccess.action = journey.action;
        GuestAccess.episodeId = journey.episodeId;
        GuestAccess.seasonNumber = journey.seasonNumber;
      }
      context.go(target);
    } catch (_) {
      if (_active) {
        setState(() => _error =
            'Your account is ready. Couldn’t finish setup - please try again.');
      }
    } finally {
      if (_active) {
        setState(() => _busy = false);
        _watching?.setBusy(false);
      }
    }
  }

  Widget _heading(String title, String body) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        Text(body, style: const TextStyle(fontSize: 16, height: 1.5)),
        const SizedBox(height: 24)
      ]);
  Widget _suggestionList() {
    final favourites = _favourites;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(
          journey.action == 'profile'
              ? 'Make yourself at home'
              : favourites
                  ? 'Any all-time favourites?'
                  : 'Anything else for later?',
          journey.action == 'guest-watchlist'
              ? 'Your picks are now in your account. Add a few more if something catches your eye.'
              : _title == null
                  ? (favourites
                      ? 'Your profile is ready. Tap a heart to add a favourite, or search for one you love.'
                      : 'Start your watchlist with a title that catches your eye.')
                  : favourites
                      ? '${journey.action == 'favorite' ? 'Your favourite' : 'Your rating'} for ${_title!.name} is saved. Tap a heart to add more favourites to your profile.'
                      : '${_title!.name} is on your watchlist. Here’s a mix of related titles and what’s trending.'),
      TextField(
          controller: _titleSearch,
          onChanged: (_) {
            setState(() {});
            ++_searchRevision;
            _searchDebounce?.cancel();
            _searchDebounce =
                Timer(const Duration(milliseconds: 350), _findTitles);
          },
          decoration: InputDecoration(
              labelText: favourites ? 'Find a favourite' : 'Find another title',
              prefixIcon: const Icon(Icons.search))),
      if (_titleSearch.text.trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [
          for (final shows in [false, true])
            ChoiceChip(
                label: Text(shows ? 'TV shows' : 'Films'),
                selected: _searchShows == shows,
                onSelected: (_) {
                  setState(() => _searchShows = shows);
                  _findTitles();
                })
        ])
      ],
      const SizedBox(height: 16),
      if (_suggestionsLoading) const Center(child: CircularProgressIndicator()),
      if (_suggestionError != null) ...[
        Text(_suggestionError!),
        TextButton(onPressed: _findTitles, child: const Text('Retry titles'))
      ],
      if (!_suggestionsLoading &&
          _suggestions.isEmpty &&
          _suggestionError == null)
        const Text(
            'No titles found. Try another search, or keep going for now.'),
      SignupTitleGrid(
          titles: _suggestions,
          saved: _added,
          pending: _savingTitles,
          favourites: favourites,
          onAdd: _add),
      const SizedBox(height: 24),
      FilledButton(
          onPressed: _savingTitles.isNotEmpty || _busy
              ? null
              : favourites
                  ? _finish
                  : _loadProviders,
          child: Text(favourites ? 'Done for now' : 'Continue')),
      TextButton(
          onPressed: _savingTitles.isNotEmpty || _busy ? null : _finish,
          child: const Text('Skip for now')),
      _optionalAvatar(),
    ]);
  }

  Widget _providerList() {
    final owner = _watching!;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading('Where do you watch?',
          'Add your streaming services to help find watch options for your watchlist. You can change these later.'),
      if (owner.error != null) Text(owner.error!, semanticsLabel: owner.error),
      OnboardingServicesStep(
          controller: owner,
          search: _providerSearch,
          onCountry: _chooseCountry),
      const SizedBox(height: 24),
      FilledButton(
          onPressed: _busy ||
                  owner.loading ||
                  owner.country == null ||
                  (owner.availabilityAlertsChoice == true &&
                      owner.selectedProviders.isEmpty) ||
                  owner.error != null
              ? null
              : () => _finish(saveProviders: true),
          child: const Text('Save services & open watchlist')),
      TextButton(
          onPressed: _busy ? null : _finish, child: const Text('Skip for now')),
    ]);
  }

  Widget _optionalAvatar() => TextButton(
      onPressed: _busy
          ? null
          : () => showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              useSafeArea: true,
              isScrollControlled: true,
              enableDrag: false,
              isDismissible: false,
              builder: (_) => const FractionallySizedBox(
                  heightFactor: .9, child: ChangeAvatarSheet())),
      child: const Text('Choose an avatar (optional)',
          textAlign: TextAlign.center));

  Widget _saved() {
    final invite = _watch?.externalInvite;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _heading(
          journey.action == 'episode'
              ? 'Episode marked watched'
              : 'That watch is in the diary',
          journey.action == 'episode'
              ? (journey.seasonNumber != null && journey.episodeNumber != null
                  ? '${_title!.name} · Season ${journey.seasonNumber} · Episode ${journey.episodeNumber}${journey.episodeTitle == null ? '' : ': ${journey.episodeTitle}'}. Marked watched.'
                  : 'Your selected episode of ${_title!.name} is marked watched.')
              : '${_title!.name} is saved. Your film history starts here.'),
      if (journey.action == 'episode') ...[
        SignupTitleContext(
            title:
                '${_title!.name}${journey.seasonNumber == null ? '' : ' · Season ${journey.seasonNumber}'}',
            isShow: true,
            posterWidth: 112,
            poster: _title!.poster),
        const SizedBox(height: 8),
      ],
      if (invite?.available == true)
        ExternalWatchInviteContent(
            invite: invite!,
            movieTitle: _title!.name,
            embedded: true,
            onDone: _finish),
      FilledButton(
          onPressed: _busy ? null : _finish,
          child: Text(_busy
              ? 'Finishing…'
              : journey.action == 'episode'
                  ? 'Back to the show'
                  : 'Back to the film')),
      _optionalAvatar(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final valid = _journey != null &&
        context.watch<AuthProvider>().dbUser?.id == _journey!.userId;
    if (!valid) {
      return Scaffold(
          appBar: AppBar(title: const FlixieWordmark()),
          body: const Center(child: Text('Open your title to continue.')));
    }
    Widget body;
    if (_loading || (journey.handoff && _error == null)) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _step == SignupJourneyStep.action) {
      body = _scroll(
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(_error!),
        FilledButton(onPressed: _start, child: const Text('Try again')),
        TextButton(
            onPressed: _finish, child: const Text('I’ll come back to this'))
      ]));
    } else if (_step == SignupJourneyStep.purpose) {
      body = _scroll(
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading('What brings you to Flixie?',
            'Your account is ready. Pick somewhere to start - you can explore the rest whenever you like.'),
        FilledButton.icon(
            onPressed: () {
              setState(() {
                _homeChoice = 'watchlist';
                _step = SignupJourneyStep.suggestions;
              });
              _loadSuggestions();
            },
            icon: const Icon(Icons.bookmark_border),
            label: const Text('Find something for my watchlist')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _homeChoice = 'favourites';
                _step = SignupJourneyStep.suggestions;
              });
              _loadSuggestions();
            },
            icon: const Icon(Icons.favorite_border),
            label: const Text('Add my favourites')),
        const SizedBox(height: 12),
        OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _homeChoice = 'log';
                _step = SignupJourneyStep.chooseLog;
              });
              _loadSuggestions();
            },
            icon: const Icon(Icons.edit_note),
            label: const Text('Log something I’ve watched')),
        TextButton(
            onPressed: _finish, child: const Text('I’ll explore for now'))
      ]));
    } else if (_step == SignupJourneyStep.chooseLog) {
      body = _scroll(
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading('What have you watched?',
            'Choose a film to add a date, rating or who you watched with.'),
        TextField(
            controller: _titleSearch,
            onChanged: (_) {
              ++_searchRevision;
              _searchDebounce?.cancel();
              _searchDebounce =
                  Timer(const Duration(milliseconds: 350), _findTitles);
            },
            decoration: const InputDecoration(
                labelText: 'Find a film', prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 16),
        if (_suggestionsLoading)
          const Center(child: CircularProgressIndicator()),
        if (_suggestionError != null) Text(_suggestionError!),
        SignupTitleGrid(
            titles: _suggestions.where((t) => !t.isShow).toList(),
            saved: const {},
            pending: const {},
            favourites: false,
            selectForLog: true,
            onAdd: (title) {
              setState(() {
                _journey = SignupJourney(
                    userId: journey.userId,
                    action: 'log',
                    path: '/movies/${title.id}',
                    title: title.name);
                _title = title;
                _step = SignupJourneyStep.action;
              });
              _start();
            }),
        TextButton(onPressed: _finish, child: const Text('Skip for now')),
      ]));
    } else if (_step == SignupJourneyStep.action && _guestDraft != null) {
      body = _scroll(GuestDiaryEditor(
          draft: _guestDraft!,
          signedIn: true,
          onBusyChanged: (busy) {
            if (mounted) setState(() => _editorBusy = busy);
          },
          onContinue: (draft) async {
            if (!_active || draft.owner != journey.userId) {
              throw StateError('Account changed');
            }
            MovieWatchEntry? saved;
            if (draft.logWatch) {
              saved = await widget.service.log(
                  journey.userId,
                  LogMovieWatchRequest(
                      movieId: draft.movieId,
                      draftId: draft.id,
                      watchedAt: draft.date.isEmpty
                          ? null
                          : DateTime.parse(draft.date)
                              .toUtc()
                              .toIso8601String(),
                      rating: draft.rating?.toDouble(),
                      recommended: draft.recommended,
                      notes: draft.note.isEmpty ? null : draft.note));
            } else {
              await widget.service.rate(
                  journey,
                  draft.rating!,
                  draft.recommended == null
                      ? null
                      : draft.recommended!
                          ? 'recommend'
                          : 'not-recommend');
            }
            if (!_active) throw StateError('Account changed');
            await GuestDiaryStore.instance.finish(draft.id, journey.userId);
            if (!_active) return;
            _changed();
            if (draft.logWatch) {
              _analytics((a) => a.watchLogged(
                  contentType: 'movie',
                  contentId: draft.movieId,
                  source: 'guest_diary'));
            } else {
              _analytics((a) => a.ratingAdded(
                  contentType: 'movie',
                  contentId: draft.movieId,
                  source: 'guest_diary'));
            }
            setState(() {
              _editorBusy = false;
              _watch = saved;
              _step = draft.logWatch
                  ? SignupJourneyStep.saved
                  : SignupJourneyStep.suggestions;
            });
            if (!draft.logWatch) unawaited(_loadSuggestions());
          }));
    } else if (_step == SignupJourneyStep.action &&
        journey.action == 'review') {
      body = WriteReviewSheet(
          embedded: true,
          onBusyChanged: (busy) {
            if (mounted) setState(() => _editorBusy = busy);
          },
          onClose: _finish,
          movieId: journey.isShow ? null : journey.mediaId,
          showId: journey.isShow ? journey.mediaId : null,
          userId: journey.userId,
          mediaTitle: _title!.name,
          onSubmitted: _reviewSaved);
    } else if ((_step == SignupJourneyStep.action && journey.action == 'log') ||
        _step == SignupJourneyStep.watch) {
      body = RewatchLogSheet(
          embedded: true,
          onBusyChanged: (busy) {
            if (mounted) setState(() => _editorBusy = busy);
          },
          onClose: _finish,
          movieTitle: _title!.name,
          initialRating: _review?.rating.toDouble(),
          initialRecommended: _review?.recommended,
          loadFriends: () async =>
              (await FriendService.getFriends(journey.userId)).friendships,
          onDetailsChanged: (details) => _details = details,
          onSubmit: _log);
    } else if (_step == SignupJourneyStep.action) {
      body = _scroll(TitleRatingEditor(
          title: 'How was ${_title!.name}?',
          subtitle: journey.isShow
              ? 'Choose a score for the overall series.'
              : 'Your score, your call. What did you think?',
          onBusyChanged: (busy) {
            if (mounted) setState(() => _editorBusy = busy);
          },
          onSave: _rate));
    } else if (_step == SignupJourneyStep.suggestions) {
      body = _scroll(_suggestionList());
    } else if (_step == SignupJourneyStep.providers) {
      body = _scroll(_providerList());
    } else if (_step == SignupJourneyStep.reviewSaved) {
      body = _scroll(
          Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _heading('Your review is posted',
            'Your thoughts on ${_title!.name}, saved.'),
        if (!journey.isShow) ...[
          const Text(
              'Want to add this watch to your diary? Add a date and who you watched with. If they’re new to Flixie, you can copy their invite after saving.'),
          const SizedBox(height: 24),
          FilledButton(
              onPressed: _busy ? null : _openReviewDiary,
              child: const Text('Add date & watched with'))
        ],
        TextButton(
            onPressed: _busy ? null : _finish,
            child: const Text('Done for now')),
        _optionalAvatar(),
      ]));
    } else {
      body = _scroll(_saved());
    }
    return PopScope(
        canPop: false,
        child: Scaffold(
            resizeToAvoidBottomInset: false,
            appBar: AppBar(
                automaticallyImplyLeading: false,
                title: const FlixieWordmark(),
                actions: [
                  IconButton(
                    tooltip: _step == SignupJourneyStep.action ||
                            _step == SignupJourneyStep.watch
                        ? 'Skip for now'
                        : 'Close',
                    onPressed: _busy ||
                            _editorBusy ||
                            _loading ||
                            _savingTitles.isNotEmpty
                        ? null
                        : _finish,
                    icon: const Icon(Icons.close),
                  )
                ]),
            body: SafeArea(
                child: Column(children: [
              if (_error != null && _step != SignupJourneyStep.action)
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, semanticsLabel: _error)),
              if (_title != null &&
                  (_step == SignupJourneyStep.action ||
                      _step == SignupJourneyStep.watch))
                Align(
                    alignment: Alignment.topCenter,
                    heightFactor: 1,
                    child: ConstrainedBox(
                        constraints: BoxConstraints(
                            maxWidth: _step == SignupJourneyStep.action &&
                                    journey.action == 'review'
                                ? 560
                                : _step == SignupJourneyStep.action &&
                                        journey.action == 'rate'
                                    ? 640
                                    : double.infinity),
                        child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                            child: SignupTitleContext(
                                title: _title!.name,
                                isShow: _title!.isShow,
                                poster: _title!.poster)))),
              Expanded(child: body)
            ]))));
  }

  Widget _scroll(Widget child) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  24,
                  24,
                  24,
                  24 +
                      MediaQuery.viewInsetsOf(context)
                          .bottom
                          .clamp(0.0, double.infinity)
                          .toDouble()),
              child: child)));
}
