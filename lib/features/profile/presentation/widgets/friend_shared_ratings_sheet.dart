import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

import '../controllers/friend_profile_controller.dart';

void showFriendSharedRatings(BuildContext context,
    {required FriendProfileController controller}) {
  final friendName = controller.user?.username ?? 'Friend';
  final generation = controller.generation, viewer = controller.auth.dbUser?.id;
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: context.colors.surface,
    builder: (sheetContext) => ListenableBuilder(
      listenable: controller,
      builder: (_, __) {
        if (!controller.owns(generation, viewer)) {
          return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('This profile changed. Close and reopen.'));
        }
        return ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * .8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
                child: Row(children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('You both rated',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: context.colors.white)),
                        const SizedBox(height: 4),
                        Text(
                            '${controller.sharedRatings.length} films in common · Scores out of 10',
                            style: TextStyle(
                                fontSize: 12, color: context.colors.medium)),
                      ])),
                  IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close)),
                ])),
            Flexible(
                child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              itemCount: controller.sharedRatings.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: context.colors.tabBarBorder),
              itemBuilder: (_, index) {
                final rating = controller.sharedRatings[index];
                final mine = controller.myRatingValues[rating.movieId]!;
                final path = rating.movie?.posterPath;
                return InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    if (context.mounted &&
                        controller.owns(generation, viewer)) {
                      context.push(movieDetailPath(rating.movieId));
                    }
                  },
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            ClipRRect(
                                borderRadius: BorderRadius.circular(7),
                                child: SizedBox(
                                    width: 48,
                                    height: 72,
                                    child: path == null
                                        ? ColoredBox(
                                            color:
                                                context.colors.surfaceElevated,
                                            child: const Icon(
                                                Icons.movie_outlined))
                                        : CachedNetworkImage(
                                            imageUrl: path.startsWith('http')
                                                ? path
                                                : 'https://image.tmdb.org/t/p/w185$path',
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                const Icon(
                                                    Icons.movie_outlined),
                                          ))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(rating.movie?.title ?? 'Movie',
                                      style: TextStyle(
                                          color: context.colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15)),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 8, runSpacing: 6, children: [
                                    _ComparisonScore(
                                        label: 'You', score: mine, isYou: true),
                                    _ComparisonScore(
                                        label: friendName,
                                        score: rating.rating),
                                  ]),
                                  if (mine == rating.rating) ...[
                                    const SizedBox(height: 8),
                                    Row(children: [
                                      Icon(Icons.auto_awesome_rounded,
                                          size: 14,
                                          color: context.colors.primaryText),
                                      const SizedBox(width: 5),
                                      Flexible(
                                          child: Text('Taste twins',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: context
                                                      .colors.primaryText))),
                                    ]),
                                  ],
                                ])),
                            const SizedBox(width: 4),
                            Icon(Icons.chevron_right_rounded,
                                size: 18, color: context.colors.medium),
                          ])),
                );
              },
            )),
          ]),
        );
      },
    ),
  );
}

class _ComparisonScore extends StatelessWidget {
  const _ComparisonScore(
      {required this.label, required this.score, this.isYou = false});
  final bool isYou;
  final String label;
  final int score;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
            color: isYou
                ? context.colors.primaryText.withValues(alpha: .10)
                : const Color(0xFFFFAD66).withValues(alpha: .18),
            borderRadius: BorderRadius.circular(10)),
        child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '$label  ',
                  style: TextStyle(color: context.colors.light)),
              TextSpan(
                  text: '$score',
                  style: TextStyle(
                      color: context.colors.primaryText,
                      fontWeight: FontWeight.w800)),
            ]),
            style: const TextStyle(fontSize: 12)),
      );
}
