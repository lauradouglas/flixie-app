import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/widgets/discussion/community_poll_deadline.dart';

void main() {
  final now = DateTime.utc(2026, 10, 11, 20);
  test('deadlines have accurate minute countdowns and close at the boundary',
      () {
    final poll = {
      'closesAt': now.add(const Duration(minutes: 20)).toIso8601String()
    };
    expect(pollDeadlineLabel(poll, now: now), 'Closing in 20 mins');
    expect(pollVotingClosed(poll, now: now), false);
    expect(pollVotingClosed(poll, now: now.add(const Duration(minutes: 20))),
        true);
    expect(pollDeadlineLabel(poll, now: now.add(const Duration(minutes: 20))),
        'Voting closed');
    expect(pollDeadlineLabel({}, now: now), 'No deadline');
    expect(pollDeadlineLabel({'closedAt': now.toIso8601String()}, now: now),
        'Voting closed');
    expect(
        pollDeadlineLabel({
          'closesAt': now.add(const Duration(seconds: 20)).toIso8601String()
        }, now: now),
        'Closing in 1 min');
  });
  testWidgets('countdown refreshes while a poll remains on screen', (t) async {
    var current = now;
    final closing = current.add(const Duration(minutes: 20));
    await t.pumpWidget(MaterialApp(
        home: CommunityPollDeadline(
            poll: {'closesAt': closing.toIso8601String()},
            now: () => current)));
    expect(find.text('Closing in 20 mins'), findsOneWidget);
    current = current.add(const Duration(minutes: 1));
    await t.pump(const Duration(minutes: 1));
    expect(find.text('Closing in 19 mins'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });
}
