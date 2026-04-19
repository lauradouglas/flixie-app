import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/conversation.dart';
import '../../models/group_watch_request.dart';
import '../../theme/app_theme.dart';
import 'request_status_badge.dart';

class WatchRequestChatCard extends StatelessWidget {
  const WatchRequestChatCard({super.key, 
    required this.msg,
    this.cachedRequest,
    this.currentUserId,
    this.myStatus,
    required this.isResponding,
    this.onAccept,
    this.onDecline,
    this.onMaybe,
    required this.onTap,
    this.memberUsernames = const {},
  });

  final ChatMessage msg;
  final GroupWatchRequest? cachedRequest;
  final String? currentUserId;
  final String? myStatus;
  final bool isResponding;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onMaybe;
  final VoidCallback onTap;
  final Map<String, String> memberUsernames;

  @override
  Widget build(BuildContext context) {
    final payload = msg.watchRequestPayload;

    final movieTitle = cachedRequest?.movieTitle ??
        payload?['movieTitle'] as String? ??
        payload?['title'] as String? ??
        'Watch Request';
    final posterPath = cachedRequest?.moviePosterPath ??
        payload?['moviePosterUrl'] as String? ??
        payload?['posterPath'] as String?;
    final requestMessage =
        cachedRequest?.message ?? payload?['message'] as String?;
    final requesterUsername = cachedRequest?.requesterUsername ??
        memberUsernames[msg.senderId] ??
        msg.senderUsername;

    final expiresAt = cachedRequest?.expiresAt;
    String? expiresLabel;
    if (expiresAt != null) {
      final exp = DateTime.tryParse(expiresAt);
      if (exp != null) {
        final diff = exp.difference(DateTime.now());
        if (diff.isNegative) {
          expiresLabel = 'Expired';
        } else if (diff.inDays > 0) {
          expiresLabel = 'Expires in ${diff.inDays}d';
        } else if (diff.inHours > 0) {
          expiresLabel = 'Expires in ${diff.inHours}h';
        } else {
          expiresLabel = 'Expires soon';
        }
      }
    }
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w185$posterPath'
        : null;
    final isMyRequest = msg.senderId == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: FlixieColors.primary.withValues(alpha: 0.35)),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header — tappable
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    const Icon(Icons.movie_filter_outlined,
                        size: 13, color: FlixieColors.primary),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        isMyRequest
                            ? 'Your watch request'
                            : '@${requesterUsername ?? 'Unknown'} wants to watch',
                        style: const TextStyle(
                            color: FlixieColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1, color: FlixieColors.tabBarBorder),
            // Poster + details — tappable
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 64,
                          child: posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                      color: FlixieColors.tabBarBackground,
                                      child: const Center(
                                          child: Icon(Icons.movie_outlined,
                                              color: FlixieColors.medium,
                                              size: 22))),
                                  errorWidget: (_, __, ___) => Container(
                                      color: FlixieColors.tabBarBackground,
                                      child: const Center(
                                          child: Icon(Icons.movie_outlined,
                                              color: FlixieColors.medium,
                                              size: 22))),
                                )
                              : Container(
                                  color: FlixieColors.tabBarBackground,
                                  child: const Center(
                                      child: Icon(Icons.movie_outlined,
                                          color: FlixieColors.medium,
                                          size: 22))),
                        ),
                      ),
                    ),
                    // Details
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              movieTitle,
                              style: const TextStyle(
                                  color: FlixieColors.light,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            RequestStatusBadge(
                              status: cachedRequest?.status,
                            ),
                            if (requestMessage != null &&
                                requestMessage.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                '"$requestMessage"',
                                style: const TextStyle(
                                    color: FlixieColors.medium,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            if (expiresLabel != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    expiresLabel == 'Expired'
                                        ? Icons.timer_off_outlined
                                        : Icons.timer_outlined,
                                    size: 11,
                                    color: expiresLabel == 'Expired'
                                        ? FlixieColors.danger
                                        : FlixieColors.warning,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    expiresLabel,
                                    style: TextStyle(
                                        color: expiresLabel == 'Expired'
                                            ? FlixieColors.danger
                                            : FlixieColors.warning,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                            if (cachedRequest != null &&
                                (cachedRequest!.acceptedCount > 0 ||
                                    cachedRequest!.maybeCount > 0 ||
                                    cachedRequest!.declinedCount > 0)) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  if (cachedRequest!.acceptedCount > 0) ...[
                                    const Icon(Icons.check,
                                        size: 11, color: FlixieColors.success),
                                    const SizedBox(width: 2),
                                    Text('${cachedRequest!.acceptedCount}',
                                        style: const TextStyle(
                                            color: FlixieColors.success,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 10),
                                  ],
                                  if (cachedRequest!.maybeCount > 0) ...[
                                    const Icon(Icons.help_outline,
                                        size: 11, color: FlixieColors.warning),
                                    const SizedBox(width: 2),
                                    Text('${cachedRequest!.maybeCount}',
                                        style: const TextStyle(
                                            color: FlixieColors.warning,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 10),
                                  ],
                                  if (cachedRequest!.declinedCount > 0) ...[
                                    const Icon(Icons.close,
                                        size: 11, color: FlixieColors.danger),
                                    const SizedBox(width: 2),
                                    Text('${cachedRequest!.declinedCount}',
                                        style: const TextStyle(
                                            color: FlixieColors.danger,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Action row — only for members who aren't the requester
            if (!isMyRequest) ...[
              const Divider(height: 1, color: FlixieColors.tabBarBorder),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: myStatus == 'ACCEPTED'
                    ? _chatStatusChip('You accepted ✓', FlixieColors.success)
                    : myStatus == 'DECLINED'
                        ? _chatStatusChip('You declined ✗', FlixieColors.danger)
                        : myStatus == 'MAYBE'
                            ? _chatStatusChip(
                                'You said maybe', FlixieColors.warning)
                            : isResponding
                                ? const Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: FlixieColors.primary),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: onDecline,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: FlixieColors.danger
                                                .withValues(alpha: 0.85),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            minimumSize: Size.zero,
                                            textStyle: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          child: const Text('Decline'),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: onMaybe,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: FlixieColors
                                                .warning
                                                .withValues(alpha: 0.85),
                                            foregroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            minimumSize: Size.zero,
                                            textStyle: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          child: const Text('Maybe'),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: onAccept,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: FlixieColors
                                                .success
                                                .withValues(alpha: 0.85),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8)),
                                            minimumSize: Size.zero,
                                            textStyle: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          child: const Text('Accept'),
                                        ),
                                      ),
                                    ],
                                  ),
              ),
            ],
            // Footer — tappable to open detail
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                color: FlixieColors.tabBarBackground.withValues(alpha: 0.6),
                child: const Row(
                  children: [
                    Icon(Icons.chat_bubble_outline,
                        size: 11, color: FlixieColors.medium),
                    SizedBox(width: 4),
                    Text('View details & reply',
                        style: TextStyle(
                            color: FlixieColors.medium, fontSize: 11)),
                    Spacer(),
                    Icon(Icons.chevron_right,
                        size: 14, color: FlixieColors.medium),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
