import 'package:flutter/foundation.dart';

import 'analytics_backend.dart';
import 'analytics_consent.dart';
import 'detail_source.dart';
import 'recommendation_attribution.dart';
import '../utils/app_logger.dart';

/// Firebase event names use lowercase_snake_case and describe completed
/// product actions. See docs/analytics.md for the canonical event contract.
class AnalyticsController extends ChangeNotifier {
  AnalyticsController({
    required AnalyticsBackend backend,
    required AnalyticsConsentStore consentStore,
  })  : _backend = backend,
        _consentStore = consentStore;

  static const approvedEvents = <String, Set<String>>{
    'signup_started': {},
    'signup_completed': {},
    'taste_signal_added': {'signal_type'},
    'taste_profile_completed': {'signal_count'},
    'content_opened': {'content_type', 'content_id', 'genre', 'source'},
    'person_opened': {
      'person_id',
      'source',
      'parent_content_id',
      'parent_content_type'
    },
    'watchlist_added': {'content_type', 'content_id', 'source'},
    'watch_logged': {
      'content_type',
      'content_id',
      'source',
      'watch_plan_id',
      'plan_type',
      'participant_count'
    },
    'rating_added': {
      'content_type',
      'content_id',
      'source',
      'recommendation_source',
      'position',
      'recommendation_algorithm',
      'recommendation_version',
      'recommendation_reason',
      'predicted_score'
    },
    'review_created': {'content_type', 'content_id', 'source'},
    'recommendation_given': {'content_type', 'content_id', 'source'},
    'recommendation_impression': {
      'content_type',
      'content_id',
      'recommendation_source',
      'position',
      'recommendation_algorithm',
      'recommendation_version',
      'recommendation_reason',
      'predicted_score'
    },
    'recommendation_opened': {
      'content_type',
      'content_id',
      'recommendation_source',
      'position',
      'recommendation_algorithm',
      'recommendation_version',
      'recommendation_reason',
      'predicted_score'
    },
    'recommendation_saved': {
      'content_type',
      'content_id',
      'recommendation_source',
      'position',
      'recommendation_algorithm',
      'recommendation_version',
      'recommendation_reason',
      'predicted_score'
    },
    'recommendation_watched': {
      'content_type',
      'content_id',
      'recommendation_source',
      'position',
      'recommendation_algorithm',
      'recommendation_version',
      'recommendation_reason',
      'predicted_score'
    },
    'friend_invite_sent': {'invite_method', 'source'},
    'friend_invite_opened': {'invite_method', 'source'},
    'friend_invite_converted': {'invite_method', 'source'},
    'friend_connected': {'source'},
    'group_created': {'group_type', 'source'},
    'group_joined': {'group_type', 'source'},
    'group_message_sent': {'group_type', 'source'},
    'watch_plan_created': {
      'watch_plan_id',
      'content_type',
      'content_id',
      'plan_type',
      'participant_count',
      'source'
    },
    'watch_plan_accepted': {
      'watch_plan_id',
      'content_type',
      'content_id',
      'plan_type',
      'participant_count',
      'source'
    },
    'watch_plan_scheduled': {
      'watch_plan_id',
      'content_type',
      'content_id',
      'plan_type',
      'participant_count',
      'source'
    },
    'watch_plan_completed': {
      'watch_plan_id',
      'content_type',
      'content_id',
      'plan_type',
      'participant_count',
      'source'
    },
    'share_created': {'content_type', 'content_id', 'share_type', 'source'},
    'shared_link_opened': {
      'content_type',
      'content_id',
      'share_type',
      'source'
    },
    'shared_link_signup': {'share_type', 'source'},
    // Existing privacy-safe product events retained where no canonical event
    // above represents the action.
    'onboarding_started': {},
    'watchlist_removed': {'content_type', 'content_id', 'source'},
    'content_favourited': {'content_type', 'content_id', 'source'},
    'content_unfavourited': {'content_type', 'content_id', 'source'},
    'content_list_added': {'content_type', 'content_id', 'source'},
    'content_list_removed': {'content_type', 'content_id', 'source'},
    'reward_unlocked': {},
    'taste_match_viewed': {},
  };

  static final allowedSources = {
    ...DetailSource.values.map((source) => source.value),
    // Non-detail event origins retained for existing funnels.
    'home',
    'recommendations',
    'friends_activity',
    'profile',
    'social',
    'settings',
    'movie_detail',
    'show_detail',
    'signup',
  };
  static const allowedContentTypes = {'movie', 'show'};
  static const allowedInviteMethods = {'referral_link', 'profile', 'unknown'};
  static const allowedGroupTypes = {'public', 'private', 'unknown'};
  static const allowedPlanTypes = {'friend', 'group'};
  static const allowedShareTypes = {
    'movie',
    'show',
    'profile',
    'list',
    'review',
    'watch_plan'
  };

  final AnalyticsBackend _backend;
  final AnalyticsConsentStore _consentStore;
  AnalyticsConsent _consent = AnalyticsConsent.unknown;
  bool _initialized = false;
  final Set<String> _loggedOnce = {};
  final Set<String> _impressions = {};
  String? _lastScreenName;
  bool _pendingReferralLinkOpen = false;
  bool _referralLinkOpenLogged = false;

  AnalyticsConsent get consent => _consent;
  bool get isInitialized => _initialized;
  bool get isEnabled => _consent == AnalyticsConsent.accepted;

  Future<void> initialize() async {
    await _safely(() => _backend.setCollectionEnabled(false));
    try {
      _consent = await _consentStore.read();
    } catch (_) {
      _consent = AnalyticsConsent.unknown;
    }
    if (isEnabled) await _safely(() => _backend.setCollectionEnabled(true));
    _initialized = true;
  }

  Future<void> allow() => _setConsent(AnalyticsConsent.accepted);
  Future<void> decline() => _setConsent(AnalyticsConsent.declined);

  Future<void> _setConsent(AnalyticsConsent value) async {
    _consent = value;
    await _safely(() => _backend.setCollectionEnabled(isEnabled));
    try {
      await _consentStore.write(value);
    } catch (_) {}
    notifyListeners();
    if (value == AnalyticsConsent.accepted && _pendingReferralLinkOpen) {
      await referralLinkOpened();
    } else if (value == AnalyticsConsent.declined) {
      _pendingReferralLinkOpen = false;
    }
  }

  Future<void> logEvent(String name, [Map<String, Object>? parameters]) async {
    if (!isEnabled || !approvedEvents.containsKey(name)) return;
    final allowedKeys = approvedEvents[name]!;
    final safe = parameters == null
        ? null
        : Map<String, Object>.fromEntries(parameters.entries.where(
            (entry) =>
                allowedKeys.contains(entry.key) &&
                !const {
                  'watch_plan_id',
                  'content_id',
                  'parent_content_id',
                  'person_id'
                }.contains(entry.key),
          ));
    if (kDebugMode && verboseFlutterLogs) {
      debugPrint('[Analytics] $name ${safe ?? const {}}');
    }
    await _safely(() => _backend.logEvent(name, safe));
  }

  Future<void> _logOnce(String name, [Map<String, Object>? parameters]) async {
    if (!isEnabled || !_loggedOnce.add(name)) return;
    await logEvent(name, parameters);
  }

  Future<void> screenViewed(String screenName) async {
    if (!isEnabled || screenName == _lastScreenName) return;
    _lastScreenName = screenName;
    if (kDebugMode && verboseFlutterLogs) {
      debugPrint('[Analytics] screen_view {$screenName}');
    }
    await _safely(() => _backend.logScreenView(screenName));
  }

  Future<void> signupStarted() => _logOnce('signup_started');
  Future<void> signupCompleted() => _logOnce('signup_completed');
  Future<void> tasteSignalAdded({required String signalType}) =>
      logEvent('taste_signal_added', {'signal_type': signalType});
  Future<void> tasteProfileCompleted({required int signalCount}) => _logOnce(
      'taste_profile_completed', {'signal_count': signalCount.clamp(0, 100)});

  Future<void> contentOpened({
    required String contentType,
    required int contentId,
    String? genre,
    String source = 'unknown',
  }) =>
      logEvent('content_opened', {
        'content_type': _contentType(contentType),
        'content_id': contentId,
        if (genre?.trim().isNotEmpty == true) 'genre': genre!.trim(),
        'source': _source(source),
      });

  Future<void> personOpened({
    required int personId,
    String source = 'unknown',
    int? parentContentId,
    String? parentContentType,
  }) =>
      logEvent('person_opened', {
        'person_id': personId,
        'source': _source(source),
        if (parentContentId != null) 'parent_content_id': parentContentId,
        if (parentContentType == 'movie' || parentContentType == 'show')
          'parent_content_type': parentContentType!,
      });

  Future<void> watchlistAdded(
          {required String contentType,
          required int contentId,
          String source = 'unknown'}) =>
      _contentEvent('watchlist_added', contentType, contentId, source);
  Future<void> watchlistRemoved(
          {required String contentType,
          required int contentId,
          String source = 'unknown'}) =>
      _contentEvent('watchlist_removed', contentType, contentId, source);
  Future<void> watchLogged({
    required String contentType,
    required int contentId,
    String source = 'unknown',
    String? watchPlanId,
    String? planType,
    int? participantCount,
  }) =>
      logEvent('watch_logged', {
        'content_type': _contentType(contentType),
        'content_id': contentId,
        'source': _source(source),
        if (watchPlanId?.isNotEmpty == true) 'watch_plan_id': watchPlanId!,
        if (planType != null) 'plan_type': _planType(planType),
        if (participantCount != null)
          'participant_count': participantCount.clamp(1, 100),
      });
  Future<void> ratingAdded({
    required String contentType,
    required int contentId,
    String source = 'unknown',
    RecommendationAttribution? recommendation,
  }) =>
      logEvent('rating_added', {
        'content_type': _contentType(contentType),
        'content_id': contentId,
        'source': _source(source),
        ...?recommendation?.analyticsParameters,
      });
  Future<void> reviewCreated(
          {required String contentType,
          required int contentId,
          String source = 'unknown'}) =>
      _contentEvent('review_created', contentType, contentId, source);
  Future<void> recommendationGiven(
          {required String contentType,
          required int contentId,
          String source = 'unknown'}) =>
      _contentEvent('recommendation_given', contentType, contentId, source);

  Future<void> recommendationImpression(
      {required RecommendationAttribution attribution}) async {
    final key =
        '${attribution.source}:${attribution.algorithm}:${attribution.version}:${attribution.contentId}:${attribution.position}';
    if (!_impressions.add(key)) return;
    await _recommendationEvent('recommendation_impression', attribution);
  }

  Future<void> recommendationOpened(
          {required RecommendationAttribution attribution}) =>
      _recommendationEvent('recommendation_opened', attribution);
  Future<void> recommendationSaved(
          {required RecommendationAttribution attribution}) =>
      _recommendationEvent('recommendation_saved', attribution);
  Future<void> recommendationWatched(
          {required RecommendationAttribution attribution}) =>
      _recommendationEvent('recommendation_watched', attribution);

  Future<void> friendInviteSent(
          {String inviteMethod = 'unknown', String source = 'unknown'}) =>
      logEvent('friend_invite_sent', {
        'invite_method': _inviteMethod(inviteMethod),
        'source': _source(source)
      });
  Future<void> friendInviteOpened(
          {String inviteMethod = 'unknown', String source = 'unknown'}) =>
      logEvent('friend_invite_opened', {
        'invite_method': _inviteMethod(inviteMethod),
        'source': _source(source)
      });

  /// Records an installed-app referral link open after consent. If the link
  /// launches before the first-run consent choice, it is held only in memory
  /// and emitted if the user subsequently accepts analytics.
  Future<void> referralLinkOpened() async {
    if (_referralLinkOpenLogged) return;
    if (consent == AnalyticsConsent.unknown) {
      _pendingReferralLinkOpen = true;
      return;
    }
    _pendingReferralLinkOpen = false;
    if (!isEnabled) return;
    _referralLinkOpenLogged = true;
    await friendInviteOpened(
      inviteMethod: 'referral_link',
      source: 'shared_link',
    );
    await sharedLinkOpened(
      shareType: 'profile',
      source: 'shared_link',
    );
  }

  Future<void> friendInviteConverted(
          {String inviteMethod = 'unknown', String source = 'unknown'}) =>
      _logOnce('friend_invite_converted', {
        'invite_method': _inviteMethod(inviteMethod),
        'source': _source(source)
      });
  Future<void> friendConnected({String source = 'unknown'}) =>
      logEvent('friend_connected', {'source': _source(source)});

  Future<void> groupCreated(
          {required String groupType, String source = 'unknown'}) =>
      logEvent('group_created',
          {'group_type': _groupType(groupType), 'source': _source(source)});
  Future<void> groupJoined(
          {required String groupType, String source = 'unknown'}) =>
      logEvent('group_joined',
          {'group_type': _groupType(groupType), 'source': _source(source)});
  Future<void> groupMessageSent(
          {required String groupType, String source = 'group'}) =>
      logEvent('group_message_sent',
          {'group_type': _groupType(groupType), 'source': _source(source)});

  Future<void> watchPlanCreated(
          {String? watchPlanId,
          int? contentId,
          String contentType = 'movie',
          required String planType,
          int? participantCount,
          String source = 'unknown'}) =>
      _watchPlanEvent('watch_plan_created', watchPlanId, contentId, contentType,
          planType, participantCount, source);
  Future<void> watchPlanAccepted(
          {String? watchPlanId,
          int? contentId,
          String contentType = 'movie',
          required String planType,
          int? participantCount,
          String source = 'unknown'}) =>
      _watchPlanEvent('watch_plan_accepted', watchPlanId, contentId,
          contentType, planType, participantCount, source);
  Future<void> watchPlanScheduled(
          {String? watchPlanId,
          int? contentId,
          String contentType = 'movie',
          required String planType,
          int? participantCount,
          String source = 'unknown'}) =>
      _watchPlanEvent('watch_plan_scheduled', watchPlanId, contentId,
          contentType, planType, participantCount, source);
  Future<void> watchPlanCompleted(
          {String? watchPlanId,
          int? contentId,
          String contentType = 'movie',
          required String planType,
          int? participantCount,
          String source = 'unknown'}) =>
      _watchPlanEvent('watch_plan_completed', watchPlanId, contentId,
          contentType, planType, participantCount, source);

  Future<void> shareCreated(
          {required String shareType,
          String? contentType,
          int? contentId,
          String source = 'unknown'}) =>
      logEvent('share_created', {
        'share_type': _shareType(shareType),
        if (contentType != null) 'content_type': _contentType(contentType),
        if (contentId != null) 'content_id': contentId,
        'source': _source(source)
      });
  Future<void> sharedLinkOpened(
          {required String shareType,
          String? contentType,
          int? contentId,
          String source = 'shared_link'}) =>
      logEvent('shared_link_opened', {
        'share_type': _shareType(shareType),
        if (contentType != null) 'content_type': _contentType(contentType),
        if (contentId != null) 'content_id': contentId,
        'source': _source(source)
      });
  Future<void> sharedLinkSignup({required String shareType}) => _logOnce(
      'shared_link_signup',
      {'share_type': _shareType(shareType), 'source': 'signup'});

  Future<void> _contentEvent(
          String event, String type, int id, String source) =>
      logEvent(event, {
        'content_type': _contentType(type),
        'content_id': id,
        'source': _source(source)
      });
  Future<void> _recommendationEvent(
          String event, RecommendationAttribution attribution) =>
      logEvent(event, attribution.analyticsParameters);
  Future<void> _watchPlanEvent(String event, String? watchPlanId, int? id,
          String type, String planType, int? count, String source) =>
      logEvent(event, {
        if (watchPlanId?.isNotEmpty == true) 'watch_plan_id': watchPlanId!,
        if (id != null) 'content_id': id,
        'content_type': _contentType(type),
        'plan_type': _planType(planType),
        if (count != null) 'participant_count': count.clamp(1, 100),
        'source': _source(source)
      });

  String _source(String value) =>
      allowedSources.contains(value) ? value : 'unknown';
  String _contentType(String value) =>
      allowedContentTypes.contains(value) ? value : 'movie';
  String _inviteMethod(String value) =>
      allowedInviteMethods.contains(value) ? value : 'unknown';
  String _groupType(String value) =>
      allowedGroupTypes.contains(value) ? value : 'unknown';
  String _planType(String value) =>
      allowedPlanTypes.contains(value) ? value : 'friend';
  String _shareType(String value) =>
      allowedShareTypes.contains(value) ? value : 'movie';

  Future<void> _safely(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {}
  }

  // Compatibility wrappers keep existing call sites on the canonical events.
  Future<void> onboardingStarted() => _logOnce('onboarding_started');
  Future<void> favouriteSelected({required int favouriteCount}) =>
      tasteSignalAdded(signalType: 'favourite_movie');
  Future<void> onboardingCompleted({required int favouriteCount}) =>
      tasteProfileCompleted(signalCount: favouriteCount);
  Future<void> watchlistItemAdded({required String source}) =>
      watchlistAdded(contentType: 'movie', contentId: 0, source: source);
  Future<void> watchlistItemRemoved({required String source}) => logEvent(
      'watchlist_removed',
      {'content_type': 'movie', 'content_id': 0, 'source': _source(source)});
  Future<void> movieFavourited() => logEvent('content_favourited',
      {'content_type': 'movie', 'content_id': 0, 'source': 'unknown'});
  Future<void> movieUnfavourited() => logEvent('content_unfavourited',
      {'content_type': 'movie', 'content_id': 0, 'source': 'unknown'});
  Future<void> showFavourited() => logEvent('content_favourited',
      {'content_type': 'show', 'content_id': 0, 'source': 'unknown'});
  Future<void> showUnfavourited() => logEvent('content_unfavourited',
      {'content_type': 'show', 'content_id': 0, 'source': 'unknown'});
  Future<void> movieAddedToWatchlist() =>
      watchlistAdded(contentType: 'movie', contentId: 0);
  Future<void> movieRemovedFromWatchlist() => logEvent('watchlist_removed',
      {'content_type': 'movie', 'content_id': 0, 'source': 'unknown'});
  Future<void> showAddedToWatchlist() =>
      watchlistAdded(contentType: 'show', contentId: 0);
  Future<void> showRemovedFromWatchlist() => logEvent('watchlist_removed',
      {'content_type': 'show', 'content_id': 0, 'source': 'unknown'});
  Future<void> movieAddedToList() => logEvent('content_list_added',
      {'content_type': 'movie', 'content_id': 0, 'source': 'list'});
  Future<void> movieRemovedFromList() => logEvent('content_list_removed',
      {'content_type': 'movie', 'content_id': 0, 'source': 'list'});
  Future<void> showAddedToList() => logEvent('content_list_added',
      {'content_type': 'show', 'content_id': 0, 'source': 'list'});
  Future<void> showRemovedFromList() => logEvent('content_list_removed',
      {'content_type': 'show', 'content_id': 0, 'source': 'list'});
  Future<void> ratingSaved({required String source}) => ratingAdded(
      contentType: source == 'show_detail' ? 'show' : 'movie',
      contentId: 0,
      source: source);
  Future<void> friendRequestSent() => friendInviteSent(source: 'profile');
  Future<void> watchInvitationSent({required String recipientType}) =>
      watchPlanCreated(
          planType: recipientType == 'group' ? 'group' : 'friend',
          source: recipientType == 'group' ? 'group' : 'profile');
  Future<void> watchInvitationAccepted({required String recipientType}) =>
      watchPlanAccepted(
          planType: recipientType == 'group' ? 'group' : 'friend',
          source: recipientType == 'group' ? 'group' : 'notification');
  Future<void> watchScheduled({required String recipientType}) =>
      watchPlanScheduled(
          planType: recipientType == 'group' ? 'group' : 'friend',
          source: recipientType == 'group' ? 'group' : 'watch_plan');
  Future<void> referralInviteShared() =>
      friendInviteSent(inviteMethod: 'referral_link', source: 'profile');
  Future<void> referralQualified() =>
      friendInviteConverted(inviteMethod: 'referral_link', source: 'signup');
  Future<void> rewardUnlocked() => _logOnce('reward_unlocked');
  Future<void> tasteMatchViewed() => logEvent('taste_match_viewed');
  Future<void> matchedMovieInvitationSent() =>
      watchPlanCreated(planType: 'friend', source: 'recommendations');
}
