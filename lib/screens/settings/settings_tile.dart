import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

const double _kSettingsCornerRadius = 14;

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLast = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  /// When [true] the bottom divider is hidden (last item in a group).
  final bool isLast;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(_kSettingsCornerRadius),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: FlixieColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: FlixieColors.primary, size: 18),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  trailing ??
                      const Icon(Icons.chevron_right,
                          color: FlixieColors.medium, size: 20),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),
      ],
    );
  }
}
