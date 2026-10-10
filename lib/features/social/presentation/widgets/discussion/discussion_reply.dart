import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../community_mention_text.dart';

ButtonStyle _threadLinkStyle(BuildContext context, {bool parent = false}) =>
    TextButton.styleFrom(
      foregroundColor:
          parent ? context.colors.light : context.colors.primaryText,
      textStyle: const TextStyle(
          fontFamily: 'Manrope',
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.6,
          letterSpacing: 0),
      padding: EdgeInsets.zero,
      minimumSize: const Size(44, 44),
      alignment: Alignment.centerLeft,
      tapTargetSize: MaterialTapTargetSize.padded,
    );

TextStyle discussionBodyStyle(BuildContext context) => TextStyle(
    fontFamily: 'Manrope',
    fontSize: 15,
    height: 1.7,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: context.colors.light);

class DiscussionReply extends StatelessWidget {
  const DiscussionReply(
      {super.key,
      required this.reply,
      required this.author,
      required this.member,
      required this.highlighted,
      required this.onFocus,
      required this.onReply});
  final Map<String, dynamic> reply;
  final Widget author;
  final bool member, highlighted;
  final ValueChanged<String> onFocus;
  final VoidCallback onReply;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
      key: ValueKey('reply-highlight-${reply['id']}'),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
          color: highlighted
              ? context.colors.primaryText.withValues(alpha: .16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10)),
      child: _commentContent(context));

  Widget _commentContent(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        author,
        if (reply['parentReply'] != null)
          TextButton.icon(
            style: _threadLinkStyle(context, parent: true),
            onPressed: () => onFocus(reply['parentReply']['id']),
            icon: const Icon(Icons.reply, size: 16),
            label: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Replying to '),
              TextSpan(
                  text: '@${reply['parentReply']['user']['username']}',
                  style: TextStyle(color: context.colors.primaryText))
            ])),
          )
        else if (reply['parentReplyId'] != null)
          const Text('Replying to an unavailable comment'),
        const SizedBox(height: 10),
        CommunityMentionText(reply['body'] ?? '',
            style: discussionBodyStyle(context)),
        if (member)
          TextButton.icon(
              style: _threadLinkStyle(context),
              onPressed: onReply,
              icon: const Icon(Icons.reply, size: 17),
              label: const Text('Reply')),
      ]));
}
