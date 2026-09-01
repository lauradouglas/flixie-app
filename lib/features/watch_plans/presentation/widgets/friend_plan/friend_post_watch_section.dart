import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/models/watch_request.dart';

class FriendPostWatchSection extends StatelessWidget {
  const FriendPostWatchSection({
    super.key,
    required this.request,
    required this.myUserId,
    required this.other,
    required this.movie,
    required this.posterUrl,
    required this.scheduledLabel,
    required this.location,
    required this.onConfirmWatched,
    required this.onNotThisTime,
    required this.onSuggestDifferentTime,
  });

  final WatchRequest request;
  final String myUserId;
  final WatchRequestUser? other;
  final WatchRequestMovieDetails? movie;
  final String? posterUrl;
  final String scheduledLabel;
  final String? location;
  final VoidCallback onConfirmWatched;
  final VoidCallback onNotThisTime;
  final VoidCallback onSuggestDifferentTime;

  @override
  Widget build(BuildContext context) {
    final entries = request.watchConfirmations;
    final mine = entries.where((entry) => entry.userId == myUserId).firstOrNull;
    final otherEntry =
        entries.where((entry) => entry.userId != myUserId).firstOrNull;
    final myResolved = mine != null;
    final state = WatchPlanDisplayState.postWatchState(request, myUserId);
    if (state == FriendPostWatchState.recap) {
      return _buildCompletedFriendRecap(context,
          other: other, movie: movie, posterUrl: posterUrl);
    }
    final scheduled = scheduledLabel;
    final title = movie?.title ?? request.movie?.title ?? 'Watch plan';
    final heading = switch (state) {
      FriendPostWatchState.nobodyLogged => 'Did the plan happen?',
      FriendPostWatchState.waitingForMe => 'Your turn',
      FriendPostWatchState.waitingForOthers =>
        'Waiting for ${other?.username ?? 'your friend'}',
      FriendPostWatchState.recap => 'Watch recap',
    };
    final copy = switch (state) {
      FriendPostWatchState.nobodyLogged =>
        'Log your viewing to add your rating and recommendation. Everyone responds separately.',
      FriendPostWatchState.waitingForMe =>
        '${other?.username ?? 'Your friend'} logged their watch. Add yours to unlock the shared recap and compare ratings.',
      FriendPostWatchState.waitingForOthers =>
        'Your watch is logged. Their rating stays hidden until they add their own take.',
      FriendPostWatchState.recap => '',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PostWatchSurface(
            child: Row(children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                  width: 72,
                  height: 108,
                  child: posterUrl == null
                      ? const _PostWatchPosterPlaceholder()
                      : CachedNetworkImage(
                          imageUrl: posterUrl!, fit: BoxFit.cover))),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    state == FriendPostWatchState.waitingForMe
                        ? '${other?.username ?? 'Friend'} LOGGED THEIRS'
                        : state == FriendPostWatchState.waitingForOthers
                            ? 'YOUR WATCH IS LOGGED'
                            : 'DID YOU WATCH IT?',
                    style: const TextStyle(
                        color: FlixieColors.warning,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1)),
                const SizedBox(height: 8),
                Text(title,
                    style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('$scheduled · ${location ?? 'Location undecided'}',
                    style: const TextStyle(
                        color: FlixieColors.light, fontSize: 13)),
                const SizedBox(height: 10),
                Row(children: [
                  ProfileAvatarView(
                      avatar: context.read<AuthProvider>().dbUser?.avatar,
                      fallbackText: 'Y',
                      fallbackColor: FlixieColors.primary,
                      size: 26),
                  const SizedBox(width: 6),
                  ProfileAvatarView(
                      avatar: other?.avatar,
                      fallbackText: other?.username.isNotEmpty == true
                          ? other!.username[0].toUpperCase()
                          : '?',
                      fallbackColor: FlixieColors.primary,
                      size: 26),
                ]),
              ])),
        ])),
        const SizedBox(height: 12),
        _PostWatchSurface(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(heading,
              style: const TextStyle(
                  color: FlixieColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(copy,
              style: const TextStyle(
                  color: FlixieColors.light, fontSize: 14, height: 1.4)),
          if (!myResolved) ...[
            const SizedBox(height: 18),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: onConfirmWatched,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(state == FriendPostWatchState.waitingForMe
                        ? 'Log your watch'
                        : 'Log watch'))),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              TextButton(
                  onPressed: onNotThisTime, child: const Text('Not this time')),
              TextButton(
                  onPressed: onSuggestDifferentTime,
                  child: const Text('Reschedule'))
            ])
          ],
        ])),
        const SizedBox(height: 12),
        _PostWatchSurface(
            child: _buildPostWatchStatus(context, other, mine, otherEntry)),
        if (state == FriendPostWatchState.waitingForMe) ...[
          const SizedBox(height: 12),
          _PostWatchSurface(
              child: const Text(
                  'Their rating is hidden for now. Log your own take before seeing theirs.',
                  style: TextStyle(color: FlixieColors.light, fontSize: 13)))
        ],
      ]),
    );
  }

  Widget _buildPostWatchStatus(BuildContext context, WatchRequestUser? other,
          WatchConfirmation? mine, WatchConfirmation? theirs) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            'WATCH STATUS · ${(mine != null ? 1 : 0) + (theirs != null ? 1 : 0)} OF 2',
            style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        const Divider(height: 22, color: FlixieColors.tabBarBorder),
        _postWatchPerson(
            'You', context.read<AuthProvider>().dbUser?.avatar, mine != null),
        const SizedBox(height: 12),
        _postWatchPerson(
            other?.username ?? 'Friend', other?.avatar, theirs != null),
      ]);

  Widget _postWatchPerson(String name, ProfileAvatar? avatar, bool resolved) =>
      Row(children: [
        ProfileAvatarView(
            avatar: avatar,
            fallbackText: name[0].toUpperCase(),
            fallbackColor: FlixieColors.primary,
            size: 42),
        const SizedBox(width: 10),
        Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: FlixieColors.textPrimary,
                    fontWeight: FontWeight.w700))),
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (resolved)
            const Icon(Icons.check_circle_rounded,
                color: FlixieColors.success, size: 18),
          if (resolved) const SizedBox(width: 5),
          Text(resolved ? 'Logged' : 'Waiting',
              style: TextStyle(
                  color: resolved ? FlixieColors.success : FlixieColors.light,
                  fontWeight: FontWeight.w700)),
        ]),
      ]);

  Widget _buildCompletedFriendRecap(
    BuildContext context, {
    required WatchRequestUser? other,
    required WatchRequestMovieDetails? movie,
    required String? posterUrl,
  }) {
    final entries = request.watchConfirmations
        .where((entry) => entry.watched)
        .toList(growable: false);
    final mine = entries.where((entry) => entry.userId == myUserId).firstOrNull;
    final theirs =
        entries.where((entry) => entry.userId != myUserId).firstOrNull;
    final mineRating = mine?.rating;
    final difference = mine?.rating != null && theirs?.rating != null
        ? (mine!.rating! - theirs!.rating!).abs()
        : null;
    final scheduled = scheduledLabel;

    Widget surface(Widget child, {bool tinted = false}) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: tinted
                ? FlixieColors.surfaceElevated.withValues(alpha: .7)
                : FlixieColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: child,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.check_rounded, color: FlixieColors.success),
            SizedBox(width: 8),
            Text('WATCHED TOGETHER',
                style: TextStyle(
                    color: FlixieColors.success,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1)),
          ]),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  width: 116,
                  height: 174,
                  child: posterUrl == null
                      ? const _PostWatchPosterPlaceholder()
                      : CachedNetworkImage(
                          imageUrl: posterUrl, fit: BoxFit.cover),
                )),
            const SizedBox(width: 18),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(movie?.title ?? 'Watch plan',
                      style: const TextStyle(
                          color: FlixieColors.primary,
                          fontSize: 25,
                          fontWeight: FontWeight.w800)),
                  if (scheduled.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(scheduled,
                        style: const TextStyle(
                            color: FlixieColors.light, fontSize: 16))
                  ],
                  const SizedBox(height: 18),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 7),
                      decoration: BoxDecoration(
                          color: FlixieColors.primary.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text('👤 You + ${other?.username ?? 'friend'}',
                          style: const TextStyle(
                              color: FlixieColors.light,
                              fontWeight: FontWeight.w700))),
                ])),
          ]),
        ])),
        const SizedBox(height: 16),
        surface(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                    child: Text('How you matched',
                        style: TextStyle(
                            color: FlixieColors.light,
                            fontSize: 20,
                            fontWeight: FontWeight.w800))),
                Text(
                    '✓ ${difference == null ? 'RATINGS PENDING' : difference <= 1 ? 'CLOSE MATCH' : 'DIFFERENT TAKES'}',
                    style: const TextStyle(
                        color: FlixieColors.success,
                        fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _friendRatingTile('You', mine?.rating,
                        context.read<AuthProvider>().dbUser?.avatar)),
                const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('VS',
                        style: TextStyle(
                            color: FlixieColors.medium,
                            fontWeight: FontWeight.w800))),
                Expanded(
                    child: _friendRatingTile(other?.username ?? 'Friend',
                        theirs?.rating, other?.avatar)),
              ]),
              if (difference != null) ...[
                const SizedBox(height: 14),
                Center(
                    child: Text(
                        difference == 0
                            ? '👍 You both gave it the same rating'
                            : '👍 ${difference == 1 ? 'Only 1 point apart' : '$difference points apart'}',
                        style: const TextStyle(
                            color: FlixieColors.success,
                            fontWeight: FontWeight.w800)))
              ],
            ]),
            tinted: true),
        const SizedBox(height: 22),
        Row(children: [
          const Expanded(
              child: Text('Your takes',
                  style: TextStyle(
                      color: FlixieColors.light,
                      fontSize: 20,
                      fontWeight: FontWeight.w800))),
          Text('${entries.length} watches logged',
              style: const TextStyle(color: FlixieColors.medium)),
        ]),
        const SizedBox(height: 12),
        ...entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _friendRecapEntry(
                entry,
                entry.userId == myUserId
                    ? context.read<AuthProvider>().dbUser?.username ?? 'You'
                    : other?.username ?? 'Friend',
                entry.userId == myUserId
                    ? context.read<AuthProvider>().dbUser?.avatar
                    : other?.avatar))),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
                  onPressed: other?.id == null
                      ? null
                      : () => context.push('/chat/${other!.id}'),
                  icon: const Icon(Icons.forum_outlined),
                  label: Text('Message ${other?.username ?? 'friend'}'),
                  style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))))),
          const SizedBox(width: 12),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: mineRating == null || movie == null
                      ? null
                      : () => promptShareCard(
                          context,
                          ShareCardData.rating(
                              mediaType: ShareCardMediaType.movie,
                              mediaId: movie.id,
                              title: movie.title,
                              posterPath: movie.posterPath,
                              user: context.read<AuthProvider>().dbUser!,
                              rating: mineRating,
                              note: mine?.reviewText)),
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Share recap'),
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))))),
        ]),
      ]),
    );
  }

  Widget _friendRatingTile(String name, int? rating, ProfileAvatar? avatar) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: FlixieColors.background.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: FlixieColors.tabBarBorder)),
        child: Column(children: [
          ProfileAvatarView(
              avatar: avatar,
              fallbackText: name[0].toUpperCase(),
              fallbackColor: FlixieColors.primary,
              size: 46),
          const SizedBox(height: 8),
          Text(rating == null ? '-' : '$rating/10',
              style: const TextStyle(
                  color: FlixieColors.warning,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
          Text(name, style: const TextStyle(color: FlixieColors.medium))
        ]),
      );

  Widget _friendRecapEntry(
          WatchConfirmation entry, String name, ProfileAvatar? avatar) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: FlixieColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FlixieColors.tabBarBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ProfileAvatarView(
                avatar: avatar,
                fallbackText: name[0].toUpperCase(),
                fallbackColor: FlixieColors.primary,
                size: 48),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name,
                      style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const Text('Watched together',
                      style: TextStyle(color: FlixieColors.medium))
                ])),
            if (entry.rating != null)
              Text('★ ${entry.rating}/10',
                  style: const TextStyle(
                      color: FlixieColors.warning,
                      fontSize: 18,
                      fontWeight: FontWeight.w800))
          ]),
          if (entry.rating != null ||
              (entry.reviewText?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 14),
            Row(children: [
              if (entry.rating != null)
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        border: Border.all(color: FlixieColors.success),
                        borderRadius: BorderRadius.circular(18)),
                    child: Text(
                        entry.rating! >= 7 ? '👍 Recommends' : '👎 Would skip',
                        style: const TextStyle(
                            color: FlixieColors.success,
                            fontWeight: FontWeight.w700))),
              if (entry.reviewText?.isNotEmpty ?? false) ...[
                const SizedBox(width: 12),
                Expanded(
                    child: Text('“${entry.reviewText}”',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.light,
                            fontStyle: FontStyle.italic)))
              ]
            ]),
          ]
        ]),
      );
}

class _PostWatchSurface extends StatelessWidget {
  const _PostWatchSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: FlixieColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: child,
      );
}

class _PostWatchPosterPlaceholder extends StatelessWidget {
  const _PostWatchPosterPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF1E2D40),
        child: const Center(
          child: Icon(Icons.movie_outlined, color: FlixieColors.medium),
        ),
      );
}
