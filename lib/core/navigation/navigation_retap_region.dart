import '../widgets/flixie_refresh.dart';
import 'package:flutter/material.dart';

/// Reuses the visible page's pull-to-refresh behavior without replacing its
/// state or resetting its filters. Retained, offstage tabs are never refreshed.
class NavigationRetapRegion extends StatefulWidget {
  const NavigationRetapRegion({super.key, required this.child});
  final Widget child;

  @override
  State<NavigationRetapRegion> createState() => NavigationRetapRegionState();
}

class NavigationRetapRegionState extends State<NavigationRetapRegion> {
  bool _refreshing = false;

  Future<void> refresh() async {
    if (_refreshing || !mounted) return;
    RefreshIndicatorState? indicator;
    FlixieRefreshState? nativeIndicator;
    ScrollableState? scrollable;
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Offstage && widget.offstage) return;
      if (widget is Visibility && !widget.visible) return;
      if (element is StatefulElement) {
        final state = element.state;
        if (state is FlixieRefreshState) nativeIndicator ??= state;
        if (state is RefreshIndicatorState) indicator ??= state;
        if (state is ScrollableState &&
            axisDirectionToAxis(state.position.axisDirection) ==
                Axis.vertical) {
          scrollable ??= state;
        }
      }
      element.visitChildren(visit);
    }

    context.visitChildElements(visit);
    _refreshing = true;
    try {
      final position = scrollable?.position;
      if (position != null && position.hasContentDimensions) {
        if (MediaQuery.disableAnimationsOf(context)) {
          position.jumpTo(position.minScrollExtent);
        } else {
          await position.animateTo(position.minScrollExtent,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic);
        }
      }
      if (mounted && nativeIndicator != null && nativeIndicator!.mounted) {
        await nativeIndicator!.show();
      } else if (mounted && indicator != null && indicator!.mounted) {
        await indicator!.show(atTop: true);
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
