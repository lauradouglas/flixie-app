import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/group.dart';
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
import 'package:flixie_app/features/social/presentation/widgets/group_watch_requests_overview.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_formatters.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_section_builder.dart';
import 'package:flixie_app/features/watch_plans/presentation/sheets/watch_plan_candidate_choices_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/sheets/watch_plan_location_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/sheets/watch_plan_schedule_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_card.dart';

enum _RequestAudience { friends, groups }

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
  WatchPlanFilter _statusFilter = WatchPlanFilter.active;
  final Map<String, FriendWatchPlanAction> _busyActions = {};
  List<Group> _groups = [];
  bool _loadingGroups = true;
  _RequestAudience _audience = _RequestAudience.friends;
  bool _showSearch = false;
  final Map<String, FriendAcceptanceScheduleDraft> _acceptScheduleDrafts = {};
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

  bool _matchesStatusFilter(WatchRequest request) =>
      _matchesFilter(request, _statusFilter);

  bool _matchesFilter(WatchRequest request, WatchPlanFilter filter) =>
      WatchPlanDisplayState.matchesFilter(
        request,
        filter,
        context.read<AuthProvider>().dbUser?.id ?? '',
      );

  DateTime _parseDate(String? iso) =>
      DateTime.tryParse(iso ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  String _formatDate(String? iso) => formatWatchPlanDate(iso);

  String _formatFriendlyDateTime(DateTime? value) =>
      formatWatchPlanDateTime(value);

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

    await _withRequestAction(request, FriendWatchPlanAction.deleting, () async {
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
    FriendWatchPlanAction action,
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
      'ACCEPTED' => FriendWatchPlanAction.accepting,
      'DECLINED' => FriendWatchPlanAction.declining,
      _ => FriendWatchPlanAction.maybe,
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
      _acceptScheduleDrafts[request.id] = FriendAcceptanceScheduleDraft(
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
      FriendAcceptanceScheduleDraft(
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
      builder: (_) => WatchPlanScheduleSheet(
        initial: initial,
        initialLocation: initialLocation,
      ),
    );
  }

  Future<void> _submitScheduleProposal(
    WatchRequest request,
    FriendAcceptanceScheduleDraft selected,
  ) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;

    await _withRequestAction(request, FriendWatchPlanAction.scheduling,
        () async {
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
      builder: (_) => WatchPlanLocationSheet(
        initialLocation: request.location,
      ),
    );
    if (!mounted || location == null || location.isEmpty) return;

    await _withRequestAction(request, FriendWatchPlanAction.scheduling,
        () async {
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

    await _withRequestAction(request, FriendWatchPlanAction.scheduling,
        () async {
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
          await _withRequestAction(request, FriendWatchPlanAction.completing,
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
    await _withRequestAction(request, FriendWatchPlanAction.declining,
        () async {
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
                      FriendWatchPlanAction.deleting,
                  icon: _busyActions[_filtered.first.id] ==
                          FriendWatchPlanAction.deleting
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
    const filters = [WatchPlanFilter.active, WatchPlanFilter.completed];
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
                  label: Text(filter == WatchPlanFilter.active
                      ? 'Active · ${_countFor(WatchPlanFilter.active)}'
                      : 'Past · ${_countFor(WatchPlanFilter.completed)}'),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _statusFilter =
                        selected ? WatchPlanFilter.active : filter);
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
        _statusFilter != WatchPlanFilter.active ||
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

    final sections = WatchPlanSectionBuilder.friendSections(
      _filtered,
      myUserId,
    );

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
      sections.needsReply,
    );
    addSection('Upcoming', 'Your agreed watch plans', sections.upcoming);
    addSection('Ready to wrap up', 'The planned time has passed',
        sections.readyToWrapUp);
    addSection(
      'Scheduling in progress',
      'Invites waiting or being arranged',
      sections.planning,
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

  Widget _buildRequestCard(
    WatchRequest request,
    bool isFocused,
    String myUserId,
  ) {
    return FriendWatchPlanCard(
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
      onNotThisTime: () => _markNotThisTime(request),
    );
  }

  Future<void> _markNotThisTime(WatchRequest request) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    await RequestService.confirmWatchRequest(
      watchRequestId: request.id,
      userId: userId,
      watched: false,
    );
    await _refreshRequestState(request, userId);
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
    await _withRequestAction(request, FriendWatchPlanAction.savingMovieChoices,
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
      builder: (_) => WatchPlanCandidateChoicesSheet(
        request: request,
        userId: userId,
      ),
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
    await _withRequestAction(request, FriendWatchPlanAction.scheduling,
        () async {
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
    await _withRequestAction(request, FriendWatchPlanAction.removingCandidate,
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
    await _withRequestAction(request, FriendWatchPlanAction.selectingMovie,
        () async {
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
    await _withRequestAction(request, FriendWatchPlanAction.selectingMovie,
        () async {
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

  String _filterLabel(WatchPlanFilter f) {
    switch (f) {
      case WatchPlanFilter.active:
        return 'Active';
      case WatchPlanFilter.needsResponse:
        return 'Needs reply ${_countFor(WatchPlanFilter.needsResponse)}';
      case WatchPlanFilter.planning:
        return 'Planning';
      case WatchPlanFilter.scheduled:
        return 'Upcoming ${_countFor(WatchPlanFilter.scheduled)}';
      case WatchPlanFilter.completed:
        return 'Past';
      case WatchPlanFilter.declined:
        return 'Declined';
      case WatchPlanFilter.cancelled:
        return 'Cancelled';
      case WatchPlanFilter.expired:
        return 'Expired';
    }
  }

  int _countFor(WatchPlanFilter filter) {
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
                    _statusFilter != WatchPlanFilter.active
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
