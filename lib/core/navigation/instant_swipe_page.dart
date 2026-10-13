import 'package:flutter/cupertino.dart';

/// Opens immediately, while retaining iOS's interactive edge-swipe back.
class InstantSwipePage<T> extends Page<T> {
  const InstantSwipePage(
      {super.key,
      super.name,
      required this.child,
      this.dismissDuration = const Duration(milliseconds: 300),
      this.swipeSettleDuration});

  final Widget child;
  final Duration dismissDuration;
  final Duration? swipeSettleDuration;

  @override
  Route<T> createRoute(BuildContext context) => _InstantSwipeRoute<T>(this);
}

class _InstantSwipeRoute<T> extends CupertinoPageRoute<T> {
  _InstantSwipeRoute(InstantSwipePage<T> page)
      : _page = page,
        super(settings: page, builder: (_) => page.child);

  final InstantSwipePage<T> _page;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Duration get reverseTransitionDuration => _page.dismissDuration;

  @override
  AnimationController createAnimationController() {
    final settle = _page.swipeSettleDuration;
    if (settle == null) return super.createAnimationController();
    return _SwipeSettleController(
        vsync: navigator!,
        duration: transitionDuration,
        reverseDuration: reverseTransitionDuration,
        settleDuration: settle);
  }
}

// Cupertino explicitly requests 350 ms after releasing a back swipe. Cap that
// settling phase without changing its native gesture thresholds or drag tracking.
class _SwipeSettleController extends AnimationController {
  _SwipeSettleController(
      {required super.vsync,
      required super.duration,
      required super.reverseDuration,
      required this.settleDuration});
  final Duration settleDuration;

  Duration? _bounded(Duration? value) =>
      value != null && value > settleDuration ? settleDuration : value;

  @override
  TickerFuture animateTo(double target,
          {Duration? duration, Curve curve = Curves.linear}) =>
      super.animateTo(target, duration: _bounded(duration), curve: curve);

  @override
  TickerFuture animateBack(double target,
          {Duration? duration, Curve curve = Curves.linear}) =>
      super.animateBack(target, duration: _bounded(duration), curve: curve);
}
