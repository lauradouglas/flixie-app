import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/person_detail/person_credit_card.dart';
import 'package:flixie_app/features/movies/presentation/widgets/person_detail/person_filmography.dart';
import 'package:flixie_app/features/movies/presentation/widgets/person_detail/person_photos.dart';
import '../../../patrol_test/support/person_detail_fixture.dart';
import '../../support/api_fixture.dart';

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
  testWidgets(
      'Retry restores content; favourite success/removal/failure updates only after save',
      (tester) async {
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
  testWidgets(
      'account switch during save cannot change new user favourite list',
      (tester) async {
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
  testWidgets('search, TV, advanced year and All years work without refetching',
      (tester) async {
    final f = PersonDetailFixture()..photos = false;
    useApiFixture(f.client);
    final auth = PersonFixtureAuth();
    final router = personFixtureRouter();
    await tester.pumpWidget(personFixtureApp(auth, router));
    await tester.pumpAndSettle();
    await reveal(tester, find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Alien');
    await tester.pumpAndSettle();
    await reveal(tester, find.text('TV').first);
    await tester.tap(find.text('TV').first);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(PersonFilmographySection),
            matching: find.text('Alien: Earth')),
        findsOneWidget);
    await tester.tap(find.text('All').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await reveal(tester, find.text('All years'));
    await tester.tap(find.text('All years'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2027').last);
    await tester.pumpAndSettle();
    expect(find.byType(PersonCreditRow), findsOneWidget);
    await tester.tap(find.text('2027').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('All years').last);
    await tester.pumpAndSettle();
    expect(find.byType(PersonCreditRow), findsNWidgets(12));
    expect(f.calls.where((v) => v.startsWith('GET')).length, 3);
    expect(f.unexpected, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    router.dispose();
  });
  testWidgets(
      'full credits closes before navigating, preserves person on Back, guards account changes',
      (tester) async {
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
  testWidgets('photo grid/viewer opens selected index, swipes and closes',
      (tester) async {
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
  for (final (size, scale) in [
    (const Size(320, 640), 2.0),
    (const Size(430, 932), 1.0),
    (const Size(900, 1024), 2.0),
    (const Size(700, 320), 2.0)
  ]) {
    testWidgets('detail and controls reflow at $size text $scale',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final f = PersonDetailFixture()..photos = false;
      useApiFixture(f.client);
      final auth = PersonFixtureAuth();
      final router = personFixtureRouter();
      await tester.pumpWidget(
          personFixtureApp(auth, router, textScaler: TextScaler.linear(scale)));
      await tester.pumpAndSettle();
      // Framework reports any layout exceptions at test completion.
      await reveal(tester, find.byType(TextField));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Alien');
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Filters'));
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      // Framework reports any layout exceptions at test completion.
      expect(f.unexpected, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
      router.dispose();
    });
  }
}
