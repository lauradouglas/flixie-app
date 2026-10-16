import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Measures the bounded set of cards at page width before laying out the pager.
/// Measurement cards never paint, accept input, or enter accessibility traversal.
class ContentSizedCarousel extends MultiChildRenderObjectWidget {
  ContentSizedCarousel({
    super.key,
    required Widget child,
    required List<Widget> measurements,
    required this.viewportFraction,
  }) : super(children: [
          child,
          ...measurements.map((card) => _Measurement(child: card))
        ]);

  final double viewportFraction;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderContentSizedCarousel(viewportFraction);

  @override
  void updateRenderObject(
      BuildContext context, covariant RenderObject renderObject) {
    (renderObject as _RenderContentSizedCarousel).viewportFraction =
        viewportFraction;
  }
}

class _CarouselParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderContentSizedCarousel extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox,
            ContainerBoxParentData<RenderBox>> {
  _RenderContentSizedCarousel(this._viewportFraction);
  double _viewportFraction;
  set viewportFraction(double value) {
    if (_viewportFraction == value) return;
    _viewportFraction = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    child.parentData = _CarouselParentData();
  }

  @override
  void performLayout() {
    final pager = firstChild!;
    double height = 0;
    RenderBox? measurement = childAfter(pager);
    while (measurement != null) {
      measurement.layout(
          BoxConstraints.tightFor(
              width: constraints.maxWidth * _viewportFraction),
          parentUsesSize: true);
      // Offstage reports zero size but lays its card out at its natural height.
      final measuredHeight = (measurement as _RenderMeasurement).measuredHeight;
      if (measuredHeight > height) height = measuredHeight;
      measurement = childAfter(measurement);
    }
    size = constraints.constrain(Size(constraints.maxWidth, height));
    pager.layout(BoxConstraints.tight(size));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      context.paintChild(firstChild!, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      firstChild!.hitTest(result, position: position);

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) =>
      visitor(firstChild!);
}

class _Measurement extends Offstage {
  const _Measurement({required super.child}) : super(offstage: true);
  @override
  RenderOffstage createRenderObject(BuildContext context) => _RenderMeasurement();
}

class _RenderMeasurement extends RenderOffstage {
  _RenderMeasurement() : super(offstage: true);
  double measuredHeight = 0;
  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    measuredHeight = child!.size.height;
  }
}
