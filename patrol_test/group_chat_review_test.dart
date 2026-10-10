import 'package:patrol/patrol.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_tab.dart';
import '../test/features/social/group_chat/journey.dart';
import '../test/features/movies/review/journey.dart';

void main() {
  patrolTest('Group Chat keeps one subscription through ten rebuilds',
      ($) async {
    await rebuildJourney(
        $.tester,
        (data, active) =>
            GroupChatTab(groupId: 'club', service: data, active: active));
  });
  patrolTest('Group Chat send retry and stream recovery', ($) async {
    await sendJourney($.tester);
  });
  patrolTest('Review reaction failure, retry and removal', ($) async {
    await reactionJourney($.tester);
  });
}
