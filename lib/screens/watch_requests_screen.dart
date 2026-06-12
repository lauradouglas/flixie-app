import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/watch_request.dart';
import '../providers/auth_provider.dart';
import '../services/request_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import '../widgets/flixie_page.dart';

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
  all,
  open,
  accepted,
  scheduled,
  completed,
  cancelled,
  expired,
}

enum _RequestAction { accepting, maybe, declining, scheduling, completing }

class WatchRequestsScreen extends StatefulWidget {
  const WatchRequestsScreen({super.key, this.initialRequestId});

  final String? initialRequestId;

  @override
  State<WatchRequestsScreen> createState() => _WatchRequestsScreenState();
}

class _WatchRequestsScreenState extends State<WatchRequestsScreen> {
  final _searchController = TextEditingController();

  List<WatchRequest> _all = [];
  List<WatchRequest> _filtered = [];
  bool _loading = true;
  String? _error;
  _StatusFilter _statusFilter = _StatusFilter.all;
  final Map<String, _RequestAction> _busyActions = {};

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_applyFilter);
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
        // Status filter
        if (_statusFilter != _StatusFilter.all && !_matchesStatusFilter(r)) {
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
    switch (_statusFilter) {
      case _StatusFilter.all:
        return true;
      case _StatusFilter.open:
        return request.isPending;
      case _StatusFilter.accepted:
        return request.isAccepted;
      case _StatusFilter.scheduled:
        return request.normalizedScheduleStatus == 'AGREED' ||
            request.normalizedScheduleStatus == 'PROPOSED';
      case _StatusFilter.completed:
        return request.normalizedWatchedStatus == 'WATCHED';
      case _StatusFilter.cancelled:
        return request.normalizedScheduleStatus == 'CANCELLED' ||
            request.isCancelled ||
            request.isDeclined;
      case _StatusFilter.expired:
        return request.isExpired;
    }
  }

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
    final action = switch (response) {
      'ACCEPTED' => _RequestAction.accepting,
      'DECLINED' => _RequestAction.declining,
      _ => _RequestAction.maybe,
    };
    await _withRequestAction(request, action, () async {
      try {
        await RequestService.updateRequest(request.id, response);
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

  Future<void> _suggestSchedule(WatchRequest request,
      {DateTime? initial}) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null || userId.isEmpty) return;
    final selected =
        await showModalBottomSheet<({DateTime proposedFor, String? message})>(
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

  Future<void> _respondToProposal(
    WatchRequest request,
    WatchScheduleProposal proposal,
    String decision,
  ) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
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

  @override
  Widget build(BuildContext context) {
    return FlixiePageScaffold(
      appBar: FlixieTitleAppBar(
        backgroundColor: FlixieColors.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Watch Requests',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            if (!_loading && _error == null)
              Text('${_all.length} total',
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 12)),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search by movie or username...',
                    hintStyle: const TextStyle(color: FlixieColors.medium),
                    prefixIcon:
                        const Icon(Icons.search, color: FlixieColors.medium),
                    filled: true,
                    fillColor: FlixieColors.tabBarBackgroundFocused,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              // Status filter chips
              Container(
                width: double.infinity,
                color: FlixieColors.tabBarBackgroundFocused,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _StatusFilter.values.map((f) {
                      final selected = _statusFilter == f;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(_filterLabel(f)),
                          selected: selected,
                          onSelected: (_) {
                            setState(() => _statusFilter = f);
                            _applyFilter();
                          },
                          selectedColor: _statusFilterColor(f),
                          backgroundColor: FlixieColors.tabBarBorder,
                          labelStyle: TextStyle(
                            color: selected ? Colors.black : FlixieColors.light,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.normal,
                            fontSize: 13,
                          ),
                          side: BorderSide.none,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _filtered.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: FlixieColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _WatchRequestCard(
                          request: _filtered[i],
                          myUserId:
                              context.read<AuthProvider>().dbUser?.id ?? '',
                          formattedDate: _formatDate(_filtered[i].createdAt),
                          scheduledLabel: _formatFriendlyDateTime(
                              _filtered[i].scheduledFor),
                          busyAction: _busyActions[_filtered[i].id],
                          onMovieTap: _filtered[i].movieId != null
                              ? () => context
                                  .push('/movies/${_filtered[i].movieId}')
                              : null,
                          onAccept: () => _respond(_filtered[i], 'ACCEPTED'),
                          onMaybe: () => _respond(_filtered[i], 'MAYBE'),
                          onDecline: () => _respond(_filtered[i], 'DECLINED'),
                          onOpen: () => _refreshRequestState(
                            _filtered[i],
                            context.read<AuthProvider>().dbUser?.id ?? '',
                          ),
                          onSuggestSchedule: () =>
                              _suggestSchedule(_filtered[i]),
                          onSuggestDifferentTime: () => _suggestSchedule(
                            _filtered[i],
                            initial: _filtered[i].scheduledFor,
                          ),
                          onRespondToProposal: (proposal, decision) =>
                              _respondToProposal(
                            _filtered[i],
                            proposal,
                            decision,
                          ),
                          onConfirmWatched: () => _confirmWatched(_filtered[i]),
                        ),
                      ),
                    ),
    );
  }

  String _filterLabel(_StatusFilter f) {
    switch (f) {
      case _StatusFilter.all:
        return 'All';
      case _StatusFilter.open:
        return 'Open';
      case _StatusFilter.accepted:
        return 'Accepted';
      case _StatusFilter.scheduled:
        return 'Scheduled';
      case _StatusFilter.completed:
        return 'Completed';
      case _StatusFilter.cancelled:
        return 'Cancelled';
      case _StatusFilter.expired:
        return 'Expired';
    }
  }

  Color _statusFilterColor(_StatusFilter f) {
    switch (f) {
      case _StatusFilter.open:
        return FlixieColors.warning;
      case _StatusFilter.accepted:
        return FlixieColors.success;
      case _StatusFilter.scheduled:
        return FlixieColors.secondary;
      case _StatusFilter.completed:
        return FlixieColors.primary;
      case _StatusFilter.cancelled:
      case _StatusFilter.expired:
        return FlixieColors.danger;
      case _StatusFilter.all:
        return FlixieColors.primary;
    }
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
                    _statusFilter != _StatusFilter.all
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

// ---------------------------------------------------------------------------
// Card
// ---------------------------------------------------------------------------

class _WatchRequestCard extends StatelessWidget {
  const _WatchRequestCard({
    required this.request,
    required this.myUserId,
    required this.formattedDate,
    required this.scheduledLabel,
    required this.onAccept,
    required this.onMaybe,
    required this.onDecline,
    required this.onOpen,
    required this.onSuggestSchedule,
    required this.onSuggestDifferentTime,
    required this.onRespondToProposal,
    required this.onConfirmWatched,
    this.onMovieTap,
    this.busyAction,
  });

  final WatchRequest request;
  final String myUserId;
  final String formattedDate;
  final String scheduledLabel;
  final VoidCallback? onMovieTap;
  final VoidCallback onAccept;
  final VoidCallback onMaybe;
  final VoidCallback onDecline;
  final VoidCallback onOpen;
  final VoidCallback onSuggestSchedule;
  final VoidCallback onSuggestDifferentTime;
  final void Function(WatchScheduleProposal proposal, String decision)
      onRespondToProposal;
  final VoidCallback onConfirmWatched;
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
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poster
              GestureDetector(
                onTap: onMovieTap,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.horizontal(left: Radius.circular(12)),
                  child: SizedBox(
                    width: 80,
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
                      // Movie title
                      GestureDetector(
                        onTap: onMovieTap,
                        child: Text(
                          movie?.title ?? 'Unknown Movie',
                          style: TextStyle(
                            color: onMovieTap != null
                                ? FlixieColors.primary
                                : FlixieColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            decorationColor: FlixieColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Direction label + username
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                              color: FlixieColors.medium, fontSize: 13),
                          children: [
                            TextSpan(text: isSent ? 'To: ' : 'From: '),
                            TextSpan(
                              text: other?.username ?? '—',
                              style: const TextStyle(
                                  color: FlixieColors.light,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      // Message
                      if (request.message != null &&
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
                      const Spacer(),
                      // Accept/Decline buttons for pending requests (if recipient)
                      _LifecycleSummary(
                        request: request,
                        scheduledLabel: _scheduleSummaryLabel(),
                        myUserId: myUserId,
                      ),
                      if (_proposalNoteText != null) ...[
                        const SizedBox(height: 7),
                        _ProposalNote(text: _proposalNoteText!),
                      ],
                      const SizedBox(height: 10),
                      _buildActions(),
                      const SizedBox(height: 8),
                      // Status badge + date
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
      return Row(
        children: [
          Expanded(
            child: _PrimaryActionButton(label: 'Accept', onPressed: onAccept),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SecondaryActionButton(label: 'Maybe', onPressed: onMaybe),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                _SecondaryActionButton(label: 'Decline', onPressed: onDecline),
          ),
        ],
      );
    }

    if (!request.isAccepted || !request.isWatchRequest) {
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
                  label: 'Confirm',
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
          Row(
            children: [
              Expanded(
                child: _PrimaryActionButton(
                  label: 'Accept time',
                  onPressed: () => onRespondToProposal(proposal, 'accepted'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SecondaryActionButton(
                  label: 'Decline',
                  onPressed: () => onRespondToProposal(proposal, 'declined'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _IconTextAction(
            icon: Icons.edit_calendar_outlined,
            label: 'Suggest another time',
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
      return Align(
        alignment: Alignment.centerLeft,
        child: _CompactActionButton(
          icon: Icons.edit_calendar_outlined,
          label: 'Suggest different',
          onPressed: onSuggestDifferentTime,
        ),
      );
    }

    if (request.normalizedScheduleStatus == 'NONE' ||
        request.normalizedScheduleStatus == 'DECLINED' ||
        request.normalizedScheduleStatus == 'CANCELLED') {
      return _PrimaryActionButton(
        label: 'Suggest a time',
        onPressed: onSuggestSchedule,
      );
    }

    return const SizedBox.shrink();
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'the suggested time';
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'pm' : 'am';
    return '${local.day} ${_kMonths[local.month - 1]}, $hour:$minute$suffix';
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
      return pending > 0
          ? '$pending pending response${pending == 1 ? '' : 's'}'
          : 'Awaiting responses';
    }
    if (request.isAccepted) {
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
            : 'They suggested a time';
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
      return 'Accepted. Ready to suggest a time.';
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

class _CompactActionButton extends StatelessWidget {
  const _CompactActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 15),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: FlixieColors.medium,
        side: BorderSide(color: FlixieColors.medium.withValues(alpha: 0.35)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  final TextEditingController _reviewController = TextEditingController();
  int? _rating;
  bool _watched = true;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

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
                  'Rating',
                  style: TextStyle(
                      color: FlixieColors.light, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: List.generate(10, (index) {
                    final value = index + 1;
                    final selected = _rating == value;
                    return ChoiceChip(
                      label: Text('$value'),
                      selected: selected,
                      onSelected: (_) => setState(() => _rating = value),
                      selectedColor: FlixieColors.primary,
                      backgroundColor: FlixieColors.tabBarBackgroundFocused,
                      labelStyle: TextStyle(
                        color: selected ? Colors.black : FlixieColors.light,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _reviewController,
                  maxLines: 4,
                  style: const TextStyle(color: FlixieColors.light),
                  decoration: const InputDecoration(
                    labelText: 'Review notes (optional)',
                    hintText: 'How was the watch?',
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
                      rating: _rating,
                      reviewText: _reviewController.text.trim(),
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
