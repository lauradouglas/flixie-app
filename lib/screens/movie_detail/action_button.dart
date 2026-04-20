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
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final Color color;
  final bool isLoading;
  final int bounceKey;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final buttonColor = isActive ? color : Colors.grey;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        side: BorderSide(
          color: isActive ? color : Colors.grey.withOpacity(0.5),
          width: 1.5,
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 24,
            width: 24,
            child: isLoading
                ? CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(buttonColor),
                  )
                : TweenAnimationBuilder<double>(
                    key: ValueKey<String>('$icon-$bounceKey'),
                    duration: const Duration(milliseconds: 500),
                    tween: Tween<double>(begin: 1.4, end: 1.0),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return ScaleTransition(
                              scale: animation,
                              child: child,
                            );
                          },
                          child: Icon(
                            icon,
                            key: ValueKey<IconData>(icon),
                            size: 24,
                            color: buttonColor,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: buttonColor,
            ),
          ),
        ],
      ),
    );
  }
}
