import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Compact entry to an existing public Flixie destination.
class GuestHomeLinkCard extends StatelessWidget {
  const GuestHomeLinkCard(
      {super.key,
      required this.icon,
      required this.title,
      required this.onTap,
      this.subtitle,
      this.actionLabel});
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.primary.withValues(alpha: .18))),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(children: [
            Icon(icon, color: colors.primary, size: 28),
            const SizedBox(width: 16),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: TextStyle(
                          color: colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!,
                        style: TextStyle(
                            color: colors.light, fontSize: 12, height: 1.3)),
                  ],
                  if (actionLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(actionLabel!,
                        style: TextStyle(
                            color: colors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ])),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward,
                color: actionLabel == null ? colors.light : colors.primary,
                size: 20),
          ]),
        ),
      ),
    );
  }
}
