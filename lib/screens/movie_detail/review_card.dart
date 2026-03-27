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

class _ReviewCardState extends State<ReviewCard> {
  late int _upvotes;
  late int _downvotes;
  String? _userVote;
  String? _votingType;

  @override
  void initState() {
    super.initState();
    _upvotes = widget.review.upvotes;
    _downvotes = widget.review.downvotes;
  }

  bool get _isOwnReview =>
      widget.currentUserId != null &&
      widget.currentUserId == widget.review.userId;

  Future<void> _vote(String voteType) async {
    if (_votingType != null) return; // already waiting on a request

    HapticFeedback.lightImpact();

    if (_userVote == voteType) {
      setState(() {
        if (voteType == 'upvote') {
          _upvotes--;
        } else {
          _downvotes--;
        }
        _userVote = null;
      });
      return;
    }

    final previousVote = _userVote;
    setState(() {
      _votingType = voteType;
      if (voteType == 'upvote') {
        _upvotes++;
        if (previousVote == 'downvote') _downvotes--;
      } else {
        _downvotes++;
        if (previousVote == 'upvote') _upvotes--;
      }
      _userVote = voteType;
    });

    try {
      final review = widget.review;
      final mediaType = review.movieId != null ? 'MOVIE' : 'SHOW';
      final mediaId = (review.movieId ?? review.showId)!.toString();
      final updated = await UserService.voteOnReview(
        mediaType: mediaType,
        mediaId: mediaId,
        reviewId: review.id,
        voteType: voteType,
      );
      if (mounted) {
        HapticFeedback.mediumImpact();
        setState(() {
          _upvotes = updated.upvotes;
          _downvotes = updated.downvotes;
        });
      }
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _upvotes = widget.review.upvotes;
          _downvotes = widget.review.downvotes;
          _userVote = previousVote;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register vote: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      logger.e('Error voting on review: $e');
    } finally {
      if (mounted) setState(() => _votingType = null);
    }
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
        upvotes: _upvotes,
        downvotes: _downvotes,
        userVote: _userVote,
        votingType: _votingType,
        isOwnReview: _isOwnReview,
        onVote: _vote,
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

            // Footer: votes + "Read more"
            Row(
              children: [
                if (!_isOwnReview) ...[
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {},
                    child: Row(
                      children: [
                        _VoteButton(
                          icon: Icons.arrow_upward,
                          activeIcon: Icons.arrow_upward,
                          count: _upvotes,
                          isActive: _userVote == 'upvote',
                          isLoading: _votingType == 'upvote',
                          onTap: () => _vote('upvote'),
                        ),
                        const SizedBox(width: 16),
                        _VoteButton(
                          icon: Icons.arrow_downward,
                          activeIcon: Icons.arrow_downward,
                          count: _downvotes,
                          isActive: _userVote == 'downvote',
                          isLoading: _votingType == 'downvote',
                          onTap: () => _vote('downvote'),
                          activeColor: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Icon(Icons.arrow_upward,
                      size: 14, color: FlixieColors.medium),
                  const SizedBox(width: 4),
                  Text('$_upvotes',
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 12)),
                  const SizedBox(width: 12),
                  const Icon(Icons.arrow_downward,
                      size: 14, color: FlixieColors.medium),
                  const SizedBox(width: 4),
                  Text('$_downvotes',
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 12)),
                ],
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

class _ReviewDetailSheet extends StatelessWidget {
  const _ReviewDetailSheet({
    required this.review,
    required this.upvotes,
    required this.downvotes,
    required this.userVote,
    required this.votingType,
    required this.isOwnReview,
    required this.onVote,
    required this.displayName,
    required this.initials,
    required this.formattedDate,
  });

  final Review review;
  final int upvotes;
  final int downvotes;
  final String? userVote;
  final String? votingType;
  final bool isOwnReview;
  final void Function(String) onVote;
  final String displayName;
  final String initials;
  final String formattedDate;

  @override
  Widget build(BuildContext context) {
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
                      initials,
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
                          displayName,
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
                        formattedDate,
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
                    // Vote row
                    if (!isOwnReview)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _VoteButton(
                            icon: Icons.thumb_up_outlined,
                            activeIcon: Icons.thumb_up,
                            count: upvotes,
                            isActive: userVote == 'upvote',
                            isLoading: votingType == 'upvote',
                            onTap: () {
                              onVote('upvote');
                              Navigator.pop(context);
                            },
                          ),
                          const SizedBox(width: 20),
                          _VoteButton(
                            icon: Icons.thumb_down_outlined,
                            activeIcon: Icons.thumb_down,
                            count: downvotes,
                            isActive: userVote == 'downvote',
                            isLoading: votingType == 'downvote',
                            onTap: () {
                              onVote('downvote');
                              Navigator.pop(context);
                            },
                            activeColor: Colors.redAccent,
                          ),
                        ],
                      )
                    else
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          const Icon(Icons.thumb_up_outlined,
                              size: 14, color: FlixieColors.medium),
                          const SizedBox(width: 4),
                          Text('$upvotes',
                              style: const TextStyle(
                                  color: FlixieColors.medium, fontSize: 12)),
                          const SizedBox(width: 12),
                          const Icon(Icons.thumb_down_outlined,
                              size: 14, color: FlixieColors.medium),
                          const SizedBox(width: 4),
                          Text('$downvotes',
                              style: const TextStyle(
                                  color: FlixieColors.medium, fontSize: 12)),
                        ],
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

class _VoteButton extends StatefulWidget {
  const _VoteButton({
    required this.icon,
    required this.activeIcon,
    required this.count,
    required this.isActive,
    required this.isLoading,
    required this.onTap,
    this.activeColor = FlixieColors.primary,
  });

  final IconData icon;
  final IconData activeIcon;
  final int count;
  final bool isActive;
  final bool isLoading;
  final VoidCallback onTap;
  final Color activeColor;

  @override
  State<_VoteButton> createState() => _VoteButtonState();
}

class _VoteButtonState extends State<_VoteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0, // start at end so icons are normal size before any vote
    );
    _scale = Tween<double>(begin: 1.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(_VoteButton old) {
    super.didUpdateWidget(old);
    // Fire bounce when vote is confirmed (loading finished & still active)
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
    final color = widget.isActive ? widget.activeColor : FlixieColors.medium;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.isLoading ? () {} : widget.onTap,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: widget.isLoading
                ? Padding(
                    padding: const EdgeInsets.all(2),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  )
                : ScaleTransition(
                    scale: _scale,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        widget.isActive ? widget.activeIcon : widget.icon,
                        key: ValueKey<bool>(widget.isActive),
                        size: 17,
                        color: color,
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: widget.isActive ? FontWeight.w700 : FontWeight.normal,
            ),
            child: Text('${widget.count}'),
          ),
        ],
      ),
    );
  }
}
