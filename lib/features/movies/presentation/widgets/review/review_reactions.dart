import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/models/activity_reaction.dart';

// Ordered list of supported reactions: (emoji, reactionType key)
final _kReactions = reviewActivityReactions.entries
    .map((entry) => (entry.value.emoji, entry.key))
    .toList();

class ReviewReactionStrip extends StatelessWidget {
  const ReviewReactionStrip({
    super.key,
    required this.reactions,
    required this.myReaction,
    required this.reactingType,
    required this.onReact,
  });

  final Map<String, int> reactions;
  final String? myReaction;
  final String? reactingType;
  final void Function(String) onReact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'React to this review',
          style: TextStyle(
            color: context.colors.medium,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _kReactions.map((entry) {
              final (emoji, type) = entry;
              final count = reactions[type] ?? 0;
              final isActive = myReaction == type;
              final isLoading = reactingType == type;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _ReactionChip(
                  emoji: emoji,
                  count: count,
                  isActive: isActive,
                  isLoading: isLoading,
                  onTap: reactingType != null ? null : () => onReact(type),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Tap again to remove your reaction',
            style: TextStyle(
              color: context.colors.medium,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactionChip extends StatefulWidget {
  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.isActive,
    required this.isLoading,
    required this.onTap,
  });

  final String emoji;
  final int count;
  final bool isActive;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  State<_ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: 1.0,
    );
    _scale = Tween<double>(begin: 1.4, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void didUpdateWidget(_ReactionChip old) {
    super.didUpdateWidget(old);
    if (!widget.isLoading && old.isLoading && widget.isActive) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
        label: '${widget.emoji}, ${widget.count} reactions',
        child: FlixiePill.action(
            selected: widget.isActive,
            onPressed: widget.onTap,
            label: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.isLoading)
                const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                ScaleTransition(
                    scale: _scale,
                    child: Text(widget.emoji,
                        style: const TextStyle(fontSize: 20))),
              if (widget.count > 0) ...[
                const SizedBox(width: 6),
                Text('${widget.count}')
              ]
            ])));
  }
}

// ---------------------------------------------------------------------------
// Reaction preview shown on the collapsed card
// ---------------------------------------------------------------------------

class ReviewReactionPreview extends StatelessWidget {
  const ReviewReactionPreview({
    super.key,
    required this.reactions,
    required this.myReaction,
  });

  final Map<String, int> reactions;
  final String? myReaction;

  @override
  Widget build(BuildContext context) {
    // Show up to 3 reaction types with the highest counts
    final sorted = reactions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          ...top.map((e) {
            final emoji = reviewReactionEmoji(e.key);
            final isMe = myReaction == e.key;
            return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FlixiePill.label(
                    selected: isMe, label: Text('$emoji ${e.value}')));
          }),
        ],
      ),
    );
  }
}
