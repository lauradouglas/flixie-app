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
      return '${dt.day}/${dt.month}/${dt.year}';
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

  String _actionVerb() {
    switch (item.type) {
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return 'added';
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        return 'watched';
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

  Widget _buildAvatar() {
    final initial = _displayName().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: 22,
      backgroundColor: FlixieColors.primary.withValues(alpha: 0.25),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildRightVisual(
      {required bool isPerson, required String? posterUrl}) {
    if (posterUrl == null) {
      final icon = item.type == ActivityListType.movieWatchlist ||
              item.type == ActivityListType.showWatchlist
          ? Icons.bookmark_outline_rounded
          : (isPerson ? Icons.person_outline : Icons.movie_outlined);
      final iconColor = item.type == ActivityListType.movieWatchlist ||
              item.type == ActivityListType.showWatchlist
          ? const Color(0xFFFFD446)
          : FlixieColors.light;
      return Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF1C3558).withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 30),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 80,
        height: 80,
        child: CachedNetworkImage(
          imageUrl: posterUrl,
          fit: BoxFit.cover,
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
            ReviewCard(review: review, currentUserId: currentUserId),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _displayName();
    final title = item.mediaTitle ?? 'something';
    final dateStr = _formatDate(item.timestamp);
    final notes = (item.notes ?? '').trim();
    final isPerson = item.type == ActivityListType.favoritePerson;
    final navId = isPerson ? item.personId : item.movieId;
    final isReview = item.type == ActivityListType.movieReview ||
        item.type == ActivityListType.showReview;
    final posterUrl = item.mediaPosterPath != null
        ? '$_posterBase${item.mediaPosterPath}'
        : null;

    final tile = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFF10345A).withValues(alpha: 0.9),
            const Color(0xFF061D3B).withValues(alpha: 0.95),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 112,
            decoration: BoxDecoration(
              color: _accentColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () => context.push('/friends/${item.userId}'),
                    child: _buildAvatar(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$displayName ${_actionVerb()} $title',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateStr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            notes,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: navId != null
                        ? () => context.push(
                            isPerson ? '/people/$navId' : '/movies/$navId')
                        : null,
                    child: _buildRightVisual(
                        isPerson: isPerson, posterUrl: posterUrl),
                  ),
                ],
              ),
            ),
          ),
        ],
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
