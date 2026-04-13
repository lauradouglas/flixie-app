import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: FlixieColors.primary),
        title: Text(
          label,
          style: const TextStyle(color: FlixieColors.light, fontSize: 15),
        ),
        trailing: const Icon(Icons.chevron_right, color: FlixieColors.medium),
        onTap: onTap,
      ),
    );
  }
}
