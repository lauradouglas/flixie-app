import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class FriendPlanButton extends StatelessWidget {
  const FriendPlanButton(
      {super.key,
      required this.label,
      required this.icon,
      required this.action,
      this.primary = true,
      this.busy = false});
  final String label;
  final IconData icon;
  final VoidCallback? action;
  final bool primary, busy;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: SizedBox(
          width: double.infinity,
          child: primary
              ? FilledButton.icon(
                  onPressed: busy ? null : action,
                  icon: Icon(icon),
                  label: Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16)))
              : TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.primaryText,
                    backgroundColor: context.colors.surfaceElevated,
                    minimumSize: const Size(0, 48),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: busy ? null : action,
                  icon: Icon(icon),
                  label: Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16))),
        ),
      );
}
