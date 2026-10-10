// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/person_detail/person_credit_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/person_detail/person_filmography.dart';
import 'package:flixie_app/features/movies/presentation/widgets/person_detail/person_photos.dart';
import 'support/person_detail_fixture.dart';
import '../test/support/api_fixture.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(target, 180,
      scrollable: find
          .descendant(
              of: find.byType(CustomScrollView).first,
              matching: find.byType(Scrollable))
          .first);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.35);
  await tester.pumpAndSettle();
}

void main() {
  patrolTest(
      'Retry restores content; favourite add, remove and failure updates only after save',
      ($) async {
    SharedPreferences.setMockInitialValues({});
    final tester = $.tester;
    final f = PersonDetailFixture()
      ..photos = false
      ..failDetail = true;
    useApiFixture(f.client);
    final auth = PersonFixtureAuth();
    final router = personFixtureRouter();
    await tester.pumpWidget(personFixtureApp(auth, router));
    await tester.pumpAndSettle();
    expect(find.text('Failed to load person'), findsOneWidget);
    f.failDetail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Casey Fixture 42'), findsOneWidget);
    await tester.tap(find.byTooltip('Add favourite'));
    await tester.pumpAndSettle();
    expect(auth.dbUser.isPersonFavorite(42), isTrue);
    await tester.tap(find.byTooltip('Remove favourite'));
    await tester.pumpAndSettle();
    expect(auth.dbUser.isPersonFavorite(42), isFalse);
    f.failFavorite = true;
    await tester.tap(find.byTooltip('Add favourite'));
    await tester.pumpAndSettle();
    expect(auth.dbUser.isPersonFavorite(42), isFalse);
    expect(find.text('Could not update favourite person.'), findsOneWidget);
    expect(f.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    router.dispose();
  });
  patrolTest('account switch during save cannot change new user favourite list',
      ($) async {
    SharedPreferences.setMockInitialValues({});
    final tester = $.tester;
    final gate = Completer<void>();
    final f = PersonDetailFixture()
      ..photos = false
      ..writeGate = gate.future;
    useApiFixture(f.client);
    final auth = PersonFixtureAuth();
    final router = personFixtureRouter();
    await tester.pumpWidget(personFixtureApp(auth, router));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add favourite'));
    await tester.pump();
    auth.switchViewer('person-other');
    gate.complete();
    await tester.pumpAndSettle();
    expect(auth.dbUser.id, 'person-other');
    expect(auth.dbUser.isPersonFavorite(42), isFalse);
    expect(find.text('Added to favourite people'), findsNothing);
    expect(find.byTooltip('Add favourite'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    router.dispose();
  });
  patrolTest(
      'full credits closes before navigating, preserves person on Back, guards account changes',
      ($) async {
    SharedPreferences.setMockInitialValues({});
    final tester = $.tester;
    final f = PersonDetailFixture()..photos = false;
    useApiFixture(f.client);
    final auth = PersonFixtureAuth();
    final router = personFixtureRouter();
    await tester.pumpWidget(personFixtureApp(auth, router));
    await tester.pumpAndSettle();
    Future<void> open() async {
      await reveal(tester, find.text('View All 25 Credits'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View All 25 Credits'));
      await tester.pumpAndSettle();
    }

    await open();
    final credit = find.descendant(
        of: find.byType(PersonCreditsSheet), matching: find.text('Alien'));
    await tester.tap(credit);
    await tester.pumpAndSettle();
    expect(find.text('movies 1 person_credits'), findsOneWidget);
    expect(find.text('All Credits'), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    await open();
    final tvCredit = find.descendant(
        of: find.byType(PersonCreditsSheet),
        matching: find.text('Alien: Earth'));
    await tester.scrollUntilVisible(tvCredit, 180,
        scrollable: find
            .descendant(
                of: find.byType(PersonCreditsSheet),
                matching: find.byType(Scrollable))
            .first);
    await tester.tap(tvCredit);
    await tester.pumpAndSettle();
    expect(find.text('shows 1 person_credits'), findsOneWidget);
    expect(find.text('All Credits'), findsNothing);
    router.pop();
    await tester.pumpAndSettle();
    await open();
    auth.switchViewer('person-other');
    await tester.pumpAndSettle();
    expect(find.text('Account changed'), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(PersonCreditsSheet),
            matching: find.byType(PersonCreditRow)),
        findsNothing);
    await tester.tap(find.text('Close credits'));
    await tester.pumpAndSettle();
    expect(find.byType(PersonFilmographySection), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    router.dispose();
  });
  patrolTest('photo grid and viewer opens selected index, swipes and closes',
      ($) async {
    SharedPreferences.setMockInitialValues({});
    final tester = $.tester;
    final f = PersonDetailFixture();
    useApiFixture(f.client);
    final auth = PersonFixtureAuth();
    final router = personFixtureRouter();
    await tester.pumpWidget(personFixtureApp(auth, router));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(find.text('See all (3)'), 180,
        scrollable: find
            .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable))
            .first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('See all (3)'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byWidgetPredicate(
        (w) => w is Semantics && w.properties.label == 'Open photo 2 of 3'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsWidgets);
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('3 / 3'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded).hitTestable().first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(PersonPhotoGridScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    router.dispose();
  });
}
