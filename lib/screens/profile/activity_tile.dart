import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../models/activity_list_item.dart';
import '../../models/review.dart';
import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../movie_detail/review_card.dart';

class ActivityTile extends StatelessWidget {
  const ActivityTile({super.key, required this.item});

  final ActivityListItem item;

  static const String _posterBase = 'https://image.tmdb.org/t/p/w342';

  Color get _accentColor {
    switch (item.type) {
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        return const Color(0xFF30C48D);
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return const Color(0xFFFFD166);
      case ActivityListType.favoriteMovie:
      case ActivityListType.favoriteShow:
      case ActivityListType.favoritePerson:
        return Colors.redAccent;
      case ActivityListType.movieRating:
      case ActivityListType.showRating:
        return FlixieColors.primary;
      case ActivityListType.movieReview:
      case ActivityListType.showReview:
        return FlixieColors.secondary;
      case ActivityListType.watchRequestSent:
      case ActivityListType.watchRequestAccepted:
      case ActivityListType.watchRequest:
        return FlixieColors.tertiary;
      case ActivityListType.unknown:
        return FlixieColors.medium;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
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

  String _displayName() {
    final full = '${item.firstName} ${item.lastName}'.trim();
    if (full.isNotEmpty) return full;
    if (item.username.trim().isNotEmpty) return item.username.trim();
    return 'Friend';
  }

  String _leadingText() {
    switch (item.type) {
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return 'added';
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        final notes = (item.notes ?? '').toLowerCase();
        return notes.contains('rewatch') ? 'rewatched' : 'watched';
      case ActivityListType.movieRating:
      case ActivityListType.showRating:
        return 'rated';
      case ActivityListType.movieReview:
      case ActivityListType.showReview:
        return 'reviewed';
      case ActivityListType.favoriteMovie:
      case ActivityListType.favoriteShow:
      case ActivityListType.favoritePerson:
        return 'favorited';
      case ActivityListType.watchRequest:
      case ActivityListType.watchRequestAccepted:
      case ActivityListType.watchRequestSent:
        return 'shared';
      case ActivityListType.unknown:
        return 'activity on';
    }
  }

  int _starCount() {
    final raw = item.mediaRating;
    if (raw == null) return 0;
    final outOfFive = (raw / 2).round();
    return outOfFive.clamp(0, 5);
  }

  Widget _buildAvatar() {
    final name = _displayName();
    final initial = name.substring(0, 1).toUpperCase();
    final colorSeed = item.username.hashCode.abs();
    final colors = [
      const Color(0xFF2D5BFF),
      const Color(0xFF8E4DFF),
      const Color(0xFF00A78E),
      const Color(0xFFDD5C2B),
      const Color(0xFFD6387A),
    ];
    final bg = colors[colorSeed % colors.length];

    return CircleAvatar(
      radius: 24,
      backgroundColor: bg.withValues(alpha: 0.35),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildRatingStars() {
    final count = _starCount();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (index) => Icon(
          index < count ? Icons.star_rounded : Icons.star_border_rounded,
          color: FlixieColors.primary,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildRightVisual(
      {required bool isPerson, required String? posterUrl}) {
    final bool isWatchlistType = item.type == ActivityListType.movieWatchlist ||
        item.type == ActivityListType.showWatchlist;

    if (posterUrl == null) {
      return Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          color: const Color(0xFF1C3558).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(
          isWatchlistType
              ? Icons.bookmark_outline_rounded
              : (isPerson ? Icons.person_outline : Icons.movie_outlined),
          color: isWatchlistType ? const Color(0xFFFFD446) : FlixieColors.light,
          size: 32,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 84,
        height: 84,
        child: CachedNetworkImage(
          imageUrl: posterUrl,
          fit: BoxFit.cover,
          fadeInDuration: Duration.zero,
          fadeOutDuration: Duration.zero,
          errorWidget: (_, __, ___) => Container(
            color: const Color(0xFF1C3558),
            child: Icon(
              isPerson ? Icons.person_outline : Icons.movie_outlined,
              color: FlixieColors.light,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeadline(
      BuildContext context, String displayName, String title) {
    final isRating = item.type == ActivityListType.movieRating ||
        item.type == ActivityListType.showRating;

    if (isRating) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          Text(
            '$displayName rated',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          _buildRatingStars(),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
        ],
      );
    }

    final verb = _leadingText();
    return Text(
      '$displayName $verb $title',
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.18,
      ),
    );
  }

  String? _metaLine() {
    if (item.type == ActivityListType.movieWatchlist ||
        item.type == ActivityListType.showWatchlist) {
      return null;
    }

    if ((item.notes ?? '').trim().isNotEmpty) {
      return item.notes!.trim();
    }

    if (item.type == ActivityListType.movieWatched ||
        item.type == ActivityListType.showWatched) {
      return 'Rewatched';
    }

    if (item.type == ActivityListType.movieReview ||
        item.type == ActivityListType.showReview) {
      return 'A cinematic masterpiece.';
    }

    return null;
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
    final dateStr = _formatDate(item.timestamp);
    final title = item.mediaTitle ?? 'something';
    final path = item.mediaPosterPath;
    final bool isPerson = item.type == ActivityListType.favoritePerson;
    final int? navId = isPerson ? item.personId : item.movieId;
    final bool isReview = item.type == ActivityListType.movieReview ||
        item.type == ActivityListType.showReview;
    final posterUrl = path != null ? '$_posterBase$path' : null;
    final displayName = _displayName();
    final meta = _metaLine();

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  const Color(0xFF10345A).withValues(alpha: 0.9),
                  const Color(0xFF061D3B).withValues(alpha: 0.95),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => context.push('/friends/${item.userId}'),
                  child: _buildAvatar(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeadline(context, displayName, title),
                      const SizedBox(height: 6),
                      Text(
                        dateStr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (meta != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          meta,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.type == ActivityListType.movieWatched ||
                                    item.type == ActivityListType.showWatched
                                ? const Color(0xFF19BE7A)
                                : Colors.white.withValues(alpha: 0.78),
                            fontSize: 16,
                            fontWeight: item.type ==
                                        ActivityListType.movieWatched ||
                                    item.type == ActivityListType.showWatched
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: navId != null
                      ? () => context
                          .push(isPerson ? '/people/$navId' : '/movies/$navId')
                      : null,
                  child: _buildRightVisual(
                      isPerson: isPerson, posterUrl: posterUrl),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (isReview && item.reviewData != null) {
      return GestureDetector(
        onTap: () => _openReviewSheet(context, item.reviewData!),
        child: content,
      );
    }

    return content;
  }
}
