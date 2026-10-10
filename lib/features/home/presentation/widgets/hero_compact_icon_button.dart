import 'package:flutter/material.dart';

class HeroCompactIconButton extends StatelessWidget {
  const HeroCompactIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.isBusy = false,
    this.foregroundColor = Colors.white,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isBusy;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: isBusy ? null : onPressed,
        style: IconButton.styleFrom(
          minimumSize: const Size.square(44),
          foregroundColor: foregroundColor,
          backgroundColor: Colors.transparent,
        ),
        icon: isBusy
            ? _SpinningActionIcon(icon: icon, color: foregroundColor)
            : Icon(icon, color: foregroundColor, size: 24),
      ),
    );
  }
}

class _SpinningActionIcon extends StatefulWidget {
  const _SpinningActionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  State<_SpinningActionIcon> createState() => _SpinningActionIconState();
}

class _SpinningActionIconState extends State<_SpinningActionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Icon(widget.icon, color: widget.color, size: 22),
    );
  }
}
