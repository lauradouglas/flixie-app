import 'movie_list_detail_test.dart' as list_detail;
import 'settings_editor_test.dart' as settings;
import 'package:patrol/patrol.dart';
import '../test/features/profile/editor_safety_test.dart'
    show profileDraftJourney;
import '../test/features/movies/movie_lists/editor_journey.dart'
    show movieListsEditorJourney;

void main() {
  list_detail.main();
  settings.main();
  patrolTest('Profile edit keeps and discards drafts explicitly', ($) async {
    await profileDraftJourney($.tester);
  });
  patrolTest('List editor retains changes through retry and saves', ($) async {
    await movieListsEditorJourney($.tester);
  });
}
