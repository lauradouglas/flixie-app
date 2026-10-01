import 'package:flutter/material.dart';

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        trailingLabel: onSeeAll != null ? 'See all' : null,
        onTrailingTap: onSeeAll,
      ),
    );
  }
}
