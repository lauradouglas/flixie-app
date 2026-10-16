import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'personalized_recommendation_card.dart';
import 'pip_loading_strip.dart';

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
              padding: EdgeInsets.symmetric(vertical: 56),
              child: PipLoadingStrip(
                  size: 96, message: 'Finding fresh picks for you…')),
        ),
      );
}
