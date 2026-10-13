import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Small trophy crest; the category mark distinguishes each achievement family.
class MilestoneShield extends StatelessWidget {
  const MilestoneShield(
      {super.key, required this.group, this.family, this.earned = true});
  final String group;
  final String? family;
  final bool earned;
  @override
  Widget build(BuildContext context) {
    final color = !earned
        ? context.colors.medium
        : switch (group) {
            'Watching' => context.colors.warning,
            'Together' => context.colors.success,
            _ => context.colors.primaryText,
          };
    final icon = switch (family) {
      'films' => Icons.movie_outlined,
      'series' => Icons.tv_rounded,
      'countries' => Icons.public,
      'decades' => Icons.history,
      'collections' => Icons.collections_bookmark_outlined,
      'comfort' => Icons.favorite_outline,
      'recommendations' => Icons.thumb_up_outlined,
      _ => switch (group) {
          'Watching' => Icons.movie_outlined,
          'Exploring' => Icons.explore_outlined,
          'Together' => Icons.people_outline,
          _ => Icons.chat_bubble_outline,
        },
    };
    return ExcludeSemantics(
        child: SizedBox(
            width: 52,
            height: 62,
            child: CustomPaint(
                painter: _ShieldPainter(color),
                child: Column(children: [
                  const SizedBox(height: 9),
                  Icon(
                      earned
                          ? Icons.emoji_events_rounded
                          : Icons.emoji_events_outlined,
                      size: 25,
                      color: color),
                  const SizedBox(height: 3),
                  Icon(icon, size: 12, color: color),
                ]))));
  }
}

class _ShieldPainter extends CustomPainter {
  const _ShieldPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * .5, 2)
      ..quadraticBezierTo(size.width * .75, 7, size.width - 2, 7)
      ..lineTo(size.width - 2, size.height * .48)
      ..quadraticBezierTo(
          size.width - 2, size.height * .78, size.width * .5, size.height - 2)
      ..quadraticBezierTo(2, size.height * .78, 2, size.height * .48)
      ..lineTo(2, 7)
      ..quadraticBezierTo(size.width * .25, 7, size.width * .5, 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .10));
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_ShieldPainter oldDelegate) => color != oldDelegate.color;
}
