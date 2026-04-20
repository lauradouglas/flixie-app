import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/activity_list_item.dart';
import '../../models/review.dart';
import '../../theme/app_theme.dart';
import '../movie_detail/review_card.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.item});

  final ActivityListItem item;

  static const String _posterBase = 'https://image.tmdb.org/t/p/w185';

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
      case ActivityListType.movieRating:
      case ActivityListType.showRating:
        return FlixieColors.tertiary;
      case ActivityListType.movieReview:
      case ActivityListType.showReview:
        return FlixieColors.secondary;
      case ActivityListType.watchRequestSent:
      case ActivityListType.watchRequestAccepted:
      case ActivityListType.watchRequest:
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
      case ActivityListType.movieRating:
      case ActivityListType.showRating:
        return Icons.star_rounded;
      case ActivityListType.movieReview:
      case ActivityListType.showReview:
        return Icons.rate_review_outlined;
      case ActivityListType.watchRequestSent:
        return Icons.send_outlined;
      case ActivityListType.watchRequestAccepted:
        return Icons.people_outline;
      case ActivityListType.watchRequest:
        return Icons.movie_filter_outlined;
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
      case ActivityListType.movieRating:
        final r = item.mediaRating;
        return r != null
            ? 'Rated ${r.toStringAsFixed(0)}/10'
            : 'Rated this movie';
      case ActivityListType.showRating:
        final sr = item.mediaRating;
        return sr != null
            ? 'Rated ${sr.toStringAsFixed(0)}/10'
            : 'Rated this show';
      case ActivityListType.movieReview:
        final mr = item.mediaRating;
        return mr != null
            ? 'Reviewed · ${mr.toStringAsFixed(0)}/10'
            : 'Reviewed this movie';
      case ActivityListType.showReview:
        final srev = item.mediaRating;
        return srev != null
            ? 'Reviewed · ${srev.toStringAsFixed(0)}/10'
            : 'Reviewed this show';
      case ActivityListType.watchRequestSent:
        return 'Sent a watch request';
      case ActivityListType.watchRequestAccepted:
        return 'Accepted a watch request';
      case ActivityListType.watchRequest:
        return 'Requested a group watch';
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

  Widget _buildTitle(BuildContext context) {
    final title = item.mediaTitle;
    final bool isPerson = item.type == ActivityListType.favoritePerson;
    final int? navId = isPerson ? item.personId : item.movieId;
    final bool canNavigate = navId != null &&
        (item.type == ActivityListType.movieWatched ||
            item.type == ActivityListType.movieWatchlist ||
            item.type == ActivityListType.favoriteMovie ||
            item.type == ActivityListType.movieRating ||
            item.type == ActivityListType.favoritePerson);

    if (title == null) return const SizedBox.shrink();

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        text: title,
        style: TextStyle(
          color: FlixieColors.light,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          decoration: canNavigate ? TextDecoration.none : null,
        ),
        recognizer: canNavigate
            ? (TapGestureRecognizer()
              ..onTap = () =>
                  context.push(isPerson ? '/people/$navId' : '/movies/$navId'))
            : null,
      ),
    );
  }

  List<Widget> _buildRecommendBadge(bool recommended) {
    return [
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: (recommended ? FlixieColors.success : Colors.redAccent)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (recommended ? FlixieColors.success : Colors.redAccent)
                .withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              recommended ? Icons.thumb_up_outlined : Icons.thumb_down_outlined,
              size: 11,
              color: recommended ? FlixieColors.success : Colors.redAccent,
            ),
            const SizedBox(width: 3),
            Text(
              recommended ? 'Recommends' : 'Not recommended',
              style: TextStyle(
                color: recommended ? FlixieColors.success : Colors.redAccent,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  void _openReviewSheet(BuildContext context, Review review) {
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FlixieColors.medium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ReviewCard(
              review: review,
              currentUserId: currentUserId,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatDate(item.timestamp).toUpperCase();
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    final isCurrentUser = item.userId == currentUserId;
    final path = item.mediaPosterPath;
    final bool isPerson = item.type == ActivityListType.favoritePerson;
    final int? navId = isPerson ? item.personId : item.movieId;
    final bool isReview = item.type == ActivityListType.movieReview ||
        item.type == ActivityListType.showReview;
    final bool isWatched = item.type == ActivityListType.movieWatched ||
        item.type == ActivityListType.showWatched;
    final hasNotes = (item.notes ?? '').trim().isNotEmpty;
    final posterUrl = path != null ? '$_posterBase$path' : null;

    final tile = Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _accentColor, width: 3),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left: text content
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isCurrentUser)
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () =>
                                context.push('/friends/${item.userId}'),
                            child: Text(
                              item.username,
                              style: const TextStyle(
                                color: FlixieColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (item.firstName.isNotEmpty ||
                              item.lastName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${item.firstName})',
                              style: const TextStyle(
                                color: FlixieColors.medium,
                                fontWeight: FontWeight.w400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          const Spacer(),
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
                    if (!isCurrentUser) const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTitle(context)),
                        if (isCurrentUser)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              dateStr,
                              style: const TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
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
                        if (isReview && item.reviewData != null)
                          ..._buildRecommendBadge(item.reviewData!.recommended),
                      ],
                    ),
                    if (isWatched && hasNotes) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.notes!.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Right: poster full height, flush to edge
            GestureDetector(
              onTap: navId != null
                  ? () => context
                      .push(isPerson ? '/people/$navId' : '/movies/$navId')
                  : null,
              child: SizedBox(
                width: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    posterUrl != null
                        ? CachedNetworkImage(
                            imageUrl: posterUrl,
                            fit: BoxFit.cover,
                            fadeInDuration: Duration.zero,
                            fadeOutDuration: Duration.zero,
                            errorWidget: (_, __, ___) => Container(
                              color: FlixieColors.tabBarBorder,
                              child: Icon(
                                isPerson ? Icons.person : Icons.movie_outlined,
                                color: FlixieColors.medium,
                                size: 28,
                              ),
                            ),
                          )
                        : Container(
                            color: FlixieColors.tabBarBorder,
                            child: Icon(
                              isPerson ? Icons.person : Icons.movie_outlined,
                              color: FlixieColors.medium,
                              size: 28,
                            ),
                          ),
                    // Fade from card background into poster
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            FlixieColors.tabBarBackgroundFocused
                                .withValues(alpha: 0.6),
                            FlixieColors.tabBarBackgroundFocused
                                .withValues(alpha: 0.0),
                          ],
                          stops: const [0.0, 0.15],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ), // GestureDetector (poster)
          ],
        ),
      ),
    );
    if (isReview && item.reviewData != null) {
      return GestureDetector(
        onTap: () => _openReviewSheet(context, item.reviewData!),
        child: tile,
      );
    }
    return tile;
  }
}
