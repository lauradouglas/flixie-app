import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart';

class MediaReviewsSection extends StatelessWidget {
  const MediaReviewsSection(
      {super.key,
      required this.reviews,
      required this.currentUserId,
      required this.onWriteReview,
      this.loading = false,
      this.failed = false,
      this.onRetry});

  final List<Review> reviews;
  final String? currentUserId;
  final VoidCallback onWriteReview;
  final bool loading, failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(reviews.isEmpty ? 'Reviews' : 'Reviews ${reviews.length}',
                    style: const TextStyle(
                        color: FlixieColors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                TextButton.icon(
                    onPressed: onWriteReview,
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: const Text('Write review')),
              ]),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Loading reviews…',
                    style: TextStyle(color: FlixieColors.light)))
          else if (failed)
            TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Couldn’t load reviews · Retry'))
          else if (reviews.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No reviews yet. What did you think?',
                    style: TextStyle(color: FlixieColors.light, fontSize: 13))),
          for (final review in reviews.take(4))
            ReviewCard(
                key: ValueKey(review.id),
                review: review,
                currentUserId: currentUserId),
          if (reviews.length > 4)
            TextButton(
                onPressed: () => _showAll(context),
                child: Text('See all ${reviews.length} reviews')),
        ],
      );

  Future<void> _showAll(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: FlixieColors.background,
        builder: (context) => SizedBox(
            height: MediaQuery.sizeOf(context).height * .85,
            child: Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  child: Row(children: [
                    Expanded(
                        child: Text('All Reviews (${reviews.length})',
                            style: const TextStyle(
                                color: FlixieColors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold))),
                    IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ])),
              const Divider(height: 1, color: FlixieColors.tabBarBorder),
              Expanded(
                  child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: reviews.length,
                      itemBuilder: (_, index) => ReviewCard(
                          key: ValueKey(reviews[index].id),
                          review: reviews[index],
                          currentUserId: currentUserId))),
            ])),
      );
}
