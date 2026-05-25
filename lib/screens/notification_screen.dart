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
                    label,
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
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _buildCard(items[i]),
          ),
        ),
        _buildMarkAllAsReadButton(items.where((n) => !n.isRead).toList()),
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

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            children: [
              if (pending.isNotEmpty) ...[
                _buildSectionHeader('REQUESTS'),
                const SizedBox(height: 10),
                ...pending.map((n) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildCard(n),
                    )),
                const SizedBox(height: 16),
              ],
              if (newItems.isNotEmpty) ...[
                _buildSectionHeader('NEW'),
                const SizedBox(height: 10),
                ...newItems.map((n) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildCard(n),
                    )),
                const SizedBox(height: 16),
              ],
              if (earlier.isNotEmpty) ...[
                _buildSectionHeader('EARLIER'),
                const SizedBox(height: 10),
                ...earlier.map((n) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildCard(n),
                    )),
              ],
            ],
          ),
        ),
        _buildMarkAllAsReadButton(
          [...pending, ...newItems, ...earlier]
              .where((n) => !n.isRead)
              .toList(),
        ),
      ],
    );
  }

  Widget _buildMarkAllAsReadButton(List<FlixieNotification> unread) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: unread.isEmpty
                ? null
                : () async {
                    try {
                      await Future.wait(
                        unread
                            .where((n) => n.id != null)
                            .map(
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
                  },
            child: const Text('Mark all as read'),
          ),
        ),
      ),
    );
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
                  const Text(
                    'No notifications',
                    style: TextStyle(color: FlixieColors.medium, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
