import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/show.dart';

String? showYearRange(TvShow show) {
  final first = DateTime.tryParse(show.firstAirDate ?? '')?.year;
  if (first == null) return null;
  final status = show.status?.trim().toLowerCase();
  if (status == 'returning series' ||
      status == 'in production' ||
      status == 'planned') {
    return '$first–present';
  }
  final last = DateTime.tryParse(show.lastAirDate ?? '')?.year;
  return last != null && last > first ? '$first–$last' : '$first';
}

class ShowStatusBadge extends StatelessWidget {
  const ShowStatusBadge({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final color = switch (status.trim().toLowerCase()) {
      'ended' => light ? const Color(0xFF995000) : const Color(0xFFFFB16B),
      'returning series' => context.colors.success,
      'canceled' || 'cancelled' => context.colors.danger,
      'in production' => context.colors.primaryText,
      'planned' ||
      'pilot' =>
        light ? const Color(0xFF16658C) : const Color(0xFF8CCEFF),
      _ => context.colors.light,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .12),
          borderRadius: BorderRadius.circular(99)),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
