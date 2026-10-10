import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/features/social/data/watch_requests_service.dart';
import 'package:flixie_app/features/social/presentation/controllers/watch_requests_controller.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_types.dart';
import '../../../../patrol_test/support/watch_plan_fixture.dart';
import '../../../../patrol_test/support/store_screenshot_fixture.dart';
import '../../../support/api_fixture.dart';

class PlansAuth extends StoreScreenshotAuth {
  String viewer = 'store-viewer';
  List<WatchRequest>? plans;
  @override
  User get dbUser => User.fromJson({
        ...screenshotPerson,
        'id': viewer,
        'email': '',
        'iconColorId': 0,
        'completedSetup': true,
        'darkMode': true
      });
  @override
  List<WatchRequest>? get cachedWatchRequests => plans;
  @override
  void updateCachedWatchRequests(List<WatchRequest> value) {
    plans = List.of(value);
  }

  void switchViewer(String id) {
    viewer = id;
    plans = null;
    notifyListeners();
  }
}

class PlanReads extends WatchRequestsService {
  final reads = <Completer<List<WatchRequest>>>[];
  final focusedReads = <Completer<WatchRequest>>[];
  Set<String> hidden = {};
  int groupLoads = 0;
  @override
  Future<List<WatchRequest>> load(String viewer) {
    final gate = Completer<List<WatchRequest>>();
    reads.add(gate);
    return gate.future;
  }

  @override
  Future<WatchRequest> focused(String viewer, String id, Object scope) {
    final gate = Completer<WatchRequest>();
    focusedReads.add(gate);
    return gate.future;
  }

  @override
  Future<Set<String>> closed(String viewer) async => hidden;
  @override
  Future<List<Group>> groups(String viewer) async {
    groupLoads++;
    return [];
  }
}

WatchRequest plan(String title,
        {String id = 'patrol-plan', String status = 'ACCEPTED'}) =>
    WatchRequest.fromJson({
      ...WatchPlanFixture(status: status).plan,
      'id': id,
      'movie': {'id': 348, 'title': title},
      'candidates': []
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('latest refresh wins and confirmed mutation invalidates an older list',
      () async {
    final auth = PlansAuth();
    final service = PlanReads();
    final controller = WatchRequestsController(auth: auth, service: service);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    final first = controller.load();
    final second = controller.load();
    service.reads[1].complete([plan('New')]);
    await second;
    service.reads[0].complete([plan('Old')]);
    await first;
    expect(controller.requests.single.movie!.title, 'New');
    final stale = controller.load();
    controller.replace(plan('Persisted'));
    service.reads.last.complete([plan('Before write')]);
    await stale;
    expect(controller.requests.single.movie!.title, 'Persisted');
    expect(auth.plans!.single.movie!.title, 'Persisted');
  });
  for (final disposed in [false, true]) {
    test(
        '${disposed ? 'disposal' : 'account switch'} rejects reads and cache writes',
        () async {
      final auth = PlansAuth();
      final service = PlanReads();
      final controller = WatchRequestsController(auth: auth, service: service);
      addTearDown(auth.dispose);
      if (!disposed) addTearDown(controller.dispose);
      final pending = controller.load();
      if (disposed) {
        controller.dispose();
      } else {
        auth.switchViewer('other');
      }
      service.reads.single.complete([plan('Old account')]);
      await pending;
      expect(auth.plans, isNull);
      expect(controller.requests, isEmpty);
    });
  }
  test('focused route reads one lifecycle state and no group overview',
      () async {
    final auth = PlansAuth()..plans = [plan('Stale cache')];
    final service = PlanReads();
    final controller = WatchRequestsController(
        auth: auth, service: service, focusedId: 'patrol-plan');
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    expect(controller.requests, isEmpty);
    expect(controller.loading, true);
    final pending = controller.start();
    service.focusedReads.single.complete(plan('Fresh state'));
    await pending;
    expect(controller.filtered.single.movie!.title, 'Fresh state');
    expect(service.reads, isEmpty);
    expect(service.groupLoads, 0);
  });
  test('focused fallback cannot overwrite a newer lifecycle state', () async {
    final auth = PlansAuth();
    final service = PlanReads();
    final controller = WatchRequestsController(
        auth: auth, service: service, focusedId: 'patrol-plan');
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    final first = controller.load();
    service.focusedReads[0].completeError(StateError('offline'));
    await Future<void>.delayed(Duration.zero);
    final second = controller.load();
    service.focusedReads[1].complete(plan('Newest'));
    await second;
    service.reads.single.complete([plan('Fallback')]);
    await first;
    expect(controller.filtered.single.movie!.title, 'Newest');
  });
  test(
      'refresh failure retains useful cached content and successful retry clears errors',
      () async {
    final auth = PlansAuth()..plans = [plan('Cached')];
    final service = PlanReads();
    final controller = WatchRequestsController(auth: auth, service: service);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    final pending = controller.load();
    service.reads.single.completeError(StateError('offline'));
    await pending;
    expect(controller.error, isNull);
    expect(controller.filtered.single.movie!.title, 'Cached');
    controller.remove('patrol-plan');
    final failed = controller.load();
    service.reads.last.completeError(StateError('offline'));
    await failed;
    expect(controller.error, 'Failed to load Watch Plans.');
    final retry = controller.load();
    service.reads.last.complete([plan('Recovered')]);
    await retry;
    expect(controller.error, isNull);
    expect(controller.filtered.single.movie!.title, 'Recovered');
  });
  test(
      'actions are single-flight, release busy state after failure and stop after account change',
      () async {
    final auth = PlansAuth();
    final controller = WatchRequestsController(auth: auth);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    final gate = Completer<void>();
    var writes = 0;
    Future<void> write() async {
      writes++;
      await gate.future;
    }

    final first =
        controller.runAction('plan', FriendWatchPlanAction.accepting, write);
    await controller.runAction('plan', FriendWatchPlanAction.accepting, write);
    expect(writes, 1);
    expect(controller.busy('plan'), true);
    gate.complete();
    await first;
    expect(controller.busy('plan'), false);
    await expectLater(
        controller.runAction('plan', FriendWatchPlanAction.accepting,
            () async => throw StateError('offline')),
        throwsStateError);
    expect(controller.busy('plan'), false);
    auth.switchViewer('other');
    await controller.runAction('plan', FriendWatchPlanAction.accepting, write);
    expect(writes, 1);
  });
  test('private closure is persisted for this viewer and changes visible plans',
      () async {
    final auth = PlansAuth()..plans = [plan('Alien')];
    final controller = WatchRequestsController(auth: auth);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    expect(controller.filtered, hasLength(1));
    await controller.close('patrol-plan');
    expect(controller.filtered, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('closed_watch_plan_ids_store-viewer'),
        ['patrol-plan']);
    expect(prefs.getStringList('closed_watch_plan_ids_other'), isNull);
  });
  test(
      'movie drafts survive refresh, are copies, and clear after confirmed save',
      () {
    final auth = PlansAuth();
    final controller = WatchRequestsController(auth: auth);
    addTearDown(controller.dispose);
    addTearDown(auth.dispose);
    final request =
        WatchRequest.fromJson(WatchPlanFixture(status: 'ACCEPTED').plan);
    expect(controller.draft(request, auth.viewer), {'alien'});
    controller.toggle(request, auth.viewer, 'alien');
    expect(controller.draft(request, auth.viewer), isEmpty);
    controller.draft(request, auth.viewer).add('external');
    expect(controller.draft(request, auth.viewer), isEmpty);
    controller.clearDraft(request.id);
    expect(controller.draft(request, auth.viewer), {'alien'});
    controller.setFilter(WatchPlanFilter.completed);
    expect(controller.filtered, isEmpty);
  });
  for (final invalidate in [false, true]) {
    test(
        'group count uses four workers${invalidate ? ' and stops stale scheduling' : ''}',
        () async {
      var active = 0;
      var peak = 0;
      var reads = 0;
      var current = true;
      final gate = Completer<void>();
      useApiFixture(MockClient((request) async {
        active++;
        reads++;
        if (active > peak) peak = active;
        await gate.future;
        active--;
        return http.Response('[{"id":"plan","status":"OPEN"}]', 200);
      }));
      const service = WatchRequestsService();
      final pending = service.activeCount(
          List.generate(
              12,
              (i) =>
                  Group(id: '$i', name: 'Group $i', ownerId: 'store-viewer')),
          current: () => current);
      await Future<void>.delayed(Duration.zero);
      expect(reads, 4);
      expect(peak, 4);
      if (invalidate) current = false;
      gate.complete();
      final count = await pending;
      expect(reads, invalidate ? 4 : 12);
      expect(count, invalidate ? 0 : 12);
    });
  }
}
