import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/notification.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';

/// Parses the `iconColor` map from a user object into a [Color].
Color _avatarColorFromIconColor(Map<String, dynamic>? iconColor,
    {Color fallback = FlixieColors.primary}) {
  if (iconColor == null) return fallback;
  final hex = ((iconColor['hexCode'] ?? iconColor['hex']) as String? ?? '')
      .replaceAll('#', '');
  return Color(int.tryParse('0xFF$hex') ?? fallback.value);
}

class NotificationRequestCard extends StatelessWidget {
  const NotificationRequestCard({
    super.key,
    required this.notification,
    required this.isProcessing,
    required this.onAccept,
    required this.onDecline,
    required this.onClose,
  });

  final FlixieNotification notification;
  final bool isProcessing;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onClose;

  bool get _isResolved =>
      notification.action == FlixieNotification.actionAccepted ||
      notification.action == FlixieNotification.actionDeclined;

  String get _subtitle {
    switch (notification.type) {
      case FlixieNotification.groupInvite:
        final msg = notification.groupInviteMessage;
        return msg.isNotEmpty ? msg : 'Invited you to join a group';
      case FlixieNotification.groupRequest:
        final movieTitle = notification.groupWatchMovieTitle;
        final groupName = notification.groupWatchGroupName;
        logger.d(
            'Building group request subtitle, movieTitle="$movieTitle", groupName="$groupName"');
        if (movieTitle != null && movieTitle.isNotEmpty) {
          final suffix =
              groupName != null && groupName.isNotEmpty ? ' ($groupName)' : '';
          return 'wants to watch $movieTitle$suffix';
        }
        return 'sent a group watch request';
      case FlixieNotification.movieWatchRequest:
        return 'sent you a watch request for';
      case FlixieNotification.friendRequest:
      default:
        return notification.message.isNotEmpty
            ? notification.message
            : 'Sent you a friend request';
    }
  }

  Widget _buildSubtitleWidget(BuildContext context) {
    // Show accepted/declined message as subtitle if resolved
    if (_isResolved) {
      final sender = notification.senderName.isNotEmpty
          ? notification.senderName
          : 'Someone';
      if (notification.type == FlixieNotification.movieWatchRequest) {
        final title = notification.watchMediaTitle;
        if (notification.action == FlixieNotification.actionAccepted) {
          return Text(
            title != null && title.isNotEmpty
                ? '$sender accepted your watch request for $title'
                : '$sender accepted your watch request',
            style: const TextStyle(color: FlixieColors.light, fontSize: 13),
          );
        } else if (notification.action == FlixieNotification.actionDeclined) {
          return Text(
            title != null && title.isNotEmpty
                ? '$sender declined your watch request for $title'
                : '$sender declined your watch request',
            style: const TextStyle(color: FlixieColors.light, fontSize: 13),
          );
        }
      } else if (notification.type == FlixieNotification.groupRequest) {
        final movieTitle = notification.groupWatchMovieTitle;
        final movieId = notification.groupWatchMovieId;
        final groupName = notification.groupWatchGroupName;
        final verb = notification.action == FlixieNotification.actionAccepted
            ? 'accepted'
            : 'declined';
        return RichText(
          text: TextSpan(
            style: const TextStyle(color: FlixieColors.light, fontSize: 13),
            children: [
              TextSpan(text: '$sender $verb your watch request'),
              if (movieTitle != null && movieTitle.isNotEmpty) ...[
                const TextSpan(text: ' for '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.baseline,
                  baseline: TextBaseline.alphabetic,
                  child: GestureDetector(
                    onTap: movieId != null
                        ? () => context.push('/movies/$movieId')
                        : null,
                    child: Text(
                      movieTitle,
                      style: TextStyle(
                        color: movieId != null
                            ? FlixieColors.primary
                            : FlixieColors.light,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
              if (groupName != null && groupName.isNotEmpty)
                TextSpan(
                  text: ' in ',
                  children: [
                    TextSpan(
                      text: groupName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
            ],
          ),
        );
      } else {
        final target = () {
          switch (notification.type) {
            case FlixieNotification.friendRequest:
              return 'your friend request';
            case FlixieNotification.groupInvite:
              return 'your group invite';
            default:
              return 'your request';
          }
        }();
        if (notification.action == FlixieNotification.actionAccepted) {
          return Text('$sender accepted $target',
              style: const TextStyle(color: FlixieColors.light, fontSize: 13));
        } else if (notification.action == FlixieNotification.actionDeclined) {
          return Text('$sender declined $target',
              style: const TextStyle(color: FlixieColors.light, fontSize: 13));
        }
      }
      return const SizedBox.shrink();
    }
    // Pending state: show original subtitle
    if (notification.type == FlixieNotification.movieWatchRequest) {
      final title = notification.watchMediaTitle;
      final movieId = notification.watchMovieId;
      return RichText(
        text: TextSpan(
          style: const TextStyle(color: FlixieColors.light, fontSize: 13),
          children: [
            const TextSpan(text: 'sent you a watch request for '),
            if (title != null && title.isNotEmpty)
              WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: GestureDetector(
                  onTap: movieId != null
                      ? () => context.push('/movies/$movieId')
                      : null,
                  child: Text(
                    title,
                    style: TextStyle(
                      color: movieId != null
                          ? FlixieColors.primary
                          : FlixieColors.light,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      decorationColor: FlixieColors.primary,
                    ),
                  ),
                ),
              )
            else
              const TextSpan(text: 'a movie'),
          ],
        ),
      );
    }
    return _buildGroupInviteSubtitle() ??
        _buildGroupRequestSubtitle(context) ??
        Text(
          _subtitle,
          style: const TextStyle(color: FlixieColors.light, fontSize: 13),
        );
  }

  Widget? _buildGroupRequestSubtitle(BuildContext context) {
    if (notification.type != FlixieNotification.groupRequest || _isResolved) {
      return null;
    }
    final movieTitle = notification.groupWatchMovieTitle;
    final movieId = notification.groupWatchMovieId;
    final groupName = notification.groupWatchGroupName;
    if (movieTitle == null || movieTitle.isEmpty) {
      return const Text(
        'sent a group watch request',
        style: TextStyle(color: FlixieColors.light, fontSize: 13),
      );
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: FlixieColors.light, fontSize: 13),
        children: [
          const TextSpan(text: 'wants to watch '),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: movieId != null
                  ? () => context.push('/movies/$movieId')
                  : null,
              child: Text(
                movieTitle,
                style: TextStyle(
                  color: movieId != null
                      ? FlixieColors.primary
                      : FlixieColors.light,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (groupName != null && groupName.isNotEmpty)
            TextSpan(
              text: ' in ',
              children: [
                TextSpan(
                  text: groupName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget? _buildGroupInviteSubtitle() {
    if (notification.type != FlixieNotification.groupInvite || _isResolved) {
      return null;
    }
    final msg = _subtitle;
    const joinPrefix = 'to join ';
    final idx = msg.indexOf(joinPrefix);
    if (idx == -1) {
      return Text(msg,
          style: const TextStyle(color: FlixieColors.light, fontSize: 13));
    }
    final before = msg.substring(0, idx + joinPrefix.length);
    final groupName = msg.substring(idx + joinPrefix.length);
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: FlixieColors.light, fontSize: 13),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: groupName,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
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

  Color get _accentColor {
    switch (notification.type) {
      case FlixieNotification.groupInvite:
      case FlixieNotification.groupRequest:
        return FlixieColors.tertiary;
      case FlixieNotification.movieWatchRequest:
        // case FlixieNotification.showWatchRequest:
        return FlixieColors.primary;
      case FlixieNotification.friendRequest:
      default:
        return FlixieColors.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = notification.senderName;
    final initials = notification.senderInitials ?? '';
    final avatarBg = _avatarColorFromIconColor(notification.senderIconColor);
    final accent = _accentColor;
    final msg = notification.watchRequestMessage;
    final hasMessage = msg.isNotEmpty && notification.action == null;

    return Stack(
      children: [
        Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: FlixieColors.tabBarBackgroundFocused,
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: accent, width: 3)),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left: content
                Expanded(
                  child: Padding(
                    // Extra right padding so content doesn't sit under the close button
                    padding: const EdgeInsets.fromLTRB(12, 12, 36, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
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
                                  : Icon(_typeIcon, color: avatarBg, size: 20),
                            ),
                            const SizedBox(width: 10),
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
                                        fontSize: 14,
                                      ),
                                    ),
                                  const SizedBox(height: 2),
                                  _buildSubtitleWidget(context),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (hasMessage) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: accent.withValues(alpha: 0.25)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.chat_bubble_outline,
                                    size: 12, color: accent),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    msg,
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
                        const SizedBox(height: 10),
                        if (isProcessing)
                          const Center(
                            child: SizedBox(
                              height: 32,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (!_isResolved)
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: onDecline,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: FlixieColors.danger,
                                    side: BorderSide(
                                        color: FlixieColors.danger
                                            .withValues(alpha: 0.45)),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    minimumSize: Size.zero,
                                    textStyle: const TextStyle(fontSize: 13),
                                  ),
                                  child: const Text('Decline',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: onAccept,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: FlixieColors.primary,
                                    foregroundColor: Colors.black,
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                    minimumSize: Size.zero,
                                    textStyle: const TextStyle(fontSize: 13),
                                  ),
                                  child: const Text('Accept',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
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
        // Close button always top-right of the card
        Positioned(
          top: 4,
          right: 4,
          child: IconButton(
            icon: const Icon(Icons.close, size: 18, color: FlixieColors.light),
            tooltip: 'Close',
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
      ],
    );
  }
}
