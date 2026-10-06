import 'dart:async';
import 'package:flutter/material.dart';
import 'notification_deep_link.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// A foreground update opens current content; it never accepts an invitation
/// or schedule. The original Watch Plan name is retained for existing callers.
class ForegroundWatchPlanNotice {
  const ForegroundWatchPlanNotice(
      {required this.key,
      required this.title,
      required this.body,
      required this.path,
      this.actionLabel = 'View plan',
      this.icon = Icons.calendar_today_outlined,
      this.planKey,
      this.occurredAt});
  final String key;
  final String title;
  final String body;
  final String path;
  final String actionLabel;
  final IconData icon;
  final String? planKey;
  final DateTime? occurredAt;

  static ForegroundWatchPlanNotice? fromPayload(
    Map<String, dynamic> data, {
    required String? currentUserId,
    String? messageId,
    String? title,
    String? body,
    Uri? currentUri,
  }) {
    if (currentUserId == null ||
        data['actorId'] == currentUserId ||
        data['senderId'] == currentUserId ||
        (data['recipientId'] != null && data['recipientId'] != currentUserId)) {
      return null;
    }
    if (data['category'] != 'WATCH_PLAN') {
      final type = (data['type'] ?? data['notificationType'] ?? '')
          .toString()
          .toUpperCase();
      final isMessage = type == 'DIRECT_MESSAGE';
      final isInvite = type == 'FRIEND_REQUEST' || type == 'GROUP_INVITE';
      // Reactions, votes and routine group chat remain quiet while using Flixie.
      if (!isMessage && !isInvite) return null;
      final path = isInvite ? '/notifications' : notificationDeepLinkPath(data);
      if (isMessage &&
          (!path.startsWith('/chat/') ||
              currentUri?.path == Uri.parse(path).path)) {
        return null;
      }
      return ForegroundWatchPlanNotice(
        key: data['notificationId']?.toString() ??
            messageId ??
            '$type:${data['messageId'] ?? data['requestId']}:${data['senderId']}',
        title: title ??
            data['title']?.toString() ??
            (isMessage ? 'New message' : 'New invitation'),
        body: body ??
            data['body']?.toString() ??
            data['message']?.toString() ??
            (isMessage
                ? 'Open the conversation to read your message.'
                : 'Open your notifications to review this invitation.'),
        path: path,
        actionLabel: isMessage ? 'View message' : 'View invitation',
        icon: isMessage
            ? Icons.chat_bubble_outline
            : type == 'GROUP_INVITE'
                ? Icons.group_add_outlined
                : Icons.person_add_outlined,
      );
    }
    if (const {'CHOICES_SAVED', 'TITLE_PROPOSED'}.contains(data['event'])) {
      return null;
    }
    final planId = data['watchPlanId'] ?? data['requestId'];
    if (planId == null) return null;
    return ForegroundWatchPlanNotice(
      key: data['notificationId']?.toString() ??
          messageId ??
          '$planId:${data['event']}:${data['scheduleProposalId']}:${data['actorId']}',
      title: title ?? data['title']?.toString() ?? 'Watch Plan updated',
      body: body ??
          data['body']?.toString() ??
          'Someone updated your plan. Open it to see the latest details.',
      path: notificationDeepLinkPath(data),
      planKey: '${data['scope'] ?? 'DIRECT'}:$planId',
      occurredAt: DateTime.tryParse(data['occurredAt']?.toString() ?? ''),
    );
  }
}

/// Keep one banner visible; a newer incoming update replaces it. The durable
/// notification inbox remains available after dismissal or timeout.
class WatchPlanNoticePresenter {
  OverlayEntry? _entry;
  Timer? _timer;
  final Set<String> _seen = {};
  final Map<String, DateTime> _latest = {};

  bool show(OverlayState? overlay, ForegroundWatchPlanNotice notice,
      {required VoidCallback onOpen}) {
    if (overlay == null || !overlay.mounted) return false;
    if (_seen.contains(notice.key)) return true;
    _seen.add(notice.key);
    if (_seen.length > 100) _seen.remove(_seen.first);
    final planKey = notice.planKey;
    final occurredAt = notice.occurredAt;
    if (planKey != null && occurredAt != null) {
      final latest = _latest[planKey];
      if (latest != null && occurredAt.isBefore(latest)) return true;
      _latest[planKey] = occurredAt;
      if (_latest.length > 100) _latest.remove(_latest.keys.first);
    }
    dismiss();
    _entry = OverlayEntry(
        builder: (context) => Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                  bottom: false,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              maxWidth: 560,
                              maxHeight:
                                  MediaQuery.sizeOf(context).height * .45),
                          child: WatchPlanNoticeBanner(
                              notice: notice,
                              onDismiss: dismiss,
                              onOpen: () {
                                dismiss();
                                onOpen();
                              }),
                        )),
                  )),
            ));
    overlay.insert(_entry!);
    if (!MediaQuery.of(overlay.context).accessibleNavigation) {
      _timer = Timer(const Duration(seconds: 8), dismiss);
    }
    return true;
  }

  void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry?.dispose();
    _entry = null;
  }

  void reset() {
    dismiss();
    _seen.clear();
    _latest.clear();
  }
}

class WatchPlanNoticeBanner extends StatelessWidget {
  const WatchPlanNoticeBanner(
      {super.key,
      required this.notice,
      required this.onOpen,
      required this.onDismiss});
  final ForegroundWatchPlanNotice notice;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).colorScheme;
    final accent = dark ? FlixieColors.primaryTint : colors.primary;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color:
            dark ? FlixieColors.surfaceElevated : colors.surfaceContainerHigh,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9, right: 12),
                  child: Icon(notice.icon, size: 22, color: accent),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(notice.title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.35,
                                color: colors.onSurface)),
                        const SizedBox(height: 4),
                        Text(notice.body,
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: dark
                                    ? FlixieColors.lightTint
                                    : colors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                    width: 44,
                    height: 44,
                    child: IconButton(
                      tooltip: 'Dismiss update',
                      onPressed: onDismiss,
                      icon: Icon(Icons.close,
                          size: 18,
                          color: dark
                              ? FlixieColors.light
                              : colors.onSurfaceVariant),
                    )),
              ]),
              Padding(
                padding: const EdgeInsets.only(left: 22),
                child: TextButton(
                  onPressed: onOpen,
                  style: TextButton.styleFrom(
                      foregroundColor: accent, minimumSize: const Size(44, 44)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(child: Text(notice.actionLabel)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 16),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
