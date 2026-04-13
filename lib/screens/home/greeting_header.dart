import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({super.key, this.name, required this.onDismiss});

  final String? name;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final label = name != null
        ? '${greeting()}, $name \u{1F44B}'
        : '${greeting()} \u{1F44B}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              FlixieColors.primary.withValues(alpha: 0.25),
              FlixieColors.secondary.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: FlixieColors.primary.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [FlixieColors.primary, FlixieColors.secondary],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            GestureDetector(
              onTap: onDismiss,
              child:
                  const Icon(Icons.close, size: 18, color: FlixieColors.medium),
            ),
          ],
        ),
      ),
    );
  }
}
