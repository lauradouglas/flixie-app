import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/activity_reaction.dart';
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

Future<void> showReviewDetailSheet(
  BuildContext context, {
  required Review review,
  required String? currentUserId,
}) {
  final username = review.user?.username ?? 'Anonymous';
  final initials = username.isNotEmpty ? username[0].toUpperCase() : '?';
  final date = DateTime.tryParse(review.createdAt);
  final formattedDate = date == null
      ? review.createdAt
      : '${date.day.toString().padLeft(2, '0')} '
          '${const [
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
          'Dec'
        ][date.month - 1]} '
          '${date.year.toString().substring(2)}';
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ReviewDetailSheet(
      review: review,
      currentUserId: currentUserId,
      initialReactions: review.reactions,
      initialMyReaction: review.myReaction,
      onReactionChanged: (_, __) {},
      displayName: username,
      initials: initials,
      formattedDate: formattedDate,
    ),
  );
}

// Ordered list of supported reactions: (emoji, reactionType key)
final _kReactions = reviewActivityReactions.entries
    .map((entry) => (entry.value.emoji, entry.key))
    .toList();

class _ReviewCardState extends State<ReviewCard> {
  late Map<String, int> _reactions;
  String? _myReaction;
  bool _blocked = false;
  bool _safetyLoading = true;
  bool _safetyFailed = false;
  int _safetyRequest = 0;
  bool _spoilerRevealed = false;

  @override
  void initState() {
    super.initState();
    ReviewReactionsController.deletedReviews.addListener(_onDeleted);
    _reactions = Map<String, int>.from(widget.review.reactions);
    _myReaction = widget.review.myReaction;
    SafetyService.changes.addListener(_onSafetyChanged);
    _loadSafety();
  }

  void _onSafetyChanged() {
    if (!mounted) return;
    _loadSafety();
  }

  Future<void> _loadSafety() async {
    final request = ++_safetyRequest;
    setState(() {
      _safetyLoading = true;
      _safetyFailed = false;
    });
    try {
      await SafetyService.blockedUsers();
      if (!mounted || request != _safetyRequest) return;
      setState(() {
        _blocked = SafetyService.isBlocked(widget.review.userId);
        _safetyLoading = false;
      });
    } catch (_) {
      if (!mounted || request != _safetyRequest) return;
      setState(() {
        _safetyLoading = false;
        _safetyFailed = true;
      });
    }
  }

  void _onDeleted() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ReviewReactionsController.deletedReviews.removeListener(_onDeleted);
    SafetyService.changes.removeListener(_onSafetyChanged);
    super.dispose();
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
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewDetailSheet(
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
    if (ReviewReactionsController.isDeleted(widget.review) ||
        _blocked ||
        SafetyService.isBlocked(widget.review.userId)) {
      return const SizedBox.shrink();
    }
    if (_safetyLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Text('Loading review…'),
      );
    }
    if (_safetyFailed) {
      return TextButton.icon(
        onPressed: _loadSafety,
        icon: const Icon(Icons.refresh),
        label: const Text('Couldn’t load review · Retry'),
      );
    }
    final review = widget.review;
    final hasSpoilers = review.containsSpoilers;

    final rating = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: context.colors.warning, size: 20),
        const SizedBox(width: 4),
        Text('${review.rating}/10',
            style: TextStyle(
                color: context.colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16)),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openFullReview(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(14) > 19;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        ProfileAvatarView(
                          avatar: review.user?.avatar,
                          fallbackText: _getInitials(),
                          fallbackColor: _avatarColor(),
                          profileBadges: review.user?.profileBadges ?? const [],
                          size: 42,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_getDisplayName(),
                                style: TextStyle(
                                    color: context.colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Text(_formatDate(review.createdAt),
                                style: TextStyle(
                                    color: context.colors.medium,
                                    fontSize: 12)),
                          ],
                        )),
                        if (!stacked) rating,
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
                                  contentPreview:
                                      '${review.title}\n${review.body}',
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
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'report',
                                child: Text('Report review'),
                              ),
                              PopupMenuItem(
                                value: 'block',
                                child: Text(
                                  'Block user',
                                  style:
                                      TextStyle(color: context.colors.danger),
                                ),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert, size: 20),
                          ),
                      ]),
                      if (stacked)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: rating),
                    ],
                  );
                }),
                if (review.title.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(review.title,
                      style: TextStyle(
                          color: context.colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 17)),
                ],
                if (hasSpoilers) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: FlixieColors.primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () =>
                          setState(() => _spoilerRevealed = !_spoilerRevealed),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        child: Row(children: [
                          Icon(Icons.visibility_off_outlined,
                              color: context.colors.light, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text('Spoiler review',
                                  style: TextStyle(
                                      color: context.colors.light,
                                      fontSize: 13))),
                          Text(_spoilerRevealed ? 'Hide' : 'Reveal',
                              style: TextStyle(
                                  color: context.colors.light,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ]),
                      ),
                    ),
                  ),
                ],
                if ((!hasSpoilers || _spoilerRevealed) &&
                    review.body.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(review.body,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.colors.light,
                          fontSize: 14,
                          height: 1.5)),
                ],
                if (review.recommended) ...[
                  const SizedBox(height: 12),
                  Row(children: [
                    Icon(Icons.thumb_up_alt_rounded,
                        color: context.colors.success, size: 16),
                    const SizedBox(width: 7),
                    Expanded(
                        child: Text('Recommends',
                            style: TextStyle(
                                color: context.colors.success,
                                fontSize: 13,
                                fontWeight: FontWeight.w600))),
                  ]),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    spacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: _reactions.isEmpty
                        ? WrapAlignment.end
                        : WrapAlignment.spaceBetween,
                    children: [
                      if (_reactions.isNotEmpty)
                        _ReactionPreview(
                            reactions: _reactions, myReaction: _myReaction),
                      TextButton.icon(
                        onPressed: () => _openFullReview(context),
                        iconAlignment: IconAlignment.end,
                        icon: const Icon(Icons.chevron_right, size: 18),
                        label: const Text('Read review'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full-review bottom sheet
// ---------------------------------------------------------------------------

class ReviewDetailSheet extends StatefulWidget {
  const ReviewDetailSheet({
    super.key,
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
  State<ReviewDetailSheet> createState() => _ReviewDetailSheetState();
}

class _ReviewDetailSheetState extends State<ReviewDetailSheet> {
  final ReviewReactionsController _reviewReactions =
      ReviewReactionsController.instance;
  late Map<String, int> _reactions;
  late String? _myReaction;
  String? _reactingType;
  bool _spoilerRevealed = false;

  bool _safetyActionRunning = false;

  Future<void> _reportReview() async {
    if (_safetyActionRunning) return;
    setState(() => _safetyActionRunning = true);
    final review = widget.review;
    try {
      await SafetyActions.report(
        context,
        targetType: review.showId == null ? 'MOVIE_REVIEW' : 'SHOW_REVIEW',
        targetId: review.id,
        reportedUserId: review.userId,
        contentPreview: '${review.title}\n${review.body}',
      );
    } finally {
      if (mounted) setState(() => _safetyActionRunning = false);
    }
  }

  Future<void> _blockAuthor() async {
    if (_safetyActionRunning) return;
    setState(() => _safetyActionRunning = true);
    try {
      final blocked = await SafetyActions.block(
        context,
        userId: widget.review.userId,
        username: widget.displayName,
      );
      if (blocked && mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _safetyActionRunning = false);
    }
  }

  bool _deleting = false;
  Future<void> _deleteReview() async {
    final confirmed = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (context) => AlertDialog(
                title: const Text('Delete this review?'),
                content: const Text(
                    'Your review and its reactions will be permanently removed.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Keep review')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Delete review'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await _reviewReactions.deleteReview(widget.review, widget.currentUserId!);
      if (!mounted) return;
      context.read<AuthProvider>().invalidateCachedReviews();
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t delete your review. Please try again.')));
      }
    }
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
    return Container(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .88),
      decoration: BoxDecoration(
        color: context.colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  height: 48,
                  child: Stack(children: [
                    Center(
                        child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                                color: context.colors.medium,
                                borderRadius: BorderRadius.circular(2)))),
                    Positioned(
                        right: 8,
                        top: 0,
                        child: IconButton(
                            tooltip: 'Close review',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close))),
                  ])),
              Flexible(
                  child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(builder: (context, constraints) {
                        final stacked = constraints.maxWidth < 300 ||
                            MediaQuery.textScalerOf(context).scale(15) > 21;
                        final rating =
                            Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.star_rounded,
                              color: context.colors.warning, size: 22),
                          const SizedBox(width: 4),
                          Text('${review.rating}/10',
                              style: TextStyle(
                                  color: context.colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ]);
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                ProfileAvatarView(
                                    avatar: review.user?.avatar,
                                    fallbackText: widget.initials,
                                    fallbackColor: _avatarColor(),
                                    profileBadges:
                                        review.user?.profileBadges ?? const [],
                                    size: 44),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(widget.displayName,
                                          style: TextStyle(
                                              color: context.colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 3),
                                      Text(widget.formattedDate,
                                          style: TextStyle(
                                              color: context.colors.medium,
                                              fontSize: 13)),
                                    ])),
                                if (!stacked) rating,
                              ]),
                              if (stacked)
                                Padding(
                                    padding: const EdgeInsets.only(top: 12),
                                    child: rating),
                            ]);
                      }),
                      if (widget.currentUserId != null &&
                          widget.currentUserId != review.userId)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              TextButton.icon(
                                onPressed:
                                    _safetyActionRunning ? null : _reportReview,
                                icon: const Icon(Icons.flag_outlined),
                                label: const Text('Report review'),
                              ),
                              TextButton.icon(
                                onPressed:
                                    _safetyActionRunning ? null : _blockAuthor,
                                icon: const Icon(Icons.block),
                                label: const Text('Block user'),
                              ),
                            ],
                          ),
                        ),
                      if (review.title.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(review.title,
                            style: TextStyle(
                                color: context.colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 24)),
                      ],
                      if (review.recommended) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          Icon(Icons.thumb_up_alt_rounded,
                              color: context.colors.success, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text('Recommends',
                                  style: TextStyle(
                                      color: context.colors.success,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600))),
                        ]),
                      ],
                      const SizedBox(height: 20),
                      if (review.containsSpoilers) ...[
                        TextButton.icon(
                          onPressed: () => setState(
                              () => _spoilerRevealed = !_spoilerRevealed),
                          icon: const Icon(Icons.visibility_off_outlined,
                              size: 18),
                          label: Text(_spoilerRevealed
                              ? 'Hide spoilers'
                              : 'Spoiler review · Reveal'),
                        ),
                        if (_spoilerRevealed) const SizedBox(height: 8),
                      ],
                      if (!review.containsSpoilers || _spoilerRevealed)
                        Text(review.body,
                            style: TextStyle(
                                color: context.colors.light,
                                fontSize: 16,
                                height: 1.5)),
                      const SizedBox(height: 24),
                      if (widget.currentUserId != null &&
                          widget.currentUserId == review.userId)
                        TextButton.icon(
                            onPressed: _deleting ? null : _deleteReview,
                            icon: Icon(Icons.delete_outline,
                                color: context.colors.danger),
                            label: Text(
                                _deleting ? 'Deleting…' : 'Delete review',
                                style:
                                    TextStyle(color: context.colors.danger))),
                      _ReactionStrip(
                          reactions: _reactions,
                          myReaction: _myReaction,
                          reactingType: _reactingType,
                          onReact: _react),
                    ]),
              )),
            ],
          )),
    );
  }
}

// ---------------------------------------------------------------------------
// Reaction strip - shown inside the full-review bottom sheet
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
