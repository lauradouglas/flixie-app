import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../services/request_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'notification/activity_card.dart';
import 'notification/request_card.dart';

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
      await NotificationService.updateNotification(id, closed: true);
      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == id);
        });
      }
    } catch (e) {
      logger.e('[NotificationScreen] close error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to close notification.'),
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

  /// Tracks in-progress accept/decline calls by notification id.
  final Set<String> _processingIds = {};

  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load(showSpinner: true);
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
      if (mounted) {
        setState(() => _notifications = fresh);
        auth.setUnreadNotificationCount(fresh.where((n) => !n.isRead).length);
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
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
          _error = null;
        });
        context.read<AuthProvider>().setUnreadNotificationCount(
            notifications.where((n) => !n.isRead).length);
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

  Future<void> _respond(FlixieNotification notification, String action) async {
    final id = notification.id;
    if (id == null) return;
    setState(() => _processingIds.add(id));
    try {
      // For watch requests, also update the underlying request record.
      if (notification.type == FlixieNotification.movieWatchRequest ||
          notification.type == FlixieNotification.showWatchRequest) {
        final requestId = notification.linkedRequestId;
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
        final requestId = notification.linkedRequestId;
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
    if (notification.isRequest) {
      return NotificationRequestCard(
        notification: notification,
        isProcessing: _processingIds.contains(notification.id),
        formatDate: _formatDate,
        onAccept: () =>
            _respond(notification, FlixieNotification.actionAccepted),
        onDecline: () =>
            _respond(notification, FlixieNotification.actionDeclined),
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
