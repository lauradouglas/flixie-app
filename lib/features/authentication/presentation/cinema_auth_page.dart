import 'package:flutter/cupertino.dart';

/// Standard interactive iOS navigation with a bounded Cinema light entrance.
class CinemaAuthPage extends Page<void> {
  const CinemaAuthPage({super.key, super.name, required this.child});
  final Widget child;

  @override
  Route<void> createRoute(BuildContext context) => _CinemaAuthRoute(
      this, MediaQuery.maybeOf(context)?.disableAnimations ?? false);
}

class _CinemaAuthRoute extends CupertinoPageRoute<void> {
  _CinemaAuthRoute(CinemaAuthPage page, this.reducedMotion)
      : super(settings: page, builder: (_) => page.child);
  final bool reducedMotion;

  @override
  Duration get transitionDuration =>
      Duration(milliseconds: reducedMotion ? 0 : 360);
  @override
  Duration get reverseTransitionDuration =>
      Duration(milliseconds: reducedMotion ? 0 : 280);
}
