import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/flixie_typography.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/models/friend_recommendation.dart';
import 'package:flixie_app/models/profile_avatar.dart';

class WatchlistFriendsViewing extends StatelessWidget {
  const WatchlistFriendsViewing(
      {super.key,
      required this.friends,
      required this.title,
      required this.movieId,
      this.isShow = false,
      this.loading = false,
      this.failed = false,
      this.onRetry});
  final int movieId;
  final List<FriendRecommendationItem> friends;
  final String title;
  final bool isShow, loading, failed;
  final VoidCallback? onRetry;

  Widget _avatar(FriendRecommendationItem friend) => SizedBox(
      width: 44,
      height: 44,
      child: Center(
          child: ProfileAvatarView(
              avatar: friend.avatar ??
                  (friend.avatarUrl?.isNotEmpty == true
                      ? ProfileAvatar(
                          id: 0,
                          key: friend.userId,
                          displayName: friend.username,
                          storagePath: '',
                          imageUrl: friend.avatarUrl)
                      : null),
              profileBadges: friend.profileBadges,
              fallbackText: friend.username.isEmpty
                  ? '?'
                  : friend.username.characters.first.toUpperCase(),
              fallbackColor: FlixieColors.primary,
              size: 32)));

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Loading friends…',
            style: TextStyle(color: context.colors.light, fontSize: 12)),
        const ContentPlaceholder(
            label: 'Loading friends', style: ContentPlaceholderStyle.compact),
      ]);
    }
    if (failed) {
      return TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Friends couldn’t load · Retry'));
    }
    final watched = friends.where((f) => f.watched).toList();
    final rated = friends
        .where((f) =>
            f.rating != null && f.ratingScope == (isShow ? 'show' : 'movie'))
        .toList();
    final average = rated.isEmpty
        ? null
        : rated.fold<double>(0, (sum, f) => sum + f.rating!) / rated.length;
    final summary =
        '${watched.length} ${watched.length == 1 ? 'friend' : 'friends'} watched';
    final scoresHidden = hideMovieRatings(context, movieId, isShow: isShow);
    final ratingLabel = scoresHidden
        ? 'Rate to see friends’ scores'
        : average == null
            ? 'No friends’ ratings yet'
            : 'Friends’ average ${average.toStringAsFixed(1)}/10 · ${rated.length} rated';
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: context.colors.background,
        builder: (sheetContext) => ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .85),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text('Friends who watched',
                            style: TextStyle(
                                fontFamily: FlixieTypography.fontFamily,
                                color: context.colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800))),
                    IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: Icon(Icons.close, color: context.colors.light)),
                  ]),
                  Text(
                      '$title · ${watched.length} watched · ${rated.length} rated',
                      style:
                          TextStyle(color: context.colors.light, fontSize: 13)),
                  const SizedBox(height: 20),
                  Divider(height: 1, color: context.colors.tabBarBorder),
                  if (friends.isEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text('No friends watched yet',
                            style: TextStyle(color: context.colors.light))),
                  for (final friend in friends) ...[
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: LayoutBuilder(builder: (context, constraints) {
                          final scope = friend.ratingScope.isEmpty
                              ? (isShow ? 'show' : 'movie')
                              : friend.ratingScope;
                          final scopeLabel =
                              '${scope[0].toUpperCase()}${scope.substring(1)} rating';
                          final state =
                              friend.watched ? 'Watched' : 'Not marked watched';
                          final details = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    friend.displayName?.trim().isNotEmpty ==
                                            true
                                        ? friend.displayName!
                                        : friend.username,
                                    style: TextStyle(
                                        color: context.colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 3),
                                Text(
                                    '$state · ${friend.rating == null ? 'Not rated yet' : scopeLabel}',
                                    style: TextStyle(
                                        color: context.colors.light,
                                        fontSize: 13)),
                              ]);
                          final rating = Text(
                              hideMovieRatings(context, movieId,
                                      isShow: isShow, ownerId: friend.userId)
                                  ? 'Hidden'
                                  : friend.rating == null
                                      ? '—'
                                      : '${friend.rating! == friend.rating!.roundToDouble() ? friend.rating!.toInt() : friend.rating}/10',
                              style: TextStyle(
                                  color: friend.rating == null
                                      ? context.colors.light
                                      : context.colors.warning,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800));
                          final stacked = constraints.maxWidth < 360 &&
                              MediaQuery.textScalerOf(context).scale(16) > 24;
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _avatar(friend),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: stacked
                                        ? Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                                details,
                                                const SizedBox(height: 6),
                                                rating
                                              ])
                                        : details),
                                if (!stacked) ...[
                                  const SizedBox(width: 12),
                                  rating
                                ],
                              ]);
                        })),
                    Divider(height: 1, color: context.colors.tabBarBorder),
                  ],
                  const SizedBox(height: 16),
                  Text(
                      average == null
                          ? 'No friends’ ratings yet'
                          : 'Friends’ average ${average.toStringAsFixed(1)}/10 · Based on ${rated.length} ${rated.length == 1 ? 'rating' : 'ratings'}',
                      style:
                          TextStyle(color: context.colors.light, fontSize: 13)),
                  if (isShow) ...[
                    const SizedBox(height: 8),
                    Text(
                        'Show-level ratings only. Season and episode ratings are separate. Watched means marked watched, not necessarily every episode completed.',
                        style: TextStyle(
                            color: context.colors.light, fontSize: 12)),
                  ],
                ]),
          ),
        ),
      ),
      child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(builder: (context, constraints) {
              final avatars =
                  Wrap(children: watched.take(3).map(_avatar).toList());
              final text = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(watched.isEmpty ? 'No friends watched yet' : summary,
                        style: TextStyle(
                            color: context.colors.white, fontSize: 13)),
                    Text(ratingLabel,
                        style: TextStyle(
                            color: context.colors.light, fontSize: 12)),
                  ]);
              if (constraints.maxWidth < 360 ||
                  MediaQuery.textScalerOf(context).scale(14) > 20) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [if (watched.isNotEmpty) avatars, text]);
              }
              return Row(children: [
                if (watched.isNotEmpty) ...[avatars, const SizedBox(width: 8)],
                Expanded(child: text),
                Icon(Icons.chevron_right, color: context.colors.light)
              ]);
            }),
          )),
    );
  }
}
