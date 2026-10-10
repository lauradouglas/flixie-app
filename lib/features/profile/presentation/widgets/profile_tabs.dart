import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

import '../../models/profile_section.dart';

class ProfileTabSelector extends StatelessWidget {
  const ProfileTabSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final ProfileTab selected;
  final ValueChanged<ProfileTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
        children: ProfileTab.values
            .map((tab) => Expanded(
                  child: Semantics(
                    selected: tab == selected,
                    button: true,
                    child: InkWell(
                      onTap: () => onSelected(tab),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 4),
                        decoration: BoxDecoration(
                            border: Border(
                                bottom: BorderSide(
                                    width: tab == selected ? 3 : 1,
                                    color: tab == selected
                                        ? FlixieColors.primary
                                        : context.colors.tabBarBorder))),
                        child: Text(_tabLabel(tab),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: tab == selected
                                    ? context.colors.white
                                    : context.colors.light,
                                fontWeight: tab == selected
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                      ),
                    ),
                  ),
                ))
            .toList());
  }

  String _tabLabel(ProfileTab tab) {
    return switch (tab) {
      ProfileTab.library => 'Library',
      ProfileTab.activity => 'Activity',
      ProfileTab.stats => 'Stats',
    };
  }
}

class ProfileTabsDelegate extends SliverPersistentHeaderDelegate {
  ProfileTabsDelegate({required this.child, required this.height});
  final Widget child;
  final double height;
  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;
  @override
  Widget build(
          BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: context.colors.background, child: child);
  @override
  bool shouldRebuild(covariant ProfileTabsDelegate oldDelegate) => true;
}
