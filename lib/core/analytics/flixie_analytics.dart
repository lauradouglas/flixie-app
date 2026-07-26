import 'package:flutter/foundation.dart';

import 'analytics_backend.dart';
import 'analytics_consent.dart';

abstract interface class FlixieAnalytics {
  Future<void> signupStarted();
  Future<void> signupCompleted();
  Future<void> onboardingStarted();
  Future<void> favouriteSelected({required int favouriteCount});
  Future<void> onboardingCompleted({required int favouriteCount});
  Future<void> watchlistItemAdded({required String source});
  Future<void> watchlistItemRemoved({required String source});
  Future<void> movieFavourited();
  Future<void> movieUnfavourited();
  Future<void> showFavourited();
  Future<void> showUnfavourited();
  Future<void> movieAddedToWatchlist();
  Future<void> movieRemovedFromWatchlist();
  Future<void> showAddedToWatchlist();
  Future<void> showRemovedFromWatchlist();
  Future<void> movieAddedToList();
  Future<void> movieRemovedFromList();
  Future<void> showAddedToList();
  Future<void> showRemovedFromList();
  Future<void> ratingSaved({required String source});
  Future<void> friendRequestSent();
  Future<void> friendConnected();
  Future<void> watchInvitationSent({required String recipientType});
  Future<void> watchInvitationAccepted({required String recipientType});
  Future<void> watchScheduled({required String recipientType});
  Future<void> referralInviteShared();
  Future<void> referralQualified();
  Future<void> rewardUnlocked();
  Future<void> tasteMatchViewed();
  Future<void> matchedMovieInvitationSent();
}

class AnalyticsController extends ChangeNotifier implements FlixieAnalytics {
  AnalyticsController({
    required AnalyticsBackend backend,
    required AnalyticsConsentStore consentStore,
  })  : _backend = backend,
        _consentStore = consentStore;

  static const approvedEvents = <String, Set<String>>{
    'signup_started': {},
    'signup_completed': {},
    'onboarding_started': {},
    'favourite_selected': {'favourite_count'},
    'onboarding_completed': {'favourite_count'},
    'watchlist_item_added': {'source'},
    'watchlist_item_removed': {'source'},
    'movie_favourited': {},
    'movie_unfavourited': {},
    'show_favourited': {},
    'show_unfavourited': {},
    'movie_added_to_watchlist': {},
    'movie_removed_from_watchlist': {},
    'show_added_to_watchlist': {},
    'show_removed_from_watchlist': {},
    'movie_added_to_list': {},
    'movie_removed_from_list': {},
    'show_added_to_list': {},
    'show_removed_from_list': {},
    'rating_saved': {'source'},
    'friend_request_sent': {},
    'friend_connected': {},
    'watch_invitation_sent': {'recipient_type'},
    'watch_invitation_accepted': {'recipient_type'},
    'watch_scheduled': {'recipient_type'},
    'referral_invite_shared': {},
    'referral_qualified': {},
    'reward_unlocked': {},
    'taste_match_viewed': {},
    'matched_movie_invitation_sent': {},
  };

  static const allowedSources = {
    'home',
    'movie_detail',
    'show_detail',
    'watchlist',
  };
  static const allowedRecipientTypes = {'friend', 'group'};

  final AnalyticsBackend _backend;
  final AnalyticsConsentStore _consentStore;
  AnalyticsConsent _consent = AnalyticsConsent.unknown;
  bool _initialized = false;
  final Set<String> _loggedOnce = {};

  AnalyticsConsent get consent => _consent;
  bool get isInitialized => _initialized;
  bool get isEnabled => _consent == AnalyticsConsent.accepted;

  Future<void> initialize() async {
    // Native configuration also defaults collection to false. Explicitly keep
    // it disabled before reading the saved choice.
    await _safely(() => _backend.setCollectionEnabled(false));
    try {
      _consent = await _consentStore.read();
    } catch (_) {
      _consent = AnalyticsConsent.unknown;
    }
    if (_consent == AnalyticsConsent.accepted) {
      await _safely(() => _backend.setCollectionEnabled(true));
    }
    _initialized = true;
  }

  Future<void> allow() => _setConsent(AnalyticsConsent.accepted);
  Future<void> decline() => _setConsent(AnalyticsConsent.declined);

  Future<void> _setConsent(AnalyticsConsent value) async {
    _consent = value;
    await _safely(() => _backend.setCollectionEnabled(isEnabled));
    try {
      await _consentStore.write(value);
    } catch (_) {
      // A storage failure must not interrupt the user's current action.
    }
    notifyListeners();
  }

  Future<void> _log(String name, [Map<String, Object>? parameters]) async {
    if (!isEnabled || !approvedEvents.containsKey(name)) return;
    final allowedKeys = approvedEvents[name]!;
    final safeParameters = parameters == null
        ? null
        : Map<String, Object>.fromEntries(
            parameters.entries
                .where((entry) => allowedKeys.contains(entry.key)),
          );
    await _safely(() => _backend.logEvent(name, safeParameters));
  }

  Future<void> _logOnce(String name, [Map<String, Object>? parameters]) async {
    if (_loggedOnce.contains(name)) return;
    if (!isEnabled) return;
    _loggedOnce.add(name);
    await _log(name, parameters);
  }

  Future<void> _safely(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      // Analytics must never block or fail a product action.
    }
  }

  String _safeSource(String source) =>
      allowedSources.contains(source) ? source : 'home';

  String _safeRecipientType(String type) =>
      allowedRecipientTypes.contains(type) ? type : 'friend';

  @override
  Future<void> signupStarted() => _logOnce('signup_started');
  @override
  Future<void> signupCompleted() => _logOnce('signup_completed');

  @override
  Future<void> referralInviteShared() => _log('referral_invite_shared');

  @override
  Future<void> referralQualified() => _logOnce('referral_qualified');

  @override
  Future<void> rewardUnlocked() => _logOnce('reward_unlocked');

  @override
  Future<void> tasteMatchViewed() => _log('taste_match_viewed');

  @override
  Future<void> matchedMovieInvitationSent() =>
      _log('matched_movie_invitation_sent');

  @override
  Future<void> onboardingStarted() => _logOnce('onboarding_started');
  @override
  Future<void> favouriteSelected({required int favouriteCount}) => _log(
      'favourite_selected', {'favourite_count': favouriteCount.clamp(1, 5)});
  @override
  Future<void> onboardingCompleted({required int favouriteCount}) => _logOnce(
        'onboarding_completed',
        {'favourite_count': favouriteCount.clamp(1, 5)},
      );
  @override
  Future<void> watchlistItemAdded({required String source}) =>
      _log('watchlist_item_added', {'source': _safeSource(source)});
  @override
  Future<void> watchlistItemRemoved({required String source}) =>
      _log('watchlist_item_removed', {'source': _safeSource(source)});
  @override
  Future<void> movieFavourited() => _log('movie_favourited');
  @override
  Future<void> movieUnfavourited() => _log('movie_unfavourited');
  @override
  Future<void> showFavourited() => _log('show_favourited');
  @override
  Future<void> showUnfavourited() => _log('show_unfavourited');
  @override
  Future<void> movieAddedToWatchlist() => _log('movie_added_to_watchlist');
  @override
  Future<void> movieRemovedFromWatchlist() =>
      _log('movie_removed_from_watchlist');
  @override
  Future<void> showAddedToWatchlist() => _log('show_added_to_watchlist');
  @override
  Future<void> showRemovedFromWatchlist() =>
      _log('show_removed_from_watchlist');
  @override
  Future<void> movieAddedToList() => _log('movie_added_to_list');
  @override
  Future<void> movieRemovedFromList() => _log('movie_removed_from_list');
  @override
  Future<void> showAddedToList() => _log('show_added_to_list');
  @override
  Future<void> showRemovedFromList() => _log('show_removed_from_list');
  @override
  Future<void> ratingSaved({required String source}) =>
      _log('rating_saved', {'source': _safeSource(source)});
  @override
  Future<void> friendRequestSent() => _log('friend_request_sent');
  @override
  Future<void> friendConnected() => _log('friend_connected');
  @override
  Future<void> watchInvitationSent({required String recipientType}) => _log(
        'watch_invitation_sent',
        {'recipient_type': _safeRecipientType(recipientType)},
      );
  @override
  Future<void> watchInvitationAccepted({required String recipientType}) => _log(
        'watch_invitation_accepted',
        {'recipient_type': _safeRecipientType(recipientType)},
      );
  @override
  Future<void> watchScheduled({required String recipientType}) => _log(
        'watch_scheduled',
        {'recipient_type': _safeRecipientType(recipientType)},
      );
}
