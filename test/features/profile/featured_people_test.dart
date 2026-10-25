import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/profile/presentation/controllers/featured_people_controller.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_favourite_people.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_header.dart';
import 'profile_controller_test.dart' show ProfileAuth;

class FeaturedAuth extends ProfileAuth {
  @override
  void updateDbUser(User user) {
    account = user;
    notifyListeners();
  }
}

const favouritePeopleFixture = [
  {'id': 525, 'name': 'Christopher Nolan'},
  {'id': 500, 'name': 'Tom Cruise'},
  {'id': 10205, 'name': 'Sigourney Weaver'},
  {'id': 139, 'name': 'Uma Thurman'},
];

Future<void> featuredPeopleJourney(WidgetTester tester) async {
  var highlights = <String, int>{};
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: SingleChildScrollView(
              child: StatefulBuilder(
                  builder: (context, update) => ProfileFavouritePeople(
                        people: favouritePeopleFixture,
                        featured: highlights,
                        onChoose: (role, person) async {
                          update(() {
                            if (person == null) {
                              highlights.remove(role);
                            } else {
                              highlights[role] = person;
                            }
                          });
                        },
                      ))))));
  await tester.tap(find.text('Choose your director'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Christopher Nolan'));
  await tester.pumpAndSettle();
  expect(highlights, isEmpty);
  await tester.tap(find.text('Save highlight'));
  await tester.pumpAndSettle();
  expect(highlights, {'director': 525});
  expect(find.text('Favourite director'), findsOneWidget);
  await tester.tap(find.text('All (4)'));
  await tester.pumpAndSettle();
  expect(find.text('Uma Thurman'), findsOneWidget);
  expect(find.text('Tom Cruise'), findsOneWidget);
  await tester.tap(find.byTooltip('Close'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Edit favourite director'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('Clear this highlight'), 200,
      scrollable: find
          .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable))
          .first);
  await tester.tap(find.text('Clear this highlight'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save highlight'));
  await tester.pumpAndSettle();
  expect(highlights, isEmpty);
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets(
      'choose clear and view every favourite person', featuredPeopleJourney);
  testWidgets('header keeps badge icons and visibly exposes avatar editing',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: ProfileHeader(
                displayName: 'Casey',
                username: 'casey',
                profileBadges: ['FOUNDER', 'EARLY_ADOPTER']))));
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);
    expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
    expect(
        find.bySemanticsLabel(RegExp('Change profile avatar')), findsOneWidget);
    expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
    semantics.dispose();
  });
  test('saved choices survive JSON round trip without losing badges or library',
      () async {
    final auth = FeaturedAuth();
    auth.account = auth.account!.copyWith(
        profileBadges: ['FOUNDER'], favoritePeople: favouritePeopleFixture);
    final controller = FeaturedPeopleController(
        auth: auth,
        save: (id, field, value) async {
          expect(field, 'featuredPeople');
          return User.fromJson({'id': id, 'featuredPeople': value});
        });
    await controller.choose('director', 525);
    final reopened = User.fromJson(auth.dbUser!.toJson());
    expect(reopened.featuredPeople, {'director': 525});
    expect(reopened.profileBadges, ['FOUNDER']);
    expect(reopened.favoritePeople, hasLength(4));
    await controller.choose('director', null);
    expect(auth.dbUser!.featuredPeople, isEmpty);
    controller.dispose();
    auth.dispose();
  });
  test(
      'failed save retains choices and a late response cannot change another account',
      () async {
    final auth = FeaturedAuth();
    final pending = Completer<User>();
    final controller = FeaturedPeopleController(
        auth: auth, save: (_, __, ___) => pending.future);
    final task = controller.choose('actor', 500);
    auth.select('another-viewer');
    pending.complete(User.fromJson({
      'featuredPeople': {'actor': 500}
    }));
    await task;
    expect(auth.dbUser!.featuredPeople, isEmpty);
    controller.dispose();
    final failing = FeaturedPeopleController(
        auth: auth, save: (_, __, ___) async => throw Exception('offline'));
    await expectLater(failing.choose('actor', 500), throwsException);
    expect(failing.saving, false);
    expect(auth.dbUser!.featuredPeople, isEmpty);
    failing.dispose();
    auth.dispose();
  });
}
