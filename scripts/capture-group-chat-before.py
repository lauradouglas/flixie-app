#!/usr/bin/env python3
"""Run the archived chat widget with the same isolated 50-message test fixture.
Only service calls are redirected; original lifecycle/build logic is preserved.
"""
import gzip
import subprocess
from pathlib import Path

root = Path(__file__).resolve().parents[1]
evidence = root / 'docs/performance/2026-10-09-chat-review-validation'
tests = root / 'test/features/social/group_chat'
legacy = tests / 'legacy_chat.generated.dart'
runner = tests / 'baseline.generated_test.dart'
if legacy.exists() or runner.exists():
    raise SystemExit('Temporary baseline files already exist; inspect them first.')
source = gzip.decompress((evidence / 'chat_tab-before.dart.gz').read_bytes()).decode()
source = "import 'package:flixie_app/features/social/data/group_chat_service.dart';\n" + source
source = source.replace('this.active = true});',
                        'this.active = true, this.service = const GroupChatService()});')
source = source.replace('  final bool active;', '  final bool active;\n  final GroupChatService service;')
source = source.replace('GroupService.getGroup(widget.groupId)', 'widget.service.group(widget.groupId)')
source = source.replace('GroupService.getGroupMembers(widget.groupId)', 'widget.service.members(widget.groupId)')
source = source.replace('''ChatService.getOrCreateGroupConversation(
        creatorId: userId,
        pgGroupId: widget.groupId,
        name: group.name,
        memberIds: memberIds,
      )''', 'widget.service.conversation(userId, widget.groupId, group.name, memberIds)')
source = source.replace('ChatService.fetchMemberUsernames(conversationId)', 'widget.service.usernames(conversationId)')
source = source.replace('''GroupService.getConversationWatchRequests(
            conversationId,
            filter: WatchRequestFilter.all,
            userId: userId,
          )''', 'widget.service.requests(conversationId, userId)')
source = source.replace('ChatService.messagesStream(conversationId)', 'widget.service.messages(conversationId)')
try:
    legacy.write_text(source)
    runner.write_text("""import 'package:flutter_test/flutter_test.dart';
import 'legacy_chat.generated.dart';
import 'journey.dart';
void main() {
  testWidgets('archived chat: ten auth notifications during loading', (tester) =>
    loadingJourney(tester, (data) => GroupChatTab(groupId: 'club', service: data), before: true));
  testWidgets('archived 50-message chat: ten parent rebuilds', (tester) =>
    rebuildJourney(tester, (data, active) => GroupChatTab(
      groupId: 'club', service: data, active: active), before: true));
}
""")
    with (evidence / 'chat-before.log').open('w') as log:
        result = subprocess.run(['flutter', 'test', str(runner.relative_to(root))],
                                cwd=root, stdout=log, stderr=subprocess.STDOUT)
    raise SystemExit(result.returncode)
finally:
    legacy.unlink(missing_ok=True)
    runner.unlink(missing_ok=True)
