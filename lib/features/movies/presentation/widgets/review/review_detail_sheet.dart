import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/features/profile/presentation/controllers/review_reactions_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

import 'review_reactions.dart';

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
                          Text(
                              hideMovieRatings(context, review.movieId,
                                      isShow: review.showId != null,
                                      ownerId: review.userId)
                                  ? 'Rate to see score'
                                  : '${review.rating}/10',
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
                      ReviewReactionStrip(
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
