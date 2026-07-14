import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/color_utils.dart';

class NotificationRequestCard extends StatelessWidget {
  const NotificationRequestCard({
    super.key,
    required this.notification,
    required this.isProcessing,
    required this.formatDate,
    required this.currentUserId,
    required this.onAccept,
    required this.onDecline,
    required this.onAcceptSchedule,
    required this.onDeclineSchedule,
    required this.onSuggestSchedule,
    required this.onClose,
  });

  final FlixieNotification notification;
  final bool isProcessing;
  final String Function(String) formatDate;
  final String? currentUserId;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onAcceptSchedule;
  final VoidCallback onDeclineSchedule;
  final VoidCallback onSuggestSchedule;
  final VoidCallback onClose;

  bool get _isResolved =>
      notification.action == FlixieNotification.actionAccepted ||
      notification.action == FlixieNotification.actionDeclined;

  bool get _canOpenAcceptedWatchRequest =>
      notification.action == FlixieNotification.actionAccepted &&
      (notification.type == FlixieNotification.movieWatchRequest ||
          notification.type == FlixieNotification.showWatchRequest) &&
      notification.linkedRequestId != null &&
      !_showsScheduleFlow;

  bool get _isWatchNotification =>
      notification.type == FlixieNotification.movieWatchRequest ||
      notification.type == FlixieNotification.showWatchRequest;

  Map<String, dynamic>? get _latestProposal =>
      notification.latestWatchScheduleProposal;

  String? get _latestProposalStatus =>
      _latestProposal?['status']?.toString().toUpperCase();

  bool get _isPendingScheduleProposal =>
      _isWatchNotification &&
      notification.watchRequestScheduleStatus?.toUpperCase() == 'PROPOSED' &&
      _latestProposalStatus == 'PENDING';

  bool get _proposedByMe =>
      currentUserId != null &&
      currentUserId!.isNotEmpty &&
      _latestProposal?['proposerId']?.toString() == currentUserId;

  bool get _canRespondToScheduleProposal =>
      _isPendingScheduleProposal && !_proposedByMe;

  bool get _isAgreedSchedule =>
      _isWatchNotification &&
      notification.watchRequestScheduleStatus?.toUpperCase() == 'AGREED';

  bool get _isDeclinedSchedule =>
      _isWatchNotification &&
      notification.watchRequestScheduleStatus?.toUpperCase() == 'DECLINED';

  bool get _showsScheduleFlow =>
      _isPendingScheduleProposal || _isAgreedSchedule || _isDeclinedSchedule;

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
    if (_isResolved && !_showsScheduleFlow) {
      final sender = notification.senderName.isNotEmpty
          ? notification.senderName
          : 'Someone';
      final verb = notification.action == FlixieNotification.actionAccepted
          ? 'accepted'
          : 'declined';
      final target = _targetTitle;
      final groupName = notification.groupWatchGroupName;
      final scheduleLabel = _acceptedScheduleLabel;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
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
          ),
          if (scheduleLabel != null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 14,
                  color: FlixieColors.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    scheduleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    final pendingScheduleLabel = _pendingScheduleLabel;
    if ((notification.type == FlixieNotification.movieWatchRequest ||
            notification.type == FlixieNotification.showWatchRequest) &&
        pendingScheduleLabel != null) {
      final title = notification.watchMediaTitle;
      final note = _proposalNote;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 13,
                height: 1.25,
              ),
              children: [
                TextSpan(
                    text: _proposedByMe
                        ? 'waiting for them to respond'
                        : 'suggested a watch time'),
                if (title != null && title.isNotEmpty) ...[
                  const TextSpan(text: ' for '),
                  _linkedTitleSpan(context, title),
                ],
              ],
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              const Icon(
                Icons.event_outlined,
                size: 14,
                color: FlixieColors.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pendingScheduleLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 7),
            _ScheduleNote(text: note),
          ],
        ],
      );
    }

    if ((notification.type == FlixieNotification.movieWatchRequest ||
            notification.type == FlixieNotification.showWatchRequest) &&
        _isDeclinedSchedule) {
      final title = notification.watchMediaTitle;
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 13,
            height: 1.25,
          ),
          children: [
            const TextSpan(text: 'time declined'),
            if (title != null && title.isNotEmpty) ...[
              const TextSpan(text: ' for '),
              _linkedTitleSpan(context, title),
            ],
          ],
        ),
      );
    }

    if ((notification.type == FlixieNotification.movieWatchRequest ||
            notification.type == FlixieNotification.showWatchRequest) &&
        _isAgreedSchedule) {
      final title = notification.watchMediaTitle;
      final scheduledFor = notification.watchRequestScheduledFor ??
          _proposalDateWithStatus('ACCEPTED');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 13,
                height: 1.25,
              ),
              children: [
                const TextSpan(text: 'watch time agreed'),
                if (title != null && title.isNotEmpty) ...[
                  const TextSpan(text: ' for '),
                  _linkedTitleSpan(context, title),
                ],
              ],
            ),
          ),
          if (scheduledFor != null) ...[
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(
                  Icons.event_available_outlined,
                  size: 14,
                  color: FlixieColors.secondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Scheduled for ${_formatScheduleDate(scheduledFor)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
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

  String? get _acceptedScheduleLabel {
    if (notification.action != FlixieNotification.actionAccepted) return null;
    final scheduledFor = notification.watchRequestScheduledFor ??
        _proposalDateWithStatus('ACCEPTED');
    if (scheduledFor == null) return null;
    return 'Scheduled for ${_formatScheduleDate(scheduledFor)}';
  }

  String? get _pendingScheduleLabel {
    final proposal = notification.latestWatchScheduleProposal;
    if (proposal == null) return null;
    final status = proposal['status']?.toString().toUpperCase();
    if (status != 'PENDING') return null;
    final proposedFor = DateTime.tryParse(
      proposal['proposedFor']?.toString() ?? '',
    );
    if (proposedFor == null) return null;
    return 'Proposed for ${_formatScheduleDate(proposedFor)}';
  }

  String? get _proposalNote {
    final note = _latestProposal?['message']?.toString().trim();
    return note == null || note.isEmpty ? null : note;
  }

  DateTime? _proposalDateWithStatus(String status) {
    final proposal = notification.latestWatchScheduleProposal;
    if (proposal == null) return null;
    if (proposal['status']?.toString().toUpperCase() != status) return null;
    return DateTime.tryParse(proposal['proposedFor']?.toString() ?? '');
  }

  String _formatScheduleDate(DateTime value) {
    final local = value.toLocal();
    const months = [
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
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'pm' : 'am';
    return '${local.day} ${months[local.month - 1]}, $hour:$minute$suffix';
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
            ] else if (_canRespondToScheduleProposal) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onAcceptSchedule,
                      style: FilledButton.styleFrom(
                        backgroundColor: FlixieColors.primary,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text(
                        'Accept time',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDeclineSchedule,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: FlixieColors.light,
                        side: BorderSide(
                          color: FlixieColors.medium.withValues(alpha: 0.5),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 17),
                      label: const Text(
                        'Decline',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onSuggestSchedule,
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: const Text('Suggest another time'),
                  style: TextButton.styleFrom(
                    foregroundColor: FlixieColors.medium,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ] else if (_isAgreedSchedule || _isDeclinedSchedule) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: onSuggestSchedule,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isAgreedSchedule
                        ? FlixieColors.primary
                        : FlixieColors.secondary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: Text(
                    _isAgreedSchedule ? 'Reschedule' : 'Suggest another time',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ] else if (_canOpenAcceptedWatchRequest) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => context.push(
                    '/watch-requests?requestId=${notification.linkedRequestId}',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: FlixieColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: const Text(
                    'Schedule watch',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ] else if (!_isResolved && !_showsScheduleFlow) ...[
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

class _ScheduleNote extends StatelessWidget {
  const _ScheduleNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: FlixieColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: FlixieColors.primary.withValues(alpha: 0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 13,
            color: FlixieColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 12,
                fontStyle: FontStyle.italic,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
