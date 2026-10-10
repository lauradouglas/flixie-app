import 'package:flutter_test/flutter_test.dart';
import 'journey.dart';

void main() {
  testWidgets(
      'inbox polling and overlapping refresh baseline',
      (tester) => pollingJourney(tester,
          before: const bool.fromEnvironment('INBOX_BEFORE')));
}
