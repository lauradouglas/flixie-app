import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/group_watch_request.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import 'request_poster_placeholder.dart';

enum _RequestFilter { all, needsResponse, active, completed, byMe }

class GroupRequestsTab extends StatefulWidget {
  const GroupRequestsTab({super.key, 
    required this.groupId,
    this.conversationId,
    this.initialRequests = const [],
    required this.currentUserId,
    this.isAdmin = false,
    this.onCountChanged,
  });

  final String groupId;
  final String? conversationId;
  final List<GroupWatchRequest> initialRequests;
  final String currentUserId;
  final bool isAdmin;
  final void Function(int count)? onCountChanged;

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
        return 'No active watch requests';
      case _RequestFilter.needsResponse:
        return 'No requests need your response';
      case _RequestFilter.completed:
        return 'No completed watches yet';
      case _RequestFilter.byMe:
        return "You haven't created any requests yet";
      case _RequestFilter.all:
        return 'No watch requests yet.';
    }
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
          userId: widget.currentUserId,
        );
      } else {
        requests = await GroupService.getGroupWatchRequests(widget.groupId);
      }
      if (mounted) {
        setState(() {
          _requests = requests;
          _loading = false;
        });
        final currentUserId = widget.currentUserId;
        final needsResponseCount = requests.where((r) {
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

    // Apply filter chip
    switch (_filter) {
      case _RequestFilter.active:
        // Active = open + scheduled; hide expired/cancelled by default
        list = list.where((r) => r.isActive).toList();
      case _RequestFilter.needsResponse:
        list = list.where((r) {
          if (!r.canRespond) return false;
          if (r.userId == currentUserId) return false;
          // Check local optimistic response first
          final localResponse = _myResponses[r.id];
          if (localResponse != null) return false;
          // Check server-side current user response
          if (r.currentUserResponse != null) return false;
          // Check memberStatuses
          return !r.memberStatuses.any((s) =>
              s.memberId == currentUserId &&
              (s.status == 'ACCEPTED' ||
                  s.status == 'DECLINED' ||
                  s.status == 'MAYBE'));
        }).toList();
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

    return list;
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
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = f),
        selectedColor: FlixieColors.primary,
        backgroundColor: FlixieColors.tabBarBackgroundFocused,
        labelStyle: TextStyle(
          color: selected ? Colors.black : FlixieColors.light,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          fontSize: 12,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        side: BorderSide.none,
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

    return Row(
      children: [
        if (acceptedCount > 0) ...[
          const Icon(Icons.check_circle_outline,
              size: 13, color: FlixieColors.success),
          const SizedBox(width: 3),
          Text('$acceptedCount',
              style:
                  const TextStyle(color: FlixieColors.success, fontSize: 12)),
          const SizedBox(width: 10),
        ],
        if (declinedCount > 0) ...[
          const Icon(Icons.cancel_outlined,
              size: 13, color: FlixieColors.danger),
          const SizedBox(width: 3),
          Text('$declinedCount',
              style: const TextStyle(color: FlixieColors.danger, fontSize: 12)),
          const SizedBox(width: 10),
        ],
        if (maybeCount > 0) ...[
          Semantics(
            label: 'Maybe responses',
            child: const Icon(Icons.help_outline,
                size: 13, color: FlixieColors.warning),
          ),
          const SizedBox(width: 3),
          Text('$maybeCount',
              style:
                  const TextStyle(color: FlixieColors.warning, fontSize: 12)),
          const SizedBox(width: 10),
        ],
        if (pendingCount > 0) ...[
          const Icon(Icons.schedule, size: 13, color: FlixieColors.medium),
          const SizedBox(width: 3),
          Text('$pendingCount',
              style: const TextStyle(color: FlixieColors.medium, fontSize: 12)),
        ],
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
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
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
          SizedBox(
            height: 40,
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
                    itemBuilder: (_, i) {
                      final req = displayed[i];
                      final isProcessing = _processing[req.id] == true;
                      final currentUserId = widget.currentUserId;
                      final isMyRequest = req.userId == currentUserId;
                      final canDelete = isMyRequest || widget.isAdmin;
                      final canManage = isMyRequest || widget.isAdmin;

                      // Determine current user's existing status
                      final myStatus = _myResponses[req.id] ??
                          req.currentUserResponse?.apiValue ??
                          req.memberStatuses
                              .where((s) => s.memberId == currentUserId)
                              .map((s) => s.status)
                              .where((s) =>
                                  s == 'ACCEPTED' ||
                                  s == 'DECLINED' ||
                                  s == 'MAYBE')
                              .firstOrNull;

                      final posterUrl = req.moviePosterPath != null
                          ? 'https://image.tmdb.org/t/p/w185${req.moviePosterPath}'
                          : null;

                      return Container(
                        clipBehavior: Clip.hardEdge,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: FlixieColors.tabBarBackgroundFocused,
                          borderRadius: BorderRadius.circular(14),
                          border: Border(
                            left: BorderSide(
                                color: _statusBorderColor(req.status),
                                width: 3),
                          ),
                        ),
                        child: IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Details (tappable for member status sheet)
                              Expanded(
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () =>
                                      _showMemberStatusSheet(context, req),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 12, 12, 10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Title + date
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                req.movieTitle ??
                                                    'Watch Request',
                                                style: const TextStyle(
                                                  color: FlixieColors.light,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textScaler:
                                                    TextScaler.noScaling,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              _formatDate(req.createdAt),
                                              style: const TextStyle(
                                                  color: FlixieColors.medium,
                                                  fontSize: 11),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        // Status pill + creator
                                        Row(
                                          children: [
                                            _statusPill(req.status),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                'By @${req.requesterUsername ?? 'Unknown'}',
                                                style: const TextStyle(
                                                    color: FlixieColors.medium,
                                                    fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (req.message != null &&
                                            req.message!.isNotEmpty) ...[
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: FlixieColors.primary
                                                  .withValues(alpha: 0.08),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                  color: FlixieColors.primary
                                                      .withValues(alpha: 0.25)),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                    Icons.chat_bubble_outline,
                                                    size: 11,
                                                    color:
                                                        FlixieColors.primary),
                                                const SizedBox(width: 5),
                                                Expanded(
                                                  child: Text(
                                                    req.message!,
                                                    style: const TextStyle(
                                                      color: FlixieColors.light,
                                                      fontSize: 12,
                                                      fontStyle:
                                                          FontStyle.italic,
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        if (req.memberStatuses.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          _buildMemberStatuses(
                                              req.memberStatuses),
                                        ],
                                        const SizedBox(height: 10),
                                        // Member response row (for non-requesters on active requests)
                                        if (!isMyRequest && req.canRespond) ...[
                                          Builder(builder: (_) {
                                            if (myStatus == 'ACCEPTED') {
                                              return _myStatusChip(
                                                  'You accepted',
                                                  FlixieColors.success);
                                            }
                                            if (myStatus == 'DECLINED') {
                                              return _myStatusChip(
                                                  'You declined',
                                                  FlixieColors.danger);
                                            }
                                            if (myStatus == 'MAYBE') {
                                              return _myStatusChip(
                                                  'You said maybe',
                                                  FlixieColors.warning);
                                            }
                                            // No response yet — show buttons
                                            if (isProcessing) {
                                              return const Align(
                                                alignment: Alignment.centerLeft,
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: FlixieColors.primary,
                                                  ),
                                                ),
                                              );
                                            }
                                            return Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Your response',
                                                  style: TextStyle(
                                                    color: FlixieColors.medium,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: OutlinedButton(
                                                        onPressed: () =>
                                                            _respond(req,
                                                                'DECLINED'),
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              FlixieColors
                                                                  .danger,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 7),
                                                          side: BorderSide(
                                                              color: FlixieColors
                                                                  .danger
                                                                  .withValues(
                                                                      alpha:
                                                                          0.45)),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                          minimumSize:
                                                              Size.zero,
                                                          textStyle:
                                                              const TextStyle(
                                                                  fontSize: 12),
                                                        ),
                                                        child: const Text(
                                                            'Decline'),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: OutlinedButton(
                                                        onPressed: () =>
                                                            _respond(
                                                                req, 'MAYBE'),
                                                        style: OutlinedButton
                                                            .styleFrom(
                                                          foregroundColor:
                                                              FlixieColors
                                                                  .warning,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 7),
                                                          side: BorderSide(
                                                              color: FlixieColors
                                                                  .warning
                                                                  .withValues(
                                                                      alpha:
                                                                          0.45)),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                          minimumSize:
                                                              Size.zero,
                                                          textStyle:
                                                              const TextStyle(
                                                                  fontSize: 12),
                                                        ),
                                                        child:
                                                            const Text('Maybe'),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: ElevatedButton(
                                                        onPressed: () =>
                                                            _respond(req,
                                                                'ACCEPTED'),
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              FlixieColors
                                                                  .primary,
                                                          foregroundColor:
                                                              Colors.black,
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                                  vertical: 7),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                          minimumSize:
                                                              Size.zero,
                                                          textStyle:
                                                              const TextStyle(
                                                                  fontSize: 12),
                                                        ),
                                                        child: const Text(
                                                            'Accept'),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            );
                                          }),
                                        ],
                                        // Creator / admin actions (active requests only)
                                        if (canManage && req.isActive) ...[
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              if (isProcessing)
                                                const SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: FlixieColors.primary,
                                                  ),
                                                )
                                              else ...[
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _markWatched(req),
                                                    icon: const Icon(
                                                        Icons
                                                            .check_circle_outline,
                                                        size: 14),
                                                    label: const Text(
                                                        'Mark Watched'),
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          FlixieColors.success,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 7),
                                                      side: BorderSide(
                                                          color: FlixieColors
                                                              .success
                                                              .withValues(
                                                                  alpha: 0.45)),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                      minimumSize: Size.zero,
                                                      textStyle:
                                                          const TextStyle(
                                                              fontSize: 12),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        _cancelRequest(req),
                                                    icon: const Icon(
                                                        Icons.cancel_outlined,
                                                        size: 14),
                                                    label: const Text('Cancel'),
                                                    style: OutlinedButton
                                                        .styleFrom(
                                                      foregroundColor:
                                                          FlixieColors.danger,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 7),
                                                      side: BorderSide(
                                                          color: FlixieColors
                                                              .danger
                                                              .withValues(
                                                                  alpha: 0.45)),
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8)),
                                                      minimumSize: Size.zero,
                                                      textStyle:
                                                          const TextStyle(
                                                              fontSize: 12),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Poster flush to right with fade
                              SizedBox(
                                width: 90,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    posterUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: posterUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (_, __) =>
                                                const RequestPosterPlaceholder(),
                                            errorWidget: (_, __, ___) =>
                                                const RequestPosterPlaceholder(),
                                          )
                                        : const RequestPosterPlaceholder(),
                                    Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.centerLeft,
                                          end: Alignment.centerRight,
                                          colors: [
                                            FlixieColors
                                                .tabBarBackgroundFocused,
                                            Colors.transparent,
                                          ],
                                          stops: [0.0, 0.25],
                                        ),
                                      ),
                                    ),
                                    if (canDelete)
                                      Positioned(
                                        top: 6,
                                        right: 6,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: isProcessing
                                              ? null
                                              : () => _delete(req),
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withValues(alpha: 0.55),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Icon(
                                                Icons.delete_outline,
                                                color: FlixieColors.danger,
                                                size: 16),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
