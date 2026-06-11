import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/notification.dart';
import '../../theme/app_theme.dart';
import '../../utils/color_utils.dart';

class NotificationRequestCard extends StatelessWidget {
  const NotificationRequestCard({
    super.key,
    required this.notification,
    required this.isProcessing,
    required this.formatDate,
    required this.onAccept,
    required this.onDecline,
    required this.onClose,
  });

  final FlixieNotification notification;
  final bool isProcessing;
  final String Function(String) formatDate;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onClose;

  bool get _isResolved =>
      notification.action == FlixieNotification.actionAccepted ||
      notification.action == FlixieNotification.actionDeclined;

  String get _requestKind {
    switch (notification.type) {
      case FlixieNotification.groupInvite:
        return 'Group invite';
      case FlixieNotification.groupRequest:
        return 'Group watch';
      case FlixieNotification.movieWatchRequest:
        return 'Watch request';
      case FlixieNotification.showWatchRequest:
        return 'Show request';
      case FlixieNotification.friendRequest:
      default:
        return 'Friend request';
    }
  }

  IconData get _typeIcon {
    switch (notification.type) {
      case FlixieNotification.groupInvite:
      case FlixieNotification.groupRequest:
        return Icons.group_outlined;
      case FlixieNotification.movieWatchRequest:
      case FlixieNotification.showWatchRequest:
        return Icons.play_circle_outline;
      case FlixieNotification.friendRequest:
      default:
        return Icons.person_outline_rounded;
    }
  }

  Color get _accentColor {
    switch (notification.type) {
      case FlixieNotification.groupInvite:
      case FlixieNotification.groupRequest:
        return FlixieColors.tertiary;
      case FlixieNotification.movieWatchRequest:
      case FlixieNotification.showWatchRequest:
        return FlixieColors.primary;
      case FlixieNotification.friendRequest:
      default:
        return FlixieColors.secondary;
    }
  }

  Widget _buildSubtitleWidget(BuildContext context) {
    if (_isResolved) {
      final sender = notification.senderName.isNotEmpty
          ? notification.senderName
          : 'Someone';
      final verb = notification.action == FlixieNotification.actionAccepted
          ? 'accepted'
          : 'declined';
      final target = _targetTitle;
      final groupName = notification.groupWatchGroupName;
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 13,
            height: 1.25,
          ),
          children: [
            TextSpan(text: '$sender $verb '),
            TextSpan(
              text: _resolvedTargetLabel,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (target != null && target.isNotEmpty) ...[
              const TextSpan(text: ' for '),
              _linkedTitleSpan(context, target),
            ],
            if (groupName != null && groupName.isNotEmpty)
              TextSpan(
                text: ' in $groupName',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
          ],
        ),
      );
    }

    if (notification.type == FlixieNotification.movieWatchRequest ||
        notification.type == FlixieNotification.showWatchRequest) {
      final title = notification.watchMediaTitle;
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 13,
            height: 1.25,
          ),
          children: [
            const TextSpan(text: 'sent you a watch request'),
            if (title != null && title.isNotEmpty) ...[
              const TextSpan(text: ' for '),
              _linkedTitleSpan(context, title),
            ],
          ],
        ),
      );
    }

    if (notification.type == FlixieNotification.groupRequest) {
      final title = notification.groupWatchMovieTitle;
      final groupName = notification.groupWatchGroupName;
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 13,
            height: 1.25,
          ),
          children: [
            const TextSpan(text: 'wants to watch'),
            if (title != null && title.isNotEmpty) ...[
              const TextSpan(text: ' '),
              _linkedTitleSpan(context, title),
            ],
            if (groupName != null && groupName.isNotEmpty)
              TextSpan(
                text: ' in $groupName',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
          ],
        ),
      );
    }

    if (notification.type == FlixieNotification.groupInvite) {
      final groupName = notification.groupInviteGroupName;
      return Text(
        groupName == null || groupName.isEmpty
            ? notification.groupInviteMessage
            : 'invited you to join $groupName',
        style: const TextStyle(
          color: FlixieColors.light,
          fontSize: 13,
          height: 1.25,
        ),
      );
    }

    return Text(
      notification.message.isNotEmpty
          ? notification.message
          : 'sent you a friend request',
      style: const TextStyle(
        color: FlixieColors.light,
        fontSize: 13,
        height: 1.25,
      ),
    );
  }

  InlineSpan _linkedTitleSpan(BuildContext context, String title) {
    final movieId = notification.watchMovieId ?? notification.groupWatchMovieId;
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: GestureDetector(
        onTap: movieId != null ? () => context.push('/movies/$movieId') : null,
        child: Text(
          title,
          style: TextStyle(
            color: movieId != null ? FlixieColors.primary : FlixieColors.light,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  String? get _targetTitle {
    return notification.watchMediaTitle ?? notification.groupWatchMovieTitle;
  }

  String get _resolvedTargetLabel {
    return switch (notification.type) {
      FlixieNotification.friendRequest => 'your friend request',
      FlixieNotification.groupInvite => 'your group invite',
      _ => 'your watch request',
    };
  }

  @override
  Widget build(BuildContext context) {
    final name = notification.senderName;
    final initials = notification.senderInitials ?? '';
    final avatarBg = avatarColorFromIconColor(notification.senderIconColor);
    final accent = _accentColor;
    final msg = notification.watchRequestMessage;
    final hasMessage = msg.isNotEmpty && notification.action == null;
    final isUnread = !notification.isRead;
    final date = notification.receivedAt.isEmpty
        ? ''
        : formatDate(notification.receivedAt);
    final posterPath = notification.watchMediaPosterPath;
    final posterUrl = posterPath == null
        ? null
        : 'https://image.tmdb.org/t/p/w185$posterPath';

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: isUnread
            ? FlixieColors.tabBarBackgroundFocused
            : FlixieColors.tabBarBackgroundFocused.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(
            color: isUnread ? accent : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RequestMediaPreview(
                  posterUrl: posterUrl,
                  accent: accent,
                  fallbackIcon: _typeIcon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 17,
                            backgroundColor: avatarBg.withValues(alpha: 0.2),
                            child: initials.isNotEmpty
                                ? Text(
                                    initials,
                                    style: TextStyle(
                                      color: avatarBg,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  )
                                : Icon(_typeIcon, color: avatarBg, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name.isNotEmpty ? name : _requestKind,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: FlixieColors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (date.isNotEmpty)
                                      Text(
                                        date,
                                        style: const TextStyle(
                                          color: FlixieColors.medium,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _requestKind,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildSubtitleWidget(context),
                      if (hasMessage) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.chat_bubble_outline,
                                size: 12,
                                color: accent,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  msg,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FlixieColors.light,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Notification actions',
                  color: FlixieColors.tabBarBackgroundFocused,
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: FlixieColors.medium,
                  ),
                  onSelected: (value) {
                    if (value == 'dismiss') onClose();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'dismiss',
                      child: Text('Dismiss'),
                    ),
                  ],
                ),
              ],
            ),
            if (isProcessing) ...[
              const SizedBox(height: 10),
              const SizedBox(
                height: 28,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ] else if (!_isResolved) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onDecline,
                    style: TextButton.styleFrom(
                      foregroundColor: FlixieColors.danger,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 17),
                    label: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: onAccept,
                    style: FilledButton.styleFrom(
                      backgroundColor: FlixieColors.primary,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestMediaPreview extends StatelessWidget {
  const _RequestMediaPreview({
    required this.posterUrl,
    required this.accent,
    required this.fallbackIcon,
  });

  final String? posterUrl;
  final Color accent;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 44,
        height: 64,
        child: posterUrl == null
            ? Container(
                color: accent.withValues(alpha: 0.12),
                child: Icon(fallbackIcon, color: accent, size: 22),
              )
            : CachedNetworkImage(
                imageUrl: posterUrl!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  color: accent.withValues(alpha: 0.12),
                  child: Icon(fallbackIcon, color: accent, size: 22),
                ),
              ),
      ),
    );
  }
}
