import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

enum FlixieToastType { success, info, warning, error }

extension FlixieToastAppearance on FlixieToastType {
  Color get colour => switch (this) {
        FlixieToastType.success => const Color(0xFF65E9A5),
        FlixieToastType.info => const Color(0xFFBF95F9),
        FlixieToastType.warning => const Color(0xFFFFD166),
        FlixieToastType.error => const Color(0xFFFF7387),
      };
  IconData get icon => switch (this) {
        FlixieToastType.success => Icons.check_circle_outline,
        FlixieToastType.info => Icons.info_outline,
        FlixieToastType.warning => Icons.error_outline,
        FlixieToastType.error => Icons.error_outline,
      };
}

/// App-wide bottom feedback. Actions must perform a real retry or restoration.
/// ScaffoldMessenger positions floating toasts above navigation and keyboards.
class FlixieToast extends SnackBar {
  FlixieToast({
    super.key,
    required Widget content,
    required FlixieToastType type,
    SnackBarAction? action,
    Duration? duration,
    bool? persist,
    // Accepted during migration; surfaces always use the shared styling.
    Color? backgroundColor,
    SnackBarBehavior? behavior,
  }) : super(
          backgroundColor: Colors.transparent,
          elevation: 0,
          persist: persist ?? false,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(8),
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          duration: duration ??
              Duration(
                  seconds:
                      action != null || type == FlixieToastType.error ? 5 : 4),
          content: _ToastBody(content: content, type: type, action: action),
        );
}

class _ToastBody extends StatefulWidget {
  const _ToastBody({required this.content, required this.type, this.action});
  final Widget content;
  final FlixieToastType type;
  final SnackBarAction? action;
  @override
  State<_ToastBody> createState() => _ToastBodyState();
}

class _ToastBodyState extends State<_ToastBody> {
  bool _used = false;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final light = Theme.of(context).brightness == Brightness.light;
        final accent = light
            ? switch (widget.type) {
                FlixieToastType.success => context.colors.success,
                FlixieToastType.info => context.colors.primaryText,
                FlixieToastType.warning => context.colors.warning,
                FlixieToastType.error => context.colors.danger,
              }
            : widget.type.colour;
        final content = widget.content;
        final message = DefaultTextStyle(
          style: TextStyle(
              fontFamily: 'Manrope',
              color: light ? context.colors.textPrimary : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.35),
          child: content is Text
              ? Text(content.data ?? '', semanticsLabel: content.semanticsLabel)
              : content,
        );
        final action = widget.action;
        final actionButton = action == null
            ? null
            : TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: accent,
                  minimumSize: const Size(48, 48),
                  textStyle: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 14,
                      fontWeight: FontWeight.w700),
                ),
                onPressed: _used
                    ? null
                    : () {
                        setState(() => _used = true);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar(
                            reason: SnackBarClosedReason.action);
                        action.onPressed();
                      },
                child: Text(action.label),
              );
        final stackAction = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: light ? context.colors.surface : const Color(0xFF261B40),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: accent.withValues(alpha: light ? .3 : .65)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                ExcludeSemantics(
                    child: Icon(widget.type.icon, color: accent, size: 24)),
                const SizedBox(width: 12),
                Expanded(child: message),
                if (actionButton != null && !stackAction) ...[
                  const SizedBox(width: 8),
                  actionButton,
                ],
              ]),
              if (actionButton != null && stackAction)
                Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: actionButton),
            ]));
      });
}

/// Replace stale feedback rather than leaving it queued behind an Undo toast.
extension FlixieToastMessenger on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showFlixieToast(
      FlixieToast toast) {
    clearSnackBars();
    return showSnackBar(toast);
  }
}
