import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'constants.dart';

const double _kTileHorizontalPadding = 16;
const double _kTileIconSize = 34;
const double _kTileGap = 14;
const double _kDividerLeftInset =
    _kTileHorizontalPadding + _kTileIconSize + _kTileGap;

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
            borderRadius: BorderRadius.circular(kSettingsCornerRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _kTileHorizontalPadding,
                vertical: 14,
              ),
              child: Row(
                children: [
                  Container(
                    width: _kTileIconSize,
                    height: _kTileIconSize,
                    decoration: BoxDecoration(
                      color: FlixieColors.surfaceElevated,
                      border: Border.all(
                        color: FlixieColors.tabBarBorder,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: FlixieColors.primary, size: 18),
                  ),
                  const SizedBox(width: _kTileGap),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: FlixieColors.textPrimary,
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
            padding: const EdgeInsets.only(left: _kDividerLeftInset),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: FlixieColors.tabBarBorder,
            ),
          ),
      ],
    );
  }
}
