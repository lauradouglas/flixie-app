import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/watch_request.dart';
import '../providers/auth_provider.dart';
import '../services/request_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

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

enum _StatusFilter { all, pending, accepted, declined }

class WatchRequestsScreen extends StatefulWidget {
  const WatchRequestsScreen({super.key});

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
      // Sort by most recent first
      requests.sort(
          (a, b) => _parseDate(b.createdAt).compareTo(_parseDate(a.createdAt)));
      if (mounted) {
        setState(() {
          _all = requests;
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
        if (_statusFilter == _StatusFilter.pending && !r.isPending)
          return false;
        if (_statusFilter == _StatusFilter.accepted && !r.isAccepted)
          return false;
        if (_statusFilter == _StatusFilter.declined && !r.isDeclined)
          return false;

        if (q.isEmpty) return true;
        // Search by movie title or other user's username
        final movieMatch = (r.movie?.title.toLowerCase().contains(q)) ?? false;
        final userMatch =
            (r.otherUser(myId)?.username.toLowerCase().contains(q)) ?? false;
        return movieMatch || userMatch;
      }).toList();
    });
  }

  DateTime _parseDate(String? iso) =>
      DateTime.tryParse(iso ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);

  String _formatDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return '';
    return '${dt.day} ${_kMonths[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlixieColors.background,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        elevation: 0,
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
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _WatchRequestCard(
                          request: _filtered[i],
                          myUserId:
                              context.read<AuthProvider>().dbUser?.id ?? '',
                          formattedDate: _formatDate(_filtered[i].createdAt),
                          onMovieTap: _filtered[i].movieId != null
                              ? () => context
                                  .push('/movies/${_filtered[i].movieId}')
                              : null,
                        ),
                      ),
                    ),
    );
  }

  String _filterLabel(_StatusFilter f) {
    switch (f) {
      case _StatusFilter.all:
        return 'All';
      case _StatusFilter.pending:
        return 'Pending';
      case _StatusFilter.accepted:
        return 'Accepted';
      case _StatusFilter.declined:
        return 'Declined';
    }
  }

  Color _statusFilterColor(_StatusFilter f) {
    switch (f) {
      case _StatusFilter.pending:
        return FlixieColors.warning;
      case _StatusFilter.accepted:
        return FlixieColors.success;
      case _StatusFilter.declined:
        return FlixieColors.danger;
      case _StatusFilter.all:
        return FlixieColors.primary;
    }
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
    this.onMovieTap,
  });

  final WatchRequest request;
  final String myUserId;
  final String formattedDate;
  final VoidCallback? onMovieTap;

  Color get _statusColor {
    if (request.isAccepted) return FlixieColors.success;
    if (request.isDeclined) return FlixieColors.danger;
    return FlixieColors.warning;
  }

  IconData get _statusIcon {
    if (request.isAccepted) return Icons.check_circle_outline;
    if (request.isDeclined) return Icons.cancel_outlined;
    return Icons.hourglass_top_outlined;
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
                    if (request.isPending && request.recipientId == myUserId)
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _showMessageDialog(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: FlixieColors.primary,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Accept',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _showMessageDialog(context, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: FlixieColors.light,
                                side: BorderSide(
                                    color: FlixieColors.medium
                                        .withValues(alpha: 0.5)),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text('Decline',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    // Status badge + date
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              Icon(_statusIcon, size: 12, color: _statusColor),
                              const SizedBox(width: 4),
                              Text(
                                request.status,
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

  void _showMessageDialog(BuildContext context, bool accept) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(accept
            ? 'Add a message for acceptance'
            : 'Add a message for decline'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Optional message...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (result != null) {
      _handleAction(context, accept, result);
    }
  }

  void _handleAction(BuildContext context, bool accept, String message) async {
    final status = accept ? 'ACCEPTED' : 'DECLINED';
    try {
      await RequestService.updateRequest(request.id, status, message: message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'Request accepted successfully.'
              : 'Request declined successfully.'),
          backgroundColor: FlixieColors.success,
        ),
      );
      // Optionally refresh the parent list
      if (context.mounted) {
        final state =
            context.findAncestorStateOfType<_WatchRequestsScreenState>();
        state?._load();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(accept
              ? 'Failed to accept. Please try again.'
              : 'Failed to decline. Please try again.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
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
