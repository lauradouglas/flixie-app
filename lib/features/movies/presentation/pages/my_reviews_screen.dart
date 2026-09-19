import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart'
    as shared;
import 'package:flixie_app/features/profile/presentation/controllers/review_reactions_controller.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class MyReviewsScreen extends StatefulWidget {
  const MyReviewsScreen({super.key});

  @override
  State<MyReviewsScreen> createState() => _MyReviewsScreenState();
}

class _MyReviewsScreenState extends State<MyReviewsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Review> _allReviews = [];
  List<Review> _filteredReviews = [];
  bool _loading = true;
  String _sortBy = 'newest'; // newest, oldest

  @override
  void initState() {
    super.initState();
    ReviewReactionsController.deletedReviews.addListener(_onReviewDeleted);
    _loadReviews();
    _searchController.addListener(_filterReviews);
  }

  void _onReviewDeleted() {
    if (!mounted) return;
    setState(() {
      _allReviews.removeWhere(ReviewReactionsController.isDeleted);
      _filteredReviews.removeWhere(ReviewReactionsController.isDeleted);
    });
  }

  @override
  void dispose() {
    ReviewReactionsController.deletedReviews.removeListener(_onReviewDeleted);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    // Use prefetched cache if ready - no spinner needed
    if (auth.cachedReviews != null) {
      setState(() {
        _allReviews = auth.cachedReviews!;
        _filterReviews();
        _loading = false;
      });
      return;
    }

    try {
      final reviews = await UserService.getUserReviews(userId);
      setState(() {
        _allReviews = reviews;
        _filterReviews();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error loading reviews: $e');
      setState(() => _loading = false);
    }
  }

  void _filterReviews() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredReviews = _allReviews.where((review) {
        final reviewTitle = review.title.toLowerCase();
        final movieTitle = (review.movieTitle ?? '').toLowerCase();
        return reviewTitle.contains(query) || movieTitle.contains(query);
      }).toList();

      // Apply sorting
      switch (_sortBy) {
        case 'newest':
          _filteredReviews.sort((a, b) {
            final dateA = DateTime.tryParse(a.createdAt) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = DateTime.tryParse(b.createdAt) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return dateB.compareTo(dateA);
          });
          break;
        case 'oldest':
          _filteredReviews.sort((a, b) {
            final dateA = DateTime.tryParse(a.createdAt) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final dateB = DateTime.tryParse(b.createdAt) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return dateA.compareTo(dateB);
          });
          break;
      }
    });
  }

  void _changeSortOrder(String? value) {
    if (value != null) {
      setState(() {
        _sortBy = value;
        _filterReviews();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: context.colors.background,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Reviews',
              style: TextStyle(
                color: context.colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!_loading && _allReviews.isNotEmpty)
              Text(
                '${_allReviews.length} reviews written',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          // Sort dropdown
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: context.colors.tabBarBackgroundFocused,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: _sortBy,
              underline: const SizedBox(),
              dropdownColor: context.colors.tabBarBackgroundFocused,
              style: TextStyle(color: context.colors.white, fontSize: 14),
              icon: Icon(Icons.arrow_drop_down, color: context.colors.white),
              items: const [
                DropdownMenuItem(value: 'newest', child: Text('Newest First')),
                DropdownMenuItem(value: 'oldest', child: Text('Oldest First')),
              ],
              onChanged: _changeSortOrder,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              style: TextStyle(color: context.colors.white),
              decoration: InputDecoration(
                hintText: 'Search reviews...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: context.colors.tabBarBackgroundFocused,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: FlixieColors.primary))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_filteredReviews.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchController.text.isNotEmpty
                  ? Icons.search_off
                  : Icons.rate_review_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No reviews found'
                  : 'No reviews yet',
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            if (_searchController.text.isEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Start reviewing movies to see them here',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredReviews.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return ReviewCard(
          review: _filteredReviews[index],
          onTap: () => shared.showReviewDetailSheet(context,
              review: _filteredReviews[index],
              currentUserId: context.read<AuthProvider>().dbUser?.id),
        );
      },
    );
  }
}

class ReviewCard extends StatefulWidget {
  final Review review;
  final VoidCallback onTap;

  const ReviewCard({
    super.key,
    required this.review,
    required this.onTap,
  });

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  bool _spoilerRevealed = false;

  void _handleTap() {
    if (widget.review.containsSpoilers && !_spoilerRevealed) {
      setState(() => _spoilerRevealed = true);
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final date = DateTime.tryParse(review.createdAt);
    final formattedDate = date != null
        ? '${date.month}/${date.day}/${date.year.toString().substring(2)}'
        : 'Unknown';

    return GestureDetector(
      onTap: _handleTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colors.tabBarBorder),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Movie title (if available)
            if (review.movieTitle != null) ...[
              Text(
                review.movieTitle!,
                style: TextStyle(
                  color: context.colors.warning,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
            ],
            // Header row with rating and date
            Row(
              children: [
                // Rating
                FlixiePill.label(
                    label: Text('${review.rating}/10'),
                    avatar: Icon(Icons.star, color: context.colors.warning)),
                const SizedBox(width: 8),
                // Recommended badge
                if (review.recommended)
                  FlixiePill.label(
                      label: const Text('Recommended'),
                      avatar:
                          Icon(Icons.thumb_up, color: context.colors.success)),
                const Spacer(),
                // Date
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: context.colors.medium,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Title
            Text(
              review.title,
              style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            // Spoiler reviews stay blurred until explicitly revealed.
            Stack(
              alignment: Alignment.center,
              children: [
                ImageFiltered(
                  imageFilter: review.containsSpoilers && !_spoilerRevealed
                      ? ImageFilter.blur(sigmaX: 5, sigmaY: 5)
                      : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                  child: Text(
                    review.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.colors.light,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                if (review.containsSpoilers && !_spoilerRevealed)
                  FlixiePill.label(
                      label: const Text('Tap to reveal spoiler'),
                      avatar: Icon(Icons.visibility_outlined,
                          color: context.colors.warning)),
              ],
            ),
            const SizedBox(height: 12),
            // Footer with reactions and spoiler warning
            Row(
              children: [
                // Reactions preview
                if (review.reactions.isNotEmpty) ...[
                  ...(() {
                    final sorted = review.reactions.entries.toList()
                      ..sort((a, b) => b.value.compareTo(a.value));
                    return sorted.take(3).map((e) => Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(reviewReactionEmoji(e.key),
                                  style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 2),
                              Text(
                                '${e.value}',
                                style: TextStyle(
                                    color: context.colors.medium, fontSize: 11),
                              ),
                            ],
                          ),
                        ));
                  })(),
                ],
                const Spacer(),
                // Spoiler warning
                if (review.containsSpoilers)
                  FlixiePill.label(
                      label: const Text('Spoilers'),
                      avatar: Icon(Icons.warning_amber_rounded,
                          color: context.colors.danger)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
