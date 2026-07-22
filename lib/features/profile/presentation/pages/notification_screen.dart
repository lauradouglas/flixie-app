import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/data/notification_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_activity_card.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_request_card.dart';

/// How often the screen silently re-fetches notifications in the background.
const Duration _kPollInterval = Duration(seconds: 30);

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

/// Notification filter tabs.
enum _NotificationFilter {
  all,
  requests,
  activity,
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  Future<void> _closeNotification(FlixieNotification notification) async {
    final id = notification.id;
    if (id == null) return;
    try {
      await NotificationService.deleteNotification(id);
      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == id);
        });
        context.read<AuthProvider>().updateCachedNotifications(_notifications);
      }
    } catch (e) {
      logger.e('[NotificationScreen] close error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to dismiss notification.'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    }
  }

  List<FlixieNotification> _notifications = [];
  bool _isLoading = true;
  String? _error;
  _NotificationFilter _filter = _NotificationFilter.all;
  final FriendActionsController _friendActions =
      FriendActionsController.instance;

  /// Tracks in-progress accept/decline calls by notification id.
  final Set<String> _processingIds = {};

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final cached = auth.cachedNotifications;
    final userId = auth.dbUser?.id;
    if (cached != null && userId != null) {
      _notifications = _visibleNotificationsForUser(cached, userId);
      _isLoading = false;
    }
    _load(showSpinner: cached == null);
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }

  // ---- Polling --------------------------------------------------------------

  void _startPolling() {
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _poll());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Silent background refresh — does not show a loading spinner and does not
  /// clear existing notifications while fetching, so the UI stays stable.
  Future<void> _poll() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;
    try {
      final fresh = await NotificationService.getNotifications(userId);
      final visible = _visibleNotificationsForUser(fresh, userId);
      if (mounted) {
        setState(() => _notifications = visible);
        auth.updateCachedNotifications(visible);
      }
    } catch (e) {
      // Polling errors are intentionally silent; the user is not disrupted.
      logger.w('[NotificationScreen] poll error: $e');
    }
  }

  // ---- Initial / manual load -----------------------------------------------

  Future<void> _load({bool showSpinner = false}) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    if (showSpinner) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final notifications = await NotificationService.getNotifications(userId);
      final visible = _visibleNotificationsForUser(notifications, userId);
      if (mounted) {
        setState(() {
          _notifications = visible;
          _isLoading = false;
          _error = null;
        });
        context.read<AuthProvider>().updateCachedNotifications(visible);
      }
    } catch (e) {
      logger.e('[NotificationScreen] load error: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to load notifications. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  List<FlixieNotification> _visibleNotificationsForUser(
    List<FlixieNotification> notifications,
    String userId,
  ) {
    final addressedToUser = notifications.where((n) => n.userId == userId);
    final byScheduleKey = <String, FlixieNotification>{};
    final visible = <FlixieNotification>[];

    for (final notification in addressedToUser) {
      final key = _scheduleNotificationKey(notification);
      if (key == null) {
        visible.add(notification);
        continue;
      }

      final existing = byScheduleKey[key];
      if (existing == null ||
          _notificationSortDate(notification).isAfter(
            _notificationSortDate(existing),
          )) {
        byScheduleKey[key] = notification;
      }
    }

    visible.addAll(byScheduleKey.values);
    visible.sort(
      (a, b) => _notificationSortDate(b).compareTo(_notificationSortDate(a)),
    );
    return visible;
  }

  String? _scheduleNotificationKey(FlixieNotification notification) {
    if (notification.type != FlixieNotification.movieWatchRequest &&
        notification.type != FlixieNotification.showWatchRequest) {
      return null;
    }
    final requestId = notification.linkedRequestId;
    if (requestId == null || requestId.isEmpty) return null;
    final scheduleStatus =
        notification.watchRequestScheduleStatus?.toUpperCase();
    if (scheduleStatus == null ||
        (scheduleStatus != 'PROPOSED' &&
            scheduleStatus != 'AGREED' &&
            scheduleStatus != 'DECLINED')) {
      return null;
    }
    final proposal = notification.latestWatchScheduleProposal;
    final proposalId = proposal?['id']?.toString();
    final proposedFor = proposal?['proposedFor']?.toString();
    return [
      notification.type,
      requestId,
      scheduleStatus,
      if (proposalId != null && proposalId.isNotEmpty)
        proposalId
      else if (proposedFor != null && proposedFor.isNotEmpty)
        proposedFor,
    ].join(':');
  }

  DateTime _notificationSortDate(FlixieNotification notification) {
    return DateTime.tryParse(notification.receivedAt) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _respond(FlixieNotification notification, String action) async {
    final id = notification.id;
    if (id == null) return;
    setState(() => _processingIds.add(id));
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.dbUser?.id;
      final requestId = notification.linkedRequestId;

      if (notification.type == FlixieNotification.friendRequest &&
          requestId != null) {
        if (action == FlixieNotification.actionAccepted) {
          await _friendActions.acceptRequest(requestId);
        } else {
          await _friendActions.declineRequest(requestId);
        }
      }

      // For watch requests, also update the underlying request record.
      if (notification.type == FlixieNotification.movieWatchRequest ||
          notification.type == FlixieNotification.showWatchRequest) {
        if (requestId != null) {
          final status = action == FlixieNotification.actionAccepted
              ? 'ACCEPTED'
              : 'DECLINED';
          await RequestService.updateRequest(requestId, status);
        }
      }

      // For group invites and group requests, also update the underlying request record.
      if (notification.type == FlixieNotification.groupInvite ||
          notification.type == FlixieNotification.groupRequest) {
        if (requestId != null) {
          final status = action == FlixieNotification.actionAccepted
              ? 'ACCEPTED'
              : 'DECLINED';
          await RequestService.updateRequest(requestId, status);
        }
      }

      await NotificationService.updateNotification(
        id,
        action: action,
        read: true,
      );

      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == id);
        });
        auth.setUnreadNotificationCount(
            _notifications.where((n) => !n.isRead).length);
        if (userId != null &&
            notification.type == FlixieNotification.friendRequest) {
          final friends = await _friendActions.getFriends(userId);
          if (mounted) auth.updateCachedFriends(friends);
        } else {
          await auth.refreshUserData();
        }
        if (!mounted) return;
        // Show success toast
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == FlixieNotification.actionAccepted
                  ? 'Request accepted successfully.'
                  : 'Request declined successfully.',
            ),
            backgroundColor: FlixieColors.success,
          ),
        );
      }
    } catch (e) {
      logger.e('[NotificationScreen] respond error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == FlixieNotification.actionAccepted
                  ? 'Failed to accept. Please try again.'
                  : 'Failed to decline. Please try again.',
            ),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(id));
    }
  }

  Future<void> _respondToScheduleProposal(
    FlixieNotification notification,
    String decision,
  ) async {
    final requestId = notification.linkedRequestId;
    final proposalId =
        notification.latestWatchScheduleProposal?['id']?.toString();
    final userId = context.read<AuthProvider>().dbUser?.id;
    final notificationId = notification.id;
    if (requestId == null ||
        proposalId == null ||
        proposalId.isEmpty ||
        userId == null) {
      return;
    }
    if (notificationId != null) {
      setState(() => _processingIds.add(notificationId));
    }
    try {
      final state = await RequestService.respondToWatchScheduleProposal(
        watchRequestId: requestId,
        proposalId: proposalId,
        userId: userId,
        decision: decision,
      );
      await _load();
      if (!mounted) return;
      final scheduledFor = state.request.scheduledFor;
      if (decision == 'accepted' && scheduledFor != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Watch time agreed'),
            backgroundColor: FlixieColors.success,
            action: SnackBarAction(
              label: 'Add to calendar',
              textColor: FlixieColors.background,
              onPressed: () => WatchCalendarService.addScheduledWatch(
                title: state.request.movie?.title ??
                    notification.watchMediaTitle ??
                    'Watch together',
                scheduledFor: scheduledFor,
                note: state.request.message,
                location:
                    state.request.location ?? notification.watchRequestLocation,
              ),
            ),
          ),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'accepted' ? 'Watch time agreed' : 'Time declined',
          ),
          backgroundColor: FlixieColors.success,
        ),
      );
    } catch (e) {
      logger.e('[NotificationScreen] schedule proposal response error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update proposed time. Please try again.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    } finally {
      if (mounted && notificationId != null) {
        setState(() => _processingIds.remove(notificationId));
      }
    }
  }

  Future<void> _suggestSchedule(FlixieNotification notification) async {
    final requestId = notification.linkedRequestId;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (requestId == null || userId == null) return;

    final selected =
        await showModalBottomSheet<({DateTime proposedFor, String? message})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotificationScheduleProposalSheet(
        initial: notification.watchRequestScheduledFor,
      ),
    );
    if (!mounted || selected == null) return;

    final notificationId = notification.id;
    if (notificationId != null) {
      setState(() => _processingIds.add(notificationId));
    }
    try {
      await RequestService.proposeWatchSchedule(
        watchRequestId: requestId,
        userId: userId,
        proposedFor: selected.proposedFor,
        message: selected.message,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Suggested a new time'),
          backgroundColor: FlixieColors.success,
        ),
      );
    } catch (e) {
      logger.e('[NotificationScreen] suggest schedule error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to suggest a time. Please try again.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    } finally {
      if (mounted && notificationId != null) {
        setState(() => _processingIds.remove(notificationId));
      }
    }
  }

  Future<void> _markAllAsRead(List<FlixieNotification> unread) async {
    if (unread.isEmpty) return;
    try {
      await Future.wait(
        unread.where((n) => n.id != null).map(
              (n) => NotificationService.updateNotification(
                n.id!,
                read: true,
              ),
            ),
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to mark all as read.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
  }

  // ---- Filter helpers -------------------------------------------------------

  bool _isRequestType(FlixieNotification n) => n.isRequest;

  bool _isActivityType(FlixieNotification n) =>
      !n.isRequest && n.type != 'ALERT';

  List<FlixieNotification> get _filtered {
    switch (_filter) {
      case _NotificationFilter.all:
        return _notifications;
      case _NotificationFilter.requests:
        return _notifications.where(_isRequestType).toList();
      case _NotificationFilter.activity:
        return _notifications.where(_isActivityType).toList();
    }
  }

  // ---- Sections for "All" view ----------------------------------------------

  /// Pending requests that still need a response.
  List<FlixieNotification> get _pendingRequests =>
      _notifications.where((n) => _isRequestType(n) && n.isPending).toList();

  /// Unread non-request notifications.
  List<FlixieNotification> get _newNotifications =>
      _notifications.where((n) => !_isRequestType(n) && !n.isRead).toList();

  /// Read non-request notifications + resolved requests.
  List<FlixieNotification> get _earlierNotifications => _notifications
      .where((n) =>
          (!_isRequestType(n) && n.isRead) ||
          (_isRequestType(n) && !n.isPending))
      .toList();

  List<FlixieNotification> get _unreadNotifications =>
      _notifications.where((n) => !n.isRead).toList();

  int _countForFilter(_NotificationFilter filter) {
    return switch (filter) {
      _NotificationFilter.all => _notifications.length,
      _NotificationFilter.requests =>
        _notifications.where(_isRequestType).length,
      _NotificationFilter.activity =>
        _notifications.where(_isActivityType).length,
    };
  }

  // ---- Helpers --------------------------------------------------------------

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${dt.day} ${_kMonths[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  String _dateSectionLabel(FlixieNotification notification) {
    final iso = notification.receivedAt;
    if (iso.isEmpty) return 'Earlier';
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final local = dt.toLocal();
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(local.year, local.month, local.day);
      final diff = today.difference(day).inDays;
      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      return 'Earlier';
    } catch (_) {
      return 'Earlier';
    }
  }

  // ---- Build ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_unreadNotifications.isNotEmpty)
            IconButton(
              tooltip: 'Mark all as read',
              onPressed: () => _markAllAsRead(_unreadNotifications),
              icon: const Icon(Icons.done_all_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        color: FlixieColors.primary,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : Column(
                    children: [
                      _buildFilterChips(),
                      Expanded(child: _buildContent()),
                    ],
                  ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                color: FlixieColors.danger, size: 48),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: FlixieColors.light)),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: () => _load(showSpinner: true),
                child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      (_NotificationFilter.all, 'All'),
      (_NotificationFilter.requests, 'Requests'),
      (_NotificationFilter.activity, 'Activity'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: filters.map((entry) {
            final (f, label) = entry;
            final selected = _filter == f;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? FlixieColors.primary.withValues(alpha: 0.25)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$label ${_countForFilter(f)}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color:
                          selected ? FlixieColors.primary : FlixieColors.light,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_filter == _NotificationFilter.all) {
      return _buildAllSections();
    }
    final items = _filtered;
    if (items.isEmpty) {
      return _buildEmptyState();
    }
    final unreadItems = items.where((n) => !n.isRead).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        if (unreadItems.isNotEmpty) ...[
          _buildInlineUnreadAction(unreadItems),
          const SizedBox(height: 12),
        ],
        ..._buildGroupedByDate(items),
      ],
    );
  }

  Widget _buildAllSections() {
    final pending = _pendingRequests;
    final newItems = _newNotifications;
    final earlier = _earlierNotifications;

    if (pending.isEmpty && newItems.isEmpty && earlier.isEmpty) {
      return _buildEmptyState();
    }
    final unreadItems =
        [...pending, ...newItems, ...earlier].where((n) => !n.isRead).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        if (pending.isNotEmpty) ...[
          _buildInboxSummary(pending.length),
          const SizedBox(height: 12),
          _buildSectionHeader('NEEDS RESPONSE'),
          const SizedBox(height: 10),
          ...pending.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildCard(n),
              )),
          const SizedBox(height: 16),
        ],
        if (unreadItems.isNotEmpty) ...[
          _buildInlineUnreadAction(unreadItems),
          const SizedBox(height: 14),
        ],
        if (newItems.isNotEmpty) ...[
          _buildSectionHeader('NEW ACTIVITY'),
          const SizedBox(height: 10),
          ...newItems.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildCard(n),
              )),
          const SizedBox(height: 16),
        ],
        ..._buildGroupedByDate(earlier),
      ],
    );
  }

  Widget _buildInboxSummary(int pendingCount) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlixieColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.inbox_rounded, color: FlixieColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$pendingCount ${pendingCount == 1 ? 'request needs' : 'requests need'} your response',
              style: const TextStyle(
                color: FlixieColors.light,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineUnreadAction(List<FlixieNotification> unread) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: () => _markAllAsRead(unread),
        icon: const Icon(Icons.done_all_rounded, size: 17),
        label: Text('Mark ${unread.length} read'),
        style: TextButton.styleFrom(
          foregroundColor: FlixieColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        ),
      ),
    );
  }

  List<Widget> _buildGroupedByDate(List<FlixieNotification> items) {
    final grouped = <String, List<FlixieNotification>>{};
    for (final item in items) {
      grouped.putIfAbsent(_dateSectionLabel(item), () => []).add(item);
    }
    final widgets = <Widget>[];
    for (final label in ['Today', 'Yesterday', 'Earlier']) {
      final sectionItems = grouped[label];
      if (sectionItems == null || sectionItems.isEmpty) continue;
      widgets.add(_buildSectionHeader(label.toUpperCase()));
      widgets.add(const SizedBox(height: 10));
      widgets.addAll(sectionItems.map((n) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _buildCard(n),
          )));
      widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }

  Widget _buildEmptyState() {
    // Wrap in a scrollable so RefreshIndicator (pull-to-refresh) works even
    // when there are no notifications to show.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none,
                      size: 64,
                      color: FlixieColors.medium.withValues(alpha: 0.6)),
                  const SizedBox(height: 16),
                  Text(
                    _emptyTitle,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _emptyBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String get _emptyTitle {
    return switch (_filter) {
      _NotificationFilter.requests => 'No pending requests',
      _NotificationFilter.activity => 'No activity yet',
      _NotificationFilter.all => 'No notifications',
    };
  }

  String get _emptyBody {
    return switch (_filter) {
      _NotificationFilter.requests =>
        'Watch requests and invites will appear here when someone needs a response.',
      _NotificationFilter.activity =>
        'Friend, group, and watch updates will show up here.',
      _NotificationFilter.all => 'You are all caught up.',
    };
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: FlixieColors.medium,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildCard(FlixieNotification notification) {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    if (notification.isRequest) {
      return NotificationRequestCard(
        notification: notification,
        isProcessing: _processingIds.contains(notification.id),
        formatDate: _formatDate,
        currentUserId: currentUserId,
        onAccept: () =>
            _respond(notification, FlixieNotification.actionAccepted),
        onDecline: () =>
            _respond(notification, FlixieNotification.actionDeclined),
        onAcceptSchedule: () =>
            _respondToScheduleProposal(notification, 'accepted'),
        onDeclineSchedule: () =>
            _respondToScheduleProposal(notification, 'declined'),
        onSuggestSchedule: () => _suggestSchedule(notification),
        onClose: () => _closeNotification(notification),
      );
    }
    return NotificationActivityCard(
      notification: notification,
      formatDate: _formatDate,
      onClose: () => _closeNotification(notification),
    );
  }
}

class _NotificationScheduleProposalSheet extends StatefulWidget {
  const _NotificationScheduleProposalSheet({this.initial});

  final DateTime? initial;

  @override
  State<_NotificationScheduleProposalSheet> createState() =>
      _NotificationScheduleProposalSheetState();
}

class _NotificationScheduleProposalSheetState
    extends State<_NotificationScheduleProposalSheet> {
  final TextEditingController _messageController = TextEditingController();
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial?.toLocal() ??
        DateTime.now().add(const Duration(hours: 2));
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
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
