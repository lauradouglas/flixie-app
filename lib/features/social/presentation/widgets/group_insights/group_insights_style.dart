import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

BoxDecoration groupInsightsDecoration(BuildContext context) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        context.colors.surfaceElevated.withValues(alpha: 0.72),
        context.colors.surface.withValues(alpha: 0.94),
      ],
    ),
    boxShadow: [
      BoxShadow(
        color: FlixieColors.primary.withValues(alpha: 0.1),
        blurRadius: 14,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

String insightsRelativeDate(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inHours < 1) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${dt.day}/${dt.month}/${dt.year}';
}

String? insightsPosterUrl(String? poster, String baseUrl) {
  if (poster == null) return null;
  final value = poster.trim();
  if (value.isEmpty || value == 'null' || value == 'undefined') return null;
  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }
  if (value.startsWith('//')) return 'https:$value';
  if (value.startsWith('/')) return '$baseUrl$value';
  return '$baseUrl/$value';
}
