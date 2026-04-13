import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class FriendGenreTag extends StatelessWidget {
  const FriendGenreTag({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FlixieColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.4)),
      ),
      child: Text(
        name,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }
}
