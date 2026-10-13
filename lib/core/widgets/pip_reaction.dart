import 'package:flutter/material.dart';
import 'package:flixie_app/models/activity_reaction.dart';

/// Shared artwork for reaction selectors, counts and existing saved reactions.
class PipReaction extends StatelessWidget {
  const PipReaction(this.value, {super.key, this.size = 28});
  final String value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final reaction =
        ActivityReaction.fromEmoji(value) ?? reviewActivityReactions[value];
    return Semantics(
      image: true,
      label: reaction?.label ?? 'Reaction',
      child: reaction == null
          ? Icon(Icons.add_reaction_outlined, size: size)
          : Image.asset(reaction.asset,
              width: size,
              height: size,
              fit: BoxFit.contain,
              cacheWidth: 128,
              excludeFromSemantics: true),
    );
  }
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
          PipReaction(value, size: size),
          const SizedBox(width: 5),
          Text('$count')
        ],
      );
}
