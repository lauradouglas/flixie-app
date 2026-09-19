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
    this.currentUserId,
    this.currentUsername,
    this.initials,
    this.profileBadges = const [],
    this.showSenderLabel = true,
    this.replyTo,
    this.onLongPress,
    this.onSenderTap,
  });

  final String? currentUserId;
  final String? currentUsername;
  final String message;
  final String senderUsername;
  final bool isMe;
  final DateTime sentAt;
  final ProfileAvatar? avatar;
  final String? initials;
  final List<String> profileBadges;
  final bool showSenderLabel;
  final String? replyTo;
  final VoidCallback? onLongPress;
  final VoidCallback? onSenderTap;

  @override
  Widget build(BuildContext context) {
    final hasRichContent = parseActivityReplyPayload(message) != null ||
        parseMovieSharePayload(message) != null;
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
                  style: TextStyle(
                    color: context.colors.medium,
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            if (hasRichContent)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment:
                      isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if (!isMe) ...[_senderAvatar(), const SizedBox(width: 9)],
                    Flexible(
                        child: GestureDetector(
                            onTap: onSenderTap,
                            child: Text(isMe ? 'You' : senderUsername,
                                textAlign:
                                    isMe ? TextAlign.right : TextAlign.left,
                                style: TextStyle(
                                    color: context.colors.primaryTint,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700)))),
                    if (isMe) ...[const SizedBox(width: 9), _senderAvatar()],
                  ],
                ),
              ),
            if (!hasRichContent && !isMe && showSenderLabel)
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
                              ? context.colors.medium
                              : context.colors.primaryTint,
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
                if (!hasRichContent && !isMe) ...[
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
                          (hasRichContent ? 0.86 : 0.62),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: hasRichContent
                          ? context.colors.surface
                          : isMe
                              ? FlixieColors.primary
                              : context.colors.surface,
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
                if (!hasRichContent) const SizedBox(width: 8),
                if (!hasRichContent)
                  Text(
                    _timeLabel(sentAt),
                    style: TextStyle(
                      color: context.colors.medium,
                      fontSize: 11,
                    ),
                  ),
              ],
            ),
            if (hasRichContent)
              Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_timeLabel(sentAt),
                      style: TextStyle(
                          color: context.colors.medium, fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Widget _senderAvatar() => ProfileAvatarView(
        avatar: avatar,
        fallbackText: initials?.isNotEmpty == true
            ? initials!
            : senderUsername.isNotEmpty
                ? senderUsername[0].toUpperCase()
                : '?',
        fallbackColor: FlixieColors.primary,
        size: 32,
        profileBadges: profileBadges,
      );

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
    final textColor = isMe ? Colors.white : context.colors.textPrimary;
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
    final isOwnActivity = payload.userId != null
        ? payload.userId == currentUserId
        : currentUsername?.trim().isNotEmpty == true &&
            payload.username.trim().toLowerCase() ==
                currentUsername!.trim().toLowerCase();
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(payload.title,
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 19,
                fontWeight: FontWeight.w800,
                height: 1.25)),
        if (payload.rating != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.star_rounded, color: context.colors.warning, size: 18),
            const SizedBox(width: 4),
            Flexible(
                child: Text(
                    '${payload.rating!.toStringAsFixed(payload.rating! % 1 == 0 ? 0 : 1)}/10',
                    style: TextStyle(
                        color: context.colors.warning,
                        fontSize: 14,
                        fontWeight: FontWeight.w700))),
          ]),
        ],
        if (payload.recommended != null) ...[
          const SizedBox(height: 5),
          Text(payload.recommended! ? 'Recommends' : 'Doesn’t recommend',
              style: TextStyle(
                  color: payload.recommended!
                      ? context.colors.success
                      : context.colors.danger,
                  fontSize: 13)),
        ],
      ],
    );
    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
          width: 64,
          height: 96,
          child: payload.posterUrl.isEmpty
              ? ColoredBox(
                  color: context.colors.surfaceElevated,
                  child:
                      Icon(Icons.movie_outlined, color: context.colors.medium))
              : CachedNetworkImage(
                  imageUrl: payload.posterUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => ColoredBox(
                      color: context.colors.surfaceElevated,
                      child: Icon(Icons.movie_outlined,
                          color: context.colors.medium)))),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.reply_rounded, size: 16, color: context.colors.medium),
          const SizedBox(width: 6),
          Expanded(
              child: Text(
                  isOwnActivity
                      ? 'Replied to your ${payload.activityLabel}'
                      : 'Replied to @${payload.username}’s ${payload.activityLabel}',
                  style:
                      TextStyle(color: context.colors.medium, fontSize: 12))),
        ]),
        const SizedBox(height: 12),
        InkWell(
          onTap: () => _openLink(context, payload.link),
          borderRadius: BorderRadius.circular(8),
          child: LayoutBuilder(builder: (context, constraints) {
            final stack = constraints.maxWidth < 220 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.5;
            return stack
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [poster, const SizedBox(height: 12), details])
                : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    poster,
                    const SizedBox(width: 14),
                    Expanded(child: details)
                  ]);
          }),
        ),
        if (payload.containsSpoilers) ...[
          const SizedBox(height: 10),
          Text('Contains spoilers',
              style: TextStyle(color: context.colors.warning, fontSize: 13)),
        ],
        if (!payload.containsSpoilers &&
            payload.reviewTitle?.isNotEmpty == true) ...[
          const SizedBox(height: 10),
          Text(payload.reviewTitle!,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontWeight: FontWeight.w700)),
        ],
        if (!payload.containsSpoilers &&
            payload.reviewBody?.isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text(payload.reviewBody!,
              style: TextStyle(
                  color: context.colors.light, fontSize: 14, height: 1.4)),
        ],
        if (payload.listName?.isNotEmpty == true)
          TextButton.icon(
              onPressed: payload.listLink == null
                  ? null
                  : () => _openLink(context, payload.listLink!),
              icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
              label: Text('Added to ${payload.listName}'),
              style:
                  TextButton.styleFrom(foregroundColor: context.colors.light)),
        if (payload.message.isNotEmpty) ...[
          Divider(color: context.colors.tabBarBorder, height: 20),
          Text(payload.message,
              style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 16,
                  height: 1.4)),
        ],
      ],
    );
  }

  Widget _buildMovieShareCard(BuildContext context, MovieSharePayload payload) {
    final foreground = isMe ? Colors.white : context.colors.textPrimary;
    final secondary = isMe ? Colors.white : context.colors.primaryTint;
    final poster = ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 68,
        height: 102,
        child: payload.posterUrl.isEmpty
            ? ColoredBox(
                color: context.colors.tabBarBackground,
                child: Icon(Icons.movie_outlined, color: context.colors.light))
            : CachedNetworkImage(
                imageUrl: payload.posterUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => ColoredBox(
                    color: context.colors.tabBarBackground,
                    child: Icon(Icons.movie_outlined,
                        color: context.colors.light)),
              ),
      ),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(payload.title,
            style: TextStyle(
                color: foreground,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.25)),
        const SizedBox(height: 10),
        Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            children: [
              Text(payload.isShow ? 'View show' : 'View movie',
                  style: TextStyle(
                      color: secondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              Icon(Icons.chevron_right_rounded, color: secondary, size: 18),
            ]),
      ],
    );
    return InkWell(
      onTap: () => _openLink(context, payload.link),
      borderRadius: BorderRadius.circular(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          LayoutBuilder(builder: (context, constraints) {
            final stack = constraints.maxWidth < 220 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.5;
            if (stack) {
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [poster, const SizedBox(height: 12), details]);
            }
            return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  poster,
                  const SizedBox(width: 14),
                  Flexible(child: details)
                ]);
          }),
          if (payload.prompt.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(payload.prompt,
                style: TextStyle(
                    color: isMe ? Colors.white : context.colors.light,
                    fontSize: 14.5,
                    height: 1.4)),
          ],
        ],
      ),
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

      if (uri.host == 'lists' && uri.pathSegments.isNotEmpty) {
        final listId = uri.pathSegments.first;
        final owner = uri.queryParameters['owner'];
        final name = uri.queryParameters['name'] ?? 'List';
        if (owner != null && owner.isNotEmpty) {
          routePath =
              '/movie-lists/$listId?name=${Uri.encodeQueryComponent(name)}&owner=${Uri.encodeQueryComponent(owner)}&isOwner=false&canEdit=false';
        }
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
