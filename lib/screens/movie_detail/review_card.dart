import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/review.dart';
import '../../services/user_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';

class ReviewCard extends StatefulWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.currentUserId,
  });

  final Review review;
  final String? currentUserId;

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

// Ordered list of supported reactions: (emoji, reactionType key)
const _kReactions = [
  ('\u{1F44D}', 'agree'),
  ('\u{1F525}', 'hot_take'),
  ('\u{2764}\u{FE0F}', 'love'),
  ('\u{1F602}', 'funny'),
  ('\u{1F914}', 'hmm'),
];

class _ReviewCardState extends State<ReviewCard> {
  late Map<String, int> _reactions;
  String? _myReaction;

  @override
  void initState() {
    super.initState();
    _reactions = Map<String, int>.from(widget.review.reactions);
    _myReaction = widget.review.myReaction;
  }

  String _getInitials() {
    final username = widget.review.user?.username ?? widget.review.userId;
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  String _getDisplayName() {
    return widget.review.user?.username ?? 'Anonymous';
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final reviewDay = DateTime(date.year, date.month, date.day);
      final diff = today.difference(reviewDay).inDays;

      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final day = date.day.toString().padLeft(2, '0');
      final month = months[date.month - 1];
      final year = date.year.toString().substring(2);
      return '$day $month $year';
    } catch (e) {
      return dateStr;
    }
  }

  void _openFullReview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReviewDetailSheet(
        review: widget.review,
        currentUserId: widget.currentUserId,
        initialReactions: _reactions,
        initialMyReaction: _myReaction,
        onReactionChanged: (reactions, myReaction) {
          if (mounted) {
            setState(() {
              _reactions = reactions;
              _myReaction = myReaction;
            });
          }
        },
        displayName: _getDisplayName(),
        initials: _getInitials(),
        formattedDate: _formatDate(widget.review.createdAt),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final hasSpoilers = review.containsSpoilers;

    return GestureDetector(
      onTap: () => _openFullReview(context),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2E42),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: FlixieColors.primary.withValues(alpha: 0.3),
                  child: Text(
                    _getInitials(),
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (review.title.isNotEmpty)
                        Text(
                          review.title,
                          style: const TextStyle(
                            color: FlixieColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      Text(
                        _getDisplayName(),
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star,
                            color: FlixieColors.warning, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          '${review.rating}/10',
                          style: const TextStyle(
                            color: FlixieColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Body — spoiler guard or truncated preview
            if (hasSpoilers)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.35)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: Colors.orange, size: 15),
                    SizedBox(width: 6),
                    Text(
                      'Contains spoilers — tap to read',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            else
              Text(
                review.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

            const SizedBox(height: 10),

            // Footer: reactions + "Read more"
            Row(
              children: [
                if (_reactions.isNotEmpty)
                  Expanded(
                    child: _ReactionPreview(
                        reactions: _reactions, myReaction: _myReaction),
                  )
                else
                  const Spacer(),
                Text(
                  hasSpoilers ? 'View review' : 'Read more',
                  style: const TextStyle(
                    color: FlixieColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    color: FlixieColors.primary, size: 16),
              ],
            ),
            // Recommended badge
            if (review.recommended) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: FlixieColors.success.withValues(alpha: 0.15),
                  border: Border.all(color: FlixieColors.success, width: 1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.thumb_up, color: FlixieColors.success, size: 12),
                    SizedBox(width: 4),
                    Text(
                      'Recommended',
                      style: TextStyle(
                        color: FlixieColors.success,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-review bottom sheet
// ---------------------------------------------------------------------------

class _ReviewDetailSheet extends StatefulWidget {
  const _ReviewDetailSheet({
    required this.review,
    required this.currentUserId,
    required this.initialReactions,
    required this.initialMyReaction,
    required this.onReactionChanged,
    required this.displayName,
    required this.initials,
    required this.formattedDate,
  });

  final Review review;
  final String? currentUserId;
  final Map<String, int> initialReactions;
  final String? initialMyReaction;
  final void Function(Map<String, int> reactions, String? myReaction)
      onReactionChanged;
  final String displayName;
  final String initials;
  final String formattedDate;

  @override
  State<_ReviewDetailSheet> createState() => _ReviewDetailSheetState();
}

class _ReviewDetailSheetState extends State<_ReviewDetailSheet> {
  late Map<String, int> _reactions;
  late String? _myReaction;
  String? _reactingType;

  @override
  void initState() {
    super.initState();
    _reactions = Map<String, int>.from(widget.initialReactions);
    _myReaction = widget.initialMyReaction;
  }

  Future<void> _react(String reactionType) async {
    HapticFeedback.lightImpact();
    if (_reactingType != null) return;

    final removing = _myReaction == reactionType;
    final previousReaction = _myReaction;
    final previousReactions = Map<String, int>.from(_reactions);

    setState(() {
      _reactingType = reactionType;
      if (removing) {
        _myReaction = null;
        final current = _reactions[reactionType] ?? 0;
        if (current <= 1) {
          _reactions.remove(reactionType);
        } else {
          _reactions[reactionType] = current - 1;
        }
      } else {
        if (previousReaction != null) {
          final old = _reactions[previousReaction] ?? 0;
          if (old <= 1) {
            _reactions.remove(previousReaction);
          } else {
            _reactions[previousReaction] = old - 1;
          }
        }
        _myReaction = reactionType;
        _reactions[reactionType] = (_reactions[reactionType] ?? 0) + 1;
      }
    });

    try {
      final review = widget.review;
      final mediaType = review.movieId != null ? 'MOVIE' : 'SHOW';
      final mediaId = (review.movieId ?? review.showId)!.toString();
      final result = await UserService.reactToReview(
        mediaType: mediaType,
        mediaId: mediaId,
        reviewId: review.id,
        userId: widget.currentUserId ?? '',
        reactionType: removing ? null : reactionType,
      );
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _reactions = Map<String, int>.from(result.reactions);
          _myReaction = result.myReaction;
        });
        widget.onReactionChanged(_reactions, _myReaction);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _reactions = previousReactions;
          _myReaction = previousReaction;
        });
      }
      logger.e('Error reacting to review: $e');
    } finally {
      if (mounted) setState(() => _reactingType = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FlixieColors.medium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor:
                        FlixieColors.primary.withValues(alpha: 0.3),
                    child: Text(
                      widget.initials,
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (review.title.isNotEmpty)
                          Text(
                            review.title,
                            style: const TextStyle(
                              color: FlixieColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        Text(
                          widget.displayName,
                          style: const TextStyle(
                            color: FlixieColors.light,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: FlixieColors.warning, size: 14),
                          const SizedBox(width: 3),
                          Text(
                            '${review.rating}/10',
                            style: const TextStyle(
                              color: FlixieColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        widget.formattedDate,
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF1E2D40), height: 1),
            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (review.containsSpoilers)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.orange.withOpacity(0.35)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orange, size: 15),
                            SizedBox(width: 6),
                            Text(
                              'Contains spoilers',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      review.body,
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Reaction strip
                    _ReactionStrip(
                      reactions: _reactions,
                      myReaction: _myReaction,
                      reactingType: _reactingType,
                      onReact: _react,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reaction strip — shown inside the full-review bottom sheet
// ---------------------------------------------------------------------------

class _ReactionStrip extends StatelessWidget {
  const _ReactionStrip({
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
        const Text(
          'Reactions',
          style: TextStyle(
            color: FlixieColors.medium,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kReactions.map((entry) {
            final (emoji, type) = entry;
            final count = reactions[type] ?? 0;
            final isActive = myReaction == type;
            final isLoading = reactingType == type;

            return _ReactionChip(
              emoji: emoji,
              count: count,
              isActive: isActive,
              isLoading: isLoading,
              onTap: isLoading ? null : () => onReact(type),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        const Text(
          'Tap to react • tap again to remove',
          style: TextStyle(
            color: FlixieColors.medium,
            fontSize: 11,
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
    final activeColor = FlixieColors.primary;
    final bg = widget.isActive
        ? activeColor.withValues(alpha: 0.18)
        : const Color(0xFF1E2D40);
    final border = widget.isActive ? activeColor : Colors.transparent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                    ),
                  )
                : ScaleTransition(
                    scale: _scale,
                    child: Text(widget.emoji,
                        style: const TextStyle(fontSize: 16)),
                  ),
            if (widget.count > 0) ...[
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: widget.isActive ? activeColor : FlixieColors.light,
                  fontSize: 13,
                  fontWeight:
                      widget.isActive ? FontWeight.w700 : FontWeight.normal,
                ),
                child: Text('${widget.count}'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reaction preview shown on the collapsed card
// ---------------------------------------------------------------------------

class _ReactionPreview extends StatelessWidget {
  const _ReactionPreview({
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
            final emoji = _kReactions
                .firstWhere(
                  (r) => r.$2 == e.key,
                  orElse: () => ('?', e.key),
                )
                .$1;
            final isMe = myReaction == e.key;
            return Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isMe
                    ? FlixieColors.primary.withValues(alpha: 0.15)
                    : const Color(0xFF1E2D40),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMe ? FlixieColors.primary : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(
                    '${e.value}',
                    style: TextStyle(
                      color: isMe ? FlixieColors.primary : FlixieColors.medium,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
