import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../chat_bubble.dart';
import '../chat_read_observer.dart';
import '../watch_request_chat_card.dart';

class GroupChatMessages extends StatelessWidget {
  const GroupChatMessages(
      {super.key,
      required this.conversationId,
      required this.groupId,
      required this.currentUserId,
      required this.active,
      required this.messages,
      required this.members,
      required this.memberUsernames,
      required this.requests,
      required this.messageRequestIds,
      required this.responses,
      required this.respondingIds,
      required this.onRespond,
      required this.onRequestDetail});
  final String conversationId, groupId;
  final String? currentUserId;
  final bool active;
  final List<ChatMessage> messages;
  final Map<String, GroupMember> members;
  final Map<String, String> memberUsernames, messageRequestIds, responses;
  final Map<String, GroupWatchRequest> requests;
  final Set<String> respondingIds;
  final void Function(String, WatchResponseDecision) onRespond;
  final void Function(ChatMessage, List<ChatMessage>, GroupWatchRequest?)
      onRequestDetail;
  @override
  Widget build(BuildContext context) {
    return ChatReadObserver(
        conversationId: conversationId,
        active: active,
        child: ListView.builder(
          reverse: true,
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (_, i) {
            final msg = messages[i];
            final isMe = msg.senderId == currentUserId;
            if (!isMe && SafetyService.isBlocked(msg.senderId)) {
              return const SizedBox.shrink();
            }

            if (msg.type == 'watch_request') {
              // Resolve to a postgres UUID.
              // After the BE sets pgGroupRequestId on the message doc,
              // msg.watchRequestId IS the postgres UUID. Until then,
              // fall back to the messageRequestIds map built from the
              // Firestore watchRequests subcollection.
              final pgId = msg.watchRequestId ?? messageRequestIds[msg.id];
              final cachedReq =
                  requests[pgId] ?? requests[messageRequestIds[msg.id]];
              final respondKey = pgId ?? msg.id;
              final optimisticStatus = responses[respondKey];
              String? myStatus = optimisticStatus;
              if (myStatus == null &&
                  cachedReq != null &&
                  currentUserId != null) {
                myStatus = cachedReq.memberStatuses
                        .where((s) => s.memberId == currentUserId)
                        .map((s) => s.status)
                        .where((s) =>
                            s == 'ACCEPTED' || s == 'DECLINED' || s == 'MAYBE')
                        .firstOrNull ??
                    cachedReq.currentUserResponse?.apiValue;
              }
              return WatchRequestChatCard(
                msg: msg,
                senderAvatar: members[msg.senderId]?.avatar,
                senderProfileBadges:
                    members[msg.senderId]?.profileBadges ?? const [],
                cachedRequest: cachedReq,
                currentUserId: currentUserId,
                myStatus: myStatus,
                memberUsernames: memberUsernames,
                isResponding: respondingIds.contains(respondKey),
                onAccept: () =>
                    onRespond(respondKey, WatchResponseDecision.accepted),
                onDecline: () =>
                    onRespond(respondKey, WatchResponseDecision.declined),
                onMaybe: () =>
                    onRespond(respondKey, WatchResponseDecision.maybe),
                onTap: () {
                  if (cachedReq != null) {
                    context.push(
                        '/groups/$groupId?tab=requests&requestId=${cachedReq.databaseRequestId ?? cachedReq.id}');
                  } else {
                    onRequestDetail(msg, messages, cachedReq);
                  }
                },
                onLongPress: isMe
                    ? null
                    : () => SafetyActions.contentMenu(
                          context,
                          targetType: 'WATCH_REQUEST_MESSAGE',
                          targetId: msg.id,
                          reportedUserId: msg.senderId,
                          username: msg.senderUsername ??
                              memberUsernames[msg.senderId] ??
                              'User',
                          contentPreview:
                              msg.watchRequestPayload?['message'] as String? ??
                                  msg.text,
                        ),
              );
            }

            // Regular text bubble
            final sid = msg.senderId;
            final username = msg.senderUsername ??
                memberUsernames[sid] ??
                sid.substring(0, sid.length.clamp(0, 6));
            final member = members[sid];
            final startsSenderRun =
                i == messages.length - 1 || messages[i + 1].senderId != sid;
            return ChatBubble(
              currentUserId: currentUserId,
              currentUsername: context.read<AuthProvider>().dbUser?.username,
              message: msg.text,
              senderUsername: username,
              isMe: isMe,
              sentAt: msg.createdAt,
              avatar: member?.avatar,
              initials: member?.initials,
              profileBadges: member?.profileBadges ?? const [],
              showSenderLabel: !isMe && startsSenderRun,
              onSenderTap: isMe ? null : () => context.push('/friends/$sid'),
              replyTo: msg.replyToMessageId != null ? '↩ replied' : null,
              onLongPress: isMe
                  ? null
                  : () => SafetyActions.contentMenu(
                        context,
                        targetType: 'GROUP_MESSAGE',
                        targetId: msg.id,
                        reportedUserId: sid,
                        username: username,
                        contentPreview: msg.text,
                      ),
            );
          },
        ));
  }
}
