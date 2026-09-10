import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/models/watch_request.dart';

class FriendParticipantsSection extends StatefulWidget {
  const FriendParticipantsSection({
    super.key,
    required this.request,
    required this.other,
  });

  final WatchRequest request;
  final WatchRequestUser? other;

  @override
  State<FriendParticipantsSection> createState() =>
      _FriendParticipantsSectionState();
}

class _FriendParticipantsSectionState extends State<FriendParticipantsSection> {
  final Map<String, ProfileAvatar?> _resolvedAvatars = {};

  @override
  void initState() {
    super.initState();
    _resolveMissingAvatars();
  }

  @override
  void didUpdateWidget(covariant FriendParticipantsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.request.id != widget.request.id) {
      _resolveMissingAvatars();
    }
  }

  Future<void> _resolveMissingAvatars() async {
    final users = [
      widget.request.requester,
      widget.request.recipient,
      widget.other,
    ]
        .whereType<WatchRequestUser>()
        .where((user) => user.avatar == null)
        .toList();
    if (users.isEmpty) return;
    final profiles = await Future.wait(users.map((user) async {
      try {
        final profile = await UserService.getUserById(user.id);
        return (id: user.id, avatar: profile.avatar);
      } catch (_) {
        return (id: user.id, avatar: null);
      }
    }));
    if (!mounted) return;
    setState(() {
      for (final profile in profiles) {
        if (profile.avatar != null) {
          _resolvedAvatars[profile.id] = profile.avatar;
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final other = widget.other;
    final users = request.participants
        .map((participant) => participant.user)
        .whereType<WatchRequestUser>()
        .toList(growable: false);
    final visible = users.isNotEmpty
        ? users
        : [request.requester, request.recipient, other]
            .whereType<WatchRequestUser>()
            .toSet()
            .toList(growable: false);
    bool hasAccepted(WatchRequestUser user) {
      final participant = request.participantFor(user.id);
      if (participant?.response.toUpperCase() == 'ACCEPTED') return true;
      if (user.id == request.requesterId) return true;
      // Direct Watch Plans store the invitee's response on the request itself,
      // rather than always returning a participant-response row.
      if (user.id == request.recipientId &&
          (request.isAccepted || request.isScheduled)) {
        return true;
      }
      // Older scheduled requests can omit their individual response rows even
      // though agreeing the schedule required the recipients to accept.
      return request.normalizedScheduleStatus == 'AGREED' ||
          request.isScheduled;
    }

    bool hasDeclined(WatchRequestUser user) =>
        request.participantFor(user.id)?.response.toUpperCase() == 'DECLINED';

    final accepted = visible.where(hasAccepted).length;
    final waiting = visible.length - accepted;
    final schedulingInProgress = request.isAwaitingScheduleApproval;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Participants',
            style: TextStyle(color: FlixieColors.light, fontSize: 13)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 8,
          children: visible
              .map((user) => _participantAvatar(
                    user,
                    accepted: hasAccepted(user),
                    declined: hasDeclined(user),
                    schedulingInProgress:
                        schedulingInProgress && hasAccepted(user),
                  ))
              .toList(growable: false),
        ),
        const SizedBox(height: 6),
        Text(
          accepted == visible.length && visible.isNotEmpty
              ? schedulingInProgress
                  ? 'All $accepted accepted · scheduling in progress'
                  : 'All $accepted accepted'
              : accepted > 0
                  ? schedulingInProgress
                      ? '$accepted accepted · $waiting waiting · scheduling in progress'
                      : '$accepted accepted · $waiting waiting'
                  : 'Waiting for responses',
          style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _participantAvatar(
    WatchRequestUser user, {
    required bool accepted,
    required bool declined,
    required bool schedulingInProgress,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: declined
                      ? FlixieColors.danger
                      : accepted
                          ? FlixieColors.success
                          : FlixieColors.tabBarBorder,
                  width: 2.5,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ProfileAvatarView(
                  avatar: _resolvedAvatars[user.id] ?? user.avatar,
                  fallbackText: user.username.isNotEmpty
                      ? user.username[0].toUpperCase()
                      : '?',
                  fallbackColor: FlixieColors.primary,
                  size: 42,
                ),
              ),
            ),
            if (accepted || declined)
              Positioned(
                top: -3,
                right: -3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: declined
                        ? FlixieColors.danger
                        : schedulingInProgress
                            ? FlixieColors.primary
                            : FlixieColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      declined
                          ? Icons.close_rounded
                          : schedulingInProgress
                              ? Icons.hourglass_top_rounded
                              : Icons.check_rounded,
                      color: Colors.black,
                      size: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 5),
        SizedBox(
          width: 62,
          child: Text(
            user.username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
