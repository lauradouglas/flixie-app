import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Allows only sparse, near-identical RGB rounding across macOS renderers.
/// Alpha, dimensions, and meaningful pixel changes remain exact failures.
bool isRasterRounding(Uint8List actual, Uint8List expected) {
  if (actual.length != expected.length ||
      actual.length % 4 != 0 ||
      actual.isEmpty) {
    return false;
  }
  var changed = 0;
  final maxChanged = (actual.length ~/ 4 * .0005).floor(); // 0.05% of pixels
  for (var i = 0; i < actual.length; i += 4) {
    if (actual[i + 3] != expected[i + 3]) return false;
    var differs = false;
    for (var channel = 0; channel < 3; channel++) {
      final delta = (actual[i + channel] - expected[i + channel]).abs();
      if (delta > 2) return false;
      differs |= delta != 0;
    }
    if (differs && ++changed > maxChanged) return false;
  }
  return true;
}

class RasterGoldenComparator extends LocalFileComparator {
  RasterGoldenComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final expected = Uint8List.fromList(await getGoldenBytes(golden));
    if (listEquals(imageBytes, expected)) return true;
    final actualCodec = await ui.instantiateImageCodec(imageBytes);
    final expectedCodec = await ui.instantiateImageCodec(expected);
    final actualImage = (await actualCodec.getNextFrame()).image;
    final expectedImage = (await expectedCodec.getNextFrame()).image;
    try {
      if (actualImage.width == expectedImage.width &&
          actualImage.height == expectedImage.height) {
        final actualPixels =
            (await actualImage.toByteData())!.buffer.asUint8List();
        final expectedPixels =
            (await expectedImage.toByteData())!.buffer.asUint8List();
        if (isRasterRounding(actualPixels, expectedPixels)) return true;
      }
    } finally {
      actualImage.dispose();
      expectedImage.dispose();
      actualCodec.dispose();
      expectedCodec.dispose();
    }
    // Preserve Flutter's normal failure images and diagnostic output.
    return super.compare(imageBytes, golden);
  }
}
