import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_reaction.dart';

Future<Object?> showActivityReactionBubble(
    BuildContext context, BuildContext anchor,
    {String? current, bool canReply = false}) async {
  final box = anchor.findRenderObject() as RenderBox;
  final overlay = Navigator.of(context, rootNavigator: true)
      .overlay!
      .context
      .findRenderObject() as RenderBox;
  final origin = box.localToGlobal(Offset.zero, ancestor: overlay);
  // Two 48px rows, a 16px divider and 16px menu padding when Reply is present.
  final bubbleHeight = canReply ? 128.0 : 64.0;
  final bubbleTop = origin.dy - bubbleHeight - 8;
  return showMenu<Object>(
    context: context,
    useRootNavigator: true,
    position: RelativeRect.fromRect(
        Rect.fromLTWH(origin.dx, bubbleTop, box.size.width, 0),
        Offset.zero & overlay.size),
    menuPadding: const EdgeInsets.symmetric(vertical: 8),
    color: context.colors.surface,
    elevation: 8,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: context.colors.tabBarBorder)),
    constraints:
        BoxConstraints.tightFor(width: (overlay.size.width - 32).clamp(0, 344)),
    items: [
      PopupMenuItem<Object>(
        enabled: false,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(children: [
          for (final reaction in ActivityReaction.values)
            Expanded(
                child: Semantics(
              selected: current == reaction.emoji,
              child: Tooltip(
                message: reaction.label,
                child: Material(
                  color: current == reaction.emoji
                      ? FlixieColors.primary
                      : Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.of(context, rootNavigator: true)
                          .pop(reaction),
                      child: SizedBox(
                          height: 48,
                          child: Center(
                              child: Text(reaction.emoji,
                                  style: const TextStyle(fontSize: 26))))),
                ),
              ),
            )),
        ]),
      ),
      if (canReply) const PopupMenuDivider(),
      if (canReply)
        PopupMenuItem<Object>(
            value: 'reply',
            child: Row(children: [
              Icon(Icons.reply_rounded, color: context.colors.primaryText),
              const SizedBox(width: 12),
              const Text('Reply in chat')
            ])),
    ],
  );
}
