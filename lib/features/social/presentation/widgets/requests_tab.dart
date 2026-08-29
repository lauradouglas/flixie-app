import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/request_poster_placeholder.dart';
import 'package:flixie_app/features/social/presentation/widgets/watch_plan_candidate_avatar.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';

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

enum _RequestFilter { all, needsResponse, active, completed, byMe }

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
  late List<GroupWatchRequest> _requests;
  bool _loading = false;
  final Map<String, bool> _processing = {};
  final Map<String, String> _processingResponses = {};
  final Map<String, String> _myResponses = {};
  final Map<String, Set<String>> _candidateChoiceDrafts = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

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

  _RequestFilter _filter = _RequestFilter.active;

  String get _emptyMessage {
    switch (_filter) {
      case _RequestFilter.active:
        return 'No active requests right now.';
      case _RequestFilter.needsResponse:
        return 'Nothing needs your response.';
      case _RequestFilter.completed:
        return 'No completed watches yet.';
      case _RequestFilter.byMe:
        return "You haven't created any Watch Plans yet.";
      case _RequestFilter.all:
        return 'No Watch Plans yet.';
    }
  }

  int get _activeCount => _requests.where((r) => r.isActive).length;

  int get _completedCount =>
      _requests.where((r) => r.status == WatchRequestStatus.completed).length;

  int get _needsResponseCount =>
      _requests.where(_needsCurrentUserResponse).length;

  bool _hasUserResponded(GroupWatchRequest request) {
    final currentUserId = widget.currentUserId;
    final localResponse = _myResponses[request.id];
    if (localResponse != null) return true;
    if (request.currentUserResponse != null) return true;
    return request.memberStatuses.any(
      (s) =>
          s.memberId == currentUserId &&
          (s.status == 'ACCEPTED' ||
              s.status == 'DECLINED' ||
              s.status == 'MAYBE'),
    );
  }

  bool _needsCurrentUserResponse(GroupWatchRequest request) {
    if (!request.canRespond) return false;
    if (request.userId == widget.currentUserId) return false;
    return !_hasUserResponded(request);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _requests = widget.initialRequests;
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

  List<GroupWatchRequest> get _filtered {
    final currentUserId = widget.currentUserId;
    var list = _requests;

    final focusedId = widget.initialRequestId;
    if (focusedId != null && focusedId.isNotEmpty) {
      return _sortRequests(list.where((r) => r.matchesId(focusedId)).toList());
    }

    // Apply filter chip
    switch (_filter) {
      case _RequestFilter.active:
        // Active = open + scheduled; hide expired/cancelled by default
        list = list.where((r) => r.isActive).toList();
      case _RequestFilter.needsResponse:
        list = list.where(_needsCurrentUserResponse).toList();
      case _RequestFilter.completed:
        list = list
            .where((r) => r.status == WatchRequestStatus.completed)
            .toList();
      case _RequestFilter.byMe:
        list = list.where((r) => r.userId == currentUserId).toList();
      case _RequestFilter.all:
        // Show everything, including expired and cancelled
        break;
    }

    // Apply search
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((r) {
        return (r.movieTitle ?? '').toLowerCase().contains(q) ||
            (r.requesterUsername ?? '').toLowerCase().contains(q) ||
            (r.message ?? '').toLowerCase().contains(q);
      }).toList();
    }

    return _sortRequests(list);
  }

  List<GroupWatchRequest> _sortRequests(List<GroupWatchRequest> requests) {
    final sorted = [...requests];
    sorted.sort((a, b) {
      if (_filter == _RequestFilter.completed) {
        return _dateForSort(b.completedAt ?? b.updatedAt ?? b.createdAt)
            .compareTo(
                _dateForSort(a.completedAt ?? a.updatedAt ?? a.createdAt));
      }
      if (_filter == _RequestFilter.active ||
          _filter == _RequestFilter.needsResponse) {
        final aScheduled = _dateForSort(a.scheduledFor ?? a.proposedDate);
        final bScheduled = _dateForSort(b.scheduledFor ?? b.proposedDate);
        final aHasDate = aScheduled != DateTime.fromMillisecondsSinceEpoch(0);
        final bHasDate = bScheduled != DateTime.fromMillisecondsSinceEpoch(0);
        if (aHasDate && bHasDate) {
          return aScheduled.compareTo(bScheduled);
        }
        if (aHasDate) return -1;
        if (bHasDate) return 1;
      }
      return _dateForSort(b.lastActivityAt ?? b.updatedAt ?? b.createdAt)
          .compareTo(
              _dateForSort(a.lastActivityAt ?? a.updatedAt ?? a.createdAt));
    });
    return sorted;
  }

  DateTime _dateForSort(String? iso) {
    if (iso == null || iso.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.tryParse(iso) ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

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
          const SnackBar(content: Text('Failed to update request')),
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
      _requests = _requests
          .map((request) => request.matchesId(updated.id) ? updated : request)
          .toList(growable: false);
      _candidateChoiceDrafts.removeWhere((key, _) => matchingIds.contains(key));
    });
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
    String? reviewText,
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
        reviewText: reviewText,
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
            content: Text(
                '"${req.movieTitle ?? 'Watch request'}" marked as watched!'),
            backgroundColor: FlixieColors.success,
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
          await UserService.logMovieWatch(
            widget.currentUserId,
            LogMovieWatchRequest(
              movieId: movieId!,
              watchedAt: watchedAt,
              rating: rating,
              recommended: recommended,
              notes: notes,
            ),
          );
          // Keep the movie's main rating in sync with this watch entry. The
          // server also performs this update for group-plan completions, but
          // doing it here keeps older deployments and cached movie screens
          // consistent immediately.
          if (rating != null) {
            try {
              await context.read<MovieService>().addMovieRating(
                    movieId!,
                    widget.currentUserId,
                    rating.round(),
                    recommended,
                  );
            } catch (error, stackTrace) {
              logger.w(
                'Watch entry saved, but its movie rating could not be reconciled.',
                error: error,
                stackTrace: stackTrace,
              );
            }
          }
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
            reviewText: notes,
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
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupScheduleWatchSheet(
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
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 88),
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
        title: const Text('Cancel request?',
            style: TextStyle(color: FlixieColors.white)),
        content: Text(
          'Cancel the watch request for "${req.movieTitle ?? 'this movie'}"?',
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
            child: const Text('Cancel Request',
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
          const SnackBar(content: Text('Failed to cancel request')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(req.id));
    }
  }

  Future<void> _delete(GroupWatchRequest req) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: FlixieColors.tabBarBackground,
        title: const Text('Delete request?',
            style: TextStyle(color: FlixieColors.white)),
        content: Text(
          'Remove the watch request for "${req.movieTitle ?? 'this movie'}"?',
          style: const TextStyle(color: FlixieColors.light),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel',
                style: TextStyle(color: FlixieColors.medium)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete',
                style: TextStyle(color: FlixieColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _processing[req.id] = true);
    try {
      await GroupService.deleteWatchRequest(
        widget.groupId,
        req.id,
        widget.currentUserId,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Watch request for "${req.movieTitle ?? 'this movie'}" removed'),
            backgroundColor: FlixieColors.success,
          ),
        );
      }
    } catch (e) {
      logger.e('Delete watch request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete request. Please try again.'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(req.id));
    }
  }

  Widget _myStatusChip(String label, Color color) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Color _statusBorderColor(WatchRequestStatus status) {
    switch (status) {
      case WatchRequestStatus.open:
        return FlixieColors.primary;
      case WatchRequestStatus.accepted:
      case WatchRequestStatus.scheduled:
        return FlixieColors.secondary;
      case WatchRequestStatus.completed:
        return FlixieColors.success;
      case WatchRequestStatus.expired:
        return FlixieColors.medium;
      case WatchRequestStatus.cancelled:
        return FlixieColors.danger;
    }
  }

  Widget _statusPill(WatchRequestStatus status) {
    final color = _statusBorderColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _filterChip(_RequestFilter f, String label) {
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

  void _showMemberStatusSheet(BuildContext context, GroupWatchRequest req) {
    // Build a userId -> username map from all known requesters in the list
    final knownNames = <String, String>{};
    for (final r in _requests) {
      if (r.userId.isNotEmpty && r.requesterUsername != null) {
        knownNames[r.userId] = r.requesterUsername!;
      }
    }

    String name(GroupRequestMemberStatus s) {
      if (s.username != null && s.username!.isNotEmpty) return s.username!;
      if (knownNames.containsKey(s.memberId)) return knownNames[s.memberId]!;
      return s.memberId.substring(0, s.memberId.length.clamp(0, 6));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: FlixieColors.tabBarBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final accepted =
            req.memberStatuses.where((s) => s.status == 'ACCEPTED').toList();
        final declined =
            req.memberStatuses.where((s) => s.status == 'DECLINED').toList();
        final maybe =
            req.memberStatuses.where((s) => s.status == 'MAYBE').toList();
        final pending = req.memberStatuses
            .where((s) =>
                s.status != 'ACCEPTED' &&
                s.status != 'DECLINED' &&
                s.status != 'MAYBE')
            .toList();

        Widget section(String label, List<GroupRequestMemberStatus> members,
            Color color, IconData icon) {
          if (members.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 6),
              ...members.map((s) => Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 6),
                    child: Row(children: [
                      ProfileAvatarView(
                        avatar: s.avatar,
                        fallbackText:
                            name(s).isNotEmpty ? name(s)[0].toUpperCase() : '?',
                        fallbackColor: color,
                        size: 28,
                        profileBadges: s.profileBadges,
                      ),
                      const SizedBox(width: 8),
                      Text('@${name(s)}',
                          style: const TextStyle(
                              color: FlixieColors.light, fontSize: 13)),
                    ]),
                  )),
              const SizedBox(height: 12),
            ],
          );
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FlixieColors.tabBarBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                req.movieTitle ?? 'Watch Request',
                style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Text('Member responses',
                  style: TextStyle(color: FlixieColors.medium, fontSize: 12)),
              const SizedBox(height: 16),
              section('Accepted', accepted, FlixieColors.success,
                  Icons.check_circle_outline),
              section('Declined', declined, FlixieColors.danger,
                  Icons.cancel_outlined),
              section('Maybe', maybe, FlixieColors.warning, Icons.help_outline),
              section('Pending', pending, FlixieColors.medium, Icons.schedule),
            ],
          ),
        );
      },
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

  Widget _poster(String? posterUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 82,
        height: 123,
        child: posterUrl != null
            ? CachedNetworkImage(
                imageUrl: posterUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => const RequestPosterPlaceholder(),
                errorWidget: (_, __, ___) => const RequestPosterPlaceholder(),
              )
            : const RequestPosterPlaceholder(),
      ),
    );
  }

  Widget _messageBubble(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote_rounded,
              size: 16, color: FlixieColors.medium),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.25,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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

  Widget _responsePreview(GroupWatchRequest req) {
    final statuses = req.memberStatuses;
    final acceptedMembers =
        statuses.where((status) => status.status == 'ACCEPTED').toList();
    final waitingMembers = statuses
        .where((status) =>
            status.status != 'ACCEPTED' &&
            status.status != 'DECLINED' &&
            status.status != 'MAYBE')
        .toList();
    final preview = [...acceptedMembers, ...waitingMembers].take(4).toList();
    final pending = statuses
        .where((status) =>
            status.status != 'ACCEPTED' &&
            status.status != 'DECLINED' &&
            status.status != 'MAYBE')
        .length;
    final acceptedLabel = acceptedMembers.isEmpty
        ? null
        : acceptedMembers.length == 1
            ? '@${acceptedMembers.first.username ?? 'member'} accepted'
            : '@${acceptedMembers.first.username ?? 'member'} +${acceptedMembers.length - 1} accepted';
    return InkWell(
      onTap: () => _showMemberStatusSheet(context, req),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: preview.isEmpty ? 0 : 34 + (preview.length - 1) * 22,
              height: 36,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = 0; index < preview.length; index++)
                    Positioned(
                      left: index * 22,
                      top: 1,
                      child: Tooltip(
                        message:
                            '@${preview[index].username ?? 'member'} · ${preview[index].status == 'ACCEPTED' ? 'Accepted' : 'Waiting'}',
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: preview[index].status == 'ACCEPTED'
                                      ? FlixieColors.success
                                      : FlixieColors.surface,
                                  width: 2,
                                ),
                              ),
                              child: ProfileAvatarView(
                                avatar: preview[index].avatar,
                                fallbackText:
                                    (preview[index].username?.isNotEmpty == true
                                            ? preview[index].username![0]
                                            : '?')
                                        .toUpperCase(),
                                fallbackColor:
                                    preview[index].status == 'ACCEPTED'
                                        ? FlixieColors.success
                                        : FlixieColors.primary,
                                size: 28,
                                profileBadges: preview[index].profileBadges,
                              ),
                            ),
                            if (preview[index].status == 'ACCEPTED')
                              Positioned(
                                left: -2,
                                top: -1,
                                child: Container(
                                  width: 13,
                                  height: 13,
                                  decoration: const BoxDecoration(
                                    color: FlixieColors.success,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 10,
                                    color: FlixieColors.surface,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (preview.isNotEmpty) const SizedBox(width: 9),
            Expanded(
              child: Text(
                acceptedLabel == null
                    ? '$pending waiting'
                    : pending > 0
                        ? '$acceptedLabel · $pending waiting'
                        : acceptedLabel,
                style: const TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Text(
              'View responses',
              style: TextStyle(
                color: FlixieColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 17, color: FlixieColors.primary),
          ],
        ),
      ),
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
    final canDelete = isMyRequest;
    final canCancelRequest = isMyRequest && req.isActive;
    final canManage = req.canScheduleFor(currentUserId) ||
        req.canCompleteFor(currentUserId) ||
        _canScheduleAsParticipant(req);
    final isProcessing = _processing[req.id] == true;
    final myStatus = _currentUserStatus(req);
    final posterUrl = req.moviePosterPath != null
        ? 'https://image.tmdb.org/t/p/w185${req.moviePosterPath}'
        : null;
    final proposedDate =
        _fullDateTimeString(req.scheduledFor ?? req.proposedDate);
    final isFocused = widget.initialRequestId?.isNotEmpty == true;

    if (isFocused) {
      return _buildFocusedWatchPlan(
        req,
        isMyRequest: isMyRequest,
        canManage: canManage,
        isProcessing: isProcessing,
        myStatus: myStatus,
        posterUrl: posterUrl,
        proposedDate: proposedDate,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: FlixieColors.tabBarBorder.withValues(alpha: 0.75),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isFocused
            ? () => _showMemberStatusSheet(context, req)
            : () => context.push(
                  '/groups/${widget.groupId}?tab=requests&requestId=${req.id}',
                ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isFocused) ...[
                _groupPlanStage(req, isMyRequest),
                const SizedBox(height: 14),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _poster(posterUrl),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                req.movieTitle ?? 'Watch Plan',
                                style: const TextStyle(
                                  color: FlixieColors.light,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  height: 1.12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textScaler: TextScaler.noScaling,
                              ),
                            ),
                            if ((canDelete || canCancelRequest) &&
                                isFocused) ...[
                              const SizedBox(width: 6),
                              PopupMenuButton<String>(
                                tooltip: 'Watch Plan actions',
                                enabled: !isProcessing,
                                color: FlixieColors.surfaceElevated,
                                onSelected: (value) {
                                  if (value == 'cancel') {
                                    _cancelRequest(req);
                                  } else if (value == 'delete') {
                                    _delete(req);
                                  }
                                },
                                itemBuilder: (_) => [
                                  if (canCancelRequest)
                                    const PopupMenuItem(
                                      value: 'cancel',
                                      child: Text('Cancel Watch Plan'),
                                    ),
                                  if (canDelete)
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete Watch Plan'),
                                    ),
                                ],
                                icon: const Icon(
                                  Icons.more_horiz_rounded,
                                  color: FlixieColors.medium,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ProfileAvatarView(
                              avatar: req.requesterAvatar,
                              fallbackText:
                                  (req.requesterUsername?.isNotEmpty == true
                                          ? req.requesterUsername![0]
                                          : '?')
                                      .toUpperCase(),
                              fallbackColor: FlixieColors.primary,
                              size: 24,
                              profileBadges: req.requesterProfileBadges,
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                isMyRequest
                                    ? 'You invited the group'
                                    : '@${req.requesterUsername ?? 'Member'}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: FlixieColors.light,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            _statusPill(req.status),
                            if (_formatDate(req.createdAt).isNotEmpty)
                              Flexible(
                                child: Text(
                                  ' · ${_formatDate(req.createdAt)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FlixieColors.medium,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (proposedDate.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.event_outlined,
                                  size: 15, color: FlixieColors.medium),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  req.scheduledFor != null
                                      ? 'Scheduled for $proposedDate'
                                      : 'Proposed for $proposedDate',
                                  style: const TextStyle(
                                    color: FlixieColors.medium,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (req.location?.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 15,
                                color: FlixieColors.secondary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  req.location!.trim(),
                                  style: const TextStyle(
                                    color: FlixieColors.light,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              if (req.message != null && req.message!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _messageBubble(req.message!),
              ],
              if (isFocused && req.memberStatuses.isNotEmpty) ...[
                const SizedBox(height: 9),
                _responsePreview(req),
              ],
              if (isFocused && req.mediaId != null) ...[
                const SizedBox(height: 9),
                _GroupRequestProviderSummary(
                  groupId: widget.groupId,
                  movieId: req.mediaId!,
                ),
              ],
              if (isFocused && !isMyRequest && req.canRespond) ...[
                const SizedBox(height: 12),
                if (myStatus == 'ACCEPTED')
                  _myStatusChip('You accepted', FlixieColors.success)
                else if (myStatus == 'DECLINED')
                  _myStatusChip('You declined', FlixieColors.danger)
                else if (myStatus == 'MAYBE')
                  _myStatusChip('You said maybe', FlixieColors.warning)
                else if (isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FlixieColors.primary,
                    ),
                  )
                else
                  _responseActions(req),
              ],
              if (isFocused && canManage && req.isActive) ...[
                const SizedBox(height: 12),
                if (isProcessing)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: FlixieColors.primary,
                    ),
                  )
                else
                  _manageActions(req),
              ],
              if (!isFocused) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_needsCurrentUserResponse(req))
                      const Expanded(
                        child: Text(
                          'Needs your response',
                          style: TextStyle(
                            color: FlixieColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/groups/${widget.groupId}?tab=requests&requestId=${req.id}',
                      ),
                      icon: const Icon(Icons.visibility_outlined, size: 15),
                      label: const Text('View request'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
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
    Widget surface({required Widget child}) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FlixieColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: child,
        );
    // A response row is only created for invited members. The person who
    // created the plan is therefore always a participant and is implicitly
    // accepted, but must be rendered separately here.
    final invitees = req.memberStatuses
        .where((member) => member.memberId != req.userId)
        .toList(growable: false);
    final accepted = invitees
        .where((member) => member.status == 'ACCEPTED')
        .toList(growable: false);
    final declined = invitees
        .where((member) => member.status == 'DECLINED')
        .toList(growable: false);
    final needsReply = _needsCurrentUserResponse(req);

    if (req.status == WatchRequestStatus.completed) {
      return _buildCompletedWatchRecap(
        req,
        posterUrl: posterUrl,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _groupPlanStage(req, isMyRequest),
              const SizedBox(height: 14),
              if (req.selectedCandidateId == null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Planning a watch together',
                      style: TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      ProfileAvatarView(
                        avatar: req.requesterAvatar,
                        fallbackText:
                            (req.requesterUsername ?? '?')[0].toUpperCase(),
                        fallbackColor: FlixieColors.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 8),
                      Text('With ${req.requesterUsername ?? 'the group'}',
                          style: const TextStyle(
                              color: FlixieColors.light, fontSize: 14)),
                    ]),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _poster(posterUrl),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(req.movieTitle ?? 'Watch Plan',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: FlixieColors.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          Row(children: [
                            ProfileAvatarView(
                              avatar: req.requesterAvatar,
                              fallbackText: (req.requesterUsername ?? '?')[0]
                                  .toUpperCase(),
                              fallbackColor: FlixieColors.primary,
                              size: 32,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                  'With ${req.requesterUsername ?? 'the group'}',
                                  style: const TextStyle(
                                      color: FlixieColors.light, fontSize: 14)),
                            ),
                          ]),
                          if (proposedDate.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(proposedDate,
                                style: const TextStyle(
                                    color: FlixieColors.secondary,
                                    fontWeight: FontWeight.w800)),
                          ],
                          if (isMyRequest &&
                              req.status != WatchRequestStatus.completed) ...[
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: isProcessing
                                  ? null
                                  : () => _changeGroupFinalMovie(req),
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Change movie'),
                              style: TextButton.styleFrom(
                                minimumSize: const Size(0, 32),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (needsReply)
          surface(child: _responseActions(req))
        else if (canManage)
          surface(child: _manageActions(req)),
        if (needsReply || canManage) const SizedBox(height: 12),
        if (req.status == WatchRequestStatus.completed) ...[
          surface(
            child: _buildCompletedWatchSummary(req),
          ),
          const SizedBox(height: 12),
        ],
        if (req.candidates.isNotEmpty && req.selectedCandidateId == null) ...[
          surface(child: _buildGroupMovieChoices(req, myStatus)),
          const SizedBox(height: 12),
        ],
        surface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text(
              'Participants',
              style: TextStyle(
                color: FlixieColors.light,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                Column(mainAxisSize: MainAxisSize.min, children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: FlixieColors.success,
                        width: 2.5,
                      ),
                    ),
                    child: ProfileAvatarView(
                      avatar: req.requesterAvatar,
                      fallbackText: (req.requesterUsername?.isNotEmpty == true
                              ? req.requesterUsername![0]
                              : '?')
                          .toUpperCase(),
                      fallbackColor: FlixieColors.primary,
                      size: 42,
                      profileBadges: req.requesterProfileBadges,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    width: 62,
                    child: Text(
                      isMyRequest ? 'You' : req.requesterUsername ?? 'Creator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: FlixieColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ]),
                ...invitees.map((member) {
                  final acceptedMember = member.status == 'ACCEPTED';
                  final declinedMember = member.status == 'DECLINED';
                  return Column(mainAxisSize: MainAxisSize.min, children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: declinedMember
                              ? FlixieColors.danger
                              : acceptedMember
                                  ? FlixieColors.success
                                  : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: ProfileAvatarView(
                        avatar: member.avatar,
                        fallbackText: (member.username ?? '?')[0].toUpperCase(),
                        fallbackColor: FlixieColors.primary,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      width: 62,
                      child: Text(member.username ?? 'Member',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: declinedMember
                                  ? FlixieColors.danger
                                  : acceptedMember
                                      ? FlixieColors.success
                                      : FlixieColors.medium,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]);
                }),
              ],
            ),
            const SizedBox(height: 10),
            Text(
                '${accepted.length + 1} accepted · ${invitees.length - accepted.length - declined.length} waiting${declined.isEmpty ? '' : ' · ${declined.length} declined'}',
                style: const TextStyle(
                    color: FlixieColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 12),
        surface(child: _buildGroupPlanActivity(req)),
      ],
    );
  }

  Widget _buildCompletedWatchRecap(
    GroupWatchRequest req, {
    required String? posterUrl,
  }) {
    final entries = req.memberStatuses
        .where((member) => member.watchedAt != null)
        .toList(growable: false);
    final ratings = entries
        .where((member) => member.rating != null)
        .map((member) => member.rating!)
        .toList(growable: false);
    final average = ratings.isEmpty
        ? null
        : ratings.reduce((total, rating) => total + rating) / ratings.length;
    final recommends = ratings.where((rating) => rating >= 7).length;
    final scheduled = _fullDateTimeString(req.scheduledFor ?? req.proposedDate);
    GroupRequestMemberStatus? myEntry;
    for (final entry in entries) {
      if (entry.memberId == widget.currentUserId) {
        myEntry = entry;
        break;
      }
    }

    Widget card(Widget child, {Color? color}) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color ?? FlixieColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: child,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.check_rounded, color: FlixieColors.success, size: 22),
              SizedBox(width: 8),
              Text('WATCHED TOGETHER',
                  style: TextStyle(
                      color: FlixieColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _poster(posterUrl),
              const SizedBox(width: 18),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req.movieTitle ?? 'Watch Plan',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: FlixieColors.primary,
                          fontSize: 21,
                          height: 1.1,
                          fontWeight: FontWeight.w700)),
                  if (scheduled.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(scheduled,
                        style: const TextStyle(
                            color: FlixieColors.light, fontSize: 15)),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: FlixieColors.primary.withValues(alpha: .16),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      '👥 Group watch · ${req.analyticsParticipantCount} people',
                      style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              )),
            ]),
          ],
        )),
        const SizedBox(height: 16),
        card(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Text("Your group's take",
                      style: TextStyle(
                          color: FlixieColors.light,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                Text(
                    '✓ ${recommends == entries.length ? 'YOU AGREED' : 'MIXED TAKE'}',
                    style: const TextStyle(
                        color: FlixieColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _recapMetric(average?.toStringAsFixed(1) ?? '—',
                        'Average rating', FlixieColors.warning)),
                const SizedBox(width: 12),
                Expanded(
                    child: _recapMetric('${recommends} of ${entries.length}',
                        'Recommend it', FlixieColors.success)),
              ]),
            ]),
            color: FlixieColors.surfaceElevated.withValues(alpha: .72)),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(
              child: Text("Everyone's ratings",
                  style: TextStyle(
                      color: FlixieColors.light,
                      fontSize: 18,
                      fontWeight: FontWeight.w700))),
          Text('${entries.length} watches logged',
              style: const TextStyle(color: FlixieColors.medium, fontSize: 14)),
        ]),
        const SizedBox(height: 14),
        ...entries.map((member) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _recapEntry(member,
                  isYou: member.memberId == widget.currentUserId),
            )),
        _buildGroupPlanActivity(req),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
            onPressed: myEntry?.rating == null || req.mediaId == null
                ? null
                : () {
                    final user = context.read<AuthProvider>().dbUser;
                    if (user == null) return;
                    promptShareCard(
                      context,
                      ShareCardData.rating(
                        mediaType: req.mediaType?.toLowerCase() == 'show'
                            ? ShareCardMediaType.show
                            : ShareCardMediaType.movie,
                        mediaId: req.mediaId!,
                        title: req.movieTitle ?? 'Watch Plan',
                        posterPath: req.moviePosterPath,
                        user: user,
                        rating: myEntry!.rating!,
                        recommended: myEntry.rating! >= 7,
                        note: myEntry.reviewText,
                      ),
                    );
                  },
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share recap'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: OutlinedButton.icon(
            onPressed: () => context.push('/groups/${widget.groupId}?tab=chat'),
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Discuss in chat'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )),
        ]),
        const SizedBox(height: 10),
        Center(
            child: TextButton.icon(
          onPressed: _makeGroupWatchPlan,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Plan another watch'),
        )),
      ],
    );
  }

  Widget _buildGroupPlanActivity(GroupWatchRequest req) {
    final watched =
        req.memberStatuses.where((member) => member.watchedAt != null).length;
    final rated =
        req.memberStatuses.where((member) => member.rating != null).length;
    final participantCount = req.analyticsParticipantCount;
    final accepted = req.acceptedCount + 1;
    final finalised = req.selectedCandidateId != null;
    final scheduled =
        (req.scheduledFor ?? req.proposedDate)?.isNotEmpty == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Plan activity',
          style: TextStyle(
              color: FlixieColors.light,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      _groupActivityRow(
          Icons.send_rounded, 'Invited', 'Group watch plan created', true),
      _groupActivityRow(
          Icons.check_circle_outline_rounded,
          'Accepted',
          '$accepted of $participantCount people accepted',
          accepted >= participantCount),
      _groupActivityRow(
          Icons.bookmark_added_outlined,
          'Choices saved',
          req.candidates.isEmpty
              ? 'No titles added yet'
              : '${req.candidates.length} titles considered',
          req.candidates.isNotEmpty),
      _groupActivityRow(
          Icons.movie_filter_outlined,
          'Movie finalised',
          finalised
              ? '${req.movieTitle ?? 'Movie'} was picked'
              : 'Pick a movie together',
          finalised),
      _groupActivityRow(
          Icons.calendar_month_outlined,
          'Scheduled',
          scheduled
              ? _fullDateTimeString(req.scheduledFor ?? req.proposedDate)
              : 'No time set yet',
          scheduled),
      _groupActivityRow(
          Icons.visibility_outlined,
          'Watched',
          watched > 0
              ? '$watched of $participantCount watches logged'
              : 'Log your watch after the plan',
          watched > 0),
      _groupActivityRow(
          Icons.star_outline_rounded,
          'Rated',
          rated > 0
              ? '$rated of $participantCount ratings saved'
              : 'Ratings will appear here',
          rated > 0,
          last: true),
    ]);
  }

  Widget _groupActivityRow(
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

  Widget _recapMetric(String value, String label, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlixieColors.background.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _recapEntry(GroupRequestMemberStatus member, {required bool isYou}) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlixieColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ProfileAvatarView(
              avatar: member.avatar,
              fallbackText: (member.username ?? '?')[0].toUpperCase(),
              fallbackColor: FlixieColors.primary,
              size: 42,
              profileBadges: member.profileBadges,
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(isYou ? 'You' : member.username ?? 'Member',
                      style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const Text('Logged after the plan',
                      style: TextStyle(color: FlixieColors.medium)),
                ])),
            if (member.rating != null)
              Text('★ ${member.rating}/10',
                  style: const TextStyle(
                      color: FlixieColors.warning,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
          ]),
          if (member.rating != null ||
              (member.reviewText?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 16),
            Row(children: [
              if (member.rating != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    border: Border.all(color: FlixieColors.success),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                      member.rating! >= 7 ? '👍 Recommends' : '👎 Would skip',
                      style: const TextStyle(
                          color: FlixieColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ),
              if (member.reviewText?.isNotEmpty ?? false) ...[
                const SizedBox(width: 12),
                Expanded(
                    child: Text('“${member.reviewText}”',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.light,
                            fontStyle: FontStyle.italic))),
              ],
            ]),
          ],
        ]),
      );

  Widget _buildCompletedWatchSummary(GroupWatchRequest req) {
    final loggedMembers = req.memberStatuses
        .where((member) => member.watchedAt != null)
        .toList(growable: false);
    final ratings = loggedMembers
        .where((member) => member.rating != null)
        .map((member) => member.rating!)
        .toList(growable: false);
    final average = ratings.isEmpty
        ? null
        : ratings.reduce((total, rating) => total + rating) / ratings.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.celebration_rounded, color: FlixieColors.success),
            SizedBox(width: 9),
            Text(
              'Everyone logged their watch',
              style: TextStyle(
                color: FlixieColors.light,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${loggedMembers.length} group members logged this viewing.',
          style: const TextStyle(color: FlixieColors.medium, fontSize: 12),
        ),
        if (average != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: FlixieColors.warning),
              const SizedBox(width: 6),
              Text(
                '${average.toStringAsFixed(1)}/10 group rating',
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...loggedMembers.where((member) => member.rating != null).map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${member.username ?? 'Member'} · ${member.rating}/10',
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }

  Widget _buildGroupMovieChoices(GroupWatchRequest request, String? myStatus) {
    final isCreator = request.userId == widget.currentUserId;
    final canChoose = isCreator || myStatus == 'ACCEPTED';
    final choices = _candidateChoicesFor(request);
    final everyoneCount = request.analyticsParticipantCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCreator ? 'Choose the final movie' : 'What could you watch?',
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isCreator
              ? 'The Watch Plan creator makes the final choice.'
              : canChoose
                  ? 'Choose every title you would watch. The creator makes the final choice.'
                  : 'Accept the invitation first, then choose the movies you would watch.',
          style: const TextStyle(color: FlixieColors.medium, fontSize: 12),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 600;
            final cardWidth = twoColumns
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 8,
              children: request.candidates.map((candidate) {
                final selected = choices.contains(candidate.id);
                final canRemove = request.selectedCandidateId == null &&
                    request.candidates.length > 1 &&
                    (isCreator ||
                        candidate.addedByUserId == widget.currentUserId);
                final poster = candidate.posterPath == null
                    ? null
                    : 'https://image.tmdb.org/t/p/w185${candidate.posterPath}';
                return SizedBox(
                  width: cardWidth,
                  child: InkWell(
                    onTap: !canChoose
                        ? null
                        : isCreator
                            ? () =>
                                _selectGroupFinalMovie(request, candidate.id)
                            : () => setState(() {
                                  if (selected) {
                                    choices.remove(candidate.id);
                                  } else {
                                    choices.add(candidate.id);
                                  }
                                }),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: selected
                            ? FlixieColors.success.withValues(alpha: .1)
                            : FlixieColors.tabBarBackgroundFocused,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? FlixieColors.success
                              : FlixieColors.tabBarBorder,
                          width: selected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 46,
                              height: 68,
                              child: poster == null
                                  ? const RequestPosterPlaceholder()
                                  : CachedNetworkImage(
                                      imageUrl: poster, fit: BoxFit.cover),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(candidate.title ?? 'Movie option',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: FlixieColors.light,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15)),
                                const SizedBox(height: 4),
                                Row(children: [
                                  WatchPlanCandidateAvatar(
                                    avatar: candidate.addedByAvatar,
                                    username: candidate.addedByUsername,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Added by @${candidate.addedByUsername ?? 'a member'}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: FlixieColors.medium,
                                          fontSize: 12),
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 2),
                                Text(
                                  '${candidate.selectedByUserIds.length} of $everyoneCount would watch',
                                  style: const TextStyle(
                                      color: FlixieColors.medium, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (isCreator)
                            const _FinalMovieChip()
                          else if (selected)
                            const Icon(Icons.check_circle,
                                color: FlixieColors.success, size: 28),
                          if (canRemove)
                            IconButton(
                              onPressed: _processing[request.id] == true
                                  ? null
                                  : () => _removeGroupCandidate(
                                      request, candidate.id),
                              tooltip: 'Remove movie option',
                              icon: const Icon(Icons.close_rounded, size: 19),
                              color: FlixieColors.medium,
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            );
          },
        ),
        if (!isCreator && canChoose) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _processing[request.id] == true
                  ? null
                  : () => _saveGroupCandidateChoices(request),
              icon: _processing[request.id] == true
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.checklist_rounded),
              label: Text(_processing[request.id] == true
                  ? 'Saving movies…'
                  : 'Save movies I’d watch'),
            ),
          ),
        ],
        if (request.selectedCandidateId == null &&
            canChoose &&
            request.candidates.length < 5)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _processing[request.id] == true
                  ? null
                  : () => _addGroupCandidate(request),
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Add another option'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
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
                  _filterChip(_RequestFilter.active, 'Active'),
                  _filterChip(_RequestFilter.needsResponse, 'Needs Response'),
                  _filterChip(_RequestFilter.completed, 'Completed'),
                  _filterChip(_RequestFilter.byMe, 'By Me'),
                  _filterChip(_RequestFilter.all, 'All'),
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
                                ? 'No requests match'
                                : _emptyMessage,
                            child: Icon(
                              _filter == _RequestFilter.completed
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

class _GroupScheduleWatchSheet extends StatefulWidget {
  const _GroupScheduleWatchSheet({this.initial, this.initialLocation});

  final DateTime? initial;
  final String? initialLocation;

  @override
  State<_GroupScheduleWatchSheet> createState() =>
      _GroupScheduleWatchSheetState();
}

class _GroupScheduleWatchSheetState extends State<_GroupScheduleWatchSheet> {
  late DateTime _selected;
  final TextEditingController _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initial ?? DateTime.now().add(const Duration(hours: 2));
    _locationController.text = widget.initialLocation?.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: FlixieColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            14,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Schedule watch',
                style: TextStyle(
                  color: FlixieColors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickScheduleChip(
                    label: 'Tonight',
                    onTap: () => setState(() => _selected = _tonight()),
                  ),
                  _QuickScheduleChip(
                    label: 'Tomorrow',
                    onTap: () => setState(() => _selected = _tomorrow()),
                  ),
                  _QuickScheduleChip(
                    label: 'This weekend',
                    onTap: () => setState(() => _selected = _thisWeekend()),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined,
                    color: FlixieColors.primary),
                title: const Text('Date',
                    style: TextStyle(color: FlixieColors.light)),
                subtitle: Text(
                  '${_selected.day} ${_kRequestMonths[_selected.month - 1]} ${_selected.year}',
                  style: const TextStyle(color: FlixieColors.medium),
                ),
                onTap: _pickDate,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule_rounded,
                    color: FlixieColors.primary),
                title: const Text('Time',
                    style: TextStyle(color: FlixieColors.light)),
                subtitle: Text(
                  TimeOfDay.fromDateTime(_selected).format(context),
                  style: const TextStyle(color: FlixieColors.medium),
                ),
                onTap: _pickTime,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _locationController,
                style: const TextStyle(color: FlixieColors.light),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.location_on_outlined),
                  labelText: 'Location (optional)',
                  hintText: 'e.g. My place or local cinema',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(
                    context,
                    (
                      scheduledFor: _selected,
                      location: _locationController.text.trim(),
                    ),
                  ),
                  child: const Text('Confirm schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupScheduleDatePickerSheet(initialDate: _selected),
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
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupScheduleTimePickerSheet(
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

class _GroupScheduleTimePickerSheet extends StatefulWidget {
  const _GroupScheduleTimePickerSheet({required this.initialTime});

  final TimeOfDay initialTime;

  @override
  State<_GroupScheduleTimePickerSheet> createState() =>
      _GroupScheduleTimePickerSheetState();
}

class _GroupScheduleTimePickerSheetState
    extends State<_GroupScheduleTimePickerSheet> {
  late TimeOfDay _selected = widget.initialTime;

  @override
  Widget build(BuildContext context) {
    final initial = DateTime(2020, 1, 1, _selected.hour, _selected.minute);
    return SafeArea(
      child: Material(
        color: FlixieColors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
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
              child: Text('Choose a time',
                  style: TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900)),
            ),
            SizedBox(
              height: 170,
              child: CupertinoTheme(
                data: const CupertinoThemeData(
                  brightness: Brightness.dark,
                  primaryColor: FlixieColors.primary,
                ),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  initialDateTime: initial,
                  use24hFormat: false,
                  onDateTimeChanged: (value) =>
                      _selected = TimeOfDay.fromDateTime(value),
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
          ]),
        ),
      ),
    );
  }
}

class _GroupScheduleDatePickerSheet extends StatefulWidget {
  const _GroupScheduleDatePickerSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_GroupScheduleDatePickerSheet> createState() =>
      _GroupScheduleDatePickerSheetState();
}

class _GroupScheduleDatePickerSheetState
    extends State<_GroupScheduleDatePickerSheet> {
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
            child: Column(children: [
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
                child: Text('Choose a date',
                    style: TextStyle(
                        color: FlixieColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
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
            ]),
          ),
        ),
      ),
    );
  }
}

class _QuickScheduleChip extends StatelessWidget {
  const _QuickScheduleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      labelStyle: const TextStyle(color: FlixieColors.light),
      side: BorderSide(color: FlixieColors.primary.withValues(alpha: 0.3)),
    );
  }
}

class _FinalMovieChip extends StatelessWidget {
  const _FinalMovieChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: FlixieColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, color: Colors.black, size: 15),
          SizedBox(width: 5),
          Text(
            'Make final',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
