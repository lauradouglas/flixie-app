import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/movie_friend_activity.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/social/data/community_service.dart';

class MovieFriendsRatingSummary extends StatelessWidget {
  const MovieFriendsRatingSummary(
      {super.key, required this.activities, required this.movieId});
  final List<MovieFriendActivity> activities;
  final int movieId;
  @override
  Widget build(BuildContext context) {
    final ratings = activities
        .where((a) => a.rating != null && a.rating! >= 1 && a.rating! <= 10)
        .toList();
    final hidden = hideMovieRatings(context, movieId);
    return Text(
        ratings.isEmpty
            ? '${activities.length} ${activities.length == 1 ? 'friend' : 'friends'} interacted'
            : '${ratings.length} ${ratings.length == 1 ? 'friend' : 'friends'} rated this${hidden ? '' : ' · ${(ratings.fold<int>(0, (sum, a) => sum + a.rating!) / ratings.length).toStringAsFixed(1)}/10 average'}',
        style: TextStyle(color: context.colors.medium, fontSize: 13));
  }
}

class MovieFriendOpinionRow extends StatelessWidget {
  const MovieFriendOpinionRow(
      {super.key,
      required this.activity,
      required this.movieId,
      required this.onTap});
  final MovieFriendActivity activity;
  final int movieId;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final count = (activity.watchCount ?? 0) > 0
        ? activity.watchCount!
        : activity.isRewatch
            ? 2
            : 1;
    return OpinionPanel(
        compact: true,
        onTap: onTap,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.all(4),
              child: ProfileAvatarView(
                fallbackColor: FlixieColors.primary,
                avatar: activity.avatar,
                profileBadges: activity.profileBadges,
                size: 42,
                fallbackText:
                    activity.username.isEmpty ? '?' : activity.username[0],
              )),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                LayoutBuilder(builder: (context, constraints) {
                  final name = Text(activity.username,
                      style: TextStyle(
                          color: context.colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700));
                  final score = OpinionRating(
                      movieId: movieId,
                      userId: activity.userId,
                      rating: activity.rating);
                  if (constraints.maxWidth < 240 ||
                      MediaQuery.textScalerOf(context).scale(15) > 20) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          name,
                          if (activity.rating != null) ...[
                            const SizedBox(height: 4),
                            score
                          ]
                        ]);
                  }
                  return Row(children: [
                    Expanded(child: name),
                    const SizedBox(width: 12),
                    score
                  ]);
                }),
                const SizedBox(height: 2),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      if (activity.watched)
                        _status(
                            context,
                            Icons.visibility_outlined,
                            'Watched $count ${count == 1 ? 'time' : 'times'}',
                            const Color(0xFF70A7FF),
                            count: '×$count'),
                      if (activity.recommended != null)
                        _status(
                            context,
                            activity.recommended!
                                ? Icons.thumb_up_rounded
                                : Icons.thumb_down_rounded,
                            activity.recommended!
                                ? 'Recommended'
                                : 'Not recommended',
                            activity.recommended!
                                ? context.colors.success
                                : context.colors.danger),
                      if (activity.favorited)
                        _status(context, Icons.favorite_rounded, 'Favourite',
                            context.colors.danger),
                      if (activity.onWatchlist)
                        _status(context, Icons.bookmark_rounded, 'In watchlist',
                            context.colors.warning),
                      if (activity.reviewed)
                        _status(context, Icons.rate_review_outlined, 'Reviewed',
                            context.colors.primaryText),
                    ])),
              ])),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              color: context.colors.primaryText, size: 20),
        ]));
  }

  Widget _status(BuildContext context, IconData icon, String label, Color color,
          {String? count}) =>
      Tooltip(
        message: label,
        child: Semantics(
          label: label,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.only(right: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 20),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: color, size: 19),
                if (count != null) ...[
                  const SizedBox(width: 4),
                  Text(count, style: TextStyle(color: color, fontSize: 13)),
                ],
              ]),
            ),
          ),
        ),
      );
}

class OpinionRating extends StatelessWidget {
  const OpinionRating(
      {super.key,
      required this.movieId,
      required this.userId,
      required this.rating});
  final int movieId;
  final String userId;
  final int? rating;
  @override
  Widget build(BuildContext context) {
    if (rating == null) return const SizedBox.shrink();
    final hidden = hideMovieRatings(context, movieId, ownerId: userId);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (!hidden) ...[
        Icon(Icons.star_rounded, size: 20, color: context.colors.warning),
        const SizedBox(width: 4)
      ],
      Text(hidden ? 'Rated' : '$rating/10',
          style: TextStyle(
              color: context.colors.warning,
              fontSize: 17,
              fontWeight: FontWeight.w700))
    ]);
  }
}

class OpinionPanel extends StatelessWidget {
  const OpinionPanel(
      {super.key,
      required this.child,
      required this.onTap,
      this.compact = false});
  final bool compact;
  final Widget child;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: compact ? 6 : 10),
      child: Material(
        color: context.colors.surface.withValues(alpha: .58),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.colors.tabBarBorder)),
        child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: 12, vertical: compact ? 8 : 12),
                child: child)),
      ));
}

class MovieFollowingOpinions extends StatefulWidget {
  const MovieFollowingOpinions(
      {super.key, required this.movieId, required this.viewerId, this.load});
  final int movieId;
  final String viewerId;
  final Future<CommunityPage> Function(String? cursor)? load;
  @override
  State<MovieFollowingOpinions> createState() => _MovieFollowingOpinionsState();
}

class _MovieFollowingOpinionsState extends State<MovieFollowingOpinions> {
  final _items = <ActivityListItem>[];
  String? _cursor;
  bool _loading = false, _failed = false, _expanded = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await (widget.load?.call(_cursor) ??
          const CommunityService()
              .followedMovieReviews(widget.movieId, cursor: _cursor));
      if (!mounted) return;
      setState(() {
        // Defensive title check also avoids unrelated content against an older API.
        final ids = _items.map((i) => i.id).toSet();
        _items.addAll(page.items.where((i) =>
            i.movieId == widget.movieId &&
            i.type == ActivityListType.movieReview &&
            ids.add(i.id)));
        _cursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('People you follow',
                  style: TextStyle(
                      color: context.colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700))),
          if (!_expanded && (_items.length > 3 || _cursor != null))
            TextButton(
                onPressed: () => setState(() => _expanded = true),
                child: const Text('View all'))
        ]),
        Text('Public ratings & reviews',
            style: TextStyle(color: context.colors.medium, fontSize: 13)),
        const SizedBox(height: 12),
        for (final item in _items.take(_expanded ? _items.length : 3))
          OpinionPanel(
              compact: true,
              onTap: () => context.push(
                  '/community/posts/${Uri.encodeComponent(item.userId)}/${item.type.value}/${Uri.encodeComponent(item.id)}'),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                    padding: const EdgeInsets.all(4),
                    child: ProfileAvatarView(
                        fallbackColor: FlixieColors.primary,
                        avatar: item.avatar,
                        profileBadges: item.profileBadges,
                        size: 42,
                        fallbackText:
                            item.username.isEmpty ? '?' : item.username[0])),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      LayoutBuilder(builder: (context, constraints) {
                        final name = Text(item.username,
                            style: TextStyle(
                                color: context.colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700));
                        final score = OpinionRating(
                            movieId: widget.movieId,
                            userId: item.userId,
                            rating: item.reviewData?.rating);
                        if (constraints.maxWidth < 240 ||
                            MediaQuery.textScalerOf(context).scale(15) > 20) {
                          return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                name,
                                const SizedBox(height: 2),
                                score
                              ]);
                        }
                        return Row(children: [
                          Expanded(child: name),
                          const SizedBox(width: 8),
                          score
                        ]);
                      }),
                      const SizedBox(height: 2),
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Text(
                                    item.reviewData?.containsSpoilers == true
                                        ? 'Review contains spoilers'
                                        : item.reviewData?.title ??
                                            'Shared a review',
                                    style: TextStyle(
                                        color: context.colors.light))),
                            if (item.recommended != null) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                  message: item.recommended!
                                      ? 'Recommended'
                                      : 'Not recommended',
                                  child: Icon(
                                      item.recommended!
                                          ? Icons.thumb_up_rounded
                                          : Icons.thumb_down_rounded,
                                      semanticLabel: item.recommended!
                                          ? 'Recommended'
                                          : 'Not recommended',
                                      size: 18,
                                      color: item.recommended!
                                          ? context.colors.success
                                          : context.colors.danger)),
                            ],
                            if (item.favorited) ...[
                              const SizedBox(width: 8),
                              Tooltip(
                                  message: 'Favourite',
                                  child: Icon(Icons.favorite_rounded,
                                      semanticLabel: 'Favourite',
                                      size: 18,
                                      color: context.colors.danger)),
                            ],
                          ]),
                    ])),
                Icon(Icons.chevron_right_rounded,
                    color: context.colors.primaryText),
              ])),
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(12),
              child: Center(child: CircularProgressIndicator())),
        if (_failed)
          TextButton(
              onPressed: _load,
              child: const Text('Couldn’t load followed reviews · Retry')),
        if (!_loading && !_failed && _items.isEmpty)
          Text('No public reviews from people you follow yet.',
              style: TextStyle(color: context.colors.medium)),
        if (_expanded && _cursor != null && !_loading && !_failed)
          TextButton(onPressed: _load, child: const Text('Load more reviews')),
      ]);
}
