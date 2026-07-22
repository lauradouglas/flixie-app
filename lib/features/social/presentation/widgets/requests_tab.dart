import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/request_poster_placeholder.dart';

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
    this.conversationId,
    this.initialRequests = const [],
    required this.currentUserId,
    this.isAdmin = false,
    this.onCountChanged,
    this.initialRequestId,
  });

  final String groupId;
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
  final Map<String, String> _myResponses = {};
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
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
        return "You haven't created any requests yet.";
      case _RequestFilter.all:
        return 'No watch requests yet.';
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
    if (_requests.isEmpty) _load();
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
    if (mounted) setState(() => _loading = true);
    try {
      final List<GroupWatchRequest> requests;
      final conversationId = widget.conversationId;
      if (conversationId != null) {
        requests = await GroupService.getConversationWatchRequests(
          conversationId,
          filter: widget.initialRequestId?.isNotEmpty == true
              ? WatchRequestFilter.all
              : WatchRequestFilter.active,
          userId: widget.currentUserId,
        );
      } else {
        requests = await GroupService.getGroupWatchRequests(widget.groupId);
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

    setState(() => _processing[req.id] = true);
    try {
      final decision = WatchResponseDecision.fromString(status);
      try {
        await GroupService.respondToWatchRequest(
            convId, req.id, userId, decision);
      } catch (e) {
        logger.d('New respond endpoint failed, using legacy: $e');
        await GroupService.updateWatchRequestForMember(
            req.id, userId, '', status);
      }
      if (mounted) setState(() => _myResponses[req.id] = status);
      await _load();
    } catch (e) {
      logger.e('Respond to watch request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update request')),
        );
      }
    } finally {
      if (mounted) setState(() => _processing.remove(req.id));
    }
  }

  Future<void> _markWatched(GroupWatchRequest req) async {
    final userId = widget.currentUserId;
    final convId = widget.conversationId ?? req.groupId;
    setState(() => _processing[req.id] = true);
    try {
      await GroupService.completeWatchRequest(convId, req.id, userId);
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

  Future<void> _scheduleRequest(GroupWatchRequest req,
      {String? initialIso}) async {
    final selected =
        await showModalBottomSheet<({DateTime scheduledFor, String? location})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _GroupScheduleWatchSheet(
        initial: DateTime.tryParse(initialIso ?? '')?.toLocal(),
      ),
    );
    if (!mounted || selected == null) return;

    final userId = widget.currentUserId;
    final convId = widget.conversationId ?? req.groupId;
    setState(() => _processing[req.id] = true);
    try {
      await GroupService.scheduleWatchRequest(
        convId,
        req.id,
        userId: userId,
        scheduledFor: selected.scheduledFor.toUtc().toIso8601String(),
        location: selected.location,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Watch scheduled for ${_fullDateTime(selected.scheduledFor)}'),
            backgroundColor: FlixieColors.success,
            action: SnackBarAction(
              label: 'Add to calendar',
              textColor: FlixieColors.background,
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

  Future<void> _unscheduleRequest(GroupWatchRequest req) async {
    final userId = widget.currentUserId;
    final convId = widget.conversationId ?? req.groupId;
    setState(() => _processing[req.id] = true);
    try {
      await GroupService.scheduleWatchRequest(
        convId,
        req.id,
        userId: userId,
        scheduledFor: null,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Watch time removed'),
            backgroundColor: FlixieColors.success,
          ),
        );
      }
    } catch (e) {
      logger.e('Unschedule watch request error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unschedule watch')),
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
      await GroupService.deleteWatchRequest(widget.groupId, req.id);
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

  Widget _buildMemberStatuses(List<GroupRequestMemberStatus> statuses) {
    if (statuses.isEmpty) return const SizedBox.shrink();
    final acceptedCount = statuses.where((s) => s.status == 'ACCEPTED').length;
    final declinedCount = statuses.where((s) => s.status == 'DECLINED').length;
    final maybeCount = statuses.where((s) => s.status == 'MAYBE').length;
    final pendingCount = statuses
        .where((s) =>
            s.status != 'ACCEPTED' &&
            s.status != 'DECLINED' &&
            s.status != 'MAYBE')
        .length;

    Widget responsePill(String label, IconData icon, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
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

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        if (acceptedCount > 0)
          responsePill('$acceptedCount accepted', Icons.check_circle_outline,
              FlixieColors.success),
        if (maybeCount > 0)
          responsePill(
              '$maybeCount maybe', Icons.help_outline, FlixieColors.warning),
        if (declinedCount > 0)
          responsePill('$declinedCount declined', Icons.cancel_outlined,
              FlixieColors.danger),
        if (pendingCount > 0)
          responsePill(
              '$pendingCount pending', Icons.schedule, FlixieColors.medium),
      ],
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
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: color.withValues(alpha: 0.15),
                        child: Text(
                          name(s).isNotEmpty ? name(s)[0].toUpperCase() : '?',
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
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
      child: Row(
        children: [
          Expanded(
            child: _summaryTile('Active', _activeCount, FlixieColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _summaryTile(
                'Needs reply', _needsResponseCount, FlixieColors.warning),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                _summaryTile('Watched', _completedCount, FlixieColors.success),
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
        width: 74,
        height: 110,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: FlixieColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chat_bubble_outline,
              size: 14, color: FlixieColors.primary),
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
    required VoidCallback onPressed,
    bool filled = false,
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

    final child = Row(
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
                onPressed: () => _respond(req, 'DECLINED'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _responseButton(
                label: 'Maybe',
                icon: Icons.help_outline,
                color: FlixieColors.warning,
                onPressed: () => _respond(req, 'MAYBE'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _responseButton(
                label: 'Accept',
                icon: Icons.check_circle_outline,
                color: FlixieColors.primary,
                onPressed: () => _respond(req, 'ACCEPTED'),
                filled: true,
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
    final showComplete = req.canCompleteFor(userId);
    final showCancel = req.canCancelFor(userId);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (showScheduling)
          SizedBox(
            width: req.status == WatchRequestStatus.scheduled ? 150 : 170,
            child: _responseButton(
              label: req.status == WatchRequestStatus.scheduled
                  ? 'Reschedule'
                  : 'Schedule',
              icon: Icons.edit_calendar_outlined,
              color: FlixieColors.primary,
              onPressed: () => _scheduleRequest(
                req,
                initialIso: req.scheduledFor ?? req.proposedDate,
              ),
              filled: req.status != WatchRequestStatus.scheduled,
            ),
          ),
        if (req.status == WatchRequestStatus.scheduled && showScheduling)
          SizedBox(
            width: 170,
            child: _responseButton(
              label: 'Add to calendar',
              icon: Icons.event_available_outlined,
              color: FlixieColors.secondary,
              onPressed: () {
                final scheduledFor = DateTime.tryParse(req.scheduledFor ?? '');
                if (scheduledFor == null) return;
                WatchCalendarService.addScheduledWatch(
                  title: req.movieTitle ?? 'Watch together',
                  scheduledFor: scheduledFor,
                  note: req.message,
                  location: req.location,
                );
              },
            ),
          ),
        if (req.status == WatchRequestStatus.scheduled && showScheduling)
          SizedBox(
            width: 150,
            child: _responseButton(
              label: 'Unschedule',
              icon: Icons.event_busy_outlined,
              color: FlixieColors.warning,
              onPressed: () => _unscheduleRequest(req),
            ),
          ),
        if (showComplete)
          SizedBox(
            width: 170,
            child: _responseButton(
              label: 'Mark Watched',
              icon: Icons.check_circle_outline,
              color: FlixieColors.success,
              onPressed: () => _markWatched(req),
            ),
          ),
        if (showCancel)
          SizedBox(
            width: 130,
            child: _responseButton(
              label: 'Cancel',
              icon: Icons.cancel_outlined,
              color: FlixieColors.danger,
              onPressed: () => _cancelRequest(req),
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

  Widget _buildRequestCard(GroupWatchRequest req) {
    final currentUserId = widget.currentUserId;
    final isMyRequest = req.userId == currentUserId;
    final canDelete = isMyRequest || widget.isAdmin;
    final canManage = isMyRequest ||
        widget.isAdmin ||
        req.canScheduleFor(currentUserId) ||
        req.canCompleteFor(currentUserId) ||
        req.canCancelFor(currentUserId) ||
        _canScheduleAsParticipant(req);
    final isProcessing = _processing[req.id] == true;
    final myStatus = _currentUserStatus(req);
    final posterUrl = req.moviePosterPath != null
        ? 'https://image.tmdb.org/t/p/w185${req.moviePosterPath}'
        : null;
    final proposedDate =
        _fullDateTimeString(req.scheduledFor ?? req.proposedDate);
    final isFocused = widget.initialRequestId?.isNotEmpty == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _statusBorderColor(req.status).withValues(alpha: 0.35),
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
                                req.movieTitle ?? 'Watch Request',
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
                            if (canDelete && isFocused) ...[
                              const SizedBox(width: 6),
                              IconButton(
                                tooltip: 'Delete request',
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(
                                  minWidth: 32,
                                  minHeight: 32,
                                ),
                                onPressed:
                                    isProcessing ? null : () => _delete(req),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: FlixieColors.danger,
                                  size: 19,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _statusPill(req.status),
                            Text(
                              'By @${req.requesterUsername ?? 'Unknown'}',
                              style: const TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_formatDate(req.createdAt).isNotEmpty)
                              Text(
                                _formatDate(req.createdAt),
                                style: const TextStyle(
                                  color: FlixieColors.medium,
                                  fontSize: 12,
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
              if (isFocused &&
                  req.message != null &&
                  req.message!.isNotEmpty) ...[
                const SizedBox(height: 12),
                _messageBubble(req.message!),
              ],
              if (isFocused && req.memberStatuses.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildMemberStatuses(req.memberStatuses),
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
                                ? 'No requests match.'
                                : _emptyMessage,
                            style: const TextStyle(color: FlixieColors.medium),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
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

class _GroupScheduleWatchSheet extends StatefulWidget {
  const _GroupScheduleWatchSheet({this.initial});

  final DateTime? initial;

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
              leading:
                  const Icon(Icons.event_outlined, color: FlixieColors.primary),
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
    );
  }

  @override
  void dispose() {
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
