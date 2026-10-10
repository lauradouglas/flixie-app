import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/features/social/data/chat_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class GroupChatRequestSheet extends StatefulWidget {
  const GroupChatRequestSheet(
      {super.key,
      required this.message,
      required this.messages,
      required this.request,
      required this.currentUserId,
      required this.conversationId,
      required this.memberUsernames,
      required this.members,
      required this.isCurrent});
  final ChatMessage message;
  final List<ChatMessage> messages;
  final GroupWatchRequest? request;
  final String? currentUserId;
  final String conversationId;
  final Map<String, String> memberUsernames;
  final Map<String, GroupMember> members;
  final bool Function() isCurrent;
  @override
  State<GroupChatRequestSheet> createState() => _GroupChatRequestSheetState();
}

class _GroupChatRequestSheetState extends State<GroupChatRequestSheet> {
  final replyController = TextEditingController();
  bool isSendingReply = false;
  @override
  void dispose() {
    replyController.dispose();
    super.dispose();
  }

  Widget _modalCountPill(String label, Color color) =>
      FlixiePill.label(label: Text(label));
  @override
  Widget build(BuildContext context) {
    final msg = widget.message;
    final req = widget.request;
    final currentUserId = widget.currentUserId;
    final allMessages = widget.messages;
    final payload = msg.watchRequestPayload;
    final movieTitle =
        req?.movieTitle ?? payload?['movieTitle'] as String? ?? 'Watch Plan';
    final posterPath = req?.moviePosterPath ??
        payload?['moviePosterPath'] as String? ??
        payload?['posterPath'] as String?;
    final requestMessage = [
      req?.message,
      payload?['message'] as String?,
      (payload?['metadata'] as Map<String, dynamic>?)?['message'] as String?,
    ]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .firstOrNull;
    final requesterUsername = req?.requesterUsername ??
        payload?['requesterUsername'] as String? ??
        msg.senderUsername;
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : null;
    final memberStatuses = req?.memberStatuses ?? <GroupRequestMemberStatus>[];

    // Collect thread replies (messages whose replyToMessageId = this message)
    final replies = allMessages
        .where((m) => m.replyToMessageId == msg.id)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: context.colors.medium.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                children: [
                  // Poster + title row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 80,
                          height: 120,
                          child: posterUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: posterUrl,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => Container(
                                      color: context
                                          .colors.tabBarBackgroundFocused),
                                  errorWidget: (_, __, ___) => Container(
                                    color:
                                        context.colors.tabBarBackgroundFocused,
                                    child: Center(
                                        child: Icon(Icons.movie_outlined,
                                            color: context.colors.medium,
                                            size: 28)),
                                  ),
                                )
                              : Container(
                                  decoration: BoxDecoration(
                                    color:
                                        context.colors.tabBarBackgroundFocused,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                      child: Icon(Icons.movie_outlined,
                                          color: context.colors.medium,
                                          size: 28)),
                                ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(movieTitle,
                                style: TextStyle(
                                    color: context.colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700)),
                            if (requesterUsername != null) ...[
                              const SizedBox(height: 4),
                              Text('Created by @$requesterUsername',
                                  style: TextStyle(
                                      color: context.colors.medium,
                                      fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (requestMessage != null && requestMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: FlixieColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                FlixieColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Text(requestMessage,
                          style: TextStyle(
                              color: context.colors.light,
                              fontSize: 13,
                              fontStyle: FontStyle.italic)),
                    ),
                  ],
                  // Responses - grouped by status
                  if (memberStatuses.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('RESPONSES',
                            style: TextStyle(
                                color: context.colors.medium,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                        const Spacer(),
                        if (req?.acceptedCount != null &&
                            req!.acceptedCount > 0)
                          _modalCountPill(
                              '✓ ${req.acceptedCount}', context.colors.success),
                        if (req?.maybeCount != null && req!.maybeCount > 0) ...[
                          const SizedBox(width: 4),
                          _modalCountPill(
                              '~ ${req.maybeCount}', context.colors.warning),
                        ],
                        if (req?.declinedCount != null &&
                            req!.declinedCount > 0) ...[
                          const SizedBox(width: 4),
                          _modalCountPill(
                              '✗ ${req.declinedCount}', context.colors.danger),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    for (final group in [
                      (
                        'ACCEPTED',
                        context.colors.success,
                        Icons.check_circle_outline
                      ),
                      ('MAYBE', context.colors.warning, Icons.help_outline),
                      (
                        'DECLINED',
                        context.colors.danger,
                        Icons.cancel_outlined
                      ),
                    ]) ...[
                      ...memberStatuses
                          .where((s) => s.status == group.$1)
                          .map((s) {
                        final name = s.username?.isNotEmpty == true
                            ? s.username!
                            : s.memberId
                                .substring(0, s.memberId.length.clamp(0, 6));
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              ProfileAvatarView(
                                avatar: s.avatar,
                                fallbackText: name.isNotEmpty
                                    ? name[0].toUpperCase()
                                    : '?',
                                fallbackColor: group.$2,
                                size: 28,
                                profileBadges: s.profileBadges,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text('@$name',
                                    style: TextStyle(
                                        color: context.colors.light,
                                        fontSize: 13)),
                              ),
                              Icon(group.$3, size: 14, color: group.$2),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                  // Thread replies
                  const SizedBox(height: 16),
                  Text(
                      replies.isEmpty
                          ? 'No replies yet'
                          : 'REPLIES (${replies.length})',
                      style: TextStyle(
                          color: context.colors.medium,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 8),
                  if (replies.isEmpty)
                    Text('Be the first to comment!',
                        style: TextStyle(
                            color: context.colors.medium, fontSize: 13))
                  else
                    ...replies.map((r) {
                      final rUsername = r.senderUsername ??
                          widget.memberUsernames[r.senderId] ??
                          r.senderId
                              .substring(0, r.senderId.length.clamp(0, 6));
                      final isMe = r.senderId == currentUserId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ProfileAvatarView(
                              avatar: widget.members[r.senderId]?.avatar,
                              profileBadges:
                                  widget.members[r.senderId]?.profileBadges ??
                                      const [],
                              fallbackText: rUsername.isNotEmpty
                                  ? rUsername[0].toUpperCase()
                                  : '?',
                              size: 28,
                              fallbackColor: FlixieColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(isMe ? 'You' : '@$rUsername',
                                      style: TextStyle(
                                          color: context.colors.medium,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 2),
                                  Text(r.text,
                                      style: TextStyle(
                                          color: context.colors.light,
                                          fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            // Reply input
            Container(
              padding: EdgeInsets.fromLTRB(
                  12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 8),
              decoration: BoxDecoration(
                color: context.colors.tabBarBackgroundFocused,
                border:
                    Border(top: BorderSide(color: context.colors.tabBarBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: replyController,
                        style: TextStyle(color: context.colors.light),
                        textInputAction: TextInputAction.send,
                        decoration: InputDecoration(
                          hintText: 'Reply to this Watch Plan…',
                          hintStyle: TextStyle(color: context.colors.medium),
                          filled: true,
                          fillColor: context.colors.tabBarBackground,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (isSendingReply)
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: FlixieColors.primary),
                      )
                    else
                      IconButton(
                        onPressed: () async {
                          final text = replyController.text.trim();
                          if (text.isEmpty ||
                              isSendingReply ||
                              !widget.isCurrent()) {
                            return;
                          }
                          final cId = widget.conversationId;
                          final uid = widget.currentUserId;
                          if (uid == null) return;
                          setState(() => isSendingReply = true);
                          replyController.clear();
                          try {
                            await ChatService.sendMessage(
                              conversationId: cId,
                              senderId: uid,
                              text: text,
                              replyToMessageId: msg.id,
                            );
                            if (context.mounted && widget.isCurrent()) {
                              Navigator.pop(context);
                            }
                          } catch (_) {
                            if (context.mounted && widget.isCurrent()) {
                              ScaffoldMessenger.of(context).showFlixieToast(
                                FlixieToast(
                                    type: FlixieToastType.error,
                                    content: const Text('Failed to send reply'),
                                    backgroundColor: context.colors.danger),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => isSendingReply = false);
                            }
                          }
                        },
                        icon: const Icon(Icons.send_rounded,
                            color: FlixieColors.primary),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
