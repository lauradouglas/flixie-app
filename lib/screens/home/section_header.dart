import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/flixie_section_header.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const HomeSectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return FlixieSectionHeader(
      title: title,
      uppercase: false,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      trailingLabel: onSeeAll != null ? 'See all' : null,
      trailingColor: FlixieColors.primary,
      onTrailingTap: onSeeAll,
    );
  }
}
