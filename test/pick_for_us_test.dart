import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/pick_for_us/pick_for_us_screen.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/movie_short.dart';

class FakePickService extends PickForUsService {
  String? venue, friendId, watching;
  bool? openToRent, allowRewatches;
  String? request;
  int? minutes;
  bool fail = false;
  @override
  Future<FriendsData> friends(String id) async =>
      const FriendsData(friendships: [
        Friendship(
            id: 'edge',
            friend:
                FriendshipUser(id: 'friend', username: 'Alex', initials: 'A'),
            createdAt: '',
            updatedAt: '')
      ], pendingFriends: [], requestedFriends: []);
  @override
  Future<List<Group>> groups(String id) async => [];
  @override
  Future<PickForUsResponse> pick(
      {String? friendId,
      String? groupId,
      String request = '',
      bool allowRewatches = false,
      Set<String> avoid = const {},
      List<int> genreIds = const [],
      bool includePossible = true,
      bool includeUnknownContent = false,
      required int maxMinutes,
      required String mood,
      required String venue,
      required String watching,
      required bool openToRent}) async {
    this.request = request;
    this.allowRewatches = allowRewatches;
    this.watching = watching;
    this.openToRent = openToRent;
    this.venue = venue;
    this.friendId = friendId;
    minutes = maxMinutes;
    if (fail) throw Exception('offline');
    return const PickForUsResponse([
      PickForUsResult(
          MovieShort(
              id: 1,
              name: 'A movie for the whole group',
              overview:
                  'A surprising adventure brings old friends together for one unforgettable evening.',
              recommendationReasons: [
                'On both your watchlists',
                '110 minutes — fits your time',
                'In cinemas in GB — check your local cinema for showtimes'
              ]),
          110),
    ], 'Fewer than three current cinema releases fit. Try more time or another mood.');
  }
}

Future<void> scroll(WidgetTester tester, Finder finder, double delta) =>
    tester.scrollUntilVisible(finder, delta,
        scrollable: find.byType(Scrollable).first);

void main() {
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  Future<void> show(WidgetTester tester, FakePickService service, Size size,
      double scale) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: PickForUsScreen(userId: 'me', service: service)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'cinema and viewer selection reach service; results can be revised',
      (tester) async {
    final service = FakePickService();
    await show(tester, service, const Size(390, 844), 1);
    await scroll(tester, find.text('Alex'), 250);
    await tester.ensureVisible(
        find.ancestor(of: find.text('Alex'), matching: find.byType(ListTile)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex'));
    await scroll(tester, find.text('Cinema'), 150);
    await tester.tap(find.text('Cinema'));
    await tester.pumpAndSettle();
    if (const bool.fromEnvironment('PICK_VISUAL_REVIEW')) {
      await expectLater(find.byType(Scaffold).first,
          matchesGoldenFile('../.impeccable/review/pick-controls.png'));
    }
    await scroll(tester, find.text('Find our picks'), 250);
    await tester.ensureVisible(find.ancestor(
        of: find.text('Find our picks'),
        matching: find.byWidgetPredicate((w) => w is FilledButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find our picks'));
    await tester.pumpAndSettle();
    expect(service.venue, 'cinema');
    expect(service.friendId, 'friend');
    expect(service.minutes, 120);
    expect(find.text('A movie for the whole group'), findsOneWidget);
    if (const bool.fromEnvironment('PICK_VISUAL_REVIEW')) {
      await expectLater(find.byType(Scaffold).first,
          matchesGoldenFile('../.impeccable/review/pick-phone.png'));
    }
    expect(find.text('Make a Watch Plan'), findsOneWidget);
    await scroll(tester, find.text('Change viewers, time or mood'), 250);
    await tester.tap(find.text('Change viewers, time or mood'));
    await tester.pumpAndSettle();
    expect(find.text('Who’s watching?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('rental opt-in is sent only for watching together',
      (tester) async {
    final service = FakePickService();
    await show(tester, service, const Size(1024, 1366), 1);
    await tester.tap(find.text('Alex'));
    await tester.tap(find.text('Open to renting'));
    await tester.pumpAndSettle();
    await scroll(tester, find.text('Find our picks'), 200);
    await tester.tap(find.text('Find our picks'));
    await tester.pumpAndSettle();
    expect(service.openToRent, isTrue);
    expect(service.watching, 'together');
    await scroll(tester, find.text('Change viewers, time or mood'), 200);
    await tester.tap(find.text('Change viewers, time or mood'));
    await tester.pumpAndSettle();
    await scroll(tester, find.text('Separately'), -200);
    await tester.tap(find.text('Separately'));
    await tester.pumpAndSettle();
    expect(find.text('Open to renting'), findsNothing);
    await scroll(tester, find.text('Find our picks'), 200);
    await tester.tap(find.text('Find our picks'));
    await tester.pumpAndSettle();
    expect(service.openToRent, isFalse);
    expect(service.watching, 'separately');
  });
  testWidgets('solo sends mood and rewatch preference without a friend',
      (tester) async {
    final service = FakePickService();
    await show(tester, service, const Size(390, 844), 1);
    expect(find.text('Just me'), findsOneWidget);
    expect(find.text('Together or separately?'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await scroll(tester, find.text('Rom com'), 200);
    await tester.tap(find.text('Rom com'));
    await scroll(tester, find.text('Include rewatches'), 200);
    await tester.tap(find.text('Include rewatches'));
    await scroll(tester, find.text('Find my picks'), 200);
    await tester.ensureVisible(find.text('Find my picks'));
    await tester.tap(find.text('Find my picks'));
    await tester.pumpAndSettle();
    expect(service.friendId, isNull);
    expect(service.request, '');
    expect(service.allowRewatches, isTrue);
    expect(service.watching, 'together');
    expect(find.text('View movie'), findsOneWidget);
    expect(find.text('Make a Watch Plan'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 640),
    const Size(430, 932),
    const Size(844, 390),
    const Size(1024, 1366)
  ]) {
    testWidgets('picker reflows at $size with large text', (tester) async {
      final service = FakePickService();
      await show(tester, service, size, 1.8);
      if (const bool.fromEnvironment('PICK_VISUAL_REVIEW')) {
        await expectLater(
            find.byType(Scaffold).first,
            matchesGoldenFile(
                '../.impeccable/review/pick-${size.width.toInt()}.png'));
      }
      await scroll(tester, find.text('Alex'), 150);
      await tester.ensureVisible(find.ancestor(
          of: find.text('Alex'), matching: find.byType(ListTile)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alex'));
      await scroll(tester, find.text('Find our picks'), 200);
      await tester.ensureVisible(find.ancestor(
          of: find.text('Find our picks'),
          matching: find.byWidgetPredicate((w) => w is FilledButton)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Find our picks'));
      await tester.pumpAndSettle();
      await scroll(tester, find.text('Make a Watch Plan'), 200);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('failed lookup preserves selections and supports retry',
      (tester) async {
    final service = FakePickService()..fail = true;
    await show(tester, service, const Size(390, 844), 1);
    await tester.ensureVisible(
        find.ancestor(of: find.text('Alex'), matching: find.byType(ListTile)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alex'));
    await scroll(tester, find.text('Find our picks'), 250);
    await tester.ensureVisible(find.ancestor(
        of: find.text('Find our picks'),
        matching: find.byWidgetPredicate((w) => w is FilledButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find our picks'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'We couldn’t find your picks. Check your connection and try again.'),
        findsOneWidget);
    service.fail = false;
    await tester.ensureVisible(find.ancestor(
        of: find.text('Find our picks'),
        matching: find.byWidgetPredicate((w) => w is FilledButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Find our picks'));
    await tester.pumpAndSettle();
    expect(find.text('Your shortlist, sorted.'), findsOneWidget);
  });
}
