import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/activity_list_item.dart';
import '../../models/group.dart';
import '../../models/group_watch_request.dart';
import '../../providers/auth_provider.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import '../profile/activity_tile.dart';
import 'group_hero_banner.dart';
import 'pending_request_preview_tile.dart';

class GroupActivityTab extends StatefulWidget {
  const GroupActivityTab({
    required this.group,
    required this.memberCount,
    required this.groupId,
    this.conversationId,
    required this.initialRequests,
    required this.initialActivity,
    required this.onRefresh,
  });

  final Group? group;
  final int memberCount;
  final String groupId;
  final String? conversationId;
  final List<GroupWatchRequest> initialRequests;
  final List<ActivityListItem> initialActivity;
  final Future<void> Function() onRefresh;

  @override
  State<GroupActivityTab> createState() => GroupActivityTabState();
}

class GroupActivityTabState extends State<GroupActivityTab> {
  late List<ActivityListItem> _activity;
  late List<GroupWatchRequest> _requests;
  bool _loading = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _activity = widget.initialActivity;
    _requests = widget.initialRequests;
  }

  @override
  void didUpdateWidget(GroupActivityTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialActivity != oldWidget.initialActivity ||
        widget.initialRequests != oldWidget.initialRequests) {
      setState(() {
        _activity = widget.initialActivity;
        _requests = widget.initialRequests;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await widget.onRefresh();
    if (mounted) {
      setState(() {
        _activity = widget.initialActivity;
        _requests = widget.initialRequests;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ActivityListItem> get _filteredActivity {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return _activity;
    return _activity.where((item) {
      return (item.mediaTitle ?? '').toLowerCase().contains(q) ||
          item.username.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final group = widget.group;
    final textTheme = Theme.of(context).textTheme;
    final currentUserId = context.read<AuthProvider>().dbUser?.id;

    // Pending requests only (no response from current user yet)
    final pendingRequests = _requests.where((r) {
      final myStatus = r.memberStatuses
          .where((s) => s.memberId == currentUserId)
          .map((s) => s.status)
          .firstOrNull;
      return myStatus == null || myStatus == 'PENDING';
    }).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      color: FlixieColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Hero banner ------------------------------------------------
            if (group != null)
              GroupHeroBanner(group: group, memberCount: widget.memberCount),

            const SizedBox(height: 16),

            // ---- Search bar -------------------------------------------------
            if (_activity.isNotEmpty || _searchQuery.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _searchController,
                  style:
                      const TextStyle(color: FlixieColors.light, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search activity & requests…',
                    hintStyle: const TextStyle(
                        color: FlixieColors.medium, fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        color: FlixieColors.medium, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear,
                                color: FlixieColors.medium, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: FlixieColors.tabBarBackgroundFocused,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: FlixieColors.tabBarBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: FlixieColors.tabBarBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: FlixieColors.primary),
                    ),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 22,
                    decoration: BoxDecoration(
                      color: FlixieColors.tertiary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'RECENT ACTIVITY',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: FlixieColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: FlixieColors.success.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        color: FlixieColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_filteredActivity.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  _searchQuery.isNotEmpty
                      ? 'No activity matches your search.'
                      : 'No recent activity.',
                  style:
                      textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
                ),
              )
            else
              ...(_filteredActivity.take(_searchQuery.isNotEmpty ? 50 : 5).map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ActivityTile(item: item),
                    ),
                  )),

            const SizedBox(height: 20),

            const SizedBox(height: 20),

            // ---- Pending Requests -------------------------------------------
            if (pendingRequests.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 22,
                      decoration: BoxDecoration(
                        color: FlixieColors.warning,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'PENDING REQUESTS (${pendingRequests.length})',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ...pendingRequests.take(3).map(
                    (req) => PendingRequestPreviewTile(
                      request: req,
                      canRespond: req.userId != currentUserId,
                      onRespond: (status) async {
                        final userId = context.read<AuthProvider>().dbUser?.id;
                        if (userId == null) return;
                        // Use conversation-scoped endpoint when possible;
                        // fall back to legacy PUT endpoint.
                        final convId = widget.conversationId ?? req.groupId;
                        try {
                          try {
                            final decision =
                                WatchResponseDecision.fromString(status);
                            await GroupService.respondToWatchRequest(
                                convId, req.id, userId, decision);
                          } catch (e) {
                            logger.d(
                                'New respond endpoint failed, using legacy: $e');
                            await GroupService.updateWatchRequestForMember(
                                req.id, userId, '', status);
                          }
                          await _refresh();
                        } catch (e) {
                          logger.e('Respond to request error: $e');
                        }
                      },
                    ),
                  ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
