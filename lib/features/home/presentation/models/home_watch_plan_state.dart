import 'package:flutter/material.dart';

import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';

enum HomeWatchPlanStateType {
  invitation,
  groupEveryoneAccepted,
  groupSomeAccepted,
  groupNoOneAccepted,
  chooseMovies,
  waitingForChoices,
  chooseFinalMovie,
  reviewSchedule,
  waitingForScheduleApproval,
  chooseSchedule,
  chooseLocation,
  logAfterOther,
  logWatch,
  waitingForLogs,
  today,
  upcoming,
  recap,
  planning,
}

class HomeWatchPlanState {
  const HomeWatchPlanState({
    required this.plan,
    required this.type,
    required this.priority,
    required this.eyebrow,
    required this.title,
    required this.supportingText,
    required this.actionLabel,
    required this.requiresAttention,
  });

  final WatchRequest plan;
  final HomeWatchPlanStateType type;
  final int priority;
  final String eyebrow;
  final String title;
  final String supportingText;
  final String actionLabel;
  final bool requiresAttention;

  WatchPlanColorRole get colorRole => switch (type) {
        HomeWatchPlanStateType.invitation ||
        HomeWatchPlanStateType.chooseMovies ||
        HomeWatchPlanStateType.chooseFinalMovie ||
        HomeWatchPlanStateType.reviewSchedule ||
        HomeWatchPlanStateType.chooseSchedule ||
        HomeWatchPlanStateType.chooseLocation ||
        HomeWatchPlanStateType.logAfterOther ||
        HomeWatchPlanStateType.logWatch =>
          WatchPlanColorRole.action,
        HomeWatchPlanStateType.groupEveryoneAccepted =>
          WatchPlanColorRole.complete,
        HomeWatchPlanStateType.groupSomeAccepted => WatchPlanColorRole.action,
        HomeWatchPlanStateType.groupNoOneAccepted => WatchPlanColorRole.failed,
        HomeWatchPlanStateType.waitingForChoices ||
        HomeWatchPlanStateType.waitingForScheduleApproval ||
        HomeWatchPlanStateType.waitingForLogs ||
        HomeWatchPlanStateType.today ||
        HomeWatchPlanStateType.upcoming =>
          WatchPlanColorRole.waiting,
        HomeWatchPlanStateType.recap => WatchPlanColorRole.complete,
        HomeWatchPlanStateType.planning => WatchPlanColorRole.neutral,
      };

  IconData get statusIcon => switch (type) {
        HomeWatchPlanStateType.invitation => Icons.chat_bubble_outline_rounded,
        HomeWatchPlanStateType.groupEveryoneAccepted => Icons.groups_rounded,
        HomeWatchPlanStateType.groupSomeAccepted => Icons.group_off_rounded,
        HomeWatchPlanStateType.groupNoOneAccepted => Icons.cancel_outlined,
        HomeWatchPlanStateType.chooseMovies => Icons.ballot_outlined,
        HomeWatchPlanStateType.chooseFinalMovie => Icons.lock_outline_rounded,
        HomeWatchPlanStateType.reviewSchedule => Icons.update_rounded,
        HomeWatchPlanStateType.waitingForScheduleApproval =>
          Icons.hourglass_top_rounded,
        HomeWatchPlanStateType.chooseSchedule => Icons.schedule_rounded,
        HomeWatchPlanStateType.chooseLocation => Icons.location_on_outlined,
        HomeWatchPlanStateType.logAfterOther ||
        HomeWatchPlanStateType.logWatch =>
          Icons.help_outline_rounded,
        HomeWatchPlanStateType.waitingForChoices => Icons.hourglass_top_rounded,
        HomeWatchPlanStateType.waitingForLogs =>
          Icons.check_circle_outline_rounded,
        HomeWatchPlanStateType.today ||
        HomeWatchPlanStateType.upcoming =>
          Icons.event_available_outlined,
        HomeWatchPlanStateType.recap => Icons.celebration_rounded,
        HomeWatchPlanStateType.planning => Icons.movie_filter_outlined,
      };

  String get route => plan.conversationId == '__group_home__'
      ? '/groups/${plan.groupId}?tab=requests&requestId=${plan.id}'
      : '/watch-requests/${plan.id}';
}

HomeWatchPlanState? selectHomeWatchPlanState(
  Iterable<WatchRequest> plans,
  String currentUserId, {
  DateTime? now,
}) =>
    homeWatchPlanStates(plans, currentUserId, now: now).firstOrNull;

/// Returns every live Watch Plan in the same priority order used for the Home
/// carousel. Keeping this shared with the featured-state selector prevents
/// friend and group plans from falling into separate visual systems.
List<HomeWatchPlanState> homeWatchPlanStates(
  Iterable<WatchRequest> plans,
  String currentUserId, {
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final states = plans
      .where((plan) => !plan.isCancelled && !plan.isExpired && !plan.isDeclined)
      .map((plan) => _stateFor(plan, currentUserId, currentTime))
      .whereType<HomeWatchPlanState>()
      .toList();
  states.sort((a, b) {
    final priority = a.priority.compareTo(b.priority);
    if (priority != 0) return priority;
    return _activityDate(b.plan).compareTo(_activityDate(a.plan));
  });
  return states;
}

int homeWatchPlanAttentionCount(
  Iterable<WatchRequest> plans,
  String currentUserId, {
  DateTime? now,
}) =>
    plans
        .map((plan) => _stateFor(plan, currentUserId, now ?? DateTime.now()))
        .whereType<HomeWatchPlanState>()
        .where((state) => state.requiresAttention)
        .length;

HomeWatchPlanState? _stateFor(
  WatchRequest plan,
  String userId,
  DateTime now,
) {
  final isCreator = plan.requesterId == userId;
  final otherUsername = plan.otherUser(userId)?.username.trim();
  final other = otherUsername != null && otherUsername.isNotEmpty
      ? otherUsername
      : 'your friend';
  final companion = plan.groupName?.trim().isNotEmpty == true
      ? plan.groupName!.trim()
      : other;
  final group = plan.groupName?.trim().isNotEmpty == true;
  final options = plan.candidates.length;
  final selectedByMe =
      plan.candidates.where((candidate) => candidate.selectedBy(userId)).length;
  final accepted = plan.hasCurrentUserAccepted == true ||
      plan.participantFor(userId)?.response.toUpperCase() == 'ACCEPTED' ||
      isCreator;
  final groupResponses =
      group ? plan.participants : const <WatchRequestParticipant>[];
  final groupRepliesResolved = groupResponses.isNotEmpty &&
      groupResponses.every((participant) {
        final response = participant.response.toUpperCase();
        return response == 'ACCEPTED' || response == 'DECLINED';
      });
  final acceptedGroupMembers = groupResponses
      .where((participant) => participant.response.toUpperCase() == 'ACCEPTED')
      .length;

  if (groupRepliesResolved && plan.scheduledFor == null) {
    if (acceptedGroupMembers == groupResponses.length) {
      return _state(
          plan,
          HomeWatchPlanStateType.groupEveryoneAccepted,
          3,
          'EVERYONE IS IN',
          plan.watchPlanTitle,
          '$companion is ready to plan the details.',
          'View plan',
          false);
    }
    if (acceptedGroupMembers == 0) {
      return _state(
          plan,
          HomeWatchPlanStateType.groupNoOneAccepted,
          3,
          'NO ONE CAN MAKE IT',
          plan.watchPlanTitle,
          '$companion needs a new plan.',
          'View plan',
          false);
    }
    return _state(
        plan,
        HomeWatchPlanStateType.groupSomeAccepted,
        3,
        'GROUP RESPONSES ARE IN',
        plan.watchPlanTitle,
        '$acceptedGroupMembers of ${groupResponses.length} members are in.',
        'View plan',
        false);
  }
  if (plan.isPending && !isCreator) {
    return _state(
        plan,
        HomeWatchPlanStateType.invitation,
        1,
        'NEEDS YOUR REPLY',
        options > 1 ? '$options movies to choose from' : plan.watchPlanTitle,
        group ? '$companion · Invited by @$other' : 'Invited by @$other',
        'View invitation',
        true);
  }
  final pendingProposal = plan.latestPendingProposal;
  final hasApprovedProposal =
      pendingProposal?.responseFor(userId)?.isAccepted == true;
  if (pendingProposal != null && (isCreator || hasApprovedProposal)) {
    return _state(
        plan,
        HomeWatchPlanStateType.waitingForScheduleApproval,
        5,
        'SCHEDULING',
        _dateTime(pendingProposal.proposedFor),
        group
            ? 'Waiting for $companion to approve the time'
            : 'Waiting for @$other to approve the time',
        'View plan',
        false);
  }
  if (plan.canRespondToProposal(userId)) {
    final proposal = plan.latestPendingProposal!;
    return _state(
        plan,
        HomeWatchPlanStateType.reviewSchedule,
        5,
        'SCHEDULING',
        _dateTime(proposal.proposedFor),
        '${plan.watchPlanTitle} · Suggested by $other',
        'Review time',
        true);
  }
  if (accepted && options > 1 && plan.selectedCandidateId == null) {
    if (!isCreator && selectedByMe == 0) {
      return _state(
          plan,
          HomeWatchPlanStateType.chooseMovies,
          2,
          'CHOOSE YOUR MOVIES',
          '$options movies to choose from',
          group ? companion : 'With @$other',
          'Choose movies',
          true);
    }
    if (isCreator) {
      final peopleWhoChose = plan.candidates
          .expand((candidate) => candidate.selectedByUserIds)
          .toSet();
      final everyoneChosen =
          peopleWhoChose.length >= plan.analyticsParticipantCount;
      if (everyoneChosen) {
        final unanimous = plan.candidates
            .where((candidate) =>
                candidate.selectedByUserIds.length >=
                plan.analyticsParticipantCount)
            .length;
        return _state(
            plan,
            HomeWatchPlanStateType.chooseFinalMovie,
            3,
            'READY TO FINALISE',
            'Everyone has chosen',
            '$unanimous ${unanimous == 1 ? 'movie works' : 'movies work'} for everyone',
            'Choose final movie',
            true);
      }
    }
    return _state(
        plan,
        HomeWatchPlanStateType.waitingForChoices,
        10,
        'CHOICES SAVED',
        'Waiting for @$other',
        'You would watch $selectedByMe of $options movies',
        'View plan',
        false);
  }
  if (group &&
      plan.selectedCandidateId != null &&
      plan.scheduledFor == null &&
      plan.proposedDate != null) {
    if (isCreator) {
      return _state(
          plan,
          HomeWatchPlanStateType.waitingForScheduleApproval,
          5,
          'TIME SUGGESTED',
          _dateTime(plan.proposedDate!),
          'Waiting for $companion to approve the time',
          'View plan',
          false);
    }
    return _state(
        plan,
        HomeWatchPlanStateType.chooseSchedule,
        4,
        'TIME PROPOSED',
        plan.watchPlanTitle,
        _dateTime(plan.proposedDate),
        'Review time',
        true);
  }
  if (plan.selectedCandidateId != null && plan.scheduledFor == null) {
    return _state(
        plan,
        HomeWatchPlanStateType.chooseSchedule,
        4,
        'READY TO SCHEDULE',
        plan.watchPlanTitle,
        group ? companion : 'With $other',
        'Choose a time',
        true);
  }
  final logged = plan.hasCurrentUserConfirmed(userId) ||
      plan.hasCurrentUserLoggedWatch == true ||
      plan.hasCurrentUserCompleted == true;
  final anotherLogged =
      plan.watchConfirmations.any((item) => item.userId != userId);
  final allDirectParticipantsLogged = !group &&
      plan.watchConfirmations
              .where((item) => item.watched)
              .map((item) => item.userId)
              .toSet()
              .length >=
          2;
  if (plan.isCompleted || allDirectParticipantsLogged) {
    return _state(
        plan,
        HomeWatchPlanStateType.recap,
        9,
        'EVERYONE WATCHED',
        'Your recap is ready',
        group ? '${plan.watchPlanTitle} · $companion' : plan.watchPlanTitle,
        'View recap',
        false);
  }
  if (logged && plan.scheduledFor != null) {
    return _state(
        plan,
        HomeWatchPlanStateType.waitingForLogs,
        11,
        'YOUR WATCH IS LOGGED',
        group
            ? '${plan.watchConfirmations.length} of ${plan.analyticsParticipantCount} watches logged'
            : 'Waiting for @$other',
        'Your shared recap will appear when everyone has logged.',
        'View plan',
        false);
  }
  if (anotherLogged && plan.scheduledFor != null) {
    return _state(
        plan,
        HomeWatchPlanStateType.logAfterOther,
        7,
        '@${other.toUpperCase()} LOGGED THEIRS',
        'Your turn',
        'Add your watch to unlock your shared recap.',
        'Log your watch',
        true);
  }
  if (plan.scheduledFor != null && (plan.location?.trim().isEmpty ?? true)) {
    return _state(
        plan,
        HomeWatchPlanStateType.chooseLocation,
        6,
        'ONE THING LEFT',
        'Where are you watching?',
        _dateTime(plan.scheduledFor),
        'Choose location',
        true);
  }
  final scheduled = plan.scheduledFor;
  if (scheduled != null && !scheduled.isAfter(now)) {
    if (!logged) {
      return _state(
          plan,
          HomeWatchPlanStateType.logWatch,
          6,
          'DID YOU WATCH IT?',
          plan.watchPlanTitle,
          'Planned ${_dateTime(scheduled)} · ${group ? companion : 'With @$other'}',
          'Log watch',
          true);
    }
  }
  if (scheduled != null && scheduled.isAfter(now)) {
    final today = _sameDay(scheduled.toLocal(), now.toLocal());
    final scheduleDetail = _dateTime(scheduled);
    return _state(
        plan,
        today ? HomeWatchPlanStateType.today : HomeWatchPlanStateType.upcoming,
        today ? 8 : 10,
        _scheduleCountdown(scheduled, now, today),
        plan.watchPlanTitle,
        'Scheduled $scheduleDetail · ${group ? companion : 'With @$other'}${plan.location == null ? '' : ' · ${plan.location}'}',
        'View plan',
        false);
  }
  return _state(
      plan,
      HomeWatchPlanStateType.planning,
      13,
      'PLANNING TOGETHER',
      plan.watchPlanTitle,
      group ? companion : 'With @$other',
      'View plan',
      false);
}

HomeWatchPlanState _state(
        WatchRequest plan,
        HomeWatchPlanStateType type,
        int priority,
        String eyebrow,
        String title,
        String supporting,
        String action,
        bool attention) =>
    HomeWatchPlanState(
        plan: plan,
        type: type,
        priority: priority,
        eyebrow: eyebrow,
        title: title,
        supportingText: supporting,
        actionLabel: action,
        requiresAttention: attention);

DateTime _activityDate(WatchRequest plan) =>
    plan.lastActivityAt ??
    DateTime.tryParse(plan.updatedAt ?? '') ??
    DateTime.tryParse(plan.createdAt ?? '') ??
    DateTime.fromMillisecondsSinceEpoch(0);
bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
String _time(DateTime? value) {
  if (value == null) return 'TIME TO AGREE';
  final date = value.toLocal();
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  return '$hour:${date.minute.toString().padLeft(2, '0')} ${date.hour < 12 ? 'AM' : 'PM'}';
}

String _scheduleCountdown(DateTime scheduled, DateTime now, bool today) {
  final remaining = scheduled.difference(now);
  if (remaining.inMinutes < 60) {
    final minutes = remaining.inMinutes.clamp(1, 59);
    return 'STARTS IN $minutes MIN';
  }
  if (remaining.inHours < 6) {
    final hours = remaining.inHours + (remaining.inMinutes % 60 == 0 ? 0 : 1);
    return 'STARTS IN $hours ${hours == 1 ? 'HOUR' : 'HOURS'}';
  }
  return today
      ? '${_time(scheduled)} TODAY'
      : _dateTime(scheduled).toUpperCase();
}

String _dateTime(DateTime? value) {
  if (value == null) return 'Choose a time';
  final date = value.toLocal();
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${days[date.weekday - 1]} · ${_time(date)}';
}
