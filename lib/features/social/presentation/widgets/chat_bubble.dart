import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/presentation/utils/movie_share_payload.dart';
import 'package:flixie_app/features/social/presentation/utils/activity_reply_payload.dart';
import 'package:flixie_app/models/profile_avatar.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.message,
    required this.senderUsername,
    required this.isMe,
    required this.sentAt,
    this.avatar,
    this.initials,
    this.profileBadges = const [],
    this.replyTo,
    this.onLongPress,
    this.onSenderTap,
  });

  final String message;
  final String senderUsername;
  final bool isMe;
  final DateTime sentAt;
  final ProfileAvatar? avatar;
  final String? initials;
  final List<String> profileBadges;
  final String? replyTo;
  final VoidCallback? onLongPress;
  final VoidCallback? onSenderTap;

  @override
  Widget build(BuildContext context) {
    final hasActivityReply = parseActivityReplyPayload(message) != null;
    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (replyTo != null)
              Padding(
                padding: EdgeInsets.only(
                    left: isMe ? 0 : 4, right: isMe ? 4 : 0, bottom: 2),
                child: Text(
                  replyTo!,
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(left: 46, bottom: 4),
                child: Semantics(
                  button: onSenderTap != null,
                  label: onSenderTap == null
                      ? senderUsername
                      : 'Open $senderUsername profile',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onSenderTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        senderUsername,
                        style: TextStyle(
                          color: onSenderTap == null
                              ? FlixieColors.medium
                              : FlixieColors.primaryTint,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[
                  ProfileAvatarView(
                    avatar: avatar,
                    fallbackText: initials?.isNotEmpty == true
                        ? initials!
                        : senderUsername.isNotEmpty
                            ? senderUsername[0].toUpperCase()
                            : '?',
                    fallbackColor: FlixieColors.primary,
                    size: 36,
                    profileBadges: profileBadges,
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width *
                          (hasActivityReply ? 0.78 : 0.62),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? FlixieColors.primary : FlixieColors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: _buildMessageBody(context),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _timeLabel(sentAt),
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildMessageBody(BuildContext context) {
    final activityReply = parseActivityReplyPayload(message);
    if (activityReply != null) {
      return _buildActivityReplyCard(context, activityReply);
    }

    final movieShare = parseMovieSharePayload(message);
    if (movieShare != null) {
      return _buildMovieShareCard(context, movieShare);
    }

    final link = _firstLink(message);
    final textColor = isMe ? Colors.white : FlixieColors.textPrimary;
    if (link == null) {
      return Text(
        message,
        style: TextStyle(color: textColor, fontSize: 15),
      );
    }

    final bodyText = message.replaceFirst(link, '').trim();
    final actionLabel = _labelForLink(link);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (bodyText.isNotEmpty)
          Text(
            bodyText,
            style: TextStyle(color: textColor, fontSize: 15),
          ),
        if (bodyText.isNotEmpty) const SizedBox(height: 8),
        InkWell(
          onTap: () => _openLink(context, link),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: isMe
                      ? Colors.white.withValues(alpha: 0.94)
                      : FlixieColors.primary,
                ),
                const SizedBox(width: 5),
                Text(
                  actionLabel,
                  style: TextStyle(
                    color: isMe
                        ? Colors.white.withValues(alpha: 0.94)
                        : FlixieColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityReplyCard(
    BuildContext context,
    ActivityReplyPayload payload,
  ) {
    final textColor = isMe ? Colors.white : FlixieColors.textPrimary;
    final recommendation = payload.recommended;
    final actionLabel = payload.activityLabel == 'review'
        ? 'View review'
        : payload.link.contains('shows')
            ? 'Open show'
            : 'Open movie';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (payload.message.isNotEmpty) ...[
          Text(
            payload.message,
            style: TextStyle(color: textColor, fontSize: 15, height: 1.3),
          ),
          const SizedBox(height: 10),
        ],
        InkWell(
          onTap: () => _openLink(context, payload.link),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isMe
                  ? const Color(0xFF5830AE)
                  : FlixieColors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isMe
                    ? Colors.white.withValues(alpha: .28)
                    : FlixieColors.primary.withValues(alpha: .42),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: SizedBox(
                    width: 64,
                    height: 96,
                    child: payload.posterUrl.isEmpty
                        ? Container(
                            color: FlixieColors.surface,
                            child: const Icon(
                              Icons.movie_outlined,
                              color: FlixieColors.medium,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: payload.posterUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: FlixieColors.surface,
                              child: const Icon(
                                Icons.movie_outlined,
                                color: FlixieColors.medium,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'REPLYING TO @${payload.username.toUpperCase()}’S ${payload.activityLabel.toUpperCase()}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .72),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.05,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        payload.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                        ),
                      ),
                      if (payload.rating != null || recommendation != null) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 8,
                          runSpacing: 3,
                          children: [
                            if (payload.rating != null)
                              Text(
                                '★ ${payload.rating!.toStringAsFixed(payload.rating! % 1 == 0 ? 0 : 1)}/10',
                                style: const TextStyle(
                                  color: Color(0xFFFFC84A),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            if (recommendation != null)
                              Text(
                                '${recommendation ? '👍' : '👎'} ${recommendation ? 'Recommends' : 'Doesn’t recommend'}',
                                style: TextStyle(
                                  color: recommendation
                                      ? const Color(0xFF00E6A8)
                                      : const Color(0xFFFF7E8A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (payload.reviewTitle?.isNotEmpty == true) ...[
                        const SizedBox(height: 7),
                        Text(
                          payload.reviewTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (payload.reviewBody?.isNotEmpty == true) ...[
                        const SizedBox(height: 3),
                        Text(
                          payload.reviewBody!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: .76),
                            fontSize: 11.5,
                            height: 1.25,
                          ),
                        ),
                      ],
                      if (payload.containsSpoilers) ...[
                        const SizedBox(height: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4A3417),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: const Text(
                            '⚠ CONTAINS SPOILERS',
                            style: TextStyle(
                              color: Color(0xFFFFC84A),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        '↗  $actionLabel',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMovieShareCard(BuildContext context, MovieSharePayload payload) {
    final cardColor = isMe
        ? Colors.white.withValues(alpha: 0.14)
        : FlixieColors.tabBarBackgroundFocused.withValues(alpha: 0.9);
    final borderColor = isMe
        ? Colors.white.withValues(alpha: 0.22)
        : FlixieColors.primary.withValues(alpha: 0.32);
    final promptColor = isMe ? Colors.white : FlixieColors.light;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (payload.prompt.isNotEmpty) ...[
          Text(
            payload.prompt,
            style: TextStyle(color: promptColor, fontSize: 14.5, height: 1.25),
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          onTap: () => _openLink(context, payload.link),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 52,
                    height: 78,
                    child: payload.posterUrl.isEmpty
                        ? Container(
                            color: FlixieColors.tabBarBackground,
                            child: const Icon(
                              Icons.movie_outlined,
                              color: FlixieColors.medium,
                              size: 22,
                            ),
                          )
                        : CachedNetworkImage(
                            imageUrl: payload.posterUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: FlixieColors.tabBarBackground,
                              child: const Icon(
                                Icons.movie_outlined,
                                color: FlixieColors.medium,
                                size: 22,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        payload.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 13,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.96)
                                : FlixieColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Open movie',
                            style: TextStyle(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.96)
                                  : FlixieColors.primary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _firstLink(String text) {
    final match = RegExp(r'(flixie://[\S]+|https?://[\S]+)').firstMatch(text);
    return match?.group(0);
  }

  String _labelForLink(String rawLink) {
    if (rawLink.startsWith('flixie://movies/') ||
        rawLink.startsWith('flixie:///movies/')) {
      return 'Open movie in Flixie';
    }
    if (rawLink.startsWith('flixie://shows/') ||
        rawLink.startsWith('flixie:///shows/')) {
      return 'Open show in Flixie';
    }
    return 'Open link';
  }

  Future<void> _openLink(BuildContext context, String rawLink) async {
    final uri = Uri.tryParse(rawLink);
    if (uri == null) return;

    if (uri.scheme == 'flixie') {
      String? routePath;

      // New format: flixie://movies/<id>?source=share
      if (uri.host == 'movies' && uri.pathSegments.isNotEmpty) {
        routePath = movieDetailPath(
          uri.pathSegments.first,
          source: DetailSource.sharedLink,
        );
      }

      if (uri.host == 'shows' && uri.pathSegments.isNotEmpty) {
        routePath = showDetailPath(
          uri.pathSegments.first,
          source: DetailSource.sharedLink,
        );
      }

      // Legacy format: flixie:///movies/<id>?source=share
      if (routePath == null && uri.path.startsWith('/movies/')) {
        final id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
        if (id != null) {
          routePath = movieDetailPath(
            id,
            source: DetailSource.sharedLink,
          );
        }
      }

      if (routePath == null && uri.path.startsWith('/shows/')) {
        final id = uri.pathSegments.length > 1 ? uri.pathSegments[1] : null;
        if (id != null) {
          routePath = showDetailPath(
            id,
            source: DetailSource.sharedLink,
          );
        }
      }

      if (routePath != null) {
        context.push(routePath);
        return;
      }
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
