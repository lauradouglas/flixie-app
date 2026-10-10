import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/flixie_typography.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../group_watch_plan_selection.dart';
import '../shared/watch_plan_components.dart';
import '../../utils/watch_plan_formatters.dart';

Widget groupPlanPoster(String? path, String? title, double width) =>
    WatchPlanPoster(path: path, title: title, width: width);

Widget groupPlanSurface(Widget child, {Color? border}) =>
    WatchPlanSurface(border: border, child: child);

Widget groupPlanSection(Widget child) => SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: child,
      ),
    );

Widget groupPlanMessage(
  BuildContext context,
  bool processing,
  String title,
  String body, {
  String? action,
  IconData? icon,
  FutureOr<void> Function()? onTap,
}) =>
    groupPlanSection(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: groupPlanSectionTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(body,
              style: groupPlanBody.copyWith(color: context.colors.light)),
          if (action != null && icon != null && onTap != null) ...[
            const SizedBox(height: 18),
            groupPlanPrimary(context, processing, action, icon, onTap),
          ],
        ],
      ),
    );

Widget groupPlanEmpty(
  BuildContext context,
  String title,
  String body, {
  String? action,
  VoidCallback? onTap,
}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.movie_filter_outlined,
            color: context.colors.primaryText,
            size: 38,
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: groupPlanSectionTitle.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            body,
            textAlign: TextAlign.center,
            style: groupPlanBody.copyWith(color: context.colors.light),
          ),
          if (action != null && onTap != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onTap, child: Text(action)),
          ],
        ],
      ),
    );

Widget groupPlanNotice(BuildContext context, String text) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: context.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: context.colors.medium, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: groupPlanBody.copyWith(color: context.colors.light),
            ),
          ),
        ],
      ),
    );

Widget groupPlanStatus(BuildContext context, GroupPlanStatusData state) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(state.icon, color: state.color, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            state.label.toUpperCase(),
            style: TextStyle(
              color: state.color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: .7,
            ),
          ),
        ),
      ],
    );

Widget groupPlanPrimary(
  BuildContext context,
  bool processing,
  String label,
  IconData icon,
  FutureOr<void> Function()? onTap,
) =>
    SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: processing || onTap == null ? null : () => onTap(),
        icon: processing
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon),
        label: Text(label),
      ),
    );

Widget groupPlanOutline(
  BuildContext context,
  bool processing,
  String label,
  IconData icon,
  FutureOr<void> Function() onTap,
) =>
    SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: processing ? null : () => onTap(),
        icon: Icon(icon),
        label: Text(label),
      ),
    );

Widget groupPlanText(
  BuildContext context,
  bool processing,
  String label,
  IconData icon,
  FutureOr<void> Function() onTap,
) =>
    SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: processing ? null : () => onTap(),
        icon: Icon(icon),
        label: Text(label),
      ),
    );

String groupPlanOptionLabel(GroupWatchRequest request) => request
        .candidates.isEmpty
    ? 'Group Watch Plan'
    : '${request.candidates.length} movie ${request.candidates.length == 1 ? 'option' : 'options'}';

String groupPlanTiming(BuildContext context, GroupWatchRequest request) {
  final iso = request.scheduledFor ??
      request.activeScheduleProposal?.proposedFor ??
      request.proposedDate;
  return iso == null || iso.isEmpty
      ? 'Time not set'
      : formatGroupPlanTime(
          context,
          iso,
          dateOnly: request.scheduledFor != null
              ? request.scheduledDateOnly
              : request.activeScheduleProposal?.dateOnly ??
                  request.proposedDateOnly,
        );
}

String formatGroupPlanTime(
  BuildContext context,
  String? iso, {
  bool dateOnly = false,
}) {
  if (dateOnly) {
    return formatWatchPlanDateTime(
      DateTime.tryParse(iso ?? ''),
      dateOnly: true,
    );
  }
  final date = DateTime.tryParse(iso ?? '')?.toLocal();
  if (date == null) return 'Time not set';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]}, ${TimeOfDay.fromDateTime(date).format(context)}';
}

const groupPlanSectionTitle = FlixieTypography.sectionTitle;
const groupPlanBody = TextStyle(color: FlixieColors.light, height: 1.35);
GroupPlanStatusData groupPlanState(
  BuildContext context,
  GroupPlanViewData view,
) =>
    switch (view.stage) {
      GroupPlanStage.declined => GroupPlanStatusData(
          view.stage,
          'You declined',
          context.colors.medium,
          Icons.person_remove_outlined,
        ),
      GroupPlanStage.recap => GroupPlanStatusData(
          view.stage,
          'Watched',
          context.colors.success,
          Icons.check_circle_rounded,
        ),
      GroupPlanStage.closed => GroupPlanStatusData(
          view.stage,
          view.request.statusLabel,
          context.colors.medium,
          Icons.block_rounded,
        ),
      GroupPlanStage.finalMovie => GroupPlanStatusData(
          view.stage,
          'Choose final movie',
          context.colors.primaryText,
          Icons.movie_filter_rounded,
        ),
      GroupPlanStage.picking => GroupPlanStatusData(
          view.stage,
          'Picking movies',
          context.colors.primaryText,
          Icons.how_to_vote_outlined,
        ),
      GroupPlanStage.proposal => GroupPlanStatusData(
          view.stage,
          'Time proposal',
          context.colors.secondary,
          Icons.schedule_rounded,
        ),
      GroupPlanStage.scheduled => GroupPlanStatusData(
          view.stage,
          'Scheduled',
          context.colors.success,
          Icons.event_available_rounded,
        ),
      GroupPlanStage.postWatch => GroupPlanStatusData(
          view.stage,
          'Ready to log',
          context.colors.warning,
          Icons.rate_review_outlined,
        ),
      GroupPlanStage.invite => GroupPlanStatusData(
          view.stage,
          'Needs a reply',
          context.colors.warning,
          Icons.mark_email_unread_outlined,
        ),
      GroupPlanStage.chooseTime => GroupPlanStatusData(
          view.stage,
          'Choose a time',
          context.colors.secondary,
          Icons.calendar_month_rounded,
        ),
      GroupPlanStage.waitingMovie => GroupPlanStatusData(
          view.stage,
          'Waiting for creator',
          context.colors.medium,
          Icons.hourglass_top_rounded,
        ),
    };

class GroupPlanStatusData {
  const GroupPlanStatusData(this.stage, this.label, this.color, this.icon);
  final GroupPlanStage stage;
  final String label;
  final Color color;
  final IconData icon;
}
