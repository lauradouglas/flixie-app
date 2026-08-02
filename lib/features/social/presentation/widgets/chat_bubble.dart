import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
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

  @override
  Widget build(BuildContext context) {
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
                child: Text(
                  senderUsername,
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
                      maxWidth: MediaQuery.of(context).size.width * 0.62,
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
    final movieShare = _parseMovieSharePayload(message);
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

  Widget _buildMovieShareCard(
      BuildContext context, _MovieSharePayload payload) {
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

  _MovieSharePayload? _parseMovieSharePayload(String text) {
    final match = RegExp(
      r'\[FLIXIE_MOVIE_SHARE\]([\s\S]*?)\[/FLIXIE_MOVIE_SHARE\]',
      multiLine: true,
    ).firstMatch(text);
    if (match == null) return null;

    final block = match.group(1) ?? '';
    final data = <String, String>{};
    for (final rawLine in block.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final separator = line.indexOf('=');
      if (separator <= 0) continue;
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      data[key] = Uri.decodeComponent(value);
    }

    final title = data['title']?.trim() ?? '';
    final link = data['link']?.trim() ?? '';
    if (title.isEmpty || link.isEmpty) return null;

    return _MovieSharePayload(
      title: title,
      link: link,
      posterUrl: data['poster']?.trim() ?? '',
      prompt: data['message']?.trim() ?? '',
    );
  }

  String _labelForLink(String rawLink) {
    if (rawLink.startsWith('flixie://movies/') ||
        rawLink.startsWith('flixie:///movies/')) {
      return 'Open movie in Flixie';
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
        routePath = '/movies/${uri.pathSegments.first}';
      }

      // Legacy format: flixie:///movies/<id>?source=share
      if (routePath == null && uri.path.startsWith('/movies/')) {
        routePath = uri.path;
      }

      if (routePath != null) {
        final query = uri.query.isEmpty ? '' : '?${uri.query}';
        context.push('$routePath$query');
        return;
      }
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _MovieSharePayload {
  const _MovieSharePayload({
    required this.title,
    required this.link,
    required this.posterUrl,
    required this.prompt,
  });

  final String title;
  final String link;
  final String posterUrl;
  final String prompt;
}
