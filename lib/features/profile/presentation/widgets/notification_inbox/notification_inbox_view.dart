import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/notification_opt_in.dart';
import 'package:flixie_app/core/utils/notification_profile_badges.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/utils/notification_destination.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/notification_inbox_card.dart';

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

class NotificationInboxView extends StatefulWidget {
  const NotificationInboxView(
      {super.key,
      required this.notifications,
      required this.processingIds,
      required this.loading,
      required this.error,
      required this.onRetry,
      required this.onMarkAllRead,
      required this.onDismiss,
      required this.onOptions,
      required this.onRespond,
      required this.onOpen,
      this.hasMore = false,
      this.unreadCount,
      this.loadingMore = false,
      this.pageError,
      this.onLoadMore});
  final int? unreadCount;
  final bool hasMore, loadingMore;
  final String? pageError;
  final VoidCallback? onLoadMore;
  final List<FlixieNotification> notifications;
  final Set<String> processingIds;
  final bool loading;
  final String? error;
  final VoidCallback onRetry, onMarkAllRead;
  final void Function(FlixieNotification) onDismiss, onOptions;
  final void Function(FlixieNotification, String) onRespond, onOpen;
  @override
  State<NotificationInboxView> createState() => _NotificationInboxViewState();
}

class _NotificationInboxViewState extends State<NotificationInboxView> {
  _NotificationFilter _filter = _NotificationFilter.all;
  final Map<String, int> _dismissVersions = {};
  // ---- Filter helpers -------------------------------------------------------

  bool _isRequestType(FlixieNotification n) => notificationNeedsResponse(n);

  bool _isActivityType(FlixieNotification n) => !notificationNeedsResponse(n);

  /// One source of truth for both cards and section headings. This protects
  /// the headings from a stale refresh during a dismiss animation.
  List<FlixieNotification> get _visibleNotifications => widget.notifications
      .where(notificationBelongsInInbox)
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
    return widget.loading
        ? const ContentListSkeleton(label: 'Loading notifications')
        : widget.error != null
            ? _buildError()
            : Column(children: [
                const NotificationOptIn(),
                _buildFilterChips(),
                Expanded(child: _buildContent()),
              ]);
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
            Text(widget.error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.light)),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: () => widget.onRetry(), child: const Text('Retry')),
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
        if (widget.hasMore) _buildMore(),
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
                    onPressed: (widget.unreadCount ??
                                widget.notifications
                                    .where((n) => !n.isRead)
                                    .length) >
                            0
                        ? widget.onMarkAllRead
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
        if (widget.hasMore) _buildMore(),
      ],
    );
  }

  Widget _buildMore() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(children: [
          if (widget.pageError != null)
            Text(widget.pageError!, textAlign: TextAlign.center),
          TextButton(
              onPressed: widget.loadingMore ? null : widget.onLoadMore,
              child: Text(widget.loadingMore
                  ? 'Loading older notifications…'
                  : 'Load older notifications')),
        ]),
      );

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
                        widget.hasMore
                            ? 'No matches on this page'
                            : _emptyTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.colors.light,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (widget.hasMore) _buildMore(),
                      const SizedBox(height: 10),
                      Text(
                        widget.hasMore
                            ? 'Older notifications are available below.'
                            : _emptyBody,
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
      key: ValueKey('notification-$id-${_dismissVersions[id] ?? 0}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        // A fast failed delete can restore the card before the next frame.
        // Give that restored card fresh swipe state, not a dismissed element.
        setState(() => _dismissVersions[id] = (_dismissVersions[id] ?? 0) + 1);
        widget.onDismiss(notification);
      },
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
      processing: widget.processingIds.contains(n.id),
      onOptions: () => widget.onOptions(n),
      onAccept: (n.type == FlixieNotification.friendRequest ||
                  (n.type == FlixieNotification.groupInvite &&
                      route == '/notifications')) &&
              notificationNeedsResponse(n)
          ? () => widget.onRespond(n, FlixieNotification.actionAccepted)
          : null,
      onDecline: () => widget.onRespond(n, FlixieNotification.actionDeclined),
      onOpen: route == '/notifications'
          ? null
          : () {
              widget.onOpen(n, route);
            },
    );
  }
}
