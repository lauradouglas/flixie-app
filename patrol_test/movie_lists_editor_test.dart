import 'package:patrol/patrol.dart';
import '../test/features/movies/movie_lists/editor_journey.dart';

void main() {
  patrolTest('Movie Lists lazy collaborators, retry and create navigation',
      ($) async {
    await movieListsEditorJourney($.tester);
  });
}
