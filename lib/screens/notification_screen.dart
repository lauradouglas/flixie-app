import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/notification.dart';
import '../providers/auth_provider.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';

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

/// Parses the `iconColor` map from a user object into a [Color].
Color _avatarColorFromIconColor(Map<String, dynamic>? iconColor,
    {Color fallback = FlixieColors.primary}) {
  if (iconColor == null) return fallback;
  final hex = ((iconColor['hexCode'] ?? iconColor['hex']) as String? ?? '')
      .replaceAll('#', '');
  return Color(int.tryParse('0xFF$hex') ?? fallback.value);
}

/// Notification filter tabs.
enum _NotificationFilter { all, friendRequests, watchRequests, groupRequests, activity, alerts }

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
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
      final updated = await NotificationService.updateNotification(
        id,
        action: action,
        read: true,
      );
      if (mounted) {
        setState(() {
          final idx = _notifications.indexWhere((n) => n.id == id);
          if (idx != -1) _notifications[idx] = updated;
        });
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

  bool _isAlertType(FlixieNotification n) => n.type == 'ALERT';

  List<FlixieNotification> get _filtered {
    switch (_filter) {
      case _NotificationFilter.all:
        return _notifications;
      case _NotificationFilter.friendRequests:
        return _notifications
            .where((n) => n.type == FlixieNotification.friendRequest)
            .toList();
      case _NotificationFilter.watchRequests:
        return _notifications
            .where((n) =>
                n.type == FlixieNotification.movieWatchRequest ||
                n.type == FlixieNotification.showWatchRequest)
            .toList();
      case _NotificationFilter.groupRequests:
        return _notifications
            .where((n) =>
                n.type == FlixieNotification.groupRequest ||
                n.type == FlixieNotification.groupInvite)
            .toList();
      case _NotificationFilter.activity:
        return _notifications.where(_isActivityType).toList();
      case _NotificationFilter.alerts:
        return _notifications.where(_isAlertType).toList();
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
      (_NotificationFilter.friendRequests, 'Friends'),
      (_NotificationFilter.watchRequests, 'Watch'),
      (_NotificationFilter.groupRequests, 'Groups'),
      // TODO: uncomment when activity notifications are implemented
      // (_NotificationFilter.activity, 'Activity'),
      // TODO: uncomment when alert notifications are implemented
      // (_NotificationFilter.alerts, 'Alerts'),
    ];

    return Container(
      width: double.infinity,
      color: FlixieColors.tabBarBackgroundFocused,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((entry) {
            final (f, label) = entry;
            final selected = _filter == f;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
                selectedColor: FlixieColors.primary,
                backgroundColor: FlixieColors.tabBarBorder,
                labelStyle: TextStyle(
                  color: selected ? Colors.black : FlixieColors.light,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                side: BorderSide.none,
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
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _buildCard(items[i]),
    );
  }

  Widget _buildAllSections() {
    final pending = _pendingRequests;
    final newItems = _newNotifications;
    final earlier = _earlierNotifications;

    if (pending.isEmpty && newItems.isEmpty && earlier.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (pending.isNotEmpty) ...[
          _buildSectionHeader('REQUESTS'),
          const SizedBox(height: 8),
          ...pending.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildCard(n),
              )),
          const SizedBox(height: 16),
        ],
        if (newItems.isNotEmpty) ...[
          _buildSectionHeader('NEW'),
          const SizedBox(height: 8),
          ...newItems.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildCard(n),
              )),
          const SizedBox(height: 16),
        ],
        if (earlier.isNotEmpty) ...[
          _buildSectionHeader('EARLIER'),
          const SizedBox(height: 8),
          ...earlier.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildCard(n),
              )),
        ],
      ],
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
      return _RequestCard(
        notification: notification,
        isProcessing: _processingIds.contains(notification.id),
        onAccept: () =>
            _respond(notification, FlixieNotification.actionAccepted),
        onDecline: () =>
            _respond(notification, FlixieNotification.actionDeclined),
      );
    }
    return _ActivityCard(
      notification: notification,
      formatDate: _formatDate,
    );
  }
}

// ---------------------------------------------------------------------------
// Request card
// ---------------------------------------------------------------------------

class _RequestCard extends StatelessWidget {
  const _RequestCard({
    required this.notification,
    required this.isProcessing,
    required this.onAccept,
    required this.onDecline,
  });

  final FlixieNotification notification;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  bool get _isResolved =>
      notification.action == FlixieNotification.actionAccepted ||
      notification.action == FlixieNotification.actionDeclined;

  Color get _resolvedColor =>
      notification.action == FlixieNotification.actionAccepted
          ? FlixieColors.success
          : FlixieColors.danger;

  String get _resolvedLabel =>
      notification.action == FlixieNotification.actionAccepted
          ? 'Accepted'
          : 'Declined';

  String get _subtitle {
    switch (notification.type) {
      case FlixieNotification.groupInvite:
        return 'Invited you';
      case FlixieNotification.groupRequest:
        return 'Requested to join your group';
      case FlixieNotification.movieWatchRequest:
        return 'Sent you a movie watch request';
      // case FlixieNotification.showWatchRequest:
      //   return 'Sent you a show watch request';
      case FlixieNotification.friendRequest:
      default:
        return notification.message.isNotEmpty
            ? notification.message
            : 'Sent you a friend request';
    }
  }

  IconData get _typeIcon {
    switch (notification.type) {
      case FlixieNotification.groupInvite:
      case FlixieNotification.groupRequest:
        return Icons.group;
      case FlixieNotification.movieWatchRequest:
        // case FlixieNotification.showWatchRequest:
        return Icons.play_circle_outline;
      case FlixieNotification.friendRequest:
      default:
        return Icons.person;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = notification.senderName;
    final initials = notification.senderInitials ?? '';
    final avatarBg = _avatarColorFromIconColor(notification.senderIconColor);

    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 28,
                backgroundColor: avatarBg.withValues(alpha: 0.2),
                child: initials.isNotEmpty
                    ? Text(
                        initials,
                        style: TextStyle(
                          color: avatarBg,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      )
                    : Icon(_typeIcon, color: avatarBg, size: 28),
              ),
              const SizedBox(width: 12),
              // Name and subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name.isNotEmpty)
                      Text(
                        name,
                        style: const TextStyle(
                          color: FlixieColors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      _subtitle,
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isResolved)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _resolvedColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: _resolvedColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                _resolvedLabel,
                style: TextStyle(
                    color: _resolvedColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            )
          else if (isProcessing)
            const Center(
              child: SizedBox(
                height: 36,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: FlixieColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Accept',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FlixieColors.light,
                      side: BorderSide(
                          color: FlixieColors.medium.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Decline',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity / general notification card
// ---------------------------------------------------------------------------

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.notification,
    required this.formatDate,
  });

  final FlixieNotification notification;
  final String Function(String) formatDate;

  Color get _accentColor {
    switch (notification.type) {
      case 'MOVIE_WATCH_REQUEST':
      case 'SHOW_WATCH_REQUEST':
        return FlixieColors.primary;
      case 'ALERT':
        return FlixieColors.tertiary;
      default:
        return FlixieColors.secondary;
    }
  }

  IconData get _icon {
    switch (notification.type) {
      case 'MOVIE_WATCH_REQUEST':
      case 'SHOW_WATCH_REQUEST':
        return Icons.play_circle_outline;
      case 'ALERT':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = notification.senderName;
    final initials = notification.senderInitials ?? '';
    final avatarBg = _avatarColorFromIconColor(
      notification.senderIconColor,
      fallback: _accentColor,
    );

    final dateStr = notification.receivedAt.isNotEmpty
        ? formatDate(notification.receivedAt)
        : '';

    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _accentColor, width: 3),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar or icon
          CircleAvatar(
            radius: 22,
            backgroundColor: avatarBg.withValues(alpha: 0.2),
            child: initials.isNotEmpty
                ? Text(
                    initials,
                    style: TextStyle(
                      color: avatarBg,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  )
                : Icon(_icon, color: avatarBg, size: 20),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          children: [
                            if (name.isNotEmpty)
                              TextSpan(
                                text: '$name ',
                                style: const TextStyle(
                                  color: FlixieColors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            TextSpan(
                              text: notification.message,
                              style: const TextStyle(
                                color: FlixieColors.light,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!notification.isRead)
                      Padding(
                        padding: const EdgeInsets.only(left: 8, top: 4),
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: FlixieColors.tertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
                if (dateStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
