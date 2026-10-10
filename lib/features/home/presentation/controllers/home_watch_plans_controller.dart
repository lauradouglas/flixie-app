import 'package:flixie_app/core/auth/startup_trace.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/watch_plan_schedule.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/features/social/data/watch_plan_visibility_store.dart';
import 'package:flixie_app/features/home/presentation/models/home_group_watch_plan.dart';
import 'package:flixie_app/features/home/presentation/models/home_watch_plan_visibility.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/user.dart' as models;

/// Owns Home's direct/group plan loading, visibility and reminder synchronisation.
class HomeWatchPlansController extends ChangeNotifier {
  HomeWatchPlansController(WatchRequestCache cache) : _cache = cache;
  final WatchRequestCache _cache;
  String? _userId;
  bool _disposed = false;
  int _watchPlansLoadGeneration = 0;
  int _watchRequestsNeedingResponse = 0;
  List<WatchRequest> _watchPlansToShow = const [];
  bool _isLoadingWatchPlans = true;
  bool _watchPlansLoadFailed = false;
  bool _watchPlansIntroDismissed = false;
  bool _hasUsedWatchPlans = false;

  List<WatchRequest> get plans => List.unmodifiable(_watchPlansToShow);
  int get requestsNeedingResponse => _watchRequestsNeedingResponse;
  bool get loading => _isLoadingWatchPlans;
  bool get failed => _watchPlansLoadFailed;
  bool get introductionDismissed => _watchPlansIntroDismissed;
  bool get hasUsedPlans => _hasUsedWatchPlans;

  void _change(VoidCallback change) {
    if (_disposed) {
      return;
    }
    change();
    notifyListeners();
  }

  void selectUser(String? userId) {
    if (_disposed || _userId == userId) {
      return;
    }
    _watchPlansLoadGeneration++;
    _userId = userId;
    _change(() {
      _watchPlansToShow = const [];
      _watchRequestsNeedingResponse = 0;
      _isLoadingWatchPlans = userId != null;
      _watchPlansLoadFailed = false;
      _watchPlansIntroDismissed = false;
      _hasUsedWatchPlans = false;
    });
  }

  void restore(List<WatchRequest> plans, int responseCount, bool hasUsed) {
    _watchPlansToShow = List.of(plans);
    _watchRequestsNeedingResponse = responseCount;
    _hasUsedWatchPlans = hasUsed;
    _isLoadingWatchPlans = true;
  }

  void removeRecap(String userId, String planId) {
    if (_userId != userId) {
      return;
    }
    _change(() => _watchPlansToShow = _watchPlansToShow
        .where((plan) => plan.id != planId)
        .toList(growable: false));
  }

  void markUsed(String userId) {
    if (_userId != userId) {
      return;
    }
    _change(() {
      _watchPlansIntroDismissed = true;
      _hasUsedWatchPlans = true;
    });
  }

  Future<void> dismissIntroduction(String userId) async {
    if (_userId != userId) {
      return;
    }
    _change(() => _watchPlansIntroDismissed = true);
    await WatchPlanVisibilityStore.dismissIntroduction(userId);
  }

  @override
  void dispose() {
    _disposed = true;
    _watchPlansLoadGeneration++;
    super.dispose();
  }

  Future<void> load(models.User? user, {bool force = true}) =>
      StartupTrace.run('home.plans.load', () => _load(user, force: force));

  Future<void> _load(models.User? user, {bool force = true}) async {
    if (_disposed) {
      return;
    }
    selectUser(user?.id);
    final generation = ++_watchPlansLoadGeneration;
    if (user == null) {
      _change(() => _isLoadingWatchPlans = false);
      return;
    }
    if (!_disposed) {
      _change(() => _isLoadingWatchPlans = true);
    }
    bool isCurrent() =>
        !_disposed &&
        _userId == user.id &&
        generation == _watchPlansLoadGeneration;

    final cache = _cache;
    cache.syncUser(user.id);
    // Direct and group plans can appear independently. Retain the other
    // source's existing cards while its request is pending or fails.
    var direct = _watchPlansToShow
        .where((plan) => plan.conversationId != '__group_home__')
        .toList();
    var groups = _watchPlansToShow
        .where((plan) => plan.conversationId == '__group_home__')
        .toList();
    if (cache.hasDirectSnapshot) {
      direct = cache.direct;
    }
    if (cache.hasHomeSnapshot) {
      groups = cache.home
          .map((entry) => asHomeGroupWatchPlan(entry.group, entry.request))
          .toList();
    }
    var failed = false;
    final visibility = StartupTrace.run(
        'home.plans.preferences',
        () => Future.wait<dynamic>([
              WatchPlanVisibilityStore.closedPlanIds(user.id),
              WatchPlanVisibilityStore.isIntroductionDismissed(user.id),
            ]));

    void applyPlans(List<dynamic> preferences) {
      if (!isCurrent()) {
        return;
      }
      final allPlans = [...direct, ...groups];
      final nextPlans = watchPlansForHome(allPlans,
          userId: user.id, closedPlanIds: preferences[0] as Set<String>);
      final hasUsed =
          allPlans.any((plan) => _hasCreatedOrAcceptedWatchPlan(plan, user.id));
      _change(() {
        _watchRequestsNeedingResponse =
            _countWatchRequestsNeedingResponse(direct, user.id);
        if (_watchPlansFingerprint(_watchPlansToShow) !=
            _watchPlansFingerprint(nextPlans)) {
          _watchPlansToShow = nextPlans;
        }
        _hasUsedWatchPlans = _hasUsedWatchPlans || hasUsed;
        _watchPlansIntroDismissed =
            _watchPlansIntroDismissed || (preferences[1] as bool) || hasUsed;
      });
      StartupTrace.mark('home.plans.published', {'count': nextPlans.length});
      if (hasUsed) {
        unawaited(WatchPlanVisibilityStore.dismissIntroduction(user.id));
      }
    }

    Future<void> loadSource(Future<List<WatchRequest>> Function() request,
        {required bool isGroup}) async {
      try {
        final results = await Future.wait<dynamic>([
          StartupTrace.run(
              isGroup ? 'home.plans.group' : 'home.plans.direct', request),
          visibility
        ]);
        if (!isCurrent()) {
          return;
        }
        final plans = results[0] as List<WatchRequest>;
        if (isGroup) {
          groups = plans;
        } else {
          direct = plans;
          _watchRequestsNeedingResponse =
              _countWatchRequestsNeedingResponse(plans, user.id);
        }
        applyPlans(results[1] as List<dynamic>);
        unawaited(_syncLocalWatchPlanReminders(plans, userId: user.id));
      } catch (error) {
        failed = true;
        if (isCurrent() &&
            error is ApiException &&
            (error.statusCode == 401 || error.statusCode == 403)) {
          if (isGroup) {
            groups = [];
          } else {
            direct = [];
          }
          applyPlans(await visibility);
        }
        logger.w('[HomeScreen] watch plans load failed: $error');
      }
    }

    // Paint the last successful snapshot while the background check runs.
    unawaited(visibility.then(applyPlans).catchError((Object _) {}));
    await Future.wait([
      loadSource(() => cache.refreshDirect(force: force), isGroup: false),
      loadSource(() => _loadGroupWatchPlansForHome(force: force),
          isGroup: true),
    ]);
    if (!isCurrent()) {
      return;
    }
    _change(() {
      _watchPlansLoadFailed = failed;
      _isLoadingWatchPlans = false;
    });
  }

  String _watchPlansFingerprint(Iterable<WatchRequest> plans) => plans
      .map(
        (plan) => [
          plan.id,
          plan.status,
          plan.updatedAt ?? '',
          plan.scheduledFor?.toIso8601String() ?? '',
          plan.proposedDate?.toIso8601String() ?? '',
          plan.location ?? '',
          plan.selectedCandidateId ?? '',
          ...plan.scheduleProposals.map(
            (proposal) => [
              proposal.id,
              proposal.status,
              proposal.proposerId,
              ...proposal.responses.map(
                (response) => '${response.userId}:${response.status}',
              ),
            ].join(','),
          ),
        ].join('|'),
      )
      .join('\n');

  Future<void> _syncLocalWatchPlanReminders(
    List<WatchRequest> plans, {
    required String userId,
  }) async {
    for (final plan in plans) {
      if (_disposed || _userId != userId) {
        return;
      }
      final scheduledFor = plan.scheduledFor;
      if (!plan.isWatchRequest ||
          plan.isTerminal ||
          scheduledFor == null ||
          watchPlanScheduleHasPassed(scheduledFor,
              dateOnly: plan.scheduledDateOnly)) {
        continue;
      }
      final hasDeclinedGroupPlan = plan.groupName?.isNotEmpty == true &&
          plan.participantFor(userId)?.response.toUpperCase() == 'DECLINED';
      if (hasDeclinedGroupPlan) {
        await PushNotificationService.cancelWatchPlanReminders(plan.id,
            scope: 'GROUP');
        continue;
      }
      final groupName = plan.groupName?.trim();
      final isGroupPlan = groupName?.isNotEmpty == true;
      final otherUser = plan.otherUser(userId);
      await PushNotificationService.scheduleWatchPlanReminders(
        planId: plan.id,
        scheduledFor: scheduledFor,
        dateOnly: plan.scheduledDateOnly,
        title: plan.watchPlanTitle,
        withName:
            isGroupPlan ? groupName! : otherUser?.username ?? 'your friend',
        deepLink: isGroupPlan && plan.groupId?.isNotEmpty == true
            ? '/groups/${plan.groupId}?tab=requests&requestId=${plan.id}'
            : '/watch-requests/${plan.id}',
        scope: isGroupPlan ? 'GROUP' : 'DIRECT',
      );
    }
  }

  /// Adapt scheduled group plans to the same homepage card contract used by
  /// direct plans. This keeps their ordering, due-state and card layout truly
  /// identical while preserving a marker for the correct deep link.
  Future<List<WatchRequest>> _loadGroupWatchPlansForHome(
      {bool force = true}) async {
    final cache = _cache;
    final userId = _userId;
    final generation = _watchPlansLoadGeneration;
    cache.syncUser(userId);
    final entries = await cache.refreshHome(force: force);
    if (_disposed ||
        _userId != userId ||
        generation != _watchPlansLoadGeneration) {
      return const [];
    }
    for (final entry in entries) {
      if (_disposed ||
          _userId != userId ||
          generation != _watchPlansLoadGeneration) {
        return const [];
      }
      final request = entry.request;
      final canonicalId = request.databaseRequestId;
      final declined = request.memberStatuses.any(
          (member) => member.memberId == userId && member.status == 'DECLINED');
      if (declined || request.isArchived) {
        await PushNotificationService.cancelWatchPlanReminders(
            canonicalId ?? request.id,
            scope: 'GROUP');
      }
      if (canonicalId != null && canonicalId != request.id) {
        await PushNotificationService.cancelWatchPlanReminders(request.id,
            scope: 'GROUP');
      }
    }
    return entries
        .map((entry) => asHomeGroupWatchPlan(entry.group, entry.request))
        .toList(growable: false);
  }

  int _countWatchRequestsNeedingResponse(
    List<WatchRequest> requests,
    String userId,
  ) {
    return requests.where((request) {
      if (!request.isWatchRequest) {
        return false;
      }
      if (request.isPending && request.requesterId != userId) {
        return true;
      }
      final proposal = request.latestPendingProposal;
      if (request.normalizedScheduleStatus == 'PROPOSED' &&
          proposal != null &&
          proposal.proposerId != userId) {
        return true;
      }
      return request.canConfirmWatchedFor(userId);
    }).length;
  }

  bool _hasCreatedOrAcceptedWatchPlan(WatchRequest plan, String userId) {
    if (plan.requesterId == userId) {
      return true;
    }

    // Direct plans can report the current user's response at the top level;
    // group plans store it against the participant. Support both shapes so
    // accepting any Watch Plan retires the first-time prompt.
    return plan.hasCurrentUserAccepted == true ||
        plan.participantFor(userId)?.response.toUpperCase() == 'ACCEPTED';
  }
}
