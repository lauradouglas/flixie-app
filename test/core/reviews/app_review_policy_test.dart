import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/reviews/app_review_policy.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('requires 48 hours, two active days and three distinct actions',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final first = DateTime(2026, 10, 1, 12);
    final eligibleAt = first.add(const Duration(hours: 48));
    await AppReviewPolicy.record(prefs, 'casey', 'save:alien', first);
    await AppReviewPolicy.record(prefs, 'casey', 'save:odyssey', first);
    await AppReviewPolicy.record(prefs, 'casey', 'save:spider-man', first);
    // Enough actions and elapsed time, but only one active day.
    expect(AppReviewPolicy.eligible(prefs, 'casey', eligibleAt), isFalse);
    await AppReviewPolicy.record(prefs, 'casey', 'watch:alien',
        first.add(const Duration(days: 1)));
    expect(AppReviewPolicy.eligible(prefs, 'casey',
        eligibleAt.subtract(const Duration(seconds: 1))), isFalse);
    expect(AppReviewPolicy.eligible(prefs, 'casey', eligibleAt), isTrue);
    expect(AppReviewPolicy.eligible(prefs, 'other', eligibleAt), isFalse);
  });
  test('two actions across two days are insufficient until the third action',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final first = DateTime(2026, 10, 1, 12);
    final now = first.add(const Duration(hours: 48));
    await AppReviewPolicy.record(prefs, 'casey', 'save:alien', first);
    await AppReviewPolicy.record(prefs, 'casey', 'save:odyssey', now);
    expect(AppReviewPolicy.eligible(prefs, 'casey', now), isFalse);
    await AppReviewPolicy.record(prefs, 'casey', 'watch:alien', now);
    expect(AppReviewPolicy.eligible(prefs, 'casey', now), isTrue);
  });
  test(
      'repeated toggles do not count as three actions and cooldown spans accounts',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final first = DateTime(2026, 10, 1), now = DateTime(2026, 10, 10);
    for (var i = 0; i < 10; i++) {
      await AppReviewPolicy.record(
          prefs, 'casey', 'save:alien', first.add(Duration(days: i)));
    }
    expect(AppReviewPolicy.eligible(prefs, 'casey', now), isFalse);
    for (var i = 0; i < 4; i++) {
      await AppReviewPolicy.record(prefs, 'casey', 'watch:$i', now);
    }
    expect(AppReviewPolicy.eligible(prefs, 'casey', now), isTrue);
    await prefs.setInt(
        AppReviewPolicy.globalAttemptKey, now.millisecondsSinceEpoch);
    expect(
        AppReviewPolicy.eligible(
            prefs, 'casey', now.add(const Duration(days: 119))),
        isFalse);
    expect(
        AppReviewPolicy.eligible(
            prefs, 'casey', now.add(const Duration(days: 120))),
        isTrue);
    await prefs.setInt('app_review.last_prompt.casey',
        now.add(const Duration(days: 100)).millisecondsSinceEpoch);
    expect(
        AppReviewPolicy.eligible(
            prefs, 'casey', now.add(const Duration(days: 121))),
        isFalse);
  });
}
