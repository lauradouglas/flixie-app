import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'support/raster_golden_comparator.dart';

void main() {
  final baseline = Uint8List.fromList(List.filled(40000, 128));
  test('allows at most five sparse two-level RGB changes in 10000 pixels', () {
    final actual = Uint8List.fromList(baseline);
    expect(isRasterRounding(actual, baseline), isTrue);
    for (var i = 0; i < 5; i++) {
      actual[i * 4] += 2;
    }
    expect(isRasterRounding(actual, baseline), isTrue);
    actual[20]++;
    expect(isRasterRounding(actual, baseline), isFalse);
  });
  test('rejects even one meaningful colour change or alpha change', () {
    final actual = Uint8List.fromList(baseline)..[0] = 131;
    expect(isRasterRounding(actual, baseline), isFalse);
    actual[0] = 128;
    actual[3]++;
    expect(isRasterRounding(actual, baseline), isFalse);
  });
  test('rejects changed buffer dimensions and widespread rounding', () {
    expect(isRasterRounding(Uint8List(4), baseline), isFalse);
    final actual = Uint8List.fromList(baseline);
    for (var i = 0; i < actual.length; i += 4) {
      actual[i]++;
    }
    expect(isRasterRounding(actual, baseline), isFalse);
  });
}
