import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';
import 'friend_plan_button.dart';
import 'friend_plan_styles.dart';

class FriendPlanChoices extends StatelessWidget {
  const FriendPlanChoices(
      {super.key,
      required this.request,
      required this.myUserId,
      required this.showFinalChoices,
      required this.candidateChoiceDraft,
      required this.onReviewChanged,
      required this.onSaveCandidateChoices,
      required this.onAddCandidate,
      required this.onRemoveCandidate,
      required this.onSelectCandidate,
      required this.onToggleCandidateChoice,
      this.busy = false});
  final WatchRequest request;
  final String myUserId;
  final bool showFinalChoices, busy;
  final Set<String> candidateChoiceDraft;
  final ValueChanged<bool> onReviewChanged;
  final Future<bool> Function() onSaveCandidateChoices;
  final VoidCallback onAddCandidate;
  final ValueChanged<String> onRemoveCandidate,
      onSelectCandidate,
      onToggleCandidateChoice;
  WatchRequest get r => request;
  bool get isCreator => r.requesterId == myUserId;
  String get friend => r.otherUser(myUserId)?.username ?? 'your friend';
  @override
  Widget build(BuildContext context) {
    if (showFinalChoices && !isCreator) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Your picks are saved. $friend will finalise the movie.',
            style: friendPlanBody.copyWith(color: context.colors.light)),
        _button(
            'Edit my picks', Icons.edit_outlined, () => onReviewChanged(false),
            primary: false),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!showFinalChoices) ...[
        Text('What could you watch?',
            style: friendPlanTitle
                .copyWith(color: context.colors.textPrimary)
                .copyWith(fontSize: 22)),
        const SizedBox(height: 6),
      ],
      Text(
          showFinalChoices
              ? 'Choose the final movie for your plan.'
              : 'Select every title you would happily watch.',
          style: friendPlanBody.copyWith(color: context.colors.light)),
      const SizedBox(height: 16),
      for (final candidate in r.candidates)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _choiceRow(context, candidate),
        ),
      if ((isCreator || !showFinalChoices) &&
          r.candidates.where((c) => c.addedByUserId == myUserId).length < 3)
        Center(
            child: TextButton.icon(
          onPressed: busy ? null : onAddCandidate,
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Add another option'),
          style:
              TextButton.styleFrom(foregroundColor: context.colors.primaryText),
        )),
      if (!showFinalChoices)
        _button('Save my picks', Icons.playlist_add_check, () async {
          final saved = await onSaveCandidateChoices();
          if (context.mounted && saved) onReviewChanged(true);
        })
      else if (!isCreator)
        _button(
            'Edit my picks', Icons.edit_outlined, () => onReviewChanged(false),
            primary: false),
    ]);
  }

  Widget _choiceRow(BuildContext context, WatchPlanCandidate candidate) {
    final selected = candidateChoiceDraft.contains(candidate.id);
    final approvals = [r.requesterId, r.recipientId]
        .where((id) => id == myUserId ? selected : candidate.selectedBy(id))
        .length;
    final both = approvals == 2;
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: both
            ? context.colors.success.withValues(alpha: .08)
            : context.colors.background.withValues(alpha: .35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: both
                  ? context.colors.success
                  : selected
                      ? FlixieColors.primary
                      : context.colors.tabBarBorder,
              width: both || selected ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy
              ? null
              : () => showFinalChoices
                  ? onSelectCandidate(candidate.id)
                  : onToggleCandidateChoice(candidate.id),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              WatchPlanPoster(
                  path: candidate.posterPath,
                  title: candidate.title,
                  width: 48),
              const SizedBox(width: 11),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(candidate.title ?? 'Movie option',
                        style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        both
                            ? 'Both would watch'
                            : '$approvals of 2 would watch',
                        style: TextStyle(
                            color: both
                                ? context.colors.success
                                : context.colors.medium,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ])),
              if (showFinalChoices) ...[
                const SizedBox(width: 10),
                SizedBox(
                  width: 100,
                  child: FilledButton(
                    onPressed:
                        busy ? null : () => onSelectCandidate(candidate.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: FlixieColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Choose', textAlign: TextAlign.center),
                  ),
                ),
              ],
              if (!showFinalChoices)
                Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected
                        ? context.colors.success
                        : context.colors.medium),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _button(String label, IconData icon, VoidCallback? action,
          {bool primary = true}) =>
      FriendPlanButton(
          label: label,
          icon: icon,
          action: action,
          primary: primary,
          busy: busy);
}
