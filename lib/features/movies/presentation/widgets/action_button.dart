import 'package:flutter/material.dart';

class MovieActionButton extends StatelessWidget {
  const MovieActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.color,
    required this.isLoading,
    required this.bounceKey,
    required this.onPressed,
    this.subtitle,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final bool isLoading;
  final int bounceKey;
  final VoidCallback? onPressed;

  /// Optional subtitle shown under the primary label (e.g. watch count).
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: onPressed != null && !isLoading,
      selected: isActive,
      label:
          '$label${isActive ? ', selected' : ''}${subtitle == null ? '' : ', $subtitle'}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onPressed,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: AnimatedContainer(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? color.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive
                      ? color.withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.25),
                          blurRadius: 12,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 24,
                    width: 24,
                    child: isLoading
                        ? CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          )
                        : TweenAnimationBuilder<double>(
                            key: ValueKey<String>('$icon-$bounceKey'),
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 500),
                            tween: Tween<double>(
                                begin: reduceMotion ? 1.0 : 1.4, end: 1.0),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) {
                              return Transform.scale(
                                scale: value,
                                child: AnimatedSwitcher(
                                  duration: reduceMotion
                                      ? Duration.zero
                                      : const Duration(milliseconds: 300),
                                  transitionBuilder: (child, animation) {
                                    return ScaleTransition(
                                      scale: animation,
                                      child: child,
                                    );
                                  },
                                  child: Icon(
                                    icon,
                                    key: ValueKey<IconData>(icon),
                                    size: 22,
                                    color: isActive
                                        ? color
                                        : Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive
                          ? color
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? color.withValues(alpha: 0.9)
                            : Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
