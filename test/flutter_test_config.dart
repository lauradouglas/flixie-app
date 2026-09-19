import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'support/raster_golden_comparator.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final previous = goldenFileComparator;
  if (previous is LocalFileComparator) {
    goldenFileComparator = RasterGoldenComparator(
        previous.basedir.resolve('flutter_test_config.dart'));
  }
  try {
    await testMain();
  } finally {
    goldenFileComparator = previous;
  }
}
