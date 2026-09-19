import 'package:flixie_app/core/utils/notification_profile_badges.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/utils/notification_destination.dart';
import 'package:flixie_app/features/profile/data/notification_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/notification_visibility.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox_card.dart';

/// How often the screen silently re-fetches notifications in the background.
const Duration _kPollInterval = Duration(seconds: 60);

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
    final watchPlanId = notification.linkedRequestId;
    final isWatchPlan =
        notification.type == FlixieNotification.movieWatchRequest ||
            notification.type == FlixieNotification.showWatchRequest;

    // Remove this card before waiting on the network. A poll or pull-to-
    // refresh can otherwise rebuild the list with an older response while a
    // Dismissible is still completing its animation, which makes the user
    // have to swipe the same card again.
    if (mounted) {
      setState(() {
        _dismissingIds.add(id);
        if (isWatchPlan && watchPlanId != null) {
          final matchingIds = _notifications
              .where((item) =>
                  (item.type == FlixieNotification.movieWatchRequest ||
                      item.type == FlixieNotification.showWatchRequest) &&
                  item.linkedRequestId == watchPlanId)
              .map((item) => item.id)
              .whereType<String>();
          _dismissingIds.addAll(matchingIds);
          _notifications.removeWhere((item) =>
              (item.type == FlixieNotification.movieWatchRequest ||
                  item.type == FlixieNotification.showWatchRequest) &&
              item.linkedRequestId == watchPlanId);
        } else {
          _notifications.removeWhere((n) => n.id == id);
        }
      });
      if (isWatchPlan && watchPlanId != null) {
        context
            .read<AuthProvider>()
            .removeCachedWatchPlanNotifications(watchPlanId);
      } else {
        context.read<AuthProvider>().removeCachedNotification(id);
      }
    }
    try {
      await NotificationService.deleteNotification(id);
      if (mounted) {
        // Keep the just-dismissed id hidden until the server confirms a
        // refreshed list that no longer contains it.
        await _load();
      }
    } catch (e) {
      logger.e('[NotificationScreen] close error: $e');
      if (mounted) {
        setState(() => _dismissingIds.remove(id));
        await _load();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Failed to dismiss notification.'),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    }
  }

  List<FlixieNotification> _notifications = [];
  final Set<String> _dismissingIds = <String>{};
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
      _notifications = visibleNotificationsForUser(cached, userId);
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

  /// Silent background refresh - does not show a loading spinner and does not
  /// clear existing notifications while fetching, so the UI stays stable.
  Future<void> _poll() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) return;
    try {
      final fresh = await NotificationService.getNotifications(userId);
      final visible = visibleNotificationsForUser(fresh, userId)
          .where((notification) =>
              notification.id == null ||
              !_dismissingIds.contains(notification.id))
          .toList();
      if (mounted) {
        setState(() {
          _notifications = visible;
          _error = null;
        });
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
      final visible = visibleNotificationsForUser(notifications, userId)
          .where((notification) =>
              notification.id == null ||
              !_dismissingIds.contains(notification.id))
          .toList();
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

  Future<void> _respond(FlixieNotification notification, String action) async {
    final id = notification.id;
    if (id == null || _processingIds.contains(id)) return;
    setState(() => _processingIds.add(id));
    final analytics = context.read<AnalyticsController>();
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.dbUser?.id;
      final requestId = notification.linkedRequestId;
      if (requestId == null) throw StateError('Missing invitation request');

      if (notification.type == FlixieNotification.friendRequest) {
        if (action == FlixieNotification.actionAccepted) {
          await _friendActions.acceptRequest(requestId);
        } else {
          await _friendActions.declineRequest(requestId);
        }
      }

      // For watch requests, also update the underlying request record.
      if (notification.type == FlixieNotification.movieWatchRequest ||
          notification.type == FlixieNotification.showWatchRequest) {
        {
          final status = action == FlixieNotification.actionAccepted
              ? 'ACCEPTED'
              : 'DECLINED';
          await RequestService.updateRequest(requestId, status);
        }
      }

      // For group invites and group requests, also update the underlying request record.
      if (notification.type == FlixieNotification.groupInvite ||
          notification.type == FlixieNotification.groupRequest) {
        {
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
      if (action == FlixieNotification.actionAccepted) {
        if (notification.type == FlixieNotification.friendRequest) {
          await analytics.friendConnected();
        } else if (notification.type == FlixieNotification.movieWatchRequest ||
            notification.type == FlixieNotification.showWatchRequest) {
          final request = notification.linkedWatchRequest;
          await analytics.watchPlanAccepted(
            watchPlanId: requestId,
            contentId: request?.analyticsContentId,
            contentType: request?.analyticsContentType ??
                (notification.type == FlixieNotification.showWatchRequest
                    ? 'show'
                    : 'movie'),
            planType: 'friend',
            participantCount: 2,
            source: 'notification',
          );
        }
      }

      if (mounted) {
        setState(() {
          _notifications.removeWhere((n) => n.id == id);
        });
        auth.updateCachedNotifications(_notifications);
        if (userId != null &&
            notification.type == FlixieNotification.friendRequest) {
          final friends = await _friendActions.getFriends(userId);
          if (mounted) auth.updateCachedFriends(friends);
        } else if (userId != null &&
            notification.type == FlixieNotification.groupInvite) {
          // Group membership has just changed on the server. Refresh this
          // cache before returning to Social so its existing IndexedStack
          // cannot render the stale pre-invite group list.
          try {
            final groups = await GroupService.getUserGroups(userId);
            if (mounted) auth.updateCachedGroups(groups);
          } catch (error) {
            // The request itself has succeeded. Preserve that success and
            // fall back to the usual background refresh if the cache fetch
            // happens to fail.
            logger.w('[NotificationScreen] group cache refresh failed: $error');
            await auth.refreshUserData();
          }
          TabRefreshController.requestSocialRefresh();
        } else {
          await auth.refreshUserData();
        }
        if (!mounted) return;
        // Show success toast
        final isWatchPlan =
            notification.type == FlixieNotification.movieWatchRequest ||
                notification.type == FlixieNotification.showWatchRequest ||
                notification.type == FlixieNotification.groupRequest;
        final subject = isWatchPlan ? 'Watch Plan' : 'Request';
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.success,
            content: Text(
              action == FlixieNotification.actionAccepted
                  ? '$subject accepted successfully.'
                  : '$subject declined successfully.',
            ),
            backgroundColor: context.colors.surfaceElevated,
          ),
        );
      }
    } catch (e) {
      logger.e('[NotificationScreen] respond error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: Text(
              action == FlixieNotification.actionAccepted
                  ? 'Failed to accept. Please try again.'
                  : 'Failed to decline. Please try again.',
            ),
            backgroundColor: context.colors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingIds.remove(id));
    }
  }

  // ---- Filter helpers -------------------------------------------------------

  bool _isRequestType(FlixieNotification n) => notificationNeedsResponse(n);

  bool _isActivityType(FlixieNotification n) => !notificationNeedsResponse(n);

  /// One source of truth for both cards and section headings. This protects
  /// the headings from a stale refresh during a dismiss animation.
  List<FlixieNotification> get _visibleNotifications => _notifications
      .where((notification) =>
          notification.id == null || !_dismissingIds.contains(notification.id))
      .toList(growable: false);

  List<FlixieNotification> get _filtered {
    switch (_filter) {
      case _NotificationFilter.all:
        return _visibleNotifications;
      case _NotificationFilter.requests:
        return _visibleNotifications.where(_isRequestType).toList();
      case _NotificationFilter.activity:
        return _visibleNotifications.where(_isActivityType).toList();
    }
  }

  int _countForFilter(_NotificationFilter filter) {
    return switch (filter) {
      _NotificationFilter.all => _visibleNotifications.length,
      _NotificationFilter.requests =>
        _visibleNotifications.where(_isRequestType).length,
      _NotificationFilter.activity =>
        _visibleNotifications.where(_isActivityType).length,
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
            Icon(Icons.error_outline, color: context.colors.danger, size: 48),
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.light)),
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
      (_NotificationFilter.requests, 'Needs you'),
      (_NotificationFilter.activity, 'Activity'),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Container(
        decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: context.colors.tabBarBorder)),
        ),
        child: Row(
          children: filters.map((entry) {
            final (f, label) = entry;
            final selected = _filter == f;
            final count = _countForFilter(f);
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: '$label, $count notifications',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => setState(() => _filter = f),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 44),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border(
                            bottom: BorderSide(
                                width: 3,
                                color: selected
                                    ? context.colors.primaryText
                                    : Colors.transparent)),
                      ),
                      child: Text(
                        f == _NotificationFilter.requests && count > 0
                            ? '$label $count'
                            : label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected
                              ? context.colors.primaryText
                              : context.colors.light,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        ..._buildGroupedByDate(items),
      ],
    );
  }

  List<Widget> _buildGroupedByDate(List<FlixieNotification> items) {
    final sorted = [...items]
      ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    final result = <Widget>[];
    String? previous;
    var first = true;
    for (final n in sorted) {
      final label = _dateSectionLabel(n);
      if (label != previous) {
        result.add(Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Row(children: [
              Expanded(child: _buildSectionHeader(label.toUpperCase())),
              if (first && _filter == _NotificationFilter.all)
                TextButton(
                    onPressed: _notifications.any((n) => !n.isRead)
                        ? _markAllRead
                        : null,
                    child: const Text('Mark all read',
                        style: TextStyle(fontSize: 12))),
            ])));
        previous = label;
        first = false;
      }
      result.add(Padding(
          padding: const EdgeInsets.only(bottom: 8), child: _buildCard(n)));
    }
    return result;
  }

  Widget _buildAllSections() {
    if (_visibleNotifications.isEmpty) return _buildEmptyState();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        ..._buildGroupedByDate(_visibleNotifications),
      ],
    );
  }

  Future<void> _setRead(FlixieNotification notification, bool read) async {
    if (notification.id == null) return;
    try {
      await NotificationService.updateNotification(notification.id!,
          read: read);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => n.id == notification.id ? n.copyWith(read: read) : n)
            .toList();
      });
      context.read<AuthProvider>().updateCachedNotifications(_notifications);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Could not update notification. Try again.')));
      }
    }
  }

  Future<void> _markAllRead() async {
    for (final notification in List<FlixieNotification>.of(_notifications)) {
      if (!notification.isRead) await _setRead(notification, true);
    }
  }

  void _showOptions(FlixieNotification notification) {
    showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(sheetContext).height * .6),
              child: SingleChildScrollView(
                  child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Notification options',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(height: 12),
                              ListTile(
                                  leading: const Icon(
                                      Icons.mark_email_unread_outlined),
                                  title: Text(notification.isRead
                                      ? 'Mark as unread'
                                      : 'Mark as read'),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _setRead(
                                        notification, !notification.isRead);
                                  }),
                              ListTile(
                                  leading: const Icon(Icons.delete_outline),
                                  title: const Text('Remove notification'),
                                  onTap: () {
                                    Navigator.pop(sheetContext);
                                    _closeNotification(notification);
                                  }),
                            ]),
                      ))),
            ));
  }

  Widget _buildEmptyState() {
    // Wrap in a scrollable so RefreshIndicator (pull-to-refresh) works even
    // when there are no notifications to show.
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.notifications_none,
                          size: 64,
                          color: context.colors.medium.withValues(alpha: 0.6)),
                      const SizedBox(height: 16),
                      Text(
                        _emptyTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.light,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _emptyBody,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.medium,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String get _emptyTitle {
    return switch (_filter) {
      _NotificationFilter.requests => 'Nothing needs you right now',
      _NotificationFilter.activity => 'No activity yet',
      _NotificationFilter.all => 'No notifications',
    };
  }

  String get _emptyBody {
    return switch (_filter) {
      _NotificationFilter.requests =>
        'Watch Plans and invites will appear here when someone needs a response.',
      _NotificationFilter.activity =>
        'Friend, group, and watch updates will show up here.',
      _NotificationFilter.all => 'You are all caught up.',
    };
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: context.colors.medium,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildCard(FlixieNotification notification) {
    final id = notification.id;
    final card = _buildNotificationCard(notification);
    if (id == null) return card;
    return Dismissible(
      key: ValueKey('notification-$id'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _closeNotification(notification),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: context.colors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline, color: context.colors.white),
      ),
      child: card,
    );
  }

  Widget _buildNotificationCard(FlixieNotification notification) {
    final n = notification;
    final route = notificationDestination(n);
    final friends = context.watch<AuthProvider>().cachedFriends;
    final badges = notificationProfileBadges(n, friends);
    return NotificationInboxCard(
      profileBadges: badges,
      notification: n,
      date: _formatDate(n.receivedAt),
      processing: _processingIds.contains(n.id),
      onOptions: () => _showOptions(n),
      onAccept: (n.type == FlixieNotification.friendRequest ||
                  (n.type == FlixieNotification.groupInvite &&
                      route == '/notifications')) &&
              notificationNeedsResponse(n)
          ? () => _respond(n, FlixieNotification.actionAccepted)
          : null,
      onDecline: () => _respond(n, FlixieNotification.actionDeclined),
      onOpen: route == '/notifications'
          ? null
          : () {
              if (!n.isRead) unawaited(_setRead(n, true));
              context.push(route);
            },
    );
  }
}
