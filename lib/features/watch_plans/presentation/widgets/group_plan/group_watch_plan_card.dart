import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/request_poster_placeholder.dart';
import 'package:flixie_app/models/group_watch_request.dart';

class GroupWatchPlanCard extends StatelessWidget {
  const GroupWatchPlanCard({
    super.key,
    required this.request,
    required this.isMyRequest,
    required this.needsResponse,
    required this.posterUrl,
    required this.proposedDate,
    required this.createdDate,
    required this.onOpen,
  });

  final GroupWatchRequest request;
  final bool isMyRequest;
  final bool needsResponse;
  final String? posterUrl;
  final String proposedDate;
  final String createdDate;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: FlixieColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: FlixieColors.tabBarBorder.withValues(alpha: 0.75),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _poster(),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.movieTitle ?? 'Watch Plan',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textScaler: TextScaler.noScaling,
                              style: const TextStyle(
                                color: FlixieColors.light,
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                height: 1.12,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                ProfileAvatarView(
                                  avatar: request.requesterAvatar,
                                  fallbackText:
                                      (request.requesterUsername?.isNotEmpty ==
                                                  true
                                              ? request.requesterUsername![0]
                                              : '?')
                                          .toUpperCase(),
                                  fallbackColor: FlixieColors.primary,
                                  size: 24,
                                  profileBadges: request.requesterProfileBadges,
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    isMyRequest
                                        ? 'You invited the group'
                                        : '@${request.requesterUsername ?? 'Member'}',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: FlixieColors.light,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                _StatusPill(status: request.status),
                                if (createdDate.isNotEmpty)
                                  Flexible(
                                    child: Text(
                                      ' · $createdDate',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: FlixieColors.medium,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            if (proposedDate.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.event_outlined,
                                      size: 15, color: FlixieColors.medium),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      request.scheduledFor != null
                                          ? 'Scheduled for $proposedDate'
                                          : 'Proposed for $proposedDate',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: FlixieColors.medium,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (request.location?.trim().isNotEmpty == true)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on_outlined,
                                        size: 15,
                                        color: FlixieColors.secondary),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        request.location!.trim(),
                                        style: const TextStyle(
                                          color: FlixieColors.light,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (request.message?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  _MessageBubble(message: request.message!),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (needsResponse)
                      const Expanded(
                        child: Text(
                          'Needs your response',
                          style: TextStyle(
                            color: FlixieColors.warning,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    OutlinedButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.visibility_outlined, size: 15),
                      label: const Text('View plan'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );

  Widget _poster() => ClipRRect(
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
        child: SizedBox(
          width: 92,
          child: posterUrl == null
              ? const RequestPosterPlaceholder()
              : CachedNetworkImage(imageUrl: posterUrl!, fit: BoxFit.cover),
        ),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final WatchRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      WatchRequestStatus.open => FlixieColors.primary,
      WatchRequestStatus.accepted ||
      WatchRequestStatus.scheduled =>
        FlixieColors.secondary,
      WatchRequestStatus.completed => FlixieColors.success,
      WatchRequestStatus.expired => FlixieColors.medium,
      WatchRequestStatus.cancelled => FlixieColors.danger,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.statusLabel,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: .3,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: FlixieColors.tabBarBackgroundFocused,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          message,
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
}
