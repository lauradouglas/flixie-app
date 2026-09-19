import 'package:flutter/material.dart';

import 'package:flixie_app/core/widgets/flixie_section_header.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return FlixieSectionHeader(
      title: title,
      accentHeight: 18,
    );
  }
}
