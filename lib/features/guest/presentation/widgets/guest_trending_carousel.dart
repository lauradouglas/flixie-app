import 'package:flutter/material.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/features/home/presentation/widgets/trending_carousel.dart';

/// Guest actions and width constraints around the shared Home carousel.
class GuestTrendingCarousel extends StatelessWidget {
  const GuestTrendingCarousel(
      {super.key,
      required this.movies,
      required this.onDetails,
      required this.onSave,
      required this.onTrailer});
  final List<MovieShort> movies;
  final ValueChanged<MovieShort> onDetails, onSave, onTrailer;

  @override
  Widget build(BuildContext context) {
    if (movies.isEmpty) return const Text('More titles will appear here soon.');
    return TrendingCarousel(
      movies: movies,
      onDetails: onDetails,
      onSave: onSave,
      onTrailer: onTrailer,
    );
  }
}
