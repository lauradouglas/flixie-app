import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_reaction.dart';

/// Shared artwork for reaction selectors, counts and existing saved reactions.
class PipReaction extends StatelessWidget {
  const PipReaction(this.value,
      {super.key, this.size = 28, this.previewable = false, this.count});
  final String value;
  final double size;
  final bool previewable;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final reaction =
        ActivityReaction.fromEmoji(value) ?? reviewActivityReactions[value];
    final artwork = Semantics(
      image: true,
      label: reaction?.label ?? 'Reaction',
      child: reaction == null
          ? Icon(Icons.add_reaction_outlined, size: size)
          : Image.asset(reaction.asset,
              width: size,
              height: size,
              fit: BoxFit.contain,
              cacheWidth: size > 64 ? 256 : 128,
              excludeFromSemantics: true),
    );
    if (!previewable || reaction == null) return artwork;
    return Semantics(
        button: true,
        label: 'Enlarge ${reaction.label}',
        child: InkWell(
            onTap: () => showPipReactionPreview(context, value, count: count),
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
                width: size,
                height: math.max(44, size),
                child: Center(child: artwork))));
  }
}

Future<void> showPipReactionPreview(BuildContext context, String value,
    {int? count}) {
  final reaction =
      ActivityReaction.fromEmoji(value) ?? reviewActivityReactions[value];
  if (reaction == null) return Future.value();
  return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .7),
          child: SingleChildScrollView(
              child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Align(
                            alignment: Alignment.centerRight,
                            child: IconButton(
                                tooltip: 'Close preview',
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close))),
                        PipReaction(value, size: 200),
                        const SizedBox(height: 16),
                        Text(reaction.label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: context.colors.white)),
                        if (count != null) ...[
                          const SizedBox(height: 8),
                          Text(
                              '$count ${count == 1 ? 'reaction' : 'reactions'}',
                              style: TextStyle(color: context.colors.medium))
                        ],
                      ]))))));
}

class PipReactionCount extends StatelessWidget {
  const PipReactionCount(this.value, this.count, {super.key, this.size = 28});
  final String value;
  final int count;
  final double size;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PipReaction(value, size: size, previewable: true, count: count),
          const SizedBox(width: 5),
          Text('$count')
        ],
      );
}
