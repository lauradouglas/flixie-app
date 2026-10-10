import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class PersonEmptySection extends StatelessWidget {
  const PersonEmptySection(this.title, this.message, this.icon, {super.key});
  final String title, message;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.colors.tabBarBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: context.colors.medium, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: context.colors.light,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(color: context.colors.medium, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
