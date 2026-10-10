import 'package:patrol/patrol.dart';
import 'group_detail_memory_test.dart' as memory;
import 'support/group_watch_plan_journeys.dart';
import '../test/features/social/group_members/widget_test.dart' as members;
import '../test/features/social/group_detail/page_test.dart' as detail;
import '../test/features/social/group_chat/journey.dart' as chat;
import 'package:flixie_app/features/social/presentation/widgets/chat_tab.dart';

void main() {
  memory.main();
  groupWatchPlanJourneys((name, journey) {
    if (name.contains('account change closes') ||
        name.contains('simultaneous refresh signals')) {
      patrolTest(name, ($) => journey($));
    }
  });
  members.registerMemberJourneys(
      (name, body) => patrolTest(name, ($) => body($.tester)));
  detail.registerDetailJourneys(
      (name, body) => patrolTest(name, ($) => body($.tester)));
  patrolTest('chat tab activation and unmount release its subscription',
      ($) async {
    await chat.rebuildJourney(
        $.tester,
        (data, active) =>
            GroupChatTab(groupId: 'club', service: data, active: active));
  });
}
