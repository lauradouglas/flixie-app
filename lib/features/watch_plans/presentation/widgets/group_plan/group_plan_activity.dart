import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/group_watch_request.dart';

class GroupPlanActivity extends StatelessWidget {
  const GroupPlanActivity({
    super.key,
    required this.req,
    required this.formatDateTimeString,
  });

  final GroupWatchRequest req;
  final String Function(String?) formatDateTimeString;

  @override
  Widget build(BuildContext context) {
    final watched =
        req.memberStatuses.where((member) => member.watchedAt != null).length;
    final rated =
        req.memberStatuses.where((member) => member.rating != null).length;
    final participantCount = req.analyticsParticipantCount;
    final accepted = req.acceptedCount + 1;
    final finalised = req.selectedCandidateId != null;
    final scheduled = req.scheduledFor?.isNotEmpty == true;
    final proposed = !scheduled && req.proposedDate?.isNotEmpty == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Plan activity',
          style: TextStyle(
              color: FlixieColors.light,
              fontSize: 16,
              fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      _groupActivityRow(
          Icons.send_rounded, 'Invited', 'Group watch plan created', true),
      _groupActivityRow(
          Icons.check_circle_outline_rounded,
          'Accepted',
          '$accepted of $participantCount people accepted',
          accepted >= participantCount),
      _groupActivityRow(
          Icons.bookmark_added_outlined,
          'Choices saved',
          req.candidates.isEmpty
              ? 'No titles added yet'
              : '${req.candidates.length} titles considered',
          req.candidates.isNotEmpty),
      _groupActivityRow(
          Icons.movie_filter_outlined,
          'Movie finalised',
          finalised
              ? '${req.movieTitle ?? 'Movie'} was picked'
              : 'Pick a movie together',
          finalised),
      _groupActivityRow(
          Icons.calendar_month_outlined,
          proposed ? 'Time proposed' : 'Scheduled',
          scheduled
              ? formatDateTimeString(req.scheduledFor)
              : proposed
                  ? '${formatDateTimeString(req.proposedDate)} · awaiting agreement'
                  : 'No time set yet',
          scheduled),
      _groupActivityRow(
          Icons.visibility_outlined,
          'Watched',
          watched > 0
              ? '$watched of $participantCount watches logged'
              : 'Log your watch after the plan',
          watched > 0),
      _groupActivityRow(
          Icons.star_outline_rounded,
          'Rated',
          rated > 0
              ? '$rated of $participantCount ratings saved'
              : 'Ratings will appear here',
          rated > 0,
          last: true),
    ]);
  }

  Widget _groupActivityRow(
          IconData icon, String title, String detail, bool complete,
          {bool last = false}) =>
      Padding(
        padding: EdgeInsets.only(bottom: last ? 0 : 8),
        child: Row(children: [
          Icon(icon,
              size: 17,
              color: complete ? FlixieColors.success : FlixieColors.medium),
          const SizedBox(width: 8),
          Expanded(
              child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: title,
                        style: TextStyle(
                            color: complete
                                ? FlixieColors.light
                                : FlixieColors.medium,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: ' · $detail',
                        style: const TextStyle(
                            color: FlixieColors.medium, fontSize: 12)),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis)),
        ]),
      );
}

class GroupCompletedWatchSummary extends StatelessWidget {
  const GroupCompletedWatchSummary({
    super.key,
    required this.req,
  });

  final GroupWatchRequest req;

  @override
  Widget build(BuildContext context) {
    final loggedMembers = req.memberStatuses
        .where((member) => member.watchedAt != null)
        .toList(growable: false);
    final ratings = loggedMembers
        .where((member) => member.rating != null)
        .map((member) => member.rating!)
        .toList(growable: false);
    final average = ratings.isEmpty
        ? null
        : ratings.reduce((total, rating) => total + rating) / ratings.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.celebration_rounded, color: FlixieColors.success),
            SizedBox(width: 9),
            Text(
              'Everyone logged their watch',
              style: TextStyle(
                color: FlixieColors.light,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '${loggedMembers.length} group members logged this viewing.',
          style: const TextStyle(color: FlixieColors.medium, fontSize: 12),
        ),
        if (average != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.star_rounded, color: FlixieColors.warning),
              const SizedBox(width: 6),
              Text(
                '${average.toStringAsFixed(1)}/10 group rating',
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...loggedMembers.where((member) => member.rating != null).map(
                (member) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${member.username ?? 'Member'} · ${member.rating}/10',
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
        ],
      ],
    );
  }
}
