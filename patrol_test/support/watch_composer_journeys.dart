import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol_finders/patrol_finders.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/user.dart';
import '../../test/support/watchlist_auth.dart';
import '../../test/features/movies/watch_composer/fixture.dart';
import 'runtime_database_fixture.dart';

class ComposerAuth extends TestAuth {
  String viewer = 'viewer';
  @override
  User get dbUser => super.dbUser.copyWith(id: viewer);
  void switchAccount() {
    viewer = 'new-viewer';
    notifyListeners();
  }
}

class FailingComposerAnalytics extends AnalyticsController {
  FailingComposerAnalytics()
      : super(
            backend: RuntimeAnalyticsBackend(),
            consentStore: RuntimeAnalyticsConsentStore());
  @override
  Future<void> watchPlanCreated(
      {String? watchPlanId,
      int? contentId,
      String contentType = 'movie',
      required String planType,
      int? participantCount,
      String source = 'unknown'}) async {
    throw StateError('Tracking unavailable');
  }
}

Future<void> composerTap(PatrolTester $, String text) async {
  final label = find.text(text).first;
  final buttons = find.ancestor(
      of: label,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
  final tiles = find.ancestor(of: label, matching: find.byType(InkWell));
  final target = buttons.evaluate().isNotEmpty
      ? buttons.first
      : tiles.evaluate().isNotEmpty
          ? tiles.first
          : label;
  await Scrollable.ensureVisible($.tester.element(target), alignment: .5);
  await $.pumpAndSettle();
  expect(target.hitTestable(), findsOneWidget,
      reason: '$text must accept input');
  await $.tester.tap(target);
  await $.pumpAndSettle();
}

Future<void> openComposer(PatrolTester $, ComposerFixture fixture,
    {ComposerAuth? auth,
    bool group = false,
    double scale = 1,
    VoidCallback? success,
    VoidCallback? error,
    bool failingAnalytics = false,
    bool empty = false}) async {
  final viewer = auth ?? ComposerAuth();
  addTearDown(viewer.dispose);
  final analytics = FailingComposerAnalytics();
  addTearDown(analytics.dispose);
  final home = Scaffold(
      body: Builder(
          builder: (context) => Center(
                  child: FilledButton(
                child: const Text('Create plan'),
                onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    useRootNavigator: true,
                    useSafeArea: true,
                    isScrollControlled: true,
                    builder: (_) => MovieWatchRequestSheet(
                        movieId: empty ? null : 348,
                        movieTitle: empty ? null : 'Alien',
                        requesterId: 'viewer',
                        friends: const [],
                        service: fixture,
                        initialGroupMode: group,
                        initialGroupId: group ? 'Film friends' : null,
                        onSuccess: success ?? () {},
                        onError: error ?? () {})),
              ))));
  await $.pumpWidgetAndSettle(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: viewer),
        if (failingAnalytics)
          ChangeNotifierProvider<AnalyticsController>.value(value: analytics),
      ],
      child: MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!),
          home: home)));
  await composerTap($, 'Create plan');
}

void watchComposerJourneys(
    void Function(String, Future<void> Function(PatrolTester)) register) {
  for (final group in [false, true]) {
    register(
        'composer ${group ? 'group' : 'friend'} save failure stays open; retry saves schedule and closes',
        ($) async {
      final api = ComposerFixture()..failSend = true;
      var successes = 0, errors = 0;
      await openComposer($, api,
          group: group, success: () => successes++, error: () => errors++);
      if (!group) await composerTap($, 'Robin');
      await composerTap($, 'Choose when to watch');
      await composerTap($, 'Tomorrow');
      await composerTap($, 'Save schedule');
      await composerTap($, 'Send watch plan');
      expect(successes, 0);
      expect(errors, 1);
      expect(find.byType(MovieWatchRequestSheet), findsOneWidget);
      await composerTap($, 'Send watch plan');
      expect(successes, 1);
      expect(errors, 1);
      expect(find.byType(MovieWatchRequestSheet), findsNothing);
      expect(
          api.writes.single['recipientId'], group ? 'Film friends' : 'Robin');
      expect(api.writes.single['movies'], [348]);
      expect(api.writes.single['dateOnly'], true);
    });
  }
  register('empty composer browses cinema, adds a film and sends that film',
      ($) async {
    final api = ComposerFixture();
    await openComposer($, api, empty: true);
    await composerTap($, 'Robin');
    await composerTap($, 'Browse cinema releases');
    expect(find.text('In cinemas near you'), findsOneWidget);
    await composerTap($, 'The Odyssey');
    expect(api.cinemaRegions, ['GB']);
    await composerTap($, 'Send watch plan');
    expect(api.writes.single['movies'], [1368337]);
    expect(find.byType(MovieWatchRequestSheet), findsNothing);
  });
  register('composer search excludes existing films and adds a new option',
      ($) async {
    final api = ComposerFixture();
    await openComposer($, api);
    final add = find.byTooltip('Add another movie option');
    await Scrollable.ensureVisible($.tester.element(add), alignment: .5);
    await $.pumpAndSettle();
    await $.tester.tap(add);
    await $.pumpAndSettle();
    await $.tester.enterText(find.byType(TextField).last, 'Odyssey');
    // Native text caret animation remains active until editing ends.
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();
    expect(api.searches, ['Odyssey']);
    await composerTap($, 'The Odyssey');
    await composerTap($, 'Robin');
    await composerTap($, 'Send watch plan');
    expect(api.writes.single['movies'], [348, 1368337]);
  });
  register(
      'composer account change removes composer and nested schedule without a write',
      ($) async {
    final api = ComposerFixture(), auth = ComposerAuth();
    await openComposer($, api, auth: auth);
    await composerTap($, 'Robin');
    await composerTap($, 'Choose when to watch');
    expect(find.byType(BottomSheet), findsNWidgets(2));
    auth.switchAccount();
    await $.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    expect(api.writes, isEmpty);
    expect($.tester.takeException(), isNull);
  });
  register(
      'composer does not report a confirmed save as failed when analytics throws',
      ($) async {
    final api = ComposerFixture();
    var successes = 0, errors = 0;
    await openComposer($, api,
        failingAnalytics: true,
        success: () => successes++,
        error: () => errors++);
    await composerTap($, 'Robin');
    await composerTap($, 'Send watch plan');
    expect(successes, 1);
    expect(errors, 0);
    expect(api.writes.length, 1);
    expect(find.byType(MovieWatchRequestSheet), findsNothing);
  });
  register(
      'composer recipient search keeps badges and group switching reuses provider reads',
      ($) async {
    final api = ComposerFixture();
    await openComposer($, api);
    expect(
        $.tester
            .widget<ProfileAvatarView>(find.byType(ProfileAvatarView).first)
            .profileBadges,
        ['FOUNDER']);
    await $.tester.enterText(find.byType(TextField).first, 'Ellis');
    // Native text caret animation remains active until editing ends.
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();
    expect(find.text('Robin'), findsNothing);
    await composerTap($, 'Ellis');
    await $.tester.enterText(find.byType(TextField).first, '');
    // Native text caret animation remains active until editing ends.
    FocusManager.instance.primaryFocus?.unfocus();
    await $.pumpAndSettle();
    await composerTap($, 'A Group');
    await composerTap($, 'Film friends');
    await composerTap($, 'Alien fans');
    await composerTap($, 'Film friends');
    expect(api.userReads, {'viewer': 1, 'Ellis': 1, 'Robin': 1, 'Blair': 1});
    expect(api.writes, isEmpty);
  });
  register(
      'composer delayed save after account change cannot call old callbacks',
      ($) async {
    final api = ComposerFixture()..writeGate = Completer<String?>();
    final auth = ComposerAuth();
    var callbacks = 0;
    await openComposer($, api,
        auth: auth, success: () => callbacks++, error: () => callbacks++);
    await composerTap($, 'Robin');
    final send = find.text('Send watch plan');
    await $.tester.ensureVisible(send);
    await $.pumpAndSettle();
    await $.tester.tap(send);
    await $.pump();
    auth.switchAccount();
    await $.pumpAndSettle();
    api.writeGate!.complete('saved');
    await $.pumpAndSettle();
    expect(callbacks, 0);
    expect(api.writes.length, 1);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
