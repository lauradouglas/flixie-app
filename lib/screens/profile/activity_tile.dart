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
  const ActivityTile({
    super.key,
    required this.item,
    this.compact = false,
    this.showMoviePreview = true,
  });

  final ActivityListItem item;
  final bool compact;
  final bool showMoviePreview;

  static const String _posterBase = 'https://image.tmdb.org/t/p/w342';

  Color get _accentColor {
    switch (item.type) {
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        return FlixieColors.success;
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return FlixieColors.warning;
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
    final username = item.username.trim();
    if (username.isNotEmpty) return username;
    final full = '${item.firstName} ${item.lastName}'.trim();
    if (full.isNotEmpty) return full;
    return 'Friend';
  }

  String _actionVerb() {
    switch (item.type) {
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return 'added to watchlist';
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
        return 'added to favorites';
      case ActivityListType.watchRequest:
      case ActivityListType.watchRequestAccepted:
      case ActivityListType.watchRequestSent:
        return 'shared';
      case ActivityListType.unknown:
        return 'activity on';
    }
  }

  String _statusLabel() {
    switch (item.type) {
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return 'Watchlist';
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        return 'Watched';
      case ActivityListType.movieRating:
      case ActivityListType.showRating:
        return 'Rated';
      case ActivityListType.movieReview:
      case ActivityListType.showReview:
        return 'Review';
      case ActivityListType.favoriteMovie:
      case ActivityListType.favoriteShow:
      case ActivityListType.favoritePerson:
        return 'Favorite';
      case ActivityListType.watchRequest:
      case ActivityListType.watchRequestAccepted:
      case ActivityListType.watchRequestSent:
        return 'Request';
      case ActivityListType.unknown:
        return 'Activity';
    }
  }

  Widget _buildAvatar() {
    final initial = _displayName().substring(0, 1).toUpperCase();
    return CircleAvatar(
      radius: compact ? 18 : 20,
      backgroundColor: FlixieColors.primary.withValues(alpha: 0.22),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String? _contextBadgeText(String? currentUserId) {
    if (currentUserId != item.userId || item.userId.isEmpty) return null;
    switch (item.type) {
      case ActivityListType.movieWatchlist:
      case ActivityListType.showWatchlist:
        return 'In your watchlist';
      case ActivityListType.favoriteMovie:
      case ActivityListType.favoriteShow:
      case ActivityListType.favoritePerson:
        return 'One of your favorites';
      case ActivityListType.movieWatched:
      case ActivityListType.showWatched:
        return null;
      case ActivityListType.movieRating:
      case ActivityListType.showRating:
        if (item.mediaRating != null) {
          return 'You rated this ${item.mediaRating!.toStringAsFixed(1)}/10';
        }
        return 'You rated this';
      case ActivityListType.movieReview:
      case ActivityListType.showReview:
        return 'You reviewed this';
      case ActivityListType.watchRequest:
      case ActivityListType.watchRequestAccepted:
      case ActivityListType.watchRequestSent:
      case ActivityListType.unknown:
        return null;
    }
  }

  String _activitySubject(String displayName, String? currentUserId) {
    if (currentUserId == item.userId && item.userId.isNotEmpty) return 'You';
    return displayName;
  }

  Widget _buildChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  void _openReviewSheet(
      BuildContext context, Review review, String? currentUserId) {
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

  bool _shouldShowUsername(String displayName, String username) {
    return username.isNotEmpty &&
        username.toLowerCase() != displayName.toLowerCase();
  }

  String? _mediaRoute() {
    final isPerson = item.type == ActivityListType.favoritePerson;
    if (isPerson && item.personId != null) return '/people/${item.personId}';
    if (item.movieId != null) return '/movies/${item.movieId}';
    if (item.showId != null) return '/shows/${item.showId}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider?>()?.dbUser?.id;
    final displayName = _displayName();
    final activitySubject = _activitySubject(displayName, currentUserId);
    final username = item.username.trim();
    final title = item.mediaTitle ?? 'something';
    final dateStr = _formatDate(item.timestamp);
    final notes = (item.notes ?? '').trim();
    final isPerson = item.type == ActivityListType.favoritePerson;
    final mediaRoute = _mediaRoute();
    final isReview = item.type == ActivityListType.movieReview ||
        item.type == ActivityListType.showReview;
    final rawPoster = item.mediaPosterPath;
    final posterUrl = rawPoster == null || rawPoster.isEmpty
        ? null
        : rawPoster.startsWith('http')
            ? rawPoster
            : '$_posterBase$rawPoster';
    final contextText = _contextBadgeText(currentUserId);

    final tile = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: FlixieColors.surface.withValues(alpha: 0.92),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              FlixieColors.surfaceElevated.withValues(alpha: 0.7),
              FlixieColors.surface.withValues(alpha: 0.96),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: FlixieColors.primary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(compact ? 10 : 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: item.userId.isEmpty
                        ? null
                        : () => context.push('/friends/${item.userId}'),
                    child: _buildAvatar(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: item.userId.isEmpty
                          ? null
                          : () => context.push('/friends/${item.userId}'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: compact ? 14 : 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_shouldShowUsername(displayName, username)) ...[
                            const SizedBox(height: 1),
                            Text(
                              '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateStr,
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: FlixieColors.light,
                    fontSize: compact ? 13 : 14,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                  children: [
                    TextSpan(text: '$activitySubject ${_actionVerb()} '),
                    TextSpan(
                      text: title,
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (showMoviePreview && !isPerson) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: mediaRoute != null ? () => context.push(mediaRoute) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: compact ? 72 : 86,
                          height: compact ? 96 : 114,
                          child: posterUrl == null
                              ? Container(
                                  color: FlixieColors.surfaceElevated,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.movie_outlined,
                                    color: FlixieColors.light,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: FlixieColors.surfaceElevated,
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.movie_outlined,
                                      color: FlixieColors.light,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: compact ? 14 : 18,
                                fontWeight: FontWeight.w700,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildChip(
                                  icon: Icons.local_activity_outlined,
                                  label: _statusLabel(),
                                  color: _accentColor,
                                ),
                                if (item.mediaRating != null)
                                  _buildChip(
                                    icon: Icons.star_rounded,
                                    label: '${item.mediaRating!.toStringAsFixed(1)}/10',
                                    color: FlixieColors.tertiary,
                                  ),
                              ],
                            ),
                            if (notes.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 7),
                                decoration: BoxDecoration(
                                  color: FlixieColors.surface.withValues(alpha: 0.8),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.08),
                                  ),
                                ),
                                child: Text(
                                  notes,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: FlixieColors.light,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (notes.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  notes,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontSize: 12,
                  ),
                ),
              ],
              if (contextText != null) ...[
                const SizedBox(height: 10),
                _buildChip(
                  icon: Icons.person_outline_rounded,
                  label: contextText,
                  color: FlixieColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    if (isReview && item.reviewData != null) {
      return GestureDetector(
        onTap: () => _openReviewSheet(context, item.reviewData!, currentUserId),
        child: tile,
      );
    }

    return tile;
  }
}
