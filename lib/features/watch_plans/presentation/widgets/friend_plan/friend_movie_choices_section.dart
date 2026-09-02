import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/widgets/watch_plan_candidate_avatar.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_types.dart';
import 'package:flixie_app/models/watch_request.dart';

class FriendMovieChoicesSection extends StatelessWidget {
  const FriendMovieChoicesSection({
    super.key,
    required this.request,
    required this.myUserId,
    required this.busyAction,
    required this.candidateChoiceDraft,
    required this.onToggleCandidateChoice,
    required this.onSaveCandidateChoices,
    required this.onAddCandidate,
    required this.onRemoveCandidate,
    required this.onSelectCandidate,
    required this.onChangeMovie,
  });

  final WatchRequest request;
  final String myUserId;
  final FriendWatchPlanAction? busyAction;
  final Set<String> candidateChoiceDraft;
  final ValueChanged<String> onToggleCandidateChoice;
  final VoidCallback onSaveCandidateChoices;
  final VoidCallback onAddCandidate;
  final ValueChanged<String> onRemoveCandidate;
  final ValueChanged<String> onSelectCandidate;
  final VoidCallback onChangeMovie;

  @override
  Widget build(BuildContext context) {
    final organiser = request.requesterId == myUserId;
    // Direct Watch Plans have a single invitee.  The lifecycle endpoint does
    // not include a per-user acceptance flag, so its accepted/scheduled status
    // is the reliable source once the invitee has accepted.
    final canChooseMovies =
        organiser || request.isAccepted || request.isScheduled;
    final selectedCandidate = request.selectedCandidateId;
    if (selectedCandidate != null) {
      return _buildFinalMovieSummary(selectedCandidate, organiser);
    }
    final acceptedIds = <String>{request.requesterId, request.recipientId};
    final savingMovieChoices =
        busyAction == FriendWatchPlanAction.savingMovieChoices;
    final removingCandidate =
        busyAction == FriendWatchPlanAction.removingCandidate;
    final selectingMovie = busyAction == FriendWatchPlanAction.selectingMovie;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          selectedCandidate == null && organiser
              ? 'Choose the final movie'
              : selectedCandidate == null
                  ? 'What could you watch?'
                  : 'Chosen movie',
          style: const TextStyle(
            color: FlixieColors.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          selectedCandidate == null && organiser
              ? 'As the Watch Plan creator, you make the final choice. Use “Make final” to lock in a movie.'
              : selectedCandidate == null
                  ? '${request.candidates.length} of 5 options · choose every title you would watch. The Watch Plan creator makes the final choice.'
                  : 'The final title is selected. Rescheduling will keep this choice.',
          style: const TextStyle(color: FlixieColors.medium, fontSize: 12),
        ),
        if (!canChooseMovies) ...[
          const SizedBox(height: 10),
          const Text(
            'Accept the invitation first, then choose the movies you would watch.',
            style: TextStyle(
              color: FlixieColors.warning,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final candidateCards = request.candidates.map((candidate) {
            final selectedCount =
                candidate.selectedByUserIds.where(acceptedIds.contains).length;
            final everyoneMatch = selectedCount == acceptedIds.length;
            final isFinal = candidate.id == selectedCandidate;
            final pickedByMe = candidateChoiceDraft.contains(candidate.id);
            final canRemove = selectedCandidate == null &&
                request.candidates.length > 1 &&
                (organiser || candidate.addedByUserId == myUserId);
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(13),
                  onTap: canChooseMovies &&
                          selectedCandidate == null &&
                          !selectingMovie
                      ? () => onToggleCandidateChoice(candidate.id)
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: pickedByMe
                          ? FlixieColors.success.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: pickedByMe
                            ? FlixieColors.success
                            : FlixieColors.tabBarBorder,
                        width: pickedByMe ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 44,
                            height: 66,
                            child: candidate.posterPath == null
                                ? const _MoviePosterPlaceholder()
                                : CachedNetworkImage(
                                    imageUrl:
                                        'https://image.tmdb.org/t/p/w185${candidate.posterPath}',
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        const _MoviePosterPlaceholder(),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(candidate.title ?? 'Untitled',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: FlixieColors.light,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(
                                isFinal
                                    ? 'Selected for this Watch Plan'
                                    : everyoneMatch
                                        ? 'Everyone\'s match'
                                        : '$selectedCount of ${acceptedIds.length} would watch',
                                style: TextStyle(
                                  color: isFinal || everyoneMatch
                                      ? FlixieColors.success
                                      : FlixieColors.medium,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (candidate.addedByUsername?.isNotEmpty == true)
                                Row(children: [
                                  WatchPlanCandidateAvatar(
                                    avatar: candidate.addedByAvatar,
                                    username: candidate.addedByUsername,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      'Suggested by ${candidate.addedByUsername}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: FlixieColors.medium,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ]),
                            ],
                          ),
                        ),
                        if (pickedByMe)
                          const Icon(Icons.check_circle_rounded,
                              color: FlixieColors.success, size: 27),
                        if (pickedByMe &&
                            organiser &&
                            selectedCandidate == null)
                          const SizedBox(width: 10),
                        if (canRemove)
                          IconButton(
                            onPressed: removingCandidate
                                ? null
                                : () => onRemoveCandidate(candidate.id),
                            tooltip: 'Remove movie option',
                            icon: removingCandidate
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.close_rounded, size: 20),
                            color: FlixieColors.medium,
                            visualDensity: VisualDensity.compact,
                          ),
                        if (organiser && selectedCandidate == null)
                          FilledButton.icon(
                            onPressed: selectingMovie
                                ? null
                                : () => onSelectCandidate(candidate.id),
                            icon: selectingMovie
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : const Icon(Icons.lock_rounded, size: 16),
                            label: Text(
                              selectingMovie ? 'Saving' : 'Final',
                            ),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 38),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 11),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(growable: false);
          if (constraints.maxWidth < 600) {
            return Column(children: candidateCards);
          }
          return Wrap(
            spacing: 10,
            runSpacing: 0,
            children: candidateCards
                .map((card) => SizedBox(
                      width: (constraints.maxWidth - 10) / 2,
                      child: card,
                    ))
                .toList(growable: false),
          );
        }),
        if (selectedCandidate == null)
          Column(children: [
            if (request.candidates.length < 5)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: canChooseMovies && !savingMovieChoices
                      ? onAddCandidate
                      : null,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  label: const Text('Add another option'),
                ),
              )
            else
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('You have reached the five-option limit.',
                      style:
                          TextStyle(color: FlixieColors.medium, fontSize: 12)),
                ),
              ),
            if (candidateChoiceDraft.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text('Select at least one movie to continue.',
                      style: TextStyle(
                          color: FlixieColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: !canChooseMovies ||
                        savingMovieChoices ||
                        candidateChoiceDraft.isEmpty
                    ? null
                    : onSaveCandidateChoices,
                icon: savingMovieChoices
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.checklist_rounded),
                label: Text(
                  savingMovieChoices
                      ? 'Saving your picks...'
                      : 'Save movies I’d watch',
                ),
              ),
            ),
          ]),
      ],
    );
  }

  Widget _buildFinalMovieSummary(String selectedCandidateId, bool organiser) {
    final selected = request.candidates
        .where((candidate) => candidate.id == selectedCandidateId)
        .firstOrNull;
    if (selected == null) return const SizedBox.shrink();
    final alternatives = request.candidates
        .where((candidate) => candidate.id != selectedCandidateId)
        .toList(growable: false);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: FlixieColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlixieColors.primary, width: 2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
              child: Text('Chosen movie',
                  style: TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900)),
            ),
            if (alternatives.isNotEmpty)
              _OtherMovieOptionsMenu(alternatives: alternatives),
            if (organiser)
              IconButton(
                onPressed: onChangeMovie,
                tooltip: 'Change selected movie',
                icon: const Icon(Icons.edit_outlined),
                color: FlixieColors.primaryText,
              ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: SizedBox(
                    width: 52,
                    height: 78,
                    child: selected.posterPath == null
                        ? const _MoviePosterPlaceholder()
                        : CachedNetworkImage(
                            imageUrl:
                                'https://image.tmdb.org/t/p/w185${selected.posterPath}',
                            fit: BoxFit.cover))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(selected.title ?? 'Untitled',
                      style: const TextStyle(
                          color: FlixieColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Selected for this Watch Plan',
                      style: TextStyle(
                          color: FlixieColors.success,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ])),
            const Icon(Icons.check_circle_rounded, color: FlixieColors.success),
          ]),
        ]),
      ),
    ]);
  }
}

class _OtherMovieOptionsMenu extends StatelessWidget {
  const _OtherMovieOptionsMenu({required this.alternatives});

  final List<WatchPlanCandidate> alternatives;

  @override
  Widget build(BuildContext context) => PopupMenuButton<void>(
        tooltip: 'View other movie options',
        padding: EdgeInsets.zero,
        splashRadius: 22,
        itemBuilder: (context) => [
          PopupMenuItem<void>(
            enabled: false,
            child: Text(
              '${alternatives.length} other ${alternatives.length == 1 ? 'option' : 'options'}',
              style: const TextStyle(
                color: FlixieColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          ...alternatives.map(
            (candidate) => PopupMenuItem<void>(
              enabled: false,
              child: Text(candidate.title ?? 'Untitled',
                  style: const TextStyle(color: FlixieColors.light)),
            ),
          ),
        ],
        child: Semantics(
          button: true,
          label:
              'View ${alternatives.length} other movie ${alternatives.length == 1 ? 'option' : 'options'}',
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('${alternatives.length} other',
                style: const TextStyle(
                    color: FlixieColors.primaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
            const Icon(Icons.expand_more_rounded,
                color: FlixieColors.primaryText, size: 18),
          ]),
        ),
      );
}

class _MoviePosterPlaceholder extends StatelessWidget {
  const _MoviePosterPlaceholder();

  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFF1E2D40),
        child: const Center(
          child: Icon(Icons.movie_outlined, color: FlixieColors.medium),
        ),
      );
}
