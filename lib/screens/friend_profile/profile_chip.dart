import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FriendProfileChip extends StatelessWidget {
  const FriendProfileChip(
      {super.key,
      required this.icon,
      required this.label,
      required this.sublabel});
  final IconData icon;
  final String label;
  final String sublabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: FlixieColors.primary, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Text(sublabel,
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}
