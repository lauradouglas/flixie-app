import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A refresh header that moves with iOS content and retains existing list state.
/// Supports the vertical scroll views used by the main navigation destinations.
class FlixieRefresh extends StatefulWidget {
  const FlixieRefresh(
      {super.key,
      required this.onRefresh,
      required this.child,
      this.color,
      this.backgroundColor});
  final Future<void> Function() onRefresh;
  final Widget child;
  final Color? color;
  final Color? backgroundColor;

  @override
  State<FlixieRefresh> createState() => FlixieRefreshState();
}

class FlixieRefreshState extends State<FlixieRefresh> {
  final _materialKey = GlobalKey<RefreshIndicatorState>();
  Future<void>? _pending;
  bool _programmatic = false;

  Future<void> _run() {
    if (_pending != null) return _pending!;
    final completer = Completer<void>();
    _pending = completer.future;
    Future<void>.sync(widget.onRefresh)
        .then(completer.complete, onError: completer.completeError)
        .whenComplete(() {
      _pending = null;
      if (mounted && _programmatic) setState(() => _programmatic = false);
    });
    return completer.future;
  }

  Future<void> show() {
    if (_pending != null) return _pending!;
    if (_materialKey.currentState != null) {
      return _materialKey.currentState!.show();
    }
    setState(() => _programmatic = true);
    return _run();
  }

  Widget _header(
      RefreshIndicatorMode mode, double pulled, double trigger, double extent) {
    final armed = mode == RefreshIndicatorMode.armed;
    final loading = mode == RefreshIndicatorMode.refresh || _programmatic;
    return ClipRect(
        child: OverflowBox(
      minHeight: 0,
      maxHeight: 64,
      alignment: Alignment.bottomCenter,
      child: SizedBox(
          height: 64,
          child: Center(
              child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const CupertinoActivityIndicator()
              else
                Icon(armed ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 18),
              const SizedBox(width: 8),
              Flexible(
                  child: Text(
                      loading
                          ? 'Refreshing…'
                          : armed
                              ? 'Release to refresh'
                              : 'Pull to refresh',
                      style: Theme.of(context).textTheme.bodySmall)),
            ],
          ))),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    if (platform != TargetPlatform.iOS && platform != TargetPlatform.macOS) {
      return RefreshIndicator.adaptive(
          key: _materialKey,
          onRefresh: _run,
          color: widget.color,
          backgroundColor: widget.backgroundColor,
          child: widget.child);
    }
    final child = widget.child;
    final List<Widget> slivers;
    ScrollController? controller;
    Key? scrollKey;
    bool? primary;
    ScrollViewKeyboardDismissBehavior dismiss =
        ScrollViewKeyboardDismissBehavior.manual;
    if (child is ScrollView) {
      assert(child.scrollDirection == Axis.vertical && !child.reverse);
      controller = child.controller;
      scrollKey = child.key;
      primary = child.primary;
      dismiss = child.keyboardDismissBehavior ??
          ScrollViewKeyboardDismissBehavior.manual;
      if (child is CustomScrollView) {
        slivers = child.slivers;
      } else if (child is ListView) {
        slivers = [
          SliverPadding(
              padding: child.padding ?? EdgeInsets.zero,
              sliver: SliverList(delegate: child.childrenDelegate))
        ];
      } else {
        throw FlutterError(
            'FlixieRefresh requires a ListView or CustomScrollView.');
      }
    } else if (child is SingleChildScrollView) {
      controller = child.controller;
      scrollKey = child.key;
      primary = child.primary;
      dismiss = child.keyboardDismissBehavior ??
          ScrollViewKeyboardDismissBehavior.manual;
      slivers = [
        SliverPadding(
            padding: child.padding ?? EdgeInsets.zero,
            sliver: SliverToBoxAdapter(child: child.child))
      ];
    } else {
      // Empty, error and initial loading states must also allow a refresh.
      slivers = [SliverFillRemaining(child: child)];
    }
    return CustomScrollView(
      key: scrollKey,
      controller: controller,
      primary: primary,
      keyboardDismissBehavior: dismiss,
      semanticChildCount: child is ScrollView ? child.semanticChildCount : null,
      physics:
          const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        CupertinoSliverRefreshControl(
            refreshTriggerPullDistance: 90,
            refreshIndicatorExtent: 64,
            onRefresh: _run,
            builder: (context, mode, pulled, trigger, extent) =>
                _header(mode, pulled, trigger, extent)),
        if (_programmatic)
          SliverToBoxAdapter(
              child: SizedBox(
                  height: 64,
                  child: _header(RefreshIndicatorMode.refresh, 64, 90, 64))),
        ...slivers,
      ],
    );
  }
}
