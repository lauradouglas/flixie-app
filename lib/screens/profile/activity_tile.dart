import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity_list_item.dart';
import '../../theme/app_theme.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.item});

  final ActivityListItem item;

  static const String _imgBase = 'https://image.tmdb.org/t/p/w92';

  Color get _accentColor {
    switch (item.type) {
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        return const Color(0xFF30C48D); // green
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return const Color(0xFFFFD166); // amber
      case ActivityListType.favoriteMovie:
      case ActivityListType.favoriteShow:
      case ActivityListType.favoritePerson:
        return Colors.redAccent;
      case ActivityListType.watchRequestSent:
      case ActivityListType.watchRequestAccepted:
        return FlixieColors.primary;
      case ActivityListType.unknown:
        return FlixieColors.medium;
    }
  }

  IconData get _icon {
    switch (item.type) {
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        return Icons.check_circle_outline;
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return Icons.bookmark_outline;
      case ActivityListType.favoriteMovie:
      case ActivityListType.favoriteShow:
      case ActivityListType.favoritePerson:
        return Icons.favorite_outline;
      case ActivityListType.watchRequestSent:
        return Icons.send_outlined;
      case ActivityListType.watchRequestAccepted:
        return Icons.people_outline;
      case ActivityListType.unknown:
        return Icons.history;
    }
  }

  String get _actionLabel {
    final rating = item.mediaRating;
    switch (item.type) {
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        if (rating != null) return 'Rated ${rating.toStringAsFixed(0)}/10';
        return 'Marked as watched';
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return 'Added to watchlist';
      case ActivityListType.favoriteMovie:
      case ActivityListType.favoriteShow:
        return 'Added to favourite movies';
      case ActivityListType.favoritePerson:
        return 'Added to favourite cast';
      case ActivityListType.watchRequestSent:
        return 'Sent a watch request';
      case ActivityListType.watchRequestAccepted:
        return 'Accepted a watch request';
      case ActivityListType.unknown:
        return 'Activity';
    }
  }

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
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  Widget _buildThumbnail() {
    final path = item.mediaPosterPath;
    final bool isPerson = item.type == ActivityListType.favoritePerson;
    final url = path != null ? '$_imgBase$path' : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 60,
        height: 80,
        child: url != null
            ? CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _fallbackThumb(isPerson),
              )
            : _fallbackThumb(isPerson),
      ),
    );
  }

  Widget _fallbackThumb(bool isPerson) {
    return Container(
      color: FlixieColors.tabBarBorder,
      child: Icon(
        isPerson ? Icons.person : Icons.movie_outlined,
        color: FlixieColors.medium,
        size: 28,
      ),
    );
  }

  Widget _buildTitle(BuildContext context) {
    final title = item.mediaTitle;
    final bool isPerson = item.type == ActivityListType.favoritePerson;
    final int? navId = isPerson ? item.personId : item.movieId;
    final bool canNavigate = navId != null &&
        (item.type == ActivityListType.movieWatched ||
            item.type == ActivityListType.movieWatchlist ||
            item.type == ActivityListType.favoriteMovie ||
            item.type == ActivityListType.favoritePerson);

    if (title == null) return const SizedBox.shrink();

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: canNavigate ? FlixieColors.primary : FlixieColors.light,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
        recognizer: canNavigate
            ? (TapGestureRecognizer()
              ..onTap = () =>
                  context.push(isPerson ? '/people/$navId' : '/movies/$navId'))
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(item.createdAt).toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _accentColor, width: 3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildThumbnail(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildTitle(context)),
                      const SizedBox(width: 8),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(_icon, color: _accentColor, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        _actionLabel,
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
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
    );
  }
}
