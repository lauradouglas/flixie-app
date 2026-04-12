import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Parses the `iconColor` map from a user object into a [Color].
///
/// Handles both `hexCode` and `hex` key names for backwards compatibility.
Color avatarColorFromIconColor(
  Map<String, dynamic>? iconColor, {
  Color fallback = FlixieColors.primary,
}) {
  if (iconColor == null) return fallback;
  final hex = ((iconColor['hexCode'] ?? iconColor['hex']) as String? ?? '')
      .replaceAll('#', '');
  return Color(int.tryParse('0xFF$hex') ?? fallback.value);
}
