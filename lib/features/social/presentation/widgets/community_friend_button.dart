import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import '../controllers/community_connections_controller.dart';

class CommunityFriendButton extends StatelessWidget {
  const CommunityFriendButton(
      {super.key,
      required this.connections,
      required this.author,
      this.compact = false});
  final CommunityConnectionsController connections;
  final FriendshipUser author;
  final bool compact;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: connections,
      builder: (context, _) {
        if (author.id == connections.userId ||
            author.id.isEmpty ||
            SafetyService.isBlocked(author.id)) {
          return const SizedBox.shrink();
        }
        final state = connections.stateFor(author.id);
        final busy = connections.busyFor(author.id);
        final label = busy
            ? (state == CommunityConnection.incoming
                ? 'Accepting…'
                : 'Sending…')
            : switch (state) {
                CommunityConnection.unknown => connections.failed
                    ? 'Retry friend status'
                    : 'Checking friendship…',
                CommunityConnection.available => 'Add friend',
                CommunityConnection.outgoing => 'Request sent',
                CommunityConnection.incoming => 'Accept request',
                CommunityConnection.friends => 'Friends',
              };
        final canConnect = state == CommunityConnection.available ||
            state == CommunityConnection.incoming;
        if (compact &&
            (state == CommunityConnection.friends ||
                state == CommunityConnection.outgoing)) {
          return Semantics(
              label: label,
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                        state == CommunityConnection.friends
                            ? Icons.check_rounded
                            : Icons.schedule,
                        size: 14,
                        color: context.colors.light),
                    const SizedBox(width: 4),
                    Text(label,
                        style: TextStyle(
                            fontSize: 12,
                            color: context.colors.light,
                            fontWeight: FontWeight.w500))
                  ])));
        }
        return TextButton.icon(
          style: compact
              ? TextButton.styleFrom(
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(44, 44))
              : null,
          icon: Icon(state == CommunityConnection.friends
              ? Icons.how_to_reg_outlined
              : state == CommunityConnection.outgoing
                  ? Icons.schedule
                  : Icons.person_add_alt_1_outlined),
          label: state == CommunityConnection.unknown && !connections.failed
              ? const SizedBox(width: 72, height: 14, child: SkeletonBox())
              : Text(label),
          onPressed: busy
              ? null
              : state == CommunityConnection.unknown && connections.failed
                  ? connections.refresh
                  : !canConnect
                      ? null
                      : () async {
                          try {
                            await connections.connect(author);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Couldn’t update the friend request. Please try again.')));
                            }
                          }
                        },
        );
      });
}
