import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'friend_plan_styles.dart';

/// The next steps for a saved, undated plan, ordered by emphasis.
class FriendPlanSavedActions extends StatelessWidget {
  const FriendPlanSavedActions({
    super.key,
    required this.friend,
    required this.onAddDate,
    required this.onWatched,
    required this.onChangeMovie,
    required this.onMessage,
    this.busy = false,
  });

  final String friend;
  final VoidCallback onAddDate, onWatched, onChangeMovie;
  final VoidCallback? onMessage;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final shape =
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 52)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      shape: WidgetStatePropertyAll(shape),
    );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Text('Plan saved',
          style: friendPlanTitle.copyWith(color: context.colors.textPrimary)),
      const SizedBox(height: 8),
      Text('Add a date when you know, or log your watch afterwards.',
          style: friendPlanBody.copyWith(color: context.colors.light)),
      const SizedBox(height: 20),
      FilledButton.icon(
        style: buttonStyle,
        onPressed: busy ? null : onAddDate,
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Add a date', textAlign: TextAlign.center),
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.primaryText,
          side: BorderSide(color: context.colors.primaryText),
        ).merge(buttonStyle),
        onPressed: busy ? null : onWatched,
        icon: const Icon(Icons.check_rounded),
        label: const Text('We watched it', textAlign: TextAlign.center),
      ),
      const SizedBox(height: 20),
      Material(
        color: context.colors.surfaceElevated,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          _row(context, 'Change movie', Icons.movie_outlined, onChangeMovie),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1, color: context.colors.tabBarBorder),
          ),
          _row(
              context, 'Message $friend', Icons.chat_bubble_outline, onMessage),
        ]),
      ),
    ]);
  }

  Widget _row(
      BuildContext context, String label, IconData icon, VoidCallback? action) {
    final enabled = !busy && action != null;
    final color = enabled ? context.colors.textPrimary : context.colors.medium;
    return InkWell(
      onTap: enabled ? action : null,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            Icon(icon, size: 22, color: context.colors.primaryText),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(color: color))),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: context.colors.medium),
          ]),
        ),
      ),
    );
  }
}
