import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/features/social/data/watch_plan_visibility_store.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_watch_requests_overview.dart';
import 'package:flixie_app/features/social/presentation/widgets/watch_plan_candidate_avatar.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';

const List<String> _kMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

enum _StatusFilter {
  active,
  needsResponse,
  planning,
  scheduled,
  completed,
  declined,
  cancelled,
  expired,
}

enum _RequestAction {
  accepting,
  maybe,
  declining,
  scheduling,
  savingMovieChoices,
  removingCandidate,
  selectingMovie,
  completing,
  deleting,
}

enum _RequestAudience { friends, groups }

enum _PostWatchState { nobodyLogged, waitingForMe, waitingForOthers, recap }

class _AcceptanceScheduleDraft {
  const _AcceptanceScheduleDraft({
    required this.proposedFor,
    this.message,
    this.location,
  });

  final DateTime proposedFor;
  final String? message;
  final String? location;
}

class WatchRequestsScreen extends StatefulWidget {
  const WatchRequestsScreen({super.key, this.initialRequestId});

  final String? initialRequestId;

  @override
  State<WatchRequestsScreen> createState() => _WatchRequestsScreenState();
}

/// Dedicated full-page view for one Watch Plan.
class WatchRequestDetailScreen extends StatefulWidget {
  const WatchRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  State<WatchRequestDetailScreen> createState() =>
      _WatchRequestDetailScreenState();
}

class _WatchRequestDetailScreenState extends State<WatchRequestDetailScreen> {
  var _resolvingGroupPlan = true;

  @override
  void initState() {
    super.initState();
    _resolveGroupPlan();
  }

  /// Some older notification payloads identify a group plan only by request
  /// ID. Resolve those before falling back to the direct-plan screen, so a
  /// tap never strands someone on an empty Watch Plans page.
  Future<void> _resolveGroupPlan() async {
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.dbUser?.id;
      if (userId == null || userId.isEmpty) return;

      // Fetch fresh membership here. A notification can arrive before the
      // authenticated cache has refreshed after someone joined a group.
      final groups = await GroupService.getUserGroups(userId);

      for (final group in groups) {
        final groupId = group.id;
        if (groupId == null || groupId.isEmpty) continue;
        final requests = await GroupService.getGroupWatchRequests(groupId);
        if (requests.any((request) => request.id == widget.requestId)) {
          if (!mounted) return;
          context.go(
              '/groups/$groupId?tab=requests&requestId=${widget.requestId}');
          return;
        }
      }
    } catch (error) {
      // A failed lookup must not prevent opening a valid direct watch plan.
      logger
          .w('Unable to resolve group watch plan ${widget.requestId}: $error');
    } finally {
      if (mounted) {
        setState(() => _resolvingGroupPlan = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resolvingGroupPlan) {
      return const FlixiePageScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return WatchRequestsScreen(initialRequestId: widget.requestId);
  }
}

class _WatchRequestsScreenState extends State<WatchRequestsScreen> {
  final _searchController = TextEditingController();

  List<WatchRequest> _all = [];
  List<WatchRequest> _filtered = [];
  bool _loading = true;
  String? _error;
  _StatusFilter _statusFilter = _StatusFilter.active;
  final Map<String, _RequestAction> _busyActions = {};
  List<Group> _groups = [];
  bool _loadingGroups = true;
  _RequestAudience _audience = _RequestAudience.friends;
  bool _showSearch = false;
  final Map<String, _AcceptanceScheduleDraft> _acceptScheduleDrafts = {};
  final Map<String, Set<String>> _candidateChoiceDrafts = {};
  final Set<String> _dirtyCandidateChoiceDraftIds = <String>{};
  Set<String> _closedPlanIds = <String>{};

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _groups = auth.cachedGroups ?? [];
    _loadingGroups = _groups.isEmpty;
    final cachedRequests = auth.cachedWatchRequests;
    if (cachedRequests != null) {
      _all = List.of(cachedRequests);
      _loading = false;
      _applyFilter();
    }
    _loadClosedPlans();
    _load(showSpinner: cachedRequests == null);
    _loadGroups();
    _searchController.addListener(_applyFilter);
  }

  Future<void> _loadClosedPlans() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    final closedPlanIds = await WatchPlanVisibilityStore.closedPlanIds(userId);
    if (!mounted) return;
    setState(() => _closedPlanIds = closedPlanIds);
    _applyFilter();
  }

  Future<void> _loadGroups() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) {
      if (mounted) setState(() => _loadingGroups = false);
      return;
    }
    try {
      final groups = await GroupService.getUserGroups(userId);
      if (mounted) {
        setState(() {
          _groups = groups;
          _loadingGroups = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = false}) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    if (showSpinner) setState(() => _loading = true);
    setState(() => _error = null);
    try {
      final requests = await RequestService.getWatchRequests(userId);
      final hydrated = await Future.wait(
        requests.map((request) async {
          try {
            final state = await RequestService.getWatchRequestState(
              watchRequestId: request.id,
              userId: userId,
            );
            return state.request;
          } catch (e) {
            logger.w('[WatchRequestsScreen] state load failed: $e');
            return request;
          }
        }),
      );
      for (final request in hydrated) {
        final scheduledFor = request.scheduledFor;
        if (scheduledFor != null && scheduledFor.isAfter(DateTime.now())) {
          PushNotificationService.scheduleWatchPlanReminders(
            planId: request.id,
            scheduledFor: scheduledFor,
            title: request.movie?.title ?? 'Watch together',
            withName: request.participants
                    .map((participant) => participant.user)
                    .whereType<WatchRequestUser>()
                    .where((participant) => participant.id != userId)
                    .firstOrNull
                    ?.username ??
                'your friend',
            deepLink: '/watch-requests/${request.id}',
          );
        }
      }
      // Sort by most recent first, keeping a linked notification target on top.
      hydrated.sort((a, b) {
        final target = widget.initialRequestId;
        if (target != null && target.isNotEmpty) {
          if (a.id == target) return -1;
          if (b.id == target) return 1;
        }
        return _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt));
      });
      if (mounted) {
        setState(() {
          _all = hydrated;
          _loading = false;
        });
        context.read<AuthProvider>().updateCachedWatchRequests(hydrated);
        _applyFilter();
      }
    } catch (e) {
      logger.e('[WatchRequestsScreen] load error: $e');
      if (mounted) {
        setState(() {
          if (_all.isEmpty) _error = 'Failed to load Watch Plans.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _startNewWatchPlan() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null || userId.isEmpty) return;

    final movie = await showModalBottomSheet<MovieShort>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: FlixieColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MovieSearchSheet(
        title: 'Choose a movie',
        searchMovies: (query) async {
          final search = await SearchService.search(query, type: 'movie');
          return search.results
              .where((item) => item.movie != null)
              .map((item) => item.movie!)
              .toList(growable: false);
        },
      ),
    );
    if (!mounted || movie == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MovieWatchRequestSheet(
        movieId: movie.id,
        movieTitle: movie.name,
        moviePoster: movie.poster,
        requesterId: userId,
        friends: auth.cachedFriends?.friendships ?? const [],
        onSuccess: () {
          if (!mounted) return;
          _load();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Watch Plan sent'),
              backgroundColor: FlixieColors.surfaceElevated,
            ),
          );
        },
        onError: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not send the Watch Plan'),
              backgroundColor: FlixieColors.danger,
            ),
          );
        },
      ),
    );
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    final myId = context.read<AuthProvider>().dbUser?.id ?? '';

    setState(() {
      _filtered = _all.where((r) {
        if (_closedPlanIds.contains(r.id)) return false;
        final focusedId = widget.initialRequestId;
        if (focusedId != null && focusedId.isNotEmpty) {
          return r.id == focusedId;
        }
        // Status filter
        if (!_matchesStatusFilter(r)) {
          return false;
        }

        if (q.isEmpty) return true;
        // Search by movie title or other user's username
        final movieMatch = (r.movie?.title.toLowerCase().contains(q)) ?? false;
        final userMatch =
            (r.otherUser(myId)?.username.toLowerCase().contains(q)) ?? false;
        return movieMatch || userMatch;
      }).toList();
    });
  }

  bool _matchesStatusFilter(WatchRequest request) {
    return _matchesFilter(request, _statusFilter);
  }

  bool _matchesFilter(WatchRequest request, _StatusFilter filter) {
    switch (filter) {
      case _StatusFilter.active:
        return _isActiveRequest(request);
      case _StatusFilter.needsResponse:
        final myUserId = context.read<AuthProvider>().dbUser?.id ?? '';
        return _isActiveRequest(request) && _needsAttention(request, myUserId);
      case _StatusFilter.planning:
        return _isActiveRequest(request) &&
            (request.isAccepted || request.isScheduled) &&
            request.normalizedScheduleStatus != 'AGREED' &&
            !_isPostWatchDue(request);
      case _StatusFilter.scheduled:
        return _isActiveRequest(request) && _isUpcoming(request);
      case _StatusFilter.completed:
        return _isCompletedRequest(request) || _isPostWatchDue(request);
      case _StatusFilter.declined:
        return _isDeclinedRequest(request);
      case _StatusFilter.cancelled:
        return _isCancelledRequest(request);
      case _StatusFilter.expired:
        return request.isExpired;
    }
  }

  bool _isCompletedRequest(WatchRequest request) =>
      request.isCompleted || request.normalizedWatchedStatus == 'WATCHED';

  bool _isPostWatchDue(WatchRequest request) {
    final time = request.scheduledFor ?? request.proposedDate;
    return !_isCompletedRequest(request) &&
        !request.isCancelled &&
        !request.isExpired &&
        time != null &&
        !time.isAfter(DateTime.now());
  }

  bool _isDeclinedRequest(WatchRequest request) => request.isDeclined;

  // A cancelled time proposal is still an active accepted request that can be
  // replanned. Only the request's own terminal status belongs in Cancelled.
  bool _isCancelledRequest(WatchRequest request) => request.isCancelled;

  bool _isActiveRequest(WatchRequest request) =>
      !_isCompletedRequest(request) &&
      !_isDeclinedRequest(request) &&
      !_isCancelledRequest(request) &&
      !request.isExpired;

  DateTime _parseDate(String? iso) =>
      DateTime.tryParse(iso ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  String _formatDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return '';
    return '${dt.day} ${_kMonths[dt.month - 1]} ${dt.year}';
  }

  String _formatFriendlyDateTime(DateTime? value) {
    if (value == null) return '';
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'pm' : 'am';
    final time = '$hour:$minute$suffix';
    if (date == today) return 'Today at $time';
    if (date == today.add(const Duration(days: 1))) return 'Tomorrow at $time';
    return '${local.day} ${_kMonths[local.month - 1]}, $time';
  }

  void _replaceRequest(WatchRequest updated) {
    setState(() {
      _all = _all.map((r) => r.id == updated.id ? updated : r).toList();
    });
    context.read<AuthProvider>().updateCachedWatchRequests(_all);
    _applyFilter();
    TabRefreshController.requestHomeRefresh();
  }

  Future<void> _refreshRequestState(WatchRequest request, String userId) async {
    if (userId.isEmpty) return;
    try {
      final state = await RequestService.getWatchRequestState(
        watchRequestId: request.id,
        userId: userId,
      );
      _replaceRequest(state.request);
    } catch (e) {
      logger.w('[WatchRequestsScreen] state refresh failed: $e');
    }
  }

  Future<void> _confirmDelete(WatchRequest request) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    final isCreator = request.requesterId == userId;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isCreator ? 'Close Watch Plan?' : 'Leave Watch Plan?'),
        content: const Text(
          'This permanently closes the shared plan, its schedule and related notifications for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep plan'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: FlixieColors.danger,
              foregroundColor: Colors.white,
            ),
            child: Text(isCreator ? 'Close for everyone' : 'Leave and close'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _withRequestAction(request, _RequestAction.deleting, () async {
      try {
        await RequestService.deleteWatchRequest(
          watchRequestId: request.id,
          userId: userId,
        );
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        final cachedNotifications = auth.cachedNotifications;
        if (cachedNotifications != null) {
          auth.updateCachedNotifications(
            cachedNotifications
                .where((item) => item.linkedRequestId != request.id)
                .toList(),
          );
        }
        setState(() {
          _all.removeWhere((item) => item.id == request.id);
          _filtered.removeWhere((item) => item.id == request.id);
        });
        auth.updateCachedWatchRequests(_all);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Watch Plan closed')),
        );
        if (widget.initialRequestId?.isNotEmpty == true) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/watch-requests');
          }
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not delete the Watch Plan'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    });
  }

  Future<void> _closeWatchPlan(WatchRequest request) async {
    await _confirmDelete(request);
  }

  Future<void> _withRequestAction(
    WatchRequest request,
    _RequestAction action,
    Future<void> Function() run,
  ) async {
    setState(() => _busyActions[request.id] = action);
    try {
      await run();
    } finally {
      if (mounted) setState(() => _busyActions.remove(request.id));
    }
  }

  Future<bool> _respond(WatchRequest request, String response) async {
    final analytics = context.read<AnalyticsController>();
    var succeeded = false;
    final action = switch (response) {
      'ACCEPTED' => _RequestAction.accepting,
      'DECLINED' => _RequestAction.declining,
      _ => _RequestAction.maybe,
    };
    await _withRequestAction(request, action, () async {
      try {
        await RequestService.updateRequest(request.id, response);
        if (response == 'ACCEPTED') {
          await analytics.watchPlanAccepted(
            watchPlanId: request.id,
            contentId: request.analyticsContentId,
            contentType: request.analyticsContentType,
            planType: request.analyticsPlanType,
            participantCount: request.analyticsParticipantCount,
            source: 'watch_plan',
          );
        }
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_responseSuccessMessage(response)),
            backgroundColor: FlixieColors.surfaceElevated,
          ),
        );
        succeeded = true;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_responseFailureMessage(response)),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    });
    return succeeded;
  }

  Future<void> _acceptWithOptionalSchedule(WatchRequest request) async {
    final scheduleDraft = _acceptScheduleDrafts[request.id];
    final accepted = await _respond(request, 'ACCEPTED');
    if (accepted && scheduleDraft != null && mounted) {
      await _submitScheduleProposal(request, scheduleDraft);
      if (mounted) setState(() => _acceptScheduleDrafts.remove(request.id));
    }
  }

  Future<void> _chooseAcceptanceSchedule(WatchRequest request) async {
    final selected = await _showScheduleProposalSheet(
      initial: _acceptScheduleDrafts[request.id]?.proposedFor,
      initialLocation: _acceptScheduleDrafts[request.id]?.location,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _acceptScheduleDrafts[request.id] = _AcceptanceScheduleDraft(
        proposedFor: selected.proposedFor,
        message: selected.message,
        location: selected.location,
      );
    });
  }

  Future<void> _suggestSchedule(WatchRequest request,
      {DateTime? initial}) async {
    final selected = await _showScheduleProposalSheet(
      initial: initial,
      initialLocation: request.location,
    );
    if (!mounted || selected == null) return;
    await _submitScheduleProposal(
      request,
      _AcceptanceScheduleDraft(
        proposedFor: selected.proposedFor,
        message: selected.message,
        location: selected.location,
      ),
    );
  }

  Future<({DateTime proposedFor, String? message, String? location})?>
      _showScheduleProposalSheet({DateTime? initial, String? initialLocation}) {
    return showModalBottomSheet<
        ({DateTime proposedFor, String? message, String? location})>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleProposalSheet(
        initial: initial,
        initialLocation: initialLocation,
      ),
    );
  }

  Future<void> _submitScheduleProposal(
    WatchRequest request,
    _AcceptanceScheduleDraft selected,
  ) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;

    await _withRequestAction(request, _RequestAction.scheduling, () async {
      try {
        final state = await RequestService.proposeWatchSchedule(
          watchRequestId: request.id,
          userId: userId,
          proposedFor: selected.proposedFor,
          message: selected.message,
          location: selected.location,
        );
        _replaceRequest(state.request);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(request.scheduledFor == null
                ? 'Suggested ${_formatFriendlyDateTime(selected.proposedFor)}'
                : 'New time proposed - the current plan stays in place until they agree'),
            backgroundColor: FlixieColors.surfaceElevated,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to schedule watch. Please try again.'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    });
  }

  Future<void> _editLocation(WatchRequest request) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    final location = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationEditorSheet(initialLocation: request.location),
    );
    if (!mounted || location == null || location.isEmpty) return;

    await _withRequestAction(request, _RequestAction.scheduling, () async {
      try {
        final updated = await RequestService.updateWatchRequestLocation(
          watchRequestId: request.id,
          userId: userId,
          location: location,
        );
        _replaceRequest(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Location set to $location')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not update the location')),
          );
        }
      }
    });
  }

  Future<void> _respondToProposal(
    WatchRequest request,
    WatchScheduleProposal proposal,
    String decision,
  ) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final analytics = context.read<AnalyticsController>();
    if (userId == null || userId.isEmpty) return;

    await _withRequestAction(request, _RequestAction.scheduling, () async {
      try {
        final state = await RequestService.respondToWatchScheduleProposal(
          watchRequestId: request.id,
          proposalId: proposal.id,
          userId: userId,
          decision: decision,
        );
        _replaceRequest(state.request);
        final agreedTime = state.request.scheduledFor ?? proposal.proposedFor;
        if (decision == 'accepted' && agreedTime != null) {
          await analytics.watchPlanScheduled(
            watchPlanId: state.request.id,
            contentId: state.request.analyticsContentId,
            contentType: state.request.analyticsContentType,
            planType: state.request.analyticsPlanType,
            participantCount: state.request.analyticsParticipantCount,
            source: 'watch_plan',
          );
          await PushNotificationService.scheduleWatchPlanReminders(
            planId: state.request.id,
            scheduledFor: agreedTime,
            title: state.request.movie?.title ?? 'Watch together',
            withName: state.request.participants
                    .map((participant) => participant.user)
                    .whereType<WatchRequestUser>()
                    .where((participant) => participant.id != userId)
                    .firstOrNull
                    ?.username ??
                'your friend',
            deepLink: '/watch-requests/${state.request.id}',
          );
        }
        if (!mounted) return;
        if (decision == 'accepted' && agreedTime != null) {
          final addToCalendar = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Time agreed'),
                  content: Text(
                    'Add “${request.movie?.title ?? 'Watch together'}” to your phone calendar?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Not now'),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Add to calendar'),
                    ),
                  ],
                ),
              ) ??
              false;
          if (addToCalendar) {
            await WatchCalendarService.addScheduledWatch(
              title: request.movie?.title ?? 'Watch together',
              scheduledFor: agreedTime,
              runtimeMinutes: request.movie?.runtimeMinutes,
              note: request.message,
              location: request.location,
            );
          }
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(decision == 'accepted'
                ? 'Watch time agreed'
                : request.scheduledFor != null
                    ? 'New time declined - your original plan is unchanged'
                    : 'Time declined'),
            backgroundColor: FlixieColors.surfaceElevated,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update proposed time. Please try again.'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    });
  }

  Future<void> _confirmWatched(WatchRequest request) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    final analytics = context.read<AnalyticsController>();
    final movieService = context.read<MovieService>();
    if (userId == null || userId.isEmpty) return;
    var saved = false;
    int? savedRating;
    bool? savedRecommended;
    String? savedNote;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewatchLogSheet(
        showReviewOption: false,
        onSubmit: ({
          required watchedAt,
          required rating,
          required recommended,
          required notes,
        }) async {
          savedRating = rating?.round();
          savedRecommended = recommended;
          savedNote = notes;
          await _withRequestAction(request, _RequestAction.completing,
              () async {
            final state = await RequestService.confirmWatchRequest(
              watchRequestId: request.id,
              userId: userId,
              watched: true,
              rating: rating?.round(),
              reviewText: notes,
              watchedAt: watchedAt,
              recommended: recommended,
            );
            // The watch-plan endpoint also performs this sync, but verify it
            // through the movie endpoint as a compatibility safeguard for
            // local/older API deployments. A plan rating should always become
            // the user's overall rating for that movie.
            final movieId = state.request.movieId;
            if (savedRating != null && movieId != null) {
              try {
                final overallRating =
                    await movieService.getUserMovieRating(movieId, userId);
                if (overallRating.rating != savedRating ||
                    overallRating.recommended != savedRecommended) {
                  await movieService.addMovieRating(
                    movieId,
                    userId,
                    savedRating!,
                    savedRecommended,
                  );
                }
              } catch (error, stackTrace) {
                logger.w(
                  'Watch plan was saved, but its movie rating could not be reconciled.',
                  error: error,
                  stackTrace: stackTrace,
                );
              }
            }
            _replaceRequest(state.request);
            await PushNotificationService.cancelWatchPlanReminders(
              state.request.id,
            );
            final contentId = state.request.analyticsContentId;
            if (contentId != null) {
              await analytics.watchLogged(
                contentType: state.request.analyticsContentType,
                contentId: contentId,
                source: 'watch_plan',
                watchPlanId: state.request.id,
                planType: state.request.analyticsPlanType,
                participantCount: state.request.analyticsParticipantCount,
              );
            }
            if (!mounted) return;
            context.read<AuthProvider>().markActivityChanged();
            if (!request.isCompleted && state.request.isCompleted) {
              await analytics.watchPlanCompleted(
                watchPlanId: state.request.id,
                contentId: state.request.analyticsContentId,
                contentType: state.request.analyticsContentType,
                planType: state.request.analyticsPlanType,
                participantCount: state.request.analyticsParticipantCount,
                source: 'watch_plan',
              );
            }
            saved = true;
          });
        },
      ),
    );
    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Watch entry saved to your plan'),
        backgroundColor: FlixieColors.surfaceElevated,
      ),
    );
    final user = context.read<AuthProvider>().dbUser;
    final movie = request.movie;
    if (savedRating != null && user != null && movie != null) {
      promptShareCard(
        context,
        ShareCardData.rating(
          mediaType: ShareCardMediaType.movie,
          mediaId: movie.id,
          title: movie.title,
          posterPath: movie.posterPath,
          user: user,
          rating: savedRating!,
          recommended: savedRecommended,
          note: savedNote,
        ),
      );
    }
  }

  Future<void> _cancelPlan(WatchRequest request) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this watch plan?'),
        content: const Text(
          'This removes the watch plan and its related notifications for everyone taking part.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep plan'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: FlixieColors.danger),
            child: const Text('Cancel plan'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _withRequestAction(request, _RequestAction.declining, () async {
      try {
        await RequestService.deleteWatchRequest(
          watchRequestId: request.id,
          userId: userId,
        );
        if (!mounted) return;
        final auth = context.read<AuthProvider>();
        final cachedNotifications = auth.cachedNotifications;
        if (cachedNotifications != null) {
          auth.updateCachedNotifications(
            cachedNotifications
                .where((item) => item.linkedRequestId != request.id)
                .toList(),
          );
        }
        setState(() {
          _all.removeWhere((item) => item.id == request.id);
          _filtered.removeWhere((item) => item.id == request.id);
        });
        auth.updateCachedWatchRequests(_all);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Watch plan cancelled for everyone')),
          );
          if (widget.initialRequestId?.isNotEmpty == true) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/watch-requests');
            }
          }
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not cancel the watch plan'),
              backgroundColor: FlixieColors.danger,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isFocused = widget.initialRequestId?.isNotEmpty == true;
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    final canDeleteFocusedPlan = isFocused &&
        !_loading &&
        _filtered.isNotEmpty &&
        _filtered.first.requesterId == currentUserId;
    final focusedCompanion = isFocused && _filtered.isNotEmpty
        ? (_filtered.first.groupName?.trim().isNotEmpty == true
            ? _filtered.first.groupName!
            : _filtered.first.otherUser(currentUserId ?? '')?.username ??
                'Watch together')
        : null;
    final directBody = _loading
        ? const WatchRequestsSkeleton()
        : _error != null
            ? _buildError()
            : _filtered.isEmpty
                ? _buildEmpty()
                : _buildRequestsList(isFocused);
    final body = isFocused
        ? directBody
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: _AudienceSwitcher(
                  selected: _audience,
                  onChanged: (value) => setState(() => _audience = value),
                ),
              ),
              if (_audience == _RequestAudience.friends) _buildFriendFilters(),
              Expanded(
                child: _audience == _RequestAudience.friends
                    ? directBody
                    : _loadingGroups
                        ? const Center(child: CircularProgressIndicator())
                        : GroupWatchRequestsOverview(groups: _groups),
              ),
            ],
          );
    final screen = FlixiePageScaffold(
      appBar: FlixieTitleAppBar(
        backgroundColor: FlixieColors.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isFocused ? 'Watch Plan' : 'Watch Plans',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: isFocused ? 20 : 22,
                    fontWeight: FontWeight.bold)),
            if (isFocused && focusedCompanion != null)
              Text('With $focusedCompanion',
                  style:
                      const TextStyle(color: FlixieColors.medium, fontSize: 12))
            else if (!_loading && _error == null)
              Text(
                  _audience == _RequestAudience.friends
                      ? '${_all.length} plans'
                      : 'Across ${_groups.length} groups',
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 12)),
          ],
        ),
        actions: canDeleteFocusedPlan
            ? [
                PopupMenuButton<String>(
                  tooltip: 'Watch Plan options',
                  enabled: _busyActions[_filtered.first.id] !=
                      _RequestAction.deleting,
                  icon: _busyActions[_filtered.first.id] ==
                          _RequestAction.deleting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'delete') _confirmDelete(_filtered.first);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline, color: FlixieColors.danger),
                        SizedBox(width: 10),
                        Text('Delete watch plan',
                            style: TextStyle(color: FlixieColors.danger)),
                      ]),
                    ),
                  ],
                ),
              ]
            : isFocused
                ? null
                : [
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: IconButton(
                        tooltip: 'New Watch Plan',
                        onPressed: _startNewWatchPlan,
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 30,
                          color: FlixieColors.primary,
                        ),
                      ),
                    ),
                  ],
        bottom: null,
      ),
      // Watch Plan actions deliberately share one shape.  Keeping this at the
      // screen boundary also carries into bottom sheets opened from here.
      body: Theme(
        data: Theme.of(context).copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        child: body,
      ),
    );
    // The plan detail is a deliberately dense, reference-led layout. It
    // should not double in size when the device's global text scaling is high.
    return isFocused
        ? MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: screen,
          )
        : screen;
  }

  Widget _buildFriendFilters() {
    const filters = [_StatusFilter.active, _StatusFilter.completed];
    return Column(
      children: [
        if (_showSearch)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by movie or username...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: FlixieColors.tabBarBackgroundFocused,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        SizedBox(
          height: 58,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            itemCount: filters.length,
            itemBuilder: (_, index) {
              final filter = filters[index];
              final selected = _statusFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter == _StatusFilter.active
                      ? 'Active · ${_countFor(_StatusFilter.active)}'
                      : 'Past · ${_countFor(_StatusFilter.completed)}'),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _statusFilter =
                        selected ? _StatusFilter.active : filter);
                    _applyFilter();
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  padding: EdgeInsets.zero,
                  selectedColor: FlixieColors.primary.withValues(alpha: .22),
                  backgroundColor: FlixieColors.tabBarBackgroundFocused,
                  side: BorderSide(
                    color: FlixieColors.primary.withValues(
                      alpha: selected ? 1 : 0.3,
                    ),
                  ),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : FlixieColors.medium,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList(bool isFocused) {
    final myUserId = context.read<AuthProvider>().dbUser?.id ?? '';
    if (isFocused ||
        _statusFilter != _StatusFilter.active ||
        _searchController.text.trim().isNotEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        color: FlixieColors.primary,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(16, isFocused ? 8 : 16, 16, 24),
          itemCount: _filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) =>
              _buildRequestCard(_filtered[index], isFocused, myUserId),
        ),
      );
    }

    final needsAttention = _filtered
        .where((request) => _needsAttention(request, myUserId))
        .toList();
    final upcoming = _filtered
        .where((request) =>
            !needsAttention.contains(request) && _isUpcoming(request))
        .toList();
    final planning = _filtered
        .where((request) =>
            !needsAttention.contains(request) &&
            !upcoming.contains(request) &&
            !_isPostWatchDue(request))
        .toList();
    final postWatch = _filtered
        .where((request) =>
            !needsAttention.contains(request) && _isPostWatchDue(request))
        .toList();

    final children = <Widget>[];
    void addSection(String title, String subtitle, List<WatchRequest> items) {
      if (items.isEmpty) return;
      if (children.isNotEmpty) children.add(const SizedBox(height: 22));
      children.add(_RequestListSectionHeader(
        title: title,
        subtitle: subtitle,
        count: items.length,
      ));
      children.add(const SizedBox(height: 10));
      for (var i = 0; i < items.length; i++) {
        if (i > 0) children.add(const SizedBox(height: 10));
        children.add(_buildRequestCard(items[i], false, myUserId));
      }
    }

    addSection(
      'Needs reply',
      'Plans waiting for your response',
      needsAttention,
    );
    addSection('Upcoming', 'Your agreed watch plans', upcoming);
    addSection('Ready to wrap up', 'The planned time has passed', postWatch);
    addSection(
      'Scheduling in progress',
      'Invites waiting or being arranged',
      planning,
    );

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: children,
      ),
    );
  }

  bool _needsAttention(WatchRequest request, String myUserId) {
    final isIncoming = request.requesterId != myUserId &&
        (request.recipientId == myUserId ||
            request.participantFor(myUserId) != null);
    final proposal = request.latestPendingProposal;
    return (request.isPending && isIncoming) ||
        (proposal != null && proposal.proposerId != myUserId);
  }

  bool _isUpcoming(WatchRequest request) =>
      request.normalizedScheduleStatus == 'AGREED' &&
      request.scheduledFor != null &&
      request.scheduledFor!.isAfter(DateTime.now());

  Widget _buildRequestCard(
    WatchRequest request,
    bool isFocused,
    String myUserId,
  ) {
    return _WatchRequestCard(
      request: request,
      compact: !isFocused,
      myUserId: myUserId,
      formattedDate: _formatDate(request.createdAt),
      scheduledLabel: _formatFriendlyDateTime(request.scheduledFor),
      busyAction: _busyActions[request.id],
      acceptanceScheduleDraft: _acceptScheduleDrafts[request.id],
      onMovieTap: request.movieId != null
          ? () => context.push(movieDetailPath(
                request.movieId!,
                source: DetailSource.watchPlan,
              ))
          : null,
      onAccept: () => _acceptWithOptionalSchedule(request),
      onChooseAcceptanceSchedule: () => _chooseAcceptanceSchedule(request),
      onDecline: () => _respond(request, 'DECLINED'),
      onOpen: isFocused
          ? () => _refreshRequestState(request, myUserId)
          : () => context.push('/watch-requests/${request.id}'),
      onSuggestSchedule: () => _suggestSchedule(request),
      onSuggestDifferentTime: () =>
          _suggestSchedule(request, initial: request.scheduledFor),
      onEditLocation: () => _editLocation(request),
      onRespondToProposal: (proposal, decision) =>
          _respondToProposal(request, proposal, decision),
      onConfirmWatched: () => _confirmWatched(request),
      onCancelPlan: () => _cancelPlan(request),
      onClosePlan: () => _closeWatchPlan(request),
      candidateChoiceDraft: _candidateChoiceDraftFor(request, myUserId),
      onToggleCandidateChoice: (candidateId) =>
          _toggleCandidateChoice(request, myUserId, candidateId),
      onSaveCandidateChoices: () => _saveCandidateChoices(request, myUserId),
      onViewMovies: () => _viewMovieChoices(request, myUserId),
      onAddCandidate: () => _addCandidate(request, myUserId),
      onRemoveCandidate: (candidateId) =>
          _removeCandidate(request, myUserId, candidateId),
      onSelectCandidate: (candidateId) =>
          _selectFinalCandidate(request, candidateId),
      onChangeMovie: () => _reopenMovieChoices(request, myUserId),
    );
  }

  Set<String> _candidateChoiceDraftFor(WatchRequest request, String userId) {
    final persistedChoices = request.candidates
        .where((candidate) => candidate.selectedBy(userId))
        .map((candidate) => candidate.id)
        .toSet();
    // A one-title plan should not make someone choose the only option.
    if (persistedChoices.isEmpty && request.candidates.length == 1) {
      persistedChoices.add(request.candidates.single.id);
    }

    final draft = _candidateChoiceDrafts[request.id];
    if (draft == null || !_dirtyCandidateChoiceDraftIds.contains(request.id)) {
      final refreshed = Set<String>.of(persistedChoices);
      _candidateChoiceDrafts[request.id] = refreshed;
      return refreshed;
    }
    return draft;
  }

  void _toggleCandidateChoice(
    WatchRequest request,
    String userId,
    String candidateId,
  ) {
    setState(() {
      final draft = _candidateChoiceDraftFor(request, userId);
      if (!draft.add(candidateId)) draft.remove(candidateId);
      _dirtyCandidateChoiceDraftIds.add(request.id);
    });
  }

  Future<void> _saveCandidateChoices(
    WatchRequest request,
    String userId, {
    bool showSuccessToast = true,
  }) async {
    if (request.requesterId != userId &&
        !request.isAccepted &&
        !request.isScheduled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accept this Watch Plan before choosing movies.'),
          backgroundColor: FlixieColors.warning,
        ),
      );
      return;
    }
    final candidateIds = _candidateChoiceDraftFor(request, userId).toList();
    if (candidateIds.isEmpty) return;
    await _withRequestAction(request, _RequestAction.savingMovieChoices,
        () async {
      try {
        final state = await RequestService.submitWatchPlanChoices(
          watchRequestId: request.id,
          userId: userId,
          candidateIds: candidateIds,
        );
        _candidateChoiceDrafts.remove(request.id);
        _dirtyCandidateChoiceDraftIds.remove(request.id);
        _replaceRequest(state.request);
        if (!mounted) return;
        if (showSuccessToast) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Movie choices saved'),
              backgroundColor: FlixieColors.surfaceElevated,
            ),
          );
        }
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save movie choices. Please try again.'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    });
  }

  Future<void> _viewMovieChoices(WatchRequest request, String userId) async {
    final selected = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CandidateChoicesSheet(request: request, userId: userId),
    );
    if (!mounted || selected == null) return;
    setState(() {
      _candidateChoiceDrafts[request.id] = selected.toSet();
      _dirtyCandidateChoiceDraftIds.add(request.id);
    });
    await _saveCandidateChoices(request, userId, showSuccessToast: false);
  }

  Future<void> _addCandidate(WatchRequest request, String userId) async {
    if (request.candidates.length >= 5) return;
    final movie = await showModalBottomSheet<MovieShort>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.surface,
      builder: (_) => MovieSearchSheet(
        title: 'Add another option',
        searchMovies: (query) async {
          final search = await SearchService.search(query, type: 'movie');
          final existingMovieIds = request.candidates
              .map((candidate) => candidate.movieId)
              .whereType<int>()
              .toSet();
          return search.results
              .where((item) => item.movie != null)
              .map((item) => item.movie!)
              .where((movie) => !existingMovieIds.contains(movie.id))
              .toList(growable: false);
        },
      ),
    );
    if (!mounted || movie == null) return;
    await _withRequestAction(request, _RequestAction.scheduling, () async {
      final state = await RequestService.addWatchPlanCandidate(
        watchRequestId: request.id,
        userId: userId,
        movieId: movie.id,
      );
      _candidateChoiceDrafts.remove(request.id);
      _dirtyCandidateChoiceDraftIds.remove(request.id);
      _replaceRequest(state.request);
    });
  }

  Future<void> _removeCandidate(
    WatchRequest request,
    String userId,
    String candidateId,
  ) async {
    await _withRequestAction(request, _RequestAction.removingCandidate,
        () async {
      try {
        final state = await RequestService.removeWatchPlanCandidate(
          watchRequestId: request.id,
          userId: userId,
          candidateId: candidateId,
        );
        _candidateChoiceDrafts.remove(request.id);
        _dirtyCandidateChoiceDraftIds.remove(request.id);
        _replaceRequest(state.request);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Movie option removed'),
          backgroundColor: FlixieColors.surfaceElevated,
        ));
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not remove that movie option.'),
          backgroundColor: FlixieColors.danger,
        ));
      }
    });
  }

  Future<void> _selectFinalCandidate(
    WatchRequest request,
    String candidateId,
  ) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    final candidate =
        request.candidates.where((item) => item.id == candidateId).firstOrNull;
    if (candidate == null) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          decoration: const BoxDecoration(
            color: FlixieColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FlixieColors.medium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Make this the final movie?',
                style: TextStyle(
                  color: FlixieColors.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${candidate.title ?? 'This movie'} will be locked in for this Watch Plan. Everyone will be notified.',
                style: const TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 15,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.lock_rounded),
                  label: const Text('Make final choice'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    await _withRequestAction(request, _RequestAction.selectingMovie, () async {
      try {
        final state = await RequestService.selectWatchPlanCandidate(
          watchRequestId: request.id,
          userId: userId,
          candidateId: candidateId,
        );
        _replaceRequest(state.request);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${candidate.title ?? 'Movie'} chosen for this Watch Plan'),
            backgroundColor: FlixieColors.surfaceElevated,
          ),
        );
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not choose this movie. Please try again.'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    });
  }

  Future<void> _reopenMovieChoices(WatchRequest request, String userId) async {
    await _withRequestAction(request, _RequestAction.selectingMovie, () async {
      try {
        final state = await RequestService.reopenWatchPlanMovieChoices(
          watchRequestId: request.id,
          userId: userId,
        );
        _replaceRequest(state.request);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Movie choices reopened')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not reopen movie choices.'),
              backgroundColor: FlixieColors.danger,
            ),
          );
        }
      }
    });
  }

  String _filterLabel(_StatusFilter f) {
    switch (f) {
      case _StatusFilter.active:
        return 'Active';
      case _StatusFilter.needsResponse:
        return 'Needs reply ${_countFor(_StatusFilter.needsResponse)}';
      case _StatusFilter.planning:
        return 'Planning';
      case _StatusFilter.scheduled:
        return 'Upcoming ${_countFor(_StatusFilter.scheduled)}';
      case _StatusFilter.completed:
        return 'Past';
      case _StatusFilter.declined:
        return 'Declined';
      case _StatusFilter.cancelled:
        return 'Cancelled';
      case _StatusFilter.expired:
        return 'Expired';
    }
  }

  int _countFor(_StatusFilter filter) {
    return _all.where((request) => _matchesFilter(request, filter)).length;
  }

  String _responseSuccessMessage(String response) {
    return switch (response) {
      'ACCEPTED' => 'Watch Plan accepted.',
      'DECLINED' => 'Watch Plan declined.',
      _ => 'Marked as maybe.',
    };
  }

  String _responseFailureMessage(String response) {
    return switch (response) {
      'ACCEPTED' => 'Failed to accept. Please try again.',
      'DECLINED' => 'Failed to decline. Please try again.',
      _ => 'Failed to mark maybe. Please try again.',
    };
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.group_outlined,
              size: 64, color: FlixieColors.medium),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isNotEmpty ||
                    _statusFilter != _StatusFilter.active
                ? 'No Watch Plans match'
                : 'No Watch Plans yet',
            style: const TextStyle(color: FlixieColors.medium, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: FlixieColors.danger, size: 48),
          const SizedBox(height: 16),
          Text(_error!, style: const TextStyle(color: FlixieColors.light)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _load, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _AudienceSwitcher extends StatelessWidget {
  const _AudienceSwitcher({
    required this.selected,
    required this.onChanged,
  });

  final _RequestAudience selected;
  final ValueChanged<_RequestAudience> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: FlixieColors.primary.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          _item(_RequestAudience.friends, 'Friends', Icons.group_outlined),
          _item(_RequestAudience.groups, 'Groups', Icons.groups_2_outlined),
        ],
      ),
    );
  }

  Widget _item(_RequestAudience value, String label, IconData icon) {
    final isSelected = selected == value;
    return Expanded(
      child: InkWell(
        onTap: () => onChanged(value),
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? FlixieColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? Colors.white : FlixieColors.medium),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : FlixieColors.medium,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _RequestListSectionHeader extends StatelessWidget {
  const _RequestListSectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: FlixieColors.primary.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: FlixieColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanRecipient {
  const _PlanRecipient({
    required this.id,
    required this.name,
    required this.isGroup,
  });

  final String id;
  final String name;
  final bool isGroup;
}

class _PlanRecipientSheet extends StatefulWidget {
  const _PlanRecipientSheet({required this.friends, required this.groups});

  final List<Friendship> friends;
  final List<Group> groups;

  @override
  State<_PlanRecipientSheet> createState() => _PlanRecipientSheetState();
}

class _PlanRecipientSheetState extends State<_PlanRecipientSheet> {
  final _searchController = TextEditingController();
  bool _showGroups = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final friends = widget.friends
        .map((friendship) => friendship.friendUser)
        .whereType<FriendshipUser>()
        .where((friend) =>
            query.isEmpty || friend.displayName.toLowerCase().contains(query))
        .toList(growable: false);
    final groups = widget.groups
        .where((group) =>
            group.id != null &&
            (query.isEmpty || group.name.toLowerCase().contains(query)))
        .toList(growable: false);
    final items = _showGroups ? groups : friends;

    return SafeArea(
      child: Material(
        color: FlixieColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: FlixieColors.medium,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Who are you watching with?',
                  style: TextStyle(
                    color: FlixieColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Choose a friend or group first. You can pick the movie next.',
                  style: TextStyle(color: FlixieColors.medium),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _RecipientTypeButton(
                        label: 'Friends',
                        icon: Icons.person_outline_rounded,
                        selected: !_showGroups,
                        onTap: () => setState(() => _showGroups = false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RecipientTypeButton(
                        label: 'Groups',
                        icon: Icons.groups_2_outlined,
                        selected: _showGroups,
                        onTap: () => setState(() => _showGroups = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: _showGroups ? 'Search groups' : 'Search friends',
                    prefixIcon: const Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            _showGroups
                                ? 'No groups found'
                                : 'No friends found',
                            style: const TextStyle(color: FlixieColors.medium),
                          ),
                        )
                      : ListView.separated(
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const Divider(
                            color: FlixieColors.tabBarBorder,
                            height: 1,
                          ),
                          itemBuilder: (context, index) {
                            if (_showGroups) {
                              final group = groups[index];
                              return ListTile(
                                minVerticalPadding: 8,
                                visualDensity: VisualDensity.standard,
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                leading: const CircleAvatar(
                                  child: Icon(Icons.groups_2_outlined),
                                ),
                                title: Text(group.name),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pop(
                                  context,
                                  _PlanRecipient(
                                    id: group.id!,
                                    name: group.name,
                                    isGroup: true,
                                  ),
                                ),
                              );
                            }
                            final friend = friends[index];
                            return ListTile(
                              minVerticalPadding: 8,
                              visualDensity: VisualDensity.standard,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              leading: ProfileAvatarView(
                                avatar: friend.avatar,
                                fallbackText: friend
                                    .displayName.characters.first
                                    .toUpperCase(),
                                fallbackColor: FlixieColors.primary,
                                size: 40,
                                profileBadges: friend.profileBadges,
                              ),
                              title: Text(friend.displayName),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pop(
                                context,
                                _PlanRecipient(
                                  id: friend.id,
                                  name: friend.displayName,
                                  isGroup: false,
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipientTypeButton extends StatelessWidget {
  const _RecipientTypeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return selected
        ? FilledButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onTap,
            icon: Icon(icon, size: 18),
            label: Text(label),
            style: OutlinedButton.styleFrom(
              foregroundColor: FlixieColors.light,
              side: const BorderSide(color: FlixieColors.tabBarBorder),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
  }
}

class _WatchRequestCard extends StatelessWidget {
  const _WatchRequestCard({
    required this.request,
    required this.compact,
    required this.myUserId,
    required this.formattedDate,
    required this.scheduledLabel,
    required this.onAccept,
    required this.onDecline,
    required this.onOpen,
    required this.onSuggestSchedule,
    required this.onSuggestDifferentTime,
    required this.onEditLocation,
    required this.onRespondToProposal,
    required this.onConfirmWatched,
    required this.onCancelPlan,
    required this.onClosePlan,
    required this.onChooseAcceptanceSchedule,
    required this.candidateChoiceDraft,
    required this.onToggleCandidateChoice,
    required this.onSaveCandidateChoices,
    required this.onViewMovies,
    required this.onAddCandidate,
    required this.onRemoveCandidate,
    required this.onSelectCandidate,
    required this.onChangeMovie,
    this.onMovieTap,
    this.busyAction,
    this.acceptanceScheduleDraft,
  });

  final WatchRequest request;
  final bool compact;
  final String myUserId;
  final String formattedDate;
  final String scheduledLabel;
  final VoidCallback? onMovieTap;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpen;
  final VoidCallback onSuggestSchedule;
  final VoidCallback onSuggestDifferentTime;
  final VoidCallback onEditLocation;
  final void Function(WatchScheduleProposal proposal, String decision)
      onRespondToProposal;
  final VoidCallback onConfirmWatched;
  final VoidCallback onCancelPlan;
  final VoidCallback onClosePlan;
  final VoidCallback onChooseAcceptanceSchedule;
  final Set<String> candidateChoiceDraft;
  final ValueChanged<String> onToggleCandidateChoice;
  final VoidCallback onSaveCandidateChoices;
  final VoidCallback onViewMovies;
  final VoidCallback onAddCandidate;
  final ValueChanged<String> onRemoveCandidate;
  final ValueChanged<String> onSelectCandidate;
  final VoidCallback onChangeMovie;
  final _RequestAction? busyAction;
  final _AcceptanceScheduleDraft? acceptanceScheduleDraft;

  Color get _statusColor {
    if (request.normalizedWatchedStatus == 'WATCHED') {
      return FlixieColors.primary;
    }
    if (request.normalizedWatchedStatus == 'NOT_WATCHED') {
      return FlixieColors.danger;
    }
    if (request.normalizedScheduleStatus == 'AGREED') {
      return FlixieColors.secondary;
    }
    if (request.normalizedScheduleStatus == 'PROPOSED') {
      return FlixieColors.warning;
    }
    if (request.isAccepted) return FlixieColors.success;
    if (request.isDeclined) return FlixieColors.danger;
    return FlixieColors.warning;
  }

  IconData get _statusIcon {
    if (request.normalizedWatchedStatus == 'WATCHED') {
      return Icons.check_circle;
    }
    if (request.normalizedWatchedStatus == 'NOT_WATCHED') {
      return Icons.cancel_outlined;
    }
    if (request.normalizedScheduleStatus == 'AGREED') {
      return Icons.event_available_outlined;
    }
    if (request.normalizedScheduleStatus == 'PROPOSED') {
      return Icons.schedule_send_outlined;
    }
    if (request.isAccepted) return Icons.check_circle_outline;
    if (request.isDeclined) return Icons.cancel_outlined;
    return Icons.hourglass_top_outlined;
  }

  String get _statusLabel => request.planStageFor(myUserId).label;

  @override
  Widget build(BuildContext context) {
    final other = request.otherUser(myUserId);
    final isSent = request.requesterId == myUserId;
    final movie = request.movie;
    final choosingMovie =
        request.selectedCandidateId == null && request.candidates.length > 1;

    final posterUrl = movie?.posterPath != null
        ? 'https://image.tmdb.org/t/p/w185${movie!.posterPath}'
        : null;

    if (!compact) {
      return _buildFullDetail(context, other, isSent, movie, posterUrl);
    }

    if (_useOverviewPlanCards) {
      return _buildOverviewPlanCard(context, other, movie, posterUrl);
    }

    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _statusColor.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            if (choosingMovie) const SizedBox(width: 12),
            GestureDetector(
              onTap: onMovieTap,
              child: choosingMovie
                  ? _buildCandidatePosterStack()
                  : ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(12)),
                      child: SizedBox(
                        width: 92,
                        height: 138,
                        child: posterUrl != null
                            ? CachedNetworkImage(
                                imageUrl: posterUrl,
                                fit: BoxFit.cover,
                                placeholder: (_, __) =>
                                    const _PosterPlaceholder(),
                                errorWidget: (_, __, ___) =>
                                    const _PosterPlaceholder(),
                              )
                            : const _PosterPlaceholder(),
                      ),
                    ),
            ),
            // Details
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _smallUserAvatar(other),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                  color: FlixieColors.medium, fontSize: 12),
                              children: [
                                TextSpan(
                                  text: request.groupName?.isNotEmpty == true
                                      ? request.groupName
                                      : other?.username ?? 'Friend',
                                  style: const TextStyle(
                                    color: FlixieColors.light,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(
                                    text: isSent ? ' invited' : ' invited you'),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.more_horiz_rounded,
                            color: FlixieColors.medium, size: 20),
                      ],
                    ),
                    const SizedBox(height: 5),
                    GestureDetector(
                      onTap: onMovieTap,
                      child: Text(
                        choosingMovie
                            ? '${request.candidates.length} movie options'
                            : movie?.title ?? 'Unknown Movie',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.primary,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    if (choosingMovie) ...[
                      const SizedBox(height: 6),
                      Text(
                        request.candidates
                            .map((candidate) => candidate.title ?? 'Untitled')
                            .join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.medium, fontSize: 12),
                      ),
                    ],
                    if (compact) ...[
                      if (_effectiveWatchTime != null) ...[
                        const SizedBox(height: 6),
                        _CompactWatchDetail(
                          icon: Icons.schedule_outlined,
                          text: _dateLabel(_effectiveWatchTime),
                        ),
                      ],
                      if (_effectiveLocation?.isNotEmpty == true) ...[
                        const SizedBox(height: 5),
                        _CompactWatchDetail(
                          icon: Icons.location_on_outlined,
                          text: _effectiveLocation!,
                        ),
                      ],
                      if (request.message?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 7),
                        Text(request.message!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: FlixieColors.medium, fontSize: 12)),
                      ],
                      // This card intentionally grows with its content. A
                      // Spacer would require a bounded height here and can
                      // corrupt the semantics/layout pass after the card is
                      // rebuilt.
                      const SizedBox(height: 8),
                      _buildCompactActions(),
                    ],
                    // Detail-only content
                    if (!compact &&
                        request.message != null &&
                        request.message!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '"${request.message}"',
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (!compact &&
                        (_effectiveWatchTime != null ||
                            _effectiveLocation?.isNotEmpty == true)) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: FlixieColors.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: FlixieColors.tabBarBorder,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_effectiveWatchTime != null)
                              _WatchDetailRow(
                                icon: request.scheduledFor != null
                                    ? Icons.event_available_outlined
                                    : Icons.schedule_outlined,
                                label: request.scheduledFor != null ||
                                        request.normalizedScheduleStatus ==
                                            'AGREED'
                                    ? 'Scheduled'
                                    : 'Proposed time',
                                value: _dateLabel(_effectiveWatchTime),
                              ),
                            if (_effectiveWatchTime != null &&
                                _effectiveLocation?.isNotEmpty == true)
                              const SizedBox(height: 8),
                            if (_effectiveLocation?.isNotEmpty == true)
                              _WatchDetailRow(
                                icon: Icons.location_on_outlined,
                                label: 'Location',
                                value: _effectiveLocation!,
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (!compact) const SizedBox(height: 12),
                    // Accept/Decline buttons for pending requests (if recipient)
                    if (!compact)
                      _LifecycleSummary(
                        request: request,
                        scheduledLabel: _scheduleSummaryLabel(),
                        myUserId: myUserId,
                      ),
                    if (!compact && _proposalNoteText != null) ...[
                      const SizedBox(height: 7),
                      _ProposalNote(text: _proposalNoteText!),
                    ],
                    if (!compact) ...[
                      const SizedBox(height: 10),
                      _buildActions(),
                      const SizedBox(height: 8),
                    ],
                    // Status badge + date
                    if (!compact)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _statusColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_statusIcon,
                                    size: 12, color: _statusColor),
                                const SizedBox(width: 4),
                                Text(
                                  _statusLabel,
                                  style: TextStyle(
                                    color: _statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (formattedDate.isNotEmpty)
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Keeps the prior compact card as a low-risk fallback while the refreshed
  // overview is rolled out.
  bool get _useOverviewPlanCards => true;

  Widget _buildOverviewPlanCard(
    BuildContext context,
    WatchRequestUser? other,
    WatchRequestMovieDetails? movie,
    String? posterUrl,
  ) {
    final time = _effectiveWatchTime;
    final isPast = time != null && !time.isAfter(DateTime.now());
    final incoming = request.isPending && request.requesterId != myUserId;
    final hasLogged = request.hasCurrentUserLoggedWatch == true ||
        request.watchConfirmations.any((entry) => entry.userId == myUserId);
    final label = isPast
        ? 'DID YOU WATCH IT?'
        : incoming
            ? 'NEEDS REPLY · ${request.candidates.length} MOVIE OPTIONS'
            : request.normalizedScheduleStatus == 'AGREED'
                ? 'SCHEDULED'
                : 'PLANNING TOGETHER';
    final actionLabel = isPast && !hasLogged
        ? 'Log watch'
        : incoming
            ? 'Choose movies'
            : 'View plan';
    final action = isPast && !hasLogged ? onConfirmWatched : onOpen;
    final title = movie?.title ??
        request.candidates
            .where((candidate) => candidate.id == request.selectedCandidateId)
            .map((candidate) => candidate.title)
            .firstOrNull ??
        '${request.candidates.length} movie options';
    return Material(
      color: FlixieColors.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          constraints: const BoxConstraints(minHeight: 164),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // A 320px phone only leaves about 256px inside this card. Keep
              // the essential plan details together at the top, then place
              // context and the CTA on their own, readable row below.
              final useStackedFooter = constraints.maxWidth < 350;
              final posterWidth = useStackedFooter ? 82.0 : 72.0;
              final posterHeight = posterWidth * 1.5;
              final participantText = isPast &&
                      other != null &&
                      request.watchConfirmations
                          .any((entry) => entry.userId == other.id)
                  ? '${other.username} has logged'
                  : 'With ${other?.username ?? 'your group'}';

              final poster = ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: posterWidth,
                  height: posterHeight,
                  child: posterUrl == null
                      ? const _PosterPlaceholder()
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              const _PosterPlaceholder(),
                        ),
                ),
              );
              final details = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    style: TextStyle(
                      color: isPast
                          ? FlixieColors.secondary
                          : FlixieColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    style: const TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(
                      Icons.event_outlined,
                      size: 18,
                      color: FlixieColors.medium,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        time == null ? 'Time to be agreed' : _dateLabel(time),
                        maxLines: 2,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ]),
                ],
              );
              final participant = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _smallUserAvatar(other),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      participantText,
                      maxLines: 2,
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              );
              final actionButton = FilledButton(
                onPressed: action,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(actionLabel),
              );

              if (useStackedFooter) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        poster,
                        const SizedBox(width: 14),
                        Expanded(child: details),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(color: FlixieColors.tabBarBorder),
                    ),
                    Row(children: [
                      Expanded(child: participant),
                      const SizedBox(width: 12),
                      actionButton,
                    ]),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  poster,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        details,
                        const SizedBox(height: 12),
                        participant
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: posterHeight,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: actionButton,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCandidatePosterStack() {
    final candidates = request.candidates.take(3).toList(growable: false);
    return SizedBox(
      width: 126,
      height: 190,
      child: ClipRect(
        child: Stack(
          children: [
            for (var index = candidates.length - 1; index >= 0; index--)
              Positioned(
                left: index * 10.0,
                top: 12 + index * 7.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 78,
                    height: 136,
                    child: candidates[index].posterPath == null
                        ? const _PosterPlaceholder()
                        : CachedNetworkImage(
                            imageUrl:
                                'https://image.tmdb.org/t/p/w185${candidates[index].posterPath}',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const _PosterPlaceholder(),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullDetail(
    BuildContext context,
    WatchRequestUser? other,
    bool isSent,
    WatchRequestMovieDetails? movie,
    String? posterUrl,
  ) {
    final hasCompleted =
        request.isCompleted || request.normalizedWatchedStatus == 'WATCHED';
    if (hasCompleted && request.watchConfirmations.isNotEmpty) {
      return _buildCompletedFriendRecap(
        context,
        other: other,
        movie: movie,
        posterUrl: posterUrl,
      );
    }
    final postWatchTime = _effectiveWatchTime;
    if (postWatchTime != null &&
        !postWatchTime.isAfter(DateTime.now()) &&
        (request.selectedCandidateId != null ||
            request.movie != null ||
            request.candidates.isNotEmpty)) {
      return _buildPostWatchLifecycle(context, other, movie, posterUrl);
    }
    final companion = request.groupName?.trim().isNotEmpty == true
        ? request.groupName!
        : other?.username ?? 'your group';
    final pendingSchedule = request.latestPendingProposal;
    final hasPendingSchedule = request.normalizedScheduleStatus == 'PROPOSED' &&
        pendingSchedule != null &&
        pendingSchedule.proposedFor != null;
    final canMessage =
        request.groupId?.isEmpty != false && other?.id.isNotEmpty == true;
    final hasChoices = request.isAccepted &&
        request.candidates
            .any((candidate) => candidate.selectedByUserIds.isNotEmpty);
    final hasSchedule = request.normalizedScheduleStatus == 'AGREED';
    final hasWatched =
        request.isCompleted || request.normalizedWatchedStatus == 'WATCHED';
    Color stageColor(bool complete) =>
        complete ? FlixieColors.success : FlixieColors.tabBarBorder;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 2, 0, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_rounded, size: 16, color: FlixieColors.success),
              SizedBox(width: 7),
              Text('PLANNING TOGETHER',
                  style: TextStyle(
                      color: FlixieColors.success,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4)),
            ]),
            const SizedBox(height: 10),
            Text(
                request.selectedCandidateId == null
                    ? 'Planning a watch together'
                    : movie?.title ?? 'Watch Plan',
                style: const TextStyle(
                    color: FlixieColors.primary,
                    fontSize: 22,
                    height: 1.08,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Row(children: [
              _smallUserAvatar(other),
              const SizedBox(width: 10),
              Expanded(
                  child: Text('With $companion',
                      style: const TextStyle(
                          color: FlixieColors.light, fontSize: 14))),
            ]),
            const Divider(height: 20, color: FlixieColors.tabBarBorder),
            _PlanOverviewRow(
              icon: Icons.calendar_month_outlined,
              label: _effectiveWatchTime == null
                  ? 'Time undecided'
                  : _dateLabel(_effectiveWatchTime),
              action: 'Edit',
              onTap: onSuggestDifferentTime,
            ),
            const SizedBox(height: 5),
            _PlanOverviewRow(
              icon: Icons.location_on_outlined,
              label: _effectiveLocation ?? 'Decide where to watch',
              action: 'Edit',
              onTap: onEditLocation,
            ),
            const SizedBox(height: 5),
            _PlanOverviewRow(
              icon: Icons.movie_filter_outlined,
              label:
                  '${request.candidates.length} movie option${request.candidates.length == 1 ? '' : 's'}',
              action: 'View',
              onTap: onViewMovies,
            ),
          ]),
        ),
        const SizedBox(height: 14),
        // A creation-time date is only actionable once this person has
        // accepted the invitation. Showing it earlier puts two competing
        // decisions on screen and makes it look as though the invite is
        // already confirmed.
        if (hasPendingSchedule && request.isAccepted) ...[
          _PlanSurface(
            child: _ScheduleConfirmationCard(
              proposedFor: pendingSchedule.proposedFor!,
              awaitingOtherPerson: pendingSchedule.proposerId == myUserId,
              onConfirm: () => onRespondToProposal(pendingSchedule, 'accepted'),
              onChange: onSuggestDifferentTime,
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (_isIncomingInvitation) ...[
          _PlanSurface(child: _buildInvitationDecisionActions()),
          const SizedBox(height: 14),
        ],
        if (request.candidates.isNotEmpty) ...[
          _PlanSurface(child: _buildCandidateChoices()),
          const SizedBox(height: 14),
        ],
        _PlanSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Plan progress',
                style: TextStyle(
                    color: FlixieColors.light,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            _buildParticipants(other),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: Divider(color: stageColor(true), thickness: 4)),
              SizedBox(width: 10),
              Expanded(
                  child: Divider(color: stageColor(hasChoices), thickness: 4)),
              SizedBox(width: 10),
              Expanded(
                  child: Divider(color: stageColor(hasSchedule), thickness: 4)),
              SizedBox(width: 10),
              Expanded(
                  child: Divider(color: stageColor(hasWatched), thickness: 4)),
            ]),
            const SizedBox(height: 10),
            const Text('Invited → Choose together → Scheduled → Watched',
                style: TextStyle(color: FlixieColors.medium, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 14),
        if (request.selectedCandidateId != null &&
            !request.hasCurrentUserConfirmed(myUserId)) ...[
          _PlanSurface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Watched it already?',
                  style: TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              const Text(
                  'Log the watch now, even if you watched before the planned time.',
                  style: TextStyle(color: FlixieColors.light, fontSize: 13)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onConfirmWatched,
                  icon:
                      const Icon(Icons.check_circle_outline_rounded, size: 18),
                  label: const Text('Log watch early'),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        _PlanSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Text('Next step',
                      style: TextStyle(
                          color: FlixieColors.light,
                          fontSize: 19,
                          fontWeight: FontWeight.w800))),
              Text(request.requesterId == myUserId ? 'PLAN OWNER' : 'WAITING',
                  style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 11,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 8),
            Text(
                request.requesterId == myUserId
                    ? 'After everyone responds, choose the final movie and add the final time.'
                    : 'Choose the movies you would watch, then wait for the plan owner to make the final pick.',
                style: const TextStyle(
                    color: FlixieColors.medium, fontSize: 14, height: 1.35)),
            if (canMessage) ...[
              const SizedBox(height: 16),
              SizedBox(
                  width: double.infinity,
                  child: _PrimaryActionButton(
                    label: 'Message $companion',
                    onPressed: () => context.push('/chat/${other!.id}'),
                  )),
            ],
          ]),
        ),
      ]),
    );
  }

  // Kept temporarily while the redesigned plan detail is rolled out; it
  // remains a useful reference for the completed-plan and edge-state copy.
  // ignore: unused_element
  Widget _buildLegacyFullDetail(
    BuildContext context,
    WatchRequestUser? other,
    bool isSent,
    WatchRequestMovieDetails? movie,
    String? posterUrl,
  ) {
    final hasSelectedMovie = request.selectedCandidateId != null;
    final currentUserConfirmation = request.watchConfirmations
        .where((confirmation) => confirmation.userId == myUserId)
        .firstOrNull;
    final hasLoggedWatch = request.hasCurrentUserLoggedWatch == true ||
        currentUserConfirmation?.watched == true;
    final hasRatedWatch = currentUserConfirmation?.watched == true &&
        currentUserConfirmation?.rating != null;
    final isAfterWatchTime = _effectiveWatchTime != null &&
        !_effectiveWatchTime!.isAfter(DateTime.now());
    final canLogThisWatch = request.canCompleteFor(myUserId) && !hasLoggedWatch;
    final isWatchFinished =
        request.isCompleted || request.normalizedWatchedStatus == 'WATCHED';
    // Older plans can carry the final title on `movie` without populating
    // selectedCandidateId, so support both representations.
    if ((hasSelectedMovie ||
            request.movie != null ||
            request.candidates.isNotEmpty) &&
        isAfterWatchTime) {
      return _buildPostWatchLifecycle(context, other, movie, posterUrl);
    }
    // Show the recap as soon as this person has logged their watch. The
    // second person's rating can then arrive into the same recap instead of
    // leaving the first person on the old, past-plan detail screen.
    if ((isWatchFinished || hasLoggedWatch) &&
        request.watchConfirmations.isNotEmpty) {
      return _buildCompletedFriendRecap(
        context,
        other: other,
        movie: movie,
        posterUrl: posterUrl,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                hasSelectedMovie
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: onMovieTap,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                width: 116,
                                height: 174,
                                child: posterUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: posterUrl,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            const _PosterPlaceholder(),
                                      )
                                    : const _PosterPlaceholder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(movie?.title ?? 'Watch plan',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: FlixieColors.primary,
                                        fontSize: 24,
                                        height: 1.05,
                                        fontWeight: FontWeight.w900)),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _smallUserAvatar(other),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        request.groupName?.trim().isNotEmpty ==
                                                true
                                            ? 'With ${request.groupName}'
                                            : 'With ${other?.username ?? 'a friend'}',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: FlixieColors.light,
                                            fontSize: 14),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 13),
                                _DetailStatusBadge(
                                    icon: _statusIcon,
                                    label: _statusLabel,
                                    color: _statusColor),
                                if (formattedDate.isNotEmpty) ...[
                                  const SizedBox(height: 9),
                                  Text('Requested $formattedDate',
                                      style: const TextStyle(
                                          color: FlixieColors.medium,
                                          fontSize: 11)),
                                ],
                                if (!isWatchFinished &&
                                    isSent &&
                                    request.selectedCandidateId != null) ...[
                                  const SizedBox(height: 8),
                                  TextButton.icon(
                                    onPressed: busyAction ==
                                            _RequestAction.selectingMovie
                                        ? null
                                        : onChangeMovie,
                                    icon: const Icon(Icons.edit_outlined,
                                        size: 16),
                                    label: const Text('Change movie'),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 32),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Planning a watch together',
                            style: TextStyle(
                              color: FlixieColors.primary,
                              fontSize: 22,
                              height: 1.05,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _smallUserAvatar(other),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  request.groupName?.trim().isNotEmpty == true
                                      ? 'With ${request.groupName}'
                                      : 'With ${other?.username ?? 'a friend'}',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FlixieColors.light,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 13),
                          _DetailStatusBadge(
                            icon: _statusIcon,
                            label: _statusLabel,
                            color: _statusColor,
                          ),
                          if (formattedDate.isNotEmpty) ...[
                            const SizedBox(height: 9),
                            Text(
                              'Requested $formattedDate',
                              style: const TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                if (request.groupId?.isEmpty != false &&
                    other?.id.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  const Divider(
                    height: 1,
                    color: FlixieColors.tabBarBorder,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.forum_outlined,
                        color: FlixieColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Need to plan something?',
                          style: TextStyle(
                            color: FlixieColors.light,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => context.push('/chat/${other!.id}'),
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: Text('Message ${other?.username ?? 'them'}'),
                        style: TextButton.styleFrom(
                          foregroundColor: FlixieColors.primary,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_isIncomingInvitation) ...[
            _PlanSurface(child: _buildInvitationDecisionActions()),
            const SizedBox(height: 12),
          ],
          if (_hasPlanningAction) ...[
            _PlanSurface(child: _buildActions(includeWatchConfirmation: false)),
            const SizedBox(height: 12),
          ],
          // Once a title is locked in, leave the candidate history available
          // without making it compete with the actual Watch Plan details.
          if (request.candidates.isNotEmpty) ...[
            _PlanSurface(
              child: request.selectedCandidateId == null
                  ? _buildCandidateChoices()
                  : Material(
                      color: Colors.transparent,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          // Keep the collapsed row aligned with the 14px
                          // surface inset instead of adding a tall default
                          // ListTile rhythm inside this compact summary card.
                          minTileHeight: 48,
                          visualDensity: const VisualDensity(vertical: -2),
                          initiallyExpanded: false,
                          leading: const Icon(
                            Icons.movie_filter_outlined,
                            color: FlixieColors.primary,
                          ),
                          title: const Text(
                            'Movie options',
                            style: TextStyle(
                              color: FlixieColors.light,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          subtitle: Text(
                            '${request.candidates.length} titles considered',
                            style: const TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 12,
                            ),
                          ),
                          iconColor: FlixieColors.primary,
                          collapsedIconColor: FlixieColors.medium,
                          children: [
                            const SizedBox(height: 4),
                            _buildCandidateChoices(),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 12),
          ],
          if (_effectiveWatchTime != null) ...[
            _PlanSurface(
              child: Column(
                children: [
                  if (canLogThisWatch) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isAfterWatchTime
                            ? "After you've watched"
                            : 'Watched early?',
                        style: TextStyle(
                          color: FlixieColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: onConfirmWatched,
                        icon: Icon(hasRatedWatch
                            ? Icons.check_circle_rounded
                            : hasLoggedWatch
                                ? Icons.star_rounded
                                : Icons.check_circle_outline_rounded),
                        label: Text(
                          isAfterWatchTime ? 'Log watch' : 'Log watch early',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: FlixieColors.success,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: FlixieColors.success,
                          disabledForegroundColor: Colors.black,
                          minimumSize: const Size(0, 48),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  _WatchDetailRow(
                    icon: Icons.event_available_outlined,
                    label:
                        request.scheduledFor != null ? 'Scheduled' : 'Proposed',
                    value: _dateLabel(_effectiveWatchTime),
                  ),
                  const SizedBox(height: 12),
                  _WatchDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: _effectiveLocation ?? 'Not set',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _PrimaryActionButton(
                          label: 'Add to calendar',
                          onPressed: () =>
                              WatchCalendarService.addScheduledWatch(
                            title: movie?.title ?? 'Watch together',
                            scheduledFor: _effectiveWatchTime!,
                            runtimeMinutes: movie?.runtimeMinutes,
                            note: request.message,
                            location: _effectiveLocation,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _SecondaryActionButton(
                          label: 'Edit plan',
                          onPressed: onSuggestDifferentTime,
                        ),
                      ),
                    ],
                  ),
                  if (request.normalizedScheduleStatus == 'AGREED' ||
                      request.isCompleted) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onClosePlan,
                        icon:
                            const Icon(Icons.visibility_off_outlined, size: 18),
                        label: const Text('Close watch plan'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: FlixieColors.light,
                          side: BorderSide(
                            color: FlixieColors.light.withValues(alpha: .45),
                          ),
                          minimumSize: const Size(0, 46),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _PlanSurface(child: _buildParticipants(other)),
          const SizedBox(height: 12),
          _PlanSurface(child: _buildPlanActivity()),
          if (request.message?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _PlanSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Message',
                      style:
                          TextStyle(color: FlixieColors.medium, fontSize: 13)),
                  const SizedBox(height: 7),
                  Text(request.message!.trim(),
                      style: const TextStyle(
                          color: FlixieColors.textPrimary,
                          fontSize: 14,
                          height: 1.4)),
                ],
              ),
            ),
          ],
          if (_shouldShowAfterWatchSection && !isAfterWatchTime) ...[
            const SizedBox(height: 12),
            _PlanSurface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("After you've watched",
                      style: TextStyle(
                          color: FlixieColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    hasLoggedWatch
                        ? 'Your watch is logged. Add a rating for this viewing.'
                        : 'Log every watch separately and rate this viewing.',
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: hasRatedWatch
                          ? null
                          : hasLoggedWatch
                              ? onMovieTap
                              : request.canCompleteFor(myUserId)
                                  ? onConfirmWatched
                                  : null,
                      icon: Icon(hasRatedWatch
                          ? Icons.check_circle_rounded
                          : hasLoggedWatch
                              ? Icons.star_outline_rounded
                              : Icons.check_circle_outline_rounded),
                      label: Text(
                        hasRatedWatch
                            ? 'Watch rated'
                            : hasLoggedWatch
                                ? 'Rate this watch'
                                : 'Log watch',
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: FlixieColors.success,
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: FlixieColors.success,
                        disabledForegroundColor: Colors.black,
                      ),
                    ),
                  ),
                  const Divider(height: 28, color: FlixieColors.tabBarBorder),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: onSuggestDifferentTime,
                          icon: const Icon(Icons.edit_calendar_outlined),
                          label: const Text('Reschedule'),
                        ),
                      ),
                      Expanded(
                        child: TextButton.icon(
                          onPressed: request.canCancelFor(myUserId)
                              ? onCancelPlan
                              : null,
                          icon: const Icon(Icons.block_outlined),
                          label: const Text('Cancel plan'),
                          style: TextButton.styleFrom(
                              foregroundColor: FlixieColors.danger),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (request.watchConfirmations.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PlanSurface(child: _buildPlanRatingsSummary(context)),
          ],
          if (request.groupId?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            _IconTextAction(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Open group chat',
              onPressed: () =>
                  context.push('/groups/${request.groupId}?tab=chat'),
            ),
          ],
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildPostWatchLifecycle(
    BuildContext context,
    WatchRequestUser? other,
    WatchRequestMovieDetails? movie,
    String? posterUrl,
  ) {
    final entries = request.watchConfirmations;
    final mine = entries.where((entry) => entry.userId == myUserId).firstOrNull;
    final otherEntry =
        entries.where((entry) => entry.userId != myUserId).firstOrNull;
    final myResolved = mine != null;
    final otherResolved = otherEntry != null;
    final state = request.isCompleted || (myResolved && otherResolved)
        ? _PostWatchState.recap
        : myResolved
            ? _PostWatchState.waitingForOthers
            : otherResolved
                ? _PostWatchState.waitingForMe
                : _PostWatchState.nobodyLogged;
    if (state == _PostWatchState.recap) {
      return _buildCompletedFriendRecap(context,
          other: other, movie: movie, posterUrl: posterUrl);
    }
    final scheduled = _effectiveWatchTime == null
        ? 'Planned watch'
        : _dateLabel(_effectiveWatchTime!);
    final title = movie?.title ?? request.movie?.title ?? 'Watch plan';
    final heading = switch (state) {
      _PostWatchState.nobodyLogged => 'Did the plan happen?',
      _PostWatchState.waitingForMe => 'Your turn',
      _PostWatchState.waitingForOthers =>
        'Waiting for ${other?.username ?? 'your friend'}',
      _PostWatchState.recap => 'Watch recap',
    };
    final copy = switch (state) {
      _PostWatchState.nobodyLogged =>
        'Log your viewing to add your rating and recommendation. Everyone responds separately.',
      _PostWatchState.waitingForMe =>
        '${other?.username ?? 'Your friend'} logged their watch. Add yours to unlock the shared recap and compare ratings.',
      _PostWatchState.waitingForOthers =>
        'Your watch is logged. Their rating stays hidden until they add their own take.',
      _PostWatchState.recap => '',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PlanSurface(
            child: Row(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                  width: 72,
                  height: 108,
                  child: posterUrl == null
                      ? const _PosterPlaceholder()
                      : CachedNetworkImage(
                          imageUrl: posterUrl, fit: BoxFit.cover))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    state == _PostWatchState.waitingForMe
                        ? '${other?.username ?? 'Friend'} LOGGED THEIRS'
                        : state == _PostWatchState.waitingForOthers
                            ? 'YOUR WATCH IS LOGGED'
                            : 'DID YOU WATCH IT?',
                    style: const TextStyle(
                        color: FlixieColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                    '$scheduled · ${_effectiveLocation ?? 'Location undecided'}',
                    style: const TextStyle(
                        color: FlixieColors.light, fontSize: 13)),
                const SizedBox(height: 10),
                Row(children: [
                  ProfileAvatarView(
                      avatar: context.read<AuthProvider>().dbUser?.avatar,
                      fallbackText: 'Y',
                      fallbackColor: FlixieColors.primary,
                      size: 26),
                  const SizedBox(width: 6),
                  ProfileAvatarView(
                      avatar: other?.avatar,
                      fallbackText: other?.username.isNotEmpty == true
                          ? other!.username[0].toUpperCase()
                          : '?',
                      fallbackColor: FlixieColors.primary,
                      size: 26),
                ]),
              ])),
        ])),
        const SizedBox(height: 12),
        _PlanSurface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(heading,
              style: const TextStyle(
                  color: FlixieColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(copy,
              style: const TextStyle(
                  color: FlixieColors.light, fontSize: 14, height: 1.4)),
          if (!myResolved) ...[
            const SizedBox(height: 18),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: onConfirmWatched,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(state == _PostWatchState.waitingForMe
                        ? 'Log your watch'
                        : 'Log watch'))),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              TextButton(
                  onPressed: () => _markNotThisTime(context, request),
                  child: const Text('Not this time')),
              TextButton(
                  onPressed: onSuggestDifferentTime,
                  child: const Text('Reschedule'))
            ])
          ],
        ])),
        const SizedBox(height: 12),
        _PlanSurface(
            child: _buildPostWatchStatus(context, other, mine, otherEntry)),
        if (state == _PostWatchState.waitingForMe) ...[
          const SizedBox(height: 12),
          _PlanSurface(
              child: const Text(
                  'Their rating is hidden for now. Log your own take before seeing theirs.',
                  style: TextStyle(color: FlixieColors.light, fontSize: 13)))
        ],
      ]),
    );
  }

  Widget _buildPostWatchStatus(BuildContext context, WatchRequestUser? other,
          WatchConfirmation? mine, WatchConfirmation? theirs) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            'WATCH STATUS · ${(mine != null ? 1 : 0) + (theirs != null ? 1 : 0)} OF 2',
            style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        const Divider(height: 22, color: FlixieColors.tabBarBorder),
        _postWatchPerson(
            'You', context.read<AuthProvider>().dbUser?.avatar, mine != null),
        const SizedBox(height: 12),
        _postWatchPerson(
            other?.username ?? 'Friend', other?.avatar, theirs != null),
      ]);

  Widget _postWatchPerson(String name, ProfileAvatar? avatar, bool resolved) =>
      Row(children: [
        ProfileAvatarView(
            avatar: avatar,
            fallbackText: name[0].toUpperCase(),
            fallbackColor: FlixieColors.primary,
            size: 42),
        const SizedBox(width: 10),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: FlixieColors.textPrimary,
                    fontWeight: FontWeight.w700))),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (resolved)
            const Icon(Icons.check_circle_rounded,
                color: FlixieColors.success, size: 18),
          if (resolved) const SizedBox(width: 5),
          Text(resolved ? 'Logged' : 'Waiting',
              style: TextStyle(
                  color: resolved ? FlixieColors.success : FlixieColors.light,
                  fontWeight: FontWeight.w700)),
        ]),
      ]);

  Future<void> _markNotThisTime(
      BuildContext context, WatchRequest target) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    await RequestService.confirmWatchRequest(
      watchRequestId: target.id,
      userId: userId,
      watched: false,
    );
    // The screen refreshes its request state when it regains focus; this also
    // keeps the stateless card free of duplicated state ownership.
  }

  Widget _buildCompletedFriendRecap(
    BuildContext context, {
    required WatchRequestUser? other,
    required WatchRequestMovieDetails? movie,
    required String? posterUrl,
  }) {
    final entries = request.watchConfirmations
        .where((entry) => entry.watched)
        .toList(growable: false);
    final ratings = entries
        .map((entry) => entry.rating)
        .whereType<int>()
        .toList(growable: false);
    final mine = entries.where((entry) => entry.userId == myUserId).firstOrNull;
    final theirs =
        entries.where((entry) => entry.userId != myUserId).firstOrNull;
    final average = ratings.isEmpty
        ? null
        : ratings.reduce((total, rating) => total + rating) / ratings.length;
    final difference = mine?.rating != null && theirs?.rating != null
        ? (mine!.rating! - theirs!.rating!).abs()
        : null;
    final scheduled =
        _effectiveWatchTime == null ? '' : _dateLabel(_effectiveWatchTime!);

    Widget surface(Widget child, {bool tinted = false}) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tinted
                ? FlixieColors.surfaceElevated.withValues(alpha: .7)
                : FlixieColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: child,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.check_rounded, color: FlixieColors.success),
            SizedBox(width: 8),
            Text('WATCHED TOGETHER',
                style: TextStyle(
                    color: FlixieColors.success,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 116,
                  height: 174,
                  child: posterUrl == null
                      ? const _PosterPlaceholder()
                      : CachedNetworkImage(
                          imageUrl: posterUrl, fit: BoxFit.cover),
                )),
            const SizedBox(width: 18),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(movie?.title ?? 'Watch plan',
                      style: const TextStyle(
                          color: FlixieColors.primary,
                          fontSize: 25,
                          fontWeight: FontWeight.w800)),
                  if (scheduled.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(scheduled,
                        style: const TextStyle(
                            color: FlixieColors.light, fontSize: 16))
                  ],
                  const SizedBox(height: 18),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                          color: FlixieColors.primary.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('👤 You + ${other?.username ?? 'friend'}',
                          style: const TextStyle(
                              color: FlixieColors.light,
                              fontWeight: FontWeight.w700))),
                ])),
          ]),
        ])),
        const SizedBox(height: 16),
        surface(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                    child: Text('How you matched',
                        style: TextStyle(
                            color: FlixieColors.light,
                            fontSize: 20,
                            fontWeight: FontWeight.w800))),
                Text(
                    '✓ ${difference == null ? 'RATINGS PENDING' : difference <= 1 ? 'CLOSE MATCH' : 'DIFFERENT TAKES'}',
                    style: const TextStyle(
                        color: FlixieColors.success,
                        fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _friendRatingTile('You', mine?.rating,
                        context.read<AuthProvider>().dbUser?.avatar)),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('VS',
                        style: TextStyle(
                            color: FlixieColors.medium,
                            fontWeight: FontWeight.w800))),
                Expanded(
                    child: _friendRatingTile(other?.username ?? 'Friend',
                        theirs?.rating, other?.avatar)),
              ]),
              if (difference != null) ...[
                const SizedBox(height: 14),
                Center(
                    child: Text(
                        difference == 0
                            ? '👍 You both gave it the same rating'
                            : '👍 ${difference == 1 ? 'Only 1 point apart' : '$difference points apart'}',
                        style: const TextStyle(
                            color: FlixieColors.success,
                            fontWeight: FontWeight.w800)))
              ],
            ]),
            tinted: true),
        const SizedBox(height: 22),
        Row(children: [
          const Expanded(
              child: Text('Your takes',
                  style: TextStyle(
                      color: FlixieColors.light,
                      fontSize: 20,
                      fontWeight: FontWeight.w800))),
          Text('${entries.length} watches logged',
              style: const TextStyle(color: FlixieColors.medium)),
        ]),
        const SizedBox(height: 12),
        ...entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _friendRecapEntry(
                entry,
                entry.userId == myUserId
                    ? context.read<AuthProvider>().dbUser?.username ?? 'You'
                    : other?.username ?? 'Friend',
                entry.userId == myUserId
                    ? context.read<AuthProvider>().dbUser?.avatar
                    : other?.avatar))),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
                  onPressed: other?.id == null
                      ? null
                      : () => context.push('/chat/${other!.id}'),
                  icon: const Icon(Icons.forum_outlined),
                  label: Text('Message ${other?.username ?? 'friend'}'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))))),
          const SizedBox(width: 12),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: mine?.rating == null || movie == null
                      ? null
                      : () => promptShareCard(
                          context,
                          ShareCardData.rating(
                              mediaType: ShareCardMediaType.movie,
                              mediaId: movie.id,
                              title: movie.title,
                              posterPath: movie.posterPath,
                              user: context.read<AuthProvider>().dbUser!,
                              rating: mine!.rating!,
                              note: mine!.reviewText)),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share recap'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))))),
        ]),
      ]),
    );
  }

  Widget _friendRatingTile(String name, int? rating, ProfileAvatar? avatar) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: FlixieColors.background.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FlixieColors.tabBarBorder)),
        child: Column(children: [
          ProfileAvatarView(
              avatar: avatar,
              fallbackText: name[0].toUpperCase(),
              fallbackColor: FlixieColors.primary,
              size: 46),
          const SizedBox(height: 8),
          Text(rating == null ? '-' : '$rating/10',
              style: const TextStyle(
                  color: FlixieColors.warning,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          Text(name, style: const TextStyle(color: FlixieColors.medium))
        ]),
      );

  Widget _friendRecapEntry(
          WatchConfirmation entry, String name, ProfileAvatar? avatar) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: FlixieColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FlixieColors.tabBarBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ProfileAvatarView(
                avatar: avatar,
                fallbackText: name[0].toUpperCase(),
                fallbackColor: FlixieColors.primary,
                size: 48),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const Text('Watched together',
                      style: TextStyle(color: FlixieColors.medium))
                ])),
            if (entry.rating != null)
              Text('★ ${entry.rating}/10',
                  style: const TextStyle(
                      color: FlixieColors.warning,
                      fontSize: 18,
                      fontWeight: FontWeight.w800))
          ]),
          if (entry.rating != null ||
              (entry.reviewText?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 14),
            Row(children: [
              if (entry.rating != null)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        border: Border.all(color: FlixieColors.success),
                        borderRadius: BorderRadius.circular(18)),
                    child: Text(
                        entry.rating! >= 7 ? '👍 Recommends' : '👎 Would skip',
                        style: const TextStyle(
                            color: FlixieColors.success,
                            fontWeight: FontWeight.w700))),
              if (entry.reviewText?.isNotEmpty ?? false) ...[
                const SizedBox(width: 12),
                Expanded(
                    child: Text('“${entry.reviewText}”',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.light,
                            fontStyle: FontStyle.italic)))
              ]
            ]),
          ]
        ]),
      );

  Widget _buildPlanActivity() {
    final watched =
        request.watchConfirmations.where((entry) => entry.watched).length;
    final rated = request.watchConfirmations
        .where((entry) => entry.watched && entry.rating != null)
        .length;
    final scheduled = _effectiveWatchTime != null;
    final finalised = request.selectedCandidateId != null;
    final selectedTitle = request.candidates
        .where((candidate) => candidate.id == request.selectedCandidateId)
        .firstOrNull
        ?.title;
    final accepted = request.isAccepted ||
        request.isScheduled ||
        request.isCompleted ||
        request.normalizedWatchedStatus == 'WATCHED';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Plan activity',
          style: TextStyle(
              color: FlixieColors.light,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      _planActivityRow(
          Icons.send_rounded, 'Invited', 'Watch plan created', true),
      _planActivityRow(Icons.check_circle_outline_rounded, 'Accepted',
          accepted ? 'You’re both in' : 'Waiting for a response', accepted),
      _planActivityRow(
          Icons.bookmark_added_outlined,
          'Choices saved',
          request.candidates.isNotEmpty
              ? '${request.candidates.length} titles considered'
              : 'No titles added yet',
          request.candidates.isNotEmpty),
      _planActivityRow(
          Icons.movie_filter_outlined,
          'Movie finalised',
          finalised
              ? '${selectedTitle ?? 'Movie'} was picked'
              : 'Pick a movie together',
          finalised),
      _planActivityRow(
          Icons.calendar_month_outlined,
          'Scheduled',
          scheduled ? _dateLabel(_effectiveWatchTime!) : 'No time set yet',
          scheduled),
      _planActivityRow(
          Icons.visibility_outlined,
          'Watched',
          watched > 0
              ? '$watched of 2 watches logged'
              : 'Log your watch after the plan',
          watched > 0),
      _planActivityRow(
          Icons.star_outline_rounded,
          'Rated',
          rated > 0 ? '$rated of 2 ratings saved' : 'Ratings will appear here',
          rated > 0,
          last: true),
    ]);
  }

  Widget _planActivityRow(
          IconData icon, String title, String detail, bool complete,
          {bool last = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 8),
        child: Row(children: [
          Icon(icon,
              size: 17,
              color: complete ? FlixieColors.success : FlixieColors.medium),
          const SizedBox(width: 8),
          Expanded(
              child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: title,
                        style: TextStyle(
                            color: complete
                                ? FlixieColors.light
                                : FlixieColors.medium,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: ' · $detail',
                        style: const TextStyle(
                            color: FlixieColors.medium, fontSize: 12)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ]),
      );

  Widget _buildPlanRatingsSummary(BuildContext context) {
    final confirmations = request.watchConfirmations
        .where((confirmation) => confirmation.watched)
        .toList();
    final ratings = confirmations
        .map((confirmation) => confirmation.rating)
        .whereType<int>()
        .toList();
    final average = ratings.isEmpty
        ? null
        : ratings.reduce((sum, rating) => sum + rating) / ratings.length;

    WatchRequestUser? userFor(String userId) {
      if (request.requester?.id == userId) return request.requester;
      if (request.recipient?.id == userId) return request.recipient;
      for (final participant in request.participants) {
        if (participant.user?.id == userId) return participant.user;
      }
      return null;
    }

    final title = request.groupName?.trim().isNotEmpty == true
        ? '${request.groupName} rating'
        : 'Watch plan ratings';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: FlixieColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (average != null)
              Text(
                '${average.toStringAsFixed(1)}/10 avg',
                style: const TextStyle(
                  color: FlixieColors.warning,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (final confirmation in confirmations) ...[
          Row(
            children: [
              _smallUserAvatar(userFor(confirmation.userId)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  userFor(confirmation.userId)?.username ?? 'Friend',
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                confirmation.rating == null
                    ? 'Logged'
                    : '★ ${confirmation.rating}/10',
                style: TextStyle(
                  color: confirmation.rating == null
                      ? FlixieColors.medium
                      : FlixieColors.warning,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (average != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                final currentUser = context.read<AuthProvider>().dbUser;
                int? currentRating;
                for (final confirmation in confirmations) {
                  if (confirmation.userId == currentUser?.id &&
                      confirmation.rating != null) {
                    currentRating = confirmation.rating;
                    break;
                  }
                }
                final movie = request.movie;
                if (currentUser == null ||
                    currentRating == null ||
                    movie == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Log your own rating before sharing it.'),
                    ),
                  );
                  return;
                }
                showShareCardSheet(
                  context,
                  ShareCardData.rating(
                    mediaType: ShareCardMediaType.movie,
                    mediaId: movie.id,
                    title: movie.title,
                    posterPath: movie.posterPath,
                    user: currentUser,
                    rating: currentRating,
                  ),
                );
              },
              icon: const Icon(Icons.ios_share_rounded, size: 17),
              label: const Text('Share your rating'),
            ),
          ),
      ],
    );
  }

  Widget _smallUserAvatar(WatchRequestUser? user) {
    final response =
        request.participantFor(user?.id ?? '')?.response.toUpperCase();
    final declined = response == 'DECLINED';
    final borderColor = declined ? FlixieColors.danger : Colors.transparent;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: ProfileAvatarView(
          avatar: user?.avatar,
          fallbackText: user?.username.isNotEmpty == true
              ? user!.username[0].toUpperCase()
              : '?',
          fallbackColor: FlixieColors.primary,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildCompactActions() {
    if (busyAction != null) {
      return const SizedBox(
        height: 34,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final incoming = request.isPending &&
        request.requesterId != myUserId &&
        (request.recipientId == myUserId ||
            request.participantFor(myUserId) != null);
    if (incoming) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          // Open the plan rather than silently accepting it: this gives the
          // recipient context and takes them straight to movie choices.
          onPressed: onOpen,
          icon: const Icon(Icons.movie_filter_outlined, size: 18),
          label: const Text('Choose movies'),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerRight,
      child: OutlinedButton.icon(
        onPressed: onOpen,
        icon: const Icon(Icons.visibility_outlined, size: 16),
        label: Text(request.normalizedScheduleStatus == 'AGREED'
            ? 'View plan'
            : 'View request'),
        style: OutlinedButton.styleFrom(
          foregroundColor: FlixieColors.primary,
          side: const BorderSide(color: FlixieColors.primary),
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildCandidateChoices() {
    final organiser = request.requesterId == myUserId;
    // Direct Watch Plans have a single invitee.  The lifecycle endpoint does
    // not include a per-user acceptance flag, so its accepted/scheduled status
    // is the reliable source once the invitee has accepted.
    final canChooseMovies =
        organiser || request.isAccepted || request.isScheduled;
    final selectedCandidate = request.selectedCandidateId;
    if (selectedCandidate != null) {
      return _buildFinalMovieSummary(selectedCandidate, organiser);
    }
    final acceptedIds = <String>{request.requesterId, request.recipientId};
    final savingMovieChoices = busyAction == _RequestAction.savingMovieChoices;
    final removingCandidate = busyAction == _RequestAction.removingCandidate;
    final selectingMovie = busyAction == _RequestAction.selectingMovie;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedCandidate == null && organiser
              ? 'Choose the final movie'
              : selectedCandidate == null
                  ? 'What could you watch?'
                  : 'Chosen movie',
          style: const TextStyle(
            color: FlixieColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          selectedCandidate == null && organiser
              ? 'As the Watch Plan creator, you make the final choice. Use “Make final” to lock in a movie.'
              : selectedCandidate == null
                  ? '${request.candidates.length} of 5 options · choose every title you would watch. The Watch Plan creator makes the final choice.'
                  : 'The final title is selected. Rescheduling will keep this choice.',
          style: const TextStyle(color: FlixieColors.medium, fontSize: 12),
        ),
        if (!canChooseMovies) ...[
          const SizedBox(height: 10),
          const Text(
            'Accept the invitation first, then choose the movies you would watch.',
            style: TextStyle(
              color: FlixieColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final candidateCards = request.candidates.map((candidate) {
            final selectedCount =
                candidate.selectedByUserIds.where(acceptedIds.contains).length;
            final everyoneMatch = selectedCount == acceptedIds.length;
            final isFinal = candidate.id == selectedCandidate;
            final pickedByMe = candidateChoiceDraft.contains(candidate.id);
            final canRemove = selectedCandidate == null &&
                request.candidates.length > 1 &&
                (organiser || candidate.addedByUserId == myUserId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: canChooseMovies &&
                          selectedCandidate == null &&
                          !selectingMovie
                      ? () => onToggleCandidateChoice(candidate.id)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: pickedByMe
                          ? FlixieColors.success.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: pickedByMe
                            ? FlixieColors.success
                            : FlixieColors.tabBarBorder,
                        width: pickedByMe ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 44,
                            height: 66,
                            child: candidate.posterPath == null
                                ? const _PosterPlaceholder()
                                : CachedNetworkImage(
                                    imageUrl:
                                        'https://image.tmdb.org/t/p/w185${candidate.posterPath}',
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        const _PosterPlaceholder(),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(candidate.title ?? 'Untitled',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: FlixieColors.light,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(
                                isFinal
                                    ? 'Selected for this Watch Plan'
                                    : everyoneMatch
                                        ? 'Everyone\'s match'
                                        : '$selectedCount of ${acceptedIds.length} would watch',
                                style: TextStyle(
                                  color: isFinal || everyoneMatch
                                      ? FlixieColors.success
                                      : FlixieColors.medium,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (candidate.addedByUsername?.isNotEmpty == true)
                                Row(children: [
                                  WatchPlanCandidateAvatar(
                                    avatar: candidate.addedByAvatar,
                                    username: candidate.addedByUsername,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Suggested by ${candidate.addedByUsername}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: FlixieColors.medium,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ]),
                            ],
                          ),
                        ),
                        if (pickedByMe)
                          const Icon(Icons.check_circle_rounded,
                              color: FlixieColors.success, size: 27),
                        if (pickedByMe &&
                            organiser &&
                            selectedCandidate == null)
                          const SizedBox(width: 10),
                        if (canRemove)
                          IconButton(
                            onPressed: removingCandidate
                                ? null
                                : () => onRemoveCandidate(candidate.id),
                            tooltip: 'Remove movie option',
                            icon: removingCandidate
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.close_rounded, size: 20),
                            color: FlixieColors.medium,
                            visualDensity: VisualDensity.compact,
                          ),
                        if (organiser && selectedCandidate == null)
                          FilledButton.icon(
                            onPressed: selectingMovie
                                ? null
                                : () => onSelectCandidate(candidate.id),
                            icon: selectingMovie
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.lock_rounded, size: 16),
                            label: Text(
                              selectingMovie ? 'Saving' : 'Final',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 11),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(growable: false);
          if (constraints.maxWidth < 600) {
            return Column(children: candidateCards);
          }
          return Wrap(
            spacing: 10,
            runSpacing: 0,
            children: candidateCards
                .map((card) => SizedBox(
                      width: (constraints.maxWidth - 10) / 2,
                      child: card,
                    ))
                .toList(growable: false),
          );
        }),
        if (selectedCandidate == null)
          Column(children: [
            if (request.candidates.length < 5)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: canChooseMovies && !savingMovieChoices
                      ? onAddCandidate
                      : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Add another option'),
                ),
              )
            else
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('You have reached the five-option limit.',
                      style:
                          TextStyle(color: FlixieColors.medium, fontSize: 12)),
                ),
              ),
            if (candidateChoiceDraft.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Select at least one movie to continue.',
                      style: TextStyle(
                          color: FlixieColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: !canChooseMovies ||
                        savingMovieChoices ||
                        candidateChoiceDraft.isEmpty
                    ? null
                    : onSaveCandidateChoices,
                icon: savingMovieChoices
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.checklist_rounded),
                label: Text(
                  savingMovieChoices
                      ? 'Saving your picks...'
                      : 'Save movies I’d watch',
                ),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _buildFinalMovieSummary(String selectedCandidateId, bool organiser) {
    final selected = request.candidates
        .where((candidate) => candidate.id == selectedCandidateId)
        .firstOrNull;
    if (selected == null) return const SizedBox.shrink();
    final alternatives = request.candidates
        .where((candidate) => candidate.id != selectedCandidateId)
        .toList(growable: false);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Chosen movie',
          style: TextStyle(
              color: FlixieColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900)),
      const SizedBox(height: 5),
      const Text(
          'The final title is selected. Rescheduling will keep this choice.',
          style: TextStyle(color: FlixieColors.medium, fontSize: 12)),
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: FlixieColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlixieColors.primary, width: 2)),
        child: Row(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: SizedBox(
                  width: 52,
                  height: 78,
                  child: selected.posterPath == null
                      ? const _PosterPlaceholder()
                      : CachedNetworkImage(
                          imageUrl:
                              'https://image.tmdb.org/t/p/w185${selected.posterPath}',
                          fit: BoxFit.cover))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(selected.title ?? 'Untitled',
                    style: const TextStyle(
                        color: FlixieColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('Selected for this Watch Plan',
                    style: TextStyle(
                        color: FlixieColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ])),
          const Icon(Icons.check_circle_rounded, color: FlixieColors.success),
        ]),
      ),
      if (organiser) ...[
        const SizedBox(height: 8),
        Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
                onPressed: onChangeMovie,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Change selected movie')))
      ],
      if (alternatives.isNotEmpty) ...[
        const SizedBox(height: 4),
        Material(
            color: Colors.transparent,
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Other movie options (${alternatives.length})',
                  style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              children: alternatives
                  .map((candidate) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: SizedBox(
                                width: 32,
                                height: 48,
                                child: candidate.posterPath == null
                                    ? const _PosterPlaceholder()
                                    : CachedNetworkImage(
                                        imageUrl:
                                            'https://image.tmdb.org/t/p/w92${candidate.posterPath}',
                                        fit: BoxFit.cover))),
                        title: Text(candidate.title ?? 'Untitled',
                            style: const TextStyle(
                                color: FlixieColors.light, fontSize: 14)),
                      ))
                  .toList(growable: false),
            ))
      ],
    ]);
  }

  Widget _buildParticipants(WatchRequestUser? other) {
    final users = request.participants
        .map((participant) => participant.user)
        .whereType<WatchRequestUser>()
        .toList(growable: false);
    final visible = users.isNotEmpty
        ? users
        : [request.requester, request.recipient, other]
            .whereType<WatchRequestUser>()
            .toSet()
            .toList(growable: false);
    bool hasAccepted(WatchRequestUser user) {
      final participant = request.participantFor(user.id);
      if (participant?.response.toUpperCase() == 'ACCEPTED') return true;
      if (user.id == request.requesterId) return true;
      // Direct Watch Plans store the invitee's response on the request itself,
      // rather than always returning a participant-response row.
      if (user.id == request.recipientId &&
          (request.isAccepted || request.isScheduled)) {
        return true;
      }
      // Older scheduled requests can omit their individual response rows even
      // though agreeing the schedule required the recipients to accept.
      return request.normalizedScheduleStatus == 'AGREED' ||
          request.isScheduled;
    }

    bool hasDeclined(WatchRequestUser user) =>
        request.participantFor(user.id)?.response.toUpperCase() == 'DECLINED';

    final accepted = visible.where(hasAccepted).length;
    final waiting = visible.length - accepted;
    final schedulingInProgress = request.isAwaitingScheduleApproval;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Participants',
            style: TextStyle(color: FlixieColors.medium, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: visible
              .map((user) => _participantAvatar(
                    user,
                    accepted: hasAccepted(user),
                    declined: hasDeclined(user),
                    schedulingInProgress:
                        schedulingInProgress && hasAccepted(user),
                  ))
              .toList(growable: false),
        ),
        const SizedBox(height: 6),
        Text(
          accepted == visible.length && visible.isNotEmpty
              ? schedulingInProgress
                  ? 'All $accepted accepted · scheduling in progress'
                  : 'All $accepted accepted'
              : accepted > 0
                  ? schedulingInProgress
                      ? '$accepted accepted · $waiting waiting · scheduling in progress'
                      : '$accepted accepted · $waiting waiting'
                  : 'Waiting for responses',
          style: TextStyle(
              color: accepted > 0 ? FlixieColors.success : FlixieColors.medium,
              fontSize: 12,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _participantAvatar(
    WatchRequestUser user, {
    required bool accepted,
    required bool declined,
    required bool schedulingInProgress,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: declined
                      ? FlixieColors.danger
                      : accepted
                          ? FlixieColors.success
                          : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ProfileAvatarView(
                  avatar: user.avatar,
                  fallbackText: user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : '?',
                  fallbackColor: FlixieColors.primary,
                  size: 34,
                ),
              ),
            ),
            if (accepted || declined)
              Positioned(
                top: -3,
                right: -3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: declined
                        ? FlixieColors.danger
                        : schedulingInProgress
                            ? FlixieColors.primary
                            : FlixieColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      declined
                          ? Icons.close_rounded
                          : schedulingInProgress
                              ? Icons.hourglass_top_rounded
                              : Icons.check_rounded,
                      color: Colors.black,
                      size: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 62,
          child: Text(
            user.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: declined
                  ? FlixieColors.danger
                  : accepted
                      ? (schedulingInProgress
                          ? FlixieColors.primary
                          : FlixieColors.success)
                      : FlixieColors.medium,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  bool get _isIncomingInvitation =>
      request.isPending &&
      request.requesterId != myUserId &&
      (request.recipientId == myUserId ||
          request.participantFor(myUserId) != null);

  bool get _hasPlanningAction {
    // Scheduling is configured in the Watch Plan composer and displayed in
    // the dedicated schedule surface below. Do not repeat that control here.
    if (_isIncomingInvitation) return false;
    // The schedule surface below owns the calendar, time and location actions.
    // Keeping them out of this generic action area avoids duplicate controls.
    if (request.normalizedScheduleStatus == 'AGREED') return false;
    if ((!request.isAccepted && !request.isScheduled) ||
        !request.isWatchRequest ||
        request.canConfirmWatchedFor(myUserId)) {
      return false;
    }
    return request.normalizedWatchedStatus != 'PARTIAL' &&
        request.normalizedWatchedStatus != 'WATCHED' &&
        request.normalizedWatchedStatus != 'NOT_WATCHED';
  }

  bool get _shouldShowAfterWatchSection =>
      request.normalizedScheduleStatus == 'AGREED' ||
      request.canConfirmWatchedFor(myUserId) ||
      request.normalizedWatchedStatus == 'PARTIAL' ||
      request.normalizedWatchedStatus == 'WATCHED' ||
      request.normalizedWatchedStatus == 'NOT_WATCHED';

  Widget _buildActions({bool includeWatchConfirmation = true}) {
    if (busyAction != null) {
      return const SizedBox(
        height: 38,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_isIncomingInvitation) {
      return const SizedBox.shrink();
    }

    if ((!request.isAccepted && !request.isScheduled) ||
        !request.isWatchRequest) {
      return const SizedBox.shrink();
    }

    if (includeWatchConfirmation && request.canConfirmWatchedFor(myUserId)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Did you watch it?',
            style: TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _PrimaryActionButton(
                  label: 'Mark as watched',
                  onPressed: onConfirmWatched,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryActionButton(
                  label: 'Suggest another time',
                  onPressed: onSuggestDifferentTime,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (request.normalizedWatchedStatus == 'PARTIAL' ||
        request.normalizedWatchedStatus == 'WATCHED' ||
        request.normalizedWatchedStatus == 'NOT_WATCHED') {
      return const SizedBox.shrink();
    }

    final proposal = request.latestPendingProposal;
    if (request.normalizedScheduleStatus == 'PROPOSED' && proposal != null) {
      if (proposal.proposerId == myUserId) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InlineStateMessage(
              icon: Icons.schedule_outlined,
              text: request.scheduledFor == null
                  ? 'Waiting for them to respond to ${_dateLabel(proposal.proposedFor)}'
                  : 'New time proposed for ${_dateLabel(proposal.proposedFor)}. Your current plan stays in place until they agree.',
            ),
            const SizedBox(height: 8),
            _IconTextAction(
              icon: Icons.edit_calendar_outlined,
              label: 'Propose a different time',
              onPressed: onSuggestDifferentTime,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlixieColors.warning.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FlixieColors.warning.withValues(alpha: .6),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    color: FlixieColors.warning, size: 25),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEW TIME WAITING FOR YOUR APPROVAL',
                        style: TextStyle(
                          color: FlixieColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _dateLabel(proposal.proposedFor),
                        style: const TextStyle(
                          color: FlixieColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (request.scheduledFor != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Current plan: ${_dateLabel(request.scheduledFor)}',
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _PrimaryActionButton(
              label: 'Accept time',
              onPressed: () => onRespondToProposal(proposal, 'accepted'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => onRespondToProposal(proposal, 'declined'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FlixieColors.danger,
                side: const BorderSide(color: FlixieColors.danger),
                minimumSize: const Size(0, 44),
              ),
              child: const Text('Keep current time'),
            ),
          ),
          const SizedBox(height: 8),
          _IconTextAction(
            icon: Icons.edit_calendar_outlined,
            label: 'Propose another time instead',
            onPressed: onSuggestDifferentTime,
          ),
        ],
      );
    }

    if (request.normalizedScheduleStatus == 'AGREED') {
      final scheduledFor = request.scheduledFor;
      final isFuture =
          scheduledFor != null && scheduledFor.isAfter(DateTime.now());
      if (!isFuture) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: _PrimaryActionButton(
              label: 'Add to calendar',
              onPressed: () => WatchCalendarService.addScheduledWatch(
                title: request.movie?.title ?? 'Watch together',
                scheduledFor: scheduledFor,
                runtimeMinutes: request.movie?.runtimeMinutes,
                note: request.message,
                location: request.location,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _IconTextAction(
                icon: Icons.edit_calendar_outlined,
                label: 'Propose a new time',
                onPressed: onSuggestDifferentTime,
              ),
              _IconTextAction(
                icon: Icons.location_on_outlined,
                label: request.location?.trim().isNotEmpty == true
                    ? 'Change location'
                    : 'Add location',
                onPressed: onEditLocation,
              ),
            ],
          ),
        ],
      );
    }

    if (request.normalizedScheduleStatus == 'NONE' ||
        request.normalizedScheduleStatus == 'DECLINED' ||
        request.normalizedScheduleStatus == 'CANCELLED') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan the details',
            style: TextStyle(
              color: FlixieColors.light,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a time first, then add a place if you have one.',
            style: TextStyle(color: FlixieColors.medium, fontSize: 12),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final time = _PrimaryActionButton(
                label: 'Suggest a time',
                onPressed: onSuggestSchedule,
              );
              final location = _SecondaryActionButton(
                label: request.location?.trim().isNotEmpty == true
                    ? 'Change location'
                    : 'Add a location',
                onPressed: onEditLocation,
              );
              if (constraints.maxWidth >= 600) {
                return Row(children: [
                  Expanded(child: time),
                  const SizedBox(width: 10),
                  Expanded(child: location),
                ]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  time,
                  const SizedBox(height: 8),
                  location,
                ],
              );
            },
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInvitationDecisionActions() {
    final acceptLabel = acceptanceScheduleDraft == null
        ? 'Accept invitation'
        : 'Accept & suggest time';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Respond to invitation',
          style: TextStyle(
            color: FlixieColors.light,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _PrimaryActionButton(label: acceptLabel, onPressed: onAccept),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onDecline,
          style: OutlinedButton.styleFrom(
            foregroundColor: FlixieColors.danger,
            side: const BorderSide(color: FlixieColors.danger),
          ),
          child: const Text('Decline'),
        ),
      ],
    );
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'the suggested time';
    final local = value.toLocal();
    if (value.isUtc && value.hour == 12 && value.minute == 0) {
      const weekdays = [
        'Monday', 'Tuesday', 'Wednesday', 'Thursday',
        'Friday', 'Saturday', 'Sunday',
      ];
      return 'Watch on ${weekdays[local.weekday - 1]}';
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'pm' : 'am';
    if (date == today) return 'Today at $hour:$minute$suffix';
    if (date == today.add(const Duration(days: 1))) {
      return 'Tomorrow at $hour:$minute$suffix';
    }
    return '${local.day} ${_kMonths[local.month - 1]}, $hour:$minute$suffix';
  }

  DateTime? get _effectiveWatchTime =>
      request.scheduledFor ??
      request.latestPendingProposal?.proposedFor ??
      request.proposedDate;

  String? get _effectiveLocation {
    final value = request.location ?? request.latestPendingProposal?.location;
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String _scheduleSummaryLabel() {
    final proposal = request.latestPendingProposal;
    if (request.normalizedScheduleStatus == 'PROPOSED' && proposal != null) {
      return _dateLabel(proposal.proposedFor);
    }
    if (request.normalizedScheduleStatus == 'AGREED') {
      return _dateLabel(request.scheduledFor);
    }
    return scheduledLabel;
  }

  WatchScheduleProposal? _visibleScheduleProposal() {
    final proposals = request.scheduleProposals.where((proposal) {
      if (request.normalizedScheduleStatus == 'PROPOSED') {
        return proposal.isPending;
      }
      if (request.normalizedScheduleStatus == 'AGREED') {
        return proposal.normalizedStatus == 'ACCEPTED';
      }
      return false;
    }).toList()
      ..sort((a, b) => _proposalCreatedAt(b).compareTo(_proposalCreatedAt(a)));
    return proposals.isEmpty ? null : proposals.first;
  }

  DateTime _proposalCreatedAt(WatchScheduleProposal proposal) {
    return DateTime.tryParse(proposal.createdAt ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String? get _proposalNoteText {
    final message = _visibleScheduleProposal()?.message?.trim();
    if (message == null || message.isEmpty) return null;
    return message;
  }
}

class _ScheduleConfirmationCard extends StatelessWidget {
  const _ScheduleConfirmationCard({
    required this.proposedFor,
    required this.awaitingOtherPerson,
    required this.onConfirm,
    required this.onChange,
  });

  final DateTime proposedFor;
  final bool awaitingOtherPerson;
  final VoidCallback onConfirm;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final isDateOnly =
        proposedFor.isUtc && proposedFor.hour == 12 && proposedFor.minute == 0;
    final local = proposedFor.toLocal();
    final date = MaterialLocalizations.of(context).formatFullDate(local);
    final time = TimeOfDay.fromDateTime(local).format(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          awaitingOtherPerson ? 'Waiting for confirmation' : 'Confirm the plan',
          style: TextStyle(
              color: FlixieColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(
          awaitingOtherPerson
              ? isDateOnly
                  ? 'Your friend needs to confirm this watch day.'
                  : 'Your friend needs to confirm this date and time.'
              : isDateOnly
                  ? 'Your friend suggested this watch day.'
                  : 'Your friend suggested this date and time.',
          style: const TextStyle(color: FlixieColors.light, fontSize: 13)),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.event_available_outlined,
              color: FlixieColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(date,
                    style: const TextStyle(
                        color: FlixieColors.textPrimary,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                    Text(isDateOnly ? 'Time to be decided' : time,
                    style: const TextStyle(
                        color: FlixieColors.light, fontSize: 13)),
              ])),
        ]),
      ),
      const SizedBox(height: 12),
      if (!awaitingOtherPerson)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onConfirm,
            icon: const Icon(Icons.check_rounded, size: 18),
            label: Text(isDateOnly ? 'Confirm watch day' : 'Confirm date & time'),
          ),
        ),
      if (!awaitingOtherPerson) const SizedBox(height: 6),
      Center(
        child: TextButton(
          onPressed: onChange,
          child: const Text('Suggest a different time'),
        ),
      ),
    ]);
  }
}

class _PlanOverviewRow extends StatelessWidget {
  const _PlanOverviewRow({
    required this.icon,
    required this.label,
    required this.action,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, color: FlixieColors.secondary, size: 18),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: FlixieColors.light, fontSize: 14)),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: FlixieColors.primary,
            minimumSize: const Size(0, 28),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(action,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ]);
}

class _PlanSurface extends StatelessWidget {
  const _PlanSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: child,
    );
  }
}

class _WatchDetailRow extends StatelessWidget {
  const _WatchDetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: FlixieColors.secondary),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 12.5,
                height: 1.35,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailStatusBadge extends StatelessWidget {
  const _DetailStatusBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactWatchDetail extends StatelessWidget {
  const _CompactWatchDetail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: FlixieColors.secondary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _LifecycleSummary extends StatelessWidget {
  const _LifecycleSummary({
    required this.request,
    required this.scheduledLabel,
    required this.myUserId,
  });

  final WatchRequest request;
  final String scheduledLabel;
  final String myUserId;

  @override
  Widget build(BuildContext context) {
    final text = _summaryText();
    if (text == null) return const SizedBox.shrink();
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: FlixieColors.light,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  String? _summaryText() {
    if (request.isPending) {
      final pending = request.participants
          .where((p) => p.response.toLowerCase() == 'pending')
          .length;
      if (request.requesterId == myUserId) {
        return pending > 0
            ? 'Waiting for $pending response${pending == 1 ? '' : 's'}'
            : 'Waiting for a response';
      }
      return 'Accept the invitation to start making a plan.';
    }
    if (request.isAccepted || request.isScheduled) {
      if (request.normalizedWatchedStatus == 'WATCHED') {
        return 'Watched together';
      }
      if (request.normalizedWatchedStatus == 'NOT_WATCHED') {
        return 'This watch was not completed by both users';
      }
      if (request.normalizedWatchedStatus == 'PARTIAL') {
        return 'One person confirmed. Waiting on the other.';
      }
      if (request.needsWatchConfirmation == true) {
        return 'Scheduled time passed. Confirmation needed.';
      }
      final proposal = request.latestPendingProposal;
      if (request.normalizedScheduleStatus == 'PROPOSED' && proposal != null) {
        return proposal.proposerId == myUserId
            ? 'Waiting for them to respond'
            : 'Choose this time or suggest another that suits you.';
      }
      if (request.normalizedScheduleStatus == 'AGREED') {
        return scheduledLabel.isEmpty
            ? 'Scheduled'
            : 'Scheduled for $scheduledLabel';
      }
      if (request.normalizedScheduleStatus == 'DECLINED') {
        return 'Suggested time declined';
      }
      if (request.normalizedScheduleStatus == 'CANCELLED') {
        return 'Schedule cancelled';
      }
      if (request.isAwaitingScheduleApproval) {
        return 'Accepted · scheduling in progress';
      }
      return 'You’re both up for it. Add a time or location when you’re ready.';
    }
    if (request.isCompleted) {
      final mine = request.participantFor(myUserId);
      if (mine?.rating != null) {
        return 'Your rating: ${mine!.rating!.toStringAsFixed(1)}/10';
      }
      if (mine?.reviewText?.isNotEmpty == true) return 'Your review is saved';
      return 'Watched together';
    }
    if (request.isCancelled) return 'This watch plan was cancelled';
    if (request.isExpired) return 'This watch request expired';
    if (request.isDeclined) return 'This watch request was declined';
    return null;
  }
}

class _InlineStateMessage extends StatelessWidget {
  const _InlineStateMessage({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: FlixieColors.medium),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProposalNote extends StatelessWidget {
  const _ProposalNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: FlixieColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FlixieColors.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 13,
            color: FlixieColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: FlixieColors.primary,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _SecondaryActionButton extends StatelessWidget {
  const _SecondaryActionButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: FlixieColors.light,
        side: BorderSide(color: FlixieColors.medium.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _IconTextAction extends StatelessWidget {
  const _IconTextAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: FlixieColors.medium,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

enum _WatchLocationKind { home, cinema, later }

class _LocationEditorSheet extends StatefulWidget {
  const _LocationEditorSheet({this.initialLocation});
  final String? initialLocation;

  @override
  State<_LocationEditorSheet> createState() => _LocationEditorSheetState();
}

class _LocationEditorSheetState extends State<_LocationEditorSheet> {
  late final TextEditingController _locationController;
  late _WatchLocationKind _kind;

  @override
  void initState() {
    super.initState();
    _locationController =
        TextEditingController(text: widget.initialLocation ?? '');
    _kind = widget.initialLocation?.trim().isNotEmpty == true
        ? _WatchLocationKind.cinema
        : _WatchLocationKind.later;
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .84,
        child: Material(
          color: FlixieColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.noScaling),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  24, 14, 24, 20 + MediaQuery.viewInsetsOf(context).bottom),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: Container(
                            width: 54,
                            height: 6,
                            decoration: BoxDecoration(
                                color: FlixieColors.medium,
                                borderRadius: BorderRadius.circular(8)))),
                    const SizedBox(height: 24),
                    Row(children: [
                      const Expanded(
                          child: Text('Where are you watching?',
                              style: TextStyle(
                                  color: FlixieColors.textPrimary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800))),
                      IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded,
                              color: FlixieColors.light, size: 28)),
                    ]),
                    const SizedBox(height: 8),
                    const Text(
                        'Choose the kind of plan first. A specific place is optional.',
                        style:
                            TextStyle(color: FlixieColors.light, fontSize: 13)),
                    const SizedBox(height: 24),
                    _LocationKindOption(
                        kind: _WatchLocationKind.home,
                        selected: _kind,
                        icon: Icons.home_outlined,
                        title: 'At home',
                        subtitle: 'Check shared streaming providers',
                        onTap: () =>
                            setState(() => _kind = _WatchLocationKind.home)),
                    const SizedBox(height: 10),
                    _LocationKindOption(
                        kind: _WatchLocationKind.cinema,
                        selected: _kind,
                        icon: Icons.theaters_outlined,
                        title: 'Cinema',
                        subtitle: 'Streaming providers don’t matter',
                        onTap: () =>
                            setState(() => _kind = _WatchLocationKind.cinema)),
                    const SizedBox(height: 10),
                    _LocationKindOption(
                        kind: _WatchLocationKind.later,
                        selected: _kind,
                        icon: Icons.more_horiz_rounded,
                        title: 'Decide later',
                        subtitle: 'Keep the plan flexible',
                        onTap: () =>
                            setState(() => _kind = _WatchLocationKind.later)),
                    const SizedBox(height: 24),
                    Row(children: [
                      Text(
                          _kind == _WatchLocationKind.cinema
                              ? 'Cinema'
                              : _kind == _WatchLocationKind.home
                                  ? 'At home'
                                  : 'Location',
                          style: const TextStyle(
                              color: FlixieColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w800)),
                      const Spacer(),
                      const Text('OPTIONAL',
                          style: TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 11,
                              fontWeight: FontWeight.w800))
                    ]),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _locationController,
                        style: const TextStyle(
                            color: FlixieColors.textPrimary, fontSize: 15),
                        decoration: InputDecoration(
                            filled: true,
                            fillColor: FlixieColors.surfaceElevated,
                            hintText: _kind == _WatchLocationKind.cinema
                                ? 'e.g. ODEON Belfast'
                                : 'e.g. My place',
                            hintStyle:
                                const TextStyle(color: FlixieColors.medium),
                            suffixIcon: const Icon(Icons.edit_outlined,
                                color: FlixieColors.primary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18),
                                borderSide: BorderSide.none))),
                    if (_kind == _WatchLocationKind.cinema) ...[
                      const SizedBox(height: 14),
                      Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                              color:
                                  FlixieColors.secondary.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(16)),
                          child: const Text(
                              'Streaming-provider matching is switched off for this plan.',
                              style: TextStyle(
                                  color: FlixieColors.secondary, fontSize: 12)))
                    ],
                    const SizedBox(height: 20),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                            color: FlixieColors.surfaceElevated,
                            borderRadius: BorderRadius.circular(16)),
                        child: const Text(
                            'Everyone in this plan will be notified that the location changed.',
                            style: TextStyle(
                                color: FlixieColors.light, fontSize: 11))),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                            onPressed: () => Navigator.pop(
                                context, _locationController.text.trim()),
                            child: const Text('Save location',
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)))),
                  ]),
            ),
          ),
        ),
      );
}

class _LocationKindOption extends StatelessWidget {
  const _LocationKindOption(
      {required this.kind,
      required this.selected,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final _WatchLocationKind kind;
  final _WatchLocationKind selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final isSelected = kind == selected;
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
                border: Border.all(
                    color: isSelected
                        ? FlixieColors.primary
                        : FlixieColors.tabBarBorder,
                    width: isSelected ? 2 : 1),
                borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: FlixieColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, color: FlixieColors.primary)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            color: FlixieColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: FlixieColors.light, fontSize: 12))
                  ])),
              Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color:
                      isSelected ? FlixieColors.primary : FlixieColors.medium)
            ])));
  }
}

class _ScheduleProposalSheet extends StatefulWidget {
  const _ScheduleProposalSheet({this.initial, this.initialLocation});

  final DateTime? initial;
  final String? initialLocation;

  @override
  State<_ScheduleProposalSheet> createState() => _ScheduleProposalSheetState();
}

class _ScheduleProposalSheetState extends State<_ScheduleProposalSheet> {
  late DateTime _selected;
  late _ScheduleEntryMode _mode;
  bool _leaveTimeUndecided = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial?.toLocal() ??
        DateTime.now().add(const Duration(hours: 2));
    _mode = _ScheduleEntryMode.dateAndTime;
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    return SizedBox(
      height: height * .88,
      child: Material(
        color: FlixieColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: MediaQuery(
          // The controls use fixed, compact sizes so a large system text scale
          // cannot cause touch labels to overflow their cards.
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                  child: Container(
                      width: 54,
                      height: 6,
                      decoration: BoxDecoration(
                          color: FlixieColors.medium,
                          borderRadius: BorderRadius.circular(10)))),
              const SizedBox(height: 24),
              Row(children: [
                const Expanded(
                    child: Text('Date & time',
                        style: TextStyle(
                            color: FlixieColors.textPrimary,
                            fontSize: 26,
                            fontWeight: FontWeight.w800))),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: FlixieColors.light, size: 28)),
              ]),
              const SizedBox(height: 8),
              const Text(
                  'Set when this plan should happen. You can change it again later.',
                  style: TextStyle(color: FlixieColors.light, fontSize: 13)),
              const SizedBox(height: 24),
              _ScheduleModeSelector(
                  mode: _mode,
                  onChanged: (mode) => setState(() {
                        _mode = mode;
                        if (mode == _ScheduleEntryMode.dateOnly) {
                          _leaveTimeUndecided = true;
                        }
                      })),
              const SizedBox(height: 24),
              const Text('Quick pick',
                  style: TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(children: [
                for (final quickPick in <({String label, DateTime value})>[
                  (label: 'Tonight', value: _tonight()),
                  (label: 'Tomorrow', value: _tomorrow()),
                  (label: 'Weekend', value: _thisWeekend()),
                ])
                  Expanded(
                      child: Padding(
                          padding: EdgeInsets.only(
                              right: quickPick.label == 'Weekend' ? 0 : 8),
                          child: _QuickScheduleButton(
                              label: quickPick.label,
                              onTap: () => setState(
                                  () => _selected = quickPick.value)))),
              ]),
              const SizedBox(height: 20),
              _ScheduleDetailCard(
                  icon: Icons.calendar_month_outlined,
                  label: 'DATE',
                  value: MaterialLocalizations.of(context)
                      .formatFullDate(_selected),
                  onTap: _pickDate),
              if (_mode == _ScheduleEntryMode.dateAndTime) ...[
                const SizedBox(height: 10),
                _ScheduleDetailCard(
                    icon: Icons.access_time_rounded,
                    label: 'TIME',
                    value: TimeOfDay.fromDateTime(_selected).format(context),
                    onTap: _pickTime),
                const SizedBox(height: 10),
                Row(children: [
                  Switch(
                      value: _leaveTimeUndecided,
                      onChanged: (value) =>
                          setState(() => _leaveTimeUndecided = value)),
                  const SizedBox(width: 10),
                  const Text('Leave the time undecided',
                      style:
                          TextStyle(color: FlixieColors.light, fontSize: 13)),
                ]),
              ],
              const SizedBox(height: 18),
              Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: FlixieColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(18)),
                  child: const Text(
                      'Everyone in this plan will be notified that the schedule changed.',
                      style:
                          TextStyle(color: FlixieColors.light, fontSize: 11))),
              const SizedBox(height: 20),
              SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                      onPressed: _save,
                      child: const Text('Save schedule',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)))),
            ]),
          ),
        ),
      ),
    );
  }

  void _save() => Navigator.pop(context, (
        proposedFor: _selected,
        message: _leaveTimeUndecided || _mode == _ScheduleEntryMode.dateOnly
            ? 'Time to be decided'
            : null,
        location: widget.initialLocation?.trim(),
      ));

  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleDatePickerSheet(initialDate: _selected),
    );
    if (picked == null) return;
    setState(() {
      _selected = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _selected.hour,
        _selected.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final picked = await showModalBottomSheet<TimeOfDay>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleTimePickerSheet(
        initialTime: TimeOfDay.fromDateTime(_selected),
      ),
    );
    if (picked == null) return;
    setState(() {
      _selected = DateTime(
        _selected.year,
        _selected.month,
        _selected.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  DateTime _tonight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 20);
  }

  DateTime _tomorrow() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 19, 30);
  }

  DateTime _thisWeekend() {
    final now = DateTime.now();
    final daysUntilSaturday = (DateTime.saturday - now.weekday) % 7;
    final saturday =
        now.add(Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday));
    return DateTime(saturday.year, saturday.month, saturday.day, 20);
  }
}

enum _ScheduleEntryMode { dateOnly, dateAndTime }

class _ScheduleModeSelector extends StatelessWidget {
  const _ScheduleModeSelector({required this.mode, required this.onChanged});

  final _ScheduleEntryMode mode;
  final ValueChanged<_ScheduleEntryMode> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: FlixieColors.tabBarBorder),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          _modeButton('Date only', _ScheduleEntryMode.dateOnly),
          _modeButton('Date & time', _ScheduleEntryMode.dateAndTime),
        ]),
      );

  Widget _modeButton(String label, _ScheduleEntryMode value) {
    final selected = mode == value;
    return Expanded(
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () => onChanged(value),
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: selected ? FlixieColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? FlixieColors.white : FlixieColors.light,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ),
      ),
    );
  }
}

class _QuickScheduleButton extends StatelessWidget {
  const _QuickScheduleButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(58),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          foregroundColor: FlixieColors.light,
          side: const BorderSide(color: FlixieColors.tabBarBorder),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Text(label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.fade,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );
}

class _ScheduleDetailCard extends StatelessWidget {
  const _ScheduleDetailCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: FlixieColors.tabBarBorder),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: FlixieColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: FlixieColors.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(label,
                        style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4)),
                    const SizedBox(height: 5),
                    Text(value,
                        style: const TextStyle(
                            color: FlixieColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w600)),
                  ])),
              const Text('Change',
                  style: TextStyle(
                      color: FlixieColors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );
}

class _ScheduleTimePickerSheet extends StatefulWidget {
  const _ScheduleTimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_ScheduleTimePickerSheet> createState() =>
      _ScheduleTimePickerSheetState();
}

class _ScheduleTimePickerSheetState extends State<_ScheduleTimePickerSheet> {
  late TimeOfDay _selected = widget.initialTime;

  @override
  Widget build(BuildContext context) {
    final initialDateTime = DateTime(
      2020,
      1,
      1,
      _selected.hour,
      _selected.minute,
    );
    return SafeArea(
      child: Material(
        color: FlixieColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Choose a time',
                  style: TextStyle(
                    color: FlixieColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 170,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.dark,
                    primaryColor: FlixieColors.primary,
                  ),
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.time,
                    initialDateTime: initialDateTime,
                    use24hFormat: false,
                    onDateTimeChanged: (value) {
                      _selected = TimeOfDay.fromDateTime(value);
                    },
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  child: const Text('Use this time'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleDatePickerSheet extends StatefulWidget {
  const _ScheduleDatePickerSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_ScheduleDatePickerSheet> createState() =>
      _ScheduleDatePickerSheetState();
}

class _ScheduleDatePickerSheetState extends State<_ScheduleDatePickerSheet> {
  late DateTime _selected = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
    widget.initialDate.day,
  );

  @override
  Widget build(BuildContext context) {
    final firstDate = DateTime.now();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .74,
        child: Material(
          color: FlixieColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FlixieColors.medium,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 18),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose a date',
                    style: TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: CalendarDatePicker(
                    initialDate:
                        _selected.isBefore(firstDate) ? firstDate : _selected,
                    firstDate: firstDate,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    onDateChanged: (date) => setState(() => _selected = date),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Use this date'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CandidateChoicesSheet extends StatefulWidget {
  const _CandidateChoicesSheet({required this.request, required this.userId});

  final WatchRequest request;
  final String userId;

  @override
  State<_CandidateChoicesSheet> createState() => _CandidateChoicesSheetState();
}

class _CandidateChoicesSheetState extends State<_CandidateChoicesSheet> {
  late final Set<String> _selected = widget.request.candidates
      .where((candidate) => candidate.selectedBy(widget.userId))
      .map((candidate) => candidate.id)
      .toSet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: FlixieColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Which would you be happy to watch?',
                style: TextStyle(
                    color: FlixieColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            const Text(
                'Select every option that works for you. Choose at least one to continue.',
                style: TextStyle(color: FlixieColors.medium, fontSize: 13)),
            const SizedBox(height: 12),
            ...widget.request.candidates.map((candidate) {
              final isSelected = _selected.contains(candidate.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() {
                      if (!_selected.add(candidate.id)) {
                        _selected.remove(candidate.id);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? FlixieColors.success.withValues(alpha: 0.12)
                            : FlixieColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected
                              ? FlixieColors.success
                              : FlixieColors.tabBarBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: SizedBox(
                              width: 36,
                              height: 54,
                              child: candidate.posterPath == null
                                  ? const _PosterPlaceholder()
                                  : CachedNetworkImage(
                                      imageUrl:
                                          'https://image.tmdb.org/t/p/w185${candidate.posterPath}',
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          const _PosterPlaceholder(),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(candidate.title ?? 'Untitled',
                                    style: const TextStyle(
                                        color: FlixieColors.light,
                                        fontWeight: FontWeight.w800)),
                                if (candidate.addedByUsername?.isNotEmpty ==
                                    true)
                                  Row(children: [
                                    WatchPlanCandidateAvatar(
                                      avatar: candidate.addedByAvatar,
                                      username: candidate.addedByUsername,
                                    ),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        'Suggested by ${candidate.addedByUsername}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: FlixieColors.medium,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ]),
                              ],
                            ),
                          ),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 160),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded,
                              key: ValueKey(isSelected),
                              color: isSelected
                                  ? FlixieColors.success
                                  : FlixieColors.medium,
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            if (_selected.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text('Select at least one movie to save your choices.',
                    style: TextStyle(
                        color: FlixieColors.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _selected.isEmpty
                    ? null
                    : () => Navigator.pop(context, _selected.toList()),
                child: const Text('Save choices'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WatchConfirmationSheet extends StatefulWidget {
  const _WatchConfirmationSheet({required this.request});

  final WatchRequest request;

  @override
  State<_WatchConfirmationSheet> createState() =>
      _WatchConfirmationSheetState();
}

class _WatchConfirmationSheetState extends State<_WatchConfirmationSheet> {
  bool _watched = true;

  @override
  Widget build(BuildContext context) {
    final posterPath = widget.request.movie?.posterPath;
    final posterUrl = posterPath == null
        ? null
        : 'https://image.tmdb.org/t/p/w185$posterPath';
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: FlixieColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          14,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      width: 56,
                      height: 84,
                      child: posterUrl == null
                          ? const _PosterPlaceholder()
                          : CachedNetworkImage(
                              imageUrl: posterUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const _PosterPlaceholder(),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.request.movie?.title ?? 'This movie',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.check_circle_outline),
                    label: Text('Watched'),
                  ),
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.cancel_outlined),
                    label: Text("Didn't watch"),
                  ),
                ],
                selected: {_watched},
                onSelectionChanged: (values) {
                  setState(() => _watched = values.first);
                },
              ),
              const SizedBox(height: 18),
              if (_watched) ...[
                const Text(
                  'After confirming, you can add a watch entry or write a review.',
                  style: TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ] else
                const Text(
                  'No rating or review needed.',
                  style: TextStyle(color: FlixieColors.medium, fontSize: 13),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    (
                      watched: _watched,
                      rating: null,
                      reviewText: null,
                    ),
                  ),
                  child: const Text('Submit confirmation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ---------------------------------------------------------------------------
// Placeholder
// ---------------------------------------------------------------------------

class _PosterPlaceholder extends StatelessWidget {
  const _PosterPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1E2D40),
      child: const Center(
        child: Icon(Icons.movie_outlined, color: FlixieColors.medium),
      ),
    );
  }
}
