import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_companion_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/models/watch_log_details.dart';
import 'package:flixie_app/features/social/data/starred_people.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

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
  testWidgets(
      'an empty friend response preserves an existing companion selection',
      (tester) async {
    StarredPeople.instance.selectAccount('fixture');
    StarredPeople.instance.loaded = true;
    addTearDown(() => StarredPeople.instance.selectAccount(null));
    List<FriendshipUser>? result;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async => result =
                        await showModalBottomSheet<List<FriendshipUser>>(
                            context: context,
                            useRootNavigator: true,
                            useSafeArea: true,
                            builder: (_) => WatchCompanionPicker(
                                    loadFriends: () async => const [],
                                    selected: const [
                                      FriendshipUser(
                                          id: 'existing', username: 'Sam')
                                    ])),
                    child: const Text('Open picker'))))));
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    expect(find.text('Their name'), findsNothing);
    await tester.tap(find.text('Done · 1 selected'));
    await tester.pumpAndSettle();
    expect(result!.single.id, 'existing');
  });
  testWidgets('multi-select stays usable with a landscape search keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    StarredPeople.instance.selectAccount('fixture');
    StarredPeople.instance.loaded = true;
    addTearDown(() => StarredPeople.instance.selectAccount(null));
    List<FriendshipUser>? selected;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () async {
                      selected =
                          await showModalBottomSheet<List<FriendshipUser>>(
                              context: context,
                              useRootNavigator: true,
                              useSafeArea: true,
                              isScrollControlled: true,
                              builder: (_) => WatchCompanionPicker(
                                  loadFriends: () async => const [
                                        Friendship(
                                            id: 'sophie',
                                            createdAt: '',
                                            updatedAt: '',
                                            friend: FriendshipUser(
                                                id: 'sophie',
                                                username: 'Sophie')),
                                      ]));
                    },
                    child: const Text('Open picker'))))));
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 216);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Soph');
    await tester.pumpAndSettle();
    expect(find.text('Sophie').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Sophie'));
    await tester.pump();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(selected?.single.id, 'sophie');
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'favourited friends appear first and multiple selected companions save without a rating',
      (tester) async {
    StarredPeople.instance.selectAccount('fixture');
    StarredPeople.instance.ids = {'sophie'};
    StarredPeople.instance.loaded = true;
    addTearDown(() => StarredPeople.instance.selectAccount(null));
    WatchLogDetails? details;
    bool submitted = false;
    final friends = [
      for (final name in ['Casey', 'Sophie', 'Robin'])
        Friendship(
            id: name,
            createdAt: '',
            updatedAt: '',
            friend: FriendshipUser(
                id: name.toLowerCase(),
                username: name,
                profileBadges: const ['EARLY_ADOPTER']))
    ];
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => showMovieWatchLogSheet(
                        context: context,
                        builder: (_) => RewatchLogSheet(
                            movieTitle: 'Alien',
                            loadFriends: () async => friends,
                            onDetailsChanged: (d) => details = d,
                            onSubmit: (
                                {required watchedAt,
                                required rating,
                                required recommended,
                                required notes}) async {
                              expect(rating, isNull);
                              submitted = true;
                            })),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add someone'));
    await tester.pumpAndSettle();
    final tiles = tester
        .widgetList<ListTile>(find.descendant(
            of: find.byType(WatchCompanionPicker),
            matching: find.byType(ListTile)))
        .where((w) => w.title is Text)
        .toList();
    expect((tiles.first.title! as Text).data, 'Sophie');
    await tester.enterText(
        find.descendant(
            of: find.byType(WatchCompanionPicker),
            matching: find.byType(TextField)),
        'soph');
    await tester.pump();
    expect(find.text('Casey'), findsNothing);
    await tester.tap(find.text('Sophie'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(WatchCompanionPicker),
            matching: find.byType(TextField)),
        '');
    await tester.pump();
    await tester.tap(find.text('Casey'));
    await tester.pump();
    await tester.tap(find.text('Robin'));
    await tester.pump();
    await tester.tap(find.text('Robin'));
    await tester.pump();
    await tester.tap(find.text('Done · 2 selected'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileAvatarView), findsNWidgets(2));
    expect(
        tester
            .widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .every((avatar) => avatar.profileBadges.contains('EARLY_ADOPTER')),
        isTrue);
    await tester.tap(find.text('Save watch'));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
    expect(details!.companion!.id, 'sophie');
    expect(details!.companions.map((friend) => friend.id), ['sophie', 'casey']);
  });
  for (final spec in [
    (const Size(375, 667), 1.0),
    (const Size(390, 844), 1.5),
    (const Size(1180, 820), 1.0),
    (const Size(600, 900), 1.0),
    (const Size(844, 390), 1.0)
  ]) {
    testWidgets('watch log remains usable at ${spec.$1} text ${spec.$2}',
        (tester) async {
      tester.view.physicalSize = spec.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.binding.setSurfaceSize(spec.$1);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final capture = GlobalKey();
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => RepaintBoundary(
              key: capture,
              child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(spec.$2)),
                  child: child!)),
          home: Scaffold(
              body: Builder(
                  builder: (context) => TextButton(
                      onPressed: () => showMovieWatchLogSheet(
                          context: context,
                          builder: (_) => RewatchLogSheet(
                              movieTitle: 'Spider-Man: Across the Spider-Verse',
                              initial: const MovieWatchEntry(
                                  id: 'watch',
                                  userId: 'actor',
                                  movieId: 348,
                                  removed: false,
                                  companions: [
                                    FriendshipUser(
                                        id: 'sophie',
                                        username: 'Sophie',
                                        profileBadges: ['EARLY_ADOPTER']),
                                    FriendshipUser(
                                        id: 'casey',
                                        username: 'Casey',
                                        profileBadges: ['FOUNDER']),
                                  ]),
                              onSubmit: (
                                  {required watchedAt,
                                  required rating,
                                  required recommended,
                                  required notes}) async {})),
                      child: const Text('Open'))))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final save =
          tester.getRect(find.widgetWithText(FilledButton, 'Save changes'));
      expect(save.bottom, lessThanOrEqualTo(spec.$1.height));
      expect(find.text('Sophie'), findsOneWidget);
      expect(find.text('Casey'), findsOneWidget);
      if (const bool.fromEnvironment('CAPTURE_MULTI_WATCH')) {
        await tester.runAsync(() async {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('/tmp/flixie-multi-watch-${spec.$1.width.toInt()}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(find.text('Spider-Man: Across the Spider-Verse'), findsOneWidget);
    });
  }
  testWidgets('failed save retains the companion and review draft for retry',
      (tester) async {
    int attempts = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: RewatchLogSheet(
                movieTitle: 'Alien',
                companion: const FriendshipUser(id: 's', username: 'Sophie'),
                onSubmit: (
                    {required watchedAt,
                    required rating,
                    required recommended,
                    required notes}) async {
                  attempts++;
                  throw StateError('offline');
                }))));
    await tester.tap(find.text('Save watch'));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.text('Sophie'), findsOneWidget);
    expect(
        find.text(
            'Couldn’t save your watch. Your details are still here. Try again.'),
        findsOneWidget);
  });
}
