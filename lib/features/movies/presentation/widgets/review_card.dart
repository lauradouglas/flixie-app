import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/features/profile/presentation/controllers/review_reactions_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

import 'review/review_detail_sheet.dart';
import 'review/review_reactions.dart';
export 'review/review_detail_sheet.dart'
    show ReviewDetailSheet, showReviewDetailSheet;

class ReviewCard extends StatefulWidget {
  const ReviewCard({
    super.key,
    required this.review,
    required this.currentUserId,
    this.showMediaTitle = false,
  });

  final Review review;
  final String? currentUserId;
  final bool showMediaTitle;

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

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
      return const ContentPlaceholder(
          label: 'Loading review', style: ContentPlaceholderStyle.review);
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
        Text(
            hideMovieRatings(context, review.movieId,
                    isShow: review.showId != null, ownerId: review.userId)
                ? 'Rate to see score'
                : '${review.rating}/10',
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
                if (widget.showMediaTitle &&
                    review.movieTitle?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(review.movieTitle!,
                      style: TextStyle(
                          color: context.colors.primaryText,
                          fontWeight: FontWeight.w700,
                          fontSize: 16)),
                ],
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
                        ReviewReactionPreview(
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
