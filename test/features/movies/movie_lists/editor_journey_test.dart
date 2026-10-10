import 'package:flutter_test/flutter_test.dart';
import 'editor_journey.dart';

void main() {
  testWidgets(
      'lazy friends retry and failed save preserve draft before successful navigation',
      movieListsEditorJourney);
}
