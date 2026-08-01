import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/features/profile/presentation/controllers/review_reactions_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

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
  bool _blocked = false;
  bool _spoilerRevealed = false;

  @override
  void initState() {
    super.initState();
    _reactions = Map<String, int>.from(widget.review.reactions);
    _myReaction = widget.review.myReaction;
    SafetyService.blockedUsers().then<void>((_) {
      if (mounted && SafetyService.isBlocked(widget.review.userId)) {
        setState(() => _blocked = true);
      }
    }).catchError((_) {});
  }

  String _getInitials() {
    final username = widget.review.user?.username ?? widget.review.userId;
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  String _getDisplayName() {
    return widget.review.user?.username ?? 'Anonymous';
  }

  Color _avatarColor() {
    final hex = widget.review.user?.iconColor?['hexCode']
        ?.toString()
        .replaceFirst('#', '');
    final value = hex == null
        ? null
        : int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return value == null ? FlixieColors.primary : Color(value);
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
    if (_blocked || SafetyService.isBlocked(widget.review.userId)) {
      return const SizedBox.shrink();
    }
    final review = widget.review;
    final hasSpoilers = review.containsSpoilers;

    return GestureDetector(
      onTap: () => _openFullReview(context),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: FlixieColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                ProfileAvatarView(
                  avatar: review.user?.avatar,
                  fallbackText: _getInitials(),
                  fallbackColor: _avatarColor(),
                  profileBadges: review.user?.profileBadges ?? const [],
                  size: 58,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDisplayName(),
                        style: const TextStyle(
                          color: FlixieColors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (review.title.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          review.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: FlixieColors.warning, size: 20),
                        const SizedBox(width: 3),
                        Text(
                          '${review.rating}/10',
                          style: const TextStyle(
                            color: FlixieColors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatDate(review.createdAt),
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
                if (widget.currentUserId != null &&
                    widget.currentUserId != review.userId)
                  PopupMenuButton<String>(
                    tooltip: 'Review actions',
                    padding: EdgeInsets.zero,
                    onSelected: (action) async {
                      if (action == 'report') {
                        await SafetyActions.report(
                          context,
                          targetType: review.showId == null
                              ? 'MOVIE_REVIEW'
                              : 'SHOW_REVIEW',
                          targetId: review.id,
                          reportedUserId: review.userId,
                          contentPreview: '${review.title}\n${review.body}',
                        );
                      } else if (action == 'block') {
                        final blocked = await SafetyActions.block(
                          context,
                          userId: review.userId,
                          username: _getDisplayName(),
                        );
                        if (blocked && mounted) {
                          setState(() => _blocked = true);
                        }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'report',
                        child: Text('Report review'),
                      ),
                      PopupMenuItem(
                        value: 'block',
                        child: Text(
                          'Block user',
                          style: TextStyle(color: FlixieColors.danger),
                        ),
                      ),
                    ],
                    icon: const Icon(Icons.more_vert, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // Body — spoiler guard or truncated preview
            if (hasSpoilers && !_spoilerRevealed)
              GestureDetector(
                onTap: () => setState(() => _spoilerRevealed = true),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: FlixieColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: FlixieColors.warning.withValues(alpha: 0.45),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: FlixieColors.warning, size: 19),
                      SizedBox(width: 10),
                      Text(
                        'Contains spoilers — tap to reveal',
                        style: TextStyle(
                          color: FlixieColors.warning,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Text(
                review.body,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),

            const SizedBox(height: 16),

            if (review.recommended)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: FlixieColors.success.withValues(alpha: 0.08),
                  border: Border.all(color: FlixieColors.success, width: 1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.thumb_up_alt_rounded,
                        color: FlixieColors.success, size: 16),
                    SizedBox(width: 7),
                    Text('Recommends',
                        style: TextStyle(
                            color: FlixieColors.success,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),

            const SizedBox(height: 16),

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
                const Icon(Icons.chevron_right,
                    color: FlixieColors.primary, size: 22),
              ],
            ),
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
  final ReviewReactionsController _reviewReactions =
      ReviewReactionsController.instance;
  late Map<String, int> _reactions;
  late String? _myReaction;
  String? _reactingType;
  bool _spoilerRevealed = false;

  Color _avatarColor() {
    final hex = widget.review.user?.iconColor?['hexCode']
        ?.toString()
        .replaceFirst('#', '');
    final value = hex == null
        ? null
        : int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
    return value == null ? FlixieColors.primary : Color(value);
  }

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
      final result = await _reviewReactions.reactToReview(
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
      initialChildSize: 0.84,
      minChildSize: 0.4,
      maxChildSize: 0.97,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(
          color: FlixieColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: FlixieColors.medium,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 18, 18),
              child: Row(
                children: [
                  ProfileAvatarView(
                    avatar: review.user?.avatar,
                    fallbackText: widget.initials,
                    fallbackColor: _avatarColor(),
                    profileBadges: review.user?.profileBadges ?? const [],
                    size: 60,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.displayName,
                          style: const TextStyle(
                            color: FlixieColors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (review.title.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            review.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FlixieColors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: FlixieColors.warning, size: 21),
                          const SizedBox(width: 3),
                          Text(
                            '${review.rating}/10',
                            style: const TextStyle(
                              color: FlixieColors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        widget.formattedDate,
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Divider(
                color: Colors.white.withValues(alpha: 0.09),
                height: 1,
              ),
            ),
            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (review.containsSpoilers && !_spoilerRevealed)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 18),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: FlixieColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  FlixieColors.warning.withValues(alpha: 0.35)),
                        ),
                        child: Column(
                          children: [
                            const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: FlixieColors.warning, size: 22),
                                SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    'This review contains spoilers',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: FlixieColors.warning,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Reveal it only when you’re ready.',
                              style: TextStyle(
                                color: FlixieColors.warning,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton(
                              onPressed: () =>
                                  setState(() => _spoilerRevealed = true),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: FlixieColors.warning,
                                side: const BorderSide(
                                    color: FlixieColors.warning),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 11),
                              ),
                              child: const Text('Reveal review'),
                            ),
                          ],
                        ),
                      ),
                    if (!review.containsSpoilers || _spoilerRevealed)
                      Text(
                        review.body,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                    if (review.recommended) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: FlixieColors.success.withValues(alpha: 0.08),
                          border: Border.all(color: FlixieColors.success),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.thumb_up_alt_rounded,
                                color: FlixieColors.success, size: 17),
                            SizedBox(width: 8),
                            Text('Recommends',
                                style: TextStyle(
                                    color: FlixieColors.success,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // Reaction strip
                    _ReactionStrip(
                      reactions: _reactions,
                      myReaction: _myReaction,
                      reactingType: _reactingType,
                      onReact: _react,
                    ),
                    const SizedBox(height: 22),
                    Divider(color: Colors.white.withValues(alpha: 0.09)),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Close',
                          style: TextStyle(
                            color: FlixieColors.primary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: _kReactions.map((entry) {
            final (emoji, type) = entry;
            final count = reactions[type] ?? 0;
            final isActive = myReaction == type;
            final isLoading = reactingType == type;

            return Expanded(
              child: _ReactionChip(
                emoji: emoji,
                count: count,
                isActive: isActive,
                isLoading: isLoading,
                onTap: isLoading ? null : () => onReact(type),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Tap to react • tap again to remove',
            style: TextStyle(
              color: FlixieColors.medium,
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
    const activeColor = FlixieColors.primary;
    final bg = widget.isActive
        ? activeColor.withValues(alpha: 0.18)
        : FlixieColors.tabBarBorder;
    final border = widget.isActive ? activeColor : Colors.transparent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              border: Border.all(color: border, width: 1.2),
            ),
            alignment: Alignment.center,
            child: widget.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.7,
                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                    ),
                  )
                : ScaleTransition(
                    scale: _scale,
                    child: Text(widget.emoji,
                        style: const TextStyle(fontSize: 24)),
                  ),
          ),
          const SizedBox(height: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: widget.isActive ? activeColor : FlixieColors.medium,
              fontSize: 13,
              fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text('${widget.count}'),
          ),
        ],
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
                    : FlixieColors.tabBarBorder,
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
