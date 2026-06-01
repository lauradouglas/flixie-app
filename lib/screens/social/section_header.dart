import 'package:flutter/material.dart';

import '../../widgets/flixie_section_header.dart';

class SocialSectionHeader extends StatelessWidget {
  const SocialSectionHeader({
    super.key,
    required this.title,
    this.badge,
    this.rightLabel,
  });

  final String title;
  final int? badge;
  final String? rightLabel;

  @override
  Widget build(BuildContext context) {
    return FlixieSectionHeader(
      title: title,
      uppercase: false,
      badge: badge,
      trailingLabel: rightLabel,
    );
  }
}
