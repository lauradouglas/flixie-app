import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/features/watchlist/presentation/controllers/watchlist_actions_controller.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_follow_up_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/write_review_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_watch_requests_overview.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

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
  completing,
  deleting,
}

enum _RequestAudience { friends, groups }

class WatchRequestsScreen extends StatefulWidget {
  const WatchRequestsScreen({super.key, this.initialRequestId});

  final String? initialRequestId;

  @override
  State<WatchRequestsScreen> createState() => _WatchRequestsScreenState();
}

/// Dedicated full-page view for one watch request.
class WatchRequestDetailScreen extends StatelessWidget {
  const WatchRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return WatchRequestsScreen(initialRequestId: requestId);
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

  @override
  void initState() {
    super.initState();
    _groups = context.read<AuthProvider>().cachedGroups ?? [];
    _loadingGroups = _groups.isEmpty;
    _load();
    _loadGroups();
    _searchController.addListener(_applyFilter);
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

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
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
        _applyFilter();
      }
    } catch (e) {
      logger.e('[WatchRequestsScreen] load error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load watch requests.';
          _loading = false;
        });
      }
    }
  }

  void _applyFilter() {
    final q = _searchController.text.toLowerCase();
    final myId = context.read<AuthProvider>().dbUser?.id ?? '';

    setState(() {
      _filtered = _all.where((r) {
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
            request.normalizedScheduleStatus != 'AGREED';
      case _StatusFilter.scheduled:
        return _isActiveRequest(request) &&
            (request.normalizedScheduleStatus == 'AGREED' ||
                request.isScheduled);
      case _StatusFilter.completed:
        return _isCompletedRequest(request);
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
    _applyFilter();
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete watch request?'),
        content: const Text(
          'This permanently removes the request, its schedule and related notifications for everyone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: FlixieColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete permanently'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Watch request deleted')),
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
            content: Text('Could not delete the watch request'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    });
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

  Future<void> _respond(WatchRequest request, String response) async {
    final analytics = context.read<AnalyticsController>();
    final action = switch (response) {
      'ACCEPTED' => _RequestAction.accepting,
      'DECLINED' => _RequestAction.declining,
      _ => _RequestAction.maybe,
    };
    await _withRequestAction(request, action, () async {
      try {
        await RequestService.updateRequest(request.id, response);
        if (response == 'ACCEPTED') {
          await analytics.watchInvitationAccepted(
            recipientType: request.groupId == null ? 'friend' : 'group',
          );
        }
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_responseSuccessMessage(response)),
            backgroundColor: FlixieColors.success,
          ),
        );
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
  }

  Future<void> _showWatchFollowUps(WatchRequest request, String userId) async {
    final movie = request.movie;
    if (movie == null || movie.id == 0 || !mounted) return;
    final choice = await showModalBottomSheet<WatchFollowUpChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchFollowUpSheet(
        movieTitle: movie.title,
        posterPath: movie.posterPath,
      ),
    );
    if (!mounted || choice == null) return;

    if (choice.addWatchEntry) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => RewatchLogSheet(
          onSubmit: ({
            required String watchedAt,
            required double? rating,
            required bool? recommended,
            required String? notes,
          }) async {
            await WatchlistActionsController.instance.logMovieWatch(
              userId,
              LogMovieWatchRequest(
                movieId: movie.id,
                watchedAt: watchedAt,
                rating: rating,
                recommended: recommended,
                notes: notes,
              ),
            );
            await WatchlistActionsController.instance
                .addToWatched(userId, movie.id);
            if (mounted) {
              context.read<AuthProvider>().markActivityChanged();
            }
          },
        ),
      );
    }

    if (mounted && choice.writeReview) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => WriteReviewSheet(
          movieId: movie.id,
          userId: userId,
          onSubmitted: (Review review) {
            final auth = context.read<AuthProvider>();
            auth.invalidateCachedReviews();
            auth.markActivityChanged();
          },
        ),
      );
    }
  }

  Future<void> _suggestSchedule(WatchRequest request,
      {DateTime? initial}) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    final selected = await showModalBottomSheet<
        ({DateTime proposedFor, String? message, String? location})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleProposalSheet(initial: initial),
    );
    if (!mounted || selected == null) return;

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
            content: Text(
                'Suggested ${_formatFriendlyDateTime(selected.proposedFor)}'),
            backgroundColor: FlixieColors.success,
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
    var enteredLocation = request.location ?? '';
    final location = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(request.location?.isNotEmpty == true
            ? 'Change location'
            : 'Add a location'),
        content: TextFormField(
          initialValue: enteredLocation,
          autofocus: true,
          onChanged: (value) => enteredLocation = value,
          onFieldSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) Navigator.pop(dialogContext, trimmed);
          },
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.location_on_outlined),
            hintText: 'e.g. My place or local cinema',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              enteredLocation.trim(),
            ),
            child: const Text('Save location'),
          ),
        ],
      ),
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
          await analytics.watchScheduled(
            recipientType: request.groupId == null ? 'friend' : 'group',
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
              note: request.message,
              location: request.location,
            );
          }
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                decision == 'accepted' ? 'Watch time agreed' : 'Time declined'),
            backgroundColor: FlixieColors.success,
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
    if (userId == null || userId.isEmpty) return;
    final result = await showModalBottomSheet<
        ({bool watched, int? rating, String? reviewText})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WatchConfirmationSheet(request: request),
    );
    if (!mounted || result == null) return;

    await _withRequestAction(request, _RequestAction.completing, () async {
      try {
        final state = await RequestService.confirmWatchRequest(
          watchRequestId: request.id,
          userId: userId,
          watched: result.watched,
          rating: result.rating,
          reviewText: result.reviewText,
        );
        _replaceRequest(state.request);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.watched
                ? 'Thanks, your watch confirmation is saved'
                : 'Saved as not watched'),
            backgroundColor: FlixieColors.success,
          ),
        );
        if (result.watched) {
          await _showWatchFollowUps(request, userId);
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to mark as watched. Please try again.'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    });
  }

  Future<void> _cancelPlan(WatchRequest request) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this watch plan?'),
        content:
            const Text('Everyone taking part will see that it was cancelled.'),
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
        final updated = await RequestService.cancelWatchRequest(
          watchRequestId: request.id,
          userId: userId,
        );
        _replaceRequest(updated);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Watch plan cancelled')),
          );
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
    final directBody = _loading
        ? const Center(child: CircularProgressIndicator())
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
    return FlixiePageScaffold(
      appBar: FlixieTitleAppBar(
        backgroundColor: FlixieColors.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isFocused ? 'Watch plan' : 'Watch requests',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            if (!isFocused && !_loading && _error == null)
              Text(
                  _audience == _RequestAudience.friends
                      ? '${_all.length} total'
                      : 'Across ${_groups.length} groups',
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 12)),
          ],
        ),
        actions: isFocused && !_loading && _filtered.isNotEmpty
            ? [
                IconButton(
                  tooltip: 'Delete watch request',
                  onPressed: _busyActions[_filtered.first.id] ==
                          _RequestAction.deleting
                      ? null
                      : () => _confirmDelete(_filtered.first),
                  icon: _busyActions[_filtered.first.id] ==
                          _RequestAction.deleting
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                ),
              ]
            : isFocused
                ? null
                : [
                    IconButton(
                      tooltip: 'Search requests',
                      onPressed: () =>
                          setState(() => _showSearch = !_showSearch),
                      icon: const Icon(Icons.search_rounded),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: FilledButton.icon(
                        onPressed: () => context.push('/search'),
                        icon: const Icon(Icons.add_rounded, size: 19),
                        label: const Text('New'),
                        style: FilledButton.styleFrom(
                          backgroundColor: FlixieColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                        ),
                      ),
                    ),
                  ],
        bottom: null,
      ),
      body: body,
    );
  }

  Widget _buildFriendFilters() {
    const filters = [
      _StatusFilter.needsResponse,
      _StatusFilter.scheduled,
      _StatusFilter.planning,
      _StatusFilter.completed,
    ];
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
          height: 48,
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
                  label: Text(_filterLabel(filter)),
                  selected: selected,
                  onSelected: (_) {
                    setState(() => _statusFilter =
                        selected ? _StatusFilter.active : filter);
                    _applyFilter();
                  },
                  selectedColor: FlixieColors.primary,
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
          padding: const EdgeInsets.all(16),
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
            !needsAttention.contains(request) && !upcoming.contains(request))
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
      'Needs your attention',
      'Requests and plans waiting for you',
      needsAttention,
    );
    addSection('Upcoming', 'Your agreed watch plans', upcoming);
    addSection('Planning', 'Invites waiting or being arranged', planning);

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
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
        (proposal != null && proposal.proposerId != myUserId) ||
        request.canConfirmWatchedFor(myUserId);
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
      onMovieTap: request.movieId != null
          ? () => context.push('/movies/${request.movieId}')
          : null,
      onAccept: () => _respond(request, 'ACCEPTED'),
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
    );
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
      'ACCEPTED' => 'Request accepted successfully.',
      'DECLINED' => 'Request declined successfully.',
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
                ? 'No requests match'
                : 'No watch requests yet',
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
    this.onMovieTap,
    this.busyAction,
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
  final _RequestAction? busyAction;

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

  String get _statusLabel {
    if (request.normalizedWatchedStatus == 'WATCHED') return 'Watched';
    if (request.normalizedWatchedStatus == 'NOT_WATCHED') {
      return 'Not watched';
    }
    if (request.normalizedWatchedStatus == 'PARTIAL') {
      return 'Confirming';
    }
    if (request.normalizedScheduleStatus == 'AGREED') return 'Scheduled';
    if (request.normalizedScheduleStatus == 'PROPOSED') return 'Proposed';
    if (request.isAccepted) return 'Accepted';
    if (request.isDeclined) return 'Declined';
    if (request.normalizedStatus == 'maybe') return 'Maybe';
    return 'Pending';
  }

  @override
  Widget build(BuildContext context) {
    final other = request.otherUser(myUserId);
    final isSent = request.requesterId == myUserId;
    final movie = request.movie;

    final posterUrl = movie?.posterPath != null
        ? 'https://image.tmdb.org/t/p/w185${movie!.posterPath}'
        : null;

    if (!compact) {
      return _buildFullDetail(context, other, isSent, movie, posterUrl);
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
        child: SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              GestureDetector(
                onTap: onMovieTap,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: SizedBox(
                    width: 126,
                    height: 190,
                    child: posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => const _PosterPlaceholder(),
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
                  padding: const EdgeInsets.all(12),
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
                                      text:
                                          isSent ? ' invited' : ' invited you'),
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
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onMovieTap,
                        child: Text(
                          movie?.title ?? 'Unknown Movie',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      if (compact) ...[
                        if (_effectiveWatchTime != null) ...[
                          const SizedBox(height: 9),
                          _CompactWatchDetail(
                            icon: Icons.schedule_outlined,
                            text: _dateLabel(_effectiveWatchTime),
                          ),
                        ],
                        if (_effectiveLocation?.isNotEmpty == true) ...[
                          const SizedBox(height: 7),
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
                        const Spacer(),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PlanSurface(
            child: Row(
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
                              request.groupName?.trim().isNotEmpty == true
                                  ? 'With ${request.groupName}'
                                  : 'With ${other?.username ?? 'a friend'}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: FlixieColors.light, fontSize: 14),
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
                                color: FlixieColors.medium, fontSize: 11)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_effectiveWatchTime != null) ...[
            _PlanSurface(
              child: Column(
                children: [
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
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _PlanSurface(child: _buildParticipants(other)),
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
                const Text('Log every watch separately and rate this viewing.',
                    style: TextStyle(color: FlixieColors.medium, fontSize: 12)),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: request.canCompleteFor(myUserId)
                        ? onConfirmWatched
                        : null,
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: const Text('Log watch'),
                    style: FilledButton.styleFrom(
                      backgroundColor: FlixieColors.success,
                      foregroundColor: Colors.black,
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
          if (request.isPending || _effectiveWatchTime == null) ...[
            const SizedBox(height: 12),
            _PlanSurface(child: _buildActions()),
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

  Widget _smallUserAvatar(WatchRequestUser? user) => ProfileAvatarView(
        avatar: user?.avatar,
        fallbackText: user?.username.isNotEmpty == true
            ? user!.username[0].toUpperCase()
            : '?',
        fallbackColor: FlixieColors.primary,
        size: 32,
      );

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
      return Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check_rounded, size: 17),
              label: const Text('Accept'),
              style: FilledButton.styleFrom(
                backgroundColor: FlixieColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _effectiveWatchTime == null
                  ? onSuggestSchedule
                  : onSuggestDifferentTime,
              icon: Icon(
                _effectiveWatchTime == null
                    ? Icons.edit_calendar_outlined
                    : Icons.schedule_outlined,
                size: 16,
              ),
              label: Text(
                  _effectiveWatchTime == null ? 'Pick a time' : 'Suggest time'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FlixieColors.primary,
                side: const BorderSide(color: FlixieColors.primary),
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                textStyle: const TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
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
        ),
      ),
    );
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
      // Older scheduled requests can omit their individual response rows even
      // though agreeing the schedule required the recipients to accept.
      return request.normalizedScheduleStatus == 'AGREED' ||
          request.isScheduled;
    }

    final accepted = visible.where(hasAccepted).length;
    final waiting = visible.length - accepted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Participants',
            style: TextStyle(color: FlixieColors.medium, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: visible
              .map((user) => _participantAvatar(
                    user,
                    accepted: hasAccepted(user),
                  ))
              .toList(growable: false),
        ),
        const SizedBox(height: 10),
        Text(
          accepted == visible.length && visible.isNotEmpty
              ? 'All $accepted accepted'
              : accepted > 0
                  ? '$accepted accepted · $waiting waiting'
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
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            ProfileAvatarView(
              avatar: user.avatar,
              fallbackText: user.username.isNotEmpty
                  ? user.username[0].toUpperCase()
                  : '?',
              fallbackColor: FlixieColors.primary,
              size: 46,
            ),
            if (accepted)
              const Positioned(
                top: -3,
                right: -3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: FlixieColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(Icons.check_rounded,
                        color: Colors.black, size: 12),
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
              color: accepted ? FlixieColors.success : FlixieColors.medium,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
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

    if (request.isPending &&
        (request.recipientId == myUserId ||
            request.participantFor(myUserId) != null) &&
        request.requesterId != myUserId) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: _PrimaryActionButton(
              label: 'Accept invitation',
              onPressed: onAccept,
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: onDecline,
            child: const Text('Decline invitation'),
          ),
        ],
      );
    }

    if ((!request.isAccepted && !request.isScheduled) ||
        !request.isWatchRequest) {
      return const SizedBox.shrink();
    }

    if (request.canConfirmWatchedFor(myUserId)) {
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
              text:
                  'Waiting for them to respond to ${_dateLabel(proposal.proposedFor)}',
            ),
            const SizedBox(height: 8),
            _IconTextAction(
              icon: Icons.edit_calendar_outlined,
              label: 'Suggest a different time',
              onPressed: onSuggestDifferentTime,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InlineStateMessage(
            icon: Icons.event_outlined,
            text: 'Proposed for ${_dateLabel(proposal.proposedFor)}',
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: _PrimaryActionButton(
              label: 'Accept time',
              onPressed: () => onRespondToProposal(proposal, 'accepted'),
            ),
          ),
          const SizedBox(height: 8),
          _IconTextAction(
            icon: Icons.edit_calendar_outlined,
            label: 'Suggest another instead',
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
                label: 'Change time',
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
          SizedBox(
            width: double.infinity,
            child: _PrimaryActionButton(
              label: 'Suggest a time',
              onPressed: onSuggestSchedule,
            ),
          ),
          const SizedBox(height: 6),
          _IconTextAction(
            icon: Icons.location_on_outlined,
            label: request.location?.trim().isNotEmpty == true
                ? 'Change location'
                : 'Add a location',
            onPressed: onEditLocation,
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'the suggested time';
    final local = value.toLocal();
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
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

class _ScheduleProposalSheet extends StatefulWidget {
  const _ScheduleProposalSheet({this.initial});

  final DateTime? initial;

  @override
  State<_ScheduleProposalSheet> createState() => _ScheduleProposalSheetState();
}

class _ScheduleProposalSheetState extends State<_ScheduleProposalSheet> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial?.toLocal() ??
        DateTime.now().add(const Duration(hours: 2));
  }

  @override
  Widget build(BuildContext context) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Suggest a time',
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
              leading:
                  const Icon(Icons.event_outlined, color: FlixieColors.primary),
              title: const Text('Date',
                  style: TextStyle(color: FlixieColors.light)),
              subtitle: Text(
                '${_selected.day} ${_kMonths[_selected.month - 1]} ${_selected.year}',
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
            const SizedBox(height: 8),
            TextField(
              controller: _locationController,
              textInputAction: TextInputAction.next,
              style: const TextStyle(color: FlixieColors.light),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_outlined),
                labelText: 'Location (optional)',
                hintText: 'e.g. My place or local cinema',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              maxLines: 2,
              style: const TextStyle(color: FlixieColors.light),
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Add a quick note',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  (
                    proposedFor: _selected,
                    message: _messageController.text.trim(),
                    location: _locationController.text.trim(),
                  ),
                ),
                child: const Text('Send suggestion'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selected,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selected),
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
