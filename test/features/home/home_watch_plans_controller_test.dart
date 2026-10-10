import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/home/presentation/controllers/home_watch_plans_controller.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'home_controller_test.dart' show viewer, flush;

WatchRequest direct(String id) => WatchRequest.fromJson({
      'id': id,
      'type': 'MOVIE_WATCH_REQUEST',
      'requesterId': 'fictional-friend',
      'recipientId': 'first',
      'status': 'PENDING',
      'candidates': [],
      'watchConfirmations': [],
      'scheduleProposals': [],
    });
HomeGroupWatchPlan groupPlan(String id) => HomeGroupWatchPlan(
      const Group(
          id: 'fictional-group',
          name: 'Film friends',
          ownerId: 'fictional-friend'),
      GroupWatchRequest(
          id: id, groupId: 'fictional-group', userId: 'fictional-friend'),
    );

class PlanCache extends WatchRequestCache {
  String? selected;
  Future<List<WatchRequest>> Function()? directRequest;
  Future<List<HomeGroupWatchPlan>> Function()? groupRequest;
  @override
  void syncUser(String? userId, {bool deferWarm = false}) {
    selected = userId;
  }

  @override
  Future<List<WatchRequest>> refreshDirect({bool force = true}) =>
      directRequest?.call() ?? Future.value([]);
  @override
  Future<List<HomeGroupWatchPlan>> refreshHome({bool force = true}) =>
      groupRequest?.call() ?? Future.value([]);
}

void main() {
  late PlanCache cache;
  late HomeWatchPlansController plans;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cache = PlanCache();
    plans = HomeWatchPlansController(cache);
  });
  tearDown(() {
    plans.dispose();
    cache.dispose();
  });

  test('direct cards appear independently while group plans are still pending',
      () async {
    final groups = Completer<List<HomeGroupWatchPlan>>();
    cache.directRequest = () async => [direct('invite')];
    cache.groupRequest = () => groups.future;
    final loading = plans.load(viewer('first'));
    await flush();
    await flush();
    expect(plans.plans.map((plan) => plan.id), ['invite']);
    expect(plans.requestsNeedingResponse, 1);
    expect(plans.loading, true);
    groups.complete([groupPlan('group-plan')]);
    await loading;
    expect(
        plans.plans.map((plan) => plan.id).toSet(), {'invite', 'group-plan'});
    expect(plans.loading, false);
    expect(plans.failed, false);
  });

  test('ordinary failure keeps cards; access denial removes only its source',
      () async {
    cache.directRequest = () async => [direct('invite')];
    cache.groupRequest = () async => [groupPlan('group-plan')];
    await plans.load(viewer('first'));
    cache.directRequest = () => Future.error(StateError('offline'));
    await plans.load(viewer('first'));
    expect(
        plans.plans.map((plan) => plan.id).toSet(), {'invite', 'group-plan'});
    expect(plans.failed, true);
    cache.directRequest = () => Future.error(const ApiException(
        statusCode: 403, code: 'FORBIDDEN', message: 'Denied'));
    await plans.load(viewer('first'));
    expect(plans.plans.map((plan) => plan.id), ['group-plan']);
    expect(plans.requestsNeedingResponse, 0);
  });

  test(
      'late results cannot restore plans or introduction state from another account',
      () async {
    final directGate = Completer<List<WatchRequest>>();
    final groupGate = Completer<List<HomeGroupWatchPlan>>();
    cache.directRequest = () => directGate.future;
    cache.groupRequest = () => groupGate.future;
    final old = plans.load(viewer('first'));
    plans.markUsed('first');
    plans.selectUser('second');
    expect(plans.hasUsedPlans, false);
    expect(plans.introductionDismissed, false);
    directGate.complete([direct('invite')]);
    groupGate.complete([groupPlan('group-plan')]);
    await old;
    expect(plans.plans, isEmpty);
    expect(plans.requestsNeedingResponse, 0);
    plans.markUsed('first');
    expect(plans.hasUsedPlans, false);
  });

  test('newer refresh wins when previous direct results arrive late', () async {
    final oldDirect = Completer<List<WatchRequest>>();
    cache.directRequest = () => oldDirect.future;
    final old = plans.load(viewer('first'));
    await flush();
    cache.directRequest = () async => [direct('new-invite')];
    await plans.load(viewer('first'));
    oldDirect.complete([direct('old-invite')]);
    await old;
    expect(plans.plans.map((plan) => plan.id), ['new-invite']);
    expect(plans.loading, false);
  });

  test('disposal rejects pending completion without notifying', () async {
    final pending = Completer<List<WatchRequest>>();
    cache.directRequest = () => pending.future;
    final load = plans.load(viewer('first'));
    var changes = 0;
    plans.addListener(() => changes++);
    plans.dispose();
    pending.complete([direct('late')]);
    await load;
    expect(changes, 0);
    // Dispose is usually called once by Home; avoid a second ChangeNotifier dispose.
    plans = HomeWatchPlansController(cache);
  });
}
