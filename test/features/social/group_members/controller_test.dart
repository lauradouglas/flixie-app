import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/features/social/presentation/controllers/group_members_controller.dart';

List<GroupMember> fixture() => List.generate(
    100,
    (i) => GroupMember(
        groupId: 'fictional-club',
        memberId: '$i',
        username: 'AlienFan$i',
        role: i == 99
            ? 'OWNER'
            : i == 98
                ? 'ADMIN'
                : 'MEMBER',
        inviteStatus: i.isEven ? 'PENDING' : 'ACCEPTED',
        profileBadges: const ['FOUNDER']));
void main() {
  test('100 members sort once and search/pending preserve badges', () async {
    final c = GroupMembersController(
        groupId: 'fictional-club',
        accountId: '99',
        fetch: (_) async => fixture());
    addTearDown(c.dispose);
    await c.load();
    expect(c.members.first.memberId, '99');
    expect(c.members[1].memberId, '98');
    final all = c.filter('');
    for (var i = 0; i < 100; i++) {
      expect(identical(c.filter(''), all), isTrue);
    }
    expect(c.filter('alienfan2').length, 11);
    expect(c.filter('', pendingOnly: true).length, 50);
    expect(c.members.first.profileBadges, ['FOUNDER']);
  });
  test('overlapping refresh publishes once; disposal rejects response',
      () async {
    final response = Completer<List<GroupMember>>();
    var reads = 0;
    var updates = 0;
    final c = GroupMembersController(
        groupId: 'g',
        accountId: 'a',
        fetch: (_) {
          reads++;
          return response.future;
        });
    c.addListener(() => updates++);
    final a = c.load();
    final b = c.load();
    expect(identical(a, b), true);
    expect(reads, 1);
    c.dispose();
    response.complete(fixture());
    await a;
    expect(updates, 0);
    expect(c.members, isEmpty);
  });
  test('failed read can retry and signed-out owner performs no reads',
      () async {
    var reads = 0;
    final c = GroupMembersController(
        groupId: 'g',
        accountId: 'a',
        fetch: (_) async {
          if (reads++ == 0) throw StateError('offline');
          return fixture();
        });
    addTearDown(c.dispose);
    await c.load();
    expect(c.error, isNotNull);
    await c.load();
    expect(c.error, isNull);
    expect(c.members.length, 100);
    final out = GroupMembersController(
        groupId: 'g',
        accountId: null,
        fetch: (_) async {
          throw StateError('must not fetch');
        });
    addTearDown(out.dispose);
    await out.load();
    expect(out.error, isNull);
    expect(out.members, isEmpty);
  });
  test('mutation waits for older refresh then requests fresh members',
      () async {
    final old = Completer<List<GroupMember>>();
    var reads = 0;
    final c = GroupMembersController(
        groupId: 'g',
        accountId: 'a',
        fetch: (_) => reads++ == 0 ? old.future : Future.value(fixture()));
    addTearDown(c.dispose);
    final loading = c.load();
    final mutation = c.reloadAfterMutation();
    old.complete([]);
    await loading;
    await mutation;
    expect(reads, 2);
    expect(c.members.length, 100);
  });
}
