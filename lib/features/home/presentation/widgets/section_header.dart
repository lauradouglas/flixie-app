import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const HomeSectionHeader({super.key, required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FlixieSectionHeader(
        title: title,
        uppercase: false,
        maxTitleLines: 1,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
        trailingLabel: onSeeAll != null ? 'See all' : null,
        trailingColor: FlixieColors.primary,
        onTrailingTap: onSeeAll,
      ),
    );
  }
}
