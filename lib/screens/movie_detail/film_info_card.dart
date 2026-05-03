import 'package:flutter/material.dart';

import '../../models/movie.dart';
import '../../theme/app_theme.dart';

class FilmInfoCard extends StatelessWidget {
  const FilmInfoCard({
    super.key,
    required this.director,
    required this.writers,
    required this.producers,
    required this.movie,
  });

  final String? director;
  final List<String> writers;
  final List<String> producers;
  final Movie movie;

  @override
  Widget build(BuildContext context) {
    final hasProducers = producers.isNotEmpty;
    final hasDirector = director != null;
    final hasWriters = writers.isNotEmpty;
    final hasBudget = movie.budget != null && movie.budget! > 0;
    final hasCollection =
        movie.collection != null && movie.collection!['name'] != null;

    if (!hasProducers &&
        !hasDirector &&
        !hasWriters &&
        !hasBudget &&
        !hasCollection) {
      return const SizedBox.shrink();
    }

    Widget row(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    const divider = Column(
      children: [
        SizedBox(height: 12),
        Divider(color: Color(0xFF1E2D40), thickness: 1, height: 1),
        SizedBox(height: 12),
      ],
    );

    String formatBudget(int amount) {
      if (amount >= 1000000) {
        final m = amount / 1000000;
        return '\$${m % 1 == 0 ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
      }
      if (amount >= 1000) {
        return '\$${(amount / 1000).toStringAsFixed(0)}K';
      }
      return '\$$amount';
    }

    final rows = <Widget>[];
    if (hasDirector) rows.add(row('Director', director!));
    if (hasWriters) {
      if (rows.isNotEmpty) rows.add(divider);
      rows.add(row(
          writers.length == 1 ? 'Writer' : 'Writers', writers.join(', ')));
    }
    if (hasBudget) {
      if (rows.isNotEmpty) rows.add(divider);
      rows.add(row('Budget', formatBudget(movie.budget!)));
    }
    if (hasProducers) {
      if (rows.isNotEmpty) rows.add(divider);
      rows.add(row(producers.length == 1 ? 'Producer' : 'Producers',
          producers.join(', ')));
    }
    if (hasCollection) {
      if (rows.isNotEmpty) rows.add(divider);
      rows.add(row('Collection', movie.collection!['name'] as String));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2D40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}
