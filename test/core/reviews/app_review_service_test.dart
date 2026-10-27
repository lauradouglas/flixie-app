import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/reviews/app_review_policy.dart';
import 'package:flixie_app/core/reviews/app_review_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dev.britannio.in_app_review');
  var calls = <String>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'isAvailable' ? true : null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
  Future<void> seed(String user) async {
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < 5; i++) {
      await AppReviewPolicy.record(prefs, user, 'saved:$i',
          DateTime.now().subtract(Duration(days: 10 - i)));
    }
  }

  test(
      'cold launch, guest and setup actions never request; recording only queues',
      () async {
    await seed('casey');
    await AppReviewService.requestIfEligible('casey', canPrompt: () => true);
    expect(calls, isEmpty);
    await AppReviewService.recordMovieInteraction('',
        hasCompletedSetup: true, eventId: 'movie:1');
    await AppReviewService.recordMovieInteraction('casey',
        hasCompletedSetup: false, eventId: 'movie:1');
    await AppReviewService.requestIfEligible('casey', canPrompt: () => true);
    expect(calls, isEmpty);
    await AppReviewService.recordMovieInteraction('casey',
        hasCompletedSetup: true, eventId: 'movie:2');
    expect(calls, isEmpty);
    await AppReviewService.requestIfEligible('casey', canPrompt: () => false);
    expect(calls, isEmpty);
    await AppReviewService.requestIfEligible('casey', canPrompt: () => true);
    expect(calls, ['isAvailable', 'requestReview']);
    await AppReviewService.requestIfEligible('casey', canPrompt: () => true);
    expect(calls.where((e) => e == 'requestReview'), hasLength(1));
  });
  test(
      'navigation/account changes while availability resolves cancel the request',
      () async {
    await seed('different-casey');
    await AppReviewService.recordMovieInteraction('different-casey',
        hasCompletedSetup: true, eventId: 'movie:3');
    final availability = Completer<bool>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return call.method == 'isAvailable' ? availability.future : null;
    });
    var safe = true;
    final request = AppReviewService.requestIfEligible('different-casey',
        canPrompt: () => safe);
    await Future<void>.delayed(Duration.zero);
    safe = false;
    availability.complete(true);
    await request;
    expect(calls, ['isAvailable']);
  });
}
