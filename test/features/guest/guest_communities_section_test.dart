import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_communities_section.dart';

const communities = <GuestCommunity>[
  (id: 28, name: 'Action'),
  (id: 35, name: 'Comedy'),
  (id: 27, name: 'Horror'),
  (id: 878, name: 'Science Fiction'),
  (id: 10749, name: 'Romance'),
  (id: 16, name: 'Animation'),
  (id: 53, name: 'Thriller'),
  (id: -1, name: 'Anime'),
  (id: 10402, name: 'Music'),
  (id: 10770, name: 'TV Movie'),
];
void main() {
  for (final (width, scale) in [
    (320.0, 2.0),
    (430.0, 1.0),
    (844.0, 2.0),
    (834.0, 1.0)
  ]) {
    testWidgets('preview grid reflows without losing genres at $width/$scale',
        (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      GuestCommunity? selected;
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: GuestCommunitiesSection(
                              communities: communities,
                              onSelect: (c) => selected = c)))))));
      await t.pumpAndSettle();
      expect(find.text('Music'), findsNothing);
      expect(find.text('TV Movie'), findsNothing);
      expect(find.text('Browse all 9 communities'), findsOneWidget);
      expect(find.text('Science Fiction'), findsOneWidget);
      await t.tap(find.text('Action'));
      await t.pump();
      expect(selected, (id: 28, name: 'Action'));
      if (width == 430) {
        final action =
            t.getRect(find.byKey(const ValueKey('guest-community-28')));
        final comedy =
            t.getRect(find.byKey(const ValueKey('guest-community-35')));
        expect(action.width, comedy.width);
        expect(action.top, comedy.top);
        expect(action.height, greaterThanOrEqualTo(52));
      }
      expect(t.takeException(), isNull);
    });
  }
  testWidgets(
      'browse all includes remaining genres and returns the selected identity',
      (t) async {
    GuestCommunity? selected;
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: SingleChildScrollView(
                child: GuestCommunitiesSection(
                    communities: communities,
                    onSelect: (c) => selected = c)))));
    await t.tap(find.text('See all'));
    await t.pumpAndSettle();
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('Big stunts. Racing hearts. Films worth the adrenaline.'),
        findsOneWidget);
    expect(
        find.text('Big performances. Unforgettable soundtracks. Turn it up.'),
        findsOneWidget);
    expect(find.text('TV Movie'), findsNothing);
    await t.ensureVisible(find.text('Music'));
    await t.pumpAndSettle();
    await t.tap(find.text('Music'));
    await t.pumpAndSettle();
    expect(selected, (id: 10402, name: 'Music'));
    expect(find.byType(BottomSheet), findsNothing);
  });
  testWidgets('loading, empty and retry are distinct states', (t) async {
    var retries = 0;
    Future<void> show({bool loading = false, bool failed = false}) =>
        t.pumpWidget(MaterialApp(
            home: Scaffold(
                body: GuestCommunitiesSection(
                    communities: const [],
                    onSelect: (_) {},
                    loading: loading,
                    failed: failed,
                    onRetry: () => retries++))));
    await show(loading: true);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await show();
    expect(find.text('Communities will appear here soon.'), findsOneWidget);
    expect(find.text('See all'), findsNothing);
    await show(failed: true);
    await t.tap(find.text('Couldn’t load communities. Retry'));
    expect(retries, 1);
  });
}
