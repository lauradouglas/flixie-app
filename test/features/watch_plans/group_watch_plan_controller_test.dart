import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/watch_plans/data/group_watch_plan_service.dart';
import 'package:flixie_app/features/watch_plans/presentation/controllers/group_watch_plan_controller.dart';
import 'package:flixie_app/features/watch_plans/presentation/group_watch_plan_selection.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../../patrol_test/support/group_watch_plan_fixture.dart';

GroupWatchRequest plan({String id = 'plan', bool invited = false}) =>
    GroupWatchRequest.fromJson(
        {...GroupWatchPlanFixture(invited: invited).plan, 'id': id});
const fixtureMembers = [
  GroupMember(
      groupId: 'group',
      memberId: GroupWatchPlanFixture.viewer,
      role: 'MEMBER',
      inviteStatus: 'ACCEPTED',
      profileBadges: ['EARLY_ADOPTER']),
  GroupMember(
      groupId: 'group',
      memberId: GroupWatchPlanFixture.robin,
      role: 'OWNER',
      inviteStatus: 'ACCEPTED'),
  GroupMember(
      groupId: 'group',
      memberId: 'pending',
      role: 'MEMBER',
      inviteStatus: 'PENDING'),
];

class Service extends GroupWatchPlanService {
  int planReads = 0, memberReads = 0, groupReads = 0;
  Future<List<GroupWatchRequest>> Function(int)? read;
  @override
  Future<List<Group>> groups(String userId) async {
    groupReads++;
    return const [
      Group(id: 'group', name: 'Four Film Friends', ownerId: 'owner')
    ];
  }

  @override
  Future<List<GroupWatchRequest>> plans(String groupId, String scope) {
    planReads++;
    return read?.call(planReads) ?? Future.value([plan()]);
  }

  @override
  Future<List<GroupMember>> members(String groupId) async {
    memberReads++;
    return membersFixture;
  }

  static const membersFixture = fixtureMembers;
  @override
  Future<void> cancelReminders(String id) async {}
}

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Service service;
  late GroupWatchPlanController controller;
  setUp(() {
    service = Service();
    controller = GroupWatchPlanController(service: service);
    controller.bind(userId: GroupWatchPlanFixture.viewer);
  });
  tearDown(() => controller.dispose());

  test(
      'same-turn refresh signals make one collection read; membership keeps badges',
      () async {
    await settle();
    expect(service.planReads, 1);
    controller.requestRefresh();
    controller.requestRefresh();
    controller.requestRefresh();
    await settle();
    expect(service.planReads, 2);
    expect(service.groupReads, 2);
    expect(service.memberReads, 2);
    expect(controller.view(controller.requests.single).members.length, 2);
    expect(
        controller.view(controller.requests.single).members.first.profileBadges,
        ['EARLY_ADOPTER']);
  });

  test('new refresh publishes before a stalled older result and stays newest',
      () async {
    await settle();
    final old = Completer<List<GroupWatchRequest>>();
    service.read =
        (n) => n == 2 ? old.future : Future.value([plan(id: 'latest')]);
    controller.requestRefresh();
    await settle();
    controller.requestRefresh();
    await settle();
    expect(controller.requests.single.id, 'latest');
    old.complete([plan(id: 'stale')]);
    await settle();
    expect(controller.requests.single.id, 'latest');
  });

  test('account switch clears private plans and drafts before old reads finish',
      () async {
    await settle();
    controller.toggleChoice(controller.requests.single, 'alien');
    final old = Completer<List<GroupWatchRequest>>();
    service.read =
        (n) => n == 2 ? old.future : Future.value([plan(id: 'new-account')]);
    controller.requestRefresh();
    await settle();
    controller.bind(userId: 'new-viewer');
    expect(controller.requests, isEmpty);
    await settle();
    old.complete([plan(id: 'private-old-account')]);
    await settle();
    expect(controller.requests.single.id, 'new-account');
    expect(controller.choices(controller.requests.single), isEmpty);
  });

  test('signed out clears loaded state without starting more API calls',
      () async {
    await settle();
    controller.bind(userId: '');
    await settle();
    expect(controller.requests, isEmpty);
    expect(controller.loading, false);
    expect(service.planReads, 1);
  });

  test(
      'duplicate action is rejected and notification burst has one post-write read',
      () async {
    await settle();
    final gate = Completer<void>();
    var writes = 0;
    final first = controller.run(() {
      writes++;
      return gate.future;
    });
    expect(
        await controller.run(() async {
          writes++;
        }),
        false);
    controller.requestRefresh();
    controller.requestRefresh();
    gate.complete();
    expect(await first, true);
    await settle();
    expect(writes, 1);
    expect(service.planReads, 2);
    expect(controller.processing, false);
  });

  test('saved action does not wait for or publish an older stalled read',
      () async {
    await settle();
    final old = Completer<List<GroupWatchRequest>>();
    service.read =
        (n) => n == 2 ? old.future : Future.value([plan(id: 'saved')]);
    controller.requestRefresh();
    await settle();
    expect(await controller.run(() async {}), true);
    expect(controller.requests.single.id, 'saved');
    old.complete([plan(id: 'pre-write')]);
    await settle();
    expect(controller.requests.single.id, 'saved');
  });

  test('old account write completion cannot refresh the next account',
      () async {
    await settle();
    final gate = Completer<void>();
    final pending = controller.run(() => gate.future);
    controller.bind(userId: 'another-viewer');
    await settle();
    final reads = service.planReads;
    gate.complete();
    expect(await pending, false);
    await settle();
    expect(service.planReads, reads);
    expect(controller.processing, false);
  });

  test('single-group failure retains useful data and retry clears error',
      () async {
    controller.bind(userId: GroupWatchPlanFixture.viewer, groupId: 'group');
    await settle();
    service.read = (_) => Future.error(Exception('offline'));
    await controller.load();
    expect(controller.requests, isNotEmpty);
    expect(controller.error, isNotNull);
    service.read = (_) => Future.value([plan(id: 'recovered')]);
    await controller.load();
    expect(controller.requests.single.id, 'recovered');
    expect(controller.error, isNull);
  });

  test('declined viewer has no active plan and always gets declined stage',
      () async {
    final data = GroupWatchPlanFixture()..decline(GroupWatchPlanFixture.viewer);
    service.read = (_) => Future.value([GroupWatchRequest.fromJson(data.plan)]);
    await settle();
    expect(controller.activeCount, 0);
    expect(controller.pastCount, 1);
    expect(controller.view(controller.requests.single).stage,
        GroupPlanStage.declined);
  });

  test('disposed controller ignores delayed reads and queued notifications',
      () async {
    final gate = Completer<List<GroupWatchRequest>>();
    service.read = (_) => gate.future;
    await settle();
    final disposed = controller;
    var publications = 0;
    disposed.addListener(() => publications++);
    disposed.dispose();
    controller = GroupWatchPlanController(service: service);
    gate.complete([plan()]);
    await settle();
    disposed.requestRefresh();
    await settle();
    expect(publications, 0);
    expect(disposed.requests, isEmpty);
  });
}
