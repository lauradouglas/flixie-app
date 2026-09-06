import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/sharing/models/share_card_data.dart';
import 'package:flixie_app/features/sharing/presentation/share_card_sheet.dart';
import 'package:flixie_app/models/group_watch_request.dart';

class GroupPostWatchSection extends StatelessWidget {
  const GroupPostWatchSection({
    super.key,
    required this.req,
    required this.currentUserId,
    required this.groupName,
    required this.posterUrl,
    required this.scheduledAt,
    required this.completed,
    required this.formatDateTime,
    required this.formatDateTimeString,
    required this.onLogWatch,
    required this.onNotThisTime,
    required this.onReschedule,
    required this.onOpenChat,
  });

  final GroupWatchRequest req;
  final String currentUserId;
  final String? groupName;
  final String? posterUrl;
  final DateTime? scheduledAt;
  final bool completed;
  final String Function(DateTime) formatDateTime;
  final String Function(String?) formatDateTimeString;
  final VoidCallback onLogWatch;
  final VoidCallback onNotThisTime;
  final VoidCallback onReschedule;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) =>
      completed ? _buildRecap(context) : _buildProgress(context);

  Widget _buildProgress(BuildContext context) {
    final watchedMembers = req.memberStatuses
        .where((member) => member.watchedAt != null)
        .toList(growable: false);
    final hasLogged =
        watchedMembers.any((member) => member.memberId == currentUserId);
    final totalParticipants = req.analyticsParticipantCount;
    final memberWord = watchedMembers.length == 1 ? 'member' : 'members';
    final statusText = hasLogged
        ? '${watchedMembers.length} of $totalParticipants logged'
        : watchedMembers.isEmpty
            ? 'No watches logged yet'
            : '${watchedMembers.length} $memberWord has logged';

    Widget surface(Widget child) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: FlixieColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: child,
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      surface(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 82,
            height: 123,
            child: posterUrl == null
                ? const ColoredBox(
                    color: FlixieColors.surfaceElevated,
                    child: Icon(Icons.movie_outlined),
                  )
                : CachedNetworkImage(imageUrl: posterUrl!, fit: BoxFit.cover),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('DID THE PLAN HAPPEN?',
                style: TextStyle(
                    color: FlixieColors.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1)),
            const SizedBox(height: 7),
            Text(req.movieTitle ?? 'Watch Plan',
                style: const TextStyle(
                    color: FlixieColors.primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(formatDateTime(scheduledAt!),
                style:
                    const TextStyle(color: FlixieColors.light, fontSize: 14)),
            const SizedBox(height: 10),
            Text(groupName ?? 'Group watch',
                style:
                    const TextStyle(color: FlixieColors.medium, fontSize: 14)),
          ]),
        ),
      ])),
      const SizedBox(height: 12),
      surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(hasLogged ? 'Watch logged' : 'Did you watch it?',
            style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 21,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Text(
          hasLogged
              ? 'Your watch is saved. We’ll reveal the group recap once everyone has logged.'
              : 'Log your own viewing. Everyone responds separately.',
          style: const TextStyle(color: FlixieColors.medium, height: 1.4),
        ),
        if (!hasLogged) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onLogWatch,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Log your watch'),
            ),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            TextButton(
              onPressed: onNotThisTime,
              child: const Text('Not this time'),
            ),
            TextButton(
              onPressed: onReschedule,
              child: const Text('Reschedule'),
            ),
          ]),
        ],
      ])),
      const SizedBox(height: 12),
      surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('WATCH STATUS · ${watchedMembers.length} OF $totalParticipants',
            style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1)),
        const Divider(height: 22, color: FlixieColors.tabBarBorder),
        Text(statusText,
            style: const TextStyle(color: FlixieColors.light, fontSize: 14)),
        if (watchedMembers.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: watchedMembers.map((member) {
              return Row(mainAxisSize: MainAxisSize.min, children: [
                _borderedMemberAvatar(member, size: 38),
                const SizedBox(width: 6),
                const Icon(Icons.check_circle_rounded,
                    color: FlixieColors.success, size: 18),
              ]);
            }).toList(),
          ),
        ],
      ])),
    ]);
  }

  Widget _buildRecap(BuildContext context) {
    final entries = req.memberStatuses
        .where((member) => member.watchedAt != null)
        .toList(growable: false);
    final ratings = entries
        .where((member) => member.rating != null)
        .map((member) => member.rating!)
        .toList(growable: false);
    final average = ratings.isEmpty
        ? null
        : ratings.reduce((total, rating) => total + rating) / ratings.length;
    final recommends = ratings.where((rating) => rating >= 7).length;
    final scheduled =
        formatDateTimeString(req.scheduledFor ?? req.proposedDate);
    GroupRequestMemberStatus? myEntry;
    for (final entry in entries) {
      if (entry.memberId == currentUserId) {
        myEntry = entry;
        break;
      }
    }

    Widget card(Widget child, {Color? color}) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: color ?? FlixieColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: child,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        card(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.check_rounded, color: FlixieColors.success, size: 22),
              SizedBox(width: 8),
              Text('WATCHED TOGETHER',
                  style: TextStyle(
                      color: FlixieColors.success,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ]),
            const SizedBox(height: 12),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _poster(posterUrl),
              const SizedBox(width: 18),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(req.movieTitle ?? 'Watch Plan',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: FlixieColors.primary,
                          fontSize: 21,
                          height: 1.1,
                          fontWeight: FontWeight.w700)),
                  if (scheduled.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(scheduled,
                        style: const TextStyle(
                            color: FlixieColors.light, fontSize: 15)),
                  ],
                  const SizedBox(height: 18),
                  _watcherAvatars(entries),
                ],
              )),
            ]),
          ],
        )),
        const SizedBox(height: 16),
        card(
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Expanded(
                  child: Text("Your group's take",
                      style: TextStyle(
                          color: FlixieColors.light,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                Text(
                    '✓ ${recommends == entries.length ? 'YOU AGREED' : 'MIXED TAKE'}',
                    style: const TextStyle(
                        color: FlixieColors.success,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _metric(average?.toStringAsFixed(1) ?? '-',
                        'Average rating', FlixieColors.warning)),
                const SizedBox(width: 12),
                Expanded(
                    child: _metric('$recommends of ${entries.length}',
                        'Recommend it', FlixieColors.success)),
              ]),
            ]),
            color: FlixieColors.surfaceElevated.withValues(alpha: .72)),
        const SizedBox(height: 16),
        Row(children: [
          const Expanded(
              child: Text("Everyone's ratings",
                  style: TextStyle(
                      color: FlixieColors.light,
                      fontSize: 18,
                      fontWeight: FontWeight.w700))),
          Text('${entries.length} watches logged',
              style: const TextStyle(color: FlixieColors.medium, fontSize: 14)),
        ]),
        const SizedBox(height: 14),
        card(
          Column(
            children: [
              for (var index = 0; index < entries.length; index++) ...[
                _entry(entries[index],
                    isYou: entries[index].memberId == currentUserId),
                if (index < entries.length - 1)
                  const Divider(height: 26, color: FlixieColors.tabBarBorder),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
              child: FilledButton.icon(
            onPressed: onOpenChat,
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Open group chat'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(
              child: OutlinedButton.icon(
            onPressed: myEntry?.rating == null || req.mediaId == null
                ? null
                : () {
                    final user = context.read<AuthProvider>().dbUser;
                    if (user == null) return;
                    promptShareCard(
                      context,
                      ShareCardData.rating(
                        mediaType: req.mediaType?.toLowerCase() == 'show'
                            ? ShareCardMediaType.show
                            : ShareCardMediaType.movie,
                        mediaId: req.mediaId!,
                        title: req.movieTitle ?? 'Watch Plan',
                        posterPath: req.moviePosterPath,
                        user: user,
                        rating: myEntry!.rating!,
                        recommended: myEntry.rating! >= 7,
                        note: myEntry.reviewText,
                      ),
                    );
                  },
            icon: const Icon(Icons.ios_share_rounded),
            label: const Text('Share recap'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          )),
        ]),
      ],
    );
  }

  Widget _metric(String value, String label, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlixieColors.background.withValues(alpha: .7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _entry(GroupRequestMemberStatus member, {required bool isYou}) {
    final recommends = (member.rating ?? 0) >= 7;
    final hasRating = member.rating != null;
    final opinionColor = hasRating
        ? recommends
            ? FlixieColors.success
            : FlixieColors.warning
        : FlixieColors.medium;
    final opinionLabel = !hasRating
        ? 'No rating'
        : recommends
            ? 'Recommends'
            : 'Would skip';
    return Row(children: [
      _borderedMemberAvatar(member, size: 52),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(isYou ? 'You' : member.username ?? 'Member',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(hasRating ? '★ ${member.rating}/10' : 'No rating',
              style: TextStyle(
                  color: hasRating ? FlixieColors.warning : FlixieColors.medium,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ]),
      ),
      Container(width: 1, height: 42, color: FlixieColors.tabBarBorder),
      const SizedBox(width: 12),
      Icon(
        hasRating
            ? recommends
                ? Icons.thumb_up_alt_rounded
                : Icons.thumb_down_alt_rounded
            : Icons.remove_circle_outline_rounded,
        color: opinionColor,
        size: 21,
      ),
      const SizedBox(width: 7),
      Flexible(
        child: Text(opinionLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: opinionColor,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ),
    ]);
  }

  Widget _watcherAvatars(List<GroupRequestMemberStatus> entries) {
    if (entries.isEmpty) {
      return Text('${req.analyticsParticipantCount} people',
          style: const TextStyle(color: FlixieColors.medium, fontSize: 13));
    }
    const size = 38.0;
    const overlap = 11.0;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      const Text('With',
          style: TextStyle(color: FlixieColors.light, fontSize: 14)),
      const SizedBox(width: 8),
      SizedBox(
        width: size + (entries.length - 1) * (size - overlap),
        height: size,
        child: Stack(children: [
          for (var index = 0; index < entries.length; index++)
            Positioned(
              left: index * (size - overlap),
              child: _borderedMemberAvatar(entries[index], size: size),
            ),
        ]),
      ),
    ]);
  }

  Widget _borderedMemberAvatar(
    GroupRequestMemberStatus member, {
    required double size,
  }) {
    final avatar = ProfileAvatarView(
      avatar: member.avatar,
      fallbackText: (member.username ?? '?')[0].toUpperCase(),
      fallbackColor: FlixieColors.primary,
      size: size - 5,
      profileBadges: member.profileBadges,
    );
    if (member.profileBadges.isNotEmpty) return avatar;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: FlixieColors.primary, width: 2.5),
      ),
      child: Padding(padding: const EdgeInsets.all(2), child: avatar),
    );
  }

  Widget _poster(String? url) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 105,
          height: 158,
          child: url == null
              ? const ColoredBox(
                  color: FlixieColors.surfaceElevated,
                  child: Icon(Icons.movie_outlined),
                )
              : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover),
        ),
      );
}
