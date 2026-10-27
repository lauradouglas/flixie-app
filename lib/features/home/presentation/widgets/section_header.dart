import 'home_tablet_layout.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/core/widgets/flixie_section_header.dart';

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final EdgeInsetsGeometry? tabletPadding;
  final bool compact;
  const HomeSectionHeader(
      {super.key,
      required this.title,
      this.onSeeAll,
      this.tabletPadding,
      this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (compact || HomeTabletLayout.active(context)) {
      return Padding(
          padding: tabletPadding ?? const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(
                child: Semantics(
                    header: true,
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary)))),
            if (onSeeAll != null)
              TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 12)),
                  child: const Text('See all'))
          ]));
    }
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
