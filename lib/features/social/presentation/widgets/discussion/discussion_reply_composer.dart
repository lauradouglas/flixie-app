import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/notification_opt_in.dart';
import '../../../data/community_space_service.dart';
import '../community_mention_suggestions.dart';
import 'discussion_reply.dart';

class DiscussionReplyComposer extends StatelessWidget {
  const DiscussionReplyComposer(
      {super.key,
      required this.postedReply,
      required this.replyTo,
      required this.sending,
      required this.sendError,
      required this.onSend,
      required this.onCancelTarget,
      required this.replyFocus,
      required this.body,
      required this.mentions,
      required this.discussionId,
      required this.communityId,
      required this.service});
  final bool postedReply, sending;
  final Map<String, dynamic>? replyTo;
  final String? sendError;
  final VoidCallback onSend, onCancelTarget;
  final FocusNode replyFocus;
  final TextEditingController body;
  final Map<String, String> mentions;
  final String discussionId;
  final int communityId;
  final CommunitySpaceService service;
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
              top: BorderSide(
                  color: context.colors.light.withValues(alpha: .2)))),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .38),
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (postedReply)
                  const NotificationOptIn(
                      message:
                          'Keep the conversation going. Enable notifications for replies and other Flixie updates. You can manage them in Settings.'),
                if (replyTo != null)
                  Row(children: [
                    Icon(Icons.reply,
                        size: 18, color: context.colors.primaryText),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'Replying to @${replyTo!['user']['username']}',
                            style: TextStyle(
                                fontSize: 12,
                                color: context.colors.primaryText))),
                    IconButton(
                        tooltip: 'Cancel reply target',
                        onPressed: sending ? null : onCancelTarget,
                        icon: const Icon(Icons.close, size: 18)),
                  ]),
                Material(
                    color: Colors.transparent,
                    child: CommunityMentionSuggestions(
                        discussionId: discussionId,
                        controller: body,
                        communityId: communityId,
                        service: service,
                        selected: mentions)),
                if (sendError != null)
                  Row(children: [
                    Expanded(
                        child: Text(sendError!,
                            style: TextStyle(
                                color: context.colors.light, fontSize: 12))),
                    TextButton(
                        onPressed: sending ? null : onSend,
                        child: const Text('Try again')),
                  ]),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                      child: TextField(
                          focusNode: replyFocus,
                          controller: body,
                          style: discussionBodyStyle(context),
                          enabled: !sending,
                          maxLength: 3000,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Your reply',
                              hintText: 'Add to the conversation…',
                              labelStyle: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w400),
                              hintStyle: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w400),
                              counterText: '',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false))),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                      valueListenable: body,
                      builder: (_, value, __) => IconButton.filled(
                          tooltip: sending ? 'Posting…' : 'Post reply',
                          onPressed: sending || value.text.trim().isEmpty
                              ? null
                              : onSend,
                          icon: sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.arrow_upward))),
                ]),
                Text('@ a friend in this community or someone in this thread',
                    style:
                        TextStyle(fontSize: 11, color: context.colors.light)),
              ]))));
}
