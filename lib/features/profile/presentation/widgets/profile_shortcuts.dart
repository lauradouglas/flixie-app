import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// The two personal destinations between profile totals and library tabs.
class ProfileShortcuts extends StatelessWidget {
  const ProfileShortcuts(
      {super.key, required this.onPeople, required this.onDiary});
  final VoidCallback onPeople;
  final VoidCallback onDiary;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget destination(IconData icon, String label, VoidCallback onTap) =>
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Icon(icon, size: 22, color: colors.primaryText),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary))),
              const SizedBox(width: 12),
              Icon(Icons.chevron_right_rounded, size: 20, color: colors.medium),
            ]),
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Material(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          destination(Icons.people_outline, 'Friends & following', onPeople),
          Padding(
              padding: const EdgeInsets.only(left: 52, right: 16),
              child: Divider(
                  height: 1,
                  thickness: 1,
                  color: colors.primaryText.withValues(alpha: .12))),
          destination(Icons.auto_stories_outlined, 'Your film diary', onDiary),
        ]),
      ),
    );
  }
}
