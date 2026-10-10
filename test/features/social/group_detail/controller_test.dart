import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/controllers/group_detail_controller.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/movie_list.dart';

void main() {
  const group = Group(id: 'g', name: 'Alien fans', ownerId: 'viewer');
  const member = GroupMember(
      groupId: 'g',
      memberId: 'viewer',
      role: 'OWNER',
      inviteStatus: 'ACCEPTED',
      profileBadges: ['EARLY_ADOPTER']);
  late GroupDetailController controller;
  late List<String> calls;
  bool current = true;
  Future<List<MovieList>> Function(String)? lists;
  Future<List<GroupWatchRequest>> Function(String)? requests;
  Future<Group> Function(String)? fetch;
  setUp(() {
    current = true;
    calls = [];
    lists = null;
    requests = null;
    fetch = null;
    controller = GroupDetailController(
        groupId: 'g',
        accountId: 'viewer',
        isCurrent: () => current,
        fetchGroup: (id) {
          calls.add('group:$id');
          return fetch?.call(id) ?? Future.value(group);
        },
        fetchMembers: (id) async {
          calls.add('members:$id');
          return [member];
        },
        fetchLists: (id) {
          calls.add('lists:$id');
          return lists?.call(id) ?? Future.value([]);
        },
        fetchRequests: (id) {
          calls.add('requests:$id');
          return requests?.call(id) ?? Future.value([]);
        });
  });
  tearDown(() => controller.dispose());
  test(
      'core content appears while optional reads remain pending; load coalesces',
      () async {
    final pendingLists = Completer<List<MovieList>>();
    final pendingRequests = Completer<List<GroupWatchRequest>>();
    lists = (_) => pendingLists.future;
    requests = (_) => pendingRequests.future;
    final first = controller.load();
    final second = controller.load();
    await Future<void>.delayed(Duration.zero);
    expect(controller.group, group);
    expect(controller.loading, false);
    expect(controller.listsLoading, true);
    expect(controller.memberCount, 1);
    expect(controller.members.single.profileBadges, ['EARLY_ADOPTER']);
    expect(calls, ['group:g', 'members:g', 'lists:viewer', 'requests:g']);
    pendingLists.complete([]);
    pendingRequests.complete([]);
    await Future.wait([first, second]);
    expect(controller.listsLoading, false);
  });
  test('old account/group replies cannot publish or notify', () async {
    final pending = Completer<Group>();
    fetch = (_) => pending.future;
    final work = controller.load();
    await Future<void>.delayed(Duration.zero);
    var changes = 0;
    controller.addListener(() => changes++);
    current = false;
    pending.complete(group);
    await work;
    expect(controller.group, isNull);
    expect(changes, 0);
  });
  test('disposed owner ignores outstanding replies', () async {
    final pending = Completer<Group>();
    fetch = (_) => pending.future;
    final work = controller.load();
    controller.dispose();
    pending.complete(group);
    await work;
    expect(controller.group, isNull);
    // Replace so tearDown disposes a live owner.
    controller = GroupDetailController(
        groupId: 'other',
        accountId: null,
        isCurrent: () => true,
        fetchRequests: (_) async => []);
  });
  test('list failure is not mistaken for an empty list and retry recovers',
      () async {
    lists = (_) => Future.error(StateError('offline'));
    await controller.load();
    expect(controller.group, group);
    expect(controller.listsFailed, true);
    expect(controller.listsLoading, false);
    lists = (_) async => [];
    await controller.load();
    expect(controller.listsFailed, false);
    expect(controller.lists, isEmpty);
    expect(calls, hasLength(8));
  });
  test('core failure is retryable', () async {
    fetch = (_) => Future.error(StateError('offline'));
    await controller.load();
    expect(controller.error, isNotNull);
    expect(controller.loading, false);
    fetch = (_) async => group;
    await controller.load();
    expect(controller.error, isNull);
    expect(controller.group, group);
  });
}
