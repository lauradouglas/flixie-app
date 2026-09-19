import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Consistent, theme-aware actions for movie and show details.
class MediaDetailAction extends StatelessWidget {
  const MediaDetailAction(
      {super.key,
      required this.icon,
      required this.label,
      this.badge,
      required this.isActive,
      required this.isLoading,
      required this.onTap});
  final IconData icon;
  final String label;
  final String? badge;
  final bool isActive, isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final toggle = label == 'Favourite' || label == 'Watchlist';
    final selected = isActive;
    final light = Theme.of(context).brightness == Brightness.light;
    final foreground = switch (label) {
      'Watchlist' => context.colors.warning,
      'Favourite' => context.colors.danger,
      'List' => context.colors.primaryText,
      'Plan' => context.colors.secondary,
      'Share' => light ? const Color(0xFF16658C) : const Color(0xFF8CCEFF),
      _ => context.colors.warning,
    };
    return Semantics(
      button: true,
      toggled: toggle ? isActive : null,
      label: label,
      child: Tooltip(
          message: label,
          child: InkWell(
            onTap: isLoading ? null : onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                          color: foreground.withValues(
                              alpha: selected ? .18 : .08),
                          borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: foreground))
                          : Icon(icon, size: 22, color: foreground)),
                  const SizedBox(height: 6),
                  Text(badge ?? label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: foreground,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight:
                              selected ? FontWeight.w600 : FontWeight.w500)),
                ])),
          )),
    );
  }
}
