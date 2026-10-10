import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/pick_for_us/pick_for_us_screen.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import '../../pick_for_us_test.dart' show FakePickService, scroll;

class CountingPickService extends FakePickService {
  int friendReads = 0, groupReads = 0;
  @override
  Future<FriendsData> friends(String id) {
    friendReads++;
    return super.friends(id);
  }

  @override
  Future<List<Group>> groups(String id) async {
    groupReads++;
    return const [
      Group(id: 'fixture-group', name: 'Alien fans', ownerId: 'fixture')
    ];
  }
}

Future<void> viewerJourney(WidgetTester tester) async {
  const before = bool.fromEnvironment('PICK_BEFORE');
  final service = CountingPickService();
  await tester.pumpWidget(
      MaterialApp(home: PickForUsScreen(userId: 'fixture', service: service)));
  await tester.pumpAndSettle();
  expect(service.friendReads, before ? 1 : 0);
  expect(service.groupReads, before ? 1 : 0);
  await tester.tap(find.text('Next · Your evening'));
  await tester.pumpAndSettle();
  await scroll(tester, find.text('With a friend'), 150);
  await tester.tap(find.text('With a friend'));
  await tester.pumpAndSettle();
  expect(service.friendReads, 1);
  expect(service.groupReads, before ? 1 : 0);
  await scroll(tester, find.text('With a group'), -150);
  await tester.tap(find.text('With a group'));
  await tester.pumpAndSettle();
  expect(service.friendReads, 1);
  expect(service.groupReads, 1);
  await scroll(tester, find.text('With a friend'), -150);
  await tester.tap(find.text('With a friend'));
  await tester.pumpAndSettle();
  expect(service.friendReads, 1);
  expect(service.groupReads, 1);
}

void main() {
  testWidgets('solo does not load viewers; selecting each type loads it once',
      viewerJourney);
}
