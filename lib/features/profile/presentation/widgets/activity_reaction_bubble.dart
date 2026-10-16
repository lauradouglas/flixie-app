import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/pip_reaction.dart';
import 'package:flixie_app/models/activity_reaction.dart';

Future<Object?> showActivityReactionBubble(
    BuildContext context, BuildContext anchor,
    {String? current, bool canReply = false}) {
  return showModalBottomSheet<Object>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: BoxConstraints(
        minWidth: MediaQuery.sizeOf(context).shortestSide >= 600
            ? MediaQuery.sizeOf(context).width
            : 0,
        maxWidth: MediaQuery.sizeOf(context).width,
        maxHeight: MediaQuery.sizeOf(context).height * .7),
    builder: (sheet) => SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('React with Pip', style: Theme.of(sheet).textTheme.titleLarge),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (context, constraints) {
            final largeText = MediaQuery.textScalerOf(context).scale(16) > 20;
            final columns = largeText || constraints.maxWidth < 330
                ? 2
                : constraints.maxWidth < 500
                    ? 3
                    : 4;
            final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
            return Wrap(spacing: 8, runSpacing: 8, children: [
              for (final reaction in ActivityReaction.selectable)
                SizedBox(
                    width: width,
                    child: Tooltip(
                        message: reaction.label,
                        child: Semantics(
                          selected: current == reaction.emoji,
                          button: true,
                          label: reaction.label,
                          child: Material(
                            color: current == reaction.emoji
                                ? FlixieColors.primary.withValues(alpha: .15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => Navigator.of(sheet).pop(reaction),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 4),
                                child: Column(children: [
                                  PipReaction(reaction.emoji, size: 48),
                                  const SizedBox(height: 6),
                                  Text(reaction.label,
                                      textAlign: TextAlign.center),
                                ]),
                              ),
                            ),
                          ),
                        ))),
            ]);
          }),
          if (canReply) ...[
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('Reply in chat'),
              onTap: () => Navigator.of(sheet).pop('reply'),
            ),
          ],
        ]),
      ),
    ),
  );
}
