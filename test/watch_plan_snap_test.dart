import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/pages/home_screen.dart';

void main() {
  test('released drag settles on a whole card and fling advances', () {
    const physics = WatchPlanSnapPhysics(itemExtent: 360);
    FixedScrollMetrics metrics(double offset) => FixedScrollMetrics(
      minScrollExtent: 0, maxScrollExtent: 1080, pixels: offset,
      viewportDimension: 400, axisDirection: AxisDirection.right, devicePixelRatio: 1);
    expect(physics.createBallisticSimulation(metrics(230), 0)!.x(10), closeTo(360, .1));
    expect(physics.createBallisticSimulation(metrics(390), 700)!.x(10), closeTo(720, .1));
    expect(physics.createBallisticSimulation(metrics(690), -700)!.x(10), closeTo(360, .1));
  });
}
