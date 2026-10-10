import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/pick_for_us/controllers/pick_people_controller.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import '../../pick_for_us_test.dart' show FakePickService;

class PendingService extends FakePickService {
  final pending = Completer<FriendsData>();
  int friendReads = 0, groupReads = 0;
  bool failGroups = true;
  @override
  Future<FriendsData> friends(String id) {
    friendReads++;
    return pending.future;
  }

  @override
  Future<List<Group>> groups(String id) async {
    groupReads++;
    if (failGroups) throw StateError('offline');
    return [];
  }
}

void main() {
  test(
      'solo skips reads; pending and successful reads are reused; retry is independent',
      () async {
    final service = PendingService();
    final controller =
        PickPeopleController(userId: 'fixture', service: service);
    addTearDown(controller.dispose);
    await controller.load('solo');
    expect(service.friendReads + service.groupReads, 0);
    final pending = controller.load('friend');
    await controller.load('friend');
    expect(service.friendReads, 1);
    await controller.load('group');
    expect(controller.error('group'), isNotNull);
    service.pending.complete(await FakePickService().friends('fixture'));
    await pending;
    expect(controller.friends, hasLength(1));
    service.failGroups = false;
    await controller.load('group');
    await controller.load('friend');
    await controller.load('group');
    expect(service.friendReads, 1);
    expect(service.groupReads, 2);
    expect(controller.error('group'), isNull);
    expect(() => controller.friends.clear(), throwsUnsupportedError);
  });
  test('a late response cannot notify or populate a disposed flow', () async {
    final service = PendingService();
    final controller =
        PickPeopleController(userId: 'fixture', service: service);
    var notifications = 0;
    controller.addListener(() => notifications++);
    final pending = controller.load('friend');
    controller.dispose();
    service.pending.complete(await FakePickService().friends('fixture'));
    await pending;
    expect(notifications, 1);
    expect(controller.friends, isEmpty);
    await controller.load('group');
    expect(service.groupReads, 0);
  });
}
