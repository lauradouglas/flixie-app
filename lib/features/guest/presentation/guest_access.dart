import 'package:uuid/uuid.dart';
import '../data/guest_diary_store.dart';
import '../models/guest_diary_draft.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../watchlist/data/guest_watchlist_store.dart';
import '../../authentication/data/setup_service.dart';
import 'package:flixie_app/features/authentication/models/signup_journey.dart';
import 'widgets/cinema_account_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// A single explicit guest action, retained only for the current app session.
class GuestAccess {
  static final _savingPicks = <String>{};
  static SignupJourney? journey;
  static String? diaryDraftId;
  static int? episodeId, seasonNumber, episodeNumber;
  static String? episodeTitle, poster;
  static SignupJourney? claimJourney(String userId) {
    if (journey?.userId == userId) return journey;
    if (!awaitingAccount || !SignupJourney.supports(action, destination)) {
      return null;
    }
    journey = SignupJourney(
        userId: userId,
        action: action!,
        path: destination!,
        title: bookmarkTitle,
        diaryDraftId: diaryDraftId,
        episodeId: episodeId,
        seasonNumber: seasonNumber,
        episodeNumber: episodeNumber,
        episodeTitle: episodeTitle);
    awaitingAccount = false;
    return journey;
  }

  static void beginGeneralSignup(String source) {
    clear();
    destination = source == 'profile' ? '/profile' : '/';
    action = source == 'profile' ? 'profile' : 'home';
    awaitingAccount = true;
  }

  static String? destination;
  static String? action;
  static bool awaitingAccount = false;
  static String? bookmarkTitle;
  // Only this title may be used before optional setup is complete.
  static String? bookmarkSetupPath;

  static String? get pendingBookmarkPath => action == 'watchlist' &&
          RegExp(r'^/(movies|shows)/[0-9]+$').hasMatch(destination ?? '')
      ? destination
      : null;

  static bool allowBookmarkBeforeSetup(String path) {
    final pending = pendingBookmarkPath;
    if (pending != null && awaitingAccount) {
      bookmarkSetupPath = pending;
      awaitingAccount = false;
    }
    return bookmarkSetupPath != null && path == bookmarkSetupPath;
  }

  static void clear() {
    journey = null;
    diaryDraftId = null;
    episodeId = null;
    seasonNumber = null;
    episodeNumber = null;
    episodeTitle = null;
    poster = null;
    destination = null;
    action = null;
    awaitingAccount = false;
    bookmarkTitle = null;
    bookmarkSetupPath = null;
  }

  static String? takeAction(String path) {
    if (destination != path) return null;
    final value = action;
    final setupPath = bookmarkSetupPath;
    clear();
    bookmarkSetupPath = setupPath;
    return value;
  }

  static bool isPublicPath(String path) =>
      [
        '/',
        '/search',
        '/guest-watchlist',
        '/guest-diary',
        '/profile',
        '/welcome',
        '/why-flixie',
        '/around-flixie',
        '/help-support',
        '/about-credits',
        '/play',
        '/play/pip-pairs',
        '/play/space-premiere',
        '/play/popcorn-catch'
      ].contains(path) ||
      RegExp(r'^/(movies|shows|people|collections)/[0-9]+$').hasMatch(path) ||
      RegExp(r'^/watch-invites/[A-Za-z0-9_-]{43}$').hasMatch(path);

  static Future<bool> require(
    BuildContext context, {
    String title = 'Make Flixie yours',
    String message =
        'Create an account to save your favourites and connect with others.',
    String? path,
    String? intent,
    String? mediaTitle,
    String? mediaPoster,
    int? selectedEpisodeId,
    int? selectedSeasonNumber,
    int? selectedEpisodeNumber,
    String? selectedEpisodeTitle,
  }) async {
    if (context.read<AuthProvider>().dbUser != null) return true;
    final target = path ?? GoRouterState.of(context).uri.toString();
    if ((intent == 'rate' || intent == 'log') &&
        RegExp(r'^/movies/[0-9]+$').hasMatch(target)) {
      try {
        final movieId = int.parse(target.split('/').last);
        final drafts = await GuestDiaryStore.instance.list(null);
        final existing = drafts
            .where(
                (d) => d.movieId == movieId && d.logWatch == (intent == 'log'))
            .firstOrNull;
        final draft = existing ??
            GuestDiaryDraft(
                id: const Uuid().v4(),
                movieId: movieId,
                title: mediaTitle ?? 'Your film',
                poster: mediaPoster,
                logWatch: intent == 'log');
        await GuestDiaryStore.instance.save(draft);
        if (context.mounted) context.push('/guest-diary?draft=${draft.id}');
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content:
                  Text('Couldn’t open your diary draft. Please try again.')));
        }
      }
      return false;
    }
    if (intent == 'watchlist' &&
        RegExp(r'^/(movies|shows)/[0-9]+$').hasMatch(target)) {
      if (!_savingPicks.add(target)) return false;
      try {
        final added = await GuestWatchlistStore.instance.toggle(SetupTitle(
            int.parse(target.split('/').last),
            mediaTitle ?? 'Untitled',
            mediaPoster,
            isShow: target.startsWith('/shows/')));
        if (context.mounted) {
          if (added) {
            final preferences = await SharedPreferences.getInstance();
            if (!context.mounted) return false;
            const explainedKey = 'guest_watchlist_explained_v1';
            if (preferences.getBool(explainedKey) == true) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                    '${mediaTitle ?? 'Your pick'} saved to your watchlist'),
                persist: false,
                action: SnackBarAction(
                    label: 'View watchlist',
                    onPressed: () {
                      if (context.mounted) context.push('/guest-watchlist');
                    }),
              ));
              return false;
            }
            // Explanatory feedback is offered once, never a limit on saving.
            await preferences.setBool(explainedKey, true);
            if (!context.mounted) return false;
            ModalRoute<dynamic>? confirmationRoute;
            final viewWatchlist = await showFlixiePromptSheet<bool>(
              context: context,
              builder: (sheetContext) {
                confirmationRoute = ModalRoute.of(sheetContext);
                return FlixiePromptSheetContent(
                  title: const Text('Added to your watchlist'),
                  content: Text(
                    '${mediaTitle ?? 'Your pick'} is saved on this device. Keep browsing and add a few more whenever you like.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      child: const Text('Keep browsing'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      child: const Text('View watchlist'),
                    ),
                  ],
                );
              },
            );
            // A pop result arrives before the sheet's reverse animation ends.
            // Finish that transition before starting the next page transition.
            await confirmationRoute?.completed;
            if (viewWatchlist == true && context.mounted) {
              context.push('/guest-watchlist');
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Removed from your picks.')));
          }
        }
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Couldn’t save your pick. Please try again.')));
        }
      } finally {
        _savingPicks.remove(target);
      }
      return false;
    }
    final contextualTitle = switch (intent) {
      'rate' => 'Your take on ${mediaTitle ?? 'this title'}',
      'review' => 'Review ${mediaTitle ?? 'this title'}',
      'log' => 'Log your watch of ${mediaTitle ?? 'this title'}',
      'favorite' => 'Keep ${mediaTitle ?? 'your favourite'} on your profile',
      'season' => 'Keep your progress in ${mediaTitle ?? 'this show'}',
      'episode' => 'Keep your place in ${mediaTitle ?? 'this show'}',
      _ => title,
    };
    final contextualMessage = switch (intent) {
      'rate' =>
        'Create an account, then choose your score and whether you’d recommend it.',
      'review' =>
        'Create an account, then write your review. Your thoughts, in your own words.',
      'log' =>
        'Create an account, then add this watch to your diary - with a date, rating and who you watched with.',
      'favorite' =>
        'Create an account and we’ll add it to your favourites. Add a few more afterwards if you like.',
      'season' =>
        'Create an account, then confirm which released episodes you’ve watched.',
      'episode' =>
        'Create an account and we’ll mark this episode watched, so you know where to pick up.',
      _ => message,
    };
    final isBookmark = intent == 'watchlist';
    final choice = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: false,
        backgroundColor: context.colors.background,
        builder: (sheet) => CinemaAccountSheet(
              title: isBookmark && mediaTitle != null
                  ? 'Keep $mediaTitle on your watchlist'
                  : contextualTitle,
              message: isBookmark
                  ? 'Create an account and we’ll save it for your next watch.'
                  : contextualMessage,
              signupLabel: switch (intent) {
                'watchlist' => 'Create account & save',
                'rate' => 'Create account & rate',
                'review' => 'Create account & review',
                'log' => 'Create account & log',
                'episode' => 'Create account & track',
                _ => 'Create account',
              },
              showReturnNote: intent != null,
              onChoice: (choice) => Navigator.pop(sheet, choice),
            ));
    if (choice != null && context.mounted) {
      clear();
      bookmarkTitle = mediaTitle;
      poster = mediaPoster;
      episodeNumber = selectedEpisodeNumber;
      episodeTitle = selectedEpisodeTitle;
      episodeId = selectedEpisodeId;
      seasonNumber = selectedSeasonNumber;
      destination = isPublicPath(Uri.parse(target).path)
          ? Uri.parse(target).path
          : target;
      action = intent ??
          (destination?.startsWith('/community/posts/') == true
              ? 'discussion'
              : null);
      awaitingAccount = true;
      context.go('/auth/$choice');
    }
    return false;
  }
}
