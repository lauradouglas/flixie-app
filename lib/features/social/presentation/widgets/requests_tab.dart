import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/group_watch_plan_schedule_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/group_post_watch_section.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/group_movie_choices_section.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/group_plan_activity.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/group_focused_watch_plan.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/group_watch_plan_card.dart';
import 'package:flixie_app/features/watch_plans/controllers/group_watch_plan_controller.dart';

class _GroupRequestProviderSummary extends StatefulWidget {
  const _GroupRequestProviderSummary({
    required this.groupId,
    required this.movieId,
  });

  final String groupId;
  final int movieId;

  @override
  State<_GroupRequestProviderSummary> createState() =>
      _GroupRequestProviderSummaryState();
}

class _GroupRequestProviderSummaryState
    extends State<_GroupRequestProviderSummary> {
  String? _summary;
  bool _allMembers = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final region =
        context.read<AuthProvider>().dbUser?.watchProviderRegion ?? 'GB';
    try {
      final available =
          (await MovieService().getMovieWatchProviders(widget.movieId, region))
              .where((provider) => provider.isStreaming)
              .toList();
      final memberList = (await GroupService.getGroupMembers(widget.groupId))
          .where((member) => member.isAccepted)
          .toList();
      if (available.isEmpty || memberList.isEmpty) return;
      final savedProviders = await Future.wait(
        memberList.map(
          (member) => UserService.getUserWatchProviders(member.memberId)
              .catchError((_) => <WatchProvider>[]),
        ),
      );
      final counts = <int, int>{};
      for (final providers in savedProviders) {
        for (final id in providers.map((provider) => provider.id).toSet()) {
          counts[id] = (counts[id] ?? 0) + 1;
        }
      }
      available.sort(
        (a, b) => (counts[b.id] ?? 0).compareTo(counts[a.id] ?? 0),
      );
      final best = available.first;
      final count = counts[best.id] ?? 0;
      if (!mounted || count == 0) return;
      setState(() {
        _allMembers = count == memberList.length;
        _summary = _allMembers
            ? 'Everyone has ${best.providerName}'
            : '$count of ${memberList.length} have ${best.providerName}';
      });
    } catch (_) {
      // Provider compatibility is helpful metadata, not a blocking action.
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = _summary;
    if (summary == null) return const SizedBox.shrink();
    return Row(
      children: [
        Icon(
          Icons.live_tv_rounded,
          size: 15,
          color: _allMembers ? FlixieColors.success : FlixieColors.medium,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            summary,
            style: TextStyle(
              color: _allMembers ? FlixieColors.success : FlixieColors.medium,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

const List<String> _kRequestMonths = [
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

class GroupRequestsTab extends StatefulWidget {
  const GroupRequestsTab({
    super.key,
    required this.groupId,
    this.groupName,
    this.conversationId,
    this.initialRequests = const [],
    required this.currentUserId,
    this.isAdmin = false,
    this.onCountChanged,
    this.initialRequestId,
  });

  final String groupId;
  final String? groupName;
  final String? conversationId;
  final List<GroupWatchRequest> initialRequests;
  final String currentUserId;
  final bool isAdmin;
  final void Function(int count)? onCountChanged;
  final String? initialRequestId;

  @override
  State<GroupRequestsTab> createState() => GroupRequestsTabState();
}

class GroupRequestsTabState extends State<GroupRequestsTab> {
  late GroupWatchPlanController _controller;
  final TextEditingController _searchController = TextEditingController();

  List<GroupWatchRequest> get _requests => _controller.requests;
  set _requests(List<GroupWatchRequest> value) =>
      _controller.setRequests(value);
  bool get _loading => _controller.loading;
  set _loading(bool value) => _controller.setLoading(value);
  Map<String, bool> get _processing => _controller.processing;
  Map<String, String> get _processingResponses =>
      _controller.processingResponses;
  Map<String, String> get _myResponses => _controller.myResponses;
  Map<String, Set<String>> get _candidateChoiceDrafts =>
      _controller.candidateChoiceDrafts;
  String get _searchQuery => _controller.searchQuery;
  set _searchQuery(String value) => _controller.setSearchQuery(value);

  Future<void> _makeGroupWatchPlan() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FlixieColors.surface,
      builder: (_) => MovieWatchRequestSheet(
        movieId: null,
        movieTitle: null,
        requesterId: widget.currentUserId,
        friends: const [],
        initialGroupId: widget.groupId,
        onSuccess: () {
          _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Watch Plan sent to the group')),
            );
          }
        },
        onError: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not create the Watch Plan'),
                backgroundColor: FlixieColors.danger,
              ),
            );
          }
        },
      ),
    );
  }

  GroupWatchPlanFilter get _filter => _controller.filter;
  set _filter(GroupWatchPlanFilter value) => _controller.setFilter(value);

  String get _emptyMessage {
    switch (_filter) {
      case GroupWatchPlanFilter.active:
        return 'No active Watch Plans right now.';
      case GroupWatchPlanFilter.needsResponse:
        return 'Nothing needs your response.';
      case GroupWatchPlanFilter.completed:
        return 'No completed watches yet.';
      case GroupWatchPlanFilter.byMe:
        return "You haven't created any Watch Plans yet.";
      case GroupWatchPlanFilter.all:
        return 'No Watch Plans yet.';
    }
  }

  int get _activeCount => _controller.activeCount;
  int get _completedCount => _controller.completedCount;
  int get _needsResponseCount => _controller.needsResponseCount;

  bool _needsCurrentUserResponse(GroupWatchRequest request) =>
      _controller.needsResponse(request);

  @override
  void dispose() {
    _searchController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _controller = GroupWatchPlanController(
      currentUserId: widget.currentUserId,
      initialRequests: widget.initialRequests,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(GroupRequestsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRequests != oldWidget.initialRequests &&
        widget.initialRequests.isNotEmpty) {
      setState(() => _requests = widget.initialRequests);
    }
    // Reload via the new endpoint as soon as a conversationId becomes available.
    if (widget.conversationId != null && oldWidget.conversationId == null) {
      _load();
    }
  }

  Future<void> _load() async {
    if (mounted && _requests.isEmpty) setState(() => _loading = true);
    try {
      // The Postgres group request is the canonical Watch Plan state. The
      // Firestore conversation mirror only carries enough data for chat
      // previews, so using it here after opening Chat was replacing rich
      // plans (candidates, participants, actions) with partial records.
      final requests =
          await context.read<WatchRequestCache>().refreshGroup(widget.groupId);
      for (final request in requests) {
        final scheduledFor = DateTime.tryParse(request.scheduledFor ?? '');
        if (scheduledFor != null && scheduledFor.isAfter(DateTime.now())) {
          PushNotificationService.scheduleWatchPlanReminders(
            planId: request.databaseRequestId ?? request.id,
            scheduledFor: scheduledFor.toLocal(),
            title: request.movieTitle ?? 'Group watch',
            withName: widget.groupName ?? 'your group',
            deepLink: '/groups/${widget.groupId}?tab=plans',
            scope: 'GROUP',
          );
        }
      }
      if (mounted) {
        final focusedId = widget.initialRequestId;
        final fetchedFocusedRequest = focusedId == null ||
            focusedId.isEmpty ||
            requests.any((request) => request.matchesId(focusedId));
        // Conversation data can arrive a frame after the Postgres group data.
        // Do not replace an already-visible focused request with an incomplete
        // mirror response while those stores synchronise.
        final nextRequests = !fetchedFocusedRequest &&
                _requests.any((request) => request.matchesId(focusedId))
            ? _requests
            : requests;
        setState(() {
          _requests = nextRequests;
          _loading = false;
        });
        final currentUserId = widget.currentUserId;
        final needsResponseCount = nextRequests.where((r) {
          if (!r.canRespond) return false;
          if (r.userId == currentUserId) return false;
          if (r.currentUserResponse != null) return false;
          return !r.memberStatuses.any((s) =>
              s.memberId == currentUserId &&
              (s.status == 'ACCEPTED' ||
                  s.status == 'DECLINED' ||
                  s.status == 'MAYBE'));
        }).length;
        widget.onCountChanged?.call(needsResponseCount);
      }
    } catch (e) {
      logger.e('RequestsTab load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  List<GroupWatchRequest> get _filtered =>
      _controller.filtered(focusedId: widget.initialRequestId);

  Future<void> _respond(GroupWatchRequest req, String status) async {
    final userId = widget.currentUserId;
    if (userId.isEmpty) return;

    // Prefer the widget-level conversationId; fall back to the one embedded
    // in the request (set when loaded via getConversationWatchRequests).
    final convId = widget.conversationId ?? req.groupId;

    setState(() {
      _processing[req.id] = true;
      _processingResponses[req.id] = status;
    });
    try {
      final analytics = context.read<AnalyticsController>();
      final decision = WatchResponseDecision.fromString(status);
      try {
        await GroupService.respondToWatchRequest(
            convId, req.id, userId, decision);
      } catch (e) {
        logger.d('New respond endpoint failed, using legacy: $e');
        await GroupService.updateWatchRequestForMember(
            req.id, userId, '', status);
      }
      if (decision == WatchResponseDecision.accepted) {
        await analytics.watchPlanAccepted(
          watchPlanId: req.databaseRequestId ?? req.id,
          contentId: req.mediaId,
          contentType: req.analyticsContentType,
          planType: 'group',
          participantCount: req.analyticsParticipantCount,
          source: 'group',
        );
      }
      if (mounted) setState(() => _myResponses[req.id] = status);
      if (status == 'ACCEPTED' && mounted) {
        final auth = context.read<AuthProvider>();
        final cached = auth.cachedNotifications;
        if (cached != null) {
          auth.updateCachedNotifications(
            cached.where((notification) {
              final linkedId = notification.linkedRequestId;
              return linkedId == null || !req.matchesId(linkedId);
            }).toList(growable: false),
          );
        }
      }
      await _load();
    } catch (e) {
      logger.e('Respond to watch request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update Watch Plan')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processing.remove(req.id);
          _processingResponses.remove(req.id);
        });
      }
    }
  }

  String _groupPlanRequestId(GroupWatchRequest request) =>
      request.databaseRequestId ?? request.id;

  Set<String> _candidateChoicesFor(GroupWatchRequest request) {
    return _candidateChoiceDrafts.putIfAbsent(
      request.id,
      () => request.candidates
          .where((candidate) =>
              candidate.selectedByUserIds.contains(widget.currentUserId))
          .map((candidate) => candidate.id)
          .toSet(),
    );
  }

  SnackBar _successToast(String message) => SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: FlixieColors.surfaceElevated,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: FlixieColors.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: FlixieColors.light, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  void _replaceGroupPlan(GroupWatchRequest updated) {
    setState(() {
      // A plan can be keyed by either its chat mirror ID or Postgres request
      // ID. Clear every matching draft, otherwise a newly added option keeps
      // the old local selection state and misses its green outline.
      final matchingIds = _requests
          .where((request) => request.matchesId(updated.id))
          .expand((request) => <String>[
                request.id,
                if (request.databaseRequestId != null)
                  request.databaseRequestId!,
              ])
          .toSet();
      matchingIds.add(updated.id);
      if (updated.databaseRequestId != null) {
        matchingIds.add(updated.databaseRequestId!);
      }
      _controller.replaceRequest(updated);
      _candidateChoiceDrafts.removeWhere((key, _) => matchingIds.contains(key));
    });
    // Group Watch Plans are also rendered in the main Watch Plans overview
    // and Home. Their lists own separate snapshots, so notify them after any
    // movie-option add/remove/update rather than waiting for a manual pull.
    TabRefreshController.requestSocialRefresh();
    TabRefreshController.requestHomeRefresh();
  }

  Future<void> _saveGroupCandidateChoices(GroupWatchRequest request) async {
    final choices = _candidateChoicesFor(request).toList(growable: false);
    if (choices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Select at least one movie you would watch'),
        backgroundColor: FlixieColors.danger,
      ));
      return;
    }
    setState(() => _processing[request.id] = true);
    try {
      final updated = await GroupService.saveWatchPlanChoices(
        _groupPlanRequestId(request),
        widget.currentUserId,
        choices,
      );
      if (!mounted) return;
      _replaceGroupPlan(updated);
      // Re-read the canonical Postgres plan after saving. This avoids a chat
      // mirror or a partially populated mutation response reverting the
      // visible choices on the next frame.
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(_successToast('Movies you’d watch saved'));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString()),
        backgroundColor: FlixieColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _processing.remove(request.id));
    }
  }

  Future<void> _removeGroupCandidate(
    GroupWatchRequest request,
    String candidateId,
  ) async {
    setState(() => _processing[request.id] = true);
    try {
      final updated = await GroupService.removeWatchPlanCandidate(
        _groupPlanRequestId(request),
        widget.currentUserId,
        candidateId,
      );
      if (!mounted) return;
      _replaceGroupPlan(updated);
      ScaffoldMessenger.of(context)
          .showSnackBar(_successToast('Movie option removed'));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString()),
        backgroundColor: FlixieColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _processing.remove(request.id));
    }
  }

  Future<void> _addGroupCandidate(GroupWatchRequest request) async {
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
              .where((item) => !existingMovieIds.contains(item.id))
              .toList(growable: false);
        },
      ),
    );
    if (!mounted || movie == null) return;
    setState(() => _processing[request.id] = true);
    try {
      final updated = await GroupService.addWatchPlanCandidate(
        _groupPlanRequestId(request),
        widget.currentUserId,
        movie.id,
      );
      if (!mounted) return;
      _replaceGroupPlan(updated);
      ScaffoldMessenger.of(context)
          .showSnackBar(_successToast('Movie option added'));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString()),
        backgroundColor: FlixieColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _processing.remove(request.id));
    }
  }

  Future<void> _selectGroupFinalMovie(
      GroupWatchRequest request, String candidateId) async {
    setState(() => _processing[request.id] = true);
    try {
      final updated = await GroupService.selectWatchPlanMovie(
        _groupPlanRequestId(request),
        widget.currentUserId,
        candidateId,
      );
      if (!mounted) return;
      _replaceGroupPlan(updated);
      ScaffoldMessenger.of(context)
          .showSnackBar(_successToast('Final movie chosen'));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString()),
        backgroundColor: FlixieColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _processing.remove(request.id));
    }
  }

  Future<void> _changeGroupFinalMovie(GroupWatchRequest request) async {
    setState(() => _processing[request.id] = true);
    try {
      final updated = await GroupService.reopenWatchPlanMovieSelection(
        _groupPlanRequestId(request),
        widget.currentUserId,
      );
      if (!mounted) return;
      _replaceGroupPlan(updated);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(_successToast('Choose a new final movie'));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error.toString()),
        backgroundColor: FlixieColors.danger,
      ));
    } finally {
      if (mounted) setState(() => _processing.remove(request.id));
    }
  }

  Future<void> _markWatched(
    GroupWatchRequest req, {
    int? rating,
    bool? recommended,
    String? reviewText,
    String? watchedAt,
  }) async {
    final userId = widget.currentUserId;
    final convId = widget.conversationId ?? req.groupId;
    final analytics = context.read<AnalyticsController>();
    setState(() => _processing[req.id] = true);
    try {
      final updated = await GroupService.completeWatchRequest(
        convId,
        req.id,
        userId,
        rating: rating,
        recommended: recommended,
        reviewText: reviewText,
        watchedAt: watchedAt,
      );
      if (req.status != WatchRequestStatus.completed &&
          updated.status == WatchRequestStatus.completed) {
        await analytics.watchPlanCompleted(
          watchPlanId: updated.databaseRequestId ?? updated.id,
          contentId: updated.mediaId,
          contentType: updated.analyticsContentType,
          planType: 'group',
          participantCount: updated.analyticsParticipantCount,
          source: 'group',
        );
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('"${req.movieTitle ?? 'Watch Plan'}" marked as watched!'),
            backgroundColor: FlixieColors.surfaceElevated,
          ),
        );
      }
    } catch (e) {
      logger.e('Mark watched error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark as watched')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(req.id));
    }
  }

  Future<void> _logGroupWatch(GroupWatchRequest req) async {
    int? movieId = req.mediaType?.toLowerCase() == 'movie' ? req.mediaId : null;
    if (movieId == null) {
      for (final candidate in req.candidates) {
        if (candidate.id == req.selectedCandidateId) {
          movieId = candidate.movieId;
          break;
        }
      }
    }
    if (movieId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This plan does not have a movie to log')),
      );
      return;
    }

    var saved = false;
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
          // The group completion endpoint creates the same MovieWatchEntry
          // used everywhere else in the app. Keeping this as one write avoids
          // duplicate entries and preserves the explicit recommendation.
          await context.read<AnalyticsController>().watchLogged(
                contentType: 'movie',
                contentId: movieId!,
                source: 'group_watch_plan',
                watchPlanId: req.databaseRequestId ?? req.id,
                planType: 'group',
                participantCount: req.analyticsParticipantCount,
              );
          saved = true;
          await _markWatched(
            req,
            rating: rating?.round(),
            recommended: recommended,
            reviewText: notes,
            watchedAt: watchedAt,
          );
          await PushNotificationService.cancelWatchPlanReminders(
            req.databaseRequestId ?? req.id,
            scope: 'GROUP',
          );
          if (mounted) context.read<AuthProvider>().markActivityChanged();
        },
      ),
    );
    if (!mounted || !saved) return;
  }

  Future<void> _scheduleRequest(GroupWatchRequest req,
      {String? initialIso}) async {
    final selected =
        await showModalBottomSheet<({DateTime scheduledFor, String? location})>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GroupWatchPlanScheduleSheet(
        initial: DateTime.tryParse(initialIso ?? '')?.toLocal(),
        initialLocation: req.location,
      ),
    );
    if (!mounted || selected == null) return;

    final userId = widget.currentUserId;
    final convId = widget.conversationId ?? req.groupId;
    final analytics = context.read<AnalyticsController>();
    setState(() => _processing[req.id] = true);
    try {
      final updated = await GroupService.scheduleWatchRequest(
        convId,
        req.id,
        userId: userId,
        scheduledFor: selected.scheduledFor.toUtc().toIso8601String(),
        location: selected.location,
      );
      await analytics.watchPlanScheduled(
        watchPlanId: updated.databaseRequestId ?? updated.id,
        contentId: updated.mediaId,
        contentType: updated.analyticsContentType,
        planType: 'group',
        participantCount: updated.analyticsParticipantCount,
        source: 'group',
      );
      await PushNotificationService.scheduleWatchPlanReminders(
        planId: updated.databaseRequestId ?? updated.id,
        scheduledFor: selected.scheduledFor,
        title: updated.movieTitle ?? 'Group watch',
        withName: widget.groupName ?? 'your group',
        deepLink: '/groups/${widget.groupId}?tab=plans',
        scope: 'GROUP',
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            // Scaffold already keeps floating snackbars above the bottom
            // navigation bar. An extra nav-height margin pushed this toast
            // into the middle of the Watch Plan on smaller phones.
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(
                color: FlixieColors.success.withValues(alpha: .38),
              ),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: FlixieColors.success,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Scheduled for ${_fullDateTime(selected.scheduledFor)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: FlixieColors.surfaceElevated,
            duration: const Duration(seconds: 5),
            persist: false,
            action: SnackBarAction(
              label: 'Calendar',
              textColor: FlixieColors.success,
              onPressed: () => WatchCalendarService.addScheduledWatch(
                title: req.movieTitle ?? 'Watch together',
                scheduledFor: selected.scheduledFor,
                note: req.message,
                location: selected.location ?? req.location,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      logger.e('Schedule watch request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to schedule watch')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(req.id));
    }
  }

  Future<void> _cancelRequest(GroupWatchRequest req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FlixieColors.tabBarBackground,
        title: const Text('Cancel Watch Plan?',
            style: TextStyle(color: FlixieColors.white)),
        content: Text(
          'Cancel the Watch Plan for "${req.movieTitle ?? 'this movie'}"?',
          style: const TextStyle(color: FlixieColors.light),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child:
                const Text('No', style: TextStyle(color: FlixieColors.medium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancel Watch Plan',
                style: TextStyle(color: FlixieColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final userId = widget.currentUserId;
    final convId = widget.conversationId ?? req.groupId;
    setState(() => _processing[req.id] = true);
    try {
      await GroupService.cancelWatchRequest(convId, req.id, userId);
      await _load();
    } catch (e) {
      logger.e('Cancel watch request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to cancel Watch Plan')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(req.id));
    }
  }

  Widget _filterChip(GroupWatchPlanFilter f, String label) {
    final selected = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _filter = f),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected
                ? FlixieColors.primary
                : FlixieColors.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? FlixieColors.primary
                  : FlixieColors.primary.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, color: Colors.black, size: 16),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : FlixieColors.light,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) {
        return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
      }
      const months = [
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
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  String _fullDateTime(DateTime value) {
    final local = value.toLocal();
    if (value.isUtc && value.hour == 12 && value.minute == 0) {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return 'Watch on ${weekdays[local.weekday - 1]}';
    }
    final time = TimeOfDay.fromDateTime(local).format(context);
    return '${local.day} ${_kRequestMonths[local.month - 1]}, $time';
  }

  String _fullDateTimeString(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    return _fullDateTime(dt);
  }

  Widget _buildSummaryStrip() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child:
                    _summaryTile('Active', _activeCount, FlixieColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryTile(
                    'Needs reply', _needsResponseCount, FlixieColors.warning),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _summaryTile(
                    'Watched', _completedCount, FlixieColors.success),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _makeGroupWatchPlan,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Make a Watch Plan'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String? _currentUserStatus(GroupWatchRequest req) {
    final currentUserId = widget.currentUserId;
    return _myResponses[req.id] ??
        req.currentUserResponse?.apiValue ??
        req.memberStatuses
            .where((s) => s.memberId == currentUserId)
            .map((s) => s.status)
            .where((s) => s == 'ACCEPTED' || s == 'DECLINED' || s == 'MAYBE')
            .firstOrNull;
  }

  Widget _responseButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    bool filled = false,
    bool loading = false,
  }) {
    final style = filled
        ? ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: color,
            padding: const EdgeInsets.symmetric(vertical: 10),
            side: BorderSide(color: color.withValues(alpha: 0.5)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          );

    final child = loading
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.black,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    if (filled) {
      return ElevatedButton(onPressed: onPressed, style: style, child: child);
    }
    return OutlinedButton(onPressed: onPressed, style: style, child: child);
  }

  Widget _responseActions(GroupWatchRequest req) {
    final processingResponse = _processingResponses[req.id];
    final isProcessing = processingResponse != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your response',
          style: TextStyle(
            color: FlixieColors.medium,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _responseButton(
                label: 'Decline',
                icon: Icons.cancel_outlined,
                color: FlixieColors.danger,
                onPressed:
                    isProcessing ? null : () => _respond(req, 'DECLINED'),
                loading: processingResponse == 'DECLINED',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _responseButton(
                label: 'Maybe',
                icon: Icons.help_outline,
                color: FlixieColors.warning,
                onPressed: isProcessing ? null : () => _respond(req, 'MAYBE'),
                loading: processingResponse == 'MAYBE',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: _responseButton(
                label: 'Accept',
                icon: Icons.check_circle_outline,
                color: FlixieColors.primary,
                onPressed:
                    isProcessing ? null : () => _respond(req, 'ACCEPTED'),
                filled: true,
                loading: processingResponse == 'ACCEPTED',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _manageActions(GroupWatchRequest req) {
    final userId = widget.currentUserId;
    final showScheduling =
        req.canScheduleFor(userId) || _canScheduleAsParticipant(req);

    final scheduledFor = DateTime.tryParse(req.scheduledFor ?? '')?.toLocal();
    final isAfterWatchTime =
        scheduledFor != null && !scheduledFor.isAfter(DateTime.now());
    // The creator is an implicit participant in a group plan, but older
    // plans do not always include an explicit accepted response for them.
    // They should still be able to log a completed scheduled watch.
    final canLogWatch = req.canCompleteFor(userId) ||
        (isAfterWatchTime && req.isActive && req.canCancelFor(userId));
    if (scheduledFor != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isAfterWatchTime) ...[
            const Text(
              "After you've watched",
              style: TextStyle(
                color: FlixieColors.light,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Log this viewing when the group has finished watching.',
              style: TextStyle(color: FlixieColors.medium, fontSize: 12),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: canLogWatch ? () => _logGroupWatch(req) : null,
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Log watch'),
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
          _GroupPlanDetailRow(
            icon: Icons.event_available_outlined,
            label: 'Scheduled',
            value: _fullDateTime(scheduledFor),
          ),
          const SizedBox(height: 10),
          _GroupPlanDetailRow(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: req.location?.trim().isNotEmpty == true
                ? req.location!.trim()
                : 'Not set',
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => WatchCalendarService.addScheduledWatch(
                  title: req.movieTitle ?? 'Watch together',
                  scheduledFor: scheduledFor,
                  note: req.message,
                  location: req.location,
                ),
                child: const Text('Add to calendar'),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: OutlinedButton(
                onPressed: showScheduling
                    ? () => _scheduleRequest(req, initialIso: req.scheduledFor)
                    : null,
                child: const Text('Edit plan'),
              ),
            ),
          ]),
          if (req.canCancelFor(userId)) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _cancelRequest(req),
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                label: const Text('Close watch plan'),
              ),
            ),
          ],
        ],
      );
    }
    if (!showScheduling) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Plan the details',
            style: TextStyle(
                color: FlixieColors.light,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('Choose a time and add a place if you have one.',
            style: TextStyle(color: FlixieColors.medium, fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () =>
                _scheduleRequest(req, initialIso: req.proposedDate),
            icon: const Icon(Icons.edit_calendar_outlined),
            label: const Text('Suggest a time'),
          ),
        ),
      ],
    );
  }

  bool _canScheduleAsParticipant(GroupWatchRequest req) {
    if (req.status != WatchRequestStatus.accepted &&
        req.status != WatchRequestStatus.scheduled) {
      return false;
    }
    final currentUserId = widget.currentUserId;
    if (req.userId == currentUserId) return true;
    if (req.currentUserResponse != null) return true;
    return req.memberStatuses.any((s) => s.memberId == currentUserId);
  }

  Widget _groupPlanStage(GroupWatchRequest req, bool isMyRequest) {
    final needsReply = _needsCurrentUserResponse(req);
    final isScheduled =
        req.status == WatchRequestStatus.scheduled || req.scheduledFor != null;
    final isCompleted = req.status == WatchRequestStatus.completed;
    final label = isCompleted
        ? 'WATCH PLAN · WATCHED'
        : isScheduled
            ? 'WATCH PLAN · UPCOMING'
            : needsReply
                ? 'WATCH PLAN · NEEDS REPLY'
                : req.status == WatchRequestStatus.accepted
                    ? 'WATCH PLAN · PLANNING'
                    : isMyRequest
                        ? 'WATCH PLAN · WAITING FOR REPLIES'
                        : 'WATCH PLAN · INVITED';
    final color = isCompleted
        ? FlixieColors.success
        : isScheduled
            ? FlixieColors.secondary
            : needsReply
                ? FlixieColors.warning
                : FlixieColors.primary;
    return Row(
      children: [
        Icon(
          isCompleted
              ? Icons.check_circle_outline_rounded
              : isScheduled
                  ? Icons.event_available_outlined
                  : needsReply
                      ? Icons.mark_email_unread_outlined
                      : Icons.movie_filter_outlined,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              letterSpacing: .6,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestCard(GroupWatchRequest req) {
    final currentUserId = widget.currentUserId;
    final isMyRequest = req.userId == currentUserId;
    final canManage = req.canScheduleFor(currentUserId) ||
        req.canCompleteFor(currentUserId) ||
        _canScheduleAsParticipant(req);
    final posterUrl = req.moviePosterPath == null
        ? null
        : 'https://image.tmdb.org/t/p/w185${req.moviePosterPath}';
    final proposedDate =
        _fullDateTimeString(req.scheduledFor ?? req.proposedDate);

    if (widget.initialRequestId?.isNotEmpty == true) {
      return _buildFocusedWatchPlan(
        req,
        isMyRequest: isMyRequest,
        canManage: canManage,
        isProcessing: _processing[req.id] == true,
        myStatus: _currentUserStatus(req),
        posterUrl: posterUrl,
        proposedDate: proposedDate,
      );
    }

    return GroupWatchPlanCard(
      request: req,
      isMyRequest: isMyRequest,
      needsResponse: _needsCurrentUserResponse(req),
      posterUrl: posterUrl,
      proposedDate: proposedDate,
      createdDate: _formatDate(req.createdAt),
      onOpen: () => context.push(
        '/groups/${widget.groupId}?tab=requests&requestId=${req.id}',
      ),
    );
  }

  Widget _buildFocusedWatchPlan(
    GroupWatchRequest req, {
    required bool isMyRequest,
    required bool canManage,
    required bool isProcessing,
    required String? myStatus,
    required String? posterUrl,
    required String proposedDate,
  }) {
    final scheduledAt = DateTime.tryParse(req.scheduledFor ?? '')?.toLocal();
    return GroupFocusedWatchPlan(
      req: req,
      isMyRequest: isMyRequest,
      canManage: canManage,
      isProcessing: isProcessing,
      needsReply: _needsCurrentUserResponse(req),
      posterUrl: posterUrl,
      proposedDate: proposedDate,
      stage: _groupPlanStage(req, isMyRequest),
      responseActions: _responseActions(req),
      manageActions: _manageActions(req),
      movieChoicesBuilder: (_) => _groupMovieChoicesSection(req, myStatus),
      activity: GroupPlanActivity(
        req: req,
        formatDateTimeString: _fullDateTimeString,
      ),
      completedContent: _groupPostWatchSection(
        req: req,
        posterUrl: posterUrl,
        completed: true,
      ),
      postWatchContent: _groupPostWatchSection(
        req: req,
        posterUrl: posterUrl,
        scheduledAt: scheduledAt,
        completed: false,
      ),
      onChangeMovie: () => _changeGroupFinalMovie(req),
    );
  }

  Widget _groupPostWatchSection({
    required GroupWatchRequest req,
    required String? posterUrl,
    required bool completed,
    DateTime? scheduledAt,
  }) =>
      GroupPostWatchSection(
        req: req,
        currentUserId: widget.currentUserId,
        groupName: widget.groupName,
        posterUrl: posterUrl,
        scheduledAt: scheduledAt,
        completed: completed,
        formatDateTime: _fullDateTime,
        formatDateTimeString: _fullDateTimeString,
        onLogWatch: () => _logGroupWatch(req),
        onNotThisTime: () => _cancelRequest(req),
        onReschedule: () => _scheduleRequest(req, initialIso: req.scheduledFor),
        onOpenChat: () => context.push('/groups/${widget.groupId}?tab=chat'),
      );

  Widget _groupMovieChoicesSection(
    GroupWatchRequest request,
    String? myStatus,
  ) {
    final choices = _candidateChoicesFor(request);
    return GroupMovieChoicesSection(
      request: request,
      myStatus: myStatus,
      currentUserId: widget.currentUserId,
      choices: choices,
      processing: _processing[request.id] == true,
      onToggleCandidate: (candidateId) => setState(() {
        if (!choices.add(candidateId)) choices.remove(candidateId);
      }),
      onSaveChoices: () => _saveGroupCandidateChoices(request),
      onAddCandidate: () => _addGroupCandidate(request),
      onRemoveCandidate: (candidateId) =>
          _removeGroupCandidate(request, candidateId),
      onSelectFinalMovie: (candidateId) =>
          _selectGroupFinalMovie(request, candidateId),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final displayed = _filtered;

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: Column(
        children: [
          if (widget.initialRequestId?.isNotEmpty != true) _buildSummaryStrip(),
          // Search bar
          if (widget.initialRequestId?.isNotEmpty != true)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: const TextStyle(color: FlixieColors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by movie or member…',
                  hintStyle:
                      const TextStyle(color: FlixieColors.medium, fontSize: 14),
                  prefixIcon: const Icon(Icons.search,
                      color: FlixieColors.medium, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              color: FlixieColors.medium, size: 18),
                          onPressed: () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          }),
                        )
                      : null,
                  filled: true,
                  fillColor: FlixieColors.tabBarBackgroundFocused,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          // Filter chips
          if (widget.initialRequestId?.isNotEmpty != true)
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _filterChip(GroupWatchPlanFilter.active, 'Active'),
                  _filterChip(
                      GroupWatchPlanFilter.needsResponse, 'Needs Response'),
                  _filterChip(GroupWatchPlanFilter.completed, 'Completed'),
                  _filterChip(GroupWatchPlanFilter.byMe, 'By Me'),
                  _filterChip(GroupWatchPlanFilter.all, 'All'),
                ],
              ),
            ),
          const SizedBox(height: 4),
          // List
          Expanded(
            child: displayed.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Semantics(
                            label: _searchQuery.isNotEmpty
                                ? 'No Watch Plans match'
                                : _emptyMessage,
                            child: Icon(
                              _filter == GroupWatchPlanFilter.completed
                                  ? Icons.movie_outlined
                                  : Icons.inbox_outlined,
                              color: FlixieColors.medium,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No Watch Plans match.'
                                : _emptyMessage,
                            style: const TextStyle(color: FlixieColors.medium),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                    itemCount: displayed.length,
                    itemBuilder: (_, i) => _buildRequestCard(displayed[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _GroupPlanDetailRow extends StatelessWidget {
  const _GroupPlanDetailRow({
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
        Icon(icon, color: FlixieColors.secondary, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 14),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: const TextStyle(color: FlixieColors.medium),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
