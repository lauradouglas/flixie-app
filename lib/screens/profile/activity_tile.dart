import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/activity_list_item.dart';
import '../../theme/app_theme.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.item});

  final ActivityListItem item;

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

  Color get _iconColor {
    switch (item.type) {
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        return Colors.green;
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return Colors.amber;
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

  Widget _buildLabel(BuildContext context) {
    final title = item.mediaTitle;
    final bool isPerson = item.type == ActivityListType.favoritePerson;
    final int? navId = isPerson ? item.personId : item.movieId;
    final bool canNavigate = navId != null &&
        (item.type == ActivityListType.movieWatched ||
            item.type == ActivityListType.movieWatchlist ||
            item.type == ActivityListType.favoriteMovie ||
            item.type == ActivityListType.favoritePerson);

    String prefix;
    String suffix;
    switch (item.type) {
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        prefix = 'Marked ';
        suffix = ' as watched';
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        prefix = 'Added ';
        suffix = ' to watchlist';
      case ActivityListType.favoriteMovie:
      case ActivityListType.favoriteShow:
      case ActivityListType.favoritePerson:
        prefix = 'Favourited ';
        suffix = '';
      case ActivityListType.watchRequestSent:
        return const Text('Sent a watch request',
            style: TextStyle(color: FlixieColors.light, fontSize: 13));
      case ActivityListType.watchRequestAccepted:
        return const Text('Accepted a watch request',
            style: TextStyle(color: FlixieColors.light, fontSize: 13));
      case ActivityListType.unknown:
        return const Text('Activity',
            style: TextStyle(color: FlixieColors.light, fontSize: 13));
    }

    if (title == null) {
      return Text(
        '$prefix${_fallbackNoun()}$suffix',
        style: const TextStyle(color: FlixieColors.light, fontSize: 13),
      );
    }

    final boldSpan = TextSpan(
      text: title,
      style: TextStyle(
        color: canNavigate ? FlixieColors.primary : FlixieColors.light,
        fontSize: 13,
        fontWeight: FontWeight.bold,
      ),
      recognizer: canNavigate
          ? (TapGestureRecognizer()
            ..onTap = () =>
                context.push(isPerson ? '/people/$navId' : '/movies/$navId'))
          : null,
    );

    return RichText(
      text: TextSpan(
        style: const TextStyle(color: FlixieColors.light, fontSize: 13),
        children: [
          TextSpan(text: prefix),
          boldSpan,
          TextSpan(text: suffix),
        ],
      ),
    );
  }

  String _fallbackNoun() {
    switch (item.type) {
      case ActivityListType.movieWatched:
      case ActivityListType.movieWatchlist:
      case ActivityListType.favoriteMovie:
        return 'a movie';
      case ActivityListType.showWatched:
      case ActivityListType.showWatchlist:
      case ActivityListType.favoriteShow:
        return 'a show';
      case ActivityListType.favoritePerson:
        return 'a person';
      default:
        return 'an item';
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: FlixieColors.medium.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_icon, color: _iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: _buildLabel(context)),
          const SizedBox(width: 8),
          Text(
            _formatDate(item.createdAt),
            style: const TextStyle(color: FlixieColors.medium, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
