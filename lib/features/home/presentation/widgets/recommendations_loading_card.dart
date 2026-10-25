import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'personalized_recommendation_card.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

/// Holds the recommendation area's height while a fresh set is requested.
class RecommendationsLoadingCard extends StatelessWidget {
  const RecommendationsLoadingCard({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
              minHeight: PersonalizedRecommendationCard.height),
          decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16)),
          child: const Padding(
            padding: EdgeInsets.all(20),
            child:
                ContentPlaceholder(label: 'Loading recommendations', rows: 3),
          ),
        ),
      );
}
