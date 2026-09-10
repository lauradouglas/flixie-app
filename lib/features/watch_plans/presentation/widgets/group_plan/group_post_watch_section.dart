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
    GroupRequestMemberStatus? myStatus;
    for (final member in req.memberStatuses) {
      if (member.memberId == currentUserId) {
        myStatus = member;
        break;
      }
    }
    final hasMissed = myStatus?.status.toUpperCase() == 'DECLINED';
    final totalParticipants = req.analyticsParticipantCount;
    final waitingMembers = req.memberStatuses
        .where((member) =>
            member.watchedAt == null &&
            member.status.toUpperCase() != 'DECLINED')
        .toList(growable: false);
    final title = req.movieTitle ?? 'this watch plan';
    final dateLabel = scheduledAt == null
        ? 'Time to be confirmed'
        : formatDateTime(scheduledAt!);

    Widget surface(Widget child) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: FlixieColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: child,
        );

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 78,
              height: 116,
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
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(req.movieTitle ?? 'Watch Plan',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 23,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(dateLabel,
                    style: const TextStyle(
                        color: FlixieColors.light, fontSize: 15)),
                const SizedBox(height: 6),
                Text(
                    '${groupName ?? 'Group watch'} · $totalParticipants members',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: FlixieColors.medium, fontSize: 14)),
                const SizedBox(height: 12),
                _participantAvatars(req.memberStatuses),
              ])),
        ]),
        const Divider(height: 30, color: FlixieColors.tabBarBorder),
        Text(
          hasLogged
              ? 'Your watch is logged'
              : hasMissed
                  ? 'You couldn’t make it'
                  : 'How did $title go?',
          style: const TextStyle(
              color: FlixieColors.textPrimary,
              fontSize: 21,
              fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 7),
        Text(
          hasLogged
              ? 'Your viewing is saved. The group recap will grow as everyone adds theirs.'
              : hasMissed
                  ? 'You’re marked as unable to make it. The rest of the group can still log this watch.'
                  : 'Log your own viewing when you’re ready. Everyone responds separately.',
          style: const TextStyle(color: FlixieColors.medium, height: 1.4),
        ),
        if (!hasLogged && !hasMissed) ...[
          const SizedBox(height: 16),
          SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onLogWatch,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Log your watch'),
              )),
          const SizedBox(height: 4),
          Center(
              child: TextButton.icon(
            onPressed: onNotThisTime,
            icon: const Icon(Icons.event_busy_outlined, size: 18),
            label: const Text('I didn’t make it'),
          )),
        ] else if (hasMissed) ...[
          const SizedBox(height: 14),
          SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onReschedule,
                icon: const Icon(Icons.edit_calendar_outlined),
                label: const Text('Suggest a new time'),
              )),
        ],
      ])),
      const SizedBox(height: 12),
      surface(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
              child: Text('Group progress',
                  style: TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800))),
          Text('${watchedMembers.length} of $totalParticipants watched',
              style: TextStyle(
                  color: watchedMembers.isEmpty
                      ? FlixieColors.medium
                      : FlixieColors.success,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        if (watchedMembers.isNotEmpty) ...[
          _memberSummary(watchedMembers,
              icon: Icons.check_circle_rounded,
              color: FlixieColors.success,
              label: 'watched'),
          if (waitingMembers.isNotEmpty) const SizedBox(height: 10),
        ],
        if (waitingMembers.isNotEmpty)
          _memberSummary(waitingMembers,
              icon: Icons.schedule_rounded,
              color: FlixieColors.medium,
              label: 'still to respond')
        else if (watchedMembers.isEmpty)
          const Text('No one has logged their watch yet.',
              style: TextStyle(color: FlixieColors.medium, fontSize: 14)),
      ])),
    ]);
  }

  Widget _memberSummary(
    List<GroupRequestMemberStatus> members, {
    required IconData icon,
    required Color color,
    required String label,
  }) {
    final names = members
        .map((member) => member.memberId == currentUserId
            ? 'You'
            : member.username ?? 'a member')
        .take(3)
        .join(', ');
    final extra = members.length > 3 ? ' +${members.length - 3}' : '';
    return Row(children: [
      _participantAvatars(members, size: 32),
      const SizedBox(width: 10),
      Expanded(
          child: Text('$names$extra $label',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: FlixieColors.medium, fontSize: 14))),
      Icon(icon, color: color, size: 18),
    ]);
  }

  Widget _participantAvatars(List<GroupRequestMemberStatus> members,
      {double size = 34}) {
    final visible = members.take(5).toList(growable: false);
    if (visible.isEmpty) return const SizedBox.shrink();
    const overlap = 10.0;
    return SizedBox(
      width: size + (visible.length - 1) * (size - overlap),
      height: size,
      child: Stack(children: [
        for (var index = 0; index < visible.length; index++)
          Positioned(
              left: index * (size - overlap),
              child: _borderedMemberAvatar(visible[index], size: size)),
      ]),
    );
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
    final hasSpecialFrame = member.profileBadges.isNotEmpty;
    // `size` is the footprint reserved by the avatar stack. Account for the
    // frame/border inside that footprint; otherwise Stack clips the lower and
    // right edges of every ring.
    final avatarSize = size - (hasSpecialFrame ? 6 : 9);
    final avatar = ProfileAvatarView(
      avatar: member.avatar,
      fallbackText: (member.username ?? '?')[0].toUpperCase(),
      fallbackColor: FlixieColors.primary,
      size: avatarSize,
      profileBadges: member.profileBadges,
    );
    return SizedBox.square(
      dimension: size,
      child: hasSpecialFrame
          ? Center(child: avatar)
          : DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: FlixieColors.primary, width: 2.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: avatar,
              ),
            ),
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
