import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/home/data/recommendation_service.dart';
import 'package:flixie_app/features/library_import/data/library_import_session.dart';
import 'package:flixie_app/features/library_import/presentation/library_import_screen.dart';
import 'package:flixie_app/models/country.dart';
import 'package:flixie_app/models/movie_short.dart';
import '../../data/setup_service.dart';
import '../controllers/onboarding_controller.dart';
import 'signup_screen.dart' show SignupCountryPickerSheet;
import 'setup_profile_favourites.dart';
import '../widgets/onboarding/onboarding_frame.dart';
import '../widgets/onboarding/onboarding_footer.dart';
import '../widgets/onboarding/onboarding_taste_step.dart';
import '../widgets/onboarding/onboarding_services_step.dart';
import '../widgets/onboarding/onboarding_picks_step.dart';
import '../widgets/onboarding/onboarding_communities_step.dart';
import '../widgets/onboarding/onboarding_preferences_step.dart';

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
  OnboardingController? _controller;
  OnboardingController get controller => _controller!;
  final _search = TextEditingController();
  final _providerSearch = TextEditingController();
  final _scroll = ScrollController();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    final user = auth.dbUser;
    if (user?.id == _controller?.userId) return;
    _controller?.dispose();
    _controller = null;
    _search.clear();
    _providerSearch.clear();
    if (user == null) return;
    final controller = OnboardingController(
        service: widget.service,
        userId: user.id,
        countryId: user.countryId,
        isCurrentUser: () => mounted && auth.dbUser?.id == user.id);
    _controller = controller;
    context.read<AnalyticsController?>()?.onboardingStarted();
    controller.start();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _search.dispose();
    _providerSearch.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _move(int step) {
    controller.move(step);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _pickCountry() async {
    final owner = controller;
    final selected = await showModalBottomSheet<Country>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => SignupCountryPickerSheet(
            countries: owner.countries, selected: owner.country));
    if (!owner.active || selected == null) return;
    _providerSearch.clear();
    owner.chooseCountry(selected);
  }

  Future<void> _finish(String destination) async {
    final owner = controller;
    await owner.run(() async {
      final auth = context.read<AuthProvider>();
      final analytics = context.read<AnalyticsController?>();
      await auth.refreshDbUser();
      if (!owner.active) return;
      final qualified = await auth.completeOnboarding();
      if (!owner.active) return;
      RecommendationService.invalidateCache(userId: owner.userId);
      await analytics?.tasteProfileCompleted(
          signalCount: owner.taste.length + owner.genres.length);
      if (!owner.active) return;
      if (qualified) await analytics?.rewardUnlocked();
      if (mounted && owner.active) {
        context.go(destination == '/' ? widget.returnTo ?? '/' : destination);
      }
    });
  }

  Future<void> _import() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;
    final importController = context
        .read<LibraryImportSession>()
        .forUser(userId, isCurrentUser: () => auth.dbUser?.id == userId);
    await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
            builder: (_) => LibraryImportScreen(controller: importController)));
  }

  Future<void> _add(SetupTitle title) async {
    final owner = controller;
    if (!await owner.add(title) || !mounted || !owner.active) return;
    context.read<AnalyticsController?>()?.watchlistAdded(
        contentType: title.isShow ? 'show' : 'movie',
        contentId: title.id,
        source: 'onboarding');
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${title.name} added to your watchlist')));
  }

  Future<void> _advance() async {
    final owner = controller;
    final previousStep = owner.step;
    switch (owner.step) {
      case 0:
        await owner.saveTaste();
      case 1:
        if (owner.country == null) {
          if (owner.countries.isNotEmpty) await _pickCountry();
        } else {
          await owner.saveWatching();
        }
      case 2:
      case 3:
      case 4:
        _move(owner.step + 1);
      default:
        if (await owner.joinCommunities() && owner.active) {
          await _finish('/social?tab=communities');
        }
    }
    if (owner.active && owner.step != previousStep && _scroll.hasClients) {
      _scroll.jumpTo(0);
    }
  }

  void _skip() {
    final owner = controller;
    switch (owner.step) {
      case 0:
        owner.saveTaste(skip: true).then((_) {
          if (mounted && owner.active && _scroll.hasClients) _scroll.jumpTo(0);
        });
      case 1:
        _move(2);
      case 2:
      case 3:
        _move(owner.step + 1);
      default:
        owner.clearCommunities();
        _finish('/');
    }
  }

  Widget _favourites() {
    final owner = controller;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 24),
      if (owner.taste.isEmpty)
        TextButton(
            onPressed: owner.busy ? null : () => _finish('/profile'),
            child:
                const Text('Make your profile more you · choose favourites')),
      if (owner.taste.isNotEmpty)
        SetupProfileFavourites(
            key: ValueKey('signup-favourites-${owner.userId}'),
            enabled: !owner.busy,
            titles: owner.taste.values.toList(),
            save: (title) async {
              if (!owner.active) throw StateError('Setup account changed');
              await owner.service.addProfileFavourite(owner.userId, title);
            },
            onSaved: () {
              if (!owner.active) return;
              owner.favouriteSaved();
              context.read<AuthProvider>().markActivityChanged();
              RecommendationService.invalidateCache(userId: owner.userId);
            },
            onBusyChanged: (busy) {
              if (!owner.active) return;
              owner.setBusy(busy);
              if (!busy && owner.favouritesAdded) owner.loadPicks();
            }),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final owner = _controller;
    if (owner == null) return const SizedBox.shrink();
    return ListenableBuilder(
        listenable: owner,
        builder: (context, _) => OnboardingFrame(
              controller: owner,
              scroll: _scroll,
              onBack: () => _move(owner.step - 1),
              footer: OnboardingFooter(
                  controller: owner, onAdvance: _advance, onSkip: _skip),
              entryActions: [
                if (widget.returnTo != null)
                  TextButton.icon(
                      onPressed:
                          owner.busy ? null : () => _finish(widget.returnTo!),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Go straight to your invitation')),
                if (owner.referrer != null)
                  TextButton(
                      onPressed: owner.busy
                          ? null
                          : () => owner.run(() async {
                                final id = await owner.service
                                    .friendId(owner.referrer!);
                                if (!owner.active) return;
                                owner.setBusy(false);
                                await _finish(id == null
                                    ? '/social?tab=people'
                                    : '/friends/$id');
                              }),
                      child: Text('Find @${owner.referrer} first')),
              ],
              child: switch (owner.step) {
                0 => OnboardingTasteStep(
                    controller: owner, search: _search, onImport: _import),
                1 => OnboardingServicesStep(
                    controller: owner,
                    search: _providerSearch,
                    onCountry: _pickCountry),
                2 => OnboardingPicksStep(
                    controller: owner, onFinish: _finish, onAdd: _add),
                3 => _favourites(),
                4 => OnboardingPreferencesStep(controller: owner),
                _ => OnboardingCommunitiesStep(
                    controller: owner, onFinish: _finish),
              },
            ));
  }
}
