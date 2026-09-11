import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';

/// A completed plan's ratings and attendance, with ratings displayed out of five.
class GroupWatchPlanRecap extends StatelessWidget {
  const GroupWatchPlanRecap(
      {super.key,
      required this.request,
      required this.currentUserId,
      required this.members,
      required this.onOpenChat});

  final GroupWatchRequest request;
  final String currentUserId;
  final List<GroupMember> members;
  final VoidCallback onOpenChat;

  static const _body =
      TextStyle(color: FlixieColors.light, fontSize: 14, height: 1.4);
  static const _heading = TextStyle(
      color: FlixieColors.textPrimary,
      fontSize: 17,
      fontWeight: FontWeight.w800);

  @override
  Widget build(BuildContext context) {
    final responses = request.memberStatuses;
    final watched = responses
        .where((r) => r.watchedAt != null && r.missedAt == null)
        .toList();
    final missed = responses.where((r) => r.missedAt != null).toList();
    final rated = watched
        .where((r) => r.rating != null && r.rating! >= 1 && r.rating! <= 10)
        .toList();
    final average = rated.isEmpty
        ? null
        : rated.fold<int>(0, (sum, r) => sum + r.rating!) / rated.length / 2;
    final yes = watched.where((r) => r.recommended == true).length;
    final no = watched.where((r) => r.recommended == false).length;
    final unknown = watched.length - yes - no;
    final selected = request.candidates
        .where((c) => c.id == request.selectedCandidateId)
        .firstOrNull;
    final title = selected?.title ?? request.movieTitle ?? 'Your Watch Plan';
    final poster = selected?.posterPath ?? request.moviePosterPath;
    final memberRows = [...watched]..sort((a, b) => a.memberId == currentUserId
        ? -1
        : b.memberId == currentUserId
            ? 1
            : 0);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4;
        final summary =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  color: FlixieColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  height: 1.15)),
          const SizedBox(height: 5),
          const Text('Your group’s take', style: _body),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.star_rounded,
                color: FlixieColors.warning, size: 36),
            const SizedBox(width: 7),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(average?.toStringAsFixed(1) ?? '—',
                      semanticsLabel: average == null
                          ? 'No ratings yet'
                          : 'Average ${average.toStringAsFixed(1)} out of 5',
                      style: const TextStyle(
                          color: FlixieColors.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          height: 1.1)),
                  Text(
                      average == null
                          ? 'No ratings yet'
                          : 'Average rating · /5',
                      style: _body),
                ])),
          ]),
          const SizedBox(height: 16),
          _recommendation(
              Icons.thumb_up_outlined, FlixieColors.success, '$yes recommend'),
          const SizedBox(height: 8),
          _recommendation(Icons.thumb_down_outlined, FlixieColors.light,
              '$no don’t recommend'),
          if (unknown > 0) ...[
            const SizedBox(height: 8),
            Text(
                '$unknown ${unknown == 1 ? 'person hasn’t' : 'people haven’t'} recommended either way',
                style: _body),
          ],
        ]);
        final art = _poster(poster, title, stacked ? 110 : 112);
        return stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [art, const SizedBox(height: 18), summary])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                art,
                const SizedBox(width: 16),
                Expanded(child: summary)
              ]);
      }),
      const Divider(height: 36, color: FlixieColors.tabBarBorder),
      const Text('Member ratings', style: _heading),
      const SizedBox(height: 14),
      if (memberRows.isEmpty)
        const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child:
                Text('No one logged a viewing for this plan.', style: _body)),
      ...memberRows.map((r) => _member(context, r)),
      if (missed.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('Didn’t make it (${missed.length})', style: _heading),
        const SizedBox(height: 6),
        const Text('Not included in ratings or recommendations.', style: _body),
        const SizedBox(height: 14),
        ...missed.map((r) => _member(context, r, missed: true)),
      ],
      const SizedBox(height: 16),
      SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: FlixieColors.primary,
                foregroundColor: FlixieColors.background,
                minimumSize: const Size(0, 56),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            onPressed: onOpenChat,
            icon: const Icon(Icons.forum_outlined),
            label: const Text('Open group chat', textAlign: TextAlign.center),
          )),
    ]);
  }

  Widget _recommendation(IconData icon, Color color, String text) =>
      Row(children: [
        Icon(icon, color: color, size: 23),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: _body)),
      ]);

  Widget _poster(String? path, String title, double width) {
    final placeholder = ColoredBox(
        color: FlixieColors.surfaceElevated,
        child: Center(
            child: Icon(Icons.movie_outlined,
                color: FlixieColors.light, size: width / 3)));
    return Semantics(
        label: '$title poster',
        image: true,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: width,
            height: width * 1.5,
            child: path == null || path.isEmpty
                ? placeholder
                : CachedNetworkImage(
                    imageUrl: path.startsWith('http')
                        ? path
                        : 'https://image.tmdb.org/t/p/w342$path',
                    fit: BoxFit.cover,
                    placeholder: (_, __) => placeholder,
                    errorWidget: (_, __, ___) => placeholder,
                  ),
          ),
        ));
  }

  Widget _member(BuildContext context, GroupRequestMemberStatus response,
      {bool missed = false}) {
    final member =
        members.where((m) => m.memberId == response.memberId).firstOrNull;
    final name = response.memberId == currentUserId
        ? 'You'
        : response.username ?? member?.displayName ?? 'Member';
    final rating = response.rating;
    final score = !missed && rating != null && rating >= 1 && rating <= 10
        ? rating / 2
        : null;
    final trailing = missed
        ? const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.event_busy_outlined,
                size: 18, color: FlixieColors.light),
            SizedBox(width: 6),
            Text('Missed', style: _body)
          ])
        : score == null
            ? const Text('Watched · Not rated', style: _body)
            : Semantics(
                label: '$score out of 5 stars',
                child: ExcludeSemantics(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                  for (var i = 0; i < 5; i++)
                    Icon(
                        score >= i + 1
                            ? Icons.star_rounded
                            : score >= i + .5
                                ? Icons.star_half_rounded
                                : Icons.star_outline_rounded,
                        color: FlixieColors.warning,
                        size: 24),
                  const SizedBox(width: 8),
                  Text(score.toStringAsFixed(1), style: _body),
                ])));
    return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (context, constraints) {
            final stack = constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.25;
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ProfileAvatarView(
                  avatar: response.avatar ?? member?.avatar,
                  fallbackText: name.isEmpty ? '?' : name.characters.first,
                  fallbackColor: FlixieColors.primaryText,
                  size: 38,
                  profileBadges: response.profileBadges),
              const SizedBox(width: 10),
              Expanded(
                  child: stack
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text(name,
                                  style: _heading.copyWith(fontSize: 15)),
                              const SizedBox(height: 5),
                              trailing,
                            ])
                      : Row(children: [
                          Expanded(
                              child: Text(name,
                                  style: _heading.copyWith(fontSize: 15))),
                          const SizedBox(width: 10),
                          trailing
                        ])),
            ]);
          }),
          if (!missed && response.reviewText?.trim().isNotEmpty == true)
            Padding(
                padding: const EdgeInsets.only(left: 48, top: 8),
                child: Text(response.reviewText!, style: _body)),
        ]));
  }
}
