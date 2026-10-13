import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/profile_milestone.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_controller.dart';
import 'profile_controller_test.dart' show ProfileAuth, ProfileData;

class MilestoneData extends ProfileData {
  final pending = Completer<ProfileMilestones>();
  bool fail = false;
  @override
  Future<ProfileMilestones> milestones(String userId, {bool refresh = false}) {
    if (fail) return Future.error(StateError('offline'));
    return pending.future;
  }
}

void main() {
  test('milestone failure leaves other stats usable; retry loads earned data',
      () async {
    final auth = ProfileAuth();
    final service = MilestoneData()..fail = true;
    final controller = ProfileController(auth: auth, service: service);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    await controller.loadStats();
    expect(controller.wrapped, isNotNull);
    expect(controller.statsFailed, isFalse);
    expect(controller.milestonesFailed, isTrue);
    service.fail = false;
    service.pending.complete(const ProfileMilestones(items: [], owner: true));
    await controller.loadMilestones(forceRefresh: true);
    expect(controller.milestones, isNotNull);
    expect(controller.milestonesFailed, isFalse);
  });
  test(
      'account change clears milestones and rejects the previous account response',
      () async {
    final auth = ProfileAuth();
    final service = MilestoneData();
    final controller = ProfileController(auth: auth, service: service);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    final load = controller.loadMilestones();
    auth.select('other');
    service.pending.complete(const ProfileMilestones(items: [], owner: true));
    await load;
    expect(controller.milestones, isNull);
  });
  test('disposed controller rejects late milestone results', () async {
    final auth = ProfileAuth();
    addTearDown(auth.dispose);
    final service = MilestoneData();
    final controller = ProfileController(auth: auth, service: service);
    final load = controller.loadMilestones();
    controller.dispose();
    service.pending.complete(const ProfileMilestones(items: [], owner: true));
    await load;
    expect(controller.milestones, isNull);
  });
}
