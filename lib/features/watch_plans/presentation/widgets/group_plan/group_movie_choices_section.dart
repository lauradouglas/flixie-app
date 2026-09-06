import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/widgets/request_poster_placeholder.dart';
import 'package:flixie_app/features/social/presentation/widgets/watch_plan_candidate_avatar.dart';
import 'package:flixie_app/models/group_watch_request.dart';

class GroupMovieChoicesSection extends StatelessWidget {
  const GroupMovieChoicesSection({
    super.key,
    required this.request,
    required this.myStatus,
    required this.currentUserId,
    required this.choices,
    required this.processing,
    required this.onToggleCandidate,
    required this.onSaveChoices,
    required this.onAddCandidate,
    required this.onRemoveCandidate,
    required this.onSelectFinalMovie,
  });

  final GroupWatchRequest request;
  final String? myStatus;
  final String currentUserId;
  final Set<String> choices;
  final bool processing;
  final ValueChanged<String> onToggleCandidate;
  final VoidCallback onSaveChoices;
  final VoidCallback onAddCandidate;
  final ValueChanged<String> onRemoveCandidate;
  final ValueChanged<String> onSelectFinalMovie;

  @override
  Widget build(BuildContext context) {
    final isCreator = request.userId == currentUserId;
    final canChoose = isCreator || myStatus == 'ACCEPTED';
    final everyoneCount = request.analyticsParticipantCount;
    final mostApprovals = request.candidates.fold<int>(
      0,
      (highest, candidate) => candidate.selectedByUserIds.length > highest
          ? candidate.selectedByUserIds.length
          : highest,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isCreator ? 'Choose the final movie' : 'What could you watch?',
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          isCreator
              ? 'Choose every title you would watch, then make the final choice.'
              : canChoose
                  ? 'Choose every title you would watch. The creator makes the final choice.'
                  : 'Accept the invitation first, then choose the movies you would watch.',
          style: const TextStyle(color: FlixieColors.medium, fontSize: 12),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 600;
            final cardWidth = twoColumns
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 10,
              runSpacing: 8,
              children: request.candidates.map((candidate) {
                final selected = choices.contains(candidate.id);
                final supportCount = candidate.selectedByUserIds.toSet().length;
                final everyoneWouldWatch =
                    everyoneCount > 0 && supportCount >= everyoneCount;
                // The creator's saved choices are useful data, not a visual
                // selection state. Reserve the highlight for a member's own
                // active vote and surface the group preference separately.
                final highlighted = selected && !isCreator;
                final hasMostApprovals =
                    supportCount > 0 && supportCount == mostApprovals;
                final canRemove = request.selectedCandidateId == null &&
                    request.candidates.length > 1 &&
                    (isCreator || candidate.addedByUserId == currentUserId);
                final poster = candidate.posterPath == null
                    ? null
                    : 'https://image.tmdb.org/t/p/w185${candidate.posterPath}';
                return SizedBox(
                  width: cardWidth,
                  child: InkWell(
                    onTap: !canChoose || processing
                        ? null
                        : () => onToggleCandidate(candidate.id),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: highlighted
                            ? FlixieColors.success.withValues(alpha: .1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: highlighted
                              ? FlixieColors.success
                              : FlixieColors.tabBarBorder,
                          width: highlighted ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 46,
                                  height: 68,
                                  child: poster == null
                                      ? const RequestPosterPlaceholder()
                                      : CachedNetworkImage(
                                          imageUrl: poster, fit: BoxFit.cover),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(candidate.title ?? 'Movie option',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: FlixieColors.light,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 15)),
                                    const SizedBox(height: 4),
                                    Row(children: [
                                      WatchPlanCandidateAvatar(
                                        avatar: candidate.addedByAvatar,
                                        username: candidate.addedByUsername,
                                      ),
                                      const SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          'Added by @${candidate.addedByUsername ?? 'a member'}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              color: FlixieColors.medium,
                                              fontSize: 12),
                                        ),
                                      ),
                                    ]),
                                    const SizedBox(height: 2),
                                    Text(
                                      everyoneWouldWatch
                                          ? "Everyone's match"
                                          : hasMostApprovals
                                              ? 'Most approvals · $supportCount of $everyoneCount would watch'
                                              : '$supportCount of $everyoneCount would watch',
                                      style: TextStyle(
                                        color: everyoneWouldWatch ||
                                                hasMostApprovals
                                            ? FlixieColors.success
                                            : FlixieColors.medium,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (selected && !isCreator)
                                const Icon(Icons.check_circle,
                                    color: FlixieColors.success, size: 28),
                              if (hasMostApprovals && !everyoneWouldWatch)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.trending_up_rounded,
                                      color: FlixieColors.success, size: 20),
                                ),
                              if (canRemove)
                                IconButton(
                                  onPressed: processing
                                      ? null
                                      : () => onRemoveCandidate(candidate.id),
                                  tooltip: 'Remove movie option',
                                  icon:
                                      const Icon(Icons.close_rounded, size: 19),
                                  color: FlixieColors.medium,
                                  visualDensity: VisualDensity.compact,
                                ),
                              if (isCreator)
                                IconButton(
                                  onPressed: processing
                                      ? null
                                      : () => onSelectFinalMovie(candidate.id),
                                  tooltip: 'Make final movie',
                                  icon: const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 23),
                                  color: FlixieColors.primaryText,
                                  visualDensity: VisualDensity.compact,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            );
          },
        ),
        if (canChoose) ...[
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: processing ? null : onSaveChoices,
              icon: processing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.checklist_rounded),
              label:
                  Text(processing ? 'Saving movies…' : 'Save movies I’d watch'),
            ),
          ),
        ],
        if (request.selectedCandidateId == null &&
            canChoose &&
            request.candidates.length < 5)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: processing ? null : onAddCandidate,
              icon: const Icon(Icons.add_circle_outline_rounded),
              label: const Text('Add another option'),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }
}
