import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_types.dart';
import 'package:flixie_app/models/watch_request.dart';

class FriendPlanActions extends StatelessWidget {
  const FriendPlanActions({
    super.key,
    required this.request,
    required this.myUserId,
    required this.busyAction,
    required this.acceptanceScheduleDraft,
    required this.dateLabel,
    required this.onAccept,
    required this.onDecline,
    required this.onSuggestSchedule,
    required this.onSuggestDifferentTime,
    required this.onEditLocation,
    required this.onRespondToProposal,
    required this.onConfirmWatched,
    this.invitationDecisionOnly = false,
    this.includeWatchConfirmation = true,
  });

  final WatchRequest request;
  final String myUserId;
  final FriendWatchPlanAction? busyAction;
  final FriendAcceptanceScheduleDraft? acceptanceScheduleDraft;
  final String Function(DateTime?) dateLabel;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onSuggestSchedule;
  final VoidCallback onSuggestDifferentTime;
  final VoidCallback onEditLocation;
  final void Function(WatchScheduleProposal proposal, String decision)
      onRespondToProposal;
  final VoidCallback onConfirmWatched;
  final bool invitationDecisionOnly;
  final bool includeWatchConfirmation;

  bool get _isIncomingInvitation =>
      request.isPending &&
      request.requesterId != myUserId &&
      (request.recipientId == myUserId ||
          request.participantFor(myUserId) != null);

  @override
  Widget build(BuildContext context) => invitationDecisionOnly
      ? _buildInvitationDecisionActions()
      : _buildActions(includeWatchConfirmation: includeWatchConfirmation);

  Widget _buildActions({bool includeWatchConfirmation = true}) {
    if (busyAction != null) {
      return const SizedBox(
        height: 38,
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_isIncomingInvitation) {
      return const SizedBox.shrink();
    }

    if ((!request.isAccepted && !request.isScheduled) ||
        !request.isWatchRequest) {
      return const SizedBox.shrink();
    }

    if (includeWatchConfirmation && request.canConfirmWatchedFor(myUserId)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Did you watch it?',
            style: TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _ActionPrimaryButton(
                  label: 'Mark as watched',
                  onPressed: onConfirmWatched,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionSecondaryButton(
                  label: 'Suggest another time',
                  onPressed: onSuggestDifferentTime,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (request.normalizedWatchedStatus == 'PARTIAL' ||
        request.normalizedWatchedStatus == 'WATCHED' ||
        request.normalizedWatchedStatus == 'NOT_WATCHED') {
      return const SizedBox.shrink();
    }

    final proposal = request.latestPendingProposal;
    if (request.normalizedScheduleStatus == 'PROPOSED' && proposal != null) {
      if (proposal.proposerId == myUserId) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActionInlineStateMessage(
              icon: Icons.schedule_outlined,
              text: request.scheduledFor == null
                  ? 'Waiting for them to respond to ${dateLabel(proposal.proposedFor)}'
                  : 'New time proposed for ${dateLabel(proposal.proposedFor)}. Your current plan stays in place until they agree.',
            ),
            const SizedBox(height: 8),
            _ActionIconText(
              icon: Icons.edit_calendar_outlined,
              label: 'Propose a different time',
              onPressed: onSuggestDifferentTime,
            ),
          ],
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlixieColors.warning.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: FlixieColors.warning.withValues(alpha: .6),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    color: FlixieColors.warning, size: 25),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'NEW TIME WAITING FOR YOUR APPROVAL',
                        style: TextStyle(
                          color: FlixieColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: .5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        dateLabel(proposal.proposedFor),
                        style: const TextStyle(
                          color: FlixieColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (request.scheduledFor != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          'Current plan: ${dateLabel(request.scheduledFor)}',
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _ActionPrimaryButton(
              label: 'Accept time',
              onPressed: () => onRespondToProposal(proposal, 'accepted'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => onRespondToProposal(proposal, 'declined'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FlixieColors.danger,
                side: const BorderSide(color: FlixieColors.danger),
                minimumSize: const Size(0, 44),
              ),
              child: const Text('Keep current time'),
            ),
          ),
          const SizedBox(height: 8),
          _ActionIconText(
            icon: Icons.edit_calendar_outlined,
            label: 'Propose another time instead',
            onPressed: onSuggestDifferentTime,
          ),
        ],
      );
    }

    if (request.normalizedScheduleStatus == 'AGREED') {
      final scheduledFor = request.scheduledFor;
      final isFuture =
          scheduledFor != null && scheduledFor.isAfter(DateTime.now());
      if (!isFuture) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: _ActionPrimaryButton(
              label: 'Add to calendar',
              onPressed: () => WatchCalendarService.addScheduledWatch(
                title: request.movie?.title ?? 'Watch together',
                scheduledFor: scheduledFor,
                runtimeMinutes: request.movie?.runtimeMinutes,
                note: request.message,
                location: request.location,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _ActionIconText(
                icon: Icons.edit_calendar_outlined,
                label: 'Propose a new time',
                onPressed: onSuggestDifferentTime,
              ),
              _ActionIconText(
                icon: Icons.location_on_outlined,
                label: request.location?.trim().isNotEmpty == true
                    ? 'Change location'
                    : 'Add location',
                onPressed: onEditLocation,
              ),
            ],
          ),
        ],
      );
    }

    if (request.normalizedScheduleStatus == 'NONE' ||
        request.normalizedScheduleStatus == 'DECLINED' ||
        request.normalizedScheduleStatus == 'CANCELLED') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Plan the details',
            style: TextStyle(
              color: FlixieColors.light,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Choose a time first, then add a place if you have one.',
            style: TextStyle(color: FlixieColors.medium, fontSize: 12),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final time = _ActionPrimaryButton(
                label: 'Suggest a time',
                onPressed: onSuggestSchedule,
              );
              final location = _ActionSecondaryButton(
                label: request.location?.trim().isNotEmpty == true
                    ? 'Change location'
                    : 'Add a location',
                onPressed: onEditLocation,
              );
              if (constraints.maxWidth >= 600) {
                return Row(children: [
                  Expanded(child: time),
                  const SizedBox(width: 10),
                  Expanded(child: location),
                ]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  time,
                  const SizedBox(height: 8),
                  location,
                ],
              );
            },
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildInvitationDecisionActions() {
    final acceptLabel = acceptanceScheduleDraft == null
        ? 'Accept invitation'
        : 'Accept & suggest time';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Respond to invitation',
          style: TextStyle(
            color: FlixieColors.light,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        _ActionPrimaryButton(label: acceptLabel, onPressed: onAccept),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onDecline,
          style: OutlinedButton.styleFrom(
            foregroundColor: FlixieColors.danger,
            side: const BorderSide(color: FlixieColors.danger),
          ),
          child: const Text('Decline'),
        ),
      ],
    );
  }
}

class _ActionInlineStateMessage extends StatelessWidget {
  const _ActionInlineStateMessage({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: FlixieColors.medium),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionPrimaryButton extends StatelessWidget {
  const _ActionPrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: FlixieColors.primary,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}

class _ActionSecondaryButton extends StatelessWidget {
  const _ActionSecondaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: FlixieColors.light,
        side: BorderSide(color: FlixieColors.medium.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _ActionIconText extends StatelessWidget {
  const _ActionIconText({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: FlixieColors.medium,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
