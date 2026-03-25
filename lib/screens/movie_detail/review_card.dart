import 'package:flutter/material.dart';

import '../../models/review.dart';
import '../../theme/app_theme.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final Review review;

  String _getInitials() {
    final username = review.user?.username ?? review.userId;
    return username.isNotEmpty ? username[0].toUpperCase() : '?';
  }

  String _getDisplayName() {
    return review.user?.username ?? 'Anonymous';
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
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ];
      final day = date.day.toString().padLeft(2, '0');
      final month = months[date.month - 1];
      final year = date.year.toString().substring(2);
      return '$day $month $year';
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2E42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Text(
            review.body,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
