import 'package:flutter/cupertino.dart';

/// Opens immediately, while retaining iOS's interactive edge-swipe back.
class InstantSwipePage<T> extends Page<T> {
  const InstantSwipePage({super.key, super.name, required this.child});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => _InstantSwipeRoute<T>(this);
}

class _InstantSwipeRoute<T> extends CupertinoPageRoute<T> {
  _InstantSwipeRoute(InstantSwipePage<T> page)
      : super(settings: page, builder: (_) => page.child);

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);
}
